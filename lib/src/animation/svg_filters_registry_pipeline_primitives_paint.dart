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
  /// feDropShadow is a convenience primitive that combines:
  /// 1. feGaussianBlur - blur the input
  /// 2. feOffset - offset by dx/dy
  /// 3. feFlood - fill with shadow color
  /// 4. feComposite in="flood" in2="blur" operator="in" - cut flood to blur shape
  /// 5. feMerge - combine shadow with original input
  ///
  /// When used with non-source inputs (e.g., in="blurred") or as part of a
  /// larger filter chain (e.g., feDropShadow -> feComposite), the composition
  /// must correctly preserve the input chain state.
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

    // If input is empty (e.g., unresolved reference), produce no shadow.
    if (input.isEmpty) {
      return const <SvgFilterPaintPass>[];
    }

    final shadowFilter = shadow.apply();

    // Create shadow passes from input, applying blur + offset + color.
    final shadowPasses = input
        .map(
          (pass) => SvgFilterPaintPass(
            imageFilter: _composeImageFilter(shadowFilter, pass.imageFilter),
            colorFilter: ui.ColorFilter.mode(
              shadow.effectiveShadowColor,
              ui.BlendMode.srcIn,
            ),
            blendMode: ui.BlendMode.srcOver,
            offset: pass.offset + shadow.offset,
            paintFill: pass.paintFill,
            paintStroke: pass.paintStroke,
          ),
        )
        .toList(growable: false);

    // Merge shadow passes (first) with original input (on top).
    // This matches the SVG spec behavior where the shadow appears behind.
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
