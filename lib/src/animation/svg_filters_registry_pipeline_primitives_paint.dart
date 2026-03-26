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

  /// Resolves feDropShadow output using Blink's multi-pass composition.
  ///
  /// feDropShadow is a convenience primitive that expands to the following
  /// filter primitive sub-graph per SVG Filter 1.1 spec and Blink's impl:
  /// 1. Extract alpha from input (SourceAlpha equivalent)
  /// 2. feGaussianBlur - blur the alpha with stdDeviation
  /// 3. feOffset - offset by dx/dy
  /// 4. feFlood - fill with shadow color (flood-color * flood-opacity)
  /// 5. feComposite in="flood" in2="blurredAlpha" operator="in" - cut flood to blur shape
  /// 6. feMerge - combine shadow with original input (shadow behind, input on top)
  ///
  /// Blink's multi-pass approach ensures:
  /// - Shadow shape comes from blurred alpha, not RGB
  /// - Flood color is multiplied by the blurred alpha mask
  /// - Result is properly composited behind the source
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
    final blurFilter = shadow.apply();

    // Check for zero blur (optimization: skip blur composition).
    // HARDENING: Check both X and Y independently for asymmetric blur cases.
    final hasBlur = shadow.stdDeviationX > 0 || shadow.stdDeviationY > 0;

    // Blink's multi-pass composition approach:
    // Step 1: Extract alpha from input (implicit via srcIn blend)
    // Step 2: Apply blur to the alpha mask
    // Step 3: Apply offset
    // Step 4: Flood color with srcIn to cut flood to blurred alpha shape
    // Step 5: Merge shadow behind source

    final shadowColor = shadow.effectiveShadowColor;

    // Create shadow passes from input using Blink's multi-pass approach:
    // 1. blur(alpha) -> 2. offset -> 3. flood*alpha via srcIn
    final shadowPasses = input
        .map(
          (pass) => SvgDropShadowPaintPass(
            // Compose blur filter with any existing filter on the input pass.
            // This blurs the alpha channel shape for the shadow.
            imageFilter: hasBlur
                ? _composeImageFilter(blurFilter, pass.imageFilter)
                : pass.imageFilter,
            // Apply shadow color using srcIn to properly multiply flood color
            // with the blurred alpha mask (Blink's feComposite in="flood" in2="blur" operator="in").
            colorFilter: ui.ColorFilter.mode(
              shadowColor,
              ui.BlendMode.srcIn,
            ),
            // Shadow renders with srcOver to blend behind the input.
            blendMode: ui.BlendMode.srcOver,
            // Apply the offset (dx/dy) to position the shadow.
            offset: pass.offset + shadow.offset,
            // Preserve paint channel scope from input.
            paintFill: pass.paintFill,
            paintStroke: pass.paintStroke,
            // Store shadow parameters for potential advanced rendering.
            shadowFilter: shadow,
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
