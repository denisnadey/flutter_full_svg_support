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

/// Utility class for performing morphology operations with proper edge handling.
///
/// Implements SVG feMorphology algorithm for pixel-level erosion and dilation
/// with support for all edge modes (duplicate, wrap, none).
class MorphologyProcessor {
  const MorphologyProcessor._();

  /// Applies morphology operation (erode or dilate) to RGBA pixel data.
  ///
  /// [pixels] - Source RGBA pixel data (4 bytes per pixel).
  /// [width] - Image width in pixels.
  /// [height] - Image height in pixels.
  /// [radiusX] - Horizontal radius of the morphology kernel.
  /// [radiusY] - Vertical radius of the morphology kernel.
  /// [operatorType] - Either erode (min) or dilate (max).
  /// [edgeMode] - How to handle pixels outside image bounds.
  ///
  /// Returns new RGBA pixel data with morphology applied.
  static Uint8List applyMorphology({
    required Uint8List pixels,
    required int width,
    required int height,
    required double radiusX,
    required double radiusY,
    required SvgMorphologyOperator operatorType,
    required SvgConvolveEdgeMode edgeMode,
  }) {
    if (width <= 0 || height <= 0) {
      return pixels;
    }

    final rx = radiusX.round().clamp(0, width);
    final ry = radiusY.round().clamp(0, height);
    if (rx <= 0 && ry <= 0) {
      return pixels;
    }

    final result = Uint8List(pixels.length);
    final isDilate = operatorType == SvgMorphologyOperator.dilate;

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        // Initialize with extreme values for min/max operation
        int resultR = isDilate ? 0 : 255;
        int resultG = isDilate ? 0 : 255;
        int resultB = isDilate ? 0 : 255;
        int resultA = isDilate ? 0 : 255;

        // Scan the kernel area
        for (int ky = -ry; ky <= ry; ky++) {
          for (int kx = -rx; kx <= rx; kx++) {
            final srcX = x + kx;
            final srcY = y + ky;

            // Get pixel based on edge mode
            final pixelValues = _getPixelWithEdgeMode(
              pixels,
              width,
              height,
              srcX,
              srcY,
              edgeMode,
            );

            if (isDilate) {
              // Max operation for dilate
              if (pixelValues[0] > resultR) resultR = pixelValues[0];
              if (pixelValues[1] > resultG) resultG = pixelValues[1];
              if (pixelValues[2] > resultB) resultB = pixelValues[2];
              if (pixelValues[3] > resultA) resultA = pixelValues[3];
            } else {
              // Min operation for erode
              if (pixelValues[0] < resultR) resultR = pixelValues[0];
              if (pixelValues[1] < resultG) resultG = pixelValues[1];
              if (pixelValues[2] < resultB) resultB = pixelValues[2];
              if (pixelValues[3] < resultA) resultA = pixelValues[3];
            }
          }
        }

        final dstIndex = (y * width + x) * 4;
        result[dstIndex] = resultR;
        result[dstIndex + 1] = resultG;
        result[dstIndex + 2] = resultB;
        result[dstIndex + 3] = resultA;
      }
    }

    return result;
  }

  /// Gets pixel RGBA values with edge mode handling.
  static List<int> _getPixelWithEdgeMode(
    Uint8List pixels,
    int width,
    int height,
    int x,
    int y,
    SvgConvolveEdgeMode edgeMode,
  ) {
    switch (edgeMode) {
      case SvgConvolveEdgeMode.duplicate:
        // Clamp coordinates to valid range
        final clampedX = x.clamp(0, width - 1);
        final clampedY = y.clamp(0, height - 1);
        final index = (clampedY * width + clampedX) * 4;
        return <int>[
          pixels[index],
          pixels[index + 1],
          pixels[index + 2],
          pixels[index + 3],
        ];

      case SvgConvolveEdgeMode.wrap:
        // Wrap coordinates around
        var wrappedX = x % width;
        var wrappedY = y % height;
        if (wrappedX < 0) wrappedX += width;
        if (wrappedY < 0) wrappedY += height;
        final index = (wrappedY * width + wrappedX) * 4;
        return <int>[
          pixels[index],
          pixels[index + 1],
          pixels[index + 2],
          pixels[index + 3],
        ];

      case SvgConvolveEdgeMode.none:
        // Return transparent black for out-of-bounds
        if (x < 0 || x >= width || y < 0 || y >= height) {
          return const <int>[0, 0, 0, 0];
        }
        final index = (y * width + x) * 4;
        return <int>[
          pixels[index],
          pixels[index + 1],
          pixels[index + 2],
          pixels[index + 3],
        ];
    }
  }
}

/// Extended paint pass that includes morphology parameters for edge mode support.
///
/// When [morphologyFilter] is non-null, the painter should apply morphology
/// with proper edge handling to the rendered content.
class SvgMorphologyPaintPass extends SvgFilterPaintPass {
  const SvgMorphologyPaintPass({
    super.imageFilter,
    super.colorFilter,
    super.blendMode,
    super.offset,
    super.paintFill,
    super.paintStroke,
    required this.morphologyFilter,
  });

  /// The morphology filter parameters to apply.
  final SvgMorphologyFilter morphologyFilter;

  @override
  SvgFilterPaintPass copyWith({
    ui.ImageFilter? imageFilter,
    ui.ColorFilter? colorFilter,
    ui.BlendMode? blendMode,
    ui.Offset? offset,
    bool? paintFill,
    bool? paintStroke,
  }) {
    return SvgMorphologyPaintPass(
      imageFilter: imageFilter ?? this.imageFilter,
      colorFilter: colorFilter ?? this.colorFilter,
      blendMode: blendMode ?? this.blendMode,
      offset: offset ?? this.offset,
      paintFill: paintFill ?? this.paintFill,
      paintStroke: paintStroke ?? this.paintStroke,
      morphologyFilter: morphologyFilter,
    );
  }
}
