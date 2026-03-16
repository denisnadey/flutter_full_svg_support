part of 'animated_svg_picture.dart';

extension _AnimatedSvgPictureStateUtilsExtension on _AnimatedSvgPictureState {
  void _applyForeignObjectChildTransform(Matrix4 matrix, SvgNode node) {
    if (node.tagName != 'foreignObject') {
      return;
    }
    final width = _getNumber(node, 'width') ?? 0.0;
    final height = _getNumber(node, 'height') ?? 0.0;
    if (width <= 0 || height <= 0) {
      return;
    }
    final x = _getNumber(node, 'x') ?? 0.0;
    final y = _getNumber(node, 'y') ?? 0.0;
    matrix.translateByDouble(x, y, 0, 1);
  }

  void _applyNodeTransform(Matrix4 matrix, SvgNode node) {
    final transformAttr = node.getAttributeValue('transform')?.toString();
    if (transformAttr == null || transformAttr.isEmpty) return;

    final transforms = SvgTransform.parse(transformAttr);
    for (final transform in transforms) {
      switch (transform.type) {
        case SvgTransformType.translate:
          final tx = transform.values.isNotEmpty ? transform.values[0] : 0.0;
          final ty = transform.values.length > 1 ? transform.values[1] : 0.0;
          matrix.translateByDouble(tx, ty, 0, 1);
          break;
        case SvgTransformType.scale:
          final sx = transform.values.isNotEmpty ? transform.values[0] : 1.0;
          final sy = transform.values.length > 1 ? transform.values[1] : sx;
          matrix.scaleByDouble(sx, sy, 1, 1);
          break;
        case SvgTransformType.rotate:
          final angle = transform.values.isNotEmpty ? transform.values[0] : 0.0;
          final radians = angle * math.pi / 180.0;
          if (transform.values.length >= 3) {
            final cx = transform.values[1];
            final cy = transform.values[2];
            matrix
              ..translateByDouble(cx, cy, 0, 1)
              ..rotateZ(radians)
              ..translateByDouble(-cx, -cy, 0, 1);
          } else {
            matrix.rotateZ(radians);
          }
          break;
        case SvgTransformType.skewX:
          final angle = transform.values.isNotEmpty ? transform.values[0] : 0.0;
          final skew = Matrix4.identity()
            ..setEntry(0, 1, math.tan(angle * math.pi / 180.0));
          matrix.multiply(skew);
          break;
        case SvgTransformType.skewY:
          final angle = transform.values.isNotEmpty ? transform.values[0] : 0.0;
          final skew = Matrix4.identity()
            ..setEntry(1, 0, math.tan(angle * math.pi / 180.0));
          matrix.multiply(skew);
          break;
        case SvgTransformType.matrix:
          if (transform.values.length >= 6) {
            final a = transform.values[0];
            final b = transform.values[1];
            final c = transform.values[2];
            final d = transform.values[3];
            final e = transform.values[4];
            final f = transform.values[5];
            final custom = Matrix4.identity()
              ..setEntry(0, 0, a)
              ..setEntry(1, 0, b)
              ..setEntry(0, 1, c)
              ..setEntry(1, 1, d)
              ..setEntry(0, 3, e)
              ..setEntry(1, 3, f);
            matrix.multiply(custom);
          }
          break;
      }
    }
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

    if (raw.startsWith('#') && raw.length > 1) {
      return raw.substring(1);
    }

    final urlMatch = RegExp(
      r'''url\(\s*['"]?#([^'")\s]+)['"]?\s*\)''',
      caseSensitive: false,
    ).firstMatch(raw);
    return urlMatch?.group(1);
  }

  String? _extractStyleValue(SvgNode node, String property) {
    final style = node.getAttributeValue('style')?.toString();
    if (style == null || style.trim().isEmpty) {
      return null;
    }

    for (final declaration in style.split(';')) {
      final parts = declaration.split(':');
      if (parts.length < 2) {
        continue;
      }
      final key = parts.first.trim().toLowerCase();
      if (key != property) {
        continue;
      }
      final value = parts.sublist(1).join(':').trim();
      final normalizedValue = value
          .replaceFirst(RegExp(r'\s*!important\s*$', caseSensitive: false), '')
          .trim();
      if (normalizedValue.isNotEmpty) {
        return normalizedValue;
      }
    }
    return null;
  }

  double? _getNumber(SvgNode node, String attributeName) {
    final value = node.getAttributeValue(attributeName);
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      final cleaned = value.trim().replaceAll(RegExp(r'[a-zA-Z%]+$'), '');
      return double.tryParse(cleaned);
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

  String? _extractTextContent(SvgNode node) {
    final raw = node.getAttributeValue('__text')?.toString();
    if (raw == null) {
      return null;
    }
    final normalized = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    return normalized.isEmpty ? null : normalized;
  }

  FontWeight _resolveFontWeight(String? fontWeight) {
    if (fontWeight == null) {
      return FontWeight.normal;
    }
    switch (fontWeight.toLowerCase()) {
      case '100':
      case 'thin':
        return FontWeight.w100;
      case '200':
      case 'extralight':
      case 'extra-light':
        return FontWeight.w200;
      case '300':
      case 'light':
        return FontWeight.w300;
      case '500':
      case 'medium':
        return FontWeight.w500;
      case '600':
      case 'semibold':
      case 'semi-bold':
        return FontWeight.w600;
      case '700':
      case 'bold':
        return FontWeight.w700;
      case '800':
      case 'extrabold':
      case 'extra-bold':
        return FontWeight.w800;
      case '900':
      case 'black':
        return FontWeight.w900;
      case '400':
      case 'normal':
      default:
        return FontWeight.normal;
    }
  }

  FontStyle _resolveFontStyle(String? fontStyle) {
    return fontStyle?.toLowerCase() == 'italic'
        ? FontStyle.italic
        : FontStyle.normal;
  }

  double _distanceToSegment(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final ap = p - a;
    final abLengthSquared = ab.dx * ab.dx + ab.dy * ab.dy;
    if (abLengthSquared == 0) {
      return (p - a).distance;
    }

    final t = ((ap.dx * ab.dx + ap.dy * ab.dy) / abLengthSquared).clamp(
      0.0,
      1.0,
    );
    final projection = Offset(a.dx + ab.dx * t, a.dy + ab.dy * t);
    return (p - projection).distance;
  }

  List<Offset> _parsePoints(SvgNode node) {
    final value = node.getAttributeValue('points')?.toString();
    if (value == null || value.trim().isEmpty) {
      return const <Offset>[];
    }

    final numbers = value
        .trim()
        .split(RegExp(r'[\s,]+'))
        .map(double.tryParse)
        .whereType<double>()
        .toList();
    if (numbers.length < 2) {
      return const <Offset>[];
    }

    final points = <Offset>[];
    for (int i = 0; i + 1 < numbers.length; i += 2) {
      points.add(Offset(numbers[i], numbers[i + 1]));
    }
    return points;
  }

  bool _isFillEnabled(SvgNode node) {
    final fill = _getInheritedAttributeValue(node, 'fill');
    return !_isPaintNone(fill);
  }

  bool _hasStroke(SvgNode node) {
    final stroke = _getInheritedAttributeValue(node, 'stroke');
    return stroke != null && !_isPaintNone(stroke);
  }

  double _strokeTolerance(SvgNode node) {
    final strokeWidth = _getInheritedNumber(node, 'stroke-width') ?? 1.0;
    return (strokeWidth / 2).clamp(1.0, 8.0);
  }

  bool _isPaintNone(Object? value) {
    if (value is Color && value.a <= 0) {
      return true;
    }
    final str = value?.toString().trim().toLowerCase();
    return str == 'none';
  }

  bool _isPointerEventsNone(SvgNode node) {
    return _resolvePointerEventsMode(node) == 'none';
  }

  bool _isVisibilityHidden(SvgNode node) {
    final visibility = _getInheritedString(node, 'visibility')?.toLowerCase();
    return visibility == 'hidden' || visibility == 'collapse';
  }

  bool _isDisplayNone(SvgNode node) {
    final styleValue = _extractStyleValue(node, 'display');
    final rawValue = styleValue ?? node.getAttributeValue('display');
    final display = rawValue?.toString().trim().toLowerCase();
    return display == 'none';
  }

  void _trace({
    required String category,
    required String message,
    SvgTraceLevel level = SvgTraceLevel.info,
    Map<String, Object?> data = const <String, Object?>{},
    Object? error,
    StackTrace? stackTrace,
  }) {
    final callback = widget.onTrace;
    if (callback == null) {
      return;
    }
    callback(
      SvgTraceEvent(
        timestamp: DateTime.now(),
        level: level,
        category: category,
        message: message,
        data: data,
        error: error,
        stackTrace: stackTrace,
      ),
    );
  }
}
