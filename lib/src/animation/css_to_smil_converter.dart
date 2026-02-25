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

      // Для transform: проверяем не является ли значение compound transform.
      // SVGator генерирует: translate(Xpx,Ypx) scale(sx,sy) — несколько функций.
      // Такой compound нужно разложить на отдельные SmilAnimation per-function.
      if (propertyName == 'transform' &&
          attributeType == SvgAttributeType.transform) {
        final decomposed = _decomposeCompoundTransform(
          keyframes: keyframes,
          animation: animation,
          targetNode: targetNode,
          values: values,
        );
        smilAnimations.addAll(decomposed);
        continue;
      }

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

  /// Раскладывает compound CSS transform (`translate(...) scale(...)`) на
  /// отдельные SmilAnimation — по одной на каждую изменяющуюся функцию.
  static List<SmilAnimation> _decomposeCompoundTransform({
    required CssKeyframes keyframes,
    required CssAnimation animation,
    required SvgNode targetNode,
    required List<Object> values,
  }) {
    final result = <SmilAnimation>[];

    // Разбираем каждый keyframe-value на список (functionName, normalizedValue).
    // Нормализованное значение — строка вида `translate(x, y)` / `scale(sx, sy)` etc.
    final funcRegex = RegExp(
      r'(translate|translatex|translatey|rotate|scale|scalex|scaley|skewx|skewy|matrix)\s*\(\s*([^)]+)\s*\)',
      caseSensitive: false,
    );

    // Collect per-function values per keyframe.
    // Map: functionName -> list of (offset, normalizedValue)
    final byFunction = <String, Map<double, String>>{};

    final relevantKfs = keyframes.keyframes
        .where((kf) => kf.properties.containsKey('transform'))
        .toList()
      ..sort((a, b) => a.offset.compareTo(b.offset));

    for (final kf in relevantKfs) {
      final rawTransform = kf.properties['transform']!;
      for (final m in funcRegex.allMatches(rawTransform)) {
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
            normalized = _normalizeTranslate([
              if (args.isNotEmpty) args[0],
              '0',
            ]);
            break;
          case 'translatey':
            normalized = _normalizeTranslate([
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
            normalized = _normalizeScale([
              if (args.isNotEmpty) args[0],
              '1',
            ]);
            break;
          case 'scaley':
            normalized = _normalizeScale([
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
          byFunction.putIfAbsent(funcName, () => {});
          byFunction[funcName]![kf.offset] = normalized;
        }
      }
    }

    if (byFunction.isEmpty) {
      // Fallback: no recognised functions — treat as single animation.
      final fallback = _createSmilAnimation(
        keyframes: keyframes,
        animation: animation,
        targetNode: targetNode,
        attributeName: 'transform',
        attributeType: SvgAttributeType.transform,
        values: values,
      );
      if (fallback != null) result.add(fallback);
      return result;
    }

    for (final entry in byFunction.entries) {
      final funcName = entry.key;
      final funcOffsets = entry.value;

      // Determine SMIL transform type.
      String smilTransformType;
      switch (funcName) {
        case 'rotate':
          smilTransformType = 'rotate';
          break;
        case 'scale':
        case 'scalex':
        case 'scaley':
          smilTransformType = 'scale';
          break;
        case 'skewx':
          smilTransformType = 'skewX';
          break;
        case 'skewy':
          smilTransformType = 'skewY';
          break;
        case 'translate':
        case 'translatex':
        case 'translatey':
        default:
          smilTransformType = 'translate';
          break;
      }

      // Extract inner values (the arguments to the function).
      final smilValues = <Object>[];
      final smilKeyTimes = <double>[];
      final sortedOffsets = funcOffsets.keys.toList()..sort();
      for (final offset in sortedOffsets) {
        final raw = funcOffsets[offset]!;
        // Extract arguments from normalised `func(args)`.
        final inner =
            RegExp(r'\(([^)]+)\)').firstMatch(raw)?.group(1) ?? raw;
        smilValues.add(inner);
        smilKeyTimes.add(offset);
      }

      if (smilValues.length < 2) continue;

      // Build per-keyframe timing.
      final intervalCount = smilValues.length - 1;
      SmilCalcMode calcMode = SmilCalcMode.linear;
      List<CubicBezier>? keySplines;

      final perInterval = <_TimingConversion>[];
      for (int i = 0; i < intervalCount; i++) {
        final kfOffset = sortedOffsets[i];
        final kf = relevantKfs.firstWhere(
          (k) => (k.offset - kfOffset).abs() < 1e-6,
          orElse: () => relevantKfs.first,
        );
        final kfTiming = kf.timingFunction ?? animation.timingFunction;
        perInterval.add(_convertTimingFunction(kfTiming, 2));
      }

      final anySpline = perInterval.any(
        (t) => t.calcMode == SmilCalcMode.spline,
      );
      if (anySpline) {
        calcMode = SmilCalcMode.spline;
        keySplines = [];
        for (final t in perInterval) {
          keySplines.add(
            t.keySplines?.isNotEmpty == true
                ? t.keySplines!.first
                : const CubicBezier(0.0, 0.0, 1.0, 1.0),
          );
        }
      } else {
        final globalT = _convertTimingFunction(
          animation.timingFunction,
          smilValues.length,
        );
        calcMode = globalT.calcMode;
        keySplines = globalT.keySplines;
      }

      final fillMode = _convertFillMode(animation.fillMode);
      final playbackDirection = _convertDirection(animation.direction);

      try {
        result.add(
          SmilAnimation(
            type: SmilAnimationType.animateTransform,
            targetNode: targetNode,
            attributeName: 'transform',
            attributeType: SvgAttributeType.transform,
            transformType: smilTransformType,
            values: smilValues,
            keyTimes: smilKeyTimes,
            keySplines: keySplines,
            dur: animation.duration,
            begin: animation.delay,
            repeatCount: animation.iterationCount,
            fillMode: fillMode,
            calcMode: calcMode,
            playbackDirection: playbackDirection,
            additive: SmilAdditiveMode.sum,
            accumulate: false,
          ),
        );
      } catch (_) {
        // skip invalid animation
      }
    }

    return result;
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

    // Строим per-keyframe timing.
    // Each interval [i..i+1] uses the timingFunction of keyframe[i], or the
    // animation-level timing as fallback.
    final relevantKeyframes = keyframes.keyframes
        .where((kf) => kf.properties.containsKey(attributeName))
        .toList()
      ..sort((a, b) => a.offset.compareTo(b.offset));

    final intervalCount = smilValues.length > 1 ? smilValues.length - 1 : 0;
    SmilCalcMode calcMode = SmilCalcMode.linear;
    List<CubicBezier>? keySplines;

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
      final anySpline = perInterval.any(
        (t) => t.calcMode == SmilCalcMode.spline,
      );
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
      } else {
        // All intervals are the same non-spline mode — use animation-level default.
        final globalTiming = _convertTimingFunction(
          animation.timingFunction,
          smilValues.length,
        );
        calcMode = globalTiming.calcMode;
        keySplines = globalTiming.keySplines;
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
        dur: animation.duration,
        begin: animation.delay,
        repeatCount: animation.iterationCount,
        fillMode: fillMode,
        calcMode: calcMode,
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
      'stroke-dashoffset',
      'stop-opacity',
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
