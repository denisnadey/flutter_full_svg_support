part of 'svg_parser.dart';

/// Parses XML element into SvgNode
SvgNode _parseElement(XmlElement element) {
  final tagName = element.name.local;
  final id = element.getAttribute('id');
  final className = element.getAttribute('class');

  final node = SvgNode(tagName: tagName, id: id, className: className);

  // Parse ARIA attributes for accessibility
  node.ariaLabel = element.getAttribute('aria-label');
  node.ariaDescribedby = element.getAttribute('aria-describedby');
  node.ariaRole = element.getAttribute('role');

  // Парсим атрибуты
  for (final attr in element.attributes) {
    final attrName = attr.name.local;
    final attrValue = attr.value;

    // Пропускаем специальные атрибуты, которые уже обработаны
    if (attrName == 'id' ||
        attrName == 'class' ||
        attrName == 'aria-label' ||
        attrName == 'aria-describedby' ||
        attrName == 'role') {
      continue;
    }

    // Определяем тип атрибута и парсим значение
    // Для анимационных элементов fill - это режим заполнения, не цвет
    final isAnimationElement = _isAnimationElement(tagName);
    final attributeType = _inferAttributeType(attrName, isAnimationElement);
    final parsedValue = _parseAttributeValue(attrValue, attributeType);

    node.setAttribute(
      attrName,
      parsedValue,
      type: attributeType,
      rawValue: attrValue,
    );
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
    final childTagName = child.name.local;

    // Пропускаем <style> элементы - они обрабатываются отдельно
    if (childTagName == 'style') {
      continue; // CSS parsing будет позже
    }

    // Extract <title> text content and store on parent (use first only)
    if (childTagName == 'title') {
      if (node.titleText == null) {
        final titleText = _extractElementText(child);
        if (titleText != null && titleText.isNotEmpty) {
          node.titleText = titleText;
        }
      }
      // Still add title as child node for DOM completeness
      final childNode = _parseElement(child);
      node.addChild(childNode);
      continue;
    }

    // Extract <desc> text content and store on parent (use first only)
    if (childTagName == 'desc') {
      if (node.descText == null) {
        final descText = _extractElementText(child);
        if (descText != null && descText.isNotEmpty) {
          node.descText = descText;
        }
      }
      // Still add desc as child node for DOM completeness
      final childNode = _parseElement(child);
      node.addChild(childNode);
      continue;
    }

    final childNode = _parseElement(child);
    node.addChild(childNode);
  }

  return node;
}

/// Extracts all text content from an element (for title/desc)
String? _extractElementText(XmlElement element) {
  final buffer = StringBuffer();
  _collectTextContent(element, buffer);
  final text = buffer.toString().trim();
  if (text.isEmpty) return null;
  // Normalize whitespace
  return text.replaceAll(RegExp(r'\s+'), ' ');
}

/// Recursively collects text content from element and its children
void _collectTextContent(XmlElement element, StringBuffer buffer) {
  for (final child in element.children) {
    if (child is XmlText) {
      buffer.write(child.value);
    } else if (child is XmlCDATA) {
      buffer.write(child.value);
    } else if (child is XmlElement) {
      _collectTextContent(child, buffer);
    }
  }
}

String? _extractDirectText(XmlElement element) {
  final raw = element.children
      .where((n) => n is XmlText || n is XmlCDATA)
      .map((n) => n.value ?? '')
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
