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

  /// Builds a path for a nested SVG element within foreignObject context.
  /// The SVG establishes its own coordinate system which may differ from
  /// the foreignObject's viewport.
  ui.Path? _buildNestedSvgPath(SvgNode svgNode, SvgNode foreignObjectParent) {
    // Get foreignObject dimensions
    final foWidth = _getNumber(foreignObjectParent, 'width') ?? 0.0;
    final foHeight = _getNumber(foreignObjectParent, 'height') ?? 0.0;
    if (foWidth <= 0 || foHeight <= 0) {
      return null;
    }

    // Get SVG element positioning
    final svgX = _getNumber(svgNode, 'x') ?? 0.0;
    final svgY = _getNumber(svgNode, 'y') ?? 0.0;
    final svgWidth = _getNumber(svgNode, 'width') ?? foWidth;
    final svgHeight = _getNumber(svgNode, 'height') ?? foHeight;

    if (svgWidth <= 0 || svgHeight <= 0) {
      return null;
    }

    // The geometry is the SVG element's bounds within the foreignObject
    return ui.Path()
      ..addRect(ui.Rect.fromLTWH(svgX, svgY, svgWidth, svgHeight));
  }

  /// Resolves the coordinate transform for content within a foreignObject.
  /// ForeignObject establishes a new stacking context with transform reset.
  Matrix4 _resolveForeignObjectContentTransform(SvgNode foreignObjectNode) {
    final x = _getNumber(foreignObjectNode, 'x') ?? 0.0;
    final y = _getNumber(foreignObjectNode, 'y') ?? 0.0;

    // ForeignObject translates content to (x, y) position
    // Transform is reset - foreignObject content starts fresh
    return Matrix4.identity()..translateByDouble(x, y, 0, 1);
  }

  void _applyPathFillType(ui.Path path, SvgNode node) {
    // clip-rule and fill-rule are inheritable properties
    final fillRule =
        _getInheritedString(node, 'clip-rule')?.toLowerCase() ??
        _getInheritedString(node, 'fill-rule')?.toLowerCase();
    path.fillType = fillRule == 'evenodd'
        ? ui.PathFillType.evenOdd
        : ui.PathFillType.nonZero;
  }

  ui.Path? _buildPath(String pathData) {
    List<PathCommand> commands;
    try {
      commands = PathParser().parse(pathData);
    } catch (_) {
      return null;
    }

    if (commands.isEmpty) {
      return null;
    }

    final path = ui.Path();
    double currentX = 0.0;
    double currentY = 0.0;
    double subPathStartX = 0.0;
    double subPathStartY = 0.0;
    PathCommand? previousCommand;

    for (final command in commands) {
      final absoluteCommand = command.toAbsolute(currentX, currentY);

      switch (absoluteCommand) {
        case MoveToCommand():
          path.moveTo(absoluteCommand.x, absoluteCommand.y);
          currentX = absoluteCommand.x;
          currentY = absoluteCommand.y;
          subPathStartX = currentX;
          subPathStartY = currentY;
          previousCommand = absoluteCommand;

        case LineToCommand():
          path.lineTo(absoluteCommand.x, absoluteCommand.y);
          currentX = absoluteCommand.x;
          currentY = absoluteCommand.y;
          previousCommand = absoluteCommand;

        case HorizontalLineToCommand():
          path.lineTo(absoluteCommand.x, currentY);
          currentX = absoluteCommand.x;
          previousCommand = LineToCommand(x: currentX, y: currentY);

        case VerticalLineToCommand():
          path.lineTo(currentX, absoluteCommand.y);
          currentY = absoluteCommand.y;
          previousCommand = LineToCommand(x: currentX, y: currentY);

        case CubicBezierCommand():
          path.cubicTo(
            absoluteCommand.x1,
            absoluteCommand.y1,
            absoluteCommand.x2,
            absoluteCommand.y2,
            absoluteCommand.x,
            absoluteCommand.y,
          );
          currentX = absoluteCommand.x;
          currentY = absoluteCommand.y;
          previousCommand = absoluteCommand;

        case SmoothCubicBezierCommand():
          final cubic = absoluteCommand.toCubicBezier(
            currentX: currentX,
            currentY: currentY,
            previousCommand: previousCommand,
          );
          path.cubicTo(
            cubic.x1,
            cubic.y1,
            cubic.x2,
            cubic.y2,
            cubic.x,
            cubic.y,
          );
          currentX = cubic.x;
          currentY = cubic.y;
          previousCommand = cubic;

        case QuadraticBezierCommand():
          path.quadraticBezierTo(
            absoluteCommand.x1,
            absoluteCommand.y1,
            absoluteCommand.x,
            absoluteCommand.y,
          );
          currentX = absoluteCommand.x;
          currentY = absoluteCommand.y;
          previousCommand = absoluteCommand;

        case SmoothQuadraticBezierCommand():
          final quadratic = absoluteCommand.toQuadraticBezier(
            currentX: currentX,
            currentY: currentY,
            previousCommand: previousCommand,
          );
          path.quadraticBezierTo(
            quadratic.x1,
            quadratic.y1,
            quadratic.x,
            quadratic.y,
          );
          currentX = quadratic.x;
          currentY = quadratic.y;
          previousCommand = quadratic;

        case ArcCommand():
          // SVG spec: If rx or ry is 0, treat as straight line
          // If rx or ry is negative, use absolute value
          final rx = absoluteCommand.rx.abs();
          final ry = absoluteCommand.ry.abs();

          // Edge case: Zero radii - treat as lineTo
          if (rx == 0 || ry == 0) {
            path.lineTo(absoluteCommand.x, absoluteCommand.y);
            currentX = absoluteCommand.x;
            currentY = absoluteCommand.y;
            previousCommand = absoluteCommand;
            break;
          }

          // Edge case: Very small arc (endpoints very close)
          // When endpoints are within a tiny epsilon, just lineTo to avoid
          // numerical instability in arc computation
          final dx = absoluteCommand.x - currentX;
          final dy = absoluteCommand.y - currentY;
          final endpointDistance = (dx * dx + dy * dy);
          const epsilon = 1e-10;
          if (endpointDistance < epsilon) {
            // Endpoints are essentially the same - no arc needed
            currentX = absoluteCommand.x;
            currentY = absoluteCommand.y;
            previousCommand = absoluteCommand;
            break;
          }

          // Edge case: Arc radius too small to reach endpoint
          // Per SVG spec, radii are scaled up uniformly to the minimum required
          // to reach the endpoint. This is handled by Flutter's arcToPoint.

          // Edge case: Very large radii relative to endpoint distance
          // This can cause numerical issues - the arc degenerates into almost
          // a straight line or full ellipse. Flutter handles this correctly
          // but we add a check for extreme cases.
          final halfChord = endpointDistance / 4;
          final minRadius = rx < ry ? rx : ry;
          if (minRadius * minRadius < halfChord * epsilon) {
            // Radius is too small relative to distance - lineTo is safer
            path.lineTo(absoluteCommand.x, absoluteCommand.y);
            currentX = absoluteCommand.x;
            currentY = absoluteCommand.y;
            previousCommand = absoluteCommand;
            break;
          }

          path.arcToPoint(
            ui.Offset(absoluteCommand.x, absoluteCommand.y),
            radius: ui.Radius.elliptical(rx, ry),
            rotation: absoluteCommand.rotation,
            largeArc: absoluteCommand.largeArc,
            clockwise: absoluteCommand.sweep,
          );
          currentX = absoluteCommand.x;
          currentY = absoluteCommand.y;
          previousCommand = absoluteCommand;

        case ClosePathCommand():
          path.close();
          currentX = subPathStartX;
          currentY = subPathStartY;
          previousCommand = absoluteCommand;
      }
    }

    return path;
  }
}
