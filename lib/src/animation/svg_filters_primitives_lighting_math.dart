part of 'svg_filters.dart';

/// 3D vector for lighting calculations.
class _LightingVector3 {
  const _LightingVector3(this.x, this.y, this.z);

  final double x;
  final double y;
  final double z;

  double get length => math.sqrt(x * x + y * y + z * z);

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

  _LightingVector3 operator +(_LightingVector3 other) {
    return _LightingVector3(x + other.x, y + other.y, z + other.z);
  }

  _LightingVector3 operator -(_LightingVector3 other) {
    return _LightingVector3(x - other.x, y - other.y, z - other.z);
  }

  _LightingVector3 operator *(double scalar) {
    return _LightingVector3(x * scalar, y * scalar, z * scalar);
  }
}

/// Surface normal calculation from alpha channel as height map.
///
/// Uses Sobel-like convolution kernels to estimate dN/dx and dN/dy,
/// then constructs the normal vector as:
///   N = normalize(-surfaceScale * dN/dx, -surfaceScale * dN/dy, 1)
// ignore: unused_element
class _SurfaceNormalCalculator {
  const _SurfaceNormalCalculator({
    required this.surfaceScale,
    // ignore: unused_element_parameter
    this.kernelUnitLengthX,
    // ignore: unused_element_parameter
    this.kernelUnitLengthY,
  });

  final double surfaceScale;
  final double? kernelUnitLengthX;
  final double? kernelUnitLengthY;

  /// Compute surface normal at a pixel position from alpha values.
  ///
  /// [alphaValues] is a 3x3 neighborhood of alpha values (0-255) centered
  /// at the target pixel. Layout:
  /// ```
  /// [0][1][2]
  /// [3][4][5]  <- [4] is the center pixel
  /// [6][7][8]
  /// ```
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

    // Scale by surfaceScale (alpha values normalized to 0-1)
    final factorX = surfaceScale / 4.0; // Sobel normalization factor
    final factorY = surfaceScale / 4.0;

    // Normal = normalize(-surfaceScale * dN/dx, -surfaceScale * dN/dy, 1)
    final nx = -factorX * gx / 255.0;
    final ny = -factorY * gy / 255.0;

    return _LightingVector3(nx, ny, 1.0).normalize();
  }

  /// Compute normal at edge pixels with reduced kernels.
  ///
  /// For edge pixels, uses 2-point difference instead of Sobel.
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
    final nx = -factor * gx;
    final ny = -factor * gy;

    return _LightingVector3(nx, ny, 1.0).normalize();
  }
}

/// Light direction calculator for feDistantLight.
///
/// Direction from azimuth/elevation angles:
///   L = normalize(cos(az)*cos(el), sin(az)*cos(el), sin(el))
class _DistantLightCalculator {
  const _DistantLightCalculator({
    required this.azimuthDegrees,
    required this.elevationDegrees,
  });

  final double azimuthDegrees;
  final double elevationDegrees;

  /// Get light direction vector (constant for all pixels).
  _LightingVector3 get direction {
    final az = azimuthDegrees * math.pi / 180.0;
    final el = elevationDegrees * math.pi / 180.0;

    final cosEl = math.cos(el);
    return _LightingVector3(
      math.cos(az) * cosEl,
      math.sin(az) * cosEl,
      math.sin(el),
    ).normalize();
  }
}

/// Light direction calculator for fePointLight.
///
/// Direction varies per pixel:
///   L = normalize(lightPos - surfacePoint)
// ignore: unused_element
class _PointLightCalculator {
  const _PointLightCalculator({
    required this.lightX,
    required this.lightY,
    required this.lightZ,
  });

  final double lightX;
  final double lightY;
  final double lightZ;

  /// Get light direction at a surface point.
  ///
  /// [surfaceX], [surfaceY] are the pixel coordinates.
  /// [surfaceZ] is the height from the alpha channel * surfaceScale.
  _LightingVector3 directionAt(
    double surfaceX,
    double surfaceY,
    double surfaceZ,
  ) {
    return _LightingVector3(
      lightX - surfaceX,
      lightY - surfaceY,
      lightZ - surfaceZ,
    ).normalize();
  }
}

/// Light calculator for feSpotLight.
///
/// Combines point light direction with cone attenuation:
///   - L direction toward surface point
///   - Attenuated by limitingConeAngle and (L·S)^specularExponent
class _SpotLightCalculator {
  const _SpotLightCalculator({
    required this.lightX,
    required this.lightY,
    required this.lightZ,
    required this.pointsAtX,
    required this.pointsAtY,
    required this.pointsAtZ,
    required this.specularExponent,
    required this.limitingConeAngleDegrees,
  });

  final double lightX;
  final double lightY;
  final double lightZ;
  final double pointsAtX;
  final double pointsAtY;
  final double pointsAtZ;
  final double specularExponent;
  final double limitingConeAngleDegrees;

  /// Spot direction (from light toward pointsAt).
  _LightingVector3 get spotDirection {
    return _LightingVector3(
      pointsAtX - lightX,
      pointsAtY - lightY,
      pointsAtZ - lightZ,
    ).normalize();
  }

  /// Cosine of the limiting cone angle.
  double get cosConeAngle {
    // If limitingConeAngle is 0, no angular cutoff (180 degree cone)
    if (limitingConeAngleDegrees <= 0) {
      return -1.0;
    }
    return math.cos(limitingConeAngleDegrees * math.pi / 180.0);
  }

  /// Get light direction and intensity at a surface point.
  ///
  /// Returns (direction, intensity) where intensity is the spot attenuation.
  (_LightingVector3, double) directionAndIntensityAt(
    double surfaceX,
    double surfaceY,
    double surfaceZ,
  ) {
    // Direction from light to surface
    final toSurface = _LightingVector3(
      surfaceX - lightX,
      surfaceY - lightY,
      surfaceZ - lightZ,
    ).normalize();

    // Direction from surface to light (for lighting calculation)
    final lightDir = _LightingVector3(
      lightX - surfaceX,
      lightY - surfaceY,
      lightZ - surfaceZ,
    ).normalize();

    // Spot attenuation: (-L · S)^specularExponent
    // where L is direction from light to surface, S is spot direction
    final spotDot = toSurface.dot(spotDirection);

    // Check if outside cone
    if (spotDot < cosConeAngle) {
      return (lightDir, 0.0);
    }

    // Compute attenuation
    final attenuation = math
        .pow(spotDot.clamp(0.0, 1.0), specularExponent)
        .toDouble();
    return (lightDir, attenuation);
  }
}

/// Diffuse lighting calculation (Lambertian reflectance).
///
/// Formula: result.rgb = diffuseConstant * max(0, N·L) * lightColor
/// result.a = 1.0
class _DiffuseLightingCalculator {
  const _DiffuseLightingCalculator({
    required this.diffuseConstant,
    required this.lightingColor,
  });

  final double diffuseConstant;
  final ui.Color lightingColor;

  /// Compute diffuse color at a point.
  ///
  /// [normal] is the surface normal.
  /// [lightDirection] is the direction toward the light.
  /// [lightIntensity] is additional attenuation (e.g., from spotlight).
  ui.Color compute(
    _LightingVector3 normal,
    _LightingVector3 lightDirection, {
    double lightIntensity = 1.0,
  }) {
    // N·L clamped to [0, 1]
    final nDotL = (normal.dot(lightDirection)).clamp(0.0, 1.0);

    // diffuseConstant * N·L * lightIntensity
    final factor = (diffuseConstant * nDotL * lightIntensity).clamp(0.0, 1.0);

    return ui.Color.fromARGB(
      255, // Diffuse lighting always has alpha = 1.0
      (lightingColor.r * 255.0 * factor).round().clamp(0, 255),
      (lightingColor.g * 255.0 * factor).round().clamp(0, 255),
      (lightingColor.b * 255.0 * factor).round().clamp(0, 255),
    );
  }

  /// Get average diffuse intensity for ColorFilter approximation.
  ///
  /// Uses a default normal pointing up (0, 0, 1) and light from above.
  double getAverageIntensity(_LightingVector3 lightDirection) {
    const defaultNormal = _LightingVector3(0, 0, 1);
    final nDotL = defaultNormal.dot(lightDirection).clamp(0.0, 1.0);
    return (diffuseConstant * nDotL).clamp(0.0, 1.0);
  }
}

/// Specular lighting calculation (Blinn-Phong).
///
/// Formula:
///   H = normalize(L + (0, 0, 1))  // Eye at infinity on z-axis
///   result.rgb = specularConstant * max(0, N·H)^specularExponent * lightColor
///   result.a = max(result.r, result.g, result.b)
class _SpecularLightingCalculator {
  const _SpecularLightingCalculator({
    required this.specularConstant,
    required this.specularExponent,
    required this.lightingColor,
  });

  final double specularConstant;
  final double specularExponent;
  final ui.Color lightingColor;

  /// Eye direction (viewer at infinity on z-axis).
  static const _eyeDirection = _LightingVector3(0, 0, 1);

  /// Compute specular color at a point.
  ///
  /// [normal] is the surface normal.
  /// [lightDirection] is the direction toward the light.
  /// [lightIntensity] is additional attenuation (e.g., from spotlight).
  ui.Color compute(
    _LightingVector3 normal,
    _LightingVector3 lightDirection, {
    double lightIntensity = 1.0,
  }) {
    // H = normalize(L + eye)
    final halfVector = (lightDirection + _eyeDirection).normalize();

    // N·H clamped to [0, 1]
    final nDotH = normal.dot(halfVector).clamp(0.0, 1.0);

    // specularConstant * (N·H)^specularExponent * lightIntensity
    final specular = math.pow(nDotH, specularExponent);
    final factor = (specularConstant * specular * lightIntensity).clamp(
      0.0,
      1.0,
    );

    final r = (lightingColor.r * 255.0 * factor).round().clamp(0, 255);
    final g = (lightingColor.g * 255.0 * factor).round().clamp(0, 255);
    final b = (lightingColor.b * 255.0 * factor).round().clamp(0, 255);

    // Alpha = max(r, g, b) / 255
    final maxComponent = math.max(r, math.max(g, b));

    return ui.Color.fromARGB(maxComponent, r, g, b);
  }

  /// Get average specular intensity for ColorFilter approximation.
  double getAverageIntensity(_LightingVector3 lightDirection) {
    const defaultNormal = _LightingVector3(0, 0, 1);
    final halfVector = (lightDirection + _eyeDirection).normalize();
    final nDotH = defaultNormal.dot(halfVector).clamp(0.0, 1.0);
    final specular = math.pow(nDotH, specularExponent);
    return (specularConstant * specular).clamp(0.0, 1.0);
  }
}

/// Helper extension to compute lighting effect from light source.
extension _LightSourceExtension on SvgLightSource {
  /// Get the primary light direction for this light source.
  ///
  /// For distant lights, returns the constant direction.
  /// For point/spot lights, returns direction from origin as approximation.
  _LightingVector3 getPrimaryDirection() {
    if (this is SvgDistantLightSource) {
      final distant = this as SvgDistantLightSource;
      return _DistantLightCalculator(
        azimuthDegrees: distant.azimuth,
        elevationDegrees: distant.elevation,
      ).direction;
    } else if (this is SvgPointLightSource) {
      final point = this as SvgPointLightSource;
      // Direction from origin to light (approximate)
      return _LightingVector3(point.x, point.y, point.z).normalize();
    } else if (this is SvgSpotLightSource) {
      final spot = this as SvgSpotLightSource;
      // Use spot direction
      return _SpotLightCalculator(
            lightX: spot.x,
            lightY: spot.y,
            lightZ: spot.z,
            pointsAtX: spot.pointsAtX,
            pointsAtY: spot.pointsAtY,
            pointsAtZ: spot.pointsAtZ,
            specularExponent: spot.specularExponent,
            limitingConeAngleDegrees: spot.limitingConeAngle,
          ).spotDirection *
          -1.0; // Reverse for light direction
    }
    // Default: light from above
    return const _LightingVector3(0, 0, 1);
  }

  /// Get average light intensity (1.0 for distant/point, variable for spot).
  double getAverageIntensity() {
    if (this is SvgSpotLightSource) {
      // Spot light has attenuation, use 0.5 as average
      return 0.5;
    }
    return 1.0;
  }
}
