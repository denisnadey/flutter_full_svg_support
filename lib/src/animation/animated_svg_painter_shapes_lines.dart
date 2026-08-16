part of 'animated_svg_painter.dart';

/// Extension for line shapes.
extension AnimatedSvgPainterShapesLinesExtension on AnimatedSvgPainter {
  /// Paints `<line>`
  void _paintLine(
    ui.Canvas canvas,
    SvgNode node, {
    ui.ImageFilter? imageFilter,
    ui.ColorFilter? colorFilter,
    ui.BlendMode? blendMode,
  }) {
    final x1 =
        resolveSvgLength(
          node,
          document,
          'x1',
          reference: SvgLengthReference.horizontal,
        ) ??
        0.0;
    final y1 =
        resolveSvgLength(
          node,
          document,
          'y1',
          reference: SvgLengthReference.vertical,
        ) ??
        0.0;
    final x2 =
        resolveSvgLength(
          node,
          document,
          'x2',
          reference: SvgLengthReference.horizontal,
        ) ??
        0.0;
    final y2 =
        resolveSvgLength(
          node,
          document,
          'y2',
          reference: SvgLengthReference.vertical,
        ) ??
        0.0;

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
