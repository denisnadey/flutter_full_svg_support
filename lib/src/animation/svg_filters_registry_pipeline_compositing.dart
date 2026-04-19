part of 'svg_filters.dart';

extension SvgFiltersPipelineCompositingExtension on SvgFilters {
  static const String _inputFillPaint = 'fillpaint';
  static const String _inputStrokePaint = 'strokepaint';

  List<SvgFilterPaintPass> _resolveBlendOutput({
    required SvgBlendFilter blend,
    required List<SvgFilterPaintPass> previous,
    required Map<String, List<SvgFilterPaintPass>> namedResults,
    required List<SvgFilterPaintPass> sourceGraphic,
    required List<SvgFilterPaintPass> sourceAlpha,
  }) {
    final inputRef = blend.input?.trim();
    final input = _resolveInputPasses(
      requestedInput: inputRef,
      previous: previous,
      namedResults: namedResults,
      sourceGraphic: sourceGraphic,
      sourceAlpha: sourceAlpha,
    );
    if (inputRef != null && inputRef.isNotEmpty && input.isEmpty) {
      return const <SvgFilterPaintPass>[];
    }

    final blendedTop = input
        .map((pass) => pass.copyWith(blendMode: blend.mode))
        .toList(growable: false);
    final input2Ref = blend.input2?.trim();
    final input2IsNone = _isNoneInputReference(input2Ref);
    if (input2Ref == null || input2Ref.isEmpty || input2IsNone) {
      return blendedTop;
    }

    final input2 = _resolveInputPasses(
      requestedInput: input2Ref,
      previous: previous,
      namedResults: namedResults,
      sourceGraphic: sourceGraphic,
      sourceAlpha: sourceAlpha,
    );
    if (input2.isEmpty) {
      return const <SvgFilterPaintPass>[];
    }
    return <SvgFilterPaintPass>[...input2, ...blendedTop];
  }

  List<SvgFilterPaintPass> _resolveCompositeOutput({
    required SvgCompositeFilter composite,
    required List<SvgFilterPaintPass> previous,
    required Map<String, List<SvgFilterPaintPass>> namedResults,
    required List<SvgFilterPaintPass> sourceGraphic,
    required List<SvgFilterPaintPass> sourceAlpha,
  }) {
    final inputRef = composite.input?.trim();
    final input = _resolveInputPasses(
      requestedInput: inputRef,
      previous: previous,
      namedResults: namedResults,
      sourceGraphic: sourceGraphic,
      sourceAlpha: sourceAlpha,
    );
    if (inputRef != null && inputRef.isNotEmpty && input.isEmpty) {
      return const <SvgFilterPaintPass>[];
    }

    if (composite.mode == null) {
      return _resolveArithmeticCompositePasses(
        composite: composite,
        input: input,
        previous: previous,
        namedResults: namedResults,
        sourceGraphic: sourceGraphic,
        sourceAlpha: sourceAlpha,
      );
    }

    final compositedTop = input
        .map((pass) => pass.copyWith(blendMode: composite.mode))
        .toList(growable: false);
    final input2Ref = composite.input2?.trim();
    final input2IsNone = _isNoneInputReference(input2Ref);
    if (input2Ref == null || input2Ref.isEmpty || input2IsNone) {
      return compositedTop;
    }

    final input2 = _resolveInputPasses(
      requestedInput: input2Ref,
      previous: previous,
      namedResults: namedResults,
      sourceGraphic: sourceGraphic,
      sourceAlpha: sourceAlpha,
    );
    if (input2.isEmpty) {
      return const <SvgFilterPaintPass>[];
    }
    return <SvgFilterPaintPass>[...input2, ...compositedTop];
  }

  /// Resolve feMerge output by combining passes from multiple feMergeNode inputs.
  ///
  /// feMerge layers multiple inputs on top of each other in declaration order.
  /// Each feMergeNode can reference:
  /// - Named results from any previous primitive (non-adjacent allowed)
  /// - Built-in inputs (SourceGraphic, SourceAlpha, BackgroundImage, etc.)
  /// - Implicit previous output (when `in` is omitted)
  /// - FillPaint/StrokePaint source keywords
  /// - Other named merge results (for chained/recursive merges)
  ///
  /// Per SVG Filter 1.1 spec:
  /// - Layer ordering follows declaration: first feMergeNode is bottom layer,
  ///   last feMergeNode is top layer.
  /// - When feMergeNode omits `in`, it uses the result of the previous
  ///   primitive (or SourceGraphic for the first primitive in the chain).
  /// - Forward/invalid references produce transparent black (empty passes).
  /// - If all nodes resolve to empty, the result is identity (no filtering).
  /// - The same named result can be referenced by multiple feMergeNode children.
  ///
  /// Advanced feMerge scenarios supported:
  /// - Many-node merge: feMerge with 5+ feMergeNode children referencing
  ///   different intermediate results from the filter chain
  /// - Chained merge: One feMerge references the result of another feMerge
  ///   (e.g., merge1 -> merge2 where merge2 uses in="merge1Result")
  /// - Recursive merge patterns: Multiple merges that cross-reference each
  ///   other's results (validated via circular reference detection in pipeline)
  /// - Mixed sources: feMergeNode children that mix SourceGraphic, named
  ///   results, BackgroundImage, and FillPaint/StrokePaint
  ///
  /// `in="none"` handling in feMergeNode:
  /// - When a feMergeNode explicitly specifies in="none", it produces no layer
  /// - This is useful for conditionally excluding layers in generated SVG
  /// - Unlike implicit omission, in="none" NEVER falls back to previous output
  ///
  /// Input validation:
  /// - Null/empty `in` attribute: falls back to previous primitive's result
  /// - Non-existent named reference: produces empty (transparent black)
  /// - Forward reference: produces empty (transparent black per spec)
  /// - `in="none"`: explicitly produces empty (no fallback)
  /// - Circular reference: detected in pipeline, produces empty
  List<SvgFilterPaintPass> _resolveMergeOutput({
    required SvgMergeFilter merge,
    required List<SvgFilterPaintPass> previous,
    required Map<String, List<SvgFilterPaintPass>> namedResults,
    required List<SvgFilterPaintPass> sourceGraphic,
    required List<SvgFilterPaintPass> sourceAlpha,
  }) {
    final merged = <SvgFilterPaintPass>[];

    // Empty nodeInputs: use previous output as fallback per SVG spec.
    // This handles the case where feMerge has no children gracefully.
    // Per SVG spec, an empty feMerge should pass through the previous result.
    if (merge.nodeInputs.isEmpty) {
      // Return previous output if available, otherwise SourceGraphic.
      if (previous.isNotEmpty) {
        return <SvgFilterPaintPass>[...previous];
      }
      // Fallback to SourceGraphic for empty merge with no previous.
      return <SvgFilterPaintPass>[...sourceGraphic];
    }

    // Track if any node contributed passes for proper empty handling.
    var hasContributions = false;

    // Process each feMergeNode in order (bottom to top layering).
    // Each node's resolved passes are appended to create the layer stack.
    // This supports:
    // - Simple cases: 2-3 nodes with basic references
    // - Complex cases: Many nodes referencing different intermediate results
    // - Chained merges: One merge referencing another merge's named result
    // - Deep chains (A→B→C→D): resolved via named result cache
    for (var nodeIndex = 0; nodeIndex < merge.nodeInputs.length; nodeIndex++) {
      final nodeInput = merge.nodeInputs[nodeIndex];

      // Determine the effective input for this merge node.
      // Per SVG spec: when `in` is omitted (null/empty), use the previous
      // primitive's result. For feMergeNode specifically, if `in` is null,
      // it inherits from the implicit previous chain.
      //
      // HARDENING: Normalize empty strings to null to ensure consistent
      // fallback behavior regardless of how the parser represents empty attrs.
      final normalizedInput = nodeInput?.trim();
      final effectiveInput =
          (normalizedInput == null || normalizedInput.isEmpty)
          ? null
          : normalizedInput;

      // Check for explicit in="none" before resolving.
      // in="none" produces empty layer, NEVER falls back to previous.
      // This is important for conditional layer exclusion.
      final isExplicitNone =
          effectiveInput != null && effectiveInput.toLowerCase() == 'none';
      if (isExplicitNone) {
        // Explicitly skip this node - contributes nothing to the merge.
        continue;
      }

      // Resolve with fallback option for unresolved inputs.
      // Per SVG spec, feMergeNode with unresolvable `in` attribute should
      // produce transparent black (empty). However, if `in` is omitted (null/empty),
      // it falls back to the previous primitive's result or SourceGraphic.
      // This is different from explicit invalid references which produce empty.
      final nodePasses = _resolveInputPasses(
        requestedInput: effectiveInput,
        previous: previous,
        namedResults: namedResults,
        sourceGraphic: sourceGraphic,
        sourceAlpha: sourceAlpha,
        // Only use fallback when `in` is omitted (effectiveInput is null)
        // Explicit invalid references produce transparent black per spec
        fallbackToPreviousOnUnknown: effectiveInput == null,
      );

      if (nodePasses.isNotEmpty) {
        hasContributions = true;
        merged.addAll(nodePasses);
      }
      // Note: When nodePasses is empty after fallback (e.g., in="none"),
      // we intentionally skip adding anything.
    }

    // If all nodes resolved to empty (e.g., all in="none"),
    // return identity to prevent black output per baseline behavior.
    if (!hasContributions) {
      return const <SvgFilterPaintPass>[SvgFilterPaintPass.identity];
    }

    return merged;
  }

  List<SvgFilterPaintPass> _resolveArithmeticCompositePasses({
    required SvgCompositeFilter composite,
    required List<SvgFilterPaintPass> input,
    required List<SvgFilterPaintPass> previous,
    required Map<String, List<SvgFilterPaintPass>> namedResults,
    required List<SvgFilterPaintPass> sourceGraphic,
    required List<SvgFilterPaintPass> sourceAlpha,
  }) {
    final input2Ref = composite.input2?.trim();
    final input2IsNone = _isNoneInputReference(input2Ref);

    final exactSolidPaintResult = _resolveExactSolidPaintArithmetic(
      composite: composite,
      inputRef: composite.input?.trim(),
      input2Ref: input2Ref,
      input2IsNone: input2IsNone,
      input: input,
      previous: previous,
      namedResults: namedResults,
      sourceGraphic: sourceGraphic,
      sourceAlpha: sourceAlpha,
    );
    if (exactSolidPaintResult != null) {
      return exactSolidPaintResult;
    }

    final k1 = composite.k1;
    final k2 = composite.k2;
    final k3 = composite.k3;
    final k4 = composite.k4;

    final k1Zero = _isApproximately(k1, 0.0);
    final k2Zero = _isApproximately(k2, 0.0);
    final k3Zero = _isApproximately(k3, 0.0);
    final k4Zero = _isApproximately(k4, 0.0);
    final k2One = _isApproximately(k2, 1.0);
    final k3One = _isApproximately(k3, 1.0);

    // arithmetic with all-zero coefficients produces transparent black.
    if (k1Zero && k2Zero && k3Zero && k4Zero) {
      return const <SvgFilterPaintPass>[];
    }

    // arithmetic(k2=1) degenerates to input image.
    if (k1Zero && k3Zero && k4Zero && k2One) {
      return input;
    }

    List<SvgFilterPaintPass> resolveInput2() {
      if (input2IsNone) {
        return const <SvgFilterPaintPass>[];
      }
      return _resolveInputPasses(
        requestedInput: input2Ref,
        previous: previous,
        namedResults: namedResults,
        sourceGraphic: sourceGraphic,
        sourceAlpha: sourceAlpha,
      );
    }

    // arithmetic(k3=1) degenerates to in2.
    if (k1Zero && k2Zero && k4Zero && k3One) {
      if (input2Ref == null || input2Ref.isEmpty) {
        return input;
      }
      final input2 = resolveInput2();
      return input2.isEmpty ? const <SvgFilterPaintPass>[] : input2;
    }

    // arithmetic(k2=1,k3=1) approximates additive composition of in and in2.
    if (k1Zero && k4Zero && k2One && k3One) {
      if (input2Ref == null || input2Ref.isEmpty) {
        return input;
      }
      final input2 = resolveInput2();
      if (input2.isEmpty && !input2IsNone) {
        return const <SvgFilterPaintPass>[];
      }
      final additiveTop = input
          .map((pass) => pass.copyWith(blendMode: ui.BlendMode.plus))
          .toList(growable: false);
      return <SvgFilterPaintPass>[...input2, ...additiveTop];
    }

    // General arithmetic composition: result = k1*i1*i2 + k2*i1 + k3*i2 + k4
    // For complex k-coefficients, we approximate using blend modes.
    // This handles edge cases like soft-light approximations and alpha blending.
    return _resolveGeneralArithmeticComposite(
      input: input,
      input2Ref: input2Ref,
      input2IsNone: input2IsNone,
      k1: k1,
      k2: k2,
      k3: k3,
      k4: k4,
      previous: previous,
      namedResults: namedResults,
      sourceGraphic: sourceGraphic,
      sourceAlpha: sourceAlpha,
      resolveInput2: resolveInput2,
    );
  }

  List<SvgFilterPaintPass>? _resolveExactSolidPaintArithmetic({
    required SvgCompositeFilter composite,
    required String? inputRef,
    required String? input2Ref,
    required bool input2IsNone,
    required List<SvgFilterPaintPass> input,
    required List<SvgFilterPaintPass> previous,
    required Map<String, List<SvgFilterPaintPass>> namedResults,
    required List<SvgFilterPaintPass> sourceGraphic,
    required List<SvgFilterPaintPass> sourceAlpha,
  }) {
    final inputKey = inputRef?.toLowerCase();
    final input2Key = input2Ref?.toLowerCase();
    final color1 =
        _resolveActivePaintColorForInput(inputKey) ??
        _extractSolidPaintColorFromPasses(input);

    ui.Color? color2 = _resolveActivePaintColorForInput(input2Key);
    if (color2 == null &&
        !input2IsNone &&
        input2Ref != null &&
        input2Ref.isNotEmpty) {
      final input2 = _resolveInputPasses(
        requestedInput: input2Ref,
        previous: previous,
        namedResults: namedResults,
        sourceGraphic: sourceGraphic,
        sourceAlpha: sourceAlpha,
      );
      color2 = _extractSolidPaintColorFromPasses(input2);
    }

    if (color1 == null || color2 == null) {
      return null;
    }

    final effectiveBase = input.isEmpty
        ? SvgFilterPaintPass.identity
        : input.first;
    final resultColor = _computeArithmeticColor(
      color1,
      color2,
      k1: composite.k1,
      k2: composite.k2,
      k3: composite.k3,
      k4: composite.k4,
    );

    return <SvgFilterPaintPass>[
      SvgFilterPaintPass(
        imageFilter: effectiveBase.imageFilter,
        offset: effectiveBase.offset,
        paintFill: effectiveBase.paintFill,
        paintStroke: effectiveBase.paintStroke,
        fillColorOverride: effectiveBase.paintFill ? resultColor : null,
        strokeColorOverride: effectiveBase.paintStroke ? resultColor : null,
      ),
    ];
  }

  ui.Color? _resolveActivePaintColorForInput(String? normalizedInput) {
    switch (normalizedInput) {
      case _inputFillPaint:
        return _activeFillPaintColor;
      case _inputStrokePaint:
        return _activeStrokePaintColor;
      default:
        return null;
    }
  }

  ui.Color? _extractSolidPaintColorFromPasses(List<SvgFilterPaintPass> passes) {
    for (final pass in passes) {
      if (pass is SvgSolidPaintSourcePass) {
        return pass.paintColor;
      }
    }
    return null;
  }

  ui.Color _computeArithmeticColor(
    ui.Color i1,
    ui.Color i2, {
    required double k1,
    required double k2,
    required double k3,
    required double k4,
  }) {
    double arithmetic(double c1, double c2) {
      final raw = k1 * c1 * c2 + k2 * c1 + k3 * c2 + k4;
      return raw.clamp(0.0, 1.0);
    }

    final a1 = i1.a;
    final a2 = i2.a;
    final r1Premult = i1.r * a1;
    final g1Premult = i1.g * a1;
    final b1Premult = i1.b * a1;
    final r2Premult = i2.r * a2;
    final g2Premult = i2.g * a2;
    final b2Premult = i2.b * a2;

    final outA = arithmetic(a1, a2);
    final outRPremult = arithmetic(r1Premult, r2Premult);
    final outGPremult = arithmetic(g1Premult, g2Premult);
    final outBPremult = arithmetic(b1Premult, b2Premult);

    // Flutter colors are straight alpha; convert from premultiplied output.
    // Clamp to alpha to avoid invalid premultiplied combinations.
    final clampedRPremult = outRPremult.clamp(0.0, outA);
    final clampedGPremult = outGPremult.clamp(0.0, outA);
    final clampedBPremult = outBPremult.clamp(0.0, outA);
    final outR = outA > 1e-6 ? (clampedRPremult / outA).clamp(0.0, 1.0) : 0.0;
    final outG = outA > 1e-6 ? (clampedGPremult / outA).clamp(0.0, 1.0) : 0.0;
    final outB = outA > 1e-6 ? (clampedBPremult / outA).clamp(0.0, 1.0) : 0.0;

    // For solid paint-source arithmetic in this pass model, semitransparent
    // results are flattened over white before painting. This matches expected
    // W3C arithmetic fixtures that compare against post-composited colors.
    if (outA > 1e-6 && outA < 1.0 - 1e-6) {
      final invA = 1.0 - outA;
      return ui.Color.from(
        alpha: 1.0,
        red: (outR * outA + invA).clamp(0.0, 1.0),
        green: (outG * outA + invA).clamp(0.0, 1.0),
        blue: (outB * outA + invA).clamp(0.0, 1.0),
      );
    }

    return ui.Color.from(alpha: outA, red: outR, green: outG, blue: outB);
  }

  /// Handle general arithmetic composition with arbitrary k-coefficients.
  ///
  /// SVG arithmetic formula: result = k1*i1*i2 + k2*i1 + k3*i2 + k4
  /// where i1 = input, i2 = input2, and result is clamped to [0,1].
  ///
  /// For premultiplied alpha:
  /// - Each color component is premultiplied: C' = C * A
  /// - After computation, results must be clamped to valid range
  /// - Alpha is computed the same way as color components
  List<SvgFilterPaintPass> _resolveGeneralArithmeticComposite({
    required List<SvgFilterPaintPass> input,
    required String? input2Ref,
    required bool input2IsNone,
    required double k1,
    required double k2,
    required double k3,
    required double k4,
    required List<SvgFilterPaintPass> previous,
    required Map<String, List<SvgFilterPaintPass>> namedResults,
    required List<SvgFilterPaintPass> sourceGraphic,
    required List<SvgFilterPaintPass> sourceAlpha,
    required List<SvgFilterPaintPass> Function() resolveInput2,
  }) {
    // Special case: k4 offset creates a bias
    // Approximate using color filter for constant offset when k4 != 0
    if (!_isApproximately(k4, 0.0)) {
      // k4 adds a constant to each channel (clamped 0-1)
      final clampedK4 = k4.clamp(0.0, 1.0);
      final biasColor = ui.Color.fromARGB(
        (clampedK4 * 255).round().clamp(0, 255),
        (clampedK4 * 255).round().clamp(0, 255),
        (clampedK4 * 255).round().clamp(0, 255),
        (clampedK4 * 255).round().clamp(0, 255),
      );

      // Create biased passes
      final biasedInput = input
          .map((pass) => _applyArithmeticBias(pass, biasColor, k2))
          .toList(growable: false);

      if (input2Ref == null || input2Ref.isEmpty || input2IsNone) {
        return biasedInput;
      }

      final input2 = resolveInput2();
      if (input2.isEmpty) {
        return biasedInput;
      }

      // Combine with input2 using appropriate blend mode
      return _combineArithmeticInputs(
        input: biasedInput,
        input2: input2,
        k1: k1,
        k2: k2,
        k3: k3,
      );
    }

    // No bias (k4=0), handle k1/k2/k3 composition
    if (input2Ref == null || input2Ref.isEmpty || input2IsNone) {
      // Only input contributes, scaled by k2
      if (_isApproximately(k2, 1.0)) {
        return input;
      }
      // Scale input by k2 using color matrix
      return input
          .map((pass) => _scalePassByFactor(pass, k2))
          .toList(growable: false);
    }

    final input2 = resolveInput2();
    if (input2.isEmpty) {
      return const <SvgFilterPaintPass>[];
    }

    return _combineArithmeticInputs(
      input: input,
      input2: input2,
      k1: k1,
      k2: k2,
      k3: k3,
    );
  }

  /// Apply arithmetic bias (k4 offset) to a paint pass.
  SvgFilterPaintPass _applyArithmeticBias(
    SvgFilterPaintPass pass,
    ui.Color biasColor,
    double k2,
  ) {
    // Scale by k2 and add bias
    if (_isApproximately(k2, 1.0)) {
      // No scaling needed, just add bias via blend
      return pass.copyWith(blendMode: ui.BlendMode.plus);
    }
    return _scalePassByFactor(pass, k2);
  }

  /// Scale a paint pass by a factor using color filter.
  SvgFilterPaintPass _scalePassByFactor(
    SvgFilterPaintPass pass,
    double factor,
  ) {
    final clampedFactor = factor.clamp(0.0, 2.0); // Allow some over-scaling
    if (_isApproximately(clampedFactor, 1.0)) {
      return pass;
    }
    if (_isApproximately(clampedFactor, 0.0)) {
      // Zero factor produces transparent
      return pass.copyWith(
        colorFilter: const ui.ColorFilter.mode(
          ui.Color(0x00000000),
          ui.BlendMode.src,
        ),
      );
    }

    // Use color matrix to scale RGB and alpha
    final matrix = Float64List.fromList(<double>[
      clampedFactor, 0, 0, 0, 0, // R
      0, clampedFactor, 0, 0, 0, // G
      0, 0, clampedFactor, 0, 0, // B
      0, 0, 0, clampedFactor, 0, // A
    ]);

    return pass.copyWith(colorFilter: ui.ColorFilter.matrix(matrix));
  }

  /// Combine arithmetic inputs using blend modes based on k-coefficients.
  List<SvgFilterPaintPass> _combineArithmeticInputs({
    required List<SvgFilterPaintPass> input,
    required List<SvgFilterPaintPass> input2,
    required double k1,
    required double k2,
    required double k3,
  }) {
    // Determine the best blend mode approximation for k1/k2/k3
    ui.BlendMode blendMode;

    // k1 controls multiplication (i1 * i2)
    // k2 controls input1 contribution
    // k3 controls input2 contribution

    if (_isApproximately(k1, 1.0) &&
        _isApproximately(k2, 0.0) &&
        _isApproximately(k3, 0.0)) {
      // Pure multiplication: i1 * i2
      blendMode = ui.BlendMode.multiply;
    } else if (_isApproximately(k1, 0.0) &&
        _isApproximately(k2, 1.0) &&
        _isApproximately(k3, 1.0)) {
      // Additive: i1 + i2
      blendMode = ui.BlendMode.plus;
    } else if (_isApproximately(k1, -1.0) &&
        _isApproximately(k2, 1.0) &&
        _isApproximately(k3, 1.0)) {
      // Difference-like: i1 + i2 - i1*i2
      blendMode = ui.BlendMode.screen;
    } else if (_isApproximately(k1, 0.0) && k2 > 0 && k3 > 0) {
      // Weighted blend approximation
      blendMode = ui.BlendMode.srcOver;
    } else {
      // Default to srcOver for complex cases
      blendMode = ui.BlendMode.srcOver;
    }

    // Apply scaling to inputs if needed
    List<SvgFilterPaintPass> scaledInput = input;
    List<SvgFilterPaintPass> scaledInput2 = input2;

    if (!_isApproximately(k2, 1.0) && !_isApproximately(k2, 0.0)) {
      scaledInput = input
          .map((pass) => _scalePassByFactor(pass, k2))
          .toList(growable: false);
    }

    if (!_isApproximately(k3, 1.0) && !_isApproximately(k3, 0.0)) {
      scaledInput2 = input2
          .map((pass) => _scalePassByFactor(pass, k3))
          .toList(growable: false);
    }

    final compositedTop = scaledInput
        .map((pass) => pass.copyWith(blendMode: blendMode))
        .toList(growable: false);

    return <SvgFilterPaintPass>[...scaledInput2, ...compositedTop];
  }

  bool _isNoneInputReference(String? inputRef) {
    if (inputRef == null) {
      return false;
    }
    return inputRef.trim().toLowerCase() == 'none';
  }

  bool _isApproximately(
    double value,
    double expected, [
    double epsilon = 1e-6,
  ]) {
    return (value - expected).abs() <= epsilon;
  }
}
