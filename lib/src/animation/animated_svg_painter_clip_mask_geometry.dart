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
      case 'symbol':
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
        final hrefId = _extractHrefId(node);
        if (hrefId == null || hrefId.isEmpty || useStack.contains(hrefId)) {
          return;
        }
        final referenced = document.root.findById(hrefId);
        if (referenced == null ||
            !_isUseReferenceAllowedTag(referenced.tagName)) {
          return;
        }
        final x = _getNumber(node, 'x') ?? 0.0;
        final y = _getNumber(node, 'y') ?? 0.0;
        final translated = Matrix4.copy(matrix)
          ..multiply(
            Matrix4.identity()
              ..setEntry(0, 3, x)
              ..setEntry(1, 3, y),
          );
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
      default:
        final path = _buildGeometryPath(node);
        if (path == null) {
          return;
        }
        target.addPath(path.transform(matrix.storage), ui.Offset.zero);
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
