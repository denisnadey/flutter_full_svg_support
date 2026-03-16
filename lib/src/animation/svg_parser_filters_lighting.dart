part of 'svg_parser.dart';

ui.Color _parseLightingColor(XmlElement element) {
  final parsedLightingColor = _parseColor(
    element.getAttribute('lighting-color') ??
        element.getAttribute('lightingColor') ??
        'white',
  );
  return parsedLightingColor is ui.Color
      ? parsedLightingColor
      : const ui.Color(0xFFFFFFFF);
}

SvgLightSource? _parseLightingLightSource(XmlElement element) {
  for (final child in element.childElements) {
    switch (child.name.local) {
      case 'feDistantLight':
        return SvgDistantLightSource(
          azimuth: _parseNumber(child.getAttribute('azimuth') ?? '0'),
          elevation: _parseNumber(child.getAttribute('elevation') ?? '0'),
        );
      case 'fePointLight':
        return SvgPointLightSource(
          x: _parseNumber(child.getAttribute('x') ?? '0'),
          y: _parseNumber(child.getAttribute('y') ?? '0'),
          z: _parseNumber(child.getAttribute('z') ?? '0'),
        );
      case 'feSpotLight':
        return SvgSpotLightSource(
          x: _parseNumber(child.getAttribute('x') ?? '0'),
          y: _parseNumber(child.getAttribute('y') ?? '0'),
          z: _parseNumber(child.getAttribute('z') ?? '0'),
          pointsAtX: _parseNumber(child.getAttribute('pointsAtX') ?? '0'),
          pointsAtY: _parseNumber(child.getAttribute('pointsAtY') ?? '0'),
          pointsAtZ: _parseNumber(child.getAttribute('pointsAtZ') ?? '0'),
          specularExponent: _parseNumber(
            child.getAttribute('specularExponent') ?? '1',
          ).clamp(1.0, 128.0).toDouble(),
          limitingConeAngle: _parseNumber(
            child.getAttribute('limitingConeAngle') ?? '0',
          ),
        );
    }
  }
  return null;
}

(double?, double?) _parseLightingKernelUnitLength(XmlElement element) {
  final raw = element.getAttribute('kernelUnitLength');
  if (raw == null || raw.trim().isEmpty) {
    return (null, null);
  }
  final parsed = _parseNumberOptionalNumber(raw);
  if (parsed.$1 <= 0 || parsed.$2 <= 0) {
    return (null, null);
  }
  return (parsed.$1, parsed.$2);
}
