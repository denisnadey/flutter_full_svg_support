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
    final x =
        _getLengthWithViewportSupport(node, 'x', isHorizontal: true) ?? 0.0;
    final y =
        _getLengthWithViewportSupport(node, 'y', isHorizontal: false) ?? 0.0;
    final width =
        _getLengthWithViewportSupport(node, 'width', isHorizontal: true) ?? 0.0;
    final height =
        _getLengthWithViewportSupport(node, 'height', isHorizontal: false) ??
        0.0;

    // SVG spec: rx/ry handling
    // - If neither rx nor ry are specified, both default to 0
    // - If rx is specified but not ry, ry = rx (and vice versa)
    // - Negative values are an error (don't render)
    // - Values greater than half width/height are clamped
    final rxRaw = _getNumber(node, 'rx');
    final ryRaw = _getNumber(node, 'ry');

    double rx;
    double ry;
    if (rxRaw == null && ryRaw == null) {
      rx = 0.0;
      ry = 0.0;
    } else if (rxRaw != null && ryRaw == null) {
      rx = rxRaw;
      ry = rxRaw;
    } else if (rxRaw == null && ryRaw != null) {
      rx = ryRaw;
      ry = ryRaw;
    } else {
      rx = rxRaw!;
      ry = ryRaw!;
    }

    // Negative rx/ry is an error - don't render
    if (rx < 0 || ry < 0) return;

    // Clamp rx/ry to half of width/height
    rx = rx.clamp(0.0, width / 2);
    ry = ry.clamp(0.0, height / 2);

    if (width <= 0 || height <= 0) return;

    final rect = ui.Rect.fromLTWH(x, y, width, height);
    final fillPaint = _createFillPaint(
      node,
      paintBounds: rect,
      imageFilter: imageFilter,
      colorFilter: colorFilter,
      blendMode: blendMode,
    );
    final strokePaint = _createStrokePaint(
      node,
      paintBounds: rect,
      imageFilter: imageFilter,
      colorFilter: colorFilter,
      blendMode: blendMode,
    );

    _paintWithOrder(
      node,
      () {
        if (fillPaint != null) {
          if (rx > 0 || ry > 0) {
            final rrect = ui.RRect.fromRectXY(rect, rx, ry);
            canvas.drawRRect(rrect, fillPaint);
          } else {
            canvas.drawRect(rect, fillPaint);
          }
        }
      },
      () {
        if (strokePaint != null) {
          // Convert to path for dasharray/dashoffset support.
          final strokePath = (rx > 0 || ry > 0)
              ? (ui.Path()..addRRect(ui.RRect.fromRectXY(rect, rx, ry)))
              : (ui.Path()..addRect(rect));
          final dashedPath = _buildDashedPath(strokePath, node);
          canvas.drawPath(dashedPath, strokePaint);
        }
      },
    );
  }
}
