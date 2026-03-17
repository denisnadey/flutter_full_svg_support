part of 'animated_svg_painter.dart';

extension AnimatedSvgPainterCanvasTransformExtension on AnimatedSvgPainter {
  void _applyTransform(ui.Canvas canvas, SvgNode node) {
    // Get both SVG transform attribute and CSS transform property
    // CSS transform property takes precedence over SVG transform attribute per spec
    final svgTransformStr = _getString(node, 'transform');
    final cssTransformStr = _getStyleOrAttributeValue(node, 'transform')?.toString();

    // Use CSS transform if available, otherwise fall back to SVG attribute
    // Note: In Blink, CSS transform overrides SVG transform completely
    final transformStr = cssTransformStr ?? svgTransformStr;
    if (transformStr == null ||
        transformStr.isEmpty ||
        transformStr.toLowerCase() == 'none') {
      return;
    }

    // Парсим трансформации
    final transforms = SvgTransform.parse(transformStr);
    if (transforms.isEmpty) return;

    // Check for transform-origin
    final origin = _parseTransformOrigin(node);
    final hasOrigin = origin != null && (origin.dx != 0.0 || origin.dy != 0.0);

    // Check for perspective property
    final perspectiveValue = _getPerspective(node);
    final hasPerspective = perspectiveValue != null && perspectiveValue > 0;

    // Check for backface-visibility
    final hideBackface =
        _getBackfaceVisibility(node) == BackfaceVisibility.hidden;

    // Apply origin offset before transform
    if (hasOrigin) {
      canvas.translate(origin.dx, origin.dy);
    }

    // Check if we have any 3D transforms
    final has3DTransform = transforms.any((t) => _is3DTransform(t.type));

    if (has3DTransform || hasPerspective) {
      // Build a 4x4 matrix for 3D transforms
      var matrix = Matrix4x4.identity();

      // Apply perspective first if present
      if (hasPerspective) {
        matrix = matrix * Matrix4x4.perspective(perspectiveValue);
      }

      // Apply each transform
      for (final transform in transforms) {
        matrix = matrix * _createMatrix4x4(transform);
      }

      // Check backface visibility
      if (hideBackface && matrix.isBackfacing()) {
        // Element is facing away, don't render
        // Set up a transform that puts everything at infinity (invisible)
        canvas.scale(0, 0);
        if (hasOrigin) {
          canvas.translate(-origin.dx, -origin.dy);
        }
        return;
      }

      // Extract 2D matrix and apply
      final matrix2d = matrix.extract2DMatrix();
      final flutterMatrix = Matrix4.identity()
        ..setEntry(0, 0, matrix2d[0]) // a
        ..setEntry(1, 0, matrix2d[1]) // b
        ..setEntry(0, 1, matrix2d[2]) // c
        ..setEntry(1, 1, matrix2d[3]) // d
        ..setEntry(0, 3, matrix2d[4]) // e (tx)
        ..setEntry(1, 3, matrix2d[5]); // f (ty)
      canvas.transform(flutterMatrix.storage);
    } else {
      // Apply 2D transforms directly (original behavior)
      for (final transform in transforms) {
        _apply2DTransform(canvas, transform);
      }
    }

    // Translate back after transform
    if (hasOrigin) {
      canvas.translate(-origin.dx, -origin.dy);
    }
  }

  /// Checks if a transform type is a 3D transform
  bool _is3DTransform(SvgTransformType type) {
    return type == SvgTransformType.translate3d ||
        type == SvgTransformType.translateZ ||
        type == SvgTransformType.scale3d ||
        type == SvgTransformType.scaleZ ||
        type == SvgTransformType.rotateX ||
        type == SvgTransformType.rotateY ||
        type == SvgTransformType.rotateZ ||
        type == SvgTransformType.rotate3d ||
        type == SvgTransformType.perspective ||
        type == SvgTransformType.matrix3d;
  }

  /// Creates a 4x4 matrix from an SvgTransform
  Matrix4x4 _createMatrix4x4(SvgTransform transform) {
    switch (transform.type) {
      case SvgTransformType.translate:
        final tx = transform.values.isNotEmpty ? transform.values[0] : 0.0;
        final ty = transform.values.length > 1 ? transform.values[1] : 0.0;
        return Matrix4x4.translation(tx, ty, 0);

      case SvgTransformType.translate3d:
        final tx = transform.values.isNotEmpty ? transform.values[0] : 0.0;
        final ty = transform.values.length > 1 ? transform.values[1] : 0.0;
        final tz = transform.values.length > 2 ? transform.values[2] : 0.0;
        return Matrix4x4.translation(tx, ty, tz);

      case SvgTransformType.translateZ:
        final tz = transform.values.isNotEmpty ? transform.values[0] : 0.0;
        return Matrix4x4.translation(0, 0, tz);

      case SvgTransformType.rotate:
        final angle = transform.values.isNotEmpty ? transform.values[0] : 0.0;
        final radians = angle * 3.14159265359 / 180.0;
        final cx = transform.values.length > 1 ? transform.values[1] : 0.0;
        final cy = transform.values.length > 2 ? transform.values[2] : 0.0;
        if (cx != 0.0 || cy != 0.0) {
          // Rotate around a point
          return Matrix4x4.translation(cx, cy, 0) *
              Matrix4x4.rotationZ(radians) *
              Matrix4x4.translation(-cx, -cy, 0);
        }
        return Matrix4x4.rotationZ(radians);

      case SvgTransformType.rotateX:
        final angle = transform.values.isNotEmpty ? transform.values[0] : 0.0;
        final radians = angle * 3.14159265359 / 180.0;
        return Matrix4x4.rotationX(radians);

      case SvgTransformType.rotateY:
        final angle = transform.values.isNotEmpty ? transform.values[0] : 0.0;
        final radians = angle * 3.14159265359 / 180.0;
        return Matrix4x4.rotationY(radians);

      case SvgTransformType.rotateZ:
        final angle = transform.values.isNotEmpty ? transform.values[0] : 0.0;
        final radians = angle * 3.14159265359 / 180.0;
        return Matrix4x4.rotationZ(radians);

      case SvgTransformType.rotate3d:
        if (transform.values.length >= 4) {
          final x = transform.values[0];
          final y = transform.values[1];
          final z = transform.values[2];
          final angle = transform.values[3];
          final radians = angle * 3.14159265359 / 180.0;
          return Matrix4x4.rotation3d(x, y, z, radians);
        }
        return Matrix4x4.identity();

      case SvgTransformType.scale:
        final sx = transform.values.isNotEmpty ? transform.values[0] : 1.0;
        final sy = transform.values.length > 1 ? transform.values[1] : sx;
        return Matrix4x4.scale(sx, sy, 1);

      case SvgTransformType.scale3d:
        final sx = transform.values.isNotEmpty ? transform.values[0] : 1.0;
        final sy = transform.values.length > 1 ? transform.values[1] : 1.0;
        final sz = transform.values.length > 2 ? transform.values[2] : 1.0;
        return Matrix4x4.scale(sx, sy, sz);

      case SvgTransformType.scaleZ:
        final sz = transform.values.isNotEmpty ? transform.values[0] : 1.0;
        return Matrix4x4.scale(1, 1, sz);

      case SvgTransformType.skewX:
        final angle = transform.values.isNotEmpty ? transform.values[0] : 0.0;
        final radians = angle * 3.14159265359 / 180.0;
        final matrix = Matrix4x4.identity();
        matrix.set(0, 1, math.tan(radians));
        return matrix;

      case SvgTransformType.skewY:
        final angle = transform.values.isNotEmpty ? transform.values[0] : 0.0;
        final radians = angle * 3.14159265359 / 180.0;
        final matrix = Matrix4x4.identity();
        matrix.set(1, 0, math.tan(radians));
        return matrix;

      case SvgTransformType.matrix:
        if (transform.values.length >= 6) {
          return Matrix4x4.from2dMatrix(transform.values);
        }
        return Matrix4x4.identity();

      case SvgTransformType.matrix3d:
        if (transform.values.length >= 16) {
          return Matrix4x4.fromMatrix3d(transform.values);
        }
        return Matrix4x4.identity();

      case SvgTransformType.perspective:
        final distance = transform.values.isNotEmpty
            ? transform.values[0]
            : 0.0;
        if (distance > 0) {
          return Matrix4x4.perspective(distance);
        }
        return Matrix4x4.identity();
    }
  }

  /// Applies a 2D transform directly to the canvas (original behavior)
  void _apply2DTransform(ui.Canvas canvas, SvgTransform transform) {
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
        final matrix = Matrix4.identity()
          ..setEntry(0, 1, tanValue); // Set skewX component
        canvas.transform(matrix.storage);

      case SvgTransformType.skewY:
        final angle = transform.values.isNotEmpty ? transform.values[0] : 0.0;
        final radians = angle * 3.14159 / 180.0;
        final tanValue = radians.isFinite ? radians : 0.0;
        final matrix = Matrix4.identity()
          ..setEntry(1, 0, tanValue); // Set skewY component
        canvas.transform(matrix.storage);

      case SvgTransformType.matrix:
        if (transform.values.length >= 6) {
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

      // 3D transforms in 2D mode - just ignore Z components
      case SvgTransformType.translate3d:
        final tx = transform.values.isNotEmpty ? transform.values[0] : 0.0;
        final ty = transform.values.length > 1 ? transform.values[1] : 0.0;
        canvas.translate(tx, ty);

      case SvgTransformType.translateZ:
        // Z-only translation has no effect in 2D
        break;

      case SvgTransformType.rotateX:
      case SvgTransformType.rotateY:
        // X/Y rotations have perspective effects, approximate with scale
        final angle = transform.values.isNotEmpty ? transform.values[0] : 0.0;
        final radians = angle * 3.14159 / 180.0;
        final cosAngle = math.cos(radians);
        if (transform.type == SvgTransformType.rotateX) {
          canvas.scale(1, cosAngle);
        } else {
          canvas.scale(cosAngle, 1);
        }

      case SvgTransformType.rotateZ:
        final angle = transform.values.isNotEmpty ? transform.values[0] : 0.0;
        canvas.rotate(angle * 3.14159 / 180.0);

      case SvgTransformType.rotate3d:
        // For 2D, just use Z rotation if Z axis dominates
        if (transform.values.length >= 4) {
          final z = transform.values[2];
          final angle = transform.values[3];
          if (z.abs() > 0.5) {
            canvas.rotate(angle * z.sign * 3.14159 / 180.0);
          }
        }

      case SvgTransformType.scale3d:
        final sx = transform.values.isNotEmpty ? transform.values[0] : 1.0;
        final sy = transform.values.length > 1 ? transform.values[1] : 1.0;
        canvas.scale(sx, sy);

      case SvgTransformType.scaleZ:
        // Z-only scale has no effect in 2D
        break;

      case SvgTransformType.perspective:
        // Perspective alone doesn't change 2D rendering
        break;

      case SvgTransformType.matrix3d:
        // Extract 2D portion
        if (transform.values.length >= 16) {
          final matrix = Matrix4x4.fromMatrix3d(transform.values);
          final matrix2d = matrix.extract2DMatrix();
          final flutterMatrix = Matrix4.identity()
            ..setEntry(0, 0, matrix2d[0])
            ..setEntry(1, 0, matrix2d[1])
            ..setEntry(0, 1, matrix2d[2])
            ..setEntry(1, 1, matrix2d[3])
            ..setEntry(0, 3, matrix2d[4])
            ..setEntry(1, 3, matrix2d[5]);
          canvas.transform(flutterMatrix.storage);
        }
    }
  }

  /// Gets the perspective value from CSS perspective property
  double? _getPerspective(SvgNode node) {
    final value = _getStyleOrAttributeValue(node, 'perspective');
    if (value == null) return null;
    final str = value.toString().trim().toLowerCase();
    if (str == 'none' || str.isEmpty) return null;
    // Parse length value (px, em, etc)
    final numValue = str.replaceAll(RegExp(r'[a-z%]+$'), '');
    return double.tryParse(numValue);
  }

  /// Gets the backface-visibility property
  BackfaceVisibility _getBackfaceVisibility(SvgNode node) {
    final value = _getStyleOrAttributeValue(node, 'backface-visibility');
    if (value == null) return BackfaceVisibility.visible;
    final str = value.toString().trim().toLowerCase();
    return str == 'hidden'
        ? BackfaceVisibility.hidden
        : BackfaceVisibility.visible;
  }

  /// Parses the transform-origin CSS property.
  /// Supports keywords (center, left, right, top, bottom), percentages, absolute values,
  /// and three-value syntax (x y z) for 3D transforms.
  /// Returns null if not set.
  ui.Offset? _parseTransformOrigin(SvgNode node) {
    final originObj = _getStyleOrAttributeValue(node, 'transform-origin');
    if (originObj == null) return null;
    final originValue = originObj.toString().trim();
    if (originValue.isEmpty) return null;

    final parts = originValue.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return null;

    // Get reference box based on transform-box property
    final bounds = _getTransformReferenceBox(node);

    double parseOriginValue(
      String value,
      double size,
      double offset,
      bool isHorizontal,
    ) {
      final lower = value.toLowerCase();
      // Handle keywords
      switch (lower) {
        case 'left':
          return offset;
        case 'center':
          return offset + size / 2;
        case 'right':
          return offset + size;
        case 'top':
          return offset;
        case 'bottom':
          return offset + size;
      }
      // Handle percentage
      if (lower.endsWith('%')) {
        final percent = double.tryParse(lower.substring(0, lower.length - 1));
        if (percent != null) {
          return offset + (percent / 100.0) * size;
        }
      }
      // Handle various length units
      return _parseLengthToPixels(lower, size, isHorizontal) + offset;
    }

    // Handle keyword swapping (e.g., "top left" vs "left top")
    var xPart = parts[0];
    var yPart = parts.length > 1 ? parts[1] : 'center';

    // Check if first part is a vertical keyword and second is horizontal
    if (_isVerticalKeyword(xPart) && parts.length > 1 && _isHorizontalKeyword(yPart)) {
      final temp = xPart;
      xPart = yPart;
      yPart = temp;
    }

    final x = parseOriginValue(xPart, bounds.width, bounds.left, true);
    final y = parseOriginValue(yPart, bounds.height, bounds.top, false);
    // Third value (z) is ignored for 2D rendering but we parse it for completeness
    // final z = parts.length > 2 ? _parseLengthToPixels(parts[2], 0, false) : 0.0;

    return ui.Offset(x, y);
  }

  /// Checks if a keyword is a vertical position keyword.
  bool _isVerticalKeyword(String keyword) {
    final lower = keyword.toLowerCase();
    return lower == 'top' || lower == 'bottom';
  }

  /// Checks if a keyword is a horizontal position keyword.
  bool _isHorizontalKeyword(String keyword) {
    final lower = keyword.toLowerCase();
    return lower == 'left' || lower == 'right';
  }

  /// Parses a CSS length value to pixels.
  /// Supports: px, em, rem, %, vw, vh, bare numbers.
  double _parseLengthToPixels(String value, double referenceSize, bool isWidth) {
    final lower = value.toLowerCase().trim();

    if (lower.endsWith('px')) {
      return double.tryParse(lower.substring(0, lower.length - 2)) ?? 0.0;
    }
    if (lower.endsWith('em') || lower.endsWith('rem')) {
      // Default font size is typically 16px
      final unitLen = lower.endsWith('rem') ? 3 : 2;
      final num = double.tryParse(lower.substring(0, lower.length - unitLen)) ?? 0.0;
      return num * 16.0;
    }
    if (lower.endsWith('%')) {
      final percent = double.tryParse(lower.substring(0, lower.length - 1)) ?? 0.0;
      return (percent / 100.0) * referenceSize;
    }
    if (lower.endsWith('vw')) {
      // Viewport width - use reference or a default
      final vw = double.tryParse(lower.substring(0, lower.length - 2)) ?? 0.0;
      return vw * (referenceSize / 100.0);
    }
    if (lower.endsWith('vh')) {
      // Viewport height
      final vh = double.tryParse(lower.substring(0, lower.length - 2)) ?? 0.0;
      return vh * (referenceSize / 100.0);
    }
    // Bare number
    return double.tryParse(lower) ?? 0.0;
  }

  /// Gets the reference box for transform-origin based on transform-box property.
  /// Supports: fill-box (default for SVG), view-box, content-box, border-box.
  ui.Rect _getTransformReferenceBox(SvgNode node) {
    final transformBox = _getStyleOrAttributeValue(node, 'transform-box');
    final boxType = transformBox?.toString().toLowerCase().trim() ?? 'fill-box';

    switch (boxType) {
      case 'view-box':
        // Use the nearest viewBox as reference
        return _getNearestViewBox(node) ?? _getNodeBounds(node);
      case 'fill-box':
      case 'content-box':
      case 'border-box':
      default:
        // For SVG, fill-box is the object bounding box
        return _getNodeBounds(node);
    }
  }

  /// Gets the nearest ancestor viewBox or the root viewBox.
  ui.Rect? _getNearestViewBox(SvgNode node) {
    var current = node;
    while (true) {
      final viewBox = _getViewBox(current);
      if (viewBox != null) return viewBox;
      final parent = current.parent;
      if (parent == null) break;
      current = parent;
    }
    return null;
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
