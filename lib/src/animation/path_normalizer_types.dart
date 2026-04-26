part of 'path_normalizer.dart';

/// Result of normalizing two paths for interpolation.
class NormalizedPathPair {
  const NormalizedPathPair({required this.from, required this.to});

  final List<PathCommand> from;
  final List<PathCommand> to;

  /// Check if normalization was successful (same length, compatible commands).
  bool get isValid {
    if (from.length != to.length) return false;

    for (int i = 0; i < from.length; i++) {
      if (from[i].runtimeType != to[i].runtimeType) {
        return false;
      }
    }

    return true;
  }
}
