part of 'animated_svg_painter.dart';

extension AnimatedSvgPainterShapesImageExtension on AnimatedSvgPainter {
  void _paintImage(
    ui.Canvas canvas,
    SvgNode node, {
    ui.ImageFilter? imageFilter,
    ui.ColorFilter? colorFilter,
    ui.BlendMode? blendMode,
  }) {
    final href = _extractImageHref(node);
    if (href == null || href.isEmpty) {
      return;
    }

    final image = imagesByHref[href];
    if (image == null) {
      return;
    }

    final x = _getNumber(node, 'x') ?? 0.0;
    final y = _getNumber(node, 'y') ?? 0.0;
    final width = _getNumber(node, 'width') ?? image.width.toDouble();
    final height = _getNumber(node, 'height') ?? image.height.toDouble();
    if (width <= 0 || height <= 0) {
      return;
    }

    final viewport = ui.Rect.fromLTWH(x, y, width, height);
    final srcRect = ui.Rect.fromLTWH(
      0,
      0,
      image.width.toDouble(),
      image.height.toDouble(),
    );

    final layout = resolveSvgViewportLayout(
      viewport: viewport,
      sourceSize: srcRect.size,
      preserveAspectRatio: _getString(node, 'preserveAspectRatio'),
    );

    final paint = ui.Paint();
    final opacity = (_getNumber(node, 'opacity') ?? 1.0).clamp(0.0, 1.0);
    paint.color = const ui.Color(0xFFFFFFFF).withValues(alpha: opacity);

    if (imageFilter != null) {
      paint.imageFilter = imageFilter;
    }
    if (colorFilter != null) {
      paint.colorFilter = colorFilter;
    }
    if (blendMode != null) {
      paint.blendMode = blendMode;
    }

    if (layout.clipToViewport) {
      canvas.save();
      canvas.clipRect(viewport, doAntiAlias: true);
      canvas.drawImageRect(image, srcRect, layout.destinationRect, paint);
      canvas.restore();
      return;
    }

    canvas.drawImageRect(image, srcRect, layout.destinationRect, paint);
  }
}
