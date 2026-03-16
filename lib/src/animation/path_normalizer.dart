/// Path normalization for SVG path morphing and interpolation.
///
/// Normalizes paths to make them compatible for smooth interpolation:
/// - Converts all commands to absolute coordinates
/// - Converts all curves to cubic bezier
/// - Ensures both paths have the same number of commands
library;

import 'dart:math' as math;
import 'path_data.dart';
part 'path_normalizer_alignment.dart';
part 'path_normalizer_curves.dart';
part 'path_normalizer_single.dart';
part 'path_normalizer_types.dart';

/// Normalizes SVG paths for morphing/interpolation.
///
/// Takes two paths and transforms them so they:
/// 1. Have all absolute coordinates
/// 2. Have the same number of commands
/// 3. Use only MoveTo, CubicBezier, and ClosePath commands
class PathNormalizer {
  PathNormalizer();

  /// Normalize a single path to absolute coordinates and cubic beziers.
  ///
  /// Returns a list of PathCommands using only:
  /// - MoveToCommand (absolute)
  /// - CubicBezierCommand (absolute)
  /// - ClosePathCommand
  List<PathCommand> normalizeSingle(List<PathCommand> commands) {
    return _normalizeSingle(commands);
  }

  /// Normalize two paths to be compatible for interpolation.
  ///
  /// Returns a [NormalizedPathPair] containing both paths with:
  /// - Same number of commands
  /// - Same command types at each index
  /// - All absolute coordinates
  NormalizedPathPair normalize(
    List<PathCommand> path1,
    List<PathCommand> path2,
  ) {
    final norm1 = normalizeSingle(path1);
    final norm2 = normalizeSingle(path2);

    // If paths have different command counts, we need to align them
    if (norm1.length != norm2.length) {
      return _alignPaths(norm1, norm2);
    }

    return NormalizedPathPair(from: norm1, to: norm2);
  }
}
