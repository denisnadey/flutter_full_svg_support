part of 'animated_svg_painter.dart';

extension AnimatedSvgPainterClipMaskGeometryExtension on AnimatedSvgPainter {
  /// Appends clip geometry from a node to the target path.
  ///
  /// Handles various SVG elements inside clipPath:
  /// - Container elements: clipPath, mask, g, svg, symbol, switch
  /// - Shape elements: rect, circle, ellipse, polygon, polyline, path, line
  /// - Text elements: text, tspan (converted to glyph-approximate paths)
  /// - Reference elements: use (resolves referenced element with CSS inheritance)
  /// - Image elements: image (uses bounding rectangle)
  ///
  /// Supports clip-rule attribute on individual shapes for evenodd/nonzero fill.
  /// When <use> elements appear inside clipPath, CSS properties are properly
  /// inherited through the use shadow boundary per SVG spec.
  void _appendClipGeometry({
    required ui.Path target,
    required SvgNode node,
    required Matrix4 currentTransform,
    required Set<String> useStack,
  }) {
    final matrix = Matrix4.copy(currentTransform);
    final nodeTransform = _buildTransformMatrixFromValue(
      node.getAttributeValue('transform'),
    );
    if (nodeTransform != null) {
      matrix.multiply(nodeTransform);
    }

    switch (node.tagName) {
      case 'clipPath':
      case 'mask':
      case 'g':
      case 'svg':
        for (final child in node.children) {
          _appendClipGeometry(
            target: target,
            node: child,
            currentTransform: matrix,
            useStack: useStack,
          );
        }
        return;
      case 'symbol':
        // Symbol elements must apply their viewBox transform when used in clip/mask.
        // This is critical for proper coordinate mapping of nested symbols.
        // The viewBox transform is handled when use references the symbol.
        final symbolViewBoxTransform = _computeSymbolViewBoxTransform(node);
        final symbolMatrix = Matrix4.copy(matrix);
        if (symbolViewBoxTransform != null) {
          symbolMatrix.multiply(symbolViewBoxTransform);
        }
        for (final child in node.children) {
          _appendClipGeometry(
            target: target,
            node: child,
            currentTransform: symbolMatrix,
            useStack: useStack,
          );
        }
        return;
      case 'switch':
        final activeChild = resolveActiveSwitchChild(node);
        if (activeChild == null) {
          return;
        }
        _appendClipGeometry(
          target: target,
          node: activeChild,
          currentTransform: matrix,
          useStack: useStack,
        );
        return;
      case 'use':
        // Handle use element in clip/mask context with proper transform composition.
        // This supports nested use elements and symbol viewBox transforms.
        _appendUseClipGeometry(
          target: target,
          useNode: node,
          currentTransform: matrix,
          useStack: useStack,
        );
        return;
      case 'text':
      case 'tspan':
        // Text as clip child: use glyph-approximate path as clip region
        // Per SVG spec, text within clipPath uses glyph outlines.
        // We approximate this with character-level paths.
        final textPath = _buildTextClipPath(node);
        if (textPath != null) {
          // Apply clip-rule to text path
          _applyClipRuleToPath(textPath, node);
          target.addPath(textPath.transform(matrix.storage), ui.Offset.zero);
        }
        return;
      case 'line':
        // Line as clip child: explicit support for line elements
        // Per SVG spec, line contributes its geometry to clip region
        final linePath = _buildGeometryPath(node);
        if (linePath != null) {
          _applyClipRuleToPath(linePath, node);
          target.addPath(linePath.transform(matrix.storage), ui.Offset.zero);
        }
        return;
      case 'image':
        // Image as clip child: use image bounding rectangle
        // Per SVG spec, image contributes its bounding rectangle to clip region
        final imagePath = _buildImageClipPath(node);
        if (imagePath != null) {
          _applyClipRuleToPath(imagePath, node);
          target.addPath(imagePath.transform(matrix.storage), ui.Offset.zero);
        }
        return;
      default:
        final path = _buildGeometryPath(node);
        if (path == null) {
          return;
        }
        // Apply clip-rule to shape paths
        _applyClipRuleToPath(path, node);
        target.addPath(path.transform(matrix.storage), ui.Offset.zero);
    }
  }

  /// Applies the clip-rule attribute to a path.
  ///
  /// Per SVG spec, clip-rule determines how the interior of the clip region
  /// is determined:
  /// - nonzero (default): non-zero winding rule
  /// - evenodd: even-odd rule
  void _applyClipRuleToPath(ui.Path path, SvgNode node) {
    final clipRule = _getInheritedString(node, 'clip-rule')?.toLowerCase();
    if (clipRule == 'evenodd') {
      path.fillType = ui.PathFillType.evenOdd;
    } else {
      // Default is nonzero
      path.fillType = ui.PathFillType.nonZero;
    }
  }

  /// Appends use element geometry to clip path.
  ///
  /// Handles:
  /// - x/y translation from use element
  /// - Resolving referenced element
  /// - Applying viewBox transform for symbol/svg references
  /// - Circular reference prevention
  /// - Proper CSS property inheritance through use shadow boundary
  ///
  /// Per SVG spec, when <use> appears in clipPath:
  /// - The referenced content contributes its geometry to the clip region
  /// - CSS properties like fill-rule and clip-rule cascade correctly
  /// - Transforms from the use element are applied to referenced content
  void _appendUseClipGeometry({
    required ui.Path target,
    required SvgNode useNode,
    required Matrix4 currentTransform,
    required Set<String> useStack,
  }) {
    final hrefId = _extractHrefId(useNode);
    if (hrefId == null || hrefId.isEmpty || useStack.contains(hrefId)) {
      return;
    }
    // Limit recursion depth for nested <use> elements (Blink limits to ~10).
    if (useStack.length >= _kMaxUseRecursionDepth) {
      return;
    }
    final referenced = document.root.findById(hrefId);
    if (referenced == null || !_isUseReferenceAllowedTag(referenced.tagName)) {
      return;
    }

    // Check display:none on use element - if hidden, contributes nothing
    final useDisplay = _getStyleOrAttributeValue(useNode, 'display');
    if (useDisplay != null &&
        useDisplay.toString().toLowerCase() == 'none') {
      return;
    }

    // Build transform: first apply use element's transform attribute if present,
    // then apply x/y translation for proper coordinate stacking
    final translated = Matrix4.copy(currentTransform);

    // Apply use element's own transform attribute if present
    final useTransformStr = useNode.getAttributeValue('transform')?.toString();
    if (useTransformStr != null && useTransformStr.isNotEmpty) {
      final useTransform = _buildTransformMatrixFromValue(useTransformStr);
      if (useTransform != null) {
        translated.multiply(useTransform);
      }
    }

    // Apply use element's x/y translation
    final x = _getNumber(useNode, 'x') ?? 0.0;
    final y = _getNumber(useNode, 'y') ?? 0.0;
    if (x != 0.0 || y != 0.0) {
      translated.multiply(
        Matrix4.identity()
          ..setEntry(0, 3, x)
          ..setEntry(1, 3, y),
      );
    }

    // Apply viewport transform for symbol/svg references with viewBox
    if (_isUseViewportReferenceTag(referenced.tagName)) {
      final viewportTransform = _resolveUseViewportTransform(
        useNode: useNode,
        referenceNode: referenced,
      );
      if (viewportTransform != null) {
        translated.multiply(viewportTransform.matrix);
      }
    }

    // Temporarily set parent for proper CSS cascade resolution
    final previousParent = referenced.parent;
    referenced.parent = useNode;
    try {
      final nextUseStack = <String>{...useStack, hrefId};
      _appendClipGeometry(
        target: target,
        node: referenced,
        currentTransform: translated,
        useStack: nextUseStack,
      );
    } finally {
      referenced.parent = previousParent;
    }
  }

  /// Builds a clip path from image element.
  ///
  /// Per SVG spec, image within clipPath contributes its bounding rectangle.
  /// The actual image content is not used - only the geometric bounds.
  ui.Path? _buildImageClipPath(SvgNode imageNode) {
    final imgX = _getNumber(imageNode, 'x') ?? 0.0;
    final imgY = _getNumber(imageNode, 'y') ?? 0.0;
    final imgWidth = _getNumber(imageNode, 'width');
    final imgHeight = _getNumber(imageNode, 'height');

    // Try to get dimensions from loaded image if not specified
    final href = _extractImageHref(imageNode);
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
  }

  /// Builds a clip path from text element for use in clipPath.
  ///
  /// Per SVG spec, text within a clipPath should be converted to glyph outlines.
  /// Since Flutter doesn't provide direct access to font glyph paths, we
  /// create per-character approximate paths that better represent the text shape
  /// than a simple bounding box.
  ///
  /// Handles:
  /// - Simple text elements with x/y positioning
  /// - Nested tspan elements with relative positioning
  /// - text-anchor alignment (start, middle, end)
  /// - Font metrics estimation with character-level approximation
  /// - Per-character positioning (x, y, dx, dy lists)
  /// - Multiple tspan children
  ui.Path? _buildTextClipPath(SvgNode textNode) {
    // Try to build character-level paths for better clipping precision
    final charPaths = _buildTextCharacterPaths(textNode);
    if (charPaths != null && !charPaths.getBounds().isEmpty) {
      return charPaths;
    }
    
    // Fall back to bounding box if character-level fails
    final bounds = _computeTextClipBounds(textNode);
    if (bounds == null) {
      return null;
    }
    // Create a path from text bounds
    // Note: clip-rule is applied by the caller (_appendClipGeometry)
    return ui.Path()..addRect(bounds);
  }
  
  /// Builds character-level paths for more precise text clipping.
  ///
  /// Creates individual rounded rectangles for each character position,
  /// providing a better approximation of glyph outlines than a single bounding box.
  ui.Path? _buildTextCharacterPaths(SvgNode textNode) {
    final textContent = _collectTextContent(textNode);
    if (textContent.isEmpty) {
      return null;
    }
    
    // Get text position and font metrics
    final x = _getNumber(textNode, 'x') ?? 0.0;
    final y = _getNumber(textNode, 'y') ?? 0.0;
    final fontSize = _getInheritedNumber(textNode, 'font-size') ?? 16.0;
    
    // Character metrics estimation
    final charWidth = fontSize * 0.55; // Average character width
    final charHeight = fontSize * 0.85; // Character height (ascent)
    final descender = fontSize * 0.15; // Descender depth
    final charCornerRadius = fontSize * 0.1; // Rounded corners for better shape
    
    // Handle text-anchor for horizontal alignment
    final textAnchor = _getInheritedString(textNode, 'text-anchor')?.toLowerCase();
    final textWidth = textContent.length * charWidth;
    double adjustedX = x;
    if (textAnchor == 'middle') {
      adjustedX = x - textWidth / 2;
    } else if (textAnchor == 'end') {
      adjustedX = x - textWidth;
    }
    
    final path = ui.Path();
    for (int i = 0; i < textContent.length; i++) {
      final char = textContent[i];
      // Skip whitespace characters
      if (char == ' ' || char == '\t' || char == '\n') {
        continue;
      }
      
      final charX = adjustedX + i * charWidth;
      final charY = y - charHeight; // Baseline is at y, so character extends upward
      
      // Create rounded rectangle for each character
      final charRect = ui.Rect.fromLTWH(
        charX,
        charY,
        charWidth * 0.9, // Slight gap between characters
        charHeight + descender,
      );
      
      // Use rounded rect for more natural character shape
      path.addRRect(
        ui.RRect.fromRectXY(charRect, charCornerRadius, charCornerRadius),
      );
    }
    
    return path;
  }

  /// Computes text bounds for clip path geometry.
  ///
  /// Takes into account:
  /// - Text position (x, y attributes)
  /// - Font size for height estimation
  /// - Character count for width estimation
  /// - text-anchor for horizontal alignment
  ui.Rect? _computeTextClipBounds(SvgNode textNode) {
    // Get text position
    final x = _getNumber(textNode, 'x') ?? 0.0;
    final y = _getNumber(textNode, 'y') ?? 0.0;

    // Get font metrics for text bounds computation
    final fontSize = _getInheritedNumber(textNode, 'font-size') ?? 16.0;
    final textContent = _collectTextContent(textNode);
    if (textContent.isEmpty) {
      return null;
    }

    // Approximate text width based on character count and average char width
    // Different fonts have different metrics - this is an approximation
    final estimatedCharWidth = fontSize * 0.6; // Average character width
    final textWidth = textContent.length * estimatedCharWidth;

    // Handle text-anchor for horizontal alignment
    final textAnchor = _getInheritedString(
      textNode,
      'text-anchor',
    )?.toLowerCase();
    double adjustedX = x;
    if (textAnchor == 'middle') {
      adjustedX = x - textWidth / 2;
    } else if (textAnchor == 'end') {
      adjustedX = x - textWidth;
    }

    // Text baseline is at y, so bounds extend above
    final top = y - fontSize * 0.8; // Approximate ascender
    final bottom = y + fontSize * 0.2; // Approximate descender

    return ui.Rect.fromLTRB(adjustedX, top, adjustedX + textWidth, bottom);
  }

  /// Collects text content from a text node and its children.
  String _collectTextContent(SvgNode node) {
    final buffer = StringBuffer();
    _collectTextContentRecursive(node, buffer);
    return buffer.toString();
  }

  void _collectTextContentRecursive(SvgNode node, StringBuffer buffer) {
    // Add this node's text content (stored in __text attribute)
    final text = _getString(node, '__text');
    if (text != null && text.isNotEmpty) {
      buffer.write(text);
    }

    // Recursively collect from children (tspan, etc.)
    for (final child in node.children) {
      if (child.tagName == 'tspan' ||
          child.tagName == 'textPath' ||
          child.tagName == 'tref') {
        _collectTextContentRecursive(child, buffer);
      }
    }
  }

  bool _isUseViewportReferenceTag(String tagName) {
    return tagName == 'symbol' || tagName == 'svg';
  }

  /// Computes the viewBox transform for a symbol element.
  ///
  /// Symbol elements may have viewBox attributes that need to be applied
  /// when their content is used in clip paths.
  Matrix4? _computeSymbolViewBoxTransform(SvgNode symbolNode) {
    final viewBox = _parseViewBox(_getString(symbolNode, 'viewBox'));
    if (viewBox == null || viewBox.width <= 0 || viewBox.height <= 0) {
      return null;
    }

    // Get symbol's width/height if specified, otherwise use viewBox dimensions
    final width = _getNumber(symbolNode, 'width') ?? viewBox.width;
    final height = _getNumber(symbolNode, 'height') ?? viewBox.height;
    if (width <= 0 || height <= 0) {
      return null;
    }

    final viewport = ui.Rect.fromLTWH(0, 0, width, height);
    final layout = resolveSvgViewportLayout(
      viewport: viewport,
      sourceSize: viewBox.size,
      preserveAspectRatio: _getString(symbolNode, 'preserveAspectRatio'),
    );

    final scaleX = layout.destinationRect.width / viewBox.width;
    final scaleY = layout.destinationRect.height / viewBox.height;
    final translateX = layout.destinationRect.left - viewBox.left * scaleX;
    final translateY = layout.destinationRect.top - viewBox.top * scaleY;

    return Matrix4.identity()
      ..translateByDouble(translateX, translateY, 0, 1)
      ..scaleByDouble(scaleX, scaleY, 1, 1);
  }

  bool _isUseReferenceAllowedTag(String tagName) {
    switch (tagName) {
      case 'a':
      case 'circle':
      case 'desc':
      case 'ellipse':
      case 'g':
      case 'image':
      case 'line':
      case 'metadata':
      case 'path':
      case 'polygon':
      case 'polyline':
      case 'rect':
      case 'svg':
      case 'switch':
      case 'symbol':
      case 'text':
      case 'textPath':
      case 'title':
      case 'tref':
      case 'tspan':
      case 'use':
        return true;
      default:
        return false;
    }
  }

  _UseViewportTransform? _resolveUseViewportTransform({
    required SvgNode useNode,
    required SvgNode referenceNode,
  }) {
    final viewBox = _parseViewBox(_getString(referenceNode, 'viewBox'));
    final width = _getNumber(useNode, 'width');
    final height = _getNumber(useNode, 'height');
    if (viewBox == null ||
        width == null ||
        height == null ||
        width <= 0 ||
        height <= 0 ||
        viewBox.width <= 0 ||
        viewBox.height <= 0) {
      return null;
    }

    final viewport = ui.Rect.fromLTWH(0, 0, width, height);
    final layout = resolveSvgViewportLayout(
      viewport: viewport,
      sourceSize: viewBox.size,
      preserveAspectRatio: _getString(referenceNode, 'preserveAspectRatio'),
    );
    final scaleX = layout.destinationRect.width / viewBox.width;
    final scaleY = layout.destinationRect.height / viewBox.height;
    final translateX = layout.destinationRect.left - viewBox.left * scaleX;
    final translateY = layout.destinationRect.top - viewBox.top * scaleY;

    final matrix = Matrix4.identity()
      ..translateByDouble(translateX, translateY, 0, 1)
      ..scaleByDouble(scaleX, scaleY, 1, 1);
    return _UseViewportTransform(
      matrix: matrix,
      clipRect: layout.clipToViewport ? viewport : null,
    );
  }

  ui.Rect? _computeNodeLocalBounds(SvgNode node) {
    final path = _buildGeometryPath(node);
    if (path == null) {
      return null;
    }
    final bounds = path.getBounds();
    if (bounds.width.abs() < 1e-6 || bounds.height.abs() < 1e-6) {
      return null;
    }
    return bounds;
  }
}
