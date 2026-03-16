part of 'svg_parser.dart';

/// Парсит число или пару чисел (например "5" или "5 10")
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

/// Парсит числовое значение (может содержать единицы измерения)
double _parseNumber(String value) {
  // Убираем единицы измерения и пробелы
  final cleaned = value.trim().replaceAll(RegExp(r'[a-zA-Z%]+$'), '');
  return double.tryParse(cleaned) ?? 0.0;
}

/// Парсит viewBox атрибут
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

/// Парсит длину (может быть число, px, em, %, etc.)
double? _parseLength(String? length) {
  if (length == null || length.isEmpty) {
    return null;
  }

  return _parseNumber(length);
}
