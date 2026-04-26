part of 'svg_parser.dart';

String? _normalizeFilterInput(String? raw) {
  final normalized = raw?.trim();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }
  return normalized;
}

String? _normalizeFilterResult(String? raw) {
  final normalized = raw?.trim();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }
  return normalized;
}

String? _getFilterPrimitiveAttributeOrStyleValue(
  XmlElement element, {
  required List<String> attributeNames,
  required List<String> styleNames,
  required Map<String, String> styleDeclarations,
}) {
  for (final styleName in styleNames) {
    final styleValue = styleDeclarations[styleName.toLowerCase()]?.trim();
    if (styleValue != null && styleValue.isNotEmpty) {
      return styleValue;
    }
  }

  for (final attributeName in attributeNames) {
    final attributeValue = element.getAttribute(attributeName)?.trim();
    if (attributeValue != null && attributeValue.isNotEmpty) {
      return attributeValue;
    }
  }

  return null;
}

Map<String, String> _parseInlineStyleDeclarations(String? rawStyle) {
  if (rawStyle == null || rawStyle.trim().isEmpty) {
    return const <String, String>{};
  }

  final declarations = <String, String>{};
  for (final entry in rawStyle.split(';')) {
    final separator = entry.indexOf(':');
    if (separator <= 0) {
      continue;
    }
    final key = entry.substring(0, separator).trim().toLowerCase();
    if (key.isEmpty) {
      continue;
    }
    final value = _stripImportantSuffix(entry.substring(separator + 1));
    if (value.isEmpty) {
      continue;
    }
    declarations[key] = value;
  }

  return declarations;
}

String _stripImportantSuffix(String rawValue) {
  final trimmed = rawValue.trim();
  final lowercase = trimmed.toLowerCase();
  final importantIndex = lowercase.lastIndexOf('!important');
  if (importantIndex < 0) {
    return trimmed;
  }
  return trimmed.substring(0, importantIndex).trim();
}

SvgChannelSelector _parseChannelSelector(String raw) {
  switch (raw.trim().toUpperCase()) {
    case 'R':
      return SvgChannelSelector.r;
    case 'G':
      return SvgChannelSelector.g;
    case 'B':
      return SvgChannelSelector.b;
    case 'A':
    default:
      return SvgChannelSelector.a;
  }
}

SvgConvolveEdgeMode _parseConvolveEdgeMode(String? raw) {
  switch (raw?.trim().toLowerCase()) {
    case 'wrap':
      return SvgConvolveEdgeMode.wrap;
    case 'none':
      return SvgConvolveEdgeMode.none;
    case 'duplicate':
    default:
      return SvgConvolveEdgeMode.duplicate;
  }
}

SvgTurbulenceType _parseTurbulenceType(String? raw) {
  switch (raw?.trim().toLowerCase()) {
    case 'fractalnoise':
      return SvgTurbulenceType.fractalNoise;
    case 'turbulence':
    default:
      return SvgTurbulenceType.turbulence;
  }
}

SvgTurbulenceStitchTiles _parseTurbulenceStitchTiles(String? raw) {
  switch (raw?.trim().toLowerCase()) {
    case 'stitch':
      return SvgTurbulenceStitchTiles.stitch;
    case 'nostitch':
    default:
      return SvgTurbulenceStitchTiles.noStitch;
  }
}

SvgComponentTransferType _parseComponentTransferType(String? raw) {
  switch (raw?.trim().toLowerCase()) {
    case 'table':
      return SvgComponentTransferType.table;
    case 'discrete':
      return SvgComponentTransferType.discrete;
    case 'linear':
      return SvgComponentTransferType.linear;
    case 'gamma':
      return SvgComponentTransferType.gamma;
    case 'identity':
    default:
      return SvgComponentTransferType.identity;
  }
}

bool _parseSvgBoolean(String? raw) {
  if (raw == null) {
    return false;
  }
  switch (raw.trim().toLowerCase()) {
    case '1':
    case 'true':
    case 'yes':
      return true;
    default:
      return false;
  }
}

int _parseIntWithDefault(String? raw, int fallback) {
  if (raw == null || raw.trim().isEmpty) {
    return fallback;
  }
  final parsed = double.tryParse(raw.trim());
  if (parsed == null) {
    return fallback;
  }
  return parsed.round();
}
