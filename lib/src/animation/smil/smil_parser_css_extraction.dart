part of 'smil_parser.dart';

/// Извлечь CSS анимации из элементов с style атрибутами
void _extractCssAnimations(
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
      if (keyframesList.isEmpty) {
        return;
      }
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
void _extractCssSelectorAnimations(
  SvgNode node,
  SvgDocument document,
  List<CssSelectorRule> rules,
  List<SmilAnimation> animations,
) {
  // Проверяем каждое правило на совпадение с текущим узлом
  for (final rule in rules) {
    var matches = false;

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
void _extractAnimations(
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
bool _isAnimationElement(String tagName) {
  return tagName == 'animate' ||
      tagName == 'animateTransform' ||
      tagName == 'animateMotion' ||
      tagName == 'set' ||
      tagName == 'animateColor';
}
