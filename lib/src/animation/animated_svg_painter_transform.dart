part of 'animated_svg_painter.dart';

extension AnimatedSvgPainterCanvasTransformExtension on AnimatedSvgPainter {
  void _applyTransform(ui.Canvas canvas, SvgNode node) {
    final transformStr = _getString(node, 'transform');
    if (transformStr == null || transformStr.isEmpty) return;

    // Парсим трансформации
    final transforms = SvgTransform.parse(transformStr);
    if (transforms.isEmpty) return;

    // Check for transform-origin
    final origin = _parseTransformOrigin(node);
    final hasOrigin = origin != null && (origin.dx != 0.0 || origin.dy != 0.0);

    // Apply origin offset before transform
    if (hasOrigin) {
      canvas.translate(origin.dx, origin.dy);
    }

    // Применяем каждую трансформацию в порядке объявления
    for (final transform in transforms) {
      switch (transform.type) {
        case SvgTransformType.translate:
          final tx = transform.values.isNotEmpty ? transform.values[0] : 0.0;
          final ty = transform.values.length > 1 ? transform.values[1] : 0.0;
          canvas.translate(tx, ty);

        case SvgTransformType.rotate:
          final angle = transform.values.isNotEmpty ? transform.values[0] : 0.0;
          final cx = transform.values.length > 1 ? transform.values[1] : 0.0;
          final cy = transform.values.length > 2 ? transform.values[2] : 0.0;

          // Rotate with center point
          if (cx != 0.0 || cy != 0.0) {
            canvas.translate(cx, cy);
            canvas.rotate(angle * 3.14159 / 180.0); // degrees to radians
            canvas.translate(-cx, -cy);
          } else {
            canvas.rotate(angle * 3.14159 / 180.0);
          }

        case SvgTransformType.scale:
          final sx = transform.values.isNotEmpty ? transform.values[0] : 1.0;
          final sy = transform.values.length > 1
              ? transform.values[1]
              : sx; // sy defaults to sx
          canvas.scale(sx, sy);

        case SvgTransformType.skewX:
          final angle = transform.values.isNotEmpty ? transform.values[0] : 0.0;
          final radians = angle * 3.14159 / 180.0;
          final tanValue = radians.isFinite ? radians : 0.0;
          // skewX matrix: [1, tan(angle), 0]
          //               [0,     1,      0]
          //               [0,     0,      1]
          final matrix = Matrix4.identity()
            ..setEntry(0, 1, tanValue); // Set skewX component
          canvas.transform(matrix.storage);

        case SvgTransformType.skewY:
          final angle = transform.values.isNotEmpty ? transform.values[0] : 0.0;
          final radians = angle * 3.14159 / 180.0;
          final tanValue = radians.isFinite ? radians : 0.0;
          // skewY matrix: [    1,      0, 0]
          //               [tan(angle), 1, 0]
          //               [    0,      0, 1]
          final matrix = Matrix4.identity()
            ..setEntry(1, 0, tanValue); // Set skewY component
          canvas.transform(matrix.storage);

        case SvgTransformType.matrix:
          if (transform.values.length >= 6) {
            // SVG matrix(a, b, c, d, e, f) maps to:
            // [a  c  e]
            // [b  d  f]
            // [0  0  1]
            final a = transform.values[0];
            final b = transform.values[1];
            final c = transform.values[2];
            final d = transform.values[3];
            final e = transform.values[4];
            final f = transform.values[5];

            final matrix = Matrix4.identity()
              ..setEntry(0, 0, a) // m11
              ..setEntry(1, 0, b) // m21
              ..setEntry(0, 1, c) // m12
              ..setEntry(1, 1, d) // m22
              ..setEntry(0, 3, e) // m14 (translateX)
              ..setEntry(1, 3, f); // m24 (translateY)
            canvas.transform(matrix.storage);
          }
          break;
      }
    }

    // Translate back after transform
    if (hasOrigin) {
      canvas.translate(-origin.dx, -origin.dy);
    }
  }

  /// Parses the transform-origin CSS property.
  /// Supports keywords (center, left, right, top, bottom), percentages, and absolute values.
  /// Returns null if not set.
  ui.Offset? _parseTransformOrigin(SvgNode node) {
    final originObj = _getStyleOrAttributeValue(node, 'transform-origin');
    if (originObj == null) return null;
    final originValue = originObj.toString().trim();
    if (originValue.isEmpty) return null;

    final parts = originValue.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return null;

    // Get element bounds for percentage calculations
    final bounds = _getNodeBounds(node);

    double parseOriginValue(String value, double size, bool isX) {
      final lower = value.toLowerCase();
      // Handle keywords
      switch (lower) {
        case 'left':
          return 0.0;
        case 'center':
          return size / 2;
        case 'right':
          return size;
        case 'top':
          return 0.0;
        case 'bottom':
          return size;
      }
      // Handle percentage
      if (lower.endsWith('%')) {
        final percent = double.tryParse(lower.substring(0, lower.length - 1));
        if (percent != null) {
          return (percent / 100.0) * size;
        }
      }
      // Handle px or bare number
      final numValue = lower.replaceAll('px', '');
      return double.tryParse(numValue) ?? (size / 2);
    }

    final xValue = parts[0];
    final yValue = parts.length > 1 ? parts[1] : 'center';

    final x = parseOriginValue(xValue, bounds.width, true) + bounds.left;
    final y = parseOriginValue(yValue, bounds.height, false) + bounds.top;

    return ui.Offset(x, y);
  }

  /// Gets the bounding box of a node for transform-origin calculations.
  ui.Rect _getNodeBounds(SvgNode node) {
    final name = node.tagName.toLowerCase();
    switch (name) {
      case 'rect':
        final x = _getNumber(node, 'x') ?? 0.0;
        final y = _getNumber(node, 'y') ?? 0.0;
        final width = _getNumber(node, 'width') ?? 0.0;
        final height = _getNumber(node, 'height') ?? 0.0;
        return ui.Rect.fromLTWH(x, y, width, height);
      case 'circle':
        final cx = _getNumber(node, 'cx') ?? 0.0;
        final cy = _getNumber(node, 'cy') ?? 0.0;
        final r = _getNumber(node, 'r') ?? 0.0;
        return ui.Rect.fromCircle(center: ui.Offset(cx, cy), radius: r);
      case 'ellipse':
        final cx = _getNumber(node, 'cx') ?? 0.0;
        final cy = _getNumber(node, 'cy') ?? 0.0;
        final rx = _getNumber(node, 'rx') ?? 0.0;
        final ry = _getNumber(node, 'ry') ?? 0.0;
        return ui.Rect.fromCenter(
          center: ui.Offset(cx, cy),
          width: rx * 2,
          height: ry * 2,
        );
      case 'line':
        final x1 = _getNumber(node, 'x1') ?? 0.0;
        final y1 = _getNumber(node, 'y1') ?? 0.0;
        final x2 = _getNumber(node, 'x2') ?? 0.0;
        final y2 = _getNumber(node, 'y2') ?? 0.0;
        return ui.Rect.fromPoints(ui.Offset(x1, y1), ui.Offset(x2, y2));
      case 'image':
        final x = _getNumber(node, 'x') ?? 0.0;
        final y = _getNumber(node, 'y') ?? 0.0;
        final width = _getNumber(node, 'width') ?? 0.0;
        final height = _getNumber(node, 'height') ?? 0.0;
        return ui.Rect.fromLTWH(x, y, width, height);
      default:
        // For groups and complex shapes, use viewBox or return zero rect
        final viewBox = _getViewBox(node);
        return viewBox ?? ui.Rect.zero;
    }
  }

  /// Gets the viewBox for a node if available.
  ui.Rect? _getViewBox(SvgNode node) {
    final viewBoxStr = _getString(node, 'viewBox');
    if (viewBoxStr == null || viewBoxStr.isEmpty) return null;

    final parts = viewBoxStr.split(RegExp(r'[\s,]+'));
    if (parts.length < 4) return null;

    final x = double.tryParse(parts[0]) ?? 0.0;
    final y = double.tryParse(parts[1]) ?? 0.0;
    final w = double.tryParse(parts[2]) ?? 0.0;
    final h = double.tryParse(parts[3]) ?? 0.0;
    return ui.Rect.fromLTWH(x, y, w, h);
  }
}
