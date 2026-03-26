part of 'animated_svg_painter.dart';

extension AnimatedSvgPainterGeometryExtension on AnimatedSvgPainter {
  ui.Path? _buildGeometryPath(SvgNode node) {
    switch (node.tagName) {
      case 'rect':
        final x = _getNumber(node, 'x') ?? 0.0;
        final y = _getNumber(node, 'y') ?? 0.0;
        final width = _getNumber(node, 'width') ?? 0.0;
        final height = _getNumber(node, 'height') ?? 0.0;

        // SVG spec: rx/ry handling
        final rxRaw = _getNumber(node, 'rx');
        final ryRaw = _getNumber(node, 'ry');

        double rx;
        double ry;
        if (rxRaw == null && ryRaw == null) {
          rx = 0.0;
          ry = 0.0;
        } else if (rxRaw != null && ryRaw == null) {
          rx = rxRaw;
          ry = rxRaw;
        } else if (rxRaw == null && ryRaw != null) {
          rx = ryRaw;
          ry = ryRaw;
        } else {
          rx = rxRaw!;
          ry = ryRaw!;
        }

        // Negative rx/ry is an error
        if (rx < 0 || ry < 0) return null;

        // Clamp rx/ry to half of width/height
        rx = rx.clamp(0.0, width / 2);
        ry = ry.clamp(0.0, height / 2);

        if (width <= 0 || height <= 0) return null;
        final rect = ui.Rect.fromLTWH(x, y, width, height);
        if (rx > 0 || ry > 0) {
          return ui.Path()..addRRect(ui.RRect.fromRectXY(rect, rx, ry));
        }
        return ui.Path()..addRect(rect);
      case 'circle':
        final cx = _getNumber(node, 'cx') ?? 0.0;
        final cy = _getNumber(node, 'cy') ?? 0.0;
        final r = _getNumber(node, 'r') ?? 0.0;
        if (r <= 0) return null;
        return ui.Path()
          ..addOval(ui.Rect.fromCircle(center: ui.Offset(cx, cy), radius: r));
      case 'ellipse':
        final cx = _getNumber(node, 'cx') ?? 0.0;
        final cy = _getNumber(node, 'cy') ?? 0.0;
        final rx = _getNumber(node, 'rx') ?? 0.0;
        final ry = _getNumber(node, 'ry') ?? 0.0;
        if (rx <= 0 || ry <= 0) return null;
        return ui.Path()..addOval(
          ui.Rect.fromCenter(
            center: ui.Offset(cx, cy),
            width: rx * 2,
            height: ry * 2,
          ),
        );
      case 'line':
        final x1 = _getNumber(node, 'x1') ?? 0.0;
        final y1 = _getNumber(node, 'y1') ?? 0.0;
        final x2 = _getNumber(node, 'x2') ?? 0.0;
        final y2 = _getNumber(node, 'y2') ?? 0.0;
        return ui.Path()
          ..moveTo(x1, y1)
          ..lineTo(x2, y2);
      case 'polygon':
        final polygon = _parsePoints(node);
        if (polygon.length < 3) return null;
        final polygonPath = ui.Path()
          ..moveTo(polygon.first.dx, polygon.first.dy);
        for (int i = 1; i < polygon.length; i++) {
          polygonPath.lineTo(polygon[i].dx, polygon[i].dy);
        }
        polygonPath.close();
        _applyPathFillType(polygonPath, node);
        return polygonPath;
      case 'polyline':
        final polyline = _parsePoints(node);
        if (polyline.length < 2) return null;
        final polylinePath = ui.Path()
          ..moveTo(polyline.first.dx, polyline.first.dy);
        for (int i = 1; i < polyline.length; i++) {
          polylinePath.lineTo(polyline[i].dx, polyline[i].dy);
        }
        _applyPathFillType(polylinePath, node);
        return polylinePath;
      case 'path':
        final pathData = _getString(node, 'd');
        if (pathData == null || pathData.isEmpty) return null;
        final parsed = _buildPath(pathData);
        if (parsed == null) return null;
        _applyPathFillType(parsed, node);
        return parsed;
      case 'image':
        // Image geometry is a rectangle defined by x, y, width, height.
        // Per SVG spec, image in clipPath contributes its bounding rectangle.
        // The alpha channel of the image content defines the clip region,
        // but for geometry-based clipping, we use the image bounds.
        final imgX = _getNumber(node, 'x') ?? 0.0;
        final imgY = _getNumber(node, 'y') ?? 0.0;
        // For clip/mask geometry, we need dimensions. If not specified,
        // we cannot determine the image bounds, so return null.
        final imgWidth = _getNumber(node, 'width');
        final imgHeight = _getNumber(node, 'height');
        // If width/height are not specified, try to get from loaded image
        final href = _extractImageHref(node);
        final actualWidth =
            imgWidth ??
            (href != null ? imagesByHref[href]?.width.toDouble() : null);
        final actualHeight =
            imgHeight ??
            (href != null ? imagesByHref[href]?.height.toDouble() : null);
        if (actualWidth == null ||
            actualHeight == null ||
            actualWidth <= 0 ||
            actualHeight <= 0) {
          return null;
        }
        return ui.Path()
          ..addRect(ui.Rect.fromLTWH(imgX, imgY, actualWidth, actualHeight));
      case 'foreignObject':
        // ForeignObject geometry is its viewport rectangle.
        // Used for clip/mask region calculation.
        final foX = _getNumber(node, 'x') ?? 0.0;
        final foY = _getNumber(node, 'y') ?? 0.0;
        final foWidth = _getNumber(node, 'width') ?? 0.0;
        final foHeight = _getNumber(node, 'height') ?? 0.0;
        if (foWidth <= 0 || foHeight <= 0) {
          return null;
        }
        return ui.Path()
          ..addRect(ui.Rect.fromLTWH(foX, foY, foWidth, foHeight));
      default:
        return null;
    }
  }

  /// Builds a path for a nested SVG element within foreignObject context.
  /// The SVG establishes its own coordinate system which may differ from
  /// the foreignObject's viewport.
  // ignore: unused_element
  ui.Path? _buildNestedSvgPath(SvgNode svgNode, SvgNode foreignObjectParent) {
    // Get foreignObject dimensions
    final foWidth = _getNumber(foreignObjectParent, 'width') ?? 0.0;
    final foHeight = _getNumber(foreignObjectParent, 'height') ?? 0.0;
    if (foWidth <= 0 || foHeight <= 0) {
      return null;
    }

    // Get SVG element positioning
    final svgX = _getNumber(svgNode, 'x') ?? 0.0;
    final svgY = _getNumber(svgNode, 'y') ?? 0.0;
    final svgWidth = _getNumber(svgNode, 'width') ?? foWidth;
    final svgHeight = _getNumber(svgNode, 'height') ?? foHeight;

    if (svgWidth <= 0 || svgHeight <= 0) {
      return null;
    }

    // The geometry is the SVG element's bounds within the foreignObject
    return ui.Path()
      ..addRect(ui.Rect.fromLTWH(svgX, svgY, svgWidth, svgHeight));
  }

  /// Resolves the coordinate transform for content within a foreignObject.
  /// ForeignObject establishes a new stacking context with transform reset.
  // ignore: unused_element
  Matrix4 _resolveForeignObjectContentTransform(SvgNode foreignObjectNode) {
    final x = _getNumber(foreignObjectNode, 'x') ?? 0.0;
    final y = _getNumber(foreignObjectNode, 'y') ?? 0.0;

    // ForeignObject translates content to (x, y) position
    // Transform is reset - foreignObject content starts fresh
    return Matrix4.identity()..translateByDouble(x, y, 0, 1);
  }

  // ============================================================================
  // ForeignObject CSS Inheritance
  // ============================================================================

  /// Set of CSS properties that should be inherited through foreignObject
  /// boundaries into the foreign content context.
  /// Note: fill and stroke are SVG-specific and should NOT propagate.
  static const Set<String> _foreignObjectCssInheritableProperties = {
    // Typography - core text styling
    'font-family',
    'font-size',
    'font-weight',
    'font-style',
    'font-variant',
    'font-stretch',
    'font-size-adjust',
    'font-feature-settings',
    'font-variation-settings',

    // Text layout
    'line-height',
    'letter-spacing',
    'word-spacing',
    'text-align',
    'text-indent',
    'text-transform',
    'white-space',
    'word-break',
    'word-wrap',
    'overflow-wrap',

    // Text decoration
    'text-decoration',
    'text-decoration-line',
    'text-decoration-style',
    'text-decoration-color',
    'text-decoration-thickness',

    // Directionality and writing
    'direction',
    'writing-mode',
    'text-orientation',
    'unicode-bidi',

    // Color (CSS color property, NOT fill/stroke)
    'color',

    // Visibility and interaction
    'visibility',
    'cursor',
  };

  /// SVG-specific properties that should NOT be inherited into foreignObject
  /// content because they only apply to SVG graphics elements.
  static const Set<String> _foreignObjectSvgExcludedProperties = {
    'fill',
    'fill-opacity',
    'fill-rule',
    'stroke',
    'stroke-opacity',
    'stroke-width',
    'stroke-linecap',
    'stroke-linejoin',
    'stroke-dasharray',
    'stroke-dashoffset',
    'stroke-miterlimit',
    'marker',
    'marker-start',
    'marker-mid',
    'marker-end',
    'paint-order',
    'vector-effect',
  };

  /// Checks whether a CSS property should be inherited across the foreignObject
  /// boundary from SVG ancestors to foreign content.
  ///
  /// Returns true for typography, text, color, and direction properties.
  /// Returns false for SVG-specific properties like fill and stroke.
  bool _isForeignObjectCssInheritable(String property) {
    final normalized = property.toLowerCase().trim();

    // CSS custom properties (--xxx) are always inherited
    if (normalized.startsWith('--')) {
      return true;
    }

    // Explicitly excluded SVG properties
    if (_foreignObjectSvgExcludedProperties.contains(normalized)) {
      return false;
    }

    // Check if property is in the inheritable set
    return _foreignObjectCssInheritableProperties.contains(normalized);
  }

  /// Resolves an inherited CSS property value respecting foreignObject
  /// boundaries. For inheritable properties (like font-family), walks up
  /// through the foreignObject boundary to ancestors. For non-inheritable
  /// or SVG-specific properties (like fill), stops at the boundary.
  ///
  /// [node] - The node to start resolution from
  /// [property] - The CSS property name to resolve
  /// [foreignObjectAncestor] - The foreignObject element establishing the boundary
  ///
  /// Returns the resolved property value or null if not found.
  // ignore: unused_element
  Object? _resolveForeignObjectInheritedCss(
    SvgNode node,
    String property,
    SvgNode? foreignObjectAncestor,
  ) {
    // No foreignObject context - use normal inheritance
    if (foreignObjectAncestor == null) {
      return _getInheritedAttributeValue(node, property);
    }

    // Check if this property can cross the foreignObject boundary
    if (_isForeignObjectCssInheritable(property)) {
      // Inheritable property - walk entire ancestor chain
      return _getInheritedAttributeValue(node, property);
    }

    // Non-inheritable or SVG-specific property - only check within foreignObject
    return _getAttributeWithinForeignObject(
      node,
      property,
      foreignObjectAncestor,
    );
  }

  /// Gets an attribute value only searching within the foreignObject subtree.
  /// Does not cross the foreignObject boundary for non-inherited properties.
  Object? _getAttributeWithinForeignObject(
    SvgNode node,
    String property,
    SvgNode foreignObjectBoundary,
  ) {
    SvgNode? current = node;
    while (current != null) {
      // Check inline style first
      final styleAttr = current.getAttributeValue('style');
      if (styleAttr != null) {
        final styleValue = _extractCssPropertyFromStyle(
          styleAttr.toString(),
          property,
        );
        if (styleValue != null) {
          return styleValue;
        }
      }

      // Check presentation attribute
      final attrValue = current.getAttributeValue(property);
      if (attrValue != null) {
        return attrValue;
      }

      // Stop at foreignObject boundary - don't go to SVG ancestors
      if (identical(current, foreignObjectBoundary)) {
        break;
      }

      current = current.parent;
    }
    return null;
  }

  /// Extracts a CSS property value from an inline style string.
  String? _extractCssPropertyFromStyle(String style, String property) {
    final normalizedProp = property.toLowerCase().trim();
    final declarations = style.split(';');

    for (final decl in declarations) {
      final colonIndex = decl.indexOf(':');
      if (colonIndex == -1) continue;

      final propName = decl.substring(0, colonIndex).trim().toLowerCase();
      if (propName == normalizedProp) {
        return decl
            .substring(colonIndex + 1)
            .replaceFirst(
              RegExp(r'\s*!important\s*$', caseSensitive: false),
              '',
            )
            .trim();
      }
    }
    return null;
  }

  // ============================================================================
  // ForeignObject Viewport Clipping
  // ============================================================================

  /// Resolves the viewport rectangle for a foreignObject element.
  /// The viewport is defined by x, y, width, height attributes.
  // ignore: unused_element
  ui.Rect? _resolveForeignObjectViewport(SvgNode foreignObjectNode) {
    if (foreignObjectNode.tagName != 'foreignObject') {
      return null;
    }

    final x = _getNumber(foreignObjectNode, 'x') ?? 0.0;
    final y = _getNumber(foreignObjectNode, 'y') ?? 0.0;
    final width = _getNumber(foreignObjectNode, 'width') ?? 0.0;
    final height = _getNumber(foreignObjectNode, 'height') ?? 0.0;

    if (width <= 0 || height <= 0) {
      return null;
    }

    return ui.Rect.fromLTWH(x, y, width, height);
  }

  /// Resolves the overflow mode for a foreignObject element.
  /// Returns 'hidden' (default), 'visible', or 'scroll' (treated as hidden).
  String _resolveForeignObjectOverflow(SvgNode foreignObjectNode) {
    final overflow = _getInheritedString(foreignObjectNode, 'overflow');
    final normalized = overflow?.toLowerCase().trim();

    switch (normalized) {
      case 'visible':
        return 'visible';
      case 'scroll':
      case 'auto':
        // In SVG context, scroll is treated like hidden (no scrollbars)
        return 'hidden';
      case 'hidden':
      default:
        // Default for foreignObject is hidden per SVG spec
        return 'hidden';
    }
  }

  /// Determines if viewport clipping should be applied to foreignObject.
  /// Returns true for overflow=hidden/scroll, false for overflow=visible.
  bool _shouldClipForeignObjectViewport(SvgNode foreignObjectNode) {
    return _resolveForeignObjectOverflow(foreignObjectNode) != 'visible';
  }

  /// Creates a clip rect for the foreignObject viewport, if clipping is needed.
  /// The clip rect is in the local coordinate system of the foreignObject
  /// (i.e., after the x,y translation has been applied).
  // ignore: unused_element
  ui.Rect? _createForeignObjectClipRect(SvgNode foreignObjectNode) {
    if (!_shouldClipForeignObjectViewport(foreignObjectNode)) {
      return null;
    }

    final width = _getNumber(foreignObjectNode, 'width') ?? 0.0;
    final height = _getNumber(foreignObjectNode, 'height') ?? 0.0;

    if (width <= 0 || height <= 0) {
      return null;
    }

    // Clip rect is at origin (0,0) because it's applied after translation
    return ui.Rect.fromLTWH(0, 0, width, height);
  }

  // ============================================================================
  // ForeignObject Transform Propagation
  // ============================================================================

  /// Computes the accumulated transform from ancestors to position the
  /// foreignObject viewport correctly. This includes transforms from all
  /// ancestor elements (svg, g, etc.) down to the foreignObject.
  ///
  /// The foreignObject's own transform is NOT included - it will be applied
  /// separately to the viewport, not to individual content items.
  Matrix4 _computeForeignObjectAncestorTransform(SvgNode foreignObjectNode) {
    final transforms = <Matrix4>[];

    // Walk up from foreignObject's parent to root, collecting transforms
    SvgNode? current = foreignObjectNode.parent;
    while (current != null) {
      final nodeTransform = _getTransformMatrix(current);
      if (nodeTransform != null) {
        transforms.add(nodeTransform);
      }
      current = current.parent;
    }

    // Apply in reverse order (root to foreignObject parent)
    final result = Matrix4.identity();
    for (int i = transforms.length - 1; i >= 0; i--) {
      result.multiply(transforms[i]);
    }

    return result;
  }

  /// Gets the transform matrix from a node's transform attribute.
  /// Returns null if no transform is specified.
  Matrix4? _getTransformMatrix(SvgNode node) {
    final transformAttr = node.getAttributeValue('transform');
    if (transformAttr == null) {
      return null;
    }

    final transformStr = transformAttr.toString().trim();
    if (transformStr.isEmpty || transformStr.toLowerCase() == 'none') {
      return null;
    }

    // Parse using the SVG transform parser
    final transforms = SvgTransform.parse(transformStr);
    if (transforms.isEmpty) {
      return null;
    }

    // Build combined matrix from all transforms
    final result = Matrix4.identity();
    for (final transform in transforms) {
      _applyTransformToMatrix4(result, transform);
    }
    return result;
  }

  /// Applies a single SVG transform to a Matrix4.
  void _applyTransformToMatrix4(Matrix4 matrix, SvgTransform transform) {
    switch (transform.type) {
      case SvgTransformType.translate:
        final tx = transform.values.isNotEmpty ? transform.values[0] : 0.0;
        final ty = transform.values.length > 1 ? transform.values[1] : 0.0;
        matrix.translateByDouble(tx, ty, 0, 1);

      case SvgTransformType.scale:
        final sx = transform.values.isNotEmpty ? transform.values[0] : 1.0;
        final sy = transform.values.length > 1 ? transform.values[1] : sx;
        matrix.scaleByDouble(sx, sy, 1, 1);

      case SvgTransformType.rotate:
        final angle = transform.values.isNotEmpty ? transform.values[0] : 0.0;
        final cx = transform.values.length > 1 ? transform.values[1] : 0.0;
        final cy = transform.values.length > 2 ? transform.values[2] : 0.0;
        if (cx != 0.0 || cy != 0.0) {
          matrix.translateByDouble(cx, cy, 0, 1);
          matrix.rotateZ(angle * math.pi / 180.0);
          matrix.translateByDouble(-cx, -cy, 0, 1);
        } else {
          matrix.rotateZ(angle * math.pi / 180.0);
        }

      case SvgTransformType.skewX:
        final angle = transform.values.isNotEmpty ? transform.values[0] : 0.0;
        final skew = Matrix4.identity();
        skew.setEntry(0, 1, math.tan(angle * math.pi / 180.0));
        matrix.multiply(skew);

      case SvgTransformType.skewY:
        final angle = transform.values.isNotEmpty ? transform.values[0] : 0.0;
        final skew = Matrix4.identity();
        skew.setEntry(1, 0, math.tan(angle * math.pi / 180.0));
        matrix.multiply(skew);

      case SvgTransformType.matrix:
        if (transform.values.length >= 6) {
          final m = Matrix4.identity();
          m.setEntry(0, 0, transform.values[0]); // a
          m.setEntry(1, 0, transform.values[1]); // b
          m.setEntry(0, 1, transform.values[2]); // c
          m.setEntry(1, 1, transform.values[3]); // d
          m.setEntry(0, 3, transform.values[4]); // e (tx)
          m.setEntry(1, 3, transform.values[5]); // f (ty)
          matrix.multiply(m);
        }

      // 3D transforms - apply as 2D projection
      case SvgTransformType.translate3d:
        final tx = transform.values.isNotEmpty ? transform.values[0] : 0.0;
        final ty = transform.values.length > 1 ? transform.values[1] : 0.0;
        // z is ignored for 2D canvas
        matrix.translateByDouble(tx, ty, 0, 1);

      case SvgTransformType.translateZ:
        // Z translation is ignored for 2D canvas
        break;

      case SvgTransformType.scale3d:
        final sx = transform.values.isNotEmpty ? transform.values[0] : 1.0;
        final sy = transform.values.length > 1 ? transform.values[1] : sx;
        // sz is ignored for 2D canvas
        matrix.scaleByDouble(sx, sy, 1, 1);

      case SvgTransformType.scaleZ:
        // Z scaling is ignored for 2D canvas
        break;

      case SvgTransformType.rotateX:
      case SvgTransformType.rotateY:
        // X/Y rotations produce foreshortening in 2D projection
        // For simplicity, we skip these (they would need perspective projection)
        break;

      case SvgTransformType.rotateZ:
        final angle = transform.values.isNotEmpty ? transform.values[0] : 0.0;
        matrix.rotateZ(angle * math.pi / 180.0);

      case SvgTransformType.rotate3d:
        // For 2D canvas, we only apply Z rotation component
        if (transform.values.length >= 4) {
          final z = transform.values[2];
          final angle = transform.values[3];
          if (z.abs() > 0.001) {
            matrix.rotateZ(angle * math.pi / 180.0 * z.sign);
          }
        }

      case SvgTransformType.perspective:
      case SvgTransformType.matrix3d:
        // These are ignored for 2D canvas operations
        break;
    }
  }

  /// Computes the complete transform for foreignObject content positioning.
  /// This combines:
  /// 1. Ancestor transforms (from parent elements)
  /// 2. ForeignObject's own transform (applied to viewport)
  /// 3. ForeignObject x,y translation (viewport positioning)
  // ignore: unused_element
  Matrix4 _computeForeignObjectCompleteTransform(SvgNode foreignObjectNode) {
    final result = Matrix4.identity();

    // 1. Apply ancestor transforms
    result.multiply(_computeForeignObjectAncestorTransform(foreignObjectNode));

    // 2. Apply foreignObject's own transform (if any)
    final foTransform = _getTransformMatrix(foreignObjectNode);
    if (foTransform != null) {
      result.multiply(foTransform);
    }

    // 3. Apply x,y translation for viewport positioning
    final x = _getNumber(foreignObjectNode, 'x') ?? 0.0;
    final y = _getNumber(foreignObjectNode, 'y') ?? 0.0;
    if (x != 0.0 || y != 0.0) {
      result.translateByDouble(x, y, 0, 1);
    }

    return result;
  }

  /// Resolves the CSS context to pass to foreignObject content.
  /// This creates a snapshot of inherited CSS properties from SVG ancestors
  /// that should propagate into the foreign content.
  // ignore: unused_element
  Map<String, String> _resolveForeignObjectCssContext(
    SvgNode foreignObjectNode,
  ) {
    final context = <String, String>{};

    // Collect all inheritable CSS properties from ancestors
    for (final property in _foreignObjectCssInheritableProperties) {
      final value = _getInheritedAttributeValue(foreignObjectNode, property);
      if (value != null) {
        context[property] = value.toString();
      }
    }

    return context;
  }

  void _applyPathFillType(ui.Path path, SvgNode node) {
    // clip-rule and fill-rule are inheritable properties
    final fillRule =
        _getInheritedString(node, 'clip-rule')?.toLowerCase() ??
        _getInheritedString(node, 'fill-rule')?.toLowerCase();
    path.fillType = fillRule == 'evenodd'
        ? ui.PathFillType.evenOdd
        : ui.PathFillType.nonZero;
  }

  ui.Path? _buildPath(String pathData) {
    List<PathCommand> commands;
    try {
      commands = PathParser().parse(pathData);
    } catch (_) {
      return null;
    }

    if (commands.isEmpty) {
      return null;
    }

    final path = ui.Path();
    double currentX = 0.0;
    double currentY = 0.0;
    double subPathStartX = 0.0;
    double subPathStartY = 0.0;
    PathCommand? previousCommand;

    for (final command in commands) {
      final absoluteCommand = command.toAbsolute(currentX, currentY);

      switch (absoluteCommand) {
        case MoveToCommand():
          path.moveTo(absoluteCommand.x, absoluteCommand.y);
          currentX = absoluteCommand.x;
          currentY = absoluteCommand.y;
          subPathStartX = currentX;
          subPathStartY = currentY;
          previousCommand = absoluteCommand;

        case LineToCommand():
          path.lineTo(absoluteCommand.x, absoluteCommand.y);
          currentX = absoluteCommand.x;
          currentY = absoluteCommand.y;
          previousCommand = absoluteCommand;

        case HorizontalLineToCommand():
          path.lineTo(absoluteCommand.x, currentY);
          currentX = absoluteCommand.x;
          previousCommand = LineToCommand(x: currentX, y: currentY);

        case VerticalLineToCommand():
          path.lineTo(currentX, absoluteCommand.y);
          currentY = absoluteCommand.y;
          previousCommand = LineToCommand(x: currentX, y: currentY);

        case CubicBezierCommand():
          path.cubicTo(
            absoluteCommand.x1,
            absoluteCommand.y1,
            absoluteCommand.x2,
            absoluteCommand.y2,
            absoluteCommand.x,
            absoluteCommand.y,
          );
          currentX = absoluteCommand.x;
          currentY = absoluteCommand.y;
          previousCommand = absoluteCommand;

        case SmoothCubicBezierCommand():
          final cubic = absoluteCommand.toCubicBezier(
            currentX: currentX,
            currentY: currentY,
            previousCommand: previousCommand,
          );
          path.cubicTo(
            cubic.x1,
            cubic.y1,
            cubic.x2,
            cubic.y2,
            cubic.x,
            cubic.y,
          );
          currentX = cubic.x;
          currentY = cubic.y;
          previousCommand = cubic;

        case QuadraticBezierCommand():
          path.quadraticBezierTo(
            absoluteCommand.x1,
            absoluteCommand.y1,
            absoluteCommand.x,
            absoluteCommand.y,
          );
          currentX = absoluteCommand.x;
          currentY = absoluteCommand.y;
          previousCommand = absoluteCommand;

        case SmoothQuadraticBezierCommand():
          final quadratic = absoluteCommand.toQuadraticBezier(
            currentX: currentX,
            currentY: currentY,
            previousCommand: previousCommand,
          );
          path.quadraticBezierTo(
            quadratic.x1,
            quadratic.y1,
            quadratic.x,
            quadratic.y,
          );
          currentX = quadratic.x;
          currentY = quadratic.y;
          previousCommand = quadratic;

        case ArcCommand():
          // SVG spec: If rx or ry is 0, treat as straight line
          // If rx or ry is negative, use absolute value
          final rx = absoluteCommand.rx.abs();
          final ry = absoluteCommand.ry.abs();

          // Edge case: Zero radii - treat as lineTo
          if (rx == 0 || ry == 0) {
            path.lineTo(absoluteCommand.x, absoluteCommand.y);
            currentX = absoluteCommand.x;
            currentY = absoluteCommand.y;
            previousCommand = absoluteCommand;
            break;
          }

          // Edge case: Very small arc (endpoints very close)
          // When endpoints are within a tiny epsilon, just lineTo to avoid
          // numerical instability in arc computation
          final dx = absoluteCommand.x - currentX;
          final dy = absoluteCommand.y - currentY;
          final endpointDistance = (dx * dx + dy * dy);
          const epsilon = 1e-10;
          if (endpointDistance < epsilon) {
            // Endpoints are essentially the same - no arc needed
            currentX = absoluteCommand.x;
            currentY = absoluteCommand.y;
            previousCommand = absoluteCommand;
            break;
          }

          // Edge case: Arc radius too small to reach endpoint
          // Per SVG spec, radii are scaled up uniformly to the minimum required
          // to reach the endpoint. This is handled by Flutter's arcToPoint.

          // Edge case: Very large radii relative to endpoint distance
          // This can cause numerical issues - the arc degenerates into almost
          // a straight line or full ellipse. Flutter handles this correctly
          // but we add a check for extreme cases.
          final halfChord = endpointDistance / 4;
          final minRadius = rx < ry ? rx : ry;
          if (minRadius * minRadius < halfChord * epsilon) {
            // Radius is too small relative to distance - lineTo is safer
            path.lineTo(absoluteCommand.x, absoluteCommand.y);
            currentX = absoluteCommand.x;
            currentY = absoluteCommand.y;
            previousCommand = absoluteCommand;
            break;
          }

          path.arcToPoint(
            ui.Offset(absoluteCommand.x, absoluteCommand.y),
            radius: ui.Radius.elliptical(rx, ry),
            rotation: absoluteCommand.rotation,
            largeArc: absoluteCommand.largeArc,
            clockwise: absoluteCommand.sweep,
          );
          currentX = absoluteCommand.x;
          currentY = absoluteCommand.y;
          previousCommand = absoluteCommand;

        case ClosePathCommand():
          path.close();
          currentX = subPathStartX;
          currentY = subPathStartY;
          previousCommand = absoluteCommand;
      }
    }

    return path;
  }
}
