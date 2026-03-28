part of 'animated_svg_painter.dart';

/// Extension for line shapes.
extension AnimatedSvgPainterShapesLinesExtension on AnimatedSvgPainter {
  /// Рисует <line>
  void _paintLine(
    ui.Canvas canvas,
    SvgNode node, {
    ui.ImageFilter? imageFilter,
    ui.ColorFilter? colorFilter,
    ui.BlendMode? blendMode,
  }) {
    final x1 = _getNumber(node, 'x1') ?? 0.0;
    final y1 = _getNumber(node, 'y1') ?? 0.0;
    final x2 = _getNumber(node, 'x2') ?? 0.0;
    final y2 = _getNumber(node, 'y2') ?? 0.0;

    final bounds = ui.Rect.fromPoints(ui.Offset(x1, y1), ui.Offset(x2, y2));
    final strokePaint = _createStrokePaint(
      node,
      paintBounds: bounds,
      imageFilter: imageFilter,
      colorFilter: colorFilter,
      blendMode: blendMode,
    );
    final linePath = ui.Path()
      ..moveTo(x1, y1)
      ..lineTo(x2, y2);

    _paintWithOrder(
      node,
      () {
        // Line has no fill
      },
      () {
        if (strokePaint != null) {
          final dashedPath = _buildDashedPath(linePath, node);
          canvas.drawPath(dashedPath, strokePaint);
        }
      },
      paintMarkers: () {
        // Paint markers at endpoints
        if (strokePaint != null) {
          _paintMarkers(
            canvas,
            node,
            linePath,
            imageFilter: imageFilter,
            colorFilter: colorFilter,
            blendMode: blendMode,
          );
        }
      },
    );
  }
}
