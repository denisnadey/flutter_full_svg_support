part of 'animated_svg_painter.dart';

/// CSS properties that are inherited through foreignObject boundaries.
/// These properties flow from SVG context into foreignObject HTML content.
const Set<String> _foreignObjectInheritableProperties = {
  // Color properties
  'color',

  // Font properties
  'font',
  'font-family',
  'font-size',
  'font-size-adjust',
  'font-stretch',
  'font-style',
  'font-variant',
  'font-variant-caps',
  'font-variant-ligatures',
  'font-variant-numeric',
  'font-weight',
  'font-feature-settings',
  'font-variation-settings',

  // Text properties
  'letter-spacing',
  'line-height',
  'text-align',
  'text-indent',
  'text-transform',
  'white-space',
  'word-spacing',
  'word-break',
  'word-wrap',
  'overflow-wrap',
  'direction',
  'writing-mode',
  'text-orientation',

  // Visibility
  'visibility',
  'pointer-events',
  'cursor',

  // Text decoration (partially inheritable)
  'text-decoration',
  'text-decoration-line',
  'text-decoration-style',
  'text-decoration-color',
};

/// Non-inherited CSS properties that should NOT cross foreignObject boundaries.
/// These establish a new stacking/transform context within foreignObject.
const Set<String> _foreignObjectNonInheritableProperties = {
  // Transform and layout
  'transform',
  'transform-origin',
  'transform-box',
  'transform-style',

  // Opacity and compositing (new stacking context)
  'opacity',
  'mix-blend-mode',
  'isolation',

  // Display and positioning
  'display',
  'position',
  'top',
  'left',
  'right',
  'bottom',
  'z-index',

  // Clipping and masking (new context)
  'clip-path',
  'clip',
  'mask',
  'mask-image',
  'overflow',
  'overflow-x',
  'overflow-y',

  // Filter effects
  'filter',
  'backdrop-filter',

  // Box model
  'width',
  'height',
  'min-width',
  'min-height',
  'max-width',
  'max-height',
  'margin',
  'padding',
  'border',
  'outline',

  // Background
  'background',
  'background-color',
  'background-image',
};

extension AnimatedSvgPainterShapesImageExtension on AnimatedSvgPainter {
  void _paintImage(
    ui.Canvas canvas,
    SvgNode node, {
    ui.ImageFilter? imageFilter,
    ui.ColorFilter? colorFilter,
    ui.BlendMode? blendMode,
  }) {
    final href = _extractImageHref(node);
    // Edge case: missing href - silently skip
    if (href == null || href.isEmpty) {
      return;
    }

    final image = imagesByHref[href];
    // Edge case: image not yet loaded - silently skip
    if (image == null) {
      return;
    }

    final x = _getNumber(node, 'x') ?? 0.0;
    final y = _getNumber(node, 'y') ?? 0.0;

    // Resolve width/height with percentage support
    final viewportSize = _getImageViewportSize(node);
    final width =
        _resolveImageLength(node, 'width', viewportSize.width) ??
        image.width.toDouble();
    final height =
        _resolveImageLength(node, 'height', viewportSize.height) ??
        image.height.toDouble();

    // Edge case: zero-size image - per SVG spec, disable rendering
    if (width <= 0 || height <= 0) {
      return;
    }

    final viewport = ui.Rect.fromLTWH(x, y, width, height);
    final srcRect = ui.Rect.fromLTWH(
      0,
      0,
      image.width.toDouble(),
      image.height.toDouble(),
    );

    // Get preserveAspectRatio - handles 'none' for stretching
    // and all 9 alignment values (xMinYMin, xMidYMin, xMaxYMin, etc.)
    // with 'meet' and 'slice' modifiers
    final preserveAspectRatio = _getString(node, 'preserveAspectRatio');
    final layout = resolveSvgViewportLayout(
      viewport: viewport,
      sourceSize: srcRect.size,
      preserveAspectRatio: preserveAspectRatio,
    );

    final paint = ui.Paint();
    final opacity = (_getNumber(node, 'opacity') ?? 1.0).clamp(0.0, 1.0);
    paint.color = const ui.Color(0xFFFFFFFF).withValues(alpha: opacity);

    // image-rendering CSS property maps to FilterQuality:
    // - auto: medium quality (bilinear)
    // - optimizeSpeed: none (no interpolation)
    // - optimizeQuality/smooth/high-quality: high (bicubic)
    // - pixelated: none (nearest-neighbor for crisp pixel art)
    paint.filterQuality = _resolveImageRendering(node);

    if (imageFilter != null) {
      paint.imageFilter = imageFilter;
    }
    if (colorFilter != null) {
      paint.colorFilter = colorFilter;
    }
    if (blendMode != null) {
      paint.blendMode = blendMode;
    }

    // For 'slice' mode, clip to viewport to hide overflow
    if (layout.clipToViewport) {
      canvas.save();
      canvas.clipRect(viewport, doAntiAlias: true);
      canvas.drawImageRect(image, srcRect, layout.destinationRect, paint);
      canvas.restore();
      return;
    }

    canvas.drawImageRect(image, srcRect, layout.destinationRect, paint);
  }

  /// Checks if a CSS property should be inherited through foreignObject boundary.
  /// Per SVG spec, foreignObject establishes a new stacking context but allows
  /// inherited CSS properties to flow from the SVG context.
  bool _isForeignObjectInheritableProperty(String property) {
    final normalized = property.trim().toLowerCase();
    // CSS custom properties (--xxx) are always inherited
    if (normalized.startsWith('--')) {
      return true;
    }
    return _foreignObjectInheritableProperties.contains(normalized);
  }

  /// Gets an inherited property value that respects foreignObject boundaries.
  /// Non-inherited properties stop at the foreignObject boundary.
  Object? _getInheritedValueRespectingForeignObjectBoundary(
    SvgNode node,
    String property,
    SvgNode? foreignObjectBoundary,
  ) {
    if (foreignObjectBoundary == null) {
      return _getInheritedAttributeValue(node, property);
    }

    // Check if property should cross the foreignObject boundary
    if (!_isForeignObjectInheritableProperty(property)) {
      // Non-inherited property - only check from foreignObject down
      return _getAttributeValueWithinForeignObject(node, property, foreignObjectBoundary);
    }

    // Inherited property - allow full inheritance chain
    return _getInheritedAttributeValue(node, property);
  }

  /// Gets attribute value within the foreignObject subtree only.
  /// Does not look beyond the foreignObject boundary for non-inherited properties.
  Object? _getAttributeValueWithinForeignObject(
    SvgNode node,
    String property,
    SvgNode foreignObjectBoundary,
  ) {
    SvgNode? current = node;
    while (current != null) {
      // Check inline style
      final styleValue = _extractStyleValue(current, property);
      if (styleValue != null) {
        return styleValue;
      }

      // Check presentation attribute
      final attrValue = current.getAttributeValue(property);
      if (attrValue != null) {
        return attrValue;
      }

      // Stop at foreignObject boundary
      if (identical(current, foreignObjectBoundary)) {
        break;
      }

      current = current.parent;
    }
    return null;
  }

  /// Resolves an image dimension that may be a percentage value.
  /// Returns null if the attribute is missing or invalid.
  double? _resolveImageLength(
    SvgNode node,
    String attributeName,
    double viewportDimension,
  ) {
    final value = node.getAttributeValue(attributeName);
    if (value == null) return null;

    final str = value.toString().trim();
    if (str.isEmpty) return null;

    // Check for percentage value
    if (str.endsWith('%')) {
      final percentStr = str.substring(0, str.length - 1);
      final percent = double.tryParse(percentStr);
      if (percent == null) return null;
      return (percent / 100.0) * viewportDimension;
    }

    // Handle other units by stripping them and parsing the number
    final cleaned = str.replaceAll(RegExp(r'[a-zA-Z]+$'), '');
    return double.tryParse(cleaned);
  }

  /// Gets the viewport size for resolving percentage-based image dimensions.
  /// Returns the nearest SVG element's viewBox/viewport dimensions.
  /// Handles nested SVG-in-SVG transforms by walking up the hierarchy.
  ui.Size _getImageViewportSize(SvgNode node) {
    // Walk up to find nearest SVG viewport
    SvgNode? current = node.parent;
    while (current != null) {
      if (current.tagName == 'svg' || current.tagName == 'symbol') {
        // Try to get viewBox dimensions
        final viewBox = _parseViewBox(_getString(current, 'viewBox'));
        if (viewBox != null && viewBox.width > 0 && viewBox.height > 0) {
          return ui.Size(viewBox.width, viewBox.height);
        }
        // Try width/height attributes
        final svgWidth = _getNumber(current, 'width');
        final svgHeight = _getNumber(current, 'height');
        if (svgWidth != null &&
            svgHeight != null &&
            svgWidth > 0 &&
            svgHeight > 0) {
          return ui.Size(svgWidth, svgHeight);
        }
      }
      // Check foreignObject viewport
      if (current.tagName == 'foreignObject') {
        final foWidth = _getNumber(current, 'width') ?? 0.0;
        final foHeight = _getNumber(current, 'height') ?? 0.0;
        if (foWidth > 0 && foHeight > 0) {
          return ui.Size(foWidth, foHeight);
        }
      }
      current = current.parent;
    }

    // Fall back to root document viewBox
    final rootViewBox = document.activeViewBox;
    if (rootViewBox != null &&
        rootViewBox.width > 0 &&
        rootViewBox.height > 0) {
      return ui.Size(rootViewBox.width, rootViewBox.height);
    }

    // Default to 100x100 if no viewport found
    return const ui.Size(100, 100);
  }

  /// Computes the accumulated viewport transform chain for SVG-in-SVG nesting.
  /// This traverses the hierarchy and composes all viewBox/preserveAspectRatio
  /// transforms to produce the correct coordinate mapping.
  ///
  /// Used when an image is nested within multiple SVG/symbol elements,
  /// each with their own viewBox. The transforms must compose correctly.
  Matrix4 _computeNestedViewportTransform(SvgNode node) {
    final transformStack = <Matrix4>[];

    // Walk up collecting viewport transforms
    SvgNode? current = node.parent;
    while (current != null) {
      if (current.tagName == 'svg' || current.tagName == 'symbol') {
        final viewportTransform = _computeSingleViewportTransform(current);
        if (viewportTransform != null) {
          transformStack.add(viewportTransform);
        }
      }
      current = current.parent;
    }

    // Compose transforms from root to current (reverse order)
    var result = Matrix4.identity();
    for (int i = transformStack.length - 1; i >= 0; i--) {
      result = result.multiplied(transformStack[i]);
    }
    return result;
  }

  /// Computes the viewport transform for a single SVG/symbol element.
  /// Returns null if no viewBox is defined (1:1 coordinate mapping).
  Matrix4? _computeSingleViewportTransform(SvgNode svgNode) {
    final viewBoxAttr = _getString(svgNode, 'viewBox');
    if (viewBoxAttr == null || viewBoxAttr.trim().isEmpty) {
      return null;
    }

    final viewBox = _parseViewBox(viewBoxAttr);
    if (viewBox == null || viewBox.width <= 0 || viewBox.height <= 0) {
      return null;
    }

    // Get SVG/symbol viewport dimensions
    final width = _getNumber(svgNode, 'width');
    final height = _getNumber(svgNode, 'height');
    if (width == null || height == null || width <= 0 || height <= 0) {
      // Without explicit dimensions, use viewBox dimensions (1:1)
      return Matrix4.identity()
        ..translateByDouble(-viewBox.left, -viewBox.top, 0, 1);
    }

    final layout = resolveSvgViewportLayout(
      viewport: ui.Rect.fromLTWH(0, 0, width, height),
      sourceSize: ui.Size(viewBox.width, viewBox.height),
      preserveAspectRatio: _getString(svgNode, 'preserveAspectRatio'),
    );

    final scaleX = layout.destinationRect.width / viewBox.width;
    final scaleY = layout.destinationRect.height / viewBox.height;
    final translateX = layout.destinationRect.left - viewBox.left * scaleX;
    final translateY = layout.destinationRect.top - viewBox.top * scaleY;

    return Matrix4.identity()
      ..translateByDouble(translateX, translateY, 0, 1)
      ..scaleByDouble(scaleX, scaleY, 1, 1);
  }

  /// Determines if image is within nested SVG structure (SVG-in-SVG).
  /// Returns the nesting depth (0 = root, 1+ = nested).
  int _getSvgNestingDepth(SvgNode node) {
    int depth = 0;
    SvgNode? current = node.parent;
    while (current != null) {
      if (current.tagName == 'svg') {
        depth++;
      }
      current = current.parent;
    }
    return depth;
  }
}
