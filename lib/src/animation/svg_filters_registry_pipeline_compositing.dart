part of 'svg_filters.dart';

extension SvgFiltersPipelineCompositingExtension on SvgFilters {
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
  /// - Built-in inputs (SourceGraphic, SourceAlpha, etc.)
  /// - Implicit previous output (when `in` is omitted)
  ///
  /// Layer ordering follows SVG spec: first feMergeNode is bottom layer,
  /// last feMergeNode is top layer.
  List<SvgFilterPaintPass> _resolveMergeOutput({
    required SvgMergeFilter merge,
    required List<SvgFilterPaintPass> previous,
    required Map<String, List<SvgFilterPaintPass>> namedResults,
    required List<SvgFilterPaintPass> sourceGraphic,
    required List<SvgFilterPaintPass> sourceAlpha,
  }) {
    final merged = <SvgFilterPaintPass>[];

    // Empty nodeInputs: use previous output as fallback.
    if (merge.nodeInputs.isEmpty) {
      merged.addAll(previous);
      return merged.isEmpty ? previous : merged;
    }

    // Track if any node contributed passes for proper empty handling.
    var hasContributions = false;

    // Process each feMergeNode in order (bottom to top layering).
    for (final nodeInput in merge.nodeInputs) {
      final nodePasses = _resolveInputPasses(
        requestedInput: nodeInput,
        previous: previous,
        namedResults: namedResults,
        sourceGraphic: sourceGraphic,
        sourceAlpha: sourceAlpha,
        // Explicit unresolved merge-node inputs are treated as empty inputs.
        // Implicit node input (missing `in`) still resolves via previous-chain
        // semantics.
      );

      if (nodePasses.isNotEmpty) {
        hasContributions = true;
        merged.addAll(nodePasses);
      }
    }

    // If all nodes resolved to empty, return identity to prevent black output.
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

    final input2Ref = composite.input2?.trim();
    final input2IsNone = _isNoneInputReference(input2Ref);

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
