part of 'svg_filters.dart';

/// Internal context for tracking filter pipeline execution state.
class _FilterPipelineContext {
  _FilterPipelineContext({
    required this.sourceGraphic,
    required this.sourceAlpha,
    required this.namedResults,
  });

  final List<SvgFilterPaintPass> sourceGraphic;
  final List<SvgFilterPaintPass> sourceAlpha;

  /// Named results cache - stores computed results for reuse by downstream
  /// primitives without recomputation.
  final Map<String, List<SvgFilterPaintPass>> namedResults;

  /// Track which primitives have been computed to avoid recomputation.
  final Set<String> computedPrimitives = <String>{};
}

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

      // Create pipeline context with shared result cache.
      final context = _FilterPipelineContext(
        sourceGraphic: sourceGraphic,
        sourceAlpha: sourceAlpha,
        namedResults: <String, List<SvgFilterPaintPass>>{},
      );

      var previous = <SvgFilterPaintPass>[...sourceGraphic];

      for (final primitive in list) {
        final output = _resolvePrimitiveOutput(
          primitive: primitive,
          previous: previous,
          namedResults: context.namedResults,
          sourceGraphic: sourceGraphic,
          sourceAlpha: sourceAlpha,
        );

        previous = output;
        final resultName = primitive.resultName?.trim();
        if (resultName != null && resultName.isNotEmpty) {
          // Cache the result for potential reuse by downstream primitives.
          // Use shallow copy to preserve reference sharing while protecting
          // against accidental mutation.
          context.namedResults[resultName] = _cacheNamedResult(output);
          context.computedPrimitives.add(resultName);
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

  /// Cache a named result for reuse by downstream primitives.
  ///
  /// Uses shallow copy to avoid recomputation while maintaining isolation
  /// between different references to the same cached result.
  List<SvgFilterPaintPass> _cacheNamedResult(List<SvgFilterPaintPass> passes) {
    // Return an unmodifiable view to prevent accidental mutation of cached
    // results by downstream consumers.
    return List<SvgFilterPaintPass>.unmodifiable(passes);
  }

}
