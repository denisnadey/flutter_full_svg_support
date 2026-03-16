part of 'animated_svg_picture.dart';

extension _AnimatedSvgPictureStatePathParserExtension
    on _AnimatedSvgPictureState {
  void _applyPathFillType(Path path, SvgNode node) {
    final fillRule = node
        .getAttributeValue('fill-rule')
        ?.toString()
        .toLowerCase();
    path.fillType = fillRule == 'evenodd'
        ? PathFillType.evenOdd
        : PathFillType.nonZero;
  }

  Path? _buildPath(String pathData) {
    List<PathCommand> commands;
    try {
      commands = PathParser().parse(pathData);
    } catch (_) {
      return null;
    }

    if (commands.isEmpty) {
      return null;
    }

    final path = Path();
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
          if (absoluteCommand.rx <= 0 || absoluteCommand.ry <= 0) {
            path.lineTo(absoluteCommand.x, absoluteCommand.y);
          } else {
            path.arcToPoint(
              Offset(absoluteCommand.x, absoluteCommand.y),
              radius: Radius.elliptical(
                absoluteCommand.rx.abs(),
                absoluteCommand.ry.abs(),
              ),
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

  bool _pathStrokeContains(Path path, Offset point, double tolerance) {
    for (final metric in path.computeMetrics()) {
      final length = metric.length;
      if (length <= 0) {
        continue;
      }

      final stepCount = math.max(1, (length / 2.0).ceil());
      Offset? previous;
      for (int step = 0; step <= stepCount; step++) {
        final tangent = metric.getTangentForOffset(length * step / stepCount);
        if (tangent == null) {
          continue;
        }
        final current = tangent.position;
        if (previous != null &&
            _distanceToSegment(point, previous, current) <= tolerance) {
          return true;
        }
        previous = current;
      }
    }
    return false;
  }
}
