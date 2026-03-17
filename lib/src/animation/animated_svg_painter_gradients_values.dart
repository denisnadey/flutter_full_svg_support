part of 'animated_svg_painter.dart';

extension AnimatedSvgPainterGradientValuesExtension on AnimatedSvgPainter {
  String? _extractPaintServerId(Object? value) {
    if (value == null) {
      return null;
    }
    final raw = value.toString().trim();
    if (raw.isEmpty) {
      return null;
    }

    final match = RegExp(
      'url\\(\\s*[\'"]?#([^\'"\\)\\s]+)[\'"]?\\s*\\)',
      caseSensitive: false,
    ).firstMatch(raw);
    return match?.group(1);
  }

  String? _extractHrefId(SvgNode node) {
    final href =
        node.getAttributeValue('href') ?? node.getAttributeValue('xlink:href');
    if (href == null) {
      return null;
    }

    final raw = href.toString().trim();
    if (raw.isEmpty) {
      return null;
    }

    if (raw.startsWith('#')) {
      return raw.substring(1);
    }

    return _extractPaintServerId(raw);
  }

  String? _extractImageHref(SvgNode node) {
    final rawHref =
        node.getAttributeValue('href') ?? node.getAttributeValue('xlink:href');
    if (rawHref == null) {
      return null;
    }
    final href = rawHref.toString().trim();
    return href.isEmpty ? null : href;
  }

  bool _isPaintNone(Object? value) {
    if (value is ui.Color && value.a <= 0) {
      return true;
    }
    final str = value?.toString().trim().toLowerCase();
    return str == 'none';
  }

  ui.Rect _normalizePaintBounds(ui.Rect bounds) {
    final width = bounds.width.abs() < 1e-6 ? 1.0 : bounds.width.abs();
    final height = bounds.height.abs() < 1e-6 ? 1.0 : bounds.height.abs();
    return ui.Rect.fromLTWH(bounds.left, bounds.top, width, height);
  }

  ui.TileMode _parseTileMode(Object? spreadMethod) {
    final value = spreadMethod?.toString().trim().toLowerCase();
    switch (value) {
      case 'repeat':
        return ui.TileMode.repeated;
      case 'reflect':
        return ui.TileMode.mirror;
      case 'pad':
      default:
        return ui.TileMode.clamp;
    }
  }

  ui.Color? _resolveColorValue(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is ui.Color) {
      return value;
    }
    return _parseColor(value.toString());
  }

  /// Resolves a color value for a node, supporting the 'currentColor' keyword
  /// and CSS variable references (var(--name, fallback)).
  /// currentColor refers to the inherited 'color' CSS property value.
  ui.Color? _resolveColorForNode(Object? value, SvgNode node) {
    if (value == null) {
      return null;
    }
    if (value is ui.Color) {
      return value;
    }

    var strValue = value.toString().trim();

    // Resolve CSS variable references before color parsing.
    // This handles fill: var(--my-color, blue) and similar patterns.
    if (strValue.contains('var(')) {
      strValue = CssVariableResolver.resolveValue(strValue, node);
    }

    final lowerValue = strValue.toLowerCase();
    if (lowerValue == 'currentcolor') {
      // Resolve the inherited 'color' property
      final colorProperty = _getInheritedString(node, 'color');
      if (colorProperty != null && colorProperty.isNotEmpty) {
        return _parseColor(colorProperty);
      }
      // Default to black if no color property is set
      return const ui.Color(0xFF000000);
    }

    return _parseColor(strValue);
  }

  ui.Color _applyOpacity(ui.Color color, double opacity) {
    final alpha = (color.a * opacity).clamp(0.0, 1.0);
    return color.withValues(alpha: alpha);
  }

  double _resolveGradientCoordinate(
    Object? rawValue, {
    required double defaultValue,
    required _GradientAxis axis,
    required ui.Rect bounds,
    required bool isUserSpaceOnUse,
  }) {
    final parsed = _parseGradientLength(rawValue, defaultValue: defaultValue);
    final value = parsed.value;

    if (!isUserSpaceOnUse) {
      final ratio = parsed.isPercent
          ? value / 100.0
          : _normalizeObjectBoundingBoxValue(value, rawValue);
      switch (axis) {
        case _GradientAxis.x:
          return bounds.left + bounds.width * ratio;
        case _GradientAxis.y:
          return bounds.top + bounds.height * ratio;
        case _GradientAxis.radius:
          return math.max(bounds.width, bounds.height) * ratio;
      }
    }

    if (parsed.isPercent) {
      switch (axis) {
        case _GradientAxis.x:
          return bounds.left + bounds.width * (value / 100.0);
        case _GradientAxis.y:
          return bounds.top + bounds.height * (value / 100.0);
        case _GradientAxis.radius:
          return math.max(bounds.width, bounds.height) * (value / 100.0);
      }
    }

    return value;
  }

  double _normalizeObjectBoundingBoxValue(double value, Object? rawValue) {
    if (rawValue is num && value.abs() > 1.0 && value.abs() <= 100.0) {
      // Parser converts "50%" into 50, restore the expected ratio.
      return value / 100.0;
    }
    return value;
  }

  _GradientLength _parseGradientLength(
    Object? rawValue, {
    required double defaultValue,
  }) {
    if (rawValue == null) {
      return _GradientLength(defaultValue, true);
    }

    if (rawValue is num) {
      return _GradientLength(rawValue.toDouble(), false);
    }

    final raw = rawValue.toString().trim();
    if (raw.isEmpty) {
      return _GradientLength(defaultValue, true);
    }

    if (raw.endsWith('%')) {
      final number = double.tryParse(raw.substring(0, raw.length - 1));
      if (number != null) {
        return _GradientLength(number, true);
      }
      return _GradientLength(defaultValue, true);
    }

    final parsed = double.tryParse(raw.replaceAll(RegExp(r'[a-zA-Z]+$'), ''));
    return _GradientLength(parsed ?? defaultValue, false);
  }

  double _parseStopOffset(Object? value) {
    final parsed = _parseGradientLength(value, defaultValue: 0.0);
    final normalized = parsed.isPercent
        ? parsed.value / 100.0
        : _normalizeObjectBoundingBoxValue(parsed.value, value);
    return normalized.clamp(0.0, 1.0);
  }

  double? _parseOpacityValue(Object? value) {
    if (value == null) {
      return null;
    }

    if (value is num) {
      final opacity = value.toDouble();
      return opacity > 1.0 && opacity <= 100.0 ? opacity / 100.0 : opacity;
    }

    final raw = value.toString().trim();
    if (raw.isEmpty) {
      return null;
    }

    if (raw.endsWith('%')) {
      final number = double.tryParse(raw.substring(0, raw.length - 1));
      return number == null ? null : number / 100.0;
    }

    return double.tryParse(raw);
  }

  /// Creates interpolated gradient stops for linearRGB color space.
  /// This approximates linear RGB interpolation by adding intermediate stops.
  List<_GradientStop> _createLinearRGBInterpolatedStops(
    List<_GradientStop> stops,
  ) {
    if (stops.length < 2) return stops;

    final result = <_GradientStop>[];
    const stepsPerSegment = 8; // Intermediate steps for smooth interpolation

    for (int i = 0; i < stops.length - 1; i++) {
      final start = stops[i];
      final end = stops[i + 1];

      // Convert start and end colors to linear RGB
      final startLinear = _srgbToLinear(start.color);
      final endLinear = _srgbToLinear(end.color);

      // Add start stop
      result.add(start);

      // Add intermediate stops interpolated in linear RGB space
      for (int step = 1; step < stepsPerSegment; step++) {
        final t = step / stepsPerSegment;
        final offset = start.offset + (end.offset - start.offset) * t;

        // Interpolate in linear RGB
        final linearR = startLinear[0] + (endLinear[0] - startLinear[0]) * t;
        final linearG = startLinear[1] + (endLinear[1] - startLinear[1]) * t;
        final linearB = startLinear[2] + (endLinear[2] - startLinear[2]) * t;
        final alpha = start.color.a + (end.color.a - start.color.a) * t;

        // Convert back to sRGB
        final color = _linearToSrgb(linearR, linearG, linearB, alpha);
        result.add(_GradientStop(offset: offset, color: color));
      }
    }

    // Add final stop
    result.add(stops.last);
    return result;
  }

  /// Converts sRGB color to linear RGB components.
  List<double> _srgbToLinear(ui.Color color) {
    return [
      _srgbChannelToLinear(color.r),
      _srgbChannelToLinear(color.g),
      _srgbChannelToLinear(color.b),
    ];
  }

  /// Converts a single sRGB channel value (0-1) to linear.
  double _srgbChannelToLinear(double value) {
    if (value <= 0.04045) {
      return value / 12.92;
    }
    return math.pow((value + 0.055) / 1.055, 2.4).toDouble();
  }

  /// Converts linear RGB back to sRGB color.
  ui.Color _linearToSrgb(
    double linearR,
    double linearG,
    double linearB,
    double alpha,
  ) {
    return ui.Color.from(
      alpha: alpha.clamp(0.0, 1.0),
      red: _linearChannelToSrgb(linearR),
      green: _linearChannelToSrgb(linearG),
      blue: _linearChannelToSrgb(linearB),
    );
  }

  /// Converts a single linear channel value to sRGB.
  double _linearChannelToSrgb(double value) {
    if (value <= 0.0031308) {
      return (12.92 * value).clamp(0.0, 1.0);
    }
    return (1.055 * math.pow(value, 1.0 / 2.4) - 0.055).clamp(0.0, 1.0);
  }
}
