part of 'animated_svg_picture.dart';

extension _AnimatedSvgPictureStateTransformExtension
    on _AnimatedSvgPictureState {
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

  /// Applies nested SVG viewport transform within foreignObject for hit-testing.
  void _applyNestedSvgTransformInForeignObject(
    Matrix4 matrix,
    SvgNode svgNode,
    SvgNode foreignObjectNode,
  ) {
    if (svgNode.tagName != 'svg') {
      return;
    }
    if (foreignObjectNode.tagName != 'foreignObject') {
      return;
    }

    // Get foreignObject viewport dimensions
    final foWidth = _getNumber(foreignObjectNode, 'width') ?? 0.0;
    final foHeight = _getNumber(foreignObjectNode, 'height') ?? 0.0;
    if (foWidth <= 0 || foHeight <= 0) {
      return;
    }

    // Get nested SVG attributes
    final svgX = _getNumber(svgNode, 'x') ?? 0.0;
    final svgY = _getNumber(svgNode, 'y') ?? 0.0;
    var svgWidth = _getNumber(svgNode, 'width');
    var svgHeight = _getNumber(svgNode, 'height');

    // Default width/height to 100% of foreignObject viewport
    svgWidth ??= foWidth;
    svgHeight ??= foHeight;

    if (svgWidth <= 0 || svgHeight <= 0) {
      return;
    }

    // Translate to SVG position
    if (svgX != 0 || svgY != 0) {
      matrix.translateByDouble(svgX, svgY, 0, 1);
    }

    // Apply viewBox transform if present
    final viewBoxAttr = svgNode.getAttributeValue('viewBox')?.toString();
    if (viewBoxAttr != null && viewBoxAttr.trim().isNotEmpty) {
      final viewBox = _parseViewBoxRect(viewBoxAttr);
      if (viewBox != null && viewBox.width > 0 && viewBox.height > 0) {
        final layout = resolveSvgViewportLayout(
          viewport: Rect.fromLTWH(0, 0, svgWidth, svgHeight),
          sourceSize: Size(viewBox.width, viewBox.height),
          preserveAspectRatio:
              svgNode.getAttributeValue('preserveAspectRatio')?.toString(),
        );

        // Compute viewBox to viewport transform
        final scaleX = layout.destinationRect.width / viewBox.width;
        final scaleY = layout.destinationRect.height / viewBox.height;
        final translateX = layout.destinationRect.left - viewBox.left * scaleX;
        final translateY = layout.destinationRect.top - viewBox.top * scaleY;

        matrix.translateByDouble(translateX, translateY, 0, 1);
        matrix.scaleByDouble(scaleX, scaleY, 1, 1);
      }
    }
  }

  Rect? _parseViewBoxRect(String viewBoxStr) {
    final parts = viewBoxStr.trim().split(RegExp(r'[\s,]+'));
    if (parts.length < 4) return null;
    final minX = double.tryParse(parts[0]);
    final minY = double.tryParse(parts[1]);
    final width = double.tryParse(parts[2]);
    final height = double.tryParse(parts[3]);
    if (minX == null || minY == null || width == null || height == null) {
      return null;
    }
    return Rect.fromLTWH(minX, minY, width, height);
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
}
