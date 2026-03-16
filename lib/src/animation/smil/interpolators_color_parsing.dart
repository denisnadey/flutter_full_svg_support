part of 'interpolators.dart';

double? _toNumber(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    final cleaned = value.trim().replaceAll(RegExp(r'[a-zA-Z%]+$'), '');
    return double.tryParse(cleaned);
  }
  return null;
}

ui.Color? _toColor(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is ui.Color) {
    return value;
  }
  if (value is String) {
    return _parseColorString(value);
  }
  return null;
}

List<double>? _toNumberList(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is List<double>) {
    return value;
  }
  if (value is List) {
    return value.map((e) => _toNumber(e) ?? 0.0).toList();
  }
  if (value is String) {
    final parts = value
        .trim()
        .split(RegExp(r'[\s,]+'))
        .map(double.tryParse)
        .whereType<double>()
        .toList();
    return parts.isEmpty ? null : parts;
  }
  return null;
}

int _lerpInt(int a, int b, double t) {
  return (a + (b - a) * t).round().clamp(0, 255);
}

int _colorChannelToInt(double channel) {
  return (channel * 255.0).round().clamp(0, 255);
}

ui.Color? _parseColorString(String value) {
  final trimmed = value.trim().toLowerCase();

  if (trimmed == 'none' || trimmed == 'transparent') {
    return const ui.Color(0x00000000);
  }
  if (trimmed.startsWith('#')) {
    return _parseHexColor(trimmed);
  }
  if (trimmed.startsWith('rgb')) {
    return _parseRgbColor(trimmed);
  }
  return _namedColors[trimmed];
}

ui.Color? _parseHexColor(String hex) {
  var cleaned = hex.substring(1);

  if (cleaned.length == 3) {
    cleaned = cleaned.split('').map((c) => c + c).join();
  }
  if (cleaned.length == 6) {
    final value = int.tryParse('FF$cleaned', radix: 16);
    return value != null ? ui.Color(value) : null;
  }
  if (cleaned.length == 8) {
    final value = int.tryParse(cleaned, radix: 16);
    return value != null ? ui.Color(value) : null;
  }
  return null;
}

ui.Color? _parseRgbColor(String rgb) {
  final match = RegExp(
    r'rgba?\s*\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*(?:,\s*([\d.]+)\s*)?\)',
  ).firstMatch(rgb);

  if (match == null) {
    return null;
  }

  final r = int.tryParse(match.group(1)!) ?? 0;
  final g = int.tryParse(match.group(2)!) ?? 0;
  final b = int.tryParse(match.group(3)!) ?? 0;
  final a = match.group(4) != null
      ? (double.tryParse(match.group(4)!) ?? 1.0)
      : 1.0;

  return ui.Color.fromARGB(
    (a * 255).round(),
    r.clamp(0, 255),
    g.clamp(0, 255),
    b.clamp(0, 255),
  );
}

const Map<String, ui.Color> _namedColors = cssNamedColors;
