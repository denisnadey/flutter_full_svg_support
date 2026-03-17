part of 'svg_filters.dart';

/// Internal context for tracking filter pipeline execution state.
///
/// This context manages the filter graph resolution including:
/// - Named result caching for multi-hop chains (A→B→C references)
/// - Circular reference detection via resolution depth tracking
/// - Background/paint context propagation for nested filters
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

  /// Maximum resolution depth to prevent stack overflow on circular references.
  static const int maxResolutionDepth = 64;

  /// Current resolution depth for detecting deep chains.
  int _currentDepth = 0;

  /// Track currently resolving references to detect circular dependencies.
  final Set<String> _resolvingReferences = <String>{};

  /// Begin resolving a named reference. Returns false if circular.
  bool beginResolve(String name) {
    if (_resolvingReferences.contains(name)) {
      return false; // Circular reference detected
    }
    if (_currentDepth >= maxResolutionDepth) {
      return false; // Maximum depth exceeded
    }
    _resolvingReferences.add(name);
    _currentDepth++;
    return true;
  }

  /// End resolving a named reference.
  void endResolve(String name) {
    _resolvingReferences.remove(name);
    if (_currentDepth > 0) _currentDepth--;
  }

  /// Check if a reference would cause circular dependency.
  bool wouldCauseCircular(String name) {
    return _resolvingReferences.contains(name);
  }
}

extension SvgFiltersPipelineExtension on SvgFilters {
  /// Resolves a filter chain to a list of paint passes.
  ///
  /// This method processes all primitives in the filter chain, handling:
  /// - Named result caching for multi-hop chains (A→B→C references)
  /// - Implicit input chaining (previous result fallback)
  /// - Forward reference handling (transparent black per SVG spec)
  /// - Circular reference detection via resolution tracking
  ///
  /// Per SVG spec:
  /// - When `in` is omitted, use the previous primitive's result
  /// - For the first primitive, omitted `in` means SourceGraphic
  /// - Forward references produce transparent black
  /// - Circular references are detected and produce transparent black
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
        // Detect circular references by checking if we're re-entering
        // a primitive that's currently being resolved.
        final resultName = primitive.resultName?.trim();
        final isCircular =
            resultName != null &&
            resultName.isNotEmpty &&
            context.wouldCauseCircular(resultName);

        if (isCircular) {
          // Circular reference detected - produce transparent black per spec.
          previous = const <SvgFilterPaintPass>[];
          continue;
        }

        // Mark this primitive as being resolved for circular detection.
        if (resultName != null && resultName.isNotEmpty) {
          context.beginResolve(resultName);
        }

        try {
          final output = _resolvePrimitiveOutput(
            primitive: primitive,
            previous: previous,
            namedResults: context.namedResults,
            sourceGraphic: sourceGraphic,
            sourceAlpha: sourceAlpha,
          );

          previous = output;

          if (resultName != null && resultName.isNotEmpty) {
            // Cache the result for potential reuse by downstream primitives.
            // Use shallow copy to preserve reference sharing while protecting
            // against accidental mutation.
            context.namedResults[resultName] = _cacheNamedResult(output);
            context.computedPrimitives.add(resultName);
          }
        } finally {
          // End resolution tracking for this primitive.
          if (resultName != null && resultName.isNotEmpty) {
            context.endResolve(resultName);
          }
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
