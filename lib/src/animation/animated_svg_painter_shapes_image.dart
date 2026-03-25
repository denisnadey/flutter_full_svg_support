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
    
    // Resolve width/height with percentage support
    final viewportSize = _getImageViewportSize(node);
    final width = _resolveImageLength(node, 'width', viewportSize.width) ?? 
                  image.width.toDouble();
    final height = _resolveImageLength(node, 'height', viewportSize.height) ?? 
                   image.height.toDouble();
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
    paint.filterQuality = _resolveImageRendering(node);

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
  
  /// Resolves an image dimension that may be a percentage value.
  /// Returns null if the attribute is missing or invalid.
  double? _resolveImageLength(SvgNode node, String attributeName, double viewportDimension) {
    final value = node.getAttributeValue(attributeName);
    if (value == null) return null;
    
    final str = value.toString().trim();
    if (str.isEmpty) return null;
    
    // Check for percentage value
    if (str.endsWith('%')) {
      final percentStr = str.substring(0, str.length - 1);
      final percent = double.tryParse(percentStr);
      if (percent == null) return null;
      return (percent / 100.0) * viewportDimension;
    }
    
    // Handle other units by stripping them and parsing the number
    final cleaned = str.replaceAll(RegExp(r'[a-zA-Z]+$'), '');
    return double.tryParse(cleaned);
  }
  
  /// Gets the viewport size for resolving percentage-based image dimensions.
  /// Returns the nearest SVG element's viewBox/viewport dimensions.
  ui.Size _getImageViewportSize(SvgNode node) {
    // Walk up to find nearest SVG viewport
    SvgNode? current = node.parent;
    while (current != null) {
      if (current.tagName == 'svg' || current.tagName == 'symbol') {
        // Try to get viewBox dimensions
        final viewBox = _parseViewBox(_getString(current, 'viewBox'));
        if (viewBox != null && viewBox.width > 0 && viewBox.height > 0) {
          return ui.Size(viewBox.width, viewBox.height);
        }
        // Try width/height attributes
        final svgWidth = _getNumber(current, 'width');
        final svgHeight = _getNumber(current, 'height');
        if (svgWidth != null && svgHeight != null && svgWidth > 0 && svgHeight > 0) {
          return ui.Size(svgWidth, svgHeight);
        }
      }
      // Check foreignObject viewport
      if (current.tagName == 'foreignObject') {
        final foWidth = _getNumber(current, 'width') ?? 0.0;
        final foHeight = _getNumber(current, 'height') ?? 0.0;
        if (foWidth > 0 && foHeight > 0) {
          return ui.Size(foWidth, foHeight);
        }
      }
      current = current.parent;
    }
    
    // Fall back to root document viewBox
    final rootViewBox = document.activeViewBox;
    if (rootViewBox != null && rootViewBox.width > 0 && rootViewBox.height > 0) {
      return ui.Size(rootViewBox.width, rootViewBox.height);
    }
    
    // Default to 100x100 if no viewport found
    return const ui.Size(100, 100);
  }
}
