part of 'svg_filters.dart';

extension SvgFiltersPipelinePrimitivePaintExtension on SvgFilters {
  List<SvgFilterPaintPass> _resolvePassthroughOutput({
    required String? requestedInput,
    required List<SvgFilterPaintPass> previous,
    required Map<String, List<SvgFilterPaintPass>> namedResults,
    required List<SvgFilterPaintPass> sourceGraphic,
    required List<SvgFilterPaintPass> sourceAlpha,
  }) {
    return _resolvePrimitiveInput(
      requestedInput: requestedInput,
      previous: previous,
      namedResults: namedResults,
      sourceGraphic: sourceGraphic,
      sourceAlpha: sourceAlpha,
    );
  }

  List<SvgFilterPaintPass> _resolveOffsetOutput({
    required SvgOffsetFilter offsetFilter,
    required List<SvgFilterPaintPass> previous,
    required Map<String, List<SvgFilterPaintPass>> namedResults,
    required List<SvgFilterPaintPass> sourceGraphic,
    required List<SvgFilterPaintPass> sourceAlpha,
  }) {
    final input = _resolvePrimitiveInput(
      requestedInput: offsetFilter.input,
      previous: previous,
      namedResults: namedResults,
      sourceGraphic: sourceGraphic,
      sourceAlpha: sourceAlpha,
    );
    return input
        .map(
          (pass) => pass.copyWith(
            offset: pass.offset + ui.Offset(offsetFilter.dx, offsetFilter.dy),
          ),
        )
        .toList(growable: false);
  }

  List<SvgFilterPaintPass> _resolveFloodOutput(SvgFloodFilter flood) {
    return <SvgFilterPaintPass>[
      SvgFilterPaintPass(
        colorFilter: ui.ColorFilter.mode(
          flood.effectiveColor,
          ui.BlendMode.src,
        ),
      ),
    ];
  }

  /// Resolves feDropShadow output for complex filter chains.
  ///
  /// feDropShadow is a convenience primitive that expands to the following
  /// filter primitive sub-graph per SVG Filter 1.1 spec:
  /// 1. feGaussianBlur - blur the input with stdDeviation
  /// 2. feOffset - offset by dx/dy
  /// 3. feFlood - fill with shadow color (flood-color * flood-opacity)
  /// 4. feComposite in="flood" in2="blur" operator="in" - cut flood to blur shape
  /// 5. feMerge - combine shadow with original input (shadow behind, input on top)
  ///
  /// When used with non-source inputs (e.g., in="blurred") or as part of a
  /// larger filter chain (e.g., feDropShadow -> feComposite), the composition
  /// must correctly preserve the input chain state.
  ///
  /// Chaining considerations:
  /// - If feDropShadow has a result name, downstream primitives can reference it
  /// - The result contains both shadow passes and source passes (merged)
  /// - When chained, subsequent primitives process all output passes
  ///
  /// Input validation and edge cases:
  /// - Empty/unresolved input: returns empty passes (transparent black)
  /// - stdDeviation=0: skips blur filter but still applies offset/color
  /// - flood-opacity=0: produces fully transparent shadow (still layered)
  /// - Multiple downstream references: each gets a copy of all passes
  List<SvgFilterPaintPass> _resolveDropShadowOutput({
    required SvgDropShadowFilter shadow,
    required List<SvgFilterPaintPass> previous,
    required Map<String, List<SvgFilterPaintPass>> namedResults,
    required List<SvgFilterPaintPass> sourceGraphic,
    required List<SvgFilterPaintPass> sourceAlpha,
  }) {
    // Resolve the input (can be SourceGraphic, named result, or previous output).
    final input = _resolvePrimitiveInput(
      requestedInput: shadow.input,
      previous: previous,
      namedResults: namedResults,
      sourceGraphic: sourceGraphic,
      sourceAlpha: sourceAlpha,
    );

    // HARDENING: If input is empty (e.g., unresolved reference), produce no
    // shadow. This matches the SVG spec behavior where invalid/forward
    // references produce transparent black output.
    if (input.isEmpty) {
      return const <SvgFilterPaintPass>[];
    }

    // Get the blur filter (stdDeviation-based gaussian blur).
    final shadowFilter = shadow.apply();

    // Check for zero blur (optimization: skip blur composition).
    // HARDENING: Check both X and Y independently for asymmetric blur cases.
    final hasBlur = shadow.stdDeviationX > 0 || shadow.stdDeviationY > 0;

    // Create shadow passes from input, applying blur + offset + color.
    // This implements the expanded sub-graph: blur -> offset -> flood/composite.
    final shadowPasses = input
        .map(
          (pass) => SvgFilterPaintPass(
            // Compose blur filter with any existing filter on the input pass.
            imageFilter: hasBlur
                ? _composeImageFilter(shadowFilter, pass.imageFilter)
                : pass.imageFilter,
            // Apply shadow color using srcIn to cut flood to input shape.
            colorFilter: ui.ColorFilter.mode(
              shadow.effectiveShadowColor,
              ui.BlendMode.srcIn,
            ),
            // Shadow renders with srcOver to blend behind the input.
            blendMode: ui.BlendMode.srcOver,
            // Apply the offset (dx/dy) to position the shadow.
            offset: pass.offset + shadow.offset,
            // Preserve paint channel scope from input.
            paintFill: pass.paintFill,
            paintStroke: pass.paintStroke,
          ),
        )
        .toList(growable: false);

    // Merge shadow passes (first/bottom) with original input (last/top).
    // This matches the SVG spec behavior where the shadow appears behind.
    // The resulting list is: [shadow_pass_0, ..., shadow_pass_n, input_0, ..., input_n]
    //
    // HARDENING: Return a new list to prevent any mutation issues when this
    // result is cached and referenced by multiple downstream primitives.
    return <SvgFilterPaintPass>[...shadowPasses, ...input];
  }

  List<SvgFilterPaintPass> _resolveColorMatrixOutput({
    required SvgColorMatrixFilter colorMatrix,
    required List<SvgFilterPaintPass> previous,
    required Map<String, List<SvgFilterPaintPass>> namedResults,
    required List<SvgFilterPaintPass> sourceGraphic,
    required List<SvgFilterPaintPass> sourceAlpha,
  }) {
    final input = _resolvePrimitiveInput(
      requestedInput: colorMatrix.input,
      previous: previous,
      namedResults: namedResults,
      sourceGraphic: sourceGraphic,
      sourceAlpha: sourceAlpha,
    );
    final colorFilter = colorMatrix.colorFilter();
    if (colorFilter == null) {
      return input;
    }
    return input
        .map((pass) => pass.copyWith(colorFilter: colorFilter))
        .toList(growable: false);
  }

  List<SvgFilterPaintPass> _resolvePrimitiveInput({
    required String? requestedInput,
    required List<SvgFilterPaintPass> previous,
    required Map<String, List<SvgFilterPaintPass>> namedResults,
    required List<SvgFilterPaintPass> sourceGraphic,
    required List<SvgFilterPaintPass> sourceAlpha,
  }) {
    return _resolveInputPasses(
      requestedInput: requestedInput,
      previous: previous,
      namedResults: namedResults,
      sourceGraphic: sourceGraphic,
      sourceAlpha: sourceAlpha,
    );
  }
}
