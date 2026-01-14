/// Path interpolation for SVG path morphing.
///
/// Provides smooth interpolation between two normalized paths.
library;

import 'dart:ui' show Path, lerpDouble;
import 'path_data.dart';

/// Interpolates between two normalized SVG paths.
///
/// Both paths must be normalized (same number of commands, same types).
/// Use [PathNormalizer] to prepare paths before interpolation.
class PathInterpolator {
  const PathInterpolator();

  /// Interpolate between two normalized path command lists.
  ///
  /// [from] and [to] must have the same length and matching command types.
  /// [t] is the interpolation factor (0.0 = from, 1.0 = to).
  ///
  /// Returns a new Path object representing the interpolated path.
  ///
  /// Throws [ArgumentError] if paths are incompatible.
  Path interpolate(List<PathCommand> from, List<PathCommand> to, double t) {
    if (from.length != to.length) {
      throw ArgumentError(
        'Paths must have the same length. from: ${from.length}, to: ${to.length}',
      );
    }

    // Clamp t to [0, 1]
    final clampedT = t.clamp(0.0, 1.0);

    final path = Path();

    for (int i = 0; i < from.length; i++) {
      final cmdFrom = from[i];
      final cmdTo = to[i];

      if (cmdFrom.runtimeType != cmdTo.runtimeType) {
        throw ArgumentError(
          'Command types must match at index $i. '
          'from: ${cmdFrom.runtimeType}, to: ${cmdTo.runtimeType}',
        );
      }

      if (cmdFrom is MoveToCommand && cmdTo is MoveToCommand) {
        _interpolateMoveTo(path, cmdFrom, cmdTo, clampedT);
      } else if (cmdFrom is CubicBezierCommand && cmdTo is CubicBezierCommand) {
        _interpolateCubicBezier(path, cmdFrom, cmdTo, clampedT);
      } else if (cmdFrom is ClosePathCommand) {
        path.close();
      } else {
        // Unexpected command type after normalization
        throw ArgumentError(
          'Unexpected command type: ${cmdFrom.runtimeType}. '
          'Paths must be normalized before interpolation.',
        );
      }
    }

    return path;
  }

  /// Interpolate a MoveTo command.
  void _interpolateMoveTo(
    Path path,
    MoveToCommand from,
    MoveToCommand to,
    double t,
  ) {
    final x = lerpDouble(from.x, to.x, t)!;
    final y = lerpDouble(from.y, to.y, t)!;
    path.moveTo(x, y);
  }

  /// Interpolate a CubicBezier command.
  void _interpolateCubicBezier(
    Path path,
    CubicBezierCommand from,
    CubicBezierCommand to,
    double t,
  ) {
    final x1 = lerpDouble(from.x1, to.x1, t)!;
    final y1 = lerpDouble(from.y1, to.y1, t)!;
    final x2 = lerpDouble(from.x2, to.x2, t)!;
    final y2 = lerpDouble(from.y2, to.y2, t)!;
    final x = lerpDouble(from.x, to.x, t)!;
    final y = lerpDouble(from.y, to.y, t)!;

    path.cubicTo(x1, y1, x2, y2, x, y);
  }

  /// Interpolate between two path data strings.
  ///
  /// This is a convenience method that handles parsing and normalization.
  /// For better performance with repeated interpolation, parse and normalize
  /// paths once, then use [interpolate] directly.
  ///
  /// Requires [PathParser] and [PathNormalizer] to be available.
  Path interpolateStrings(
    String fromPathData,
    String toPathData,
    double t, {
    required dynamic parser,
    required dynamic normalizer,
  }) {
    final fromCommands = parser.parse(fromPathData) as List<PathCommand>;
    final toCommands = parser.parse(toPathData) as List<PathCommand>;

    final normalized = normalizer.normalize(fromCommands, toCommands);

    if (!normalized.isValid) {
      throw ArgumentError(
        'Failed to normalize paths for interpolation. '
        'Paths may have incompatible structures.',
      );
    }

    return interpolate(normalized.from, normalized.to, t);
  }
}

/// Helper class to manage path morphing animations.
///
/// Caches normalized paths for efficient repeated interpolation.
class PathMorpher {
  PathMorpher({
    required List<PathCommand> fromCommands,
    required List<PathCommand> toCommands,
  }) : _fromCommands = fromCommands,
       _toCommands = toCommands {
    if (fromCommands.length != toCommands.length) {
      throw ArgumentError(
        'Paths must have the same length. '
        'Use PathNormalizer.normalize() first.',
      );
    }
  }

  final List<PathCommand> _fromCommands;
  final List<PathCommand> _toCommands;
  final PathInterpolator _interpolator = const PathInterpolator();

  /// Get the interpolated path at time t (0.0 to 1.0).
  Path getPathAt(double t) {
    return _interpolator.interpolate(_fromCommands, _toCommands, t);
  }

  /// Get the from path (t = 0.0).
  Path get fromPath => getPathAt(0.0);

  /// Get the to path (t = 1.0).
  Path get toPath => getPathAt(1.0);

  /// Get a path at a specific percentage (0 to 100).
  Path getPathAtPercent(double percent) {
    return getPathAt(percent / 100.0);
  }
}

/// Extension methods for easier path interpolation.
extension PathCommandListInterpolation on List<PathCommand> {
  /// Interpolate this path to another path.
  Path interpolateTo(List<PathCommand> other, double t) {
    return const PathInterpolator().interpolate(this, other, t);
  }

  /// Create a PathMorpher for animating between this path and another.
  PathMorpher morphTo(List<PathCommand> other) {
    return PathMorpher(fromCommands: this, toCommands: other);
  }
}
