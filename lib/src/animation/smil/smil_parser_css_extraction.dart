part of 'smil_parser.dart';

/// Extract CSS animations from elements with style attributes
void _extractCssAnimations(
  SvgNode node,
  SvgDocument document,
  List<SmilAnimation> animations,
) {
  // Parse style attribute if present
  final styleAttr = node.getAttributeValue('style') as String?;
  if (styleAttr != null && styleAttr.isNotEmpty) {
    // Parse and store custom properties from this node's style
    node.parseAndSetCustomProperties(styleAttr);

    // Parse multiple animations (comma-separated)
    final cssAnimations = CssParser.parseMultipleAnimationsFromStyle(styleAttr);
    for (final cssAnimation in cssAnimations) {
      if (document.cssKeyframes != null) {
        // Find corresponding @keyframes
        final keyframesList = document.cssKeyframes!
            .where((kf) => kf.name == cssAnimation.name)
            .toList();
        if (keyframesList.isEmpty) continue;
        final keyframes = keyframesList.first;

        // Convert CSS animation to SMIL
        final smilAnims = CssToSmilConverter.convert(
          keyframes,
          cssAnimation,
          node,
          document,
        );
        animations.addAll(smilAnims);

        // Mark node as having animations
        node.hasAnimations = true;
      }
    }
  }

  // Recursively process children
  for (final child in node.children) {
    _extractCssAnimations(child, document, animations);
  }
}

/// Apply CSS rules from <style> to nodes by selectors
void _extractCssSelectorAnimations(
  SvgNode node,
  SvgDocument document,
  List<CssSelectorRule> rules,
  List<SmilAnimation> animations,
) {
  // Check each rule for match with current node
  for (final rule in rules) {
    final matches = _matchesCssRule(node, rule);

    if (matches) {
      // Apply custom properties from the rule to the node
      for (final entry in rule.declarations.entries) {
        if (isCustomProperty(entry.key)) {
          node.cssCustomProperties.set(entry.key, entry.value);
        }
      }

      if (rule.hasAnimation && document.cssKeyframes != null) {
        // Create fake style string for parsing animation properties
        final styleStr = rule.declarations.entries
            .map((e) => '${e.key}: ${e.value}')
            .join('; ');

        // Parse multiple animations from the style
        final cssAnimations = CssParser.parseMultipleAnimationsFromStyle(
          styleStr,
        );
        for (final cssAnimation in cssAnimations) {
          final keyframesList = document.cssKeyframes!
              .where((kf) => kf.name == cssAnimation.name)
              .toList();

          if (keyframesList.isNotEmpty) {
            final keyframes = keyframesList.first;

            // Convert CSS animation to SMIL
            final smilAnims = CssToSmilConverter.convert(
              keyframes,
              cssAnimation,
              node,
              document,
            );
            animations.addAll(smilAnims);

            // Mark node as having animations
            node.hasAnimations = true;
          }
        }
      }
    }
  }

  // Recursively process children
  for (final child in node.children) {
    _extractCssSelectorAnimations(child, document, rules, animations);
  }
}

/// Check if a node matches a CSS selector rule
bool _matchesCssRule(SvgNode node, CssSelectorRule rule) {
  final parsed = rule.parsedSelector;
  if (parsed == null) {
    // Fallback to simple matching for unparseable selectors
    return _simpleMatch(node, rule);
  }
  return _matchesSelector(node, parsed);
}

/// Simple matching for legacy/unparseable selectors
bool _simpleMatch(SvgNode node, CssSelectorRule rule) {
  if (rule.isIdSelector) {
    return node.id == rule.targetId;
  } else if (rule.isClassSelector) {
    return node.className != null &&
        node.className!.split(RegExp(r'\s+')).contains(rule.targetClass);
  } else {
    // Simple element selector
    return node.tagName == rule.selector;
  }
}

/// Match a node against a parsed CSS selector (with combinators)
bool _matchesSelector(SvgNode node, CssSelector selector) {
  // Start from the rightmost (subject) part and work backwards
  final parts = selector.parts;
  if (parts.isEmpty) return false;

  // Check if the node matches the subject (last part)
  if (!_matchesSimpleSelector(node, parts.last.selector)) {
    return false;
  }

  // If only one part, we're done
  if (parts.length == 1) return true;

  // Check ancestors/siblings for remaining parts
  return _matchCombinatorChain(node, parts, parts.length - 2);
}

/// Match the combinator chain from a given part index backwards
bool _matchCombinatorChain(
  SvgNode node,
  List<CssSelectorPart> parts,
  int partIndex,
) {
  if (partIndex < 0) return true;

  final part = parts[partIndex + 1]; // The part after the one we're matching
  final combinator = part.combinator;
  final selectorToMatch = parts[partIndex].selector;

  switch (combinator) {
    case CssCombinator.none:
      // Should not happen for partIndex > 0
      return true;

    case CssCombinator.descendant:
      // Any ancestor must match
      SvgNode? ancestor = node.parent;
      while (ancestor != null) {
        if (_matchesSimpleSelector(ancestor, selectorToMatch)) {
          if (partIndex == 0) return true;
          if (_matchCombinatorChain(ancestor, parts, partIndex - 1))
            return true;
        }
        ancestor = ancestor.parent;
      }
      return false;

    case CssCombinator.child:
      // Immediate parent must match
      final parent = node.parent;
      if (parent == null) return false;
      if (!_matchesSimpleSelector(parent, selectorToMatch)) return false;
      if (partIndex == 0) return true;
      return _matchCombinatorChain(parent, parts, partIndex - 1);

    case CssCombinator.adjacentSibling:
      // Immediate previous sibling must match
      final prevSibling = _getPreviousSibling(node);
      if (prevSibling == null) return false;
      if (!_matchesSimpleSelector(prevSibling, selectorToMatch)) return false;
      if (partIndex == 0) return true;
      return _matchCombinatorChain(prevSibling, parts, partIndex - 1);

    case CssCombinator.generalSibling:
      // Any previous sibling must match
      final siblings = _getPreviousSiblings(node);
      for (final sibling in siblings) {
        if (_matchesSimpleSelector(sibling, selectorToMatch)) {
          if (partIndex == 0) return true;
          if (_matchCombinatorChain(sibling, parts, partIndex - 1)) return true;
        }
      }
      return false;
  }
}

/// Match a node against a simple selector (tag, id, classes, attributes, pseudo-classes)
bool _matchesSimpleSelector(SvgNode node, CssSimpleSelector selector) {
  // Check tag name
  if (selector.tagName != null && selector.tagName != '*') {
    if (node.tagName != selector.tagName) return false;
  }

  // Check ID
  if (selector.id != null) {
    if (node.id != selector.id) return false;
  }

  // Check classes
  if (selector.classes.isNotEmpty) {
    final nodeClasses = node.className?.split(RegExp(r'\s+')) ?? [];
    for (final cls in selector.classes) {
      if (!nodeClasses.contains(cls)) return false;
    }
  }

  // Check attribute selectors
  for (final attrSel in selector.attributes) {
    final attrValue = node.getRawAttributeValue(attrSel.attribute);
    if (!attrSel.matches(attrValue)) return false;
  }

  // Check pseudo-classes
  for (final pseudo in selector.pseudoClasses) {
    if (!_matchesPseudoClass(pseudo, node)) return false;
  }

  // Check nth pseudo-classes
  for (final nthPseudo in selector.nthPseudoClasses) {
    if (!_matchesNthPseudoClass(nthPseudo, node)) return false;
  }

  // Check :not() selectors
  for (final notSelector in selector.notSelectors) {
    if (_matchesSimpleSelector(node, notSelector)) return false;
  }

  return true;
}

/// Check if a node matches a structural pseudo-class
bool _matchesPseudoClass(CssPseudoClass pseudo, SvgNode node) {
  switch (pseudo) {
    case CssPseudoClass.root:
      return node.parent == null || node.parent?.tagName == 'svg';
    case CssPseudoClass.empty:
      return node.children.isEmpty;
    case CssPseudoClass.firstChild:
      return _isFirstChild(node);
    case CssPseudoClass.lastChild:
      return _isLastChild(node);
    case CssPseudoClass.onlyChild:
      return _isOnlyChild(node);
    case CssPseudoClass.firstOfType:
      return _isFirstOfType(node);
    case CssPseudoClass.lastOfType:
      return _isLastOfType(node);
    case CssPseudoClass.onlyOfType:
      return _isOnlyOfType(node);
    case CssPseudoClass.hover:
    case CssPseudoClass.active:
    case CssPseudoClass.focus:
    case CssPseudoClass.visited:
    case CssPseudoClass.link:
      // Dynamic pseudo-classes are handled separately at runtime
      return true;
  }
}

/// Check if a node matches an nth pseudo-class
bool _matchesNthPseudoClass(CssNthPseudoClass nthPseudo, SvgNode node) {
  final parent = node.parent;
  if (parent == null) return false;

  final siblings = parent.children;
  final nodeIndex = siblings.indexOf(node);
  if (nodeIndex == -1) return false;

  switch (nthPseudo.type) {
    case CssNthType.nthChild:
      // 1-based index from start
      return nthPseudo.matches(nodeIndex + 1);

    case CssNthType.nthLastChild:
      // 1-based index from end
      return nthPseudo.matches(siblings.length - nodeIndex);

    case CssNthType.nthOfType:
      // Count only siblings of the same type, from start
      final tagName = node.tagName.toLowerCase();
      var typeIndex = 0;
      for (var i = 0; i <= nodeIndex; i++) {
        if (siblings[i].tagName.toLowerCase() == tagName) {
          typeIndex++;
        }
      }
      return nthPseudo.matches(typeIndex);

    case CssNthType.nthLastOfType:
      // Count only siblings of the same type, from end
      final tagName2 = node.tagName.toLowerCase();
      var typeIndexFromEnd = 0;
      for (var i = siblings.length - 1; i >= nodeIndex; i--) {
        if (siblings[i].tagName.toLowerCase() == tagName2) {
          typeIndexFromEnd++;
        }
      }
      return nthPseudo.matches(typeIndexFromEnd);
  }
}

bool _isFirstChild(SvgNode node) {
  final parent = node.parent;
  if (parent == null) return true;
  return parent.children.isNotEmpty && parent.children.first == node;
}

bool _isLastChild(SvgNode node) {
  final parent = node.parent;
  if (parent == null) return true;
  return parent.children.isNotEmpty && parent.children.last == node;
}

bool _isOnlyChild(SvgNode node) {
  final parent = node.parent;
  if (parent == null) return true;
  return parent.children.length == 1 && parent.children.first == node;
}

bool _isFirstOfType(SvgNode node) {
  final parent = node.parent;
  if (parent == null) return true;
  final tagName = node.tagName.toLowerCase();
  for (final sibling in parent.children) {
    if (sibling.tagName.toLowerCase() == tagName) {
      return sibling == node;
    }
  }
  return true;
}

bool _isLastOfType(SvgNode node) {
  final parent = node.parent;
  if (parent == null) return true;
  final tagName = node.tagName.toLowerCase();
  for (var i = parent.children.length - 1; i >= 0; i--) {
    final sibling = parent.children[i];
    if (sibling.tagName.toLowerCase() == tagName) {
      return sibling == node;
    }
  }
  return true;
}

bool _isOnlyOfType(SvgNode node) {
  final parent = node.parent;
  if (parent == null) return true;
  final tagName = node.tagName.toLowerCase();
  var count = 0;
  for (final sibling in parent.children) {
    if (sibling.tagName.toLowerCase() == tagName) {
      count++;
      if (count > 1) return false;
    }
  }
  return count == 1;
}

/// Get the immediate previous sibling of a node
SvgNode? _getPreviousSibling(SvgNode node) {
  final parent = node.parent;
  if (parent == null) return null;

  final siblings = parent.children;
  final index = siblings.indexOf(node);
  if (index <= 0) return null;

  return siblings[index - 1];
}

/// Get all previous siblings of a node (in reverse order)
List<SvgNode> _getPreviousSiblings(SvgNode node) {
  final parent = node.parent;
  if (parent == null) return [];

  final siblings = parent.children;
  final index = siblings.indexOf(node);
  if (index <= 0) return [];

  return siblings.sublist(0, index).reversed.toList();
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
