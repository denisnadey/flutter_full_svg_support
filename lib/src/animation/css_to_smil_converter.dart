import 'dart:math' as math;

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

      // Создаём SMIL анимацию
      final smilAnim = _createSmilAnimation(
        keyframes: keyframes,
        animation: animation,
        targetNode: targetNode,
        attributeName: propertyName,
        attributeType: attributeType,
        values: values,
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
      final values = sortedOffsets
          .map((offset) => prop.value[offset]!)
          .toList();
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
  }) {
    // Конвертируем CSS values в SMIL values
    final smilValues = _convertCssValues(values, attributeType, attributeName);

    // Создаём keyTimes из keyframe offsets
    final keyTimes = _extractKeyTimes(keyframes, attributeName);

    // Конвертируем direction в runtime направление проигрывания итераций
    final playbackDirection = _convertDirection(animation.direction);

    // Конвертируем timing function в calcMode/keySplines
    final timing = _convertTimingFunction(
      animation.timingFunction,
      smilValues.length,
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
        keySplines: timing.keySplines,
        dur: animation.duration,
        begin: animation.delay,
        repeatCount: animation.iterationCount,
        fillMode: fillMode,
        calcMode: timing.calcMode,
        playbackDirection: playbackDirection,
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
    if (attributeName == 'transform' &&
        attributeType == SvgAttributeType.transform) {
      return cssValues.map((value) {
        return _normalizeCssTransform(value.toString());
      }).toList();
    }

    // Для других типов возвращаем как есть
    return cssValues;
  }

  /// Конвертирует CSS timing function в SMIL calcMode/keySplines
  static _TimingConversion _convertTimingFunction(
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
        return _splineTiming(
          const CubicBezier(0.25, 0.1, 0.25, 1.0),
          valueCount,
        );
      case 'ease-in':
        return _splineTiming(
          const CubicBezier(0.42, 0.0, 1.0, 1.0),
          valueCount,
        );
      case 'ease-out':
        return _splineTiming(
          const CubicBezier(0.0, 0.0, 0.58, 1.0),
          valueCount,
        );
      case 'ease-in-out':
        return _splineTiming(
          const CubicBezier(0.42, 0.0, 0.58, 1.0),
          valueCount,
        );
      default:
        if (normalized.startsWith('steps(')) {
          return const _TimingConversion(calcMode: SmilCalcMode.discrete);
        }

        final cubicBezier = _parseCubicBezier(normalized);
        if (cubicBezier != null) {
          return _splineTiming(cubicBezier, valueCount);
        }
        return const _TimingConversion(calcMode: SmilCalcMode.linear);
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

  static SmilPlaybackDirection _convertDirection(String direction) {
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

  static _TimingConversion _splineTiming(CubicBezier spline, int valueCount) {
    return _TimingConversion(
      calcMode: SmilCalcMode.spline,
      keySplines: List<CubicBezier>.filled(valueCount - 1, spline),
    );
  }

  static CubicBezier? _parseCubicBezier(String value) {
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

  static String _normalizeCssTransform(String value) {
    final input = value.trim();
    if (input.isEmpty) {
      return input;
    }

    final regex = RegExp(
      r'(translate|translatex|translatey|rotate|scale|scalex|scaley|skewx|skewy|matrix)\s*\(\s*([^)]+)\s*\)',
      caseSensitive: false,
    );

    final normalizedParts = <String>[];
    for (final match in regex.allMatches(input)) {
      final functionName = match.group(1)!.toLowerCase();
      final args = match
          .group(2)!
          .split(RegExp(r'[\s,]+'))
          .where((part) => part.trim().isNotEmpty)
          .map((part) => part.trim())
          .toList();

      String? normalized;
      switch (functionName) {
        case 'translate':
          normalized = _normalizeTranslate(args);
          break;
        case 'translatex':
          normalized = _normalizeTranslate(<String>[
            if (args.isNotEmpty) args[0],
            '0',
          ]);
          break;
        case 'translatey':
          normalized = _normalizeTranslate(<String>[
            '0',
            if (args.isNotEmpty) args[0],
          ]);
          break;
        case 'rotate':
          normalized = _normalizeRotate(args);
          break;
        case 'scale':
          normalized = _normalizeScale(args);
          break;
        case 'scalex':
          normalized = _normalizeScale(<String>[
            if (args.isNotEmpty) args[0],
            '1',
          ]);
          break;
        case 'scaley':
          normalized = _normalizeScale(<String>[
            '1',
            if (args.isNotEmpty) args[0],
          ]);
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
      }

      if (normalized != null) {
        normalizedParts.add(normalized);
      }
    }

    return normalizedParts.isNotEmpty ? normalizedParts.join(' ') : input;
  }

  static String? _normalizeTranslate(List<String> args) {
    final tx = args.isNotEmpty ? _parseLength(args[0]) : 0.0;
    final ty = args.length > 1 ? _parseLength(args[1]) : 0.0;
    return 'translate(${_formatDouble(tx)}, ${_formatDouble(ty)})';
  }

  static String? _normalizeRotate(List<String> args) {
    final angle = args.isNotEmpty ? _parseAngleToDegrees(args[0]) : 0.0;
    final cx = args.length > 1 ? _parseLength(args[1]) : null;
    final cy = args.length > 2 ? _parseLength(args[2]) : null;
    if (cx != null && cy != null) {
      return 'rotate(${_formatDouble(angle)}, ${_formatDouble(cx)}, ${_formatDouble(cy)})';
    }
    return 'rotate(${_formatDouble(angle)})';
  }

  static String? _normalizeScale(List<String> args) {
    final sx = args.isNotEmpty ? _parseNumber(args[0], fallback: 1.0) : 1.0;
    final sy = args.length > 1 ? _parseNumber(args[1], fallback: sx) : sx;
    return 'scale(${_formatDouble(sx)}, ${_formatDouble(sy)})';
  }

  static String? _normalizeSkew(List<String> args, String name) {
    final angle = args.isNotEmpty ? _parseAngleToDegrees(args[0]) : 0.0;
    return '$name(${_formatDouble(angle)})';
  }

  static String? _normalizeMatrix(List<String> args) {
    if (args.length < 6) {
      return null;
    }

    final values = args
        .take(6)
        .map((part) => _parseNumber(part, fallback: 0.0))
        .map(_formatDouble)
        .join(', ');
    return 'matrix($values)';
  }

  static double _parseLength(String value) {
    return _parseNumber(value, fallback: 0.0);
  }

  static double _parseAngleToDegrees(String value) {
    final match = RegExp(
      r'^([+-]?(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?)\s*(deg|rad|turn|grad)?$',
      caseSensitive: false,
    ).firstMatch(value.trim());
    if (match == null) {
      return 0.0;
    }

    final number = double.tryParse(match.group(1) ?? '') ?? 0.0;
    final unit = (match.group(2) ?? 'deg').toLowerCase();
    return switch (unit) {
      'deg' => number,
      'rad' => number * 180.0 / math.pi,
      'turn' => number * 360.0,
      'grad' => number * 0.9,
      _ => number,
    };
  }

  static double _parseNumber(String value, {required double fallback}) {
    final match = RegExp(
      r'^[+-]?(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?',
    ).firstMatch(value.trim());
    if (match == null) {
      return fallback;
    }
    return double.tryParse(match.group(0)!) ?? fallback;
  }

  static String _formatDouble(double value) {
    final normalized = value == -0.0 ? 0.0 : value;
    if (normalized == normalized.truncateToDouble()) {
      return normalized.toStringAsFixed(0);
    }
    return normalized
        .toStringAsFixed(4)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }
}

class _TimingConversion {
  const _TimingConversion({required this.calcMode, this.keySplines});

  final SmilCalcMode calcMode;
  final List<CubicBezier>? keySplines;
}
