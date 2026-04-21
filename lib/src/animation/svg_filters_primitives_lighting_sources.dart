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
  const double kConeAaThreshold = 0.016;

  double normalizeLimitingConeAngle(double angleDegrees) {
    if (angleDegrees == 0.0 || angleDegrees > 90.0 || angleDegrees < -90.0) {
      return 90.0;
    }
    return angleDegrees;
  }

  // Spot direction (from light toward pointsAt)
  final spotDx = pointsAtX - lightX;
  final spotDy = pointsAtY - lightY;
  final spotDz = pointsAtZ - lightZ;
  final spotLen = math.sqrt(
    spotDx * spotDx + spotDy * spotDy + spotDz * spotDz,
  );
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
  final toSurfaceDirX = toSurfaceLen > 0.000001
      ? toSurfaceX / toSurfaceLen
      : 0.0;
  final toSurfaceDirY = toSurfaceLen > 0.000001
      ? toSurfaceY / toSurfaceLen
      : 0.0;
  final toSurfaceDirZ = toSurfaceLen > 0.000001
      ? toSurfaceZ / toSurfaceLen
      : 1.0;

  // Direction from surface to light (for lighting calculation)
  final lightDirX = toSurfaceLen > 0.000001 ? -toSurfaceDirX : 0.0;
  final lightDirY = toSurfaceLen > 0.000001 ? -toSurfaceDirY : 0.0;
  final lightDirZ = toSurfaceLen > 0.000001 ? -toSurfaceDirZ : 1.0;

  // Dot product: direction from light to surface · spot direction
  final spotDot =
      toSurfaceDirX * spotDirX +
      toSurfaceDirY * spotDirY +
      toSurfaceDirZ * spotDirZ;

  final normalizedConeAngle = normalizeLimitingConeAngle(
    limitingConeAngleDegrees,
  );
  final cosConeAngle = math.cos(normalizedConeAngle * math.pi / 180.0);

  // If outside the cone, intensity is 0
  if (spotDot < cosConeAngle) {
    return ((lightDirX, lightDirY, lightDirZ), 0.0);
  }

  // Match Skia spotlight cone-edge softening:
  // if close to cutoff, fade in linearly within a small angular band.
  final clampedDot = spotDot.clamp(0.0, 1.0);
  final baseScale = math.pow(clampedDot, specularExponent).toDouble();
  final attenuation = clampedDot < cosConeAngle + kConeAaThreshold
      ? baseScale * (clampedDot - cosConeAngle) / kConeAaThreshold
      : baseScale;
  return ((lightDirX, lightDirY, lightDirZ), attenuation);
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

  static const double _coneAaThreshold = 0.016;

  double get _normalizedLimitingConeAngle {
    if (limitingConeAngleDegrees == 0.0 ||
        limitingConeAngleDegrees > 90.0 ||
        limitingConeAngleDegrees < -90.0) {
      return 90.0;
    }
    return limitingConeAngleDegrees;
  }

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
    return math.cos(_normalizedLimitingConeAngle * math.pi / 180.0);
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

    final clampedDot = spotDot.clamp(0.0, 1.0);
    final baseScale = math.pow(clampedDot, specularExponent).toDouble();
    final attenuation = clampedDot < cosConeAngle + _coneAaThreshold
        ? baseScale * (clampedDot - cosConeAngle) / _coneAaThreshold
        : baseScale;
    return (lightDir, attenuation);
  }
}
