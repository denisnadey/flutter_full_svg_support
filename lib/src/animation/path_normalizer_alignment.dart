part of 'path_normalizer.dart';

/// Align two paths to have the same number of commands.
///
/// Uses de Casteljau subdivision to split the longest cubic segments in the
/// shorter path, distributing extra commands evenly along the path.
/// This matches browser (Blink) behavior and avoids degenerate zero-length
/// curves that cause visible "bunching" during morphing.
NormalizedPathPair _alignPaths(
  List<PathCommand> path1,
  List<PathCommand> path2,
) {
  final isPath1Longer = path1.length > path2.length;
  final longer = isPath1Longer ? path1 : path2;
  final shorter = isPath1Longer ? path2 : path1;
  final difference = longer.length - shorter.length;

  if (difference == 0) {
    return NormalizedPathPair(
      from: isPath1Longer ? path1 : path2,
      to: isPath1Longer ? path2 : path1,
    );
  }

  // Subdivide the longest cubic segments in the shorter path.
  final padded = List<PathCommand>.from(shorter);
  int remaining = difference;

  while (remaining > 0) {
    // Find the longest cubic segment to subdivide.
    int bestIndex = -1;
    double bestLength = -1;
    double cx = 0, cy = 0; // track current position

    for (int i = 0; i < padded.length; i++) {
      final cmd = padded[i];
      if (cmd is MoveToCommand) {
        cx = cmd.x;
        cy = cmd.y;
      } else if (cmd is CubicBezierCommand) {
        // Approximate length using chord + control polygon.
        final chordLen = _dist(cx, cy, cmd.x, cmd.y);
        final polyLen = _dist(cx, cy, cmd.x1, cmd.y1) +
            _dist(cmd.x1, cmd.y1, cmd.x2, cmd.y2) +
            _dist(cmd.x2, cmd.y2, cmd.x, cmd.y);
        final approxLen = (chordLen + polyLen) / 2;
        if (approxLen > bestLength) {
          bestLength = approxLen;
          bestIndex = i;
        }
        cx = cmd.x;
        cy = cmd.y;
      }
    }

    if (bestIndex < 0) {
      // No cubics to subdivide — fall back to degenerate insertion.
      _insertDegenerateCurves(padded, remaining);
      break;
    }

    // Get the start point of the cubic at bestIndex.
    double startX = 0, startY = 0;
    for (int i = bestIndex - 1; i >= 0; i--) {
      final prev = padded[i];
      if (prev is MoveToCommand) {
        startX = prev.x;
        startY = prev.y;
        break;
      } else if (prev is CubicBezierCommand) {
        startX = prev.x;
        startY = prev.y;
        break;
      }
    }

    final cubic = padded[bestIndex] as CubicBezierCommand;
    final halves = _subdivideCubic(startX, startY, cubic, 0.5);

    // Replace one cubic with two halves.
    padded.removeAt(bestIndex);
    padded.insert(bestIndex, halves.$2);
    padded.insert(bestIndex, halves.$1);
    remaining--;
  }

  return NormalizedPathPair(
    from: isPath1Longer ? longer : padded,
    to: isPath1Longer ? padded : longer,
  );
}

/// Euclidean distance between two points.
double _dist(double x1, double y1, double x2, double y2) {
  final dx = x2 - x1;
  final dy = y2 - y1;
  return math.sqrt(dx * dx + dy * dy);
}

/// Subdivide a cubic Bezier at parameter [t] using de Casteljau's algorithm.
/// Returns two cubic Bezier commands: (first half, second half).
(CubicBezierCommand, CubicBezierCommand) _subdivideCubic(
  double startX,
  double startY,
  CubicBezierCommand c,
  double t,
) {
  // P0 = (startX, startY), P1 = (c.x1, c.y1),
  // P2 = (c.x2, c.y2), P3 = (c.x, c.y)
  final p0x = startX, p0y = startY;
  final p1x = c.x1, p1y = c.y1;
  final p2x = c.x2, p2y = c.y2;
  final p3x = c.x, p3y = c.y;

  // Level 1
  final p01x = p0x + (p1x - p0x) * t, p01y = p0y + (p1y - p0y) * t;
  final p12x = p1x + (p2x - p1x) * t, p12y = p1y + (p2y - p1y) * t;
  final p23x = p2x + (p3x - p2x) * t, p23y = p2y + (p3y - p2y) * t;

  // Level 2
  final p012x = p01x + (p12x - p01x) * t, p012y = p01y + (p12y - p01y) * t;
  final p123x = p12x + (p23x - p12x) * t, p123y = p12y + (p23y - p12y) * t;

  // Level 3 — the split point
  final px = p012x + (p123x - p012x) * t;
  final py = p012y + (p123y - p012y) * t;

  return (
    CubicBezierCommand(
      x1: p01x, y1: p01y,
      x2: p012x, y2: p012y,
      x: px, y: py,
      isRelative: false,
    ),
    CubicBezierCommand(
      x1: p123x, y1: p123y,
      x2: p23x, y2: p23y,
      x: p3x, y: p3y,
      isRelative: false,
    ),
  );
}

/// Fallback: insert degenerate zero-length curves when no cubics are available.
void _insertDegenerateCurves(List<PathCommand> path, int count) {
  // Find insertion point (after last non-close command).
  int insertIndex = 1;
  for (int i = 0; i < path.length; i++) {
    if (path[i] is! ClosePathCommand) {
      insertIndex = i + 1;
    } else {
      break;
    }
  }

  double x = 0, y = 0;
  if (insertIndex > 0 && insertIndex <= path.length) {
    final prevCmd = path[insertIndex - 1];
    if (prevCmd is MoveToCommand) {
      x = prevCmd.x;
      y = prevCmd.y;
    } else if (prevCmd is CubicBezierCommand) {
      x = prevCmd.x;
      y = prevCmd.y;
    }
  }

  for (int i = 0; i < count; i++) {
    path.insert(
      insertIndex,
      CubicBezierCommand(
        x1: x, y1: y, x2: x, y2: y, x: x, y: y, isRelative: false,
      ),
    );
  }
}
