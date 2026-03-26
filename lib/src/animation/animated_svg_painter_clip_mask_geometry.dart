part of 'animated_svg_painter.dart';

extension AnimatedSvgPainterClipMaskGeometryExtension on AnimatedSvgPainter {
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
        for (final child in node.children) {
          _appendClipGeometry(
            target: target,
            node: child,
            currentTransform: matrix,
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
        final hrefId = _extractHrefId(node);
        if (hrefId == null || hrefId.isEmpty || useStack.contains(hrefId)) {
          return;
        }
        // Limit recursion depth for nested <use> elements (Blink limits to ~10).
        if (useStack.length >= _kMaxUseRecursionDepth) {
          return;
        }
        final referenced = document.root.findById(hrefId);
        if (referenced == null ||
            !_isUseReferenceAllowedTag(referenced.tagName)) {
          return;
        }
        
        // Apply use element's x/y translation first
        final x = _getNumber(node, 'x') ?? 0.0;
        final y = _getNumber(node, 'y') ?? 0.0;
        final translated = Matrix4.copy(matrix)
          ..multiply(
            Matrix4.identity()
              ..setEntry(0, 3, x)
              ..setEntry(1, 3, y),
          );
        
        // Apply use element's own transform attribute if present
        final useTransformStr = node.getAttributeValue('transform')?.toString();
        if (useTransformStr != null && useTransformStr.isNotEmpty) {
          final useTransform = _buildTransformMatrixFromValue(useTransformStr);
          if (useTransform != null) {
            translated.multiply(useTransform);
          }
        }
        
        // Apply viewport transform for symbol/svg references with viewBox
        if (_isUseViewportReferenceTag(referenced.tagName)) {
          final viewportTransform = _resolveUseViewportTransform(
            useNode: node,
            referenceNode: referenced,
          );
          if (viewportTransform != null) {
            translated.multiply(viewportTransform.matrix);
          }
        }
        
        final nextUseStack = <String>{...useStack, hrefId};
        _appendClipGeometry(
          target: target,
          node: referenced,
          currentTransform: translated,
          useStack: nextUseStack,
        );
        return;
      case 'text':
      case 'tspan':
        // Text as clip child: use text bounding box as clip region
        // Per SVG spec, text within clipPath uses glyph outlines.
        // We approximate this with the text's bounding rectangle.
        final textPath = _buildTextClipPath(node);
        if (textPath != null) {
          target.addPath(textPath.transform(matrix.storage), ui.Offset.zero);
        }
        return;
      default:
        final path = _buildGeometryPath(node);
        if (path == null) {
          return;
        }
        target.addPath(path.transform(matrix.storage), ui.Offset.zero);
    }
  }

  /// Builds a clip path from text element for use in clipPath.
  ///
  /// Per SVG spec, text within a clipPath should be converted to glyph outlines.
  /// Since Flutter doesn't provide direct access to font glyph paths, we
  /// approximate using the text's bounding rectangle. For more precise clipping,
  /// glyph metrics would need to be parsed from font data.
  ui.Path? _buildTextClipPath(SvgNode textNode) {
    final bounds = _computeTextClipBounds(textNode);
    if (bounds == null) {
      return null;
    }
    // Create a path from text bounds
    return ui.Path()..addRect(bounds);
  }

  /// Computes text bounds for clip path geometry.
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
    // This is a rough estimate; actual rendering would use proper font metrics
    final estimatedCharWidth = fontSize * 0.6; // Average character width
    final textWidth = textContent.length * estimatedCharWidth;
    final textHeight = fontSize * 1.2; // Line height factor

    // Text baseline is at y, so bounds extend above
    final top = y - fontSize;
    final bottom = y + (textHeight - fontSize);

    return ui.Rect.fromLTRB(x, top, x + textWidth, bottom);
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
