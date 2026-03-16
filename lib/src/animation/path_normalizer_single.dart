part of 'path_normalizer.dart';

List<PathCommand> _normalizeSingle(List<PathCommand> commands) {
  if (commands.isEmpty) return [];

  final normalized = <PathCommand>[];
  double currentX = 0;
  double currentY = 0;
  double subpathStartX = 0;
  double subpathStartY = 0;
  PathCommand? previousCommand;

  for (final cmd in commands) {
    // Convert to absolute first.
    final absoluteCmd = cmd.toAbsolute(currentX, currentY);

    if (absoluteCmd is MoveToCommand) {
      normalized.add(absoluteCmd);
      currentX = absoluteCmd.x;
      currentY = absoluteCmd.y;
      subpathStartX = currentX;
      subpathStartY = currentY;
    } else if (absoluteCmd is LineToCommand) {
      // Convert LineTo to CubicBezier (straight line).
      normalized.add(_lineToCubic(currentX, currentY, absoluteCmd));
      currentX = absoluteCmd.x;
      currentY = absoluteCmd.y;
    } else if (absoluteCmd is HorizontalLineToCommand) {
      // Convert H to L, then to C.
      final lineTo = absoluteCmd.toLineTo(currentY);
      final absLine = lineTo.toAbsolute(currentX, currentY) as LineToCommand;
      normalized.add(_lineToCubic(currentX, currentY, absLine));
      currentX = absLine.x;
      currentY = absLine.y;
    } else if (absoluteCmd is VerticalLineToCommand) {
      // Convert V to L, then to C.
      final lineTo = absoluteCmd.toLineTo(currentX);
      final absLine = lineTo.toAbsolute(currentX, currentY) as LineToCommand;
      normalized.add(_lineToCubic(currentX, currentY, absLine));
      currentX = absLine.x;
      currentY = absLine.y;
    } else if (absoluteCmd is CubicBezierCommand) {
      normalized.add(absoluteCmd);
      currentX = absoluteCmd.x;
      currentY = absoluteCmd.y;
    } else if (absoluteCmd is SmoothCubicBezierCommand) {
      final cubic = absoluteCmd.toCubicBezier(
        currentX: currentX,
        currentY: currentY,
        previousCommand: previousCommand,
      );
      final absCubic =
          cubic.toAbsolute(currentX, currentY) as CubicBezierCommand;
      normalized.add(absCubic);
      currentX = absCubic.x;
      currentY = absCubic.y;
    } else if (absoluteCmd is QuadraticBezierCommand) {
      final cubic = absoluteCmd.toCubicBezier(currentX, currentY);
      final absCubic =
          cubic.toAbsolute(currentX, currentY) as CubicBezierCommand;
      normalized.add(absCubic);
      currentX = absCubic.x;
      currentY = absCubic.y;
    } else if (absoluteCmd is SmoothQuadraticBezierCommand) {
      final quad = absoluteCmd.toQuadraticBezier(
        currentX: currentX,
        currentY: currentY,
        previousCommand: previousCommand,
      );
      final absQuad =
          quad.toAbsolute(currentX, currentY) as QuadraticBezierCommand;
      final cubic = absQuad.toCubicBezier(currentX, currentY);
      final absCubic =
          cubic.toAbsolute(currentX, currentY) as CubicBezierCommand;
      normalized.add(absCubic);
      currentX = absCubic.x;
      currentY = absCubic.y;
    } else if (absoluteCmd is ArcCommand) {
      // Convert arc to cubic bezier approximation.
      final cubics = _arcToCubics(currentX, currentY, absoluteCmd);
      normalized.addAll(cubics);
      if (cubics.isNotEmpty) {
        final last = cubics.last;
        currentX = last.x;
        currentY = last.y;
      }
    } else if (absoluteCmd is ClosePathCommand) {
      // Add line from current point to subpath start, then close.
      if (currentX != subpathStartX || currentY != subpathStartY) {
        normalized.add(
          _lineToCubic(
            currentX,
            currentY,
            LineToCommand(x: subpathStartX, y: subpathStartY),
          ),
        );
      }
      normalized.add(const ClosePathCommand());
      currentX = subpathStartX;
      currentY = subpathStartY;
    }

    previousCommand = absoluteCmd;
  }

  return normalized;
}
