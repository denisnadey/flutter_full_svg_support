part of 'animated_svg_painter.dart';

extension AnimatedSvgPainterValuesExtension on AnimatedSvgPainter {
  String? _resolveCssRuleValue(SvgNode node, String property) {
    final normalizedProperty = property.trim().toLowerCase();

    if (_currentUseContext != null) {
      return _currentUseContext!.resolveCssRuleValue(node, normalizedProperty);
    }

    final resolver = _currentDocumentCssResolver;
    if (resolver == null) {
      return null;
    }
    return resolver.resolveFromStyleRulesOnly(node, normalizedProperty);
  }

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
      final cleaned = value.trim().replaceAll(RegExp(r'[a-zA-Z%]+$'), '');
      return double.tryParse(cleaned);
    }

    return null;
  }

  double? _getLengthWithViewportSupport(
    SvgNode node,
    String attributeName, {
    required bool isHorizontal,
  }) {
    final raw = node.getRawAttributeValue(attributeName)?.trim();
    final fallback = _getNumber(node, attributeName);
    if (raw == null || raw.isEmpty) {
      return fallback;
    }

    if (raw.endsWith('%')) {
      final percent = double.tryParse(raw.substring(0, raw.length - 1));
      if (percent == null) {
        return fallback;
      }
      final viewportSize = _resolveNearestViewportSize(node);
      final viewportDimension = isHorizontal
          ? viewportSize.width
          : viewportSize.height;
      return (percent / 100.0) * viewportDimension;
    }

    final cleaned = raw.replaceAll(RegExp(r'[a-zA-Z]+$'), '');
    return double.tryParse(cleaned) ?? fallback;
  }

  ui.Size _resolveNearestViewportSize(SvgNode node) {
    SvgNode? current = node.parent;
    while (current != null) {
      if (current.tagName == 'svg' || current.tagName == 'symbol') {
        final viewBox = _parseViewBox(_getString(current, 'viewBox'));
        if (viewBox != null && viewBox.width > 0 && viewBox.height > 0) {
          return ui.Size(viewBox.width, viewBox.height);
        }

        final width = _getNumber(current, 'width');
        final height = _getNumber(current, 'height');
        if (width != null && height != null && width > 0 && height > 0) {
          return ui.Size(width, height);
        }
      }

      if (current.tagName == 'foreignObject') {
        final width = _getNumber(current, 'width') ?? 0.0;
        final height = _getNumber(current, 'height') ?? 0.0;
        if (width > 0 && height > 0) {
          return ui.Size(width, height);
        }
      }

      current = current.parent;
    }

    final rootViewBox = document.activeViewBox;
    if (rootViewBox != null &&
        rootViewBox.width > 0 &&
        rootViewBox.height > 0) {
      return ui.Size(rootViewBox.width, rootViewBox.height);
    }

    final docWidth = document.width;
    final docHeight = document.height;
    if (docWidth != null &&
        docHeight != null &&
        docWidth > 0 &&
        docHeight > 0) {
      return ui.Size(docWidth, docHeight);
    }

    return const ui.Size(100, 100);
  }

  /// SVG/CSS properties that are NOT inherited per spec.
  /// These should only be read from the node itself, not from ancestors.
  /// Per CSS spec: opacity creates a stacking context and is NOT inherited.
  /// Per SVG spec: filter, mask, clip-path are NOT inherited.
  static const _nonInheritedProperties = {
    'opacity',
    'filter',
    'mask',
    'clip-path',
    'overflow',
  };

  bool _isInheritKeyword(Object? value) {
    if (value == null) {
      return false;
    }
    return value.toString().trim().toLowerCase() == 'inherit';
  }

  Object? _getInheritedAttributeValue(SvgNode node, String attributeName) {
    final normalizedName = attributeName.trim().toLowerCase();
    SvgNode? current = node;
    bool explicitInheritRequested = false;

    // First check the node itself for inline style or explicit attribute
    final nodeStyleValue = _extractStyleValue(node, normalizedName);
    if (nodeStyleValue != null) {
      // Check for !important - it wins over everything else
      if (nodeStyleValue.contains('!important')) {
        final cleaned = nodeStyleValue
            .replaceFirst(
              RegExp(r'\s*!important\s*$', caseSensitive: false),
              '',
            )
            .trim();
        if (_isInheritKeyword(cleaned)) {
          explicitInheritRequested = true;
        } else {
          return cleaned;
        }
      } else if (_isInheritKeyword(nodeStyleValue)) {
        explicitInheritRequested = true;
      } else {
        return nodeStyleValue;
      }
    }

    // Check CSS rules from document's <style> blocks for this node.
    // CSS rules have higher specificity than presentation attributes.
    // This allows CSS class/id rules to apply to use-referenced elements.
    final cssRuleValue = _resolveCssRuleValue(node, normalizedName);

    // Check presentation attribute on the node itself
    final nodeAttrValue = node.getAttributeValue(attributeName);

    // CSS rule > presentation attribute (per CSS cascade spec)
    if (cssRuleValue != null) {
      if (_isInheritKeyword(cssRuleValue)) {
        explicitInheritRequested = true;
      } else {
        return cssRuleValue;
      }
    }
    if (nodeAttrValue != null) {
      if (_isInheritKeyword(nodeAttrValue)) {
        explicitInheritRequested = true;
      } else {
        return nodeAttrValue;
      }
    }

    // Non-inherited properties: only check the node itself, never walk up
    // the parent chain. Per CSS spec, opacity creates a stacking context and
    // is NOT inherited. Group opacity is applied via saveLayer in
    // _paintGroupWithOpacity; child paints must NOT re-apply it.
    if (_nonInheritedProperties.contains(normalizedName) &&
        !explicitInheritRequested) {
      return null;
    }

    // Walk up the parent chain looking for inherited values
    current = node.parent;
    while (current != null) {
      // Check inline style first
      final styleValue = _extractStyleValue(current, normalizedName);
      if (styleValue != null) {
        if (_isInheritKeyword(styleValue)) {
          current = current.parent;
          continue;
        }
        return styleValue;
      }

      // Check CSS rules for this ancestor.
      final ancestorCssValue = _resolveCssRuleValue(current, normalizedName);
      if (ancestorCssValue != null) {
        if (_isInheritKeyword(ancestorCssValue)) {
          current = current.parent;
          continue;
        }
        return ancestorCssValue;
      }

      // Check presentation attribute
      final value = current.getAttributeValue(attributeName);
      if (value != null) {
        if (_isInheritKeyword(value)) {
          current = current.parent;
          continue;
        }
        return value;
      }
      current = current.parent;
    }

    // Check use inheritance context for CSS properties inherited through <use>
    // boundaries. This implements the shadow DOM inheritance semantics.
    if (_currentUseContext != null) {
      final useValue = _currentUseContext!.getInheritedValue(attributeName);
      if (useValue != null && !_isInheritKeyword(useValue)) {
        return useValue;
      }
    }

    return null;
  }

  /// Returns the node where an inherited property value is defined.
  ///
  /// This is used for context-sensitive values like `currentColor` so that the
  /// value is resolved in the scope where the property was declared.
  SvgNode? _findInheritedAttributeSourceNode(
    SvgNode node,
    String attributeName,
  ) {
    final normalizedName = attributeName.trim().toLowerCase();
    bool explicitInheritRequested = false;

    final nodeStyleValue = _extractStyleValue(node, normalizedName);
    if (nodeStyleValue != null) {
      final cleaned = nodeStyleValue
          .replaceFirst(RegExp(r'\s*!important\s*$', caseSensitive: false), '')
          .trim();
      if (_isInheritKeyword(cleaned)) {
        explicitInheritRequested = true;
      } else {
        return node;
      }
    }

    if (_currentUseContext != null) {
      final cssRuleValue = _currentUseContext!.resolveCssRuleValue(
        node,
        normalizedName,
      );
      if (cssRuleValue != null) {
        if (_isInheritKeyword(cssRuleValue)) {
          explicitInheritRequested = true;
        } else {
          return node;
        }
      }
    }

    final nodeAttrValue = node.getAttributeValue(attributeName);
    if (nodeAttrValue != null) {
      if (_isInheritKeyword(nodeAttrValue)) {
        explicitInheritRequested = true;
      } else {
        return node;
      }
    }

    if (_nonInheritedProperties.contains(normalizedName) &&
        !explicitInheritRequested) {
      return null;
    }

    SvgNode? current = node.parent;
    while (current != null) {
      final styleValue = _extractStyleValue(current, normalizedName);
      if (styleValue != null) {
        if (_isInheritKeyword(styleValue)) {
          current = current.parent;
          continue;
        }
        return current;
      }

      if (_currentUseContext != null) {
        final ancestorCssValue = _currentUseContext!.resolveCssRuleValue(
          current,
          normalizedName,
        );
        if (ancestorCssValue != null) {
          if (_isInheritKeyword(ancestorCssValue)) {
            current = current.parent;
            continue;
          }
          return current;
        }
      }

      final value = current.getAttributeValue(attributeName);
      if (value != null) {
        if (_isInheritKeyword(value)) {
          current = current.parent;
          continue;
        }
        return current;
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

    if (str.isEmpty || str == 'none') return null;
    if (str == 'transparent') return const ui.Color(0x00000000);

    if (str.startsWith('#')) {
      return _parseHexColor(str);
    }

    final rgbColor = _parseRgbColor(str);
    if (rgbColor != null) {
      return rgbColor;
    }

    final hslColor = _parseHslColor(str);
    if (hslColor != null) {
      return hslColor;
    }

    // Defensive: parse Flutter's Color.toString() representation.
    // This can appear when typed color attributes are stringified by
    // intermediate cascade paths.
    final flutterColorMatch = RegExp(
      r'^color\(\s*alpha:\s*([0-9]*\.?[0-9]+)\s*,\s*red:\s*([0-9]*\.?[0-9]+)\s*,\s*green:\s*([0-9]*\.?[0-9]+)\s*,\s*blue:\s*([0-9]*\.?[0-9]+)',
    ).firstMatch(str);
    if (flutterColorMatch != null) {
      final alpha = double.tryParse(flutterColorMatch.group(1)!) ?? 1.0;
      final red = double.tryParse(flutterColorMatch.group(2)!) ?? 0.0;
      final green = double.tryParse(flutterColorMatch.group(3)!) ?? 0.0;
      final blue = double.tryParse(flutterColorMatch.group(4)!) ?? 0.0;
      return ui.Color.from(
        alpha: alpha.clamp(0.0, 1.0),
        red: red.clamp(0.0, 1.0),
        green: green.clamp(0.0, 1.0),
        blue: blue.clamp(0.0, 1.0),
      );
    }

    return cssNamedColors[str];
  }

  ui.Color? _parseHexColor(String value) {
    var hex = value.substring(1);

    // #RGB -> #RRGGBB
    if (hex.length == 3) {
      hex = hex.split('').map((char) => '$char$char').join();
    }

    // #RGBA -> #RRGGBBAA
    if (hex.length == 4) {
      hex = hex.split('').map((char) => '$char$char').join();
    }

    if (hex.length == 6) {
      final parsed = int.tryParse(hex, radix: 16);
      if (parsed == null) return null;
      return ui.Color(0xFF000000 | parsed);
    }

    if (hex.length == 8) {
      // CSS/SVG 8-digit hex is #RRGGBBAA; Flutter expects AARRGGBB.
      final parsed = int.tryParse(hex, radix: 16);
      if (parsed == null) return null;
      final r = (parsed >> 24) & 0xFF;
      final g = (parsed >> 16) & 0xFF;
      final b = (parsed >> 8) & 0xFF;
      final a = parsed & 0xFF;
      return ui.Color((a << 24) | (r << 16) | (g << 8) | b);
    }

    return null;
  }

  ui.Color? _parseRgbColor(String value) {
    final match = RegExp(r'^rgba?\(\s*(.+)\s*\)$').firstMatch(value);
    if (match == null) return null;

    final args = _parseColorFunctionArgs(match.group(1)!);
    if (args.length < 3) return null;

    late final int r;
    late final int g;
    late final int b;
    var alpha = 1.0;

    if (args.contains('/')) {
      final slashIndex = args.indexOf('/');
      if (slashIndex != 3 || args.length != 5) {
        return null;
      }
      r = _parseRgbChannel(args[0]);
      g = _parseRgbChannel(args[1]);
      b = _parseRgbChannel(args[2]);
      alpha = _parseAlpha(args[4]);
    } else {
      r = _parseRgbChannel(args[0]);
      g = _parseRgbChannel(args[1]);
      b = _parseRgbChannel(args[2]);
      if (args.length >= 4) {
        alpha = _parseAlpha(args[3]);
      }
    }

    return _colorFromRgba(r, g, b, alpha);
  }

  ui.Color? _parseHslColor(String value) {
    final match = RegExp(r'^hsla?\(\s*(.+)\s*\)$').firstMatch(value);
    if (match == null) return null;

    final args = _parseColorFunctionArgs(match.group(1)!);
    if (args.length < 3) return null;

    late final double hue;
    late final double saturation;
    late final double lightness;
    var alpha = 1.0;

    if (args.contains('/')) {
      final slashIndex = args.indexOf('/');
      if (slashIndex != 3 || args.length != 5) {
        return null;
      }
      hue = _parseHueDegrees(args[0]);
      saturation = _parseFraction(args[1]);
      lightness = _parseFraction(args[2]);
      alpha = _parseAlpha(args[4]);
    } else {
      hue = _parseHueDegrees(args[0]);
      saturation = _parseFraction(args[1]);
      lightness = _parseFraction(args[2]);
      if (args.length >= 4) {
        alpha = _parseAlpha(args[3]);
      }
    }

    return _hslToColor(hue, saturation, lightness, alpha);
  }

  List<String> _parseColorFunctionArgs(String input) {
    if (input.contains(',')) {
      return input
          .split(',')
          .map((part) => part.trim())
          .where((part) => part.isNotEmpty)
          .toList();
    }

    return input
        .replaceAll('/', ' / ')
        .split(RegExp(r'\s+'))
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
  }

  int _parseRgbChannel(String input) {
    final value = input.trim();
    if (value.endsWith('%')) {
      final percent =
          double.tryParse(value.substring(0, value.length - 1)) ?? 0.0;
      final normalized = percent.clamp(0.0, 100.0) / 100.0;
      return (normalized * 255).round().clamp(0, 255);
    }

    final number = double.tryParse(value) ?? 0.0;
    return number.clamp(0.0, 255.0).round();
  }

  double _parseAlpha(String input) {
    final value = input.trim();
    if (value.endsWith('%')) {
      final percent =
          double.tryParse(value.substring(0, value.length - 1)) ?? 0.0;
      return (percent.clamp(0.0, 100.0) / 100.0).toDouble();
    }

    final alpha = double.tryParse(value) ?? 1.0;
    return alpha.clamp(0.0, 1.0).toDouble();
  }

  double _parseFraction(String input) {
    final value = input.trim();
    if (value.endsWith('%')) {
      final percent =
          double.tryParse(value.substring(0, value.length - 1)) ?? 0.0;
      return (percent.clamp(0.0, 100.0) / 100.0).toDouble();
    }

    final number = double.tryParse(value) ?? 0.0;
    return number.clamp(0.0, 1.0).toDouble();
  }

  double _parseHueDegrees(String input) {
    final match = RegExp(
      r'^([+-]?(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?)\s*(deg|rad|turn|grad)?$',
      caseSensitive: false,
    ).firstMatch(input.trim());
    if (match == null) {
      return 0.0;
    }

    final numericValue = double.tryParse(match.group(1) ?? '') ?? 0.0;
    final unit = (match.group(2) ?? 'deg').toLowerCase();
    return switch (unit) {
      'deg' => numericValue,
      'rad' => numericValue * 180.0 / math.pi,
      'turn' => numericValue * 360.0,
      'grad' => numericValue * 0.9,
      _ => numericValue,
    };
  }

  ui.Color _colorFromRgba(int r, int g, int b, double alpha) {
    final a = (alpha.clamp(0.0, 1.0) * 255).round();
    return ui.Color((a << 24) | (r << 16) | (g << 8) | b);
  }

  ui.Color _hslToColor(
    double hueDegrees,
    double saturation,
    double lightness,
    double alpha,
  ) {
    final h = ((hueDegrees % 360.0) + 360.0) % 360.0 / 360.0;
    final s = saturation.clamp(0.0, 1.0).toDouble();
    final l = lightness.clamp(0.0, 1.0).toDouble();

    if (s == 0.0) {
      final gray = (l * 255).round();
      return _colorFromRgba(gray, gray, gray, alpha);
    }

    final q = l < 0.5 ? l * (1 + s) : l + s - l * s;
    final p = 2 * l - q;

    final r = _hueToRgb(p, q, h + (1 / 3));
    final g = _hueToRgb(p, q, h);
    final b = _hueToRgb(p, q, h - (1 / 3));
    return _colorFromRgba(
      (r * 255).round(),
      (g * 255).round(),
      (b * 255).round(),
      alpha,
    );
  }

  double _hueToRgb(double p, double q, double t) {
    var normalizedT = t;
    if (normalizedT < 0) normalizedT += 1;
    if (normalizedT > 1) normalizedT -= 1;
    if (normalizedT < 1 / 6) return p + (q - p) * 6 * normalizedT;
    if (normalizedT < 1 / 2) return q;
    if (normalizedT < 2 / 3) return p + (q - p) * (2 / 3 - normalizedT) * 6;
    return p;
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

  /// Resolves the textPath method attribute.
  /// - align (default): Render glyphs along path with their natural spacing
  /// - stretch: Scale glyphs uniformly to fill the path
  _SvgTextPathMethod _resolveTextPathMethod(SvgNode node) {
    final value = _getString(node, 'method')?.trim().toLowerCase();
    switch (value) {
      case 'stretch':
        return _SvgTextPathMethod.stretch;
      case 'align':
      default:
        return _SvgTextPathMethod.align;
    }
  }

  /// Computes the accumulated scale factor from the transform chain.
  /// Used for vector-effect: non-scaling-stroke.
  /// Returns the geometric mean of sx and sy scale factors.
  double _computeAccumulatedScale(SvgNode node) {
    final scales = _computeAccumulatedScaleXY(node);
    // Return geometric mean of scales
    final scale = math.sqrt(scales.dx * scales.dy);
    return scale > 0 ? scale : 1.0;
  }

  /// Computes the accumulated non-uniform scale factors (sx, sy) from the transform chain.
  ///
  /// Returns an Offset where dx = scaleX and dy = scaleY.
  /// This is useful for text rendering under non-uniform transforms where
  /// text metrics and glyph positioning need to account for different
  /// horizontal and vertical scaling.
  ui.Offset _computeAccumulatedScaleXY(SvgNode node) {
    var accumulatedMatrix = Matrix4.identity();

    // Walk up from current node to root, collecting transforms
    final transformStack = <Matrix4>[];
    SvgNode? current = node;
    while (current != null) {
      final transformStr = _getString(current, 'transform');
      if (transformStr != null && transformStr.isNotEmpty) {
        final nodeMatrix = _buildTransformMatrixFromValue(transformStr);
        if (nodeMatrix != null) {
          transformStack.add(nodeMatrix);
        }
      }
      current = current.parent;
    }

    // Apply transforms in reverse order (root to current)
    for (int i = transformStack.length - 1; i >= 0; i--) {
      accumulatedMatrix = accumulatedMatrix.multiplied(transformStack[i]);
    }

    // Extract scale from the accumulated matrix
    final sx = math.sqrt(
      accumulatedMatrix.entry(0, 0) * accumulatedMatrix.entry(0, 0) +
          accumulatedMatrix.entry(1, 0) * accumulatedMatrix.entry(1, 0),
    );
    final sy = math.sqrt(
      accumulatedMatrix.entry(0, 1) * accumulatedMatrix.entry(0, 1) +
          accumulatedMatrix.entry(1, 1) * accumulatedMatrix.entry(1, 1),
    );

    return ui.Offset(sx > 0 ? sx : 1.0, sy > 0 ? sy : 1.0);
  }

  /// Resolves stroke-linecap attribute to Flutter StrokeCap.
  /// Default is butt per SVG spec.
  ui.StrokeCap _resolveStrokeLinecap(SvgNode node) {
    final value = _getInheritedString(node, 'stroke-linecap')?.toLowerCase();
    switch (value) {
      case 'round':
        return ui.StrokeCap.round;
      case 'square':
        return ui.StrokeCap.square;
      case 'butt':
      default:
        return ui.StrokeCap.butt;
    }
  }

  /// Resolves stroke-linejoin attribute to Flutter StrokeJoin.
  /// Default is miter per SVG spec.
  ui.StrokeJoin _resolveStrokeLinejoin(SvgNode node) {
    final value = _getInheritedString(node, 'stroke-linejoin')?.toLowerCase();
    switch (value) {
      case 'round':
        return ui.StrokeJoin.round;
      case 'bevel':
        return ui.StrokeJoin.bevel;
      case 'miter':
      default:
        return ui.StrokeJoin.miter;
    }
  }

  /// Resolves shape-rendering attribute to anti-alias flag.
  /// Default is true (anti-alias enabled).
  /// - auto, geometricPrecision: anti-alias enabled (true)
  /// - optimizeSpeed, crispEdges: anti-alias disabled (false)
  bool _resolveShapeRendering(SvgNode node) {
    final value = _getInheritedString(node, 'shape-rendering')?.toLowerCase();
    switch (value) {
      case 'optimizespeed':
      case 'crispedges':
        return false;
      case 'auto':
      case 'geometricprecision':
      default:
        return true;
    }
  }

  /// Resolves image-rendering attribute to Flutter FilterQuality.
  /// Default is medium.
  /// - auto: medium quality
  /// - optimizeSpeed, pixelated: no filtering (none)
  /// - optimizeQuality, smooth, high-quality: high quality
  ui.FilterQuality _resolveImageRendering(SvgNode node) {
    final value = _getInheritedString(node, 'image-rendering')?.toLowerCase();
    switch (value) {
      case 'optimizespeed':
      case 'pixelated':
        return ui.FilterQuality.none;
      case 'optimizequality':
      case 'smooth':
      case 'high-quality':
        return ui.FilterQuality.high;
      case 'auto':
      default:
        return ui.FilterQuality.medium;
    }
  }

  /// Resolves mix-blend-mode CSS property to Flutter BlendMode.
  /// Default is srcOver (normal).
  ui.BlendMode? _resolveMixBlendMode(SvgNode node) {
    final value = _getInheritedString(node, 'mix-blend-mode')?.toLowerCase();
    if (value == null || value == 'normal') {
      return null; // Use default srcOver
    }
    switch (value) {
      case 'multiply':
        return ui.BlendMode.multiply;
      case 'screen':
        return ui.BlendMode.screen;
      case 'overlay':
        return ui.BlendMode.overlay;
      case 'darken':
        return ui.BlendMode.darken;
      case 'lighten':
        return ui.BlendMode.lighten;
      case 'color-dodge':
        return ui.BlendMode.colorDodge;
      case 'color-burn':
        return ui.BlendMode.colorBurn;
      case 'hard-light':
        return ui.BlendMode.hardLight;
      case 'soft-light':
        return ui.BlendMode.softLight;
      case 'difference':
        return ui.BlendMode.difference;
      case 'exclusion':
        return ui.BlendMode.exclusion;
      case 'hue':
        return ui.BlendMode.hue;
      case 'saturation':
        return ui.BlendMode.saturation;
      case 'color':
        return ui.BlendMode.color;
      case 'luminosity':
        return ui.BlendMode.luminosity;
      case 'plus-lighter':
        return ui.BlendMode.plus;
      default:
        return null;
    }
  }

  /// Resolves `color-interpolation-filters` for a node.
  ///
  /// Per SVG spec, the default value is `linearRGB`.
  /// Returns true when filters should operate in linearRGB color space.
  bool _isLinearRGBFilterSpace(SvgNode node) {
    final value = _getInheritedString(
      node,
      'color-interpolation-filters',
    )?.trim().toLowerCase();
    // Per SVG spec, the initial (default) value is linearRGB.
    // Only returns false when explicitly set to sRGB.
    return value != 'srgb';
  }
}
