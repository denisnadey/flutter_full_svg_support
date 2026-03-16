part of 'animated_svg_painter.dart';

extension AnimatedSvgPainterShapesRectExtension on AnimatedSvgPainter {
  /// Рисует <rect>
  void _paintRect(
    ui.Canvas canvas,
    SvgNode node, {
    ui.ImageFilter? imageFilter,
    ui.ColorFilter? colorFilter,
    ui.BlendMode? blendMode,
  }) {
    final x = _getNumber(node, 'x') ?? 0.0;
    final y = _getNumber(node, 'y') ?? 0.0;
    final width = _getNumber(node, 'width') ?? 0.0;
    final height = _getNumber(node, 'height') ?? 0.0;
    final rx = _getNumber(node, 'rx') ?? 0.0;
    final ry = _getNumber(node, 'ry') ?? rx;

    if (width <= 0 || height <= 0) return;

    final rect = ui.Rect.fromLTWH(x, y, width, height);
    final fillPaint = _createFillPaint(
      node,
      paintBounds: rect,
      imageFilter: imageFilter,
      colorFilter: colorFilter,
      blendMode: blendMode,
    );

    if (fillPaint != null) {
      if (rx > 0 || ry > 0) {
        final rrect = ui.RRect.fromRectXY(rect, rx, ry);
        canvas.drawRRect(rrect, fillPaint);
      } else {
        canvas.drawRect(rect, fillPaint);
      }
    }

    // Stroke если указан.
    final strokePaint = _createStrokePaint(
      node,
      paintBounds: rect,
      imageFilter: imageFilter,
      colorFilter: colorFilter,
      blendMode: blendMode,
    );
    if (strokePaint != null) {
      // Convert to path for dasharray/dashoffset support.
      final strokePath = (rx > 0 || ry > 0)
          ? (ui.Path()..addRRect(ui.RRect.fromRectXY(rect, rx, ry)))
          : (ui.Path()..addRect(rect));
      final dashedPath = _buildDashedPath(strokePath, node);
      canvas.drawPath(dashedPath, strokePaint);
    }
  }
}
