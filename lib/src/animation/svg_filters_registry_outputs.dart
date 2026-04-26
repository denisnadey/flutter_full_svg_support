part of 'svg_filters.dart';

extension SvgFiltersOutputResolversExtension on SvgFilters {
  /// Compose the ImageFilter chain for a filter id.
  ui.ImageFilter? resolveImageFilter(String id) {
    final passes = resolvePaintPasses(id);
    for (final pass in passes) {
      if (pass.imageFilter != null) {
        return pass.imageFilter;
      }
    }
    return null;
  }

  /// Get the final ColorFilter for the chain (the last color primitive).
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

  /// Get the final blend mode for the chain (the last composition mode).
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
