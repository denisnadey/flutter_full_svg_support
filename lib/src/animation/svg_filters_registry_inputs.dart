part of 'svg_filters.dart';

extension SvgFiltersInputResolverExtension on SvgFilters {
  /// Resolves input passes for a filter primitive.
  ///
  /// This method handles the full SVG filter input resolution semantics:
  /// - Built-in inputs: SourceGraphic, SourceAlpha, BackgroundImage,
  ///   BackgroundAlpha, FillPaint, StrokePaint
  /// - Named results from previous primitives via `result` attribute
  /// - Default input resolution (previous output or SourceGraphic)
  /// - Forward reference handling (produces transparent black per spec)
  /// - Multi-hop chain resolution (A→B→C references)
  /// - Nested filter context handling for BackgroundImage
  List<SvgFilterPaintPass> _resolveInputPasses({
    required String? requestedInput,
    required List<SvgFilterPaintPass> previous,
    required Map<String, List<SvgFilterPaintPass>> namedResults,
    required List<SvgFilterPaintPass> sourceGraphic,
    required List<SvgFilterPaintPass> sourceAlpha,
    bool fallbackToPreviousOnUnknown = false,
  }) {
    final normalized = requestedInput?.trim();
    if (normalized == null || normalized.isEmpty) {
      // Per SVG spec: when `in` is omitted, use the result of the previous
      // primitive, or SourceGraphic for the first primitive.
      return previous.isEmpty
          ? <SvgFilterPaintPass>[...sourceGraphic]
          : previous;
    }

    // `in="none"` explicitly requests transparent-black input.
    // It should never fall back to previous output, including merge-node flow.
    if (normalized.toLowerCase() == 'none') {
      return const <SvgFilterPaintPass>[];
    }

    // Try built-in inputs first (case-sensitive per spec).
    final builtIn = _resolveBuiltInInputPasses(
      normalized,
      sourceGraphic: sourceGraphic,
      sourceAlpha: sourceAlpha,
    );
    if (builtIn != null) {
      return builtIn;
    }

    // Try named results from previous primitives.
    // This enables filter chains like: blur result="blurred" -> composite in="blurred"
    // Also supports multi-hop chains: A→B→C where C references A's result.
    final named = namedResults[normalized];
    if (named != null && named.isNotEmpty) {
      // Return a copy to prevent accidental mutation of cached results.
      return <SvgFilterPaintPass>[...named];
    }

    // Built-in inputs are accepted case-insensitively for baseline parity.
    final builtInCaseInsensitive = _resolveBuiltInInputPasses(
      normalized.toLowerCase(),
      sourceGraphic: sourceGraphic,
      sourceAlpha: sourceAlpha,
      isNormalizedLowerCase: true,
    );
    if (builtInCaseInsensitive != null) {
      return builtInCaseInsensitive;
    }

    // Handle fallback for unknown references.
    if (fallbackToPreviousOnUnknown) {
      return previous.isEmpty
          ? <SvgFilterPaintPass>[...sourceGraphic]
          : previous;
    }

    // Explicit unresolved primitive inputs (including forward references)
    // should produce transparent black per SVG spec.
    return const <SvgFilterPaintPass>[];
  }

  List<SvgFilterPaintPass>? _resolveBuiltInInputPasses(
    String normalizedInput, {
    required List<SvgFilterPaintPass> sourceGraphic,
    required List<SvgFilterPaintPass> sourceAlpha,
    bool isNormalizedLowerCase = false,
  }) {
    // Use _createFillPaintInput and _createStrokePaintInput for proper handling
    // of pattern fills, gradient fills with objectBoundingBox, and inherited paint.
    final fillPaint = _activeFillPaint ?? _createFillPaintInput(sourceGraphic);
    final strokePaint =
        _activeStrokePaint ?? _createStrokePaintInput(sourceGraphic);

    // Use effective background methods for nested filter context support.
    final backgroundImage = effectiveBackgroundImage ?? sourceGraphic;
    final backgroundAlpha = effectiveBackgroundAlpha ?? sourceAlpha;

    switch (normalizedInput) {
      case 'SourceGraphic':
        return <SvgFilterPaintPass>[...sourceGraphic];
      case 'SourceAlpha':
        return <SvgFilterPaintPass>[...sourceAlpha];
      case 'BackgroundImage':
        return _resolveBackgroundImageInput(backgroundImage);
      case 'BackgroundAlpha':
        return _resolveBackgroundAlphaInput(backgroundAlpha);
      case 'FillPaint':
        return <SvgFilterPaintPass>[...fillPaint];
      case 'StrokePaint':
        return <SvgFilterPaintPass>[...strokePaint];
    }

    if (!isNormalizedLowerCase) {
      return null;
    }

    switch (normalizedInput) {
      case 'sourcegraphic':
        return <SvgFilterPaintPass>[...sourceGraphic];
      case 'sourcealpha':
        return <SvgFilterPaintPass>[...sourceAlpha];
      case 'backgroundimage':
        return _resolveBackgroundImageInput(backgroundImage);
      case 'backgroundalpha':
        return _resolveBackgroundAlphaInput(backgroundAlpha);
      case 'fillpaint':
        return <SvgFilterPaintPass>[...fillPaint];
      case 'strokepaint':
        return <SvgFilterPaintPass>[...strokePaint];
      default:
        return null;
    }
  }

  /// Create FillPaint input with proper handling of pattern fills,
  /// gradient fills with objectBoundingBox, and inherited fill.
  List<SvgFilterPaintPass> _createFillPaintInput(
    List<SvgFilterPaintPass> source,
  ) {
    return _maskPaintSourcePasses(source, paintFill: true, paintStroke: false);
  }

  /// Create StrokePaint input with proper handling of pattern strokes,
  /// gradient strokes with objectBoundingBox, and inherited stroke.
  List<SvgFilterPaintPass> _createStrokePaintInput(
    List<SvgFilterPaintPass> source,
  ) {
    return _maskPaintSourcePasses(source, paintFill: false, paintStroke: true);
  }

  /// Resolve BackgroundImage input with transform handling.
  ///
  /// When filters are nested or BackgroundImage is referenced with
  /// non-identity transforms, this method applies the appropriate
  /// coordinate space transformation.
  List<SvgFilterPaintPass> _resolveBackgroundImageInput(
    List<SvgFilterPaintPass> backgroundImage,
  ) {
    final transform = effectiveBackgroundTransform;
    if (transform == null) {
      return <SvgFilterPaintPass>[...backgroundImage];
    }

    // Apply transform to background image passes for proper coordinate mapping.
    return backgroundImage
        .map(
          (pass) => pass.copyWith(
            imageFilter: _composeImageFilter(
              ui.ImageFilter.matrix(transform),
              pass.imageFilter,
            ),
          ),
        )
        .toList(growable: false);
  }

  /// Resolve BackgroundAlpha input with transform handling.
  List<SvgFilterPaintPass> _resolveBackgroundAlphaInput(
    List<SvgFilterPaintPass> backgroundAlpha,
  ) {
    final transform = effectiveBackgroundTransform;
    if (transform == null) {
      return <SvgFilterPaintPass>[...backgroundAlpha];
    }

    // Apply transform to background alpha passes.
    return backgroundAlpha
        .map(
          (pass) => pass.copyWith(
            imageFilter: _composeImageFilter(
              ui.ImageFilter.matrix(transform),
              pass.imageFilter,
            ),
          ),
        )
        .toList(growable: false);
  }

  List<SvgFilterPaintPass> _maskPaintSourcePasses(
    List<SvgFilterPaintPass> source, {
    required bool paintFill,
    required bool paintStroke,
  }) {
    return source
        .map(
          (pass) =>
              pass.copyWith(paintFill: paintFill, paintStroke: paintStroke),
        )
        .toList(growable: false);
  }

  ui.ImageFilter? _composeImageFilter(
    ui.ImageFilter? outer,
    ui.ImageFilter? inner,
  ) {
    if (outer == null) return inner;
    if (inner == null) return outer;
    return ui.ImageFilter.compose(outer: outer, inner: inner);
  }
}
