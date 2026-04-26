part of 'svg_parser.dart';

/// Parses a number or a pair of numbers (e.g. "5" or "5 10")
(double, double) _parseNumberOptionalNumber(String value) {
  final parts = value
      .trim()
      .split(RegExp(r'[\s,]+'))
      .map((s) => double.tryParse(s))
      .whereType<double>()
      .toList();

  if (parts.isEmpty) {
    return (0.0, 0.0);
  } else if (parts.length == 1) {
    return (parts[0], parts[0]);
  } else {
    return (parts[0], parts[1]);
  }
}

/// Parses a numeric value (may contain units)
double _parseNumber(String value) {
  // Strip units and whitespace
  final cleaned = value.trim().replaceAll(RegExp(r'[a-zA-Z%]+$'), '');
  return double.tryParse(cleaned) ?? 0.0;
}

/// Parses the viewBox attribute
ui.Rect? _parseViewBox(String? viewBox) {
  if (viewBox == null || viewBox.isEmpty) {
    return null;
  }

  final parts = viewBox
      .trim()
      .split(RegExp(r'[\s,]+'))
      .map((s) => double.tryParse(s))
      .whereType<double>()
      .toList();

  if (parts.length == 4) {
    return ui.Rect.fromLTWH(parts[0], parts[1], parts[2], parts[3]);
  }

  return null;
}

/// Parses a length value (can be a number, px, em, %, etc.)
double? _parseLength(String? length) {
  if (length == null || length.isEmpty) {
    return null;
  }

  return _parseNumber(length);
}
