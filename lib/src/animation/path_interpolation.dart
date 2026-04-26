/// Path interpolation for SVG path morphing.
///
/// Provides smooth interpolation between two normalized paths.
library;

import 'dart:ui' show Path, lerpDouble;
import 'path_data.dart';
part 'path_interpolation_helpers.dart';
part 'path_interpolation_morpher.dart';

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
