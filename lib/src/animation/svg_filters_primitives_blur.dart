part of 'svg_filters.dart';

/// Maximum reasonable stdDeviation for Gaussian blur.
/// Beyond this, we use iterative box blur approximation per Blink behavior.
const double _maxGaussianBlurStdDeviation = 50.0;

/// Maximum kernel radius to prevent excessive memory allocation.
/// A kernel radius of 256 pixels is already very large.
const int _maxBlurKernelRadius = 256;

/// Gaussian Blur фильтр
///
/// Использует ImageFilter.blur для размытия.
/// Supports edgeMode per SVG Filter 1.1 spec.
/// For extreme stdDeviation values (>50), uses iterative box blur approximation.
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

  /// Whether stdDeviation=0 (passthrough, no blur).
  bool get isPassthrough => stdDeviationX <= 0.0 && stdDeviationY <= 0.0;

  /// Whether this blur requires the iterative box blur approximation.
  /// Used for large stdDeviation values to prevent performance issues.
  bool get requiresBoxBlurApproximation =>
      stdDeviationX > _maxGaussianBlurStdDeviation ||
      stdDeviationY > _maxGaussianBlurStdDeviation;

  /// Gets the clamped stdDeviation values.
  /// Caps at _maxGaussianBlurStdDeviation for the standard blur filter.
  (double, double) get clampedStdDeviation => (
    stdDeviationX.clamp(0.0, _maxGaussianBlurStdDeviation),
    stdDeviationY.clamp(0.0, _maxGaussianBlurStdDeviation),
  );

  @override
  ui.ImageFilter? apply() {
    // stdDeviation=0 means passthrough (no blur)
    if (isPassthrough) {
      return null;
    }

    // For very large blur values, cap at maximum to prevent performance issues.
    // The GaussianBlurProcessor handles the actual large blur via box blur approx.
    final (sigmaX, sigmaY) = clampedStdDeviation;

    // Flutter ImageFilter.blur использует sigma (стандартное отклонение)
    // В SVG stdDeviation = sigma
    // Note: Flutter's blur doesn't directly support edgeMode - we handle this
    // via the tile mode in the shader when applicable.
    final tileMode = _edgeModeToTileMode(edgeMode);
    return ui.ImageFilter.blur(
      sigmaX: sigmaX,
      sigmaY: sigmaY,
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

/// Utility class for performing Gaussian blur with proper edge handling.
///
/// Handles extreme stdDeviation values (>50) using iterative box blur
/// approximation (3-pass box blur ≈ Gaussian per Blink behavior).
class GaussianBlurProcessor {
  const GaussianBlurProcessor._();

  /// Applies Gaussian blur to RGBA pixel data.
  ///
  /// For large stdDeviation values, uses 3-pass box blur approximation
  /// which is faster and matches Blink behavior.
  ///
  /// [pixels] - Source RGBA pixel data (4 bytes per pixel).
  /// [width] - Image width in pixels.
  /// [height] - Image height in pixels.
  /// [stdDeviationX] - Blur standard deviation in X.
  /// [stdDeviationY] - Blur standard deviation in Y.
  /// [edgeMode] - How to handle pixels outside image bounds.
  ///
  /// Returns new RGBA pixel data with blur applied.
  static Uint8List applyBlur({
    required Uint8List pixels,
    required int width,
    required int height,
    required double stdDeviationX,
    required double stdDeviationY,
    required SvgConvolveEdgeMode edgeMode,
  }) {
    if (width <= 0 || height <= 0) {
      return pixels;
    }

    // stdDeviation=0 means passthrough
    if (stdDeviationX <= 0.0 && stdDeviationY <= 0.0) {
      return pixels;
    }

    // Use box blur approximation for large values
    if (stdDeviationX > _maxGaussianBlurStdDeviation ||
        stdDeviationY > _maxGaussianBlurStdDeviation) {
      return _applyBoxBlurApproximation(
        pixels: pixels,
        width: width,
        height: height,
        stdDeviationX: stdDeviationX,
        stdDeviationY: stdDeviationY,
        edgeMode: edgeMode,
      );
    }

    // Standard Gaussian blur for reasonable values
    return _applyGaussianBlur(
      pixels: pixels,
      width: width,
      height: height,
      stdDeviationX: stdDeviationX,
      stdDeviationY: stdDeviationY,
      edgeMode: edgeMode,
    );
  }

  /// Applies standard Gaussian blur using separable convolution.
  static Uint8List _applyGaussianBlur({
    required Uint8List pixels,
    required int width,
    required int height,
    required double stdDeviationX,
    required double stdDeviationY,
    required SvgConvolveEdgeMode edgeMode,
  }) {
    var result = Uint8List.fromList(pixels);

    // Horizontal pass
    if (stdDeviationX > 0) {
      final kernel = _createGaussianKernel(stdDeviationX);
      result = _applyHorizontalConvolution(
        result,
        width,
        height,
        kernel,
        edgeMode,
      );
    }

    // Vertical pass
    if (stdDeviationY > 0) {
      final kernel = _createGaussianKernel(stdDeviationY);
      result = _applyVerticalConvolution(
        result,
        width,
        height,
        kernel,
        edgeMode,
      );
    }

    return result;
  }

  /// Applies 3-pass box blur approximation for large blur values.
  ///
  /// Per Blink behavior, 3 consecutive box blurs approximate a Gaussian.
  /// Box blur radius = sqrt((12 * sigma^2 / n) + 1) / 2 where n=3 passes.
  static Uint8List _applyBoxBlurApproximation({
    required Uint8List pixels,
    required int width,
    required int height,
    required double stdDeviationX,
    required double stdDeviationY,
    required SvgConvolveEdgeMode edgeMode,
  }) {
    // Calculate box blur radius for 3-pass approximation
    // wIdeal = sqrt((12*sigma²/n)+1) where n=3
    final radiusX = _calculateBoxBlurRadius(stdDeviationX);
    final radiusY = _calculateBoxBlurRadius(stdDeviationY);

    var result = Uint8List.fromList(pixels);

    // Apply 3 passes of box blur
    for (var pass = 0; pass < 3; pass++) {
      if (radiusX > 0) {
        result = _applyHorizontalBoxBlur(
          result,
          width,
          height,
          radiusX,
          edgeMode,
        );
      }
      if (radiusY > 0) {
        result = _applyVerticalBoxBlur(
          result,
          width,
          height,
          radiusY,
          edgeMode,
        );
      }
    }

    return result;
  }

  /// Calculates box blur radius for Gaussian approximation.
  static int _calculateBoxBlurRadius(double stdDeviation) {
    if (stdDeviation <= 0) return 0;
    // For 3-pass box blur: wIdeal = sqrt((12*sigma²/3)+1)
    final wIdeal = math.sqrt((12 * stdDeviation * stdDeviation / 3) + 1);
    return math.min((wIdeal ~/ 2), _maxBlurKernelRadius);
  }

  /// Creates a 1D Gaussian kernel.
  static List<double> _createGaussianKernel(double sigma) {
    final radius = math.min((sigma * 3).ceil(), _maxBlurKernelRadius);
    final size = radius * 2 + 1;
    final kernel = List<double>.filled(size, 0.0);

    final twoSigmaSquare = 2 * sigma * sigma;
    var sum = 0.0;

    for (var i = -radius; i <= radius; i++) {
      final value = math.exp(-(i * i) / twoSigmaSquare);
      kernel[i + radius] = value;
      sum += value;
    }

    // Normalize
    for (var i = 0; i < size; i++) {
      kernel[i] /= sum;
    }

    return kernel;
  }

  /// Applies horizontal convolution with the given kernel.
  static Uint8List _applyHorizontalConvolution(
    Uint8List pixels,
    int width,
    int height,
    List<double> kernel,
    SvgConvolveEdgeMode edgeMode,
  ) {
    final result = Uint8List(pixels.length);
    final radius = kernel.length ~/ 2;

    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        var r = 0.0, g = 0.0, b = 0.0, a = 0.0;

        for (var k = -radius; k <= radius; k++) {
          final srcX = _getCoordWithEdgeMode(x + k, width, edgeMode);
          if (srcX < 0) continue; // Skip for 'none' mode

          final srcIndex = (y * width + srcX) * 4;
          final weight = kernel[k + radius];
          r += pixels[srcIndex] * weight;
          g += pixels[srcIndex + 1] * weight;
          b += pixels[srcIndex + 2] * weight;
          a += pixels[srcIndex + 3] * weight;
        }

        final dstIndex = (y * width + x) * 4;
        result[dstIndex] = r.round().clamp(0, 255);
        result[dstIndex + 1] = g.round().clamp(0, 255);
        result[dstIndex + 2] = b.round().clamp(0, 255);
        result[dstIndex + 3] = a.round().clamp(0, 255);
      }
    }

    return result;
  }

  /// Applies vertical convolution with the given kernel.
  static Uint8List _applyVerticalConvolution(
    Uint8List pixels,
    int width,
    int height,
    List<double> kernel,
    SvgConvolveEdgeMode edgeMode,
  ) {
    final result = Uint8List(pixels.length);
    final radius = kernel.length ~/ 2;

    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        var r = 0.0, g = 0.0, b = 0.0, a = 0.0;

        for (var k = -radius; k <= radius; k++) {
          final srcY = _getCoordWithEdgeMode(y + k, height, edgeMode);
          if (srcY < 0) continue; // Skip for 'none' mode

          final srcIndex = (srcY * width + x) * 4;
          final weight = kernel[k + radius];
          r += pixels[srcIndex] * weight;
          g += pixels[srcIndex + 1] * weight;
          b += pixels[srcIndex + 2] * weight;
          a += pixels[srcIndex + 3] * weight;
        }

        final dstIndex = (y * width + x) * 4;
        result[dstIndex] = r.round().clamp(0, 255);
        result[dstIndex + 1] = g.round().clamp(0, 255);
        result[dstIndex + 2] = b.round().clamp(0, 255);
        result[dstIndex + 3] = a.round().clamp(0, 255);
      }
    }

    return result;
  }

  /// Applies horizontal box blur.
  static Uint8List _applyHorizontalBoxBlur(
    Uint8List pixels,
    int width,
    int height,
    int radius,
    SvgConvolveEdgeMode edgeMode,
  ) {
    final result = Uint8List(pixels.length);
    final kernelSize = radius * 2 + 1;
    final invKernelSize = 1.0 / kernelSize;

    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        var r = 0, g = 0, b = 0, a = 0;

        for (var k = -radius; k <= radius; k++) {
          final srcX = _getCoordWithEdgeMode(x + k, width, edgeMode);
          if (srcX < 0) continue;

          final srcIndex = (y * width + srcX) * 4;
          r += pixels[srcIndex];
          g += pixels[srcIndex + 1];
          b += pixels[srcIndex + 2];
          a += pixels[srcIndex + 3];
        }

        final dstIndex = (y * width + x) * 4;
        result[dstIndex] = (r * invKernelSize).round().clamp(0, 255);
        result[dstIndex + 1] = (g * invKernelSize).round().clamp(0, 255);
        result[dstIndex + 2] = (b * invKernelSize).round().clamp(0, 255);
        result[dstIndex + 3] = (a * invKernelSize).round().clamp(0, 255);
      }
    }

    return result;
  }

  /// Applies vertical box blur.
  static Uint8List _applyVerticalBoxBlur(
    Uint8List pixels,
    int width,
    int height,
    int radius,
    SvgConvolveEdgeMode edgeMode,
  ) {
    final result = Uint8List(pixels.length);
    final kernelSize = radius * 2 + 1;
    final invKernelSize = 1.0 / kernelSize;

    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        var r = 0, g = 0, b = 0, a = 0;

        for (var k = -radius; k <= radius; k++) {
          final srcY = _getCoordWithEdgeMode(y + k, height, edgeMode);
          if (srcY < 0) continue;

          final srcIndex = (srcY * width + x) * 4;
          r += pixels[srcIndex];
          g += pixels[srcIndex + 1];
          b += pixels[srcIndex + 2];
          a += pixels[srcIndex + 3];
        }

        final dstIndex = (y * width + x) * 4;
        result[dstIndex] = (r * invKernelSize).round().clamp(0, 255);
        result[dstIndex + 1] = (g * invKernelSize).round().clamp(0, 255);
        result[dstIndex + 2] = (b * invKernelSize).round().clamp(0, 255);
        result[dstIndex + 3] = (a * invKernelSize).round().clamp(0, 255);
      }
    }

    return result;
  }

  /// Gets coordinate with edge mode handling.
  /// Returns -1 for 'none' mode when out of bounds.
  static int _getCoordWithEdgeMode(
    int coord,
    int size,
    SvgConvolveEdgeMode edgeMode,
  ) {
    if (coord >= 0 && coord < size) return coord;

    switch (edgeMode) {
      case SvgConvolveEdgeMode.duplicate:
        return coord.clamp(0, size - 1);
      case SvgConvolveEdgeMode.wrap:
        var wrapped = coord % size;
        if (wrapped < 0) wrapped += size;
        return wrapped;
      case SvgConvolveEdgeMode.none:
        return -1; // Signal to skip this sample
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
