part of 'svg_filters.dart';

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
