part of 'svg_parser.dart';

/// Парсит XML элемент в SvgNode
SvgNode _parseElement(XmlElement element) {
  final tagName = element.name.local;
  final id = element.getAttribute('id');
  final className = element.getAttribute('class');

  final node = SvgNode(tagName: tagName, id: id, className: className);

  // Парсим атрибуты
  for (final attr in element.attributes) {
    final attrName = attr.name.local;
    final attrValue = attr.value;

    // Пропускаем специальные атрибуты, которые уже обработаны
    if (attrName == 'id' || attrName == 'class') {
      continue;
    }

    // Определяем тип атрибута и парсим значение
    // Для анимационных элементов fill - это режим заполнения, не цвет
    final isAnimationElement = _isAnimationElement(tagName);
    final attributeType = _inferAttributeType(attrName, isAnimationElement);
    final parsedValue = _parseAttributeValue(attrValue, attributeType);

    node.setAttribute(attrName, parsedValue, type: attributeType, rawValue: attrValue);
  }

  // Сохраняем прямой текстовый контент для текстовых узлов.
  if (tagName == 'text' || tagName == 'tspan' || tagName == 'textPath') {
    final directText = _extractDirectText(element);
    if (directText != null) {
      node.setAttribute('__text', directText, type: SvgAttributeType.string);
    }
  }

  // Рекурсивно парсим дочерние элементы
  for (final child in element.childElements) {
    // Пропускаем <style> элементы - они обрабатываются отдельно
    if (child.name.local == 'style') {
      continue; // CSS parsing будет позже
    }
    final childNode = _parseElement(child);
    node.addChild(childNode);
  }

  return node;
}

String? _extractDirectText(XmlElement element) {
  final raw = element.children
      .whereType<XmlText>()
      .map((n) => n.value)
      .join();
  if (raw.trim().isEmpty) {
    return null;
  }
  final normalized = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
  return normalized.isEmpty ? null : normalized;
}

/// Определяет тип атрибута по его имени
SvgAttributeType _inferAttributeType(
  String attributeName, [
  bool isAnimationElement = false,
]) {
  // Для анимационных элементов fill/calcMode/etc - это строки, не цвета
  if (isAnimationElement &&
      (attributeName == 'fill' ||
          attributeName == 'calcMode' ||
          attributeName == 'additive' ||
          attributeName == 'accumulate')) {
    return SvgAttributeType.string;
  }

  // Числовые атрибуты
  if (_numericAttributes.contains(attributeName)) {
    return SvgAttributeType.number;
  }

  // Цветовые атрибуты
  if (_colorAttributes.contains(attributeName)) {
    return SvgAttributeType.color;
  }

  // Трансформации
  if (attributeName == 'transform') {
    return SvgAttributeType.transform;
  }

  // Path данные
  if (attributeName == 'd') {
    return SvgAttributeType.path;
  }

  // Points для polygon/polyline
  if (attributeName == 'points') {
    return SvgAttributeType.points;
  }

  // URL ссылки
  if (_urlAttributes.contains(attributeName)) {
    return SvgAttributeType.url;
  }

  // По умолчанию — строка
  return SvgAttributeType.string;
}

/// Парсит значение атрибута в соответствующий тип
Object _parseAttributeValue(String value, SvgAttributeType type) {
  switch (type) {
    case SvgAttributeType.number:
      return _parseNumber(value);
    case SvgAttributeType.color:
      return _parseColor(value);
    case SvgAttributeType.transform:
    case SvgAttributeType.path:
    case SvgAttributeType.points:
    case SvgAttributeType.string:
    case SvgAttributeType.url:
    case SvgAttributeType.list:
    case SvgAttributeType.length:
      // Пока возвращаем как строку, парсинг будет позже
      return value;
  }
}

/// Проверяет, является ли элемент анимационным
bool _isAnimationElement(String tagName) {
  return tagName == 'animate' ||
      tagName == 'animateTransform' ||
      tagName == 'animateMotion' ||
      tagName == 'set' ||
      tagName == 'animateColor';
}
