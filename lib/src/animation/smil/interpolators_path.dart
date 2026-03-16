part of 'interpolators.dart';

String _interpolatePathValue(Object from, Object to, double t) {
  final fromStr = from.toString();
  final toStr = to.toString();

  if (fromStr.isEmpty || toStr.isEmpty) {
    return t < 0.5 ? fromStr : toStr;
  }

  final clampedT = t.clamp(0.0, 1.0);

  try {
    final parser = PathParser();
    final fromCommands = parser.parse(fromStr);
    final toCommands = parser.parse(toStr);

    final normalizer = PathNormalizer();
    final normalizedPair = normalizer.normalize(fromCommands, toCommands);

    final interpolatedCommands = <PathCommand>[];
    for (int i = 0; i < normalizedPair.from.length; i++) {
      final cmdFrom = normalizedPair.from[i];
      final cmdTo = normalizedPair.to[i];
      interpolatedCommands.add(
        _interpolatePathCommand(cmdFrom, cmdTo, clampedT),
      );
    }
    return _pathCommandsToString(interpolatedCommands);
  } catch (_) {
    return clampedT < 0.5 ? fromStr : toStr;
  }
}

PathCommand _interpolatePathCommand(
  PathCommand from,
  PathCommand to,
  double t,
) {
  if (from is MoveToCommand && to is MoveToCommand) {
    return MoveToCommand(
      x: from.x + (to.x - from.x) * t,
      y: from.y + (to.y - from.y) * t,
    );
  }

  if (from is CubicBezierCommand && to is CubicBezierCommand) {
    return CubicBezierCommand(
      x1: from.x1 + (to.x1 - from.x1) * t,
      y1: from.y1 + (to.y1 - from.y1) * t,
      x2: from.x2 + (to.x2 - from.x2) * t,
      y2: from.y2 + (to.y2 - from.y2) * t,
      x: from.x + (to.x - from.x) * t,
      y: from.y + (to.y - from.y) * t,
    );
  }

  if (from is ClosePathCommand) {
    return const ClosePathCommand();
  }

  return from;
}

String _pathCommandsToString(List<PathCommand> commands) {
  final buffer = StringBuffer();

  for (final cmd in commands) {
    if (cmd is MoveToCommand) {
      buffer.write('M${cmd.x.toStringAsFixed(2)},${cmd.y.toStringAsFixed(2)} ');
      continue;
    }
    if (cmd is CubicBezierCommand) {
      buffer.write(
        'C${cmd.x1.toStringAsFixed(2)},${cmd.y1.toStringAsFixed(2)} '
        '${cmd.x2.toStringAsFixed(2)},${cmd.y2.toStringAsFixed(2)} '
        '${cmd.x.toStringAsFixed(2)},${cmd.y.toStringAsFixed(2)} ',
      );
      continue;
    }
    if (cmd is ClosePathCommand) {
      buffer.write('Z ');
    }
  }

  return buffer.toString().trim();
}
