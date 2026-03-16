part of 'animated_svg_painter.dart';

extension AnimatedSvgPainterValuesExtension on AnimatedSvgPainter {
  /// Parses a space/comma-separated list of numbers from an attribute.
  /// Returns empty list if attribute is missing or empty.
  List<double> _getNumberList(SvgNode node, String attributeName) {
    final value = node.getAttributeValue(attributeName)?.toString();
    if (value == null || value.trim().isEmpty) {
      return const <double>[];
    }
    return value
        .trim()
        .split(RegExp(r'[\s,]+'))
        .map((s) => double.tryParse(s))
        .whereType<double>()
        .toList();
  }

  double? _getNumber(SvgNode node, String attributeName) {
    final value = node.getAttributeValue(attributeName);
    if (value == null) return null;

    if (value is num) {
      return value.toDouble();
    }

    if (value is String) {
      return double.tryParse(value);
    }

    return null;
  }

  Object? _getInheritedAttributeValue(SvgNode node, String attributeName) {
    final normalizedName = attributeName.trim().toLowerCase();
    SvgNode? current = node;
    while (current != null) {
      final styleValue = _extractStyleValue(current, normalizedName);
      if (styleValue != null) {
        return styleValue;
      }
      final value = current.getAttributeValue(attributeName);
      if (value != null) {
        return value;
      }
      current = current.parent;
    }
    return null;
  }

  String? _getInheritedString(SvgNode node, String attributeName) {
    final value = _getInheritedAttributeValue(node, attributeName);
    final str = value?.toString();
    if (str == null) {
      return null;
    }
    final trimmed = str.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  double? _getInheritedNumber(SvgNode node, String attributeName) {
    final value = _getInheritedAttributeValue(node, attributeName);
    if (value == null) {
      return null;
    }
    if (value is num) {
      return value.toDouble();
    }
    final raw = value.toString().trim();
    if (raw.isEmpty) {
      return null;
    }
    final cleaned = raw.replaceAll(RegExp(r'[a-zA-Z%]+$'), '');
    return double.tryParse(cleaned);
  }

  ui.FontWeight _resolveFontWeight(String? fontWeight) {
    if (fontWeight == null) {
      return ui.FontWeight.normal;
    }
    switch (fontWeight.toLowerCase()) {
      case '100':
      case 'thin':
        return ui.FontWeight.w100;
      case '200':
      case 'extralight':
      case 'extra-light':
        return ui.FontWeight.w200;
      case '300':
      case 'light':
        return ui.FontWeight.w300;
      case '500':
      case 'medium':
        return ui.FontWeight.w500;
      case '600':
      case 'semibold':
      case 'semi-bold':
        return ui.FontWeight.w600;
      case '700':
      case 'bold':
        return ui.FontWeight.w700;
      case '800':
      case 'extrabold':
      case 'extra-bold':
        return ui.FontWeight.w800;
      case '900':
      case 'black':
        return ui.FontWeight.w900;
      case '400':
      case 'normal':
      default:
        return ui.FontWeight.normal;
    }
  }

  ui.FontStyle _resolveFontStyle(String? fontStyle) {
    return fontStyle?.toLowerCase() == 'italic'
        ? ui.FontStyle.italic
        : ui.FontStyle.normal;
  }

  _SvgTextAnchor _resolveTextAnchor(String? anchorValue) {
    switch (anchorValue?.trim().toLowerCase()) {
      case 'middle':
        return _SvgTextAnchor.middle;
      case 'end':
        return _SvgTextAnchor.end;
      case 'start':
      default:
        return _SvgTextAnchor.start;
    }
  }

  ui.Rect? _parseViewBox(String? viewBoxValue) {
    if (viewBoxValue == null || viewBoxValue.trim().isEmpty) {
      return null;
    }

    final values = viewBoxValue
        .trim()
        .split(RegExp(r'[\s,]+'))
        .map(double.tryParse)
        .whereType<double>()
        .toList();

    if (values.length != 4 || values[2] <= 0 || values[3] <= 0) {
      return null;
    }

    return ui.Rect.fromLTWH(values[0], values[1], values[2], values[3]);
  }

  /// Получает строковое значение атрибута
  String? _getString(SvgNode node, String attributeName) {
    final value = node.getAttributeValue(attributeName);
    return value?.toString();
  }

  List<ui.Offset> _parsePoints(SvgNode node) {
    final pointsValue = _getString(node, 'points');
    if (pointsValue == null || pointsValue.trim().isEmpty) {
      return const <ui.Offset>[];
    }

    final numbers = pointsValue
        .trim()
        .split(RegExp(r'[\s,]+'))
        .map(double.tryParse)
        .whereType<double>()
        .toList();
    if (numbers.length < 2) {
      return const <ui.Offset>[];
    }

    final points = <ui.Offset>[];
    for (int i = 0; i + 1 < numbers.length; i += 2) {
      points.add(ui.Offset(numbers[i], numbers[i + 1]));
    }
    return points;
  }

  /// Парсит цвет из строки
  ui.Color? _parseColor(String colorStr) {
    final str = colorStr.trim().toLowerCase();

    // none
    if (str == 'none') return null;

    // Hex colors
    if (str.startsWith('#')) {
      final hex = str.substring(1);

      if (hex.length == 3) {
        // #RGB -> #RRGGBB
        final r = int.parse(hex[0] + hex[0], radix: 16);
        final g = int.parse(hex[1] + hex[1], radix: 16);
        final b = int.parse(hex[2] + hex[2], radix: 16);
        return ui.Color.fromARGB(255, r, g, b);
      } else if (hex.length == 6) {
        // #RRGGBB
        final value = int.parse(hex, radix: 16);
        return ui.Color(0xFF000000 | value);
      } else if (hex.length == 8) {
        // #RRGGBBAA
        final value = int.parse(hex, radix: 16);
        return ui.Color(value);
      }
    }

    return cssNamedColors[str];
  }

  /// Resolves the textPath spacing attribute.
  /// Default is `exact` per SVG spec.
  _SvgTextPathSpacing _resolveTextPathSpacing(SvgNode node) {
    final value = _getString(node, 'spacing')?.trim().toLowerCase();
    switch (value) {
      case 'auto':
        return _SvgTextPathSpacing.auto;
      case 'exact':
      default:
        return _SvgTextPathSpacing.exact;
    }
  }
}
