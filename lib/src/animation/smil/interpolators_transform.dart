part of 'interpolators.dart';

/// Identity transform string for 'none' value.
const _identityTransform = 'translate(0, 0)';

/// Checks if a transform value represents no transform.
bool _isNoneTransform(String value) {
  final trimmed = value.trim().toLowerCase();
  return trimmed.isEmpty || trimmed == 'none';
}

/// Checks if two transform lists have matching function types in the same order.
///
/// This is needed for per-function interpolation, which provides better results
/// for non-commutative transforms (e.g., rotate(0) scale(1) → rotate(180) scale(2)).
bool _hasMatchingTransformFunctions(
  List<SvgTransform> from,
  List<SvgTransform> to,
) {
  if (from.length != to.length) return false;
  for (int i = 0; i < from.length; i++) {
    if (from[i].type != to[i].type) return false;
  }
  return true;
}

/// Per-function interpolation for matching transform lists.
///
/// This is the preferred method for non-commutative transforms because it
/// interpolates each function independently, preserving the transform order
/// and producing visually correct results.
///
/// For example:
/// - `rotate(0) scale(1)` → `rotate(180) scale(2)` at t=0.5
/// - Results in `rotate(90) scale(1.5)` (each function interpolated)
///
/// This is better than matrix decomposition which may not preserve
/// the original transform semantics.
String _interpolateMatchingTransformLists(
  List<SvgTransform> from,
  List<SvgTransform> to,
  double t,
) {
  final results = <String>[];

  for (int i = 0; i < from.length; i++) {
    final interpolatedTransform = _interpolateSingleTransformValue(
      from[i],
      to[i],
      t,
    );
    results.add(interpolatedTransform);
  }

  return results.join(' ');
}

String _interpolateTransformValue(Object from, Object to, double t) {
  final fromStr = from.toString();
  final toStr = to.toString();

  // Handle 'none' values as identity transform
  final effectiveFrom = _isNoneTransform(fromStr)
      ? _identityTransform
      : fromStr;
  final effectiveTo = _isNoneTransform(toStr) ? _identityTransform : toStr;

  // If both are 'none', return identity
  if (_isNoneTransform(fromStr) && _isNoneTransform(toStr)) {
    return _identityTransform;
  }

  final fromTransforms = SvgTransform.parse(effectiveFrom);
  final toTransforms = SvgTransform.parse(effectiveTo);

  if (fromTransforms.isEmpty || toTransforms.isEmpty) {
    // Use identity decomposition for empty transforms
    final fromDecomp = fromTransforms.isEmpty
        ? TransformDecomposition.identity
        : TransformDecomposition.fromTransforms(fromTransforms);
    final toDecomp = toTransforms.isEmpty
        ? TransformDecomposition.identity
        : TransformDecomposition.fromTransforms(toTransforms);
    final interpolated = fromDecomp.lerp(toDecomp, t);
    final resultTransforms = interpolated.toTransforms();
    if (resultTransforms.isEmpty) {
      return _identityTransform;
    }
    return resultTransforms
        .map((transform) {
          final name = transform.type.toString().split('.').last;
          final values = transform.values
              .map((v) => v.toStringAsFixed(4))
              .join(', ');
          return '$name($values)';
        })
        .join(' ');
  }

  // Check if transform lists have matching functions - use per-function interpolation
  // This handles non-commutative transforms better (e.g., rotate + scale)
  if (_hasMatchingTransformFunctions(fromTransforms, toTransforms)) {
    return _interpolateMatchingTransformLists(fromTransforms, toTransforms, t);
  }

  // Single matching transform type - direct interpolation
  if (fromTransforms.length == 1 &&
      toTransforms.length == 1 &&
      fromTransforms[0].type == toTransforms[0].type) {
    return _interpolateSingleTransformValue(
      fromTransforms[0],
      toTransforms[0],
      t,
    );
  }

  // Fall back to matrix decomposition for non-matching transform lists
  final fromDecomp = TransformDecomposition.fromTransforms(fromTransforms);
  final toDecomp = TransformDecomposition.fromTransforms(toTransforms);
  final interpolated = fromDecomp.lerp(toDecomp, t);
  final resultTransforms = interpolated.toTransforms();

  return resultTransforms
      .map((transform) {
        final name = transform.type.toString().split('.').last;
        final values = transform.values
            .map((v) => v.toStringAsFixed(4))
            .join(', ');
        return '$name($values)';
      })
      .join(' ');
}

String _interpolateSingleTransformValue(
  SvgTransform from,
  SvgTransform to,
  double t,
) {
  final name = from.type.toString().split('.').last;
  final maxLength = from.values.length > to.values.length
      ? from.values.length
      : to.values.length;

  // Handle rotation specially - take shortest path
  if (from.type == SvgTransformType.rotate ||
      from.type == SvgTransformType.rotateX ||
      from.type == SvgTransformType.rotateY ||
      from.type == SvgTransformType.rotateZ) {
    final interpolatedValues = <double>[];
    for (int i = 0; i < maxLength; i++) {
      final fromVal = i < from.values.length ? from.values[i] : 0.0;
      final toVal = i < to.values.length ? to.values[i] : 0.0;

      // For angle (first value), we just interpolate directly
      // The animation system handles the actual rotation direction
      interpolatedValues.add(fromVal + (toVal - fromVal) * t);
    }

    final valueStr = interpolatedValues
        .map((v) => v.toStringAsFixed(4))
        .join(' ');
    return '$name($valueStr)';
  }

  final interpolatedValues = <double>[];
  for (int i = 0; i < maxLength; i++) {
    final fromVal = i < from.values.length ? from.values[i] : 0.0;
    final toVal = i < to.values.length ? to.values[i] : 0.0;
    interpolatedValues.add(fromVal + (toVal - fromVal) * t);
  }

  final valueStr = interpolatedValues
      .map((v) => v.toStringAsFixed(4))
      .join(' ');
  return '$name($valueStr)';
}
