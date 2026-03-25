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

    // First check the node itself for inline style or explicit attribute
    final nodeStyleValue = _extractStyleValue(node, normalizedName);
    if (nodeStyleValue != null) {
      // Check for !important - it wins over everything else
      if (nodeStyleValue.contains('!important')) {
        return nodeStyleValue
            .replaceFirst(
              RegExp(r'\s*!important\s*$', caseSensitive: false),
              '',
            )
            .trim();
      }
      return nodeStyleValue;
    }

    // Check CSS rules from document's <style> blocks for this node.
    // CSS rules have higher specificity than presentation attributes.
    // This allows CSS class/id rules to apply to use-referenced elements.
    String? cssRuleValue;
    if (_currentUseContext != null) {
      cssRuleValue = _currentUseContext!.resolveCssRuleValue(
        node,
        normalizedName,
      );
    }

    // Check presentation attribute on the node itself
    final nodeAttrValue = node.getAttributeValue(attributeName);

    // CSS rule > presentation attribute (per CSS cascade spec)
    if (cssRuleValue != null) {
      return cssRuleValue;
    }
    if (nodeAttrValue != null) {
      return nodeAttrValue;
    }

    // Walk up the parent chain looking for inherited values
    current = node.parent;
    while (current != null) {
      // Check inline style first
      final styleValue = _extractStyleValue(current, normalizedName);
      if (styleValue != null) {
        return styleValue;
      }

      // Check CSS rules for this ancestor
      if (_currentUseContext != null) {
        final ancestorCssValue = _currentUseContext!.resolveCssRuleValue(
          current,
          normalizedName,
        );
        if (ancestorCssValue != null) {
          return ancestorCssValue;
        }
      }

      // Check presentation attribute
      final value = current.getAttributeValue(attributeName);
      if (value != null) {
        return value;
      }
      current = current.parent;
    }

    // Check use inheritance context for CSS properties inherited through <use>
    // boundaries. This implements the shadow DOM inheritance semantics.
    if (_currentUseContext != null) {
      final useValue = _currentUseContext!.getInheritedValue(attributeName);
      if (useValue != null) {
        return useValue;
      }
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
    // Use the geometric mean of x and y scales
    final sx = math.sqrt(
      accumulatedMatrix.entry(0, 0) * accumulatedMatrix.entry(0, 0) +
          accumulatedMatrix.entry(1, 0) * accumulatedMatrix.entry(1, 0),
    );
    final sy = math.sqrt(
      accumulatedMatrix.entry(0, 1) * accumulatedMatrix.entry(0, 1) +
          accumulatedMatrix.entry(1, 1) * accumulatedMatrix.entry(1, 1),
    );

    // Return geometric mean of scales
    final scale = math.sqrt(sx * sy);
    return scale > 0 ? scale : 1.0;
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
}
