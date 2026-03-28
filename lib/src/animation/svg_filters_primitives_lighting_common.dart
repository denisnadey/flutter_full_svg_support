part of 'svg_filters.dart';

/// Edge mode for surface normal computation at image boundaries.
enum LightingEdgeMode {
  /// Duplicate edge pixels (Blink default behavior).
  duplicate,

  /// Wrap around to opposite edge.
  wrap,

  /// Use zero (transparent black) for out-of-bounds pixels.
  none,
}

/// 3D vector for lighting calculations.
class _LightingVector3 {
  const _LightingVector3(this.x, this.y, this.z);

  final double x;
  final double y;
  final double z;

  double get length => math.sqrt(x * x + y * y + z * z);

  double get lengthSquared => x * x + y * y + z * z;

  _LightingVector3 normalize() {
    final len = length;
    if (len < 0.000001) {
      return const _LightingVector3(0, 0, 1);
    }
    return _LightingVector3(x / len, y / len, z / len);
  }

  double dot(_LightingVector3 other) {
    return x * other.x + y * other.y + z * other.z;
  }

  _LightingVector3 cross(_LightingVector3 other) {
    return _LightingVector3(
      y * other.z - z * other.y,
      z * other.x - x * other.z,
      x * other.y - y * other.x,
    );
  }

  _LightingVector3 operator +(_LightingVector3 other) {
    return _LightingVector3(x + other.x, y + other.y, z + other.z);
  }

  _LightingVector3 operator -(_LightingVector3 other) {
    return _LightingVector3(x - other.x, y - other.y, z - other.z);
  }

  _LightingVector3 operator *(double scalar) {
    return _LightingVector3(x * scalar, y * scalar, z * scalar);
  }

  _LightingVector3 operator /(double scalar) {
    return _LightingVector3(x / scalar, y / scalar, z / scalar);
  }

  @override
  String toString() => 'Vec3($x, $y, $z)';
}

/// Surface normal calculation from alpha channel as height map.
///
/// Uses Sobel-like convolution kernels to estimate dN/dx and dN/dy,
/// then constructs the normal vector as:
///   N = normalize(-surfaceScale * dN/dx, -surfaceScale * dN/dy, 1)
///
/// Implements full Blink-style surface normal computation with proper
/// edge handling for border pixels.
class _SurfaceNormalCalculator {
  const _SurfaceNormalCalculator({
    required this.surfaceScale,
    this.kernelUnitLengthX,
    this.kernelUnitLengthY,
    this.edgeMode = LightingEdgeMode.duplicate,
  });

  final double surfaceScale;
  final double? kernelUnitLengthX;
  final double? kernelUnitLengthY;
  final LightingEdgeMode edgeMode;

  /// Factor for kernel unit length scaling.
  double get _factorX => kernelUnitLengthX ?? 1.0;
  double get _factorY => kernelUnitLengthY ?? 1.0;

  /// Compute surface normal at a pixel position from alpha values.
  ///
  /// [alphaValues] is a 3x3 neighborhood of alpha values (0-255) centered
  /// at the target pixel. Layout:
  /// ```
  /// [0][1][2]
  /// [3][4][5]  <- [4] is the center pixel
  /// [6][7][8]
  /// ```
  ///
  /// This uses the standard Sobel operator for gradient estimation.
  _LightingVector3 computeNormal(List<double> alphaValues) {
    // Sobel kernels for gradient estimation
    // Gx = | -1  0  1 |    Gy = | -1 -2 -1 |
    //      | -2  0  2 |         |  0  0  0 |
    //      | -1  0  1 |         |  1  2  1 |
    final gx =
        (alphaValues[2] - alphaValues[0]) +
        2 * (alphaValues[5] - alphaValues[3]) +
        (alphaValues[8] - alphaValues[6]);
    final gy =
        (alphaValues[6] - alphaValues[0]) +
        2 * (alphaValues[7] - alphaValues[1]) +
        (alphaValues[8] - alphaValues[2]);

    // Scale by surfaceScale and kernel unit length
    // The Sobel operator has an implicit 1/4 normalization factor
    final factorX = surfaceScale / (4.0 * _factorX);
    final factorY = surfaceScale / (4.0 * _factorY);

    // Normal = normalize(-surfaceScale * dN/dx, -surfaceScale * dN/dy, 1)
    // Alpha values are 0-255, so normalize to 0-1 range
    final nx = -factorX * gx / 255.0;
    final ny = -factorY * gy / 255.0;

    return _LightingVector3(nx, ny, 1.0).normalize();
  }

  /// Compute surface normal at an interior pixel from alpha data.
  ///
  /// [alphaData] is the full image alpha channel.
  /// [x], [y] are the pixel coordinates.
  /// [width], [height] are the image dimensions.
  _LightingVector3 computeNormalAt(
    Uint8List alphaData,
    int x,
    int y,
    int width,
    int height,
  ) {
    // Collect 3x3 neighborhood
    final values = <double>[];
    for (int dy = -1; dy <= 1; dy++) {
      for (int dx = -1; dx <= 1; dx++) {
        values.add(_getAlphaAt(alphaData, x + dx, y + dy, width, height));
      }
    }
    return computeNormal(values);
  }

  /// Get alpha value at coordinates with edge mode handling.
  double _getAlphaAt(Uint8List alphaData, int x, int y, int width, int height) {
    if (x >= 0 && x < width && y >= 0 && y < height) {
      return alphaData[y * width + x].toDouble();
    }

    switch (edgeMode) {
      case LightingEdgeMode.duplicate:
        // Clamp to edge
        final clampedX = x.clamp(0, width - 1);
        final clampedY = y.clamp(0, height - 1);
        return alphaData[clampedY * width + clampedX].toDouble();
      case LightingEdgeMode.wrap:
        // Wrap around
        final wrappedX = ((x % width) + width) % width;
        final wrappedY = ((y % height) + height) % height;
        return alphaData[wrappedY * width + wrappedX].toDouble();
      case LightingEdgeMode.none:
        // Return 0 (transparent)
        return 0.0;
    }
  }

  /// Compute normal at edge pixels with reduced kernels.
  ///
  /// For edge pixels, uses 2-point difference instead of Sobel.
  /// This is used when explicit edge handling is needed.
  _LightingVector3 computeEdgeNormal(
    double centerAlpha,
    double? leftAlpha,
    double? rightAlpha,
    double? topAlpha,
    double? bottomAlpha,
  ) {
    double gx = 0;
    double gy = 0;

    // Compute X gradient
    if (leftAlpha != null && rightAlpha != null) {
      gx = (rightAlpha - leftAlpha) / 2.0;
    } else if (rightAlpha != null) {
      gx = rightAlpha - centerAlpha;
    } else if (leftAlpha != null) {
      gx = centerAlpha - leftAlpha;
    }

    // Compute Y gradient
    if (topAlpha != null && bottomAlpha != null) {
      gy = (bottomAlpha - topAlpha) / 2.0;
    } else if (bottomAlpha != null) {
      gy = bottomAlpha - centerAlpha;
    } else if (topAlpha != null) {
      gy = centerAlpha - topAlpha;
    }

    final factor = surfaceScale / 255.0;
    final nx = -factor * gx / _factorX;
    final ny = -factor * gy / _factorY;

    return _LightingVector3(nx, ny, 1.0).normalize();
  }

  /// Compute normals for all pixels in the alpha channel.
  ///
  /// Returns a list of normals, one per pixel, in row-major order.
  List<_LightingVector3> computeAllNormals(
    Uint8List alphaData,
    int width,
    int height,
  ) {
    final normals = <_LightingVector3>[];
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        normals.add(computeNormalAt(alphaData, x, y, width, height));
      }
    }
    return normals;
  }
}
