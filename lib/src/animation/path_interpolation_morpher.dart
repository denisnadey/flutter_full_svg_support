part of 'path_interpolation.dart';

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
