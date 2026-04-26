part of 'css_to_smil_converter.dart';

/// Converts a CSS timing function to SMIL calcMode/keySplines
_TimingConversion _convertTimingFunction(
  String timingFunction,
  int valueCount,
) {
  if (valueCount < 2) {
    return const _TimingConversion(calcMode: SmilCalcMode.linear);
  }

  final normalized = timingFunction.trim().toLowerCase();

  switch (normalized) {
    case 'linear':
      return const _TimingConversion(calcMode: SmilCalcMode.linear);
    case 'step-start':
    case 'step-end':
      return const _TimingConversion(calcMode: SmilCalcMode.discrete);
    case 'ease':
      return _splineTiming(const CubicBezier(0.25, 0.1, 0.25, 1.0), valueCount);
    case 'ease-in':
      return _splineTiming(const CubicBezier(0.42, 0.0, 1.0, 1.0), valueCount);
    case 'ease-out':
      return _splineTiming(const CubicBezier(0.0, 0.0, 0.58, 1.0), valueCount);
    case 'ease-in-out':
      return _splineTiming(const CubicBezier(0.42, 0.0, 0.58, 1.0), valueCount);
    default:
      if (normalized.startsWith('steps(')) {
        final step = _parseSteps(normalized);
        if (step != null) {
          return _stepTiming(step, valueCount);
        }
        return const _TimingConversion(calcMode: SmilCalcMode.discrete);
      }

      final cubicBezier = _parseCubicBezier(normalized);
      if (cubicBezier != null) {
        return _splineTiming(cubicBezier, valueCount);
      }
      return const _TimingConversion(calcMode: SmilCalcMode.linear);
  }
}

_TimingConversion _splineTiming(CubicBezier bezier, int valueCount) {
  return _TimingConversion(
    calcMode: SmilCalcMode.spline,
    keySplines: List<CubicBezier>.filled(valueCount - 1, bezier),
  );
}

_TimingConversion _stepTiming(StepTiming step, int valueCount) {
  return _TimingConversion(
    calcMode: SmilCalcMode.linear, // Using linear to interpolate steps
    keySteps: List<StepTiming>.filled(valueCount - 1, step),
  );
}

StepTiming? _parseSteps(String value) {
  // Expected format: steps(5) or steps(5, end) or steps(5, start)
  final match = RegExp(
    r'^steps\(\s*(\d+)(?:\s*,\s*(start|end))?\s*\)$',
    caseSensitive: false,
  ).firstMatch(value.trim());
  if (match != null) {
    final steps = int.tryParse(match.group(1) ?? '') ?? 1;
    final type = (match.group(2) ?? 'end').toLowerCase();
    return StepTiming(steps: steps, stepAtStart: type == 'start');
  }
  return null;
}

CubicBezier? _parseCubicBezier(String value) {
  final match = RegExp(
    r'^cubic-bezier\(\s*([^)]+)\s*\)$',
    caseSensitive: false,
  ).firstMatch(value);
  if (match == null) {
    return null;
  }

  final rawValues = match
      .group(1)!
      .split(',')
      .map((part) => double.tryParse(part.trim()))
      .toList();
  if (rawValues.length != 4 || rawValues.any((item) => item == null)) {
    return null;
  }

  final x1 = rawValues[0]!.clamp(0.0, 1.0).toDouble();
  final y1 = rawValues[1]!;
  final x2 = rawValues[2]!.clamp(0.0, 1.0).toDouble();
  final y2 = rawValues[3]!;
  return CubicBezier(x1, y1, x2, y2);
}

class _TimingConversion {
  const _TimingConversion({
    required this.calcMode,
    this.keySplines,
    this.keySteps,
  });

  final SmilCalcMode calcMode;
  final List<CubicBezier>? keySplines;
  final List<StepTiming>? keySteps;
}
