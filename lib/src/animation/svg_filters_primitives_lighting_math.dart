part of 'svg_filters.dart';

/// Compute distant light direction vector from azimuth and elevation angles.
///
/// Implements SVG feDistantLight light direction calculation:
///   Lx = cos(azimuth) * cos(elevation)
///   Ly = sin(azimuth) * cos(elevation)
///   Lz = sin(elevation)
///
/// [azimuthDegrees] is the angle in the XY plane (degrees, default 0).
/// [elevationDegrees] is the angle from the XY plane (degrees, default 0).
///
/// Returns a normalized (Lx, Ly, Lz) direction vector tuple.
(double, double, double) computeDistantLightVector(
  double azimuthDegrees,
  double elevationDegrees,
) {
  final az = azimuthDegrees * math.pi / 180.0;
  final el = elevationDegrees * math.pi / 180.0;

  final cosEl = math.cos(el);
  final lx = math.cos(az) * cosEl;
  final ly = math.sin(az) * cosEl;
  final lz = math.sin(el);

  // Normalize the vector
  final len = math.sqrt(lx * lx + ly * ly + lz * lz);
  if (len < 0.000001) {
    return (0.0, 0.0, 1.0);
  }
  return (lx / len, ly / len, lz / len);
}

/// Compute point light direction vector from light position to surface point.
///
/// Implements SVG fePointLight light direction calculation.
/// The direction is from the surface point toward the light source.
///
/// [lightX], [lightY], [lightZ] are the light source coordinates.
/// [surfaceX], [surfaceY], [surfaceZ] are the surface point coordinates.
///
/// Returns a normalized direction vector tuple from surface to light.
(double, double, double) computePointLightVector(
  double lightX,
  double lightY,
  double lightZ,
  double surfaceX,
  double surfaceY,
  double surfaceZ,
) {
  final dx = lightX - surfaceX;
  final dy = lightY - surfaceY;
  final dz = lightZ - surfaceZ;

  final len = math.sqrt(dx * dx + dy * dy + dz * dz);
  if (len < 0.000001) {
    return (0.0, 0.0, 1.0);
  }
  return (dx / len, dy / len, dz / len);
}

/// Compute spot light contribution with direction and cone attenuation.
///
/// Implements SVG feSpotLight light calculation with:
/// - Direction from light position to surface point
/// - Cone attenuation based on limitingConeAngle
/// - Falloff based on specularExponent
///
/// [lightX], [lightY], [lightZ] are the light source coordinates.
/// [pointsAtX], [pointsAtY], [pointsAtZ] define the spot direction target.
/// [surfaceX], [surfaceY], [surfaceZ] are the surface point coordinates.
/// [specularExponent] controls the spotlight falloff (default 1).
/// [limitingConeAngleDegrees] defines the cone cutoff angle (0 = no cutoff).
///
/// Returns a tuple of (direction (Lx, Ly, Lz), intensity).
/// Intensity is 0 if outside the cone, otherwise attenuated by specularExponent.
((double, double, double), double) computeSpotLightVector(
  double lightX,
  double lightY,
  double lightZ,
  double pointsAtX,
  double pointsAtY,
  double pointsAtZ,
  double surfaceX,
  double surfaceY,
  double surfaceZ, {
  double specularExponent = 1.0,
  double limitingConeAngleDegrees = 0.0,
}) {
  // Spot direction (from light toward pointsAt)
  final spotDx = pointsAtX - lightX;
  final spotDy = pointsAtY - lightY;
  final spotDz = pointsAtZ - lightZ;
  final spotLen = math.sqrt(spotDx * spotDx + spotDy * spotDy + spotDz * spotDz);
  final spotDirX = spotLen > 0.000001 ? spotDx / spotLen : 0.0;
  final spotDirY = spotLen > 0.000001 ? spotDy / spotLen : 0.0;
  final spotDirZ = spotLen > 0.000001 ? spotDz / spotLen : 1.0;

  // Direction from light to surface (for cone check)
  final toSurfaceX = surfaceX - lightX;
  final toSurfaceY = surfaceY - lightY;
  final toSurfaceZ = surfaceZ - lightZ;
  final toSurfaceLen = math.sqrt(
    toSurfaceX * toSurfaceX + toSurfaceY * toSurfaceY + toSurfaceZ * toSurfaceZ,
  );
  final toSurfaceDirX = toSurfaceLen > 0.000001 ? toSurfaceX / toSurfaceLen : 0.0;
  final toSurfaceDirY = toSurfaceLen > 0.000001 ? toSurfaceY / toSurfaceLen : 0.0;
  final toSurfaceDirZ = toSurfaceLen > 0.000001 ? toSurfaceZ / toSurfaceLen : 1.0;

  // Direction from surface to light (for lighting calculation)
  final lightDirX = toSurfaceLen > 0.000001 ? -toSurfaceDirX : 0.0;
  final lightDirY = toSurfaceLen > 0.000001 ? -toSurfaceDirY : 0.0;
  final lightDirZ = toSurfaceLen > 0.000001 ? -toSurfaceDirZ : 1.0;

  // Dot product: direction from light to surface · spot direction
  final spotDot =
      toSurfaceDirX * spotDirX + toSurfaceDirY * spotDirY + toSurfaceDirZ * spotDirZ;

  // Cone cutoff check
  double cosConeAngle = -1.0;
  if (limitingConeAngleDegrees > 0) {
    cosConeAngle = math.cos(limitingConeAngleDegrees * math.pi / 180.0);
  }

  // If outside the cone, intensity is 0
  if (spotDot < cosConeAngle) {
    return ((lightDirX, lightDirY, lightDirZ), 0.0);
  }

  // Compute attenuation: (spotDot)^specularExponent
  final attenuation = math.pow(spotDot.clamp(0.0, 1.0), specularExponent).toDouble();
  return ((lightDirX, lightDirY, lightDirZ), attenuation);
}

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
///
/// Implements full Blink-style point light with optional distance attenuation.
class _PointLightCalculator {
  const _PointLightCalculator({
    required this.lightX,
    required this.lightY,
    required this.lightZ,
    this.useDistanceAttenuation = false,
  });

  final double lightX;
  final double lightY;
  final double lightZ;
  final bool useDistanceAttenuation;

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

  /// Get light direction and intensity at a surface point.
  ///
  /// Returns (direction, intensity) where intensity accounts for distance
  /// attenuation when enabled.
  (_LightingVector3, double) directionAndIntensityAt(
    double surfaceX,
    double surfaceY,
    double surfaceZ,
  ) {
    final toLight = _LightingVector3(
      lightX - surfaceX,
      lightY - surfaceY,
      lightZ - surfaceZ,
    );

    final distance = toLight.length;
    final direction = distance > 0.000001
        ? toLight / distance
        : const _LightingVector3(0, 0, 1);

    double intensity = 1.0;
    if (useDistanceAttenuation && distance > 0.000001) {
      // Inverse square falloff, but clamped to prevent extreme values
      // Using a simple 1/d model that's common in real-time graphics
      intensity = 1.0 / (1.0 + distance * 0.01);
    }

    return (direction, intensity);
  }

  /// Compute the average intensity for color filter approximation.
  ///
  /// Assumes surface centered at (0, 0, 0) for simplified calculation.
  double getAverageIntensity() {
    if (!useDistanceAttenuation) return 1.0;

    final distance = _LightingVector3(lightX, lightY, lightZ).length;
    if (distance < 0.000001) return 1.0;

    return 1.0 / (1.0 + distance * 0.01);
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
extension SvgLightSourceExtension on SvgLightSource {
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

  /// Get light direction and intensity at a specific surface point.
  ///
  /// [surfaceX], [surfaceY], [surfaceZ] are the surface point coordinates.
  /// Returns (direction, intensity) tuple.
  (_LightingVector3, double) getDirectionAndIntensityAt(
    double surfaceX,
    double surfaceY,
    double surfaceZ,
  ) {
    if (this is SvgDistantLightSource) {
      final distant = this as SvgDistantLightSource;
      final dir = _DistantLightCalculator(
        azimuthDegrees: distant.azimuth,
        elevationDegrees: distant.elevation,
      ).direction;
      return (dir, 1.0);
    } else if (this is SvgPointLightSource) {
      final point = this as SvgPointLightSource;
      final calc = _PointLightCalculator(
        lightX: point.x,
        lightY: point.y,
        lightZ: point.z,
        useDistanceAttenuation: true,
      );
      return calc.directionAndIntensityAt(surfaceX, surfaceY, surfaceZ);
    } else if (this is SvgSpotLightSource) {
      final spot = this as SvgSpotLightSource;
      final calc = _SpotLightCalculator(
        lightX: spot.x,
        lightY: spot.y,
        lightZ: spot.z,
        pointsAtX: spot.pointsAtX,
        pointsAtY: spot.pointsAtY,
        pointsAtZ: spot.pointsAtZ,
        specularExponent: spot.specularExponent,
        limitingConeAngleDegrees: spot.limitingConeAngle,
      );
      return calc.directionAndIntensityAt(surfaceX, surfaceY, surfaceZ);
    }
    // Default: light from above
    return (const _LightingVector3(0, 0, 1), 1.0);
  }
}

/// Per-pixel lighting processor for full Blink-style lighting effects.
///
/// This class handles the complete lighting computation pipeline:
/// 1. Extract alpha channel as height map
/// 2. Compute surface normals using Sobel operator
/// 3. Apply lighting model (diffuse or specular) per pixel
/// 4. Output RGBA image data
class LightingProcessor {
  const LightingProcessor({
    required this.surfaceScale,
    required this.lightSource,
    required this.lightingColor,
    this.kernelUnitLengthX,
    this.kernelUnitLengthY,
    this.edgeMode = LightingEdgeMode.duplicate,
  });

  final double surfaceScale;
  final SvgLightSource lightSource;
  final ui.Color lightingColor;
  final double? kernelUnitLengthX;
  final double? kernelUnitLengthY;
  final LightingEdgeMode edgeMode;

  /// Process diffuse lighting on image data.
  ///
  /// [imageData] is RGBA byte array (4 bytes per pixel).
  /// [width], [height] are image dimensions.
  /// [diffuseConstant] is the kd coefficient.
  ///
  /// Returns processed RGBA image data.
  Uint8List processDiffuse(
    Uint8List imageData,
    int width,
    int height,
    double diffuseConstant,
  ) {
    // Extract alpha channel
    final alphaData = _extractAlpha(imageData, width, height);

    // Create normal calculator
    final normalCalc = _SurfaceNormalCalculator(
      surfaceScale: surfaceScale,
      kernelUnitLengthX: kernelUnitLengthX,
      kernelUnitLengthY: kernelUnitLengthY,
      edgeMode: edgeMode,
    );

    // Create output buffer
    final output = Uint8List(width * height * 4);

    // Process each pixel
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final idx = (y * width + x) * 4;

        // Compute surface normal
        final normal = normalCalc.computeNormalAt(
          alphaData,
          x,
          y,
          width,
          height,
        );

        // Compute surface height
        final surfaceZ = alphaData[y * width + x] / 255.0 * surfaceScale;

        // Get light direction and intensity
        final (lightDir, lightIntensity) = lightSource
            .getDirectionAndIntensityAt(x.toDouble(), y.toDouble(), surfaceZ);

        // Compute diffuse: kd * max(0, N·L) * lightIntensity
        final nDotL = normal.dot(lightDir).clamp(0.0, 1.0);
        final factor = (diffuseConstant * nDotL * lightIntensity).clamp(
          0.0,
          1.0,
        );

        // Apply to lighting color
        output[idx] = (lightingColor.r * 255 * factor).round().clamp(0, 255);
        output[idx + 1] = (lightingColor.g * 255 * factor).round().clamp(
          0,
          255,
        );
        output[idx + 2] = (lightingColor.b * 255 * factor).round().clamp(
          0,
          255,
        );
        output[idx + 3] = 255; // Diffuse alpha is always 1.0
      }
    }

    return output;
  }

  /// Process specular lighting on image data.
  ///
  /// [imageData] is RGBA byte array (4 bytes per pixel).
  /// [width], [height] are image dimensions.
  /// [specularConstant] is the ks coefficient.
  /// [specularExponent] is the shininess exponent.
  ///
  /// Returns processed RGBA image data.
  Uint8List processSpecular(
    Uint8List imageData,
    int width,
    int height,
    double specularConstant,
    double specularExponent,
  ) {
    // Extract alpha channel
    final alphaData = _extractAlpha(imageData, width, height);

    // Create normal calculator
    final normalCalc = _SurfaceNormalCalculator(
      surfaceScale: surfaceScale,
      kernelUnitLengthX: kernelUnitLengthX,
      kernelUnitLengthY: kernelUnitLengthY,
      edgeMode: edgeMode,
    );

    // Eye direction (viewer at infinity on z-axis)
    const eyeDir = _LightingVector3(0, 0, 1);

    // Create output buffer
    final output = Uint8List(width * height * 4);

    // Process each pixel
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final idx = (y * width + x) * 4;

        // Compute surface normal
        final normal = normalCalc.computeNormalAt(
          alphaData,
          x,
          y,
          width,
          height,
        );

        // Compute surface height
        final surfaceZ = alphaData[y * width + x] / 255.0 * surfaceScale;

        // Get light direction and intensity
        final (lightDir, lightIntensity) = lightSource
            .getDirectionAndIntensityAt(x.toDouble(), y.toDouble(), surfaceZ);

        // Compute half vector: H = normalize(L + Eye)
        final halfVector = (lightDir + eyeDir).normalize();

        // Compute specular: ks * (N·H)^exp * lightIntensity
        final nDotH = normal.dot(halfVector).clamp(0.0, 1.0);
        final specular = math.pow(nDotH, specularExponent).toDouble();
        final factor = (specularConstant * specular * lightIntensity).clamp(
          0.0,
          1.0,
        );

        // Apply to lighting color
        final r = (lightingColor.r * 255 * factor).round().clamp(0, 255);
        final g = (lightingColor.g * 255 * factor).round().clamp(0, 255);
        final b = (lightingColor.b * 255 * factor).round().clamp(0, 255);

        output[idx] = r;
        output[idx + 1] = g;
        output[idx + 2] = b;
        // Specular alpha = max(r, g, b)
        output[idx + 3] = math.max(r, math.max(g, b));
      }
    }

    return output;
  }

  /// Extract alpha channel from RGBA image data.
  Uint8List _extractAlpha(Uint8List imageData, int width, int height) {
    final alpha = Uint8List(width * height);
    for (int i = 0; i < width * height; i++) {
      alpha[i] = imageData[i * 4 + 3];
    }
    return alpha;
  }
}

/// Computes a sample of lighting values for a given light source configuration.
///
/// This is useful for generating preview colors or testing lighting setups.
class LightingSampler {
  const LightingSampler({
    required this.lightSource,
    required this.lightingColor,
    required this.surfaceScale,
  });

  final SvgLightSource lightSource;
  final ui.Color lightingColor;
  final double surfaceScale;

  /// Sample diffuse lighting at multiple points.
  ///
  /// Returns average color across sample points.
  ui.Color sampleDiffuse(double diffuseConstant, {int sampleCount = 9}) {
    double totalR = 0, totalG = 0, totalB = 0;
    final gridSize = math.sqrt(sampleCount).ceil();

    for (int i = 0; i < gridSize; i++) {
      for (int j = 0; j < gridSize; j++) {
        final x = i * 10.0;
        final y = j * 10.0;
        final z = surfaceScale * 0.5; // Mid-height assumption

        final (lightDir, intensity) = lightSource.getDirectionAndIntensityAt(
          x,
          y,
          z,
        );

        // Assume flat normal (0, 0, 1) for sampling
        const normal = _LightingVector3(0, 0, 1);
        final nDotL = normal.dot(lightDir).clamp(0.0, 1.0);
        final factor = (diffuseConstant * nDotL * intensity).clamp(0.0, 1.0);

        totalR += lightingColor.r * factor;
        totalG += lightingColor.g * factor;
        totalB += lightingColor.b * factor;
      }
    }

    final count = gridSize * gridSize;
    return ui.Color.fromARGB(
      255,
      (totalR / count * 255).round().clamp(0, 255),
      (totalG / count * 255).round().clamp(0, 255),
      (totalB / count * 255).round().clamp(0, 255),
    );
  }

  /// Sample specular lighting at multiple points.
  ///
  /// Returns average color across sample points.
  ui.Color sampleSpecular(
    double specularConstant,
    double specularExponent, {
    int sampleCount = 9,
  }) {
    double totalR = 0, totalG = 0, totalB = 0;
    final gridSize = math.sqrt(sampleCount).ceil();
    const eyeDir = _LightingVector3(0, 0, 1);

    for (int i = 0; i < gridSize; i++) {
      for (int j = 0; j < gridSize; j++) {
        final x = i * 10.0;
        final y = j * 10.0;
        final z = surfaceScale * 0.5;

        final (lightDir, intensity) = lightSource.getDirectionAndIntensityAt(
          x,
          y,
          z,
        );

        // Assume flat normal for sampling
        const normal = _LightingVector3(0, 0, 1);
        final halfVector = (lightDir + eyeDir).normalize();
        final nDotH = normal.dot(halfVector).clamp(0.0, 1.0);
        final specular = math.pow(nDotH, specularExponent).toDouble();
        final factor = (specularConstant * specular * intensity).clamp(
          0.0,
          1.0,
        );

        totalR += lightingColor.r * factor;
        totalG += lightingColor.g * factor;
        totalB += lightingColor.b * factor;
      }
    }

    final count = gridSize * gridSize;
    final r = (totalR / count * 255).round().clamp(0, 255);
    final g = (totalG / count * 255).round().clamp(0, 255);
    final b = (totalB / count * 255).round().clamp(0, 255);
    return ui.Color.fromARGB(math.max(r, math.max(g, b)), r, g, b);
  }
}
