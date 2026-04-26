part of 'svg_filters.dart';

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
