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

  List<SvgFilterPaintPass> _resolveDropShadowOutput({
    required SvgDropShadowFilter shadow,
    required List<SvgFilterPaintPass> previous,
    required Map<String, List<SvgFilterPaintPass>> namedResults,
    required List<SvgFilterPaintPass> sourceGraphic,
    required List<SvgFilterPaintPass> sourceAlpha,
  }) {
    final input = _resolvePrimitiveInput(
      requestedInput: shadow.input,
      previous: previous,
      namedResults: namedResults,
      sourceGraphic: sourceGraphic,
      sourceAlpha: sourceAlpha,
    );
    final shadowFilter = shadow.apply();
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
