import 'css_animations.dart';
import 'smil/smil_animation.dart';
import 'svg_dom.dart';

/// Конвертер CSS анимаций в SMIL структуру
class CssToSmilConverter {
  /// Конвертирует CSS keyframes и animation в список SMIL анимаций
  static List<SmilAnimation> convert(
    CssKeyframes keyframes,
    CssAnimation animation,
    SvgNode targetNode,
    SvgDocument document,
  ) {
    final smilAnimations = <SmilAnimation>[];

    // Для каждого свойства в keyframes создаём отдельную SMIL анимацию
    final animatedProperties = _extractAnimatedProperties(keyframes);

    for (final property in animatedProperties.entries) {
      final propertyName = property.key;
      final values = property.value;

      // Определяем тип атрибута
      final attributeType = _inferAttributeType(propertyName, targetNode);

      // Конвертируем CSS timing function в SMIL calcMode
      final calcMode = _convertTimingFunction(animation.timingFunction);

      // Создаём SMIL анимацию
      final smilAnim = _createSmilAnimation(
        keyframes: keyframes,
        animation: animation,
        targetNode: targetNode,
        attributeName: propertyName,
        attributeType: attributeType,
        values: values,
        calcMode: calcMode,
      );

      if (smilAnim != null) {
        smilAnimations.add(smilAnim);
      }
    }

    return smilAnimations;
  }

  /// Извлекает все анимируемые свойства из keyframes
  static Map<String, List<Object>> _extractAnimatedProperties(
    CssKeyframes keyframes,
  ) {
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

  /// Создаёт SMIL анимацию из CSS keyframes и animation
  static SmilAnimation? _createSmilAnimation({
    required CssKeyframes keyframes,
    required CssAnimation animation,
    required SvgNode targetNode,
    required String attributeName,
    required SvgAttributeType attributeType,
    required List<Object> values,
    required SmilCalcMode calcMode,
  }) {
    // Конвертируем CSS values в SMIL values
    final smilValues = _convertCssValues(values, attributeType, attributeName);

    // Создаём keyTimes из keyframe offsets
    final keyTimes = _extractKeyTimes(keyframes, attributeName);

    // Конвертируем direction в параметры анимации
    final (finalValues, finalKeyTimes) = _applyDirection(
      animation.direction,
      smilValues,
      keyTimes,
    );

    // Конвертируем fillMode
    final fillMode = _convertFillMode(animation.fillMode);

    try {
      // Определяем тип SMIL анимации
      SmilAnimationType type = SmilAnimationType.animate;
      String? transformType;

      if (attributeName == 'transform') {
        type = SmilAnimationType.animateTransform;
        // Пытаемся определить тип трансформации из первого значения
        transformType = _inferTransformType(smilValues.isNotEmpty ? smilValues[0] : null);
      }

      return SmilAnimation(
        type: type,
        targetNode: targetNode,
        attributeName: attributeName,
        attributeType: attributeType,
        transformType: transformType,
        values: finalValues,
        keyTimes: finalKeyTimes,
        dur: animation.duration,
        begin: animation.delay,
        repeatCount: animation.iterationCount,
        fillMode: fillMode,
        calcMode: calcMode,
        additive: SmilAdditiveMode.replace,
        accumulate: false,
      );
    } catch (e) {
      // Если не удалось создать анимацию, возвращаем null
      return null;
    }
  }

  /// Извлекает keyTimes для конкретного свойства
  static List<double> _extractKeyTimes(
    CssKeyframes keyframes,
    String propertyName,
  ) {
    // Находим keyframes, которые содержат это свойство
    final relevantKeyframes = keyframes.keyframes
        .where((kf) => kf.properties.containsKey(propertyName))
        .toList();

    // Сортируем по offset
    relevantKeyframes.sort((a, b) => a.offset.compareTo(b.offset));

    return relevantKeyframes.map((kf) => kf.offset).toList();
  }

  /// Конвертирует CSS values в SMIL values
  static List<Object> _convertCssValues(
    List<Object> cssValues,
    SvgAttributeType attributeType,
    String attributeName,
  ) {
    // Для transform нужно парсить CSS функции
    if (attributeName == 'transform' && attributeType == SvgAttributeType.transform) {
      // Пока возвращаем строки, парсинг transform будет позже
      // TODO: Парсить CSS transform функции (rotate(45deg), translate(10px), etc.)
      return cssValues;
    }
    
    // Для других типов возвращаем как есть
    return cssValues;
  }

  /// Конвертирует CSS timing function в SMIL calcMode
  static SmilCalcMode _convertTimingFunction(String timingFunction) {
    switch (timingFunction.toLowerCase()) {
      case 'linear':
        return SmilCalcMode.linear;
      case 'ease':
      case 'ease-in':
      case 'ease-out':
      case 'ease-in-out':
      case 'step-start':
      case 'step-end':
        // Для этих функций нужны keySplines, пока используем linear
        // TODO: Реализовать cubic-bezier парсинг
        return SmilCalcMode.linear;
      default:
        return SmilCalcMode.linear;
    }
  }

  /// Конвертирует CSS fillMode в SMIL fillMode
  static SmilFillMode _convertFillMode(String fillMode) {
    switch (fillMode.toLowerCase()) {
      case 'forwards':
      case 'both':
        return SmilFillMode.freeze;
      case 'backwards':
      case 'none':
      default:
        return SmilFillMode.remove;
    }
  }

  /// Применяет CSS direction к values и keyTimes
  static (List<Object>, List<double>) _applyDirection(
    String direction,
    List<Object> values,
    List<double> keyTimes,
  ) {
    switch (direction.toLowerCase()) {
      case 'reverse':
        return (
          values.reversed.toList(),
          keyTimes.reversed.map((kt) => 1.0 - kt).toList(),
        );
      case 'alternate':
      case 'alternate-reverse':
        // TODO: Реализовать alternate (требует отслеживания итерации)
        return (values, keyTimes);
      case 'normal':
      default:
        return (values, keyTimes);
    }
  }

  /// Определяет тип атрибута
  static SvgAttributeType _inferAttributeType(
    String attributeName,
    SvgNode node,
  ) {
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
    };

    if (numericAttributes.contains(attributeName)) {
      return SvgAttributeType.number;
    }

    // Цветовые атрибуты
    if (attributeName == 'fill' || attributeName == 'stroke') {
      return SvgAttributeType.color;
    }

    // Трансформации
    if (attributeName == 'transform') {
      return SvgAttributeType.transform;
    }

    return SvgAttributeType.string;
  }

  /// Определяет тип трансформации из значения
  static String? _inferTransformType(Object? value) {
    if (value == null) return null;

    final str = value.toString().toLowerCase();
    if (str.startsWith('rotate')) return 'rotate';
    if (str.startsWith('translate')) return 'translate';
    if (str.startsWith('scale')) return 'scale';
    if (str.startsWith('skewx')) return 'skewX';
    if (str.startsWith('skewy')) return 'skewY';

    return 'translate'; // По умолчанию
  }
}
