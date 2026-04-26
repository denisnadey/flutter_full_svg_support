part of 'animated_svg_painter.dart';

extension AnimatedSvgPainterShapesPathExtension on AnimatedSvgPainter {
  /// Paints `<path>`
  void _paintPath(
    ui.Canvas canvas,
    SvgNode node, {
    ui.ImageFilter? imageFilter,
    ui.ColorFilter? colorFilter,
    ui.BlendMode? blendMode,
  }) {
    final pathData = _getString(node, 'd');
    if (pathData == null || pathData.isEmpty) return;

    final path = _buildPath(pathData);
    if (path == null) return;

    // fill-rule is an inheritable property
    final fillRule = _getInheritedString(node, 'fill-rule')?.toLowerCase();
    path.fillType = fillRule == 'evenodd'
        ? ui.PathFillType.evenOdd
        : ui.PathFillType.nonZero;

    final paintBounds = path.getBounds();
    final fillPaint = _createFillPaint(
      node,
      paintBounds: paintBounds,
      imageFilter: imageFilter,
      colorFilter: colorFilter,
      blendMode: blendMode,
    );
    final strokePaint = _createStrokePaint(
      node,
      paintBounds: paintBounds,
      imageFilter: imageFilter,
      colorFilter: colorFilter,
      blendMode: blendMode,
    );

    _paintWithOrder(
      node,
      () {
        if (fillPaint != null) {
          canvas.drawPath(path, fillPaint);
        }
      },
      () {
        if (strokePaint != null) {
          final dashedPath = _buildDashedPath(path, node);
          canvas.drawPath(dashedPath, strokePaint);
        }
      },
      paintMarkers: () {
        // Paint markers at vertices
        _paintMarkers(
          canvas,
          node,
          path,
          imageFilter: imageFilter,
          colorFilter: colorFilter,
          blendMode: blendMode,
        );
      },
    );
  }

  void _paintPolygon(
    ui.Canvas canvas,
    SvgNode node, {
    ui.ImageFilter? imageFilter,
    ui.ColorFilter? colorFilter,
    ui.BlendMode? blendMode,
  }) {
    final points = _parsePoints(node);
    if (points.length < 3) return;

    final path = ui.Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    path.close();

    // fill-rule is an inheritable property
    final fillRule = _getInheritedString(node, 'fill-rule')?.toLowerCase();
    path.fillType = fillRule == 'evenodd'
        ? ui.PathFillType.evenOdd
        : ui.PathFillType.nonZero;

    final paintBounds = path.getBounds();
    final fillPaint = _createFillPaint(
      node,
      paintBounds: paintBounds,
      imageFilter: imageFilter,
      colorFilter: colorFilter,
      blendMode: blendMode,
    );
    final strokePaint = _createStrokePaint(
      node,
      paintBounds: paintBounds,
      imageFilter: imageFilter,
      colorFilter: colorFilter,
      blendMode: blendMode,
    );

    _paintWithOrder(
      node,
      () {
        if (fillPaint != null) {
          canvas.drawPath(path, fillPaint);
        }
      },
      () {
        if (strokePaint != null) {
          final dashedPath = _buildDashedPath(path, node);
          canvas.drawPath(dashedPath, strokePaint);
        }
      },
      paintMarkers: () {
        // Paint markers at vertices
        _paintMarkers(
          canvas,
          node,
          path,
          imageFilter: imageFilter,
          colorFilter: colorFilter,
          blendMode: blendMode,
        );
      },
    );
  }

  void _paintPolyline(
    ui.Canvas canvas,
    SvgNode node, {
    ui.ImageFilter? imageFilter,
    ui.ColorFilter? colorFilter,
    ui.BlendMode? blendMode,
  }) {
    final points = _parsePoints(node);
    if (points.length < 2) return;

    final path = ui.Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }

    final paintBounds = path.getBounds();
    final fillPaint = _createFillPaint(
      node,
      paintBounds: paintBounds,
      imageFilter: imageFilter,
      colorFilter: colorFilter,
      blendMode: blendMode,
    );
    final strokePaint = _createStrokePaint(
      node,
      paintBounds: paintBounds,
      imageFilter: imageFilter,
      colorFilter: colorFilter,
      blendMode: blendMode,
    );

    _paintWithOrder(
      node,
      () {
        if (fillPaint != null) {
          canvas.drawPath(path, fillPaint);
        }
      },
      () {
        if (strokePaint != null) {
          final dashedPath = _buildDashedPath(path, node);
          canvas.drawPath(dashedPath, strokePaint);
        }
      },
      paintMarkers: () {
        // Paint markers at vertices
        _paintMarkers(
          canvas,
          node,
          path,
          imageFilter: imageFilter,
          colorFilter: colorFilter,
          blendMode: blendMode,
        );
      },
    );
  }
}
