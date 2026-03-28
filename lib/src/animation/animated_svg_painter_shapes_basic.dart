part of 'animated_svg_painter.dart';

/// Extension for basic oval-based shapes (circle, ellipse).
extension AnimatedSvgPainterShapesBasicExtension on AnimatedSvgPainter {
  /// Рисует <circle>
  void _paintCircle(
    ui.Canvas canvas,
    SvgNode node, {
    ui.ImageFilter? imageFilter,
    ui.ColorFilter? colorFilter,
    ui.BlendMode? blendMode,
  }) {
    final cx = _getNumber(node, 'cx') ?? 0.0;
    final cy = _getNumber(node, 'cy') ?? 0.0;
    final r = _getNumber(node, 'r') ?? 0.0;

    if (r <= 0) return;

    final center = ui.Offset(cx, cy);
    final bounds = ui.Rect.fromCircle(center: center, radius: r);
    final fillPaint = _createFillPaint(
      node,
      paintBounds: bounds,
      imageFilter: imageFilter,
      colorFilter: colorFilter,
      blendMode: blendMode,
    );
    final strokePaint = _createStrokePaint(
      node,
      paintBounds: bounds,
      imageFilter: imageFilter,
      colorFilter: colorFilter,
      blendMode: blendMode,
    );

    _paintWithOrder(
      node,
      () {
        if (fillPaint != null) {
          canvas.drawCircle(center, r, fillPaint);
        }
      },
      () {
        if (strokePaint != null) {
          final circlePath = ui.Path()..addOval(bounds);
          final dashedPath = _buildDashedPath(circlePath, node);
          canvas.drawPath(dashedPath, strokePaint);
        }
      },
    );
  }

  /// Рисует <ellipse>
  void _paintEllipse(
    ui.Canvas canvas,
    SvgNode node, {
    ui.ImageFilter? imageFilter,
    ui.ColorFilter? colorFilter,
    ui.BlendMode? blendMode,
  }) {
    final cx = _getNumber(node, 'cx') ?? 0.0;
    final cy = _getNumber(node, 'cy') ?? 0.0;
    final rx = _getNumber(node, 'rx') ?? 0.0;
    final ry = _getNumber(node, 'ry') ?? 0.0;

    if (rx <= 0 || ry <= 0) return;

    final rect = ui.Rect.fromCenter(
      center: ui.Offset(cx, cy),
      width: rx * 2,
      height: ry * 2,
    );
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
          canvas.drawOval(rect, fillPaint);
        }
      },
      () {
        if (strokePaint != null) {
          final ellipsePath = ui.Path()..addOval(rect);
          final dashedPath = _buildDashedPath(ellipsePath, node);
          canvas.drawPath(dashedPath, strokePaint);
        }
      },
    );
  }
}
