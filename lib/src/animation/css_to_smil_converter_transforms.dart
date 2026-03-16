part of 'css_to_smil_converter.dart';

/// Раскладывает compound CSS transform (`translate(...) scale(...)`) на
/// отдельные SmilAnimation — по одной на каждую изменяющуюся функцию.
List<SmilAnimation> _decomposeCompoundTransform({
  required CssKeyframes keyframes,
  required CssAnimation animation,
  required SvgNode targetNode,
  required List<Object> values,
}) {
  return _decomposeCompoundTransformInternal(
    keyframes: keyframes,
    animation: animation,
    targetNode: targetNode,
    values: values,
  );
}

String _normalizeCssTransform(String value) {
  return _normalizeCssTransformInternal(value);
}
