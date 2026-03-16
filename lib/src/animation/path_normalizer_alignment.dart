part of 'path_normalizer.dart';

/// Align two paths to have the same number of commands by subdividing.
NormalizedPathPair _alignPaths(
  List<PathCommand> path1,
  List<PathCommand> path2,
) {
  // Simple strategy: pad the shorter path with degenerate (zero-length) curves.
  final longer = path1.length > path2.length ? path1 : path2;
  final shorter = path1.length > path2.length ? path2 : path1;
  final difference = longer.length - shorter.length;

  if (difference == 0) {
    return NormalizedPathPair(
      from: path1.length > path2.length ? path1 : path2,
      to: path1.length > path2.length ? path2 : path1,
    );
  }

  // Create padded version of shorter path.
  final padded = List<PathCommand>.from(shorter);

  // Find a good place to insert padding (after MoveTo, before ClosePath).
  int insertIndex = 1; // After first MoveTo.
  for (int i = 0; i < shorter.length; i++) {
    if (shorter[i] is! ClosePathCommand) {
      insertIndex = i + 1;
    } else {
      break;
    }
  }

  // Get position for degenerate curves.
  double x = 0;
  double y = 0;
  if (insertIndex > 0 && insertIndex <= shorter.length) {
    final prevCmd = shorter[insertIndex - 1];
    if (prevCmd is MoveToCommand) {
      x = prevCmd.x;
      y = prevCmd.y;
    } else if (prevCmd is CubicBezierCommand) {
      x = prevCmd.x;
      y = prevCmd.y;
    }
  }

  // Insert degenerate curves (point to itself).
  for (int i = 0; i < difference; i++) {
    padded.insert(
      insertIndex,
      CubicBezierCommand(
        x1: x,
        y1: y,
        x2: x,
        y2: y,
        x: x,
        y: y,
        isRelative: false,
      ),
    );
  }

  return NormalizedPathPair(
    from: path1.length > path2.length ? longer : padded,
    to: path1.length > path2.length ? padded : longer,
  );
}
