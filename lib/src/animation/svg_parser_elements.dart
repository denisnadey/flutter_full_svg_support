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

  // Parse attributes
  for (final attr in element.attributes) {
    final attrName = attr.name.local;
    final attrValue = attr.value;

    // Skip special attributes that have already been handled
    if (attrName == 'id' ||
        attrName == 'class' ||
        attrName == 'aria-label' ||
        attrName == 'aria-describedby' ||
        attrName == 'role') {
      continue;
    }

    // Determine the attribute type and parse the value
    // For animation elements, fill is the fill mode, not a color
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

  final isTextContainer =
      tagName == 'text' || tagName == 'tspan' || tagName == 'textPath';
  final hasElementChildren = element.childElements.isNotEmpty;

  if (isTextContainer && hasElementChildren) {
    _parseTextContainerChildren(element, node);
  } else {
    // Preserve direct text content for simple text nodes.
    if (isTextContainer) {
      final directText = _extractDirectText(element);
      if (directText != null) {
        node.setAttribute('__text', directText, type: SvgAttributeType.string);
      }
    }

    // Recursively parse child elements
    for (final child in element.childElements) {
      _parseAndAddChildElement(node, child);
    }
  }

  return node;
}

void _parseTextContainerChildren(XmlElement element, SvgNode node) {
  final children = element.children.toList(growable: false);
  var hasSeenStructuredChild = false;
  var hasLeadingDirectText = false;

  for (var index = 0; index < children.length; index++) {
    final child = children[index];
    if (child is XmlElement) {
      final added = _parseAndAddChildElement(node, child);
      if (added) {
        hasSeenStructuredChild = true;
      }
      continue;
    }

    if (child is! XmlText && child is! XmlCDATA) {
      continue;
    }

    final rawSegment = child.value ?? '';
    if (rawSegment.isEmpty) {
      continue;
    }

    final hasFutureStructuredChild = _hasRenderableElementChildAfter(
      children,
      index,
    );
    final normalizedSegment = _normalizeMixedTextSegment(
      rawSegment,
      trimLeft: !hasSeenStructuredChild,
      trimRight: !hasFutureStructuredChild,
    );
    if (normalizedSegment == null) {
      continue;
    }

    if (!hasSeenStructuredChild && !hasLeadingDirectText) {
      node.setAttribute(
        '__text',
        normalizedSegment,
        type: SvgAttributeType.string,
      );
      hasLeadingDirectText = true;
      continue;
    }

    final syntheticTextNode = SvgNode(tagName: 'tspan');
    syntheticTextNode.setAttribute(
      '__text',
      normalizedSegment,
      type: SvgAttributeType.string,
    );
    node.addChild(syntheticTextNode);
    hasSeenStructuredChild = true;
  }
}

bool _parseAndAddChildElement(SvgNode node, XmlElement child) {
  final childTagName = child.name.local;

  // Skip <style> elements - they are handled separately
  if (childTagName == 'style') {
    return false; // CSS parsing will happen later
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
    return true;
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
    return true;
  }

  final childNode = _parseElement(child);
  node.addChild(childNode);
  return true;
}

bool _hasRenderableElementChildAfter(List<XmlNode> children, int index) {
  for (var i = index + 1; i < children.length; i++) {
    final child = children[i];
    if (child is XmlElement && child.name.local != 'style') {
      return true;
    }
  }
  return false;
}

String? _normalizeMixedTextSegment(
  String raw, {
  required bool trimLeft,
  required bool trimRight,
}) {
  final collapsed = raw.replaceAll(RegExp(r'\s+'), ' ');
  var normalized = collapsed;
  if (trimLeft) {
    normalized = normalized.replaceFirst(RegExp(r'^ +'), '');
  }
  if (trimRight) {
    normalized = normalized.replaceFirst(RegExp(r' +$'), '');
  }
  if (normalized.isEmpty) {
    return null;
  }
  return normalized;
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

/// Determines the attribute type by its name
SvgAttributeType _inferAttributeType(
  String attributeName, [
  bool isAnimationElement = false,
]) {
  // For animation elements, fill/calcMode/etc are strings, not colors
  if (isAnimationElement &&
      (attributeName == 'fill' ||
          attributeName == 'calcMode' ||
          attributeName == 'additive' ||
          attributeName == 'accumulate')) {
    return SvgAttributeType.string;
  }

  // Numeric attributes
  if (_numericAttributes.contains(attributeName)) {
    return SvgAttributeType.number;
  }

  // Color attributes
  if (_colorAttributes.contains(attributeName)) {
    return SvgAttributeType.color;
  }

  // Transformations
  if (attributeName == 'transform') {
    return SvgAttributeType.transform;
  }

  // Path data
  if (attributeName == 'd') {
    return SvgAttributeType.path;
  }

  // Points for polygon/polyline
  if (attributeName == 'points') {
    return SvgAttributeType.points;
  }

  // URL references
  if (_urlAttributes.contains(attributeName)) {
    return SvgAttributeType.url;
  }

  // Default — string
  return SvgAttributeType.string;
}

/// Parses an attribute value into the corresponding type
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
      // For now return as a string; parsing will happen later
      return value;
  }
}

/// Checks whether an element is an animation element
bool _isAnimationElement(String tagName) {
  return tagName == 'animate' ||
      tagName == 'animateTransform' ||
      tagName == 'animateMotion' ||
      tagName == 'set' ||
      tagName == 'animateColor';
}
