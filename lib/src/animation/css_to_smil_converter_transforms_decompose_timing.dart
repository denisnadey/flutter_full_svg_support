part of 'css_to_smil_converter.dart';

(List<CubicBezier>?, List<StepTiming>?, SmilCalcMode)
_resolveDecomposedTransformTiming({
  required List<double> sortedOffsets,
  required List<CssKeyframe> relevantKeyframes,
  required CssAnimation animation,
  required int valueCount,
}) {
  final intervalCount = valueCount - 1;
  final perInterval = <_TimingConversion>[];

  for (int i = 0; i < intervalCount; i++) {
    final kfOffset = sortedOffsets[i];
    final kf = relevantKeyframes.firstWhere(
      (k) => (k.offset - kfOffset).abs() < 1e-6,
      orElse: () => relevantKeyframes.first,
    );
    final kfTiming = kf.timingFunction ?? animation.timingFunction;
    perInterval.add(_convertTimingFunction(kfTiming, 2));
  }

  final anySpline = perInterval.any((t) => t.calcMode == SmilCalcMode.spline);
  final anyStep = perInterval.any((t) => t.keySteps != null);

  if (anySpline) {
    final keySplines = <CubicBezier>[];
    for (final t in perInterval) {
      keySplines.add(
        t.keySplines?.isNotEmpty == true
            ? t.keySplines!.first
            : const CubicBezier(0.0, 0.0, 1.0, 1.0),
      );
    }
    return (keySplines, null, SmilCalcMode.spline);
  }

  if (anyStep) {
    final keySteps = <StepTiming>[];
    for (final t in perInterval) {
      keySteps.add(
        t.keySteps?.isNotEmpty == true
            ? t.keySteps!.first
            : const StepTiming(steps: 1000),
      );
    }
    return (null, keySteps, SmilCalcMode.linear);
  }

  final globalTiming = _convertTimingFunction(
    animation.timingFunction,
    valueCount,
  );
  return (
    globalTiming.keySplines,
    globalTiming.keySteps,
    globalTiming.calcMode,
  );
}

String _resolveSmilTransformType(String functionName) {
  switch (functionName) {
    case 'rotate':
    case 'rotatez':
      return 'rotate';
    case 'scale':
    case 'scalex':
    case 'scaley':
    case 'scale3d':
    case 'scalez':
      return 'scale';
    case 'skewx':
      return 'skewX';
    case 'skewy':
      return 'skewY';
    case 'translate':
    case 'translatex':
    case 'translatey':
    case 'translate3d':
    case 'translatez':
      return 'translate';
    // 3D rotations that need special handling
    case 'rotatex':
      return 'rotateX';
    case 'rotatey':
      return 'rotateY';
    case 'rotate3d':
      return 'rotate3d';
    case 'perspective':
      return 'perspective';
    case 'matrix':
      return 'matrix';
    case 'matrix3d':
      return 'matrix3d';
    default:
      return 'translate';
  }
}
