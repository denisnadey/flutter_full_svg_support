part of 'css_to_smil_converter.dart';

final RegExp _cssTransformFunctionRegex = RegExp(
  r'(translate3d|translatez|translatex|translatey|translate|rotate3d|rotatex|rotatey|rotatez|rotate|scale3d|scalez|scalex|scaley|scale|skewx|skewy|matrix3d|matrix|perspective)\s*\(\s*([^)]+)\s*\)',
  caseSensitive: false,
);

String _normalizeCssTransformInternal(String value) {
  final input = value.trim();
  if (input.isEmpty) {
    return input;
  }

  final normalizedParts = <String>[];
  for (final match in _cssTransformFunctionRegex.allMatches(input)) {
    final functionName = match.group(1)!.toLowerCase();
    final args = match
        .group(2)!
        .split(RegExp(r'[\s,]+'))
        .where((part) => part.trim().isNotEmpty)
        .map((part) => part.trim())
        .toList();

    String? normalized;
    switch (functionName) {
      case 'translate':
        normalized = _normalizeTranslate(args);
        break;
      case 'translatex':
        normalized = _normalizeTranslate(<String>[
          if (args.isNotEmpty) args[0],
          '0',
        ]);
        break;
      case 'translatey':
        normalized = _normalizeTranslate(<String>[
          '0',
          if (args.isNotEmpty) args[0],
        ]);
        break;
      case 'rotate':
        normalized = _normalizeRotate(args);
        break;
      case 'scale':
        normalized = _normalizeScale(args);
        break;
      case 'scalex':
        normalized = _normalizeScale(<String>[
          if (args.isNotEmpty) args[0],
          '1',
        ]);
        break;
      case 'scaley':
        normalized = _normalizeScale(<String>[
          '1',
          if (args.isNotEmpty) args[0],
        ]);
        break;
      case 'skewx':
        normalized = _normalizeSkew(args, 'skewX');
        break;
      case 'skewy':
        normalized = _normalizeSkew(args, 'skewY');
        break;
      case 'matrix':
        normalized = _normalizeMatrix(args);
        break;
      // 3D transform functions
      case 'translate3d':
        normalized = _normalizeTranslate3d(args);
        break;
      case 'translatez':
        normalized = _normalizeTranslateZ(args);
        break;
      case 'rotate3d':
        normalized = _normalizeRotate3d(args);
        break;
      case 'rotatex':
        normalized = _normalizeRotateAxis(args, 'rotateX');
        break;
      case 'rotatey':
        normalized = _normalizeRotateAxis(args, 'rotateY');
        break;
      case 'rotatez':
        normalized = _normalizeRotateAxis(args, 'rotateZ');
        break;
      case 'scale3d':
        normalized = _normalizeScale3d(args);
        break;
      case 'scalez':
        normalized = _normalizeScaleZ(args);
        break;
      case 'perspective':
        normalized = _normalizePerspective(args);
        break;
      case 'matrix3d':
        normalized = _normalizeMatrix3d(args);
        break;
    }

    if (normalized != null) {
      normalizedParts.add(normalized);
    }
  }

  return normalizedParts.isNotEmpty ? normalizedParts.join(' ') : input;
}

String? _normalizeTranslate(List<String> args) {
  final tx = args.isNotEmpty ? _parseLength(args[0]) : 0.0;
  final ty = args.length > 1 ? _parseLength(args[1]) : 0.0;
  return 'translate(${_formatDouble(tx)}, ${_formatDouble(ty)})';
}

String? _normalizeRotate(List<String> args) {
  final angle = args.isNotEmpty ? _parseAngleToDegrees(args[0]) : 0.0;
  final cx = args.length > 1 ? _parseLength(args[1]) : null;
  final cy = args.length > 2 ? _parseLength(args[2]) : null;
  if (cx != null && cy != null) {
    return 'rotate(${_formatDouble(angle)}, ${_formatDouble(cx)}, ${_formatDouble(cy)})';
  }
  return 'rotate(${_formatDouble(angle)})';
}

String? _normalizeScale(List<String> args) {
  final sx = args.isNotEmpty ? _parseNumber(args[0], fallback: 1.0) : 1.0;
  final sy = args.length > 1 ? _parseNumber(args[1], fallback: sx) : sx;
  return 'scale(${_formatDouble(sx)}, ${_formatDouble(sy)})';
}

String? _normalizeSkew(List<String> args, String name) {
  final angle = args.isNotEmpty ? _parseAngleToDegrees(args[0]) : 0.0;
  return '$name(${_formatDouble(angle)})';
}

String? _normalizeMatrix(List<String> args) {
  if (args.length < 6) {
    return null;
  }

  final values = args
      .take(6)
      .map((part) => _parseNumber(part, fallback: 0.0))
      .map(_formatDouble)
      .join(', ');
  return 'matrix($values)';
}

/// Parses a CSS length value to pixels.
/// Supports: px, em, rem, %, vw, vh, vmin, vmax, cm, mm, in, pt, pc, bare numbers.
double _parseLength(String value) {
  final trimmed = value.trim().toLowerCase();

  // Handle percentage separately - need context for proper conversion
  if (trimmed.endsWith('%')) {
    // For transforms, we can't resolve % without context, so just parse the number
    return double.tryParse(trimmed.substring(0, trimmed.length - 1)) ?? 0.0;
  }

  // Map of unit suffixes to their pixel conversion factors
  // Base assumptions: 16px = 1em = 1rem, 96dpi for absolute units
  // Sorted by length descending to avoid 'em' matching 'rem'
  const unitConversions = <String, double>{
    'vmin': 1.0,
    'vmax': 1.0,
    'rem': 16.0, // Must come before 'em'
    'em': 16.0,
    'px': 1.0,
    'ex': 8.0,
    'ch': 8.0,
    'vw': 1.0,
    'vh': 1.0,
    'cm': 37.795,
    'mm': 3.7795,
    'in': 96.0,
    'pt': 1.333,
    'pc': 16.0,
  };

  for (final entry in unitConversions.entries) {
    if (trimmed.endsWith(entry.key)) {
      final numStr = trimmed.substring(0, trimmed.length - entry.key.length);
      final num = double.tryParse(numStr) ?? 0.0;
      return num * entry.value;
    }
  }

  // Bare number
  return double.tryParse(trimmed) ?? 0.0;
}

double _parseAngleToDegrees(String value) {
  final match = RegExp(
    r'^([+-]?(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?)\s*(deg|rad|turn|grad)?$',
    caseSensitive: false,
  ).firstMatch(value.trim());
  if (match == null) {
    return 0.0;
  }

  final number = double.tryParse(match.group(1) ?? '') ?? 0.0;
  final unit = (match.group(2) ?? 'deg').toLowerCase();
  return switch (unit) {
    'deg' => number,
    'rad' => number * 180.0 / math.pi,
    'turn' => number * 360.0,
    'grad' => number * 0.9,
    _ => number,
  };
}

double _parseNumber(String value, {required double fallback}) {
  final match = RegExp(
    r'^[+-]?(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?',
  ).firstMatch(value.trim());
  if (match == null) {
    return fallback;
  }
  return double.tryParse(match.group(0)!) ?? fallback;
}

String _formatDouble(double value) {
  final normalized = value == -0.0 ? 0.0 : value;
  if (normalized == normalized.truncateToDouble()) {
    return normalized.toStringAsFixed(0);
  }
  return normalized
      .toStringAsFixed(4)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}

// 3D transform normalization functions

String? _normalizeTranslate3d(List<String> args) {
  final tx = args.isNotEmpty ? _parseLength(args[0]) : 0.0;
  final ty = args.length > 1 ? _parseLength(args[1]) : 0.0;
  final tz = args.length > 2 ? _parseLength(args[2]) : 0.0;
  return 'translate3d(${_formatDouble(tx)}, ${_formatDouble(ty)}, ${_formatDouble(tz)})';
}

String? _normalizeTranslateZ(List<String> args) {
  final tz = args.isNotEmpty ? _parseLength(args[0]) : 0.0;
  return 'translateZ(${_formatDouble(tz)})';
}

String? _normalizeRotate3d(List<String> args) {
  final x = args.isNotEmpty ? _parseNumber(args[0], fallback: 0.0) : 0.0;
  final y = args.length > 1 ? _parseNumber(args[1], fallback: 0.0) : 0.0;
  final z = args.length > 2 ? _parseNumber(args[2], fallback: 0.0) : 0.0;
  final angle = args.length > 3 ? _parseAngleToDegrees(args[3]) : 0.0;
  return 'rotate3d(${_formatDouble(x)}, ${_formatDouble(y)}, ${_formatDouble(z)}, ${_formatDouble(angle)})';
}

String? _normalizeRotateAxis(List<String> args, String name) {
  final angle = args.isNotEmpty ? _parseAngleToDegrees(args[0]) : 0.0;
  return '$name(${_formatDouble(angle)})';
}

String? _normalizeScale3d(List<String> args) {
  final sx = args.isNotEmpty ? _parseNumber(args[0], fallback: 1.0) : 1.0;
  final sy = args.length > 1 ? _parseNumber(args[1], fallback: 1.0) : 1.0;
  final sz = args.length > 2 ? _parseNumber(args[2], fallback: 1.0) : 1.0;
  return 'scale3d(${_formatDouble(sx)}, ${_formatDouble(sy)}, ${_formatDouble(sz)})';
}

String? _normalizeScaleZ(List<String> args) {
  final sz = args.isNotEmpty ? _parseNumber(args[0], fallback: 1.0) : 1.0;
  return 'scaleZ(${_formatDouble(sz)})';
}

String? _normalizePerspective(List<String> args) {
  final distance = args.isNotEmpty ? _parseLength(args[0]) : 0.0;
  return 'perspective(${_formatDouble(distance)})';
}

String? _normalizeMatrix3d(List<String> args) {
  if (args.length < 16) {
    return null;
  }

  final values = args
      .take(16)
      .map((part) => _parseNumber(part, fallback: 0.0))
      .map(_formatDouble)
      .join(', ');
  return 'matrix3d($values)';
}
