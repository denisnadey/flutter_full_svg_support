part of 'animated_svg_painter.dart';

extension AnimatedSvgPainterShapesExtension on AnimatedSvgPainter {
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

    if (fillPaint != null) {
      canvas.drawCircle(center, r, fillPaint);
    }

    final strokePaint = _createStrokePaint(
      node,
      paintBounds: bounds,
      imageFilter: imageFilter,
      colorFilter: colorFilter,
      blendMode: blendMode,
    );
    if (strokePaint != null) {
      final circlePath = ui.Path()..addOval(bounds);
      final dashedPath = _buildDashedPath(circlePath, node);
      canvas.drawPath(dashedPath, strokePaint);
    }
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

    if (fillPaint != null) {
      canvas.drawOval(rect, fillPaint);
    }

    final strokePaint = _createStrokePaint(
      node,
      paintBounds: rect,
      imageFilter: imageFilter,
      colorFilter: colorFilter,
      blendMode: blendMode,
    );
    if (strokePaint != null) {
      final ellipsePath = ui.Path()..addOval(rect);
      final dashedPath = _buildDashedPath(ellipsePath, node);
      canvas.drawPath(dashedPath, strokePaint);
    }
  }

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
    if (strokePaint != null) {
      final linePath = ui.Path()
        ..moveTo(x1, y1)
        ..lineTo(x2, y2);
      final dashedPath = _buildDashedPath(linePath, node);
      canvas.drawPath(dashedPath, strokePaint);
    }
  }
}
