part of 'svg_filters.dart';

/// Коллекция фильтров в SVG документе
class SvgFilters {
  /// Карта ID фильтра -> список примитивов в порядке объявления.
  final Map<String, List<SvgFilter>> _filters = {};
  List<SvgFilterPaintPass>? _activeFillPaint;
  List<SvgFilterPaintPass>? _activeStrokePaint;
  List<SvgFilterPaintPass>? _activeBackgroundImage;
  List<SvgFilterPaintPass>? _activeBackgroundAlpha;

  /// Stack of nested background contexts for filters inside filtered groups.
  final List<_NestedBackgroundContext> _backgroundContextStack = [];

  /// Current transform matrix for BackgroundImage coordinate mapping.
  Float64List? _activeBackgroundTransform;

  /// Добавить фильтр
  void add(SvgFilter filter) {
    _filters.putIfAbsent(filter.id, () => <SvgFilter>[]).add(filter);
  }

  /// Получить последний примитив фильтра по ID (совместимость с legacy API).
  SvgFilter? getById(String id) {
    final list = _filters[id];
    if (list == null || list.isEmpty) {
      return null;
    }
    return list.last;
  }

  /// Получить все примитивы фильтра по ID в порядке объявления.
  List<SvgFilter> getAllById(String id) {
    final list = _filters[id];
    if (list == null) {
      return const <SvgFilter>[];
    }
    return List<SvgFilter>.unmodifiable(list);
  }

  /// Проверить наличие фильтра
  bool hasFilter(String id) {
    final list = _filters[id];
    return list != null && list.isNotEmpty;
  }

  /// Получить все фильтры (flattened).
  List<SvgFilter> get all =>
      _filters.values.expand((filters) => filters).toList(growable: false);

  /// Push a nested background context for filter-inside-filtered-group scenarios.
  ///
  /// This allows proper BackgroundImage resolution when a filter references
  /// the background of an element that is itself inside a filtered group.
  void pushBackgroundContext({
    List<SvgFilterPaintPass>? backgroundImage,
    List<SvgFilterPaintPass>? backgroundAlpha,
    Float64List? transform,
  }) {
    _backgroundContextStack.add(
      _NestedBackgroundContext(
        backgroundImage: backgroundImage,
        backgroundAlpha: backgroundAlpha,
        transform: transform,
      ),
    );
  }

  /// Pop the most recent nested background context.
  void popBackgroundContext() {
    if (_backgroundContextStack.isNotEmpty) {
      _backgroundContextStack.removeLast();
    }
  }

  /// Get the current effective background image, considering nested contexts.
  List<SvgFilterPaintPass>? get effectiveBackgroundImage {
    if (_activeBackgroundImage != null) {
      return _activeBackgroundImage;
    }
    for (var i = _backgroundContextStack.length - 1; i >= 0; i--) {
      final ctx = _backgroundContextStack[i];
      if (ctx.backgroundImage != null) {
        return ctx.backgroundImage;
      }
    }
    return null;
  }

  /// Get the current effective background alpha, considering nested contexts.
  List<SvgFilterPaintPass>? get effectiveBackgroundAlpha {
    if (_activeBackgroundAlpha != null) {
      return _activeBackgroundAlpha;
    }
    for (var i = _backgroundContextStack.length - 1; i >= 0; i--) {
      final ctx = _backgroundContextStack[i];
      if (ctx.backgroundAlpha != null) {
        return ctx.backgroundAlpha;
      }
    }
    return null;
  }

  /// Get the current background transform, considering nested contexts.
  Float64List? get effectiveBackgroundTransform {
    if (_activeBackgroundTransform != null) {
      return _activeBackgroundTransform;
    }
    for (var i = _backgroundContextStack.length - 1; i >= 0; i--) {
      final ctx = _backgroundContextStack[i];
      if (ctx.transform != null) {
        return ctx.transform;
      }
    }
    return null;
  }
}

/// Internal class for tracking nested background contexts.
class _NestedBackgroundContext {
  const _NestedBackgroundContext({
    this.backgroundImage,
    this.backgroundAlpha,
    this.transform,
  });

  final List<SvgFilterPaintPass>? backgroundImage;
  final List<SvgFilterPaintPass>? backgroundAlpha;
  final Float64List? transform;
}
