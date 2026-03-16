part of 'svg_filters.dart';

extension SvgFiltersPipelineExtension on SvgFilters {
  List<SvgFilterPaintPass> resolvePaintPasses(
    String id, {
    SvgFilterSourceContext? sourceContext,
  }) {
    final list = _filters[id];
    if (list == null || list.isEmpty) {
      return const <SvgFilterPaintPass>[SvgFilterPaintPass.identity];
    }

    final previousFillPaint = _activeFillPaint;
    final previousStrokePaint = _activeStrokePaint;
    final previousBackgroundImage = _activeBackgroundImage;
    final previousBackgroundAlpha = _activeBackgroundAlpha;
    _activeFillPaint = sourceContext?.fillPaint == null
        ? null
        : <SvgFilterPaintPass>[...sourceContext!.fillPaint!];
    _activeStrokePaint = sourceContext?.strokePaint == null
        ? null
        : <SvgFilterPaintPass>[...sourceContext!.strokePaint!];
    _activeBackgroundImage = sourceContext?.backgroundImage == null
        ? null
        : <SvgFilterPaintPass>[...sourceContext!.backgroundImage!];
    _activeBackgroundAlpha = sourceContext?.backgroundAlpha == null
        ? null
        : <SvgFilterPaintPass>[...sourceContext!.backgroundAlpha!];

    try {
      const sourceGraphic = <SvgFilterPaintPass>[SvgFilterPaintPass.identity];
      final sourceAlpha = <SvgFilterPaintPass>[
        const SvgFilterPaintPass(
          colorFilter: ui.ColorFilter.mode(
            ui.Color(0xFFFFFFFF),
            ui.BlendMode.srcIn,
          ),
        ),
      ];

      final namedResults = <String, List<SvgFilterPaintPass>>{};
      var previous = <SvgFilterPaintPass>[...sourceGraphic];

      for (final primitive in list) {
        final output = _resolvePrimitiveOutput(
          primitive: primitive,
          previous: previous,
          namedResults: namedResults,
          sourceGraphic: sourceGraphic,
          sourceAlpha: sourceAlpha,
        );

        previous = output;
        final resultName = primitive.resultName?.trim();
        if (resultName != null && resultName.isNotEmpty) {
          namedResults[resultName] = _clonePaintPasses(output);
        }
      }

      if (previous.isEmpty) {
        return const <SvgFilterPaintPass>[SvgFilterPaintPass.identity];
      }
      return previous;
    } finally {
      _activeFillPaint = previousFillPaint;
      _activeStrokePaint = previousStrokePaint;
      _activeBackgroundImage = previousBackgroundImage;
      _activeBackgroundAlpha = previousBackgroundAlpha;
    }
  }

  List<SvgFilterPaintPass> _clonePaintPasses(List<SvgFilterPaintPass> passes) {
    return passes
        .map(
          (pass) => SvgFilterPaintPass(
            imageFilter: pass.imageFilter,
            colorFilter: pass.colorFilter,
            blendMode: pass.blendMode,
            offset: pass.offset,
            paintFill: pass.paintFill,
            paintStroke: pass.paintStroke,
          ),
        )
        .toList(growable: false);
  }
}
