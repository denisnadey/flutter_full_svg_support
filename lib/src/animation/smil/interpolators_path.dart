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

    // Per SVG spec (and Blink behavior): blending requires MATCHING segment
    // types and counts in the original paths. Blink's SVGPathBlender walks
    // both paths simultaneously, comparing segment types at each position.
    // If any segment type differs or counts don't match, it returns false
    // and the animation falls back to discrete interpolation.
    if (!_canBlendPaths(fromCommands, toCommands)) {
      // Blink distinguishes two failure modes:
      // 1. Different command COUNTS → adjustFromToListValues detects byte stream
      //    size mismatch → applies discrete fallback (from/to based on t).
      // 2. Same command count but different TYPES → adjustFromToListValues
      //    sees matching byte sizes → passes through to blender → blender fails
      //    → animated path is cleared → element becomes invisible.
      // We replicate both behaviors for Blink parity.
      if (fromCommands.length == toCommands.length) {
        // Case 2: counts match but types differ → empty path (invisible).
        return '';
      }
      // Case 1: different counts → discrete snap.
      return clampedT < 0.5 ? fromStr : toStr;
    }

    final normalizer = PathNormalizer();
    final norm1 = normalizer.normalizeSingle(fromCommands);
    final norm2 = normalizer.normalizeSingle(toCommands);

    // After normalization to cubics, verify counts still match.
    if (norm1.length != norm2.length) {
      return clampedT < 0.5 ? fromStr : toStr;
    }

    final normalizedPair = NormalizedPathPair(from: norm1, to: norm2);
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

/// Check whether two parsed path command lists can be smoothly blended.
///
/// Matches Blink's SVGPathBlender behavior: paths can only be blended if
/// they have the same number of segments AND the same segment type at each
/// position. Different types (L vs C, Q vs C, etc.) cause discrete fallback.
bool _canBlendPaths(List<PathCommand> from, List<PathCommand> to) {
  if (from.length != to.length) return false;
  for (int i = 0; i < from.length; i++) {
    if (from[i].runtimeType != to[i].runtimeType) return false;
  }
  return true;
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
      buffer.write('M${cmd.x.toStringAsFixed(4)},${cmd.y.toStringAsFixed(4)} ');
      continue;
    }
    if (cmd is CubicBezierCommand) {
      buffer.write(
        'C${cmd.x1.toStringAsFixed(4)},${cmd.y1.toStringAsFixed(4)} '
        '${cmd.x2.toStringAsFixed(4)},${cmd.y2.toStringAsFixed(4)} '
        '${cmd.x.toStringAsFixed(4)},${cmd.y.toStringAsFixed(4)} ',
      );
      continue;
    }
    if (cmd is ClosePathCommand) {
      buffer.write('Z ');
    }
  }

  return buffer.toString().trim();
}
