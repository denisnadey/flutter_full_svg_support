part of 'interpolators.dart';

/// Identity transform string for 'none' value.
const _identityTransform = 'translate(0, 0)';

/// Checks if a transform value represents no transform.
bool _isNoneTransform(String value) {
  final trimmed = value.trim().toLowerCase();
  return trimmed.isEmpty || trimmed == 'none';
}

String _interpolateTransformValue(Object from, Object to, double t) {
  final fromStr = from.toString();
  final toStr = to.toString();

  // Handle 'none' values as identity transform
  final effectiveFrom = _isNoneTransform(fromStr) ? _identityTransform : fromStr;
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
              .map((v) => v.toStringAsFixed(2))
              .join(', ');
          return '$name($values)';
        })
        .join(' ');
  }

  if (fromTransforms.length == 1 &&
      toTransforms.length == 1 &&
      fromTransforms[0].type == toTransforms[0].type) {
    return _interpolateSingleTransformValue(
      fromTransforms[0],
      toTransforms[0],
      t,
    );
  }

  final fromDecomp = TransformDecomposition.fromTransforms(fromTransforms);
  final toDecomp = TransformDecomposition.fromTransforms(toTransforms);
  final interpolated = fromDecomp.lerp(toDecomp, t);
  final resultTransforms = interpolated.toTransforms();

  return resultTransforms
      .map((transform) {
        final name = transform.type.toString().split('.').last;
        final values = transform.values
            .map((v) => v.toStringAsFixed(2))
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

  final interpolatedValues = <double>[];
  for (int i = 0; i < maxLength; i++) {
    final fromVal = i < from.values.length ? from.values[i] : 0.0;
    final toVal = i < to.values.length ? to.values[i] : 0.0;
    interpolatedValues.add(fromVal + (toVal - fromVal) * t);
  }

  final valueStr = interpolatedValues
      .map((v) => v.toStringAsFixed(2))
      .join(' ');
  return '$name($valueStr)';
}
