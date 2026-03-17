part of 'css_to_smil_converter.dart';

/// Извлекает все анимируемые свойства из keyframes
Map<String, List<Object>> _extractAnimatedProperties(CssKeyframes keyframes) {
  final properties = <String, Map<double, String>>{};

  // Собираем все свойства из всех keyframes
  for (final keyframe in keyframes.keyframes) {
    for (final prop in keyframe.properties.entries) {
      properties.putIfAbsent(prop.key, () => {});
      properties[prop.key]![keyframe.offset] = prop.value;
    }
  }

  // Конвертируем в список значений с keyTimes
  final result = <String, List<Object>>{};
  for (final prop in properties.entries) {
    // Сортируем по offset
    final sortedOffsets = prop.value.keys.toList()..sort();
    final values = sortedOffsets.map((offset) => prop.value[offset]!).toList();
    result[prop.key] = values;
  }

  return result;
}

/// Creates a SMIL animation from CSS keyframes and animation
SmilAnimation? _createSmilAnimation({
  required CssKeyframes keyframes,
  required CssAnimation animation,
  required SvgNode targetNode,
  required String attributeName,
  required SvgAttributeType attributeType,
  required List<Object> values,
}) {
  // Конвертируем CSS values в SMIL values
  final smilValues = _convertCssValues(values, attributeType, attributeName);

  // Создаём keyTimes из keyframe offsets
  final keyTimes = _extractKeyTimes(keyframes, attributeName);

  // Конвертируем direction в runtime направление проигрывания итераций
  final playbackDirection = _convertDirection(animation.direction);

  // Строим per-keyframe timing.
  // Each interval [i..i+1] uses the timingFunction of keyframe[i], or the
  // animation-level timing as fallback.
  final relevantKeyframes =
      keyframes.keyframes
          .where((kf) => kf.properties.containsKey(attributeName))
          .toList()
        ..sort((a, b) => a.offset.compareTo(b.offset));

  final intervalCount = smilValues.length > 1 ? smilValues.length - 1 : 0;
  SmilCalcMode calcMode = SmilCalcMode.linear;
  List<CubicBezier>? keySplines;
  List<StepTiming>? keySteps;

  if (intervalCount > 0) {
    // Try to detect per-keyframe overrides first.
    final perInterval = <_TimingConversion>[];
    for (int i = 0; i < intervalCount; i++) {
      final kfTimingStr = i < relevantKeyframes.length
          ? relevantKeyframes[i].timingFunction
          : null;
      final effectiveTiming = kfTimingStr ?? animation.timingFunction;
      perInterval.add(_convertTimingFunction(effectiveTiming, 2));
    }

    // If any interval is spline, the whole animation must be spline.
    final anySpline = perInterval.any((t) => t.calcMode == SmilCalcMode.spline);
    final anyStep = perInterval.any((t) => t.keySteps != null);

    if (anySpline) {
      calcMode = SmilCalcMode.spline;
      keySplines = [];
      for (final t in perInterval) {
        if (t.keySplines != null && t.keySplines!.isNotEmpty) {
          keySplines.add(t.keySplines!.first);
        } else {
          // linear interval mapped to cubic-bezier(0,0,1,1)
          keySplines.add(const CubicBezier(0.0, 0.0, 1.0, 1.0));
        }
      }
    } else if (anyStep) {
      calcMode = SmilCalcMode.linear;
      keySteps = [];
      for (final t in perInterval) {
        if (t.keySteps != null && t.keySteps!.isNotEmpty) {
          keySteps.add(t.keySteps!.first);
        } else {
          keySteps.add(const StepTiming(steps: 1000));
        }
      }
    } else {
      // All intervals are the same non-spline mode — use animation-level default.
      final globalTiming = _convertTimingFunction(
        animation.timingFunction,
        smilValues.length,
      );
      calcMode = globalTiming.calcMode;
      keySplines = globalTiming.keySplines;
      keySteps = globalTiming.keySteps;
    }
  }

  // Конвертируем fillMode
  final fillMode = _convertFillMode(animation.fillMode);

  try {
    // Определяем тип SMIL анимации
    SmilAnimationType type = SmilAnimationType.animate;
    String? transformType;

    if (attributeName == 'transform') {
      type = SmilAnimationType.animateTransform;
      // Пытаемся определить тип трансформации из первого значения
      transformType = _inferTransformType(
        smilValues.isNotEmpty ? smilValues[0] : null,
      );
    }

    return SmilAnimation(
      type: type,
      targetNode: targetNode,
      attributeName: attributeName,
      attributeType: attributeType,
      transformType: transformType,
      values: smilValues,
      keyTimes: keyTimes,
      keySplines: keySplines,
      keySteps: keySteps,
      dur: animation.duration,
      begin: animation.delay,
      repeatCount: animation.iterationCount,
      fillMode: fillMode,
      calcMode: calcMode,
      playbackDirection: playbackDirection,
      additive: SmilAdditiveMode.replace,
      accumulate: false,
      isPaused: animation.isPaused,
    );
  } catch (_) {
    // Если не удалось создать анимацию, возвращаем null
    return null;
  }
}

/// Извлекает keyTimes для конкретного свойства
List<double> _extractKeyTimes(CssKeyframes keyframes, String propertyName) {
  // Находим keyframes, которые содержат это свойство
  final relevantKeyframes = keyframes.keyframes
      .where((kf) => kf.properties.containsKey(propertyName))
      .toList();

  // Сортируем по offset
  relevantKeyframes.sort((a, b) => a.offset.compareTo(b.offset));

  return relevantKeyframes.map((kf) => kf.offset).toList();
}

/// Конвертирует CSS values в SMIL values
List<Object> _convertCssValues(
  List<Object> cssValues,
  SvgAttributeType attributeType,
  String attributeName,
) {
  // Для transform нужно парсить CSS функции
  if (attributeName == 'transform' &&
      attributeType == SvgAttributeType.transform) {
    return cssValues.map((value) {
      return _normalizeCssTransform(value.toString());
    }).toList();
  }

  // Для других типов возвращаем как есть
  return cssValues;
}

/// Converts CSS fillMode to SMIL fillMode
SmilFillMode _convertFillMode(String fillMode) {
  switch (fillMode.toLowerCase()) {
    case 'forwards':
      return SmilFillMode.freeze;
    case 'backwards':
      return SmilFillMode.backwards;
    case 'both':
      return SmilFillMode.both;
    case 'none':
    default:
      return SmilFillMode.remove;
  }
}

SmilPlaybackDirection _convertDirection(String direction) {
  switch (direction.toLowerCase().trim()) {
    case 'reverse':
      return SmilPlaybackDirection.reverse;
    case 'alternate':
      return SmilPlaybackDirection.alternate;
    case 'alternate-reverse':
      return SmilPlaybackDirection.alternateReverse;
    case 'normal':
    default:
      return SmilPlaybackDirection.normal;
  }
}

/// Определяет тип атрибута
SvgAttributeType _inferAttributeType(String attributeName, SvgNode node) {
  // Базовые числовые атрибуты
  const numericAttributes = {
    'x',
    'y',
    'cx',
    'cy',
    'r',
    'rx',
    'ry',
    'width',
    'height',
    'opacity',
    'fill-opacity',
    'stroke-opacity',
    'stroke-width',
    'stroke-dashoffset',
    'stop-opacity',
    'font-size',
    'letter-spacing',
    'word-spacing',
  };

  if (numericAttributes.contains(attributeName)) {
    return SvgAttributeType.number;
  }

  // Цветовые атрибуты
  if (attributeName == 'fill' ||
      attributeName == 'stroke' ||
      attributeName == 'stop-color') {
    return SvgAttributeType.color;
  }

  // Трансформации
  if (attributeName == 'transform') {
    return SvgAttributeType.transform;
  }

  return SvgAttributeType.string;
}

/// Определяет тип трансформации из значения
String? _inferTransformType(Object? value) {
  if (value == null) {
    return null;
  }

  final str = value.toString().toLowerCase();
  if (str.startsWith('rotate')) {
    return 'rotate';
  }
  if (str.startsWith('translate')) {
    return 'translate';
  }
  if (str.startsWith('scale')) {
    return 'scale';
  }
  if (str.startsWith('skewx')) {
    return 'skewX';
  }
  if (str.startsWith('skewy')) {
    return 'skewY';
  }

  return 'translate'; // По умолчанию
}
