part of 'animated_svg_painter.dart';

extension AnimatedSvgPainterGeometryExtension on AnimatedSvgPainter {
  ui.Path? _buildGeometryPath(SvgNode node) {
    switch (node.tagName) {
      case 'rect':
        final x = _getNumber(node, 'x') ?? 0.0;
        final y = _getNumber(node, 'y') ?? 0.0;
        final width = _getNumber(node, 'width') ?? 0.0;
        final height = _getNumber(node, 'height') ?? 0.0;

        // SVG spec: rx/ry handling
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

        // Negative rx/ry is an error
        if (rx < 0 || ry < 0) return null;

        // Clamp rx/ry to half of width/height
        rx = rx.clamp(0.0, width / 2);
        ry = ry.clamp(0.0, height / 2);

        if (width <= 0 || height <= 0) return null;
        final rect = ui.Rect.fromLTWH(x, y, width, height);
        if (rx > 0 || ry > 0) {
          return ui.Path()..addRRect(ui.RRect.fromRectXY(rect, rx, ry));
        }
        return ui.Path()..addRect(rect);
      case 'circle':
        final cx = _getNumber(node, 'cx') ?? 0.0;
        final cy = _getNumber(node, 'cy') ?? 0.0;
        final r = _getNumber(node, 'r') ?? 0.0;
        if (r <= 0) return null;
        return ui.Path()
          ..addOval(ui.Rect.fromCircle(center: ui.Offset(cx, cy), radius: r));
      case 'ellipse':
        final cx = _getNumber(node, 'cx') ?? 0.0;
        final cy = _getNumber(node, 'cy') ?? 0.0;
        final rx = _getNumber(node, 'rx') ?? 0.0;
        final ry = _getNumber(node, 'ry') ?? 0.0;
        if (rx <= 0 || ry <= 0) return null;
        return ui.Path()..addOval(
          ui.Rect.fromCenter(
            center: ui.Offset(cx, cy),
            width: rx * 2,
            height: ry * 2,
          ),
        );
      case 'line':
        final x1 = _getNumber(node, 'x1') ?? 0.0;
        final y1 = _getNumber(node, 'y1') ?? 0.0;
        final x2 = _getNumber(node, 'x2') ?? 0.0;
        final y2 = _getNumber(node, 'y2') ?? 0.0;
        return ui.Path()
          ..moveTo(x1, y1)
          ..lineTo(x2, y2);
      case 'polygon':
        final polygon = _parsePoints(node);
        if (polygon.length < 3) return null;
        final polygonPath = ui.Path()
          ..moveTo(polygon.first.dx, polygon.first.dy);
        for (int i = 1; i < polygon.length; i++) {
          polygonPath.lineTo(polygon[i].dx, polygon[i].dy);
        }
        polygonPath.close();
        _applyPathFillType(polygonPath, node);
        return polygonPath;
      case 'polyline':
        final polyline = _parsePoints(node);
        if (polyline.length < 2) return null;
        final polylinePath = ui.Path()
          ..moveTo(polyline.first.dx, polyline.first.dy);
        for (int i = 1; i < polyline.length; i++) {
          polylinePath.lineTo(polyline[i].dx, polyline[i].dy);
        }
        _applyPathFillType(polylinePath, node);
        return polylinePath;
      case 'path':
        final pathData = _getString(node, 'd');
        if (pathData == null || pathData.isEmpty) return null;
        final parsed = _buildPath(pathData);
        if (parsed == null) return null;
        _applyPathFillType(parsed, node);
        return parsed;
      case 'image':
        // Image geometry is a rectangle defined by x, y, width, height.
        // Per SVG spec, image in clipPath contributes its bounding rectangle.
        // The alpha channel of the image content defines the clip region,
        // but for geometry-based clipping, we use the image bounds.
        final imgX = _getNumber(node, 'x') ?? 0.0;
        final imgY = _getNumber(node, 'y') ?? 0.0;
        // For clip/mask geometry, we need dimensions. If not specified,
        // we cannot determine the image bounds, so return null.
        final imgWidth = _getNumber(node, 'width');
        final imgHeight = _getNumber(node, 'height');
        // If width/height are not specified, try to get from loaded image
        final href = _extractImageHref(node);
        final actualWidth =
            imgWidth ??
            (href != null ? imagesByHref[href]?.width.toDouble() : null);
        final actualHeight =
            imgHeight ??
            (href != null ? imagesByHref[href]?.height.toDouble() : null);
        if (actualWidth == null ||
            actualHeight == null ||
            actualWidth <= 0 ||
            actualHeight <= 0) {
          return null;
        }
        return ui.Path()
          ..addRect(ui.Rect.fromLTWH(imgX, imgY, actualWidth, actualHeight));
      case 'foreignObject':
        // ForeignObject geometry is its viewport rectangle.
        // Used for clip/mask region calculation.
        final foX = _getNumber(node, 'x') ?? 0.0;
        final foY = _getNumber(node, 'y') ?? 0.0;
        final foWidth = _getNumber(node, 'width') ?? 0.0;
        final foHeight = _getNumber(node, 'height') ?? 0.0;
        if (foWidth <= 0 || foHeight <= 0) {
          return null;
        }
        return ui.Path()
          ..addRect(ui.Rect.fromLTWH(foX, foY, foWidth, foHeight));
      default:
        return null;
    }
  }
}
