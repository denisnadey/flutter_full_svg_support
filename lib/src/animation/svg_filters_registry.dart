part of 'svg_filters.dart';

/// Коллекция фильтров в SVG документе
class SvgFilters {
  /// Карта ID фильтра -> список примитивов в порядке объявления.
  final Map<String, List<SvgFilter>> _filters = {};
  List<SvgFilterPaintPass>? _activeFillPaint;
  List<SvgFilterPaintPass>? _activeStrokePaint;
  List<SvgFilterPaintPass>? _activeBackgroundImage;
  List<SvgFilterPaintPass>? _activeBackgroundAlpha;

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
}
