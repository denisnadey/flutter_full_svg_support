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
      default:
        return null;
    }
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
          if (rx == 0 || ry == 0) {
            path.lineTo(absoluteCommand.x, absoluteCommand.y);
          } else {
            path.arcToPoint(
              ui.Offset(absoluteCommand.x, absoluteCommand.y),
              radius: ui.Radius.elliptical(rx, ry),
              rotation: absoluteCommand.rotation,
              largeArc: absoluteCommand.largeArc,
              clockwise: absoluteCommand.sweep,
            );
          }
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
