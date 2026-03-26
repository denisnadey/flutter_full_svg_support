part of 'svg_filters.dart';

/// Utility class for performing convolution on image data.
///
/// Implements the SVG feConvolveMatrix algorithm for pixel-level kernel
/// convolution with support for all edge modes, preserveAlpha, and kernelUnitLength.
class ConvolveMatrixProcessor {
  const ConvolveMatrixProcessor._();

  /// Applies convolution kernel to RGBA pixel data.
  ///
  /// [pixels] - Source RGBA pixel data (4 bytes per pixel).
  /// [width] - Image width in pixels.
  /// [height] - Image height in pixels.
  /// [kernel] - Convolution kernel values in row-major order.
  /// [orderX] - Kernel width.
  /// [orderY] - Kernel height.
  /// [targetX] - X position of kernel center (0-based).
  /// [targetY] - Y position of kernel center (0-based).
  /// [divisor] - Normalization factor.
  /// [bias] - Value added after division.
  /// [edgeMode] - How to handle pixels outside image bounds.
  /// [preserveAlpha] - If true, alpha channel is not convolved.
  /// [kernelUnitLengthX] - Optional X scale for kernel coordinates.
  /// [kernelUnitLengthY] - Optional Y scale for kernel coordinates.
  ///
  /// Returns new RGBA pixel data with convolution applied.
  static Uint8List applyConvolution({
    required Uint8List pixels,
    required int width,
    required int height,
    required List<double> kernel,
    required int orderX,
    required int orderY,
    required int targetX,
    required int targetY,
    required double divisor,
    required double bias,
    required SvgConvolveEdgeMode edgeMode,
    required bool preserveAlpha,
    double? kernelUnitLengthX,
    double? kernelUnitLengthY,
  }) {
    if (width <= 0 || height <= 0) {
      return pixels;
    }
    if (kernel.isEmpty || orderX <= 0 || orderY <= 0) {
      return pixels;
    }
    if (kernel.length != orderX * orderY) {
      return pixels;
    }

    final result = Uint8List(pixels.length);
    final bias255 = (bias * 255.0).roundToDouble();
    final invDivisor = divisor != 0 ? 1.0 / divisor : 1.0;

    // Calculate effective kernel step based on kernelUnitLength
    // When kernelUnitLength is specified, the kernel samples are spread out
    // by that factor in user space
    final stepX = (kernelUnitLengthX != null && kernelUnitLengthX > 0)
        ? kernelUnitLengthX
        : 1.0;
    final stepY = (kernelUnitLengthY != null && kernelUnitLengthY > 0)
        ? kernelUnitLengthY
        : 1.0;

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        double sumR = 0.0;
        double sumG = 0.0;
        double sumB = 0.0;
        double sumA = 0.0;

        // Apply kernel with kernelUnitLength scaling
        for (int ky = 0; ky < orderY; ky++) {
          for (int kx = 0; kx < orderX; kx++) {
            // Calculate source pixel position with kernelUnitLength scaling
            // Kernel is applied with targetX/targetY as the center
            final srcX = (x + (kx - targetX) * stepX).round();
            final srcY = (y + (ky - targetY) * stepY).round();

            // Get pixel based on edge mode
            final pixelValues = _getPixelWithEdgeMode(
              pixels,
              width,
              height,
              srcX,
              srcY,
              edgeMode,
            );

            final kernelValue = kernel[ky * orderX + kx];
            sumR += pixelValues[0] * kernelValue;
            sumG += pixelValues[1] * kernelValue;
            sumB += pixelValues[2] * kernelValue;
            sumA += pixelValues[3] * kernelValue;
          }
        }

        // Apply divisor and bias
        final outR = (sumR * invDivisor + bias255).clamp(0.0, 255.0).round();
        final outG = (sumG * invDivisor + bias255).clamp(0.0, 255.0).round();
        final outB = (sumB * invDivisor + bias255).clamp(0.0, 255.0).round();

        final dstIndex = (y * width + x) * 4;
        result[dstIndex] = outR;
        result[dstIndex + 1] = outG;
        result[dstIndex + 2] = outB;

        if (preserveAlpha) {
          // Copy original alpha
          result[dstIndex + 3] = pixels[dstIndex + 3];
        } else {
          final outA = (sumA * invDivisor + bias255).clamp(0.0, 255.0).round();
          result[dstIndex + 3] = outA;
        }
      }
    }

    return result;
  }

  /// Gets pixel RGBA values with edge mode handling.
  static List<double> _getPixelWithEdgeMode(
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
        return <double>[
          pixels[index].toDouble(),
          pixels[index + 1].toDouble(),
          pixels[index + 2].toDouble(),
          pixels[index + 3].toDouble(),
        ];

      case SvgConvolveEdgeMode.wrap:
        // Wrap coordinates around
        var wrappedX = x % width;
        var wrappedY = y % height;
        if (wrappedX < 0) wrappedX += width;
        if (wrappedY < 0) wrappedY += height;
        final index = (wrappedY * width + wrappedX) * 4;
        return <double>[
          pixels[index].toDouble(),
          pixels[index + 1].toDouble(),
          pixels[index + 2].toDouble(),
          pixels[index + 3].toDouble(),
        ];

      case SvgConvolveEdgeMode.none:
        // Return transparent black for out-of-bounds
        if (x < 0 || x >= width || y < 0 || y >= height) {
          return const <double>[0.0, 0.0, 0.0, 0.0];
        }
        final index = (y * width + x) * 4;
        return <double>[
          pixels[index].toDouble(),
          pixels[index + 1].toDouble(),
          pixels[index + 2].toDouble(),
          pixels[index + 3].toDouble(),
        ];
    }
  }

  /// Checks if kernel is an identity kernel (output equals input).
  ///
  /// An identity kernel has:
  /// - All zeros except at targetX, targetY position
  /// - Value 1 at the target position
  /// - Divisor of 1
  /// - Bias of 0
  static bool isIdentityKernel({
    required List<double> kernel,
    required int orderX,
    required int orderY,
    required int targetX,
    required int targetY,
    required double divisor,
    required double bias,
  }) {
    if (bias.abs() > 0.000001) return false;
    if ((divisor - 1.0).abs() > 0.000001) return false;
    if (kernel.length != orderX * orderY) return false;

    final targetIndex = targetY * orderX + targetX;
    for (int i = 0; i < kernel.length; i++) {
      if (i == targetIndex) {
        if ((kernel[i] - 1.0).abs() > 0.000001) return false;
      } else {
        if (kernel[i].abs() > 0.000001) return false;
      }
    }
    return true;
  }
}

/// Extended paint pass that includes convolution parameters.
///
/// When [convolveFilter] is non-null, the painter should apply convolution
/// to the rendered content before compositing.
class SvgConvolveMatrixPaintPass extends SvgFilterPaintPass {
  const SvgConvolveMatrixPaintPass({
    super.imageFilter,
    super.colorFilter,
    super.blendMode,
    super.offset,
    super.paintFill,
    super.paintStroke,
    required this.convolveFilter,
  });

  /// The convolution filter parameters to apply.
  final SvgConvolveMatrixFilter convolveFilter;

  @override
  SvgFilterPaintPass copyWith({
    ui.ImageFilter? imageFilter,
    ui.ColorFilter? colorFilter,
    ui.BlendMode? blendMode,
    ui.Offset? offset,
    bool? paintFill,
    bool? paintStroke,
  }) {
    return SvgConvolveMatrixPaintPass(
      imageFilter: imageFilter ?? this.imageFilter,
      colorFilter: colorFilter ?? this.colorFilter,
      blendMode: blendMode ?? this.blendMode,
      offset: offset ?? this.offset,
      paintFill: paintFill ?? this.paintFill,
      paintStroke: paintStroke ?? this.paintStroke,
      convolveFilter: convolveFilter,
    );
  }
}
