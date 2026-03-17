part of 'css_to_smil_converter.dart';

List<SmilAnimation> _decomposeCompoundTransformInternal({
  required CssKeyframes keyframes,
  required CssAnimation animation,
  required SvgNode targetNode,
  required List<Object> values,
}) {
  final byFunction = _collectTransformFunctionsByOffset(keyframes);
  if (byFunction.isEmpty) {
    final fallback = _createSmilAnimation(
      keyframes: keyframes,
      animation: animation,
      targetNode: targetNode,
      attributeName: 'transform',
      attributeType: SvgAttributeType.transform,
      values: values,
    );
    return fallback == null ? <SmilAnimation>[] : <SmilAnimation>[fallback];
  }

  final relevantKfs =
      keyframes.keyframes
          .where((kf) => kf.properties.containsKey('transform'))
          .toList()
        ..sort((a, b) => a.offset.compareTo(b.offset));

  return _buildTransformAnimationsFromFunctions(
    byFunction: byFunction,
    relevantKeyframes: relevantKfs,
    animation: animation,
    targetNode: targetNode,
  );
}

Map<String, Map<double, String>> _collectTransformFunctionsByOffset(
  CssKeyframes keyframes,
) {
  final byFunction = <String, Map<double, String>>{};

  final relevantKfs =
      keyframes.keyframes
          .where((kf) => kf.properties.containsKey('transform'))
          .toList()
        ..sort((a, b) => a.offset.compareTo(b.offset));

  for (final kf in relevantKfs) {
    final rawTransform = kf.properties['transform']!;
    for (final m in _cssTransformFunctionRegex.allMatches(rawTransform)) {
      final funcName = m.group(1)!.toLowerCase();
      final args = m
          .group(2)!
          .split(RegExp(r'[\s,]+'))
          .where((s) => s.trim().isNotEmpty)
          .map((s) => s.trim())
          .toList();

      String? normalized;
      switch (funcName) {
        case 'translate':
          normalized = _normalizeTranslate(args);
          break;
        case 'translatex':
          normalized = _normalizeTranslate([if (args.isNotEmpty) args[0], '0']);
          break;
        case 'translatey':
          normalized = _normalizeTranslate(['0', if (args.isNotEmpty) args[0]]);
          break;
        case 'rotate':
          normalized = _normalizeRotate(args);
          break;
        case 'scale':
          normalized = _normalizeScale(args);
          break;
        case 'scalex':
          normalized = _normalizeScale([if (args.isNotEmpty) args[0], '1']);
          break;
        case 'scaley':
          normalized = _normalizeScale(['1', if (args.isNotEmpty) args[0]]);
          break;
        case 'skewx':
          normalized = _normalizeSkew(args, 'skewX');
          break;
        case 'skewy':
          normalized = _normalizeSkew(args, 'skewY');
          break;
        case 'matrix':
          normalized = _normalizeMatrix(args);
          break;
        // 3D transform functions
        case 'translate3d':
          normalized = _normalizeTranslate3d(args);
          break;
        case 'translatez':
          normalized = _normalizeTranslateZ(args);
          break;
        case 'rotate3d':
          normalized = _normalizeRotate3d(args);
          break;
        case 'rotatex':
          normalized = _normalizeRotateAxis(args, 'rotateX');
          break;
        case 'rotatey':
          normalized = _normalizeRotateAxis(args, 'rotateY');
          break;
        case 'rotatez':
          normalized = _normalizeRotateAxis(args, 'rotateZ');
          break;
        case 'scale3d':
          normalized = _normalizeScale3d(args);
          break;
        case 'scalez':
          normalized = _normalizeScaleZ(args);
          break;
        case 'perspective':
          normalized = _normalizePerspective(args);
          break;
        case 'matrix3d':
          normalized = _normalizeMatrix3d(args);
          break;
      }

      if (normalized != null) {
        byFunction.putIfAbsent(funcName, () => <double, String>{});
        byFunction[funcName]![kf.offset] = normalized;
      }
    }
  }

  return byFunction;
}

List<SmilAnimation> _buildTransformAnimationsFromFunctions({
  required Map<String, Map<double, String>> byFunction,
  required List<CssKeyframe> relevantKeyframes,
  required CssAnimation animation,
  required SvgNode targetNode,
}) {
  final result = <SmilAnimation>[];

  for (final entry in byFunction.entries) {
    final animationForFunction = _buildTransformAnimationForFunction(
      functionName: entry.key,
      functionOffsets: entry.value,
      relevantKeyframes: relevantKeyframes,
      animation: animation,
      targetNode: targetNode,
    );
    if (animationForFunction != null) {
      result.add(animationForFunction);
    }
  }

  return result;
}

SmilAnimation? _buildTransformAnimationForFunction({
  required String functionName,
  required Map<double, String> functionOffsets,
  required List<CssKeyframe> relevantKeyframes,
  required CssAnimation animation,
  required SvgNode targetNode,
}) {
  final smilTransformType = _resolveSmilTransformType(functionName);

  final smilValues = <Object>[];
  final smilKeyTimes = <double>[];
  final sortedOffsets = functionOffsets.keys.toList()..sort();

  for (final offset in sortedOffsets) {
    final raw = functionOffsets[offset]!;
    final inner = RegExp(r'\(([^)]+)\)').firstMatch(raw)?.group(1) ?? raw;
    smilValues.add(inner);
    smilKeyTimes.add(offset);
  }

  if (smilValues.length < 2) {
    return null;
  }

  final timing = _resolveDecomposedTransformTiming(
    sortedOffsets: sortedOffsets,
    relevantKeyframes: relevantKeyframes,
    animation: animation,
    valueCount: smilValues.length,
  );

  final fillMode = _convertFillMode(animation.fillMode);
  final playbackDirection = _convertDirection(animation.direction);

  try {
    return SmilAnimation(
      type: SmilAnimationType.animateTransform,
      targetNode: targetNode,
      attributeName: 'transform',
      attributeType: SvgAttributeType.transform,
      transformType: smilTransformType,
      values: smilValues,
      keyTimes: smilKeyTimes,
      keySplines: timing.$1,
      keySteps: timing.$2,
      dur: animation.duration,
      begin: animation.delay,
      repeatCount: animation.iterationCount,
      fillMode: fillMode,
      calcMode: timing.$3,
      playbackDirection: playbackDirection,
      additive: SmilAdditiveMode.sum,
      accumulate: false,
    );
  } catch (_) {
    return null;
  }
}
