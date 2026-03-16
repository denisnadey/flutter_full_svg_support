part of 'svg_filters.dart';

extension SvgFiltersInputResolverExtension on SvgFilters {
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
      return previous.isEmpty
          ? <SvgFilterPaintPass>[...sourceGraphic]
          : previous;
    }

    // `in="none"` explicitly requests transparent-black input.
    // It should never fall back to previous output, including merge-node flow.
    if (normalized.toLowerCase() == 'none') {
      return const <SvgFilterPaintPass>[];
    }

    final builtIn = _resolveBuiltInInputPasses(
      normalized,
      sourceGraphic: sourceGraphic,
      sourceAlpha: sourceAlpha,
    );
    if (builtIn != null) {
      return builtIn;
    }

    final named = namedResults[normalized];
    if (named != null && named.isNotEmpty) {
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

    if (fallbackToPreviousOnUnknown) {
      return previous.isEmpty
          ? <SvgFilterPaintPass>[...sourceGraphic]
          : previous;
    }

    // Explicit unresolved primitive inputs should not fall back to previous
    // output when fallback is disabled (e.g. merge node semantics).
    return const <SvgFilterPaintPass>[];
  }

  List<SvgFilterPaintPass>? _resolveBuiltInInputPasses(
    String normalizedInput, {
    required List<SvgFilterPaintPass> sourceGraphic,
    required List<SvgFilterPaintPass> sourceAlpha,
    bool isNormalizedLowerCase = false,
  }) {
    final fillPaint =
        _activeFillPaint ??
        _maskPaintSourcePasses(
          sourceGraphic,
          paintFill: true,
          paintStroke: false,
        );
    final strokePaint =
        _activeStrokePaint ??
        _maskPaintSourcePasses(
          sourceGraphic,
          paintFill: false,
          paintStroke: true,
        );
    final backgroundImage = _activeBackgroundImage ?? sourceGraphic;
    final backgroundAlpha = _activeBackgroundAlpha ?? sourceAlpha;

    switch (normalizedInput) {
      case 'SourceGraphic':
        return <SvgFilterPaintPass>[...sourceGraphic];
      case 'SourceAlpha':
        return <SvgFilterPaintPass>[...sourceAlpha];
      case 'BackgroundImage':
        return <SvgFilterPaintPass>[...backgroundImage];
      case 'BackgroundAlpha':
        return <SvgFilterPaintPass>[...backgroundAlpha];
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
        return <SvgFilterPaintPass>[...backgroundImage];
      case 'backgroundalpha':
        return <SvgFilterPaintPass>[...backgroundAlpha];
      case 'fillpaint':
        return <SvgFilterPaintPass>[...fillPaint];
      case 'strokepaint':
        return <SvgFilterPaintPass>[...strokePaint];
      default:
        return null;
    }
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
