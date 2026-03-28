part of 'animated_svg_painter.dart';

/// Extension for foreign object handling in use elements.
extension AnimatedSvgPainterUseForeignObjectExtension on AnimatedSvgPainter {
  /// Checks if foreignObject should be rendered based on requiredExtensions.
  bool _shouldRenderForeignObject(SvgNode node) {
    if (node.tagName != 'foreignObject') {
      return true;
    }
    final requiredExtensions = node.getAttributeValue('requiredExtensions');
    if (requiredExtensions != null &&
        requiredExtensions.toString().trim().isNotEmpty) {
      return false;
    }
    return true;
  }

  void _applyForeignObjectViewport(ui.Canvas canvas, SvgNode node) {
    if (node.tagName != 'foreignObject') {
      return;
    }
    final x = _getNumber(node, 'x') ?? 0.0;
    final y = _getNumber(node, 'y') ?? 0.0;
    final width = _getNumber(node, 'width') ?? 0.0;
    final height = _getNumber(node, 'height') ?? 0.0;
    if (width <= 0 || height <= 0) {
      return;
    }
    canvas.translate(x, y);
    final overflow = _getInheritedString(node, 'overflow')?.toLowerCase();
    if (overflow != 'visible') {
      canvas.clipRect(ui.Rect.fromLTWH(0, 0, width, height), doAntiAlias: true);
    }
  }

  /// Applies nested SVG viewport transform within foreignObject.
  void _applyNestedSvgViewportInForeignObject(
    ui.Canvas canvas,
    SvgNode svgNode,
    SvgNode? foreignObjectParent,
  ) {
    if (svgNode.tagName != 'svg' || foreignObjectParent == null) {
      return;
    }
    if (foreignObjectParent.tagName != 'foreignObject') {
      return;
    }
    final foWidth = _getNumber(foreignObjectParent, 'width') ?? 0.0;
    final foHeight = _getNumber(foreignObjectParent, 'height') ?? 0.0;
    if (foWidth <= 0 || foHeight <= 0) {
      return;
    }
    final svgX = _getNumber(svgNode, 'x') ?? 0.0;
    final svgY = _getNumber(svgNode, 'y') ?? 0.0;
    var svgWidth = _getNumber(svgNode, 'width');
    var svgHeight = _getNumber(svgNode, 'height');
    svgWidth ??= foWidth;
    svgHeight ??= foHeight;
    if (svgWidth <= 0 || svgHeight <= 0) {
      return;
    }
    if (svgX != 0 || svgY != 0) {
      canvas.translate(svgX, svgY);
    }
    final viewBoxAttr = svgNode.getAttributeValue('viewBox')?.toString();
    if (viewBoxAttr != null && viewBoxAttr.trim().isNotEmpty) {
      final viewBox = _parseForeignObjectViewBox(viewBoxAttr);
      if (viewBox != null && viewBox.width > 0 && viewBox.height > 0) {
        final layout = resolveSvgViewportLayout(
          viewport: ui.Rect.fromLTWH(0, 0, svgWidth, svgHeight),
          sourceSize: ui.Size(viewBox.width, viewBox.height),
          preserveAspectRatio: svgNode
              .getAttributeValue('preserveAspectRatio')
              ?.toString(),
        );
        final scaleX = layout.destinationRect.width / viewBox.width;
        final scaleY = layout.destinationRect.height / viewBox.height;
        final translateX = layout.destinationRect.left - viewBox.left * scaleX;
        final translateY = layout.destinationRect.top - viewBox.top * scaleY;
        final transform = Matrix4.identity()
          ..translateByDouble(translateX, translateY, 0, 1)
          ..scaleByDouble(scaleX, scaleY, 1, 1);
        canvas.transform(transform.storage);
        final overflow = svgNode
            .getAttributeValue('overflow')
            ?.toString()
            .toLowerCase();
        if (layout.clipToViewport || overflow != 'visible') {
          canvas.clipRect(
            ui.Rect.fromLTWH(
              viewBox.left,
              viewBox.top,
              viewBox.width,
              viewBox.height,
            ),
            doAntiAlias: true,
          );
        }
      }
    } else {
      final overflow = svgNode
          .getAttributeValue('overflow')
          ?.toString()
          .toLowerCase();
      if (overflow != 'visible') {
        canvas.clipRect(
          ui.Rect.fromLTWH(0, 0, svgWidth, svgHeight),
          doAntiAlias: true,
        );
      }
    }
  }

  ui.Rect? _parseForeignObjectViewBox(String viewBoxStr) {
    final parts = viewBoxStr.trim().split(RegExp(r'[\s,]+'));
    if (parts.length < 4) return null;
    final minX = double.tryParse(parts[0]);
    final minY = double.tryParse(parts[1]);
    final width = double.tryParse(parts[2]);
    final height = double.tryParse(parts[3]);
    if (minX == null || minY == null || width == null || height == null) {
      return null;
    }
    return ui.Rect.fromLTWH(minX, minY, width, height);
  }
}
