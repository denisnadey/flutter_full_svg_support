part of 'animated_svg_painter.dart';

/// Extension for path building and fill type handling.
extension AnimatedSvgPainterGeometryPathExtension on AnimatedSvgPainter {
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
