part of 'svg_filters.dart';

extension SvgFiltersOutputResolversExtension on SvgFilters {
  /// Скомпоновать ImageFilter цепочку для filter id.
  ui.ImageFilter? resolveImageFilter(String id) {
    final passes = resolvePaintPasses(id);
    for (final pass in passes) {
      if (pass.imageFilter != null) {
        return pass.imageFilter;
      }
    }
    return null;
  }

  /// Получить итоговый ColorFilter для цепочки (последний цветовой примитив).
  ui.ColorFilter? resolveColorFilter(String id) {
    final passes = resolvePaintPasses(id);
    ui.ColorFilter? result;
    for (final pass in passes) {
      final colorFilter = pass.colorFilter;
      if (colorFilter != null) {
        result = colorFilter;
      }
    }
    return result;
  }

  /// Получить итоговый blend mode для цепочки (последний режим композиции).
  ui.BlendMode? resolveBlendMode(String id) {
    final passes = resolvePaintPasses(id);
    ui.BlendMode? result;
    for (final pass in passes) {
      final mode = pass.blendMode;
      if (mode != null) {
        result = mode;
      }
    }
    return result;
  }
}
