part of 'smil_parser.dart';

/// Распарсить анимационный элемент
SmilAnimation? _parseAnimationElement(
  SvgNode animNode,
  SvgNode targetNode,
  SvgDocument document,
) {
  try {
    // Определяем тип анимации
    final type = _parseAnimationType(animNode.tagName);

    // Для animateMotion логика отличается - там нет attributeName
    if (type == SmilAnimationType.animateMotion) {
      return _parseAnimateMotion(animNode, targetNode, document);
    }

    // Получаем имя анимируемого атрибута
    final attributeName =
        animNode.getAttributeValue('attributeName') as String?;
    if (attributeName == null) {
      return null; // Без attributeName анимация невалидна
    }

    // Определяем тип атрибута
    final attributeType = _inferAttributeType(attributeName, targetNode);

    // Для animateTransform получаем тип трансформации (rotate, translate, etc.)
    String? transformType;
    if (type == SmilAnimationType.animateTransform) {
      transformType = animNode
          .getAttributeValue('type')
          ?.toString()
          .toLowerCase();
      if (transformType == null) {
        return null; // animateTransform без type невалидна
      }
    }

    // Парсим значения анимации
    final from = _parseValue(
      animNode.getAttributeValue('from'),
      attributeType,
      transformType: transformType,
    );
    final to = _parseValue(
      animNode.getAttributeValue('to'),
      attributeType,
      transformType: transformType,
    );
    final by = _parseValue(
      animNode.getAttributeValue('by'),
      attributeType,
      transformType: transformType,
    );

    // Парсим values и keyTimes
    List<Object>? values;
    List<double>? keyTimes;
    final valuesStr = animNode.getAttributeValue('values') as String?;
    if (valuesStr != null) {
      values = _parseValues(
        valuesStr,
        attributeType,
        transformType: transformType,
      );
    }

    final keyTimesStr = animNode.getAttributeValue('keyTimes') as String?;
    if (keyTimesStr != null) {
      keyTimes = _parseKeyTimes(keyTimesStr);
    }

    // Парсим keySplines
    List<CubicBezier>? keySplines;
    final keySplinesStr = animNode.getAttributeValue('keySplines') as String?;
    if (keySplinesStr != null) {
      keySplines = _parseKeySplines(keySplinesStr);
    }

    // Парсим ID анимации (для syncbase timing)
    final id = animNode.id;

    // Парсим тайминг
    final dur = _parseDuration(animNode.getAttributeValue('dur'));
    if (dur == null) {
      return null; // Без dur анимация невалидна
    }

    // Парсим begin/end как timing conditions (поддержка syncbase)
    var begin = Duration.zero;
    List<TimingCondition> beginConditions = [];
    final beginAttr = animNode.getAttributeValue('begin')?.toString();
    if (beginAttr != null) {
      beginConditions = TimingParser.parse(beginAttr);
      // Если есть простое offset condition, используем его как begin
      if (beginConditions.length == 1 &&
          beginConditions.first is OffsetCondition) {
        begin = (beginConditions.first as OffsetCondition).offset;
        beginConditions = []; // Не нужны conditions для простого offset
      }
    }

    Duration? end;
    List<TimingCondition> endConditions = [];
    final endAttr = animNode.getAttributeValue('end')?.toString();
    if (endAttr != null) {
      endConditions = TimingParser.parse(endAttr);
      // Если есть простое offset condition, используем его как end
      if (endConditions.length == 1 && endConditions.first is OffsetCondition) {
        end = (endConditions.first as OffsetCondition).offset;
        endConditions = []; // Не нужны conditions для простого offset
      }
    }

    // Парсим repeatCount
    var repeatCount = 1.0;
    final repeatCountStr = animNode.getAttributeValue('repeatCount') as String?;
    if (repeatCountStr != null) {
      if (repeatCountStr == 'indefinite') {
        repeatCount = double.infinity;
      } else {
        repeatCount = double.tryParse(repeatCountStr) ?? 1.0;
      }
    }

    final repeatDur = _parseDuration(animNode.getAttributeValue('repeatDur'));

    // Парсим режимы - используем toString() для безопасной конвертации
    final fillMode = _parseFillMode(
      animNode.getAttributeValue('fill')?.toString(),
    );
    final calcMode = _parseCalcMode(
      animNode.getAttributeValue('calcMode')?.toString(),
    );
    final additive = _parseAdditiveMode(
      animNode.getAttributeValue('additive')?.toString(),
    );
    final accumulate =
        animNode.getAttributeValue('accumulate')?.toString() == 'sum';

    return SmilAnimation(
      id: id,
      type: type,
      targetNode: targetNode,
      attributeName: attributeName,
      attributeType: attributeType,
      transformType: transformType,
      from: from,
      to: to,
      by: by,
      values: values,
      keyTimes: keyTimes,
      keySplines: keySplines,
      dur: dur,
      begin: begin,
      end: end,
      beginConditions: beginConditions,
      endConditions: endConditions,
      repeatCount: repeatCount,
      repeatDur: repeatDur,
      fillMode: fillMode,
      calcMode: calcMode,
      additive: additive,
      accumulate: accumulate,
    );
  } catch (_) {
    // Игнорируем невалидные анимации
    return null;
  }
}

/// Определить тип анимации по тегу
SmilAnimationType _parseAnimationType(String tagName) {
  switch (tagName) {
    case 'animate':
      return SmilAnimationType.animate;
    case 'animateTransform':
      return SmilAnimationType.animateTransform;
    case 'animateMotion':
      return SmilAnimationType.animateMotion;
    case 'set':
      return SmilAnimationType.set;
    case 'animateColor':
      return SmilAnimationType.animateColor;
    default:
      return SmilAnimationType.animate;
  }
}

/// Определить тип атрибута
SvgAttributeType _inferAttributeType(String attributeName, SvgNode targetNode) {
  // Сначала проверяем, есть ли уже атрибут на узле
  final existingAttr = targetNode.getAttribute(attributeName);
  if (existingAttr != null) {
    return existingAttr.type;
  }

  // Иначе определяем по имени
  if (_numberAttributes.contains(attributeName)) {
    return SvgAttributeType.number;
  }
  if (_colorAttributes.contains(attributeName)) {
    return SvgAttributeType.color;
  }
  if (attributeName == 'transform') {
    return SvgAttributeType.transform;
  }
  if (attributeName == 'd') {
    return SvgAttributeType.path;
  }
  if (attributeName == 'points') {
    return SvgAttributeType.points;
  }

  return SvgAttributeType.string;
}

/// Распарсить значение в соответствии с типом
Object? _parseValue(
  Object? value,
  SvgAttributeType type, {
  String? transformType,
}) {
  if (value == null) {
    return null;
  }

  switch (type) {
    case SvgAttributeType.number:
    case SvgAttributeType.length:
      if (value is num) {
        return value.toDouble();
      }
      if (value is String) {
        final cleaned = value.trim().replaceAll(RegExp(r'[a-zA-Z%]+$'), '');
        return double.tryParse(cleaned);
      }
      return null;

    case SvgAttributeType.color:
      // Цвета будут парситься интерполяторами
      return value;

    case SvgAttributeType.transform:
      // Для animateTransform нужно обернуть значения в тип трансформации
      if (transformType != null) {
        return '$transformType($value)';
      }
      return value;

    default:
      return value;
  }
}

/// Распарсить список values
List<Object> _parseValues(
  String valuesStr,
  SvgAttributeType type, {
  String? transformType,
}) {
  // values разделяются точкой с запятой
  final parts = valuesStr
      .split(';')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty);

  final result = <Object>[];
  for (final part in parts) {
    final value = _parseValue(part, type, transformType: transformType);
    if (value != null) {
      result.add(value);
    }
  }

  return result;
}

/// Распарсить keyTimes
List<double> _parseKeyTimes(String keyTimesStr) {
  // keyTimes разделяются точкой с запятой
  final parts = keyTimesStr
      .split(';')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty);

  final result = <double>[];
  for (final part in parts) {
    final value = double.tryParse(part);
    if (value != null) {
      result.add(value);
    }
  }

  return result;
}

/// Распарсить keySplines
List<CubicBezier> _parseKeySplines(String keySplinesStr) {
  // keySplines разделяются точкой с запятой
  // Каждый сплайн: "x1 y1 x2 y2"
  final parts = keySplinesStr
      .split(';')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty);

  final result = <CubicBezier>[];
  for (final part in parts) {
    final numbers = part
        .split(RegExp(r'[\s,]+'))
        .map((s) => double.tryParse(s))
        .whereType<double>()
        .toList();

    if (numbers.length == 4) {
      result.add(CubicBezier(numbers[0], numbers[1], numbers[2], numbers[3]));
    }
  }

  return result;
}

/// Распарсить длительность (dur, begin, end, repeatDur)
Duration? _parseDuration(Object? value) {
  if (value == null) {
    return null;
  }

  final str = value.toString().trim();

  // Форматы:
  // - "2s" (секунды)
  // - "500ms" (миллисекунды)
  // - "2.5s"
  // - "0:0:2" (часы:минуты:секунды)
  // - "indefinite" (возвращаем null)

  if (str == 'indefinite') {
    return null;
  }

  // Секунды
  if (str.endsWith('s') && !str.endsWith('ms')) {
    final seconds = double.tryParse(str.substring(0, str.length - 1));
    if (seconds != null) {
      return Duration(microseconds: (seconds * 1000000).round());
    }
  }

  // Миллисекунды
  if (str.endsWith('ms')) {
    final ms = double.tryParse(str.substring(0, str.length - 2));
    if (ms != null) {
      return Duration(microseconds: (ms * 1000).round());
    }
  }

  // Clock value (часы:минуты:секунды или минуты:секунды)
  if (str.contains(':')) {
    final parts = str.split(':').map((s) => double.tryParse(s)).toList();
    if (parts.every((p) => p != null)) {
      if (parts.length == 2) {
        // минуты:секунды
        return Duration(
          minutes: parts[0]!.toInt(),
          microseconds: (parts[1]! * 1000000).round(),
        );
      }
      if (parts.length == 3) {
        // часы:минуты:секунды
        return Duration(
          hours: parts[0]!.toInt(),
          minutes: parts[1]!.toInt(),
          microseconds: (parts[2]! * 1000000).round(),
        );
      }
    }
  }

  return null;
}

/// Распарсить fill mode
SmilFillMode _parseFillMode(String? value) {
  final str = value?.toLowerCase().trim();
  if (str == 'freeze') {
    return SmilFillMode.freeze;
  }
  return SmilFillMode.remove;
}

/// Распарсить calc mode
SmilCalcMode _parseCalcMode(String? value) {
  switch (value?.toLowerCase().trim()) {
    case 'discrete':
      return SmilCalcMode.discrete;
    case 'paced':
      return SmilCalcMode.paced;
    case 'spline':
      return SmilCalcMode.spline;
    default:
      return SmilCalcMode.linear;
  }
}

/// Распарсить additive mode
SmilAdditiveMode _parseAdditiveMode(String? value) {
  if (value?.toLowerCase().trim() == 'sum') {
    return SmilAdditiveMode.sum;
  }
  return SmilAdditiveMode.replace;
}

// Наборы известных атрибутов
const Set<String> _numberAttributes = {
  'x',
  'y',
  'cx',
  'cy',
  'r',
  'rx',
  'ry',
  'width',
  'height',
  'x1',
  'y1',
  'x2',
  'y2',
  'opacity',
  'fill-opacity',
  'stroke-opacity',
  'stroke-width',
  'stroke-dashoffset',
  'stop-opacity',
  'stroke-miterlimit',
  'font-size',
  'letter-spacing',
  'word-spacing',
  'textLength',
  'offset',
};

const Set<String> _colorAttributes = {
  'fill',
  'stroke',
  'stop-color',
  'flood-color',
  'lighting-color',
};
