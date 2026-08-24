part of 'animated_svg_painter.dart';

void _paintFullSvgDebugHighlight(
  AnimatedSvgPainter painter,
  ui.Canvas canvas,
  SvgNode root,
  SvgNode target,
) {
  bool visit(SvgNode node, SvgNode? foreignObjectParent) {
    canvas.save();
    try {
      painter._applyTransform(canvas, node);
      painter._applyForeignObjectViewport(canvas, node);
      painter._applyNestedSvgViewportInForeignObject(
        canvas,
        node,
        foreignObjectParent,
      );
      painter._applyNestedSvgViewport(canvas, node, foreignObjectParent);

      if (identical(node, target)) {
        final geometry = painter._buildGeometryPath(node);
        final bounds = painter._resolveFilterTargetBounds(node);
        final fillPaint = ui.Paint()
          ..color = const ui.Color(0x3339D0FF)
          ..style = ui.PaintingStyle.fill;
        final strokePaint = ui.Paint()
          ..color = const ui.Color(0xFF00B8F0)
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = 1.75;
        if (geometry != null) {
          canvas.drawPath(geometry, fillPaint);
          canvas.drawPath(geometry, strokePaint);
        } else if (bounds.width > 0 && bounds.height > 0) {
          canvas.drawRect(bounds, fillPaint);
          canvas.drawRect(bounds, strokePaint);
        }
        return true;
      }

      final childForeignObjectParent = _childForeignObjectParent(
        node,
        foreignObjectParent,
      );
      for (final child in node.children) {
        if (visit(child, childForeignObjectParent)) return true;
      }
      return false;
    } finally {
      canvas.restore();
    }
  }

  visit(root, null);
}
