part of 'css_to_smil_converter.dart';

final RegExp _cssTransformFunctionRegex = RegExp(
  r'(translate|translatex|translatey|rotate|scale|scalex|scaley|skewx|skewy|matrix)\s*\(\s*([^)]+)\s*\)',
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

double _parseLength(String value) {
  return _parseNumber(value, fallback: 0.0);
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
