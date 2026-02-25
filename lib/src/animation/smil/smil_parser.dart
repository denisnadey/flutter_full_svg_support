import '../css_animations.dart';
import '../css_to_smil_converter.dart';
import '../svg_dom.dart';
import 'smil_animation.dart';
import 'timing_condition.dart';
import 'timing_parser.dart';

/// Парсер SMIL анимационных элементов из SVG DOM
class SmilParser {
  SmilParser._();

  /// Извлечь все SMIL анимации из документа (включая CSS анимации)
  static List<SmilAnimation> parseAnimations(SvgDocument document) {
    final animations = <SmilAnimation>[];

    // Парсим SMIL анимации (<animate>, <animateTransform>, etc.)
    _extractAnimations(document.root, document, animations);

    // Парсим CSS анимации из style атрибутов и @keyframes
    _extractCssAnimations(document.root, document, animations);

    // Парсим CSS анимации из <style> селекторов (#id, .class, tagName)
    if (document.cssSelectorRules != null) {
      _extractCssSelectorAnimations(
        document.root,
        document,
        document.cssSelectorRules!,
        animations,
      );
    }

    return animations;
  }

  /// Извлечь CSS анимации из элементов с style атрибутами
  static void _extractCssAnimations(
    SvgNode node,
    SvgDocument document,
    List<SmilAnimation> animations,
  ) {
    // Парсим style атрибут если есть
    final styleAttr = node.getAttributeValue('style') as String?;
    if (styleAttr != null && styleAttr.isNotEmpty) {
      final cssAnimation = CssParser.parseAnimationFromStyle(styleAttr);
      if (cssAnimation != null && document.cssKeyframes != null) {
        // Находим соответствующий @keyframes
        final keyframesList = document.cssKeyframes!
            .where((kf) => kf.name == cssAnimation.name)
            .toList();
        if (keyframesList.isEmpty) return;
        final keyframes = keyframesList.first;

        // Конвертируем CSS анимацию в SMIL
        final smilAnims = CssToSmilConverter.convert(
          keyframes,
          cssAnimation,
          node,
          document,
        );
        animations.addAll(smilAnims);

        // Помечаем узел как имеющий анимации
        node.hasAnimations = true;
      }
    }

    // Рекурсивно обрабатываем детей
    for (final child in node.children) {
      _extractCssAnimations(child, document, animations);
    }
  }

  /// Применить CSS правила из <style> к узлам по селекторам
  static void _extractCssSelectorAnimations(
    SvgNode node,
    SvgDocument document,
    List<CssSelectorRule> rules,
    List<SmilAnimation> animations,
  ) {
    // Проверяем каждое правило на совпадение с текущим узлом
    for (final rule in rules) {
      bool matches = false;

      if (rule.isIdSelector) {
        matches = node.id == rule.targetId;
      } else if (rule.isClassSelector) {
        matches =
            node.className != null &&
            node.className!.split(RegExp(r'\s+')).contains(rule.targetClass);
      } else {
        // Простой элементный селектор
        matches = node.tagName == rule.selector;
      }

      if (matches && rule.hasAnimation && document.cssKeyframes != null) {
        // Создаем фейковую строку style для парсинга animation свойств
        // (переиспользуем existing логику parseAnimationFromStyle)
        final styleStr = rule.declarations.entries
            .map((e) => '${e.key}: ${e.value}')
            .join('; ');

        final cssAnimation = CssParser.parseAnimationFromStyle(styleStr);
        if (cssAnimation != null) {
          final keyframesList = document.cssKeyframes!
              .where((kf) => kf.name == cssAnimation.name)
              .toList();

          if (keyframesList.isNotEmpty) {
            final keyframes = keyframesList.first;

            // Конвертируем CSS анимацию в SMIL
            final smilAnims = CssToSmilConverter.convert(
              keyframes,
              cssAnimation,
              node,
              document,
            );
            animations.addAll(smilAnims);

            // Помечаем узел как имеющий анимации
            node.hasAnimations = true;
          }
        }
      }
    }

    // Рекурсивно обрабатываем детей
    for (final child in node.children) {
      _extractCssSelectorAnimations(child, document, rules, animations);
    }
  }

  /// Рекурсивно извлечь анимации из узла и его детей
  static void _extractAnimations(
    SvgNode node,
    SvgDocument document,
    List<SmilAnimation> animations,
  ) {
    // Ищем анимационные элементы среди детей
    for (final child in node.children) {
      if (_isAnimationElement(child.tagName)) {
        final animation = _parseAnimationElement(child, node, document);
        if (animation != null) {
          animations.add(animation);
          // Помечаем родительский узел как имеющий анимации
          node.hasAnimations = true;
        }
      }

      // Рекурсивно обрабатываем детей
      _extractAnimations(child, document, animations);
    }
  }

  /// Проверить, является ли тег анимационным элементом
  static bool _isAnimationElement(String tagName) {
    return tagName == 'animate' ||
        tagName == 'animateTransform' ||
        tagName == 'animateMotion' ||
        tagName == 'set' ||
        tagName == 'animateColor';
  }

  /// Распарсить анимационный элемент
  static SmilAnimation? _parseAnimationElement(
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
      Duration begin = Duration.zero;
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
        if (endConditions.length == 1 &&
            endConditions.first is OffsetCondition) {
          end = (endConditions.first as OffsetCondition).offset;
          endConditions = []; // Не нужны conditions для простого offset
        }
      }

      // Парсим repeatCount
      double repeatCount = 1.0;
      final repeatCountStr =
          animNode.getAttributeValue('repeatCount') as String?;
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
    } catch (e) {
      // Игнорируем невалидные анимации
      return null;
    }
  }

  /// Определить тип анимации по тегу
  static SmilAnimationType _parseAnimationType(String tagName) {
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
  static SvgAttributeType _inferAttributeType(
    String attributeName,
    SvgNode targetNode,
  ) {
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
  static Object? _parseValue(
    Object? value,
    SvgAttributeType type, {
    String? transformType,
  }) {
    if (value == null) return null;

    switch (type) {
      case SvgAttributeType.number:
      case SvgAttributeType.length:
        if (value is num) return value.toDouble();
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
  static List<Object> _parseValues(
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
  static List<double> _parseKeyTimes(String keyTimesStr) {
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
  static List<CubicBezier> _parseKeySplines(String keySplinesStr) {
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
  static Duration? _parseDuration(Object? value) {
    if (value == null) return null;

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
        } else if (parts.length == 3) {
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
  static SmilFillMode _parseFillMode(String? value) {
    final str = value?.toLowerCase().trim();
    if (str == 'freeze') {
      return SmilFillMode.freeze;
    }
    return SmilFillMode.remove;
  }

  /// Распарсить calc mode
  static SmilCalcMode _parseCalcMode(String? value) {
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
  static SmilAdditiveMode _parseAdditiveMode(String? value) {
    if (value?.toLowerCase().trim() == 'sum') {
      return SmilAdditiveMode.sum;
    }
    return SmilAdditiveMode.replace;
  }

  /// Распарсить <animateMotion> элемент
  static SmilAnimation? _parseAnimateMotion(
    SvgNode animNode,
    SvgNode targetNode,
    SvgDocument document,
  ) {
    try {
      // Парсим ID анимации (для syncbase timing)
      final id = animNode.id;

      // Получаем path из inline path или <mpath href="#...">.
      final pathData = _resolveAnimateMotionPathData(animNode, document);
      if (pathData == null || pathData.trim().isEmpty) {
        return null; // animateMotion без path невалидна
      }

      // Парсим тайминг
      final dur = _parseDuration(animNode.getAttributeValue('dur'));
      if (dur == null) {
        return null;
      }

      // Парсим begin/end как timing conditions (поддержка syncbase)
      Duration begin = Duration.zero;
      List<TimingCondition> beginConditions = [];
      final beginAttr = animNode.getAttributeValue('begin')?.toString();
      if (beginAttr != null) {
        beginConditions = TimingParser.parse(beginAttr);
        if (beginConditions.length == 1 &&
            beginConditions.first is OffsetCondition) {
          begin = (beginConditions.first as OffsetCondition).offset;
          beginConditions = [];
        }
      }

      Duration? end;
      List<TimingCondition> endConditions = [];
      final endAttr = animNode.getAttributeValue('end')?.toString();
      if (endAttr != null) {
        endConditions = TimingParser.parse(endAttr);
        if (endConditions.length == 1 &&
            endConditions.first is OffsetCondition) {
          end = (endConditions.first as OffsetCondition).offset;
          endConditions = [];
        }
      }

      // Парсим repeatCount
      double repeatCount = 1.0;
      final repeatCountStr =
          animNode.getAttributeValue('repeatCount') as String?;
      if (repeatCountStr != null) {
        if (repeatCountStr == 'indefinite') {
          repeatCount = double.infinity;
        } else {
          repeatCount = double.tryParse(repeatCountStr) ?? 1.0;
        }
      }

      final repeatDur = _parseDuration(animNode.getAttributeValue('repeatDur'));

      // Парсим режимы
      final fillMode = _parseFillMode(
        animNode.getAttributeValue('fill')?.toString(),
      );
      final calcMode = _parseCalcMode(
        animNode.getAttributeValue('calcMode')?.toString(),
      );

      // Парсим rotate атрибут
      final rotateStr = animNode.getAttributeValue('rotate')?.toString();
      String? rotateMode;
      if (rotateStr != null) {
        rotateMode = rotateStr.trim();
        // Может быть "auto", "auto-reverse", или угол в градусах (например "45")
      }

      // Парсим keyPoints
      List<double>? keyPoints;
      final keyPointsStr = animNode.getAttributeValue('keyPoints') as String?;
      if (keyPointsStr != null) {
        keyPoints = _parseKeyTimes(keyPointsStr); // Тот же формат что keyTimes
      }

      // Парсим keyTimes
      List<double>? keyTimes;
      final keyTimesStr = animNode.getAttributeValue('keyTimes') as String?;
      if (keyTimesStr != null) {
        keyTimes = _parseKeyTimes(keyTimesStr);
      }

      // Создаём SmilAnimation для animateMotion
      // Используем специальное значение для from/to - сам path
      return SmilAnimation(
        id: id,
        type: SmilAnimationType.animateMotion,
        targetNode: targetNode,
        attributeName: 'motion', // Специальное имя для motion
        attributeType: SvgAttributeType.transform,
        from: pathData, // Path data хранится в from
        to: rotateMode, // Rotate mode хранится в to
        values: keyPoints?.map((kp) => kp as Object).toList(),
        keyTimes: keyTimes,
        dur: dur,
        begin: begin,
        end: end,
        beginConditions: beginConditions,
        endConditions: endConditions,
        repeatCount: repeatCount,
        repeatDur: repeatDur,
        fillMode: fillMode,
        calcMode: calcMode,
        additive: SmilAdditiveMode.sum, // Motion всегда аддитивен
        accumulate: false,
      );
    } catch (e) {
      return null;
    }
  }

  static String? _resolveAnimateMotionPathData(
    SvgNode animNode,
    SvgDocument document,
  ) {
    final inlinePath = animNode.getAttributeValue('path')?.toString();
    if (inlinePath != null && inlinePath.trim().isNotEmpty) {
      return inlinePath.trim();
    }

    SvgNode? mpath;
    for (final child in animNode.children) {
      if (child.tagName == 'mpath') {
        mpath = child;
        break;
      }
    }
    if (mpath == null) {
      return null;
    }

    final hrefValue =
        mpath.getAttributeValue('href')?.toString() ??
        mpath.getAttributeValue('xlink:href')?.toString();
    final referencedId = _extractHrefId(hrefValue);
    if (referencedId == null) {
      return null;
    }

    final referencedNode = document.getElementById(referencedId);
    if (referencedNode == null || referencedNode.tagName != 'path') {
      return null;
    }

    final referencedPath = referencedNode.getAttributeValue('d')?.toString();
    if (referencedPath == null || referencedPath.trim().isEmpty) {
      return null;
    }
    return referencedPath.trim();
  }

  static String? _extractHrefId(String? href) {
    if (href == null) {
      return null;
    }
    final trimmed = href.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    if (trimmed.startsWith('#') && trimmed.length > 1) {
      return trimmed.substring(1);
    }

    final urlMatch = RegExp(r'url\(#([^)]+)\)').firstMatch(trimmed);
    if (urlMatch != null) {
      return urlMatch.group(1);
    }

    return null;
  }

  // Наборы известных атрибутов
  static const Set<String> _numberAttributes = {
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
    'offset',
  };

  static const Set<String> _colorAttributes = {
    'fill',
    'stroke',
    'stop-color',
    'flood-color',
    'lighting-color',
  };
}
