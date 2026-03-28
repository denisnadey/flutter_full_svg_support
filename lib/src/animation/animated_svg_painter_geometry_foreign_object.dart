part of 'animated_svg_painter.dart';

/// Extension for foreignObject geometry and CSS handling.
extension AnimatedSvgPainterGeometryForeignObjectExtension
    on AnimatedSvgPainter {
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
}
