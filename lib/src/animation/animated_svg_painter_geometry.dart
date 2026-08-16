part of 'animated_svg_painter.dart';

extension AnimatedSvgPainterGeometryExtension on AnimatedSvgPainter {
  ui.Path? _buildGeometryPath(SvgNode node) {
    switch (node.tagName) {
      case 'rect':
        final x =
            resolveSvgLength(
              node,
              document,
              'x',
              reference: SvgLengthReference.horizontal,
            ) ??
            0.0;
        final y =
            resolveSvgLength(
              node,
              document,
              'y',
              reference: SvgLengthReference.vertical,
            ) ??
            0.0;
        final width =
            resolveSvgLength(
              node,
              document,
              'width',
              reference: SvgLengthReference.horizontal,
            ) ??
            0.0;
        final height =
            resolveSvgLength(
              node,
              document,
              'height',
              reference: SvgLengthReference.vertical,
            ) ??
            0.0;

        // SVG spec: rx/ry handling
        final rxRaw = resolveSvgLength(
          node,
          document,
          'rx',
          reference: SvgLengthReference.horizontal,
        );
        final ryRaw = resolveSvgLength(
          node,
          document,
          'ry',
          reference: SvgLengthReference.vertical,
        );

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
        final cx =
            resolveSvgLength(
              node,
              document,
              'cx',
              reference: SvgLengthReference.horizontal,
            ) ??
            0.0;
        final cy =
            resolveSvgLength(
              node,
              document,
              'cy',
              reference: SvgLengthReference.vertical,
            ) ??
            0.0;
        final r =
            resolveSvgLength(
              node,
              document,
              'r',
              reference: SvgLengthReference.normalizedDiagonal,
            ) ??
            0.0;
        if (r <= 0) return null;
        return ui.Path()
          ..addOval(ui.Rect.fromCircle(center: ui.Offset(cx, cy), radius: r));
      case 'ellipse':
        final cx =
            resolveSvgLength(
              node,
              document,
              'cx',
              reference: SvgLengthReference.horizontal,
            ) ??
            0.0;
        final cy =
            resolveSvgLength(
              node,
              document,
              'cy',
              reference: SvgLengthReference.vertical,
            ) ??
            0.0;
        final rx =
            resolveSvgLength(
              node,
              document,
              'rx',
              reference: SvgLengthReference.horizontal,
            ) ??
            0.0;
        final ry =
            resolveSvgLength(
              node,
              document,
              'ry',
              reference: SvgLengthReference.vertical,
            ) ??
            0.0;
        if (rx <= 0 || ry <= 0) return null;
        return ui.Path()..addOval(
          ui.Rect.fromCenter(
            center: ui.Offset(cx, cy),
            width: rx * 2,
            height: ry * 2,
          ),
        );
      case 'line':
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
        final imgX =
            resolveSvgLength(
              node,
              document,
              'x',
              reference: SvgLengthReference.horizontal,
            ) ??
            0.0;
        final imgY =
            resolveSvgLength(
              node,
              document,
              'y',
              reference: SvgLengthReference.vertical,
            ) ??
            0.0;
        // For clip/mask geometry, we need dimensions. If not specified,
        // we cannot determine the image bounds, so return null.
        final imgWidth = resolveSvgLength(
          node,
          document,
          'width',
          reference: SvgLengthReference.horizontal,
        );
        final imgHeight = resolveSvgLength(
          node,
          document,
          'height',
          reference: SvgLengthReference.vertical,
        );
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
        final foX =
            resolveSvgLength(
              node,
              document,
              'x',
              reference: SvgLengthReference.horizontal,
            ) ??
            0.0;
        final foY =
            resolveSvgLength(
              node,
              document,
              'y',
              reference: SvgLengthReference.vertical,
            ) ??
            0.0;
        final foWidth =
            resolveSvgLength(
              node,
              document,
              'width',
              reference: SvgLengthReference.horizontal,
            ) ??
            0.0;
        final foHeight =
            resolveSvgLength(
              node,
              document,
              'height',
              reference: SvgLengthReference.vertical,
            ) ??
            0.0;
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
