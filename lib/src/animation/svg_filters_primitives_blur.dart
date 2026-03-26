part of 'svg_filters.dart';

/// Gaussian Blur фильтр
///
/// Использует ImageFilter.blur для размытия.
/// Supports edgeMode per SVG Filter 1.1 spec.
class SvgGaussianBlurFilter extends SvgFilter {
  /// Стандартное отклонение по X (размытие по горизонтали)
  final double stdDeviationX;

  /// Стандартное отклонение по Y (размытие по вертикали)
  final double stdDeviationY;

  /// Edge mode for handling pixels at the filter region boundary.
  /// Per SVG spec:
  /// - duplicate: Clamp to edge pixels (default)
  /// - wrap: Wrap around (tile)
  /// - none: Use transparent black for out-of-bounds
  final SvgConvolveEdgeMode edgeMode;

  SvgGaussianBlurFilter({
    required super.id,
    required this.stdDeviationX,
    required this.stdDeviationY,
    this.edgeMode = SvgConvolveEdgeMode.duplicate,
    super.input,
    super.resultName,
  }) : super(type: SvgFilterType.gaussianBlur);

  @override
  ui.ImageFilter? apply() {
    // Flutter ImageFilter.blur использует sigma (стандартное отклонение)
    // В SVG stdDeviation = sigma
    // Note: Flutter's blur doesn't directly support edgeMode - we handle this
    // via the tile mode in the shader when applicable.
    final tileMode = _edgeModeToTileMode(edgeMode);
    return ui.ImageFilter.blur(
      sigmaX: stdDeviationX,
      sigmaY: stdDeviationY,
      tileMode: tileMode,
    );
  }

  /// Convert SVG edge mode to Flutter TileMode for blur filter.
  ui.TileMode _edgeModeToTileMode(SvgConvolveEdgeMode mode) {
    switch (mode) {
      case SvgConvolveEdgeMode.duplicate:
        return ui.TileMode.clamp;
      case SvgConvolveEdgeMode.wrap:
        return ui.TileMode.repeated;
      case SvgConvolveEdgeMode.none:
        return ui.TileMode.decal;
    }
  }
}

/// Morphology фильтр
///
/// Использует ImageFilter.erode/dilate для базовой SVG feMorphology-поддержки.
/// Supports edgeMode per SVG Filter 1.1 spec.
class SvgMorphologyFilter extends SvgFilter {
  /// Оператор morphology: erode или dilate.
  final SvgMorphologyOperator operatorType;

  /// Радиус по X.
  final double radiusX;

  /// Радиус по Y.
  final double radiusY;

  /// Edge mode for handling pixels at the filter region boundary.
  /// Per SVG spec:
  /// - duplicate: Clamp to edge pixels (default)
  /// - wrap: Wrap around (tile)
  /// - none: Use transparent black for out-of-bounds
  final SvgConvolveEdgeMode edgeMode;

  SvgMorphologyFilter({
    required super.id,
    required this.operatorType,
    required this.radiusX,
    required this.radiusY,
    this.edgeMode = SvgConvolveEdgeMode.duplicate,
    super.input,
    super.resultName,
  }) : super(type: SvgFilterType.morphology);

  @override
  ui.ImageFilter? apply() {
    final clampedX = radiusX.clamp(0.0, 4096.0).toDouble();
    final clampedY = radiusY.clamp(0.0, 4096.0).toDouble();
    if (clampedX <= 0.0 && clampedY <= 0.0) {
      return null;
    }
    // Note: Flutter's erode/dilate filters don't have direct edge mode support.
    // For full Blink parity, custom shader processing would be needed.
    // Current implementation uses default behavior (clamp to edges).
    switch (operatorType) {
      case SvgMorphologyOperator.dilate:
        return ui.ImageFilter.dilate(radiusX: clampedX, radiusY: clampedY);
      case SvgMorphologyOperator.erode:
        return ui.ImageFilter.erode(radiusX: clampedX, radiusY: clampedY);
    }
  }
}
