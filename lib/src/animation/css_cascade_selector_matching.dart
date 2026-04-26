/// Selector matching logic for CSS cascade.
part of 'css_cascade.dart';

/// Mixin providing selector matching functionality for CssCascadeResolver.
mixin _SelectorMatchingMixin {
  /// CSS rules from <style> elements (must be provided by implementing class).
  List<CssSelectorRule> get cssRules;

  /// ID of the shadow boundary root (must be provided by implementing class).
  String? get shadowBoundaryId;

  /// Rule cache (must be provided by implementing class).
  Map<String, List<_MatchedRule>> get _ruleCache;

  /// Pseudo-class state (must be provided by implementing class).
  SvgPseudoClassState? get pseudoClassState;

  /// Gets all matching CSS rules for a node.
  /// For shadow DOM contexts (use/symbol), combinator selectors
  /// should not pierce the shadow boundary.
  List<_MatchedRule> _getMatchingRules(SvgNode node) {
    // Build cache key from node's identifying attributes and pseudo-state
    final id = node.getAttributeValue('id')?.toString();
    final className = node.getAttributeValue('class')?.toString();
    final tagName = node.tagName;

    // Include pseudo-class state in cache key
    final pseudoKey = _buildPseudoStateKey(id);
    final cacheKey = '$tagName|${id ?? ''}|${className ?? ''}|$pseudoKey';

    if (_ruleCache.containsKey(cacheKey)) {
      return _ruleCache[cacheKey]!;
    }

    final matched = <_MatchedRule>[];
    final nodeClasses = (className ?? '')
        .split(RegExp(r'\s+'))
        .where((c) => c.isNotEmpty)
        .toSet();

    for (final rule in cssRules) {
      if (_selectorMatchesWithPseudo(rule, node, tagName, id, nodeClasses)) {
        matched.add(
          _MatchedRule(
            rule: rule,
            specificity: CssSpecificityCalculator.calculate(rule.selector),
          ),
        );
      }
    }

    _ruleCache[cacheKey] = matched;
    return matched;
  }

  /// Build a key representing the current pseudo-class state for an element.
  String _buildPseudoStateKey(String? id) {
    if (id == null || pseudoClassState == null) return '';
    final parts = <String>[];
    if (pseudoClassState!.isHovered(id)) parts.add('h');
    if (pseudoClassState!.isActive(id)) parts.add('a');
    if (pseudoClassState!.isFocused(id)) parts.add('f');
    return parts.join();
  }

  /// Checks if a selector matches a node, including pseudo-class state.
  /// Handles shadow DOM boundaries for combinator selectors.
  bool _selectorMatchesWithPseudo(
    CssSelectorRule rule,
    SvgNode node,
    String tagName,
    String? id,
    Set<String> classes,
  ) {
    final parsed = rule.parsedSelector;
    if (parsed == null) {
      // Fall back to basic matching
      return _selectorMatches(rule.selector, tagName, id, classes);
    }

    // For simple selectors (no combinators), just match the subject
    if (parsed.isSimple) {
      return _matchSimpleSelector(
        parsed.subject.selector,
        node,
        tagName,
        id,
        classes,
      );
    }

    // For complex selectors with combinators, we need to traverse the DOM
    // and respect shadow DOM boundaries (use/symbol)
    return _matchComplexSelector(parsed, node, tagName, id, classes);
  }

  /// Matches a complex selector with combinators against a node.
  /// Respects shadow DOM boundaries per SVG spec - combinators
  /// should not pierce through use/symbol boundaries.
  bool _matchComplexSelector(
    CssSelector selector,
    SvgNode node,
    String tagName,
    String? id,
    Set<String> classes,
  ) {
    // First, match the subject (rightmost) part
    if (!_matchSimpleSelector(
      selector.subject.selector,
      node,
      tagName,
      id,
      classes,
    )) {
      return false;
    }

    // If this is a simple selector (single part), we're done
    if (selector.parts.length == 1) {
      return true;
    }

    // For complex selectors, traverse the DOM matching each part
    // Start from the rightmost (subject) and work left
    var currentNode = node;
    for (int i = selector.parts.length - 2; i >= 0; i--) {
      final part = selector.parts[i];
      final nextPart = selector.parts[i + 1];
      final combinator = nextPart.combinator;

      switch (combinator) {
        case CssCombinator.descendant:
          // Find any ancestor matching part
          final matchingAncestor = _findMatchingAncestor(
            currentNode,
            part.selector,
          );
          if (matchingAncestor == null) return false;
          currentNode = matchingAncestor;
        case CssCombinator.child:
          // Check direct parent
          final parent = currentNode.parent;
          if (parent == null) return false;
          if (!_matchNodeSelector(parent, part.selector)) return false;
          currentNode = parent;
        case CssCombinator.adjacentSibling:
          // Check immediately preceding sibling
          final sibling = _getPreviousSibling(currentNode);
          if (sibling == null) return false;
          if (!_matchNodeSelector(sibling, part.selector)) return false;
          currentNode = sibling;
        case CssCombinator.generalSibling:
          // Check any preceding sibling
          final matchingSibling = _findMatchingPrecedingSibling(
            currentNode,
            part.selector,
          );
          if (matchingSibling == null) return false;
          currentNode = matchingSibling;
        case CssCombinator.none:
          // Should not happen for index > 0
          return false;
      }
    }

    return true;
  }

  /// Finds an ancestor matching the selector, respecting shadow boundaries.
  /// When shadowBoundaryId is set, stops at the element with that ID.
  ///
  /// Per SVG 2 spec:
  /// - CSS combinator selectors (descendant, child, sibling) STOP at shadow boundary
  /// - Simple selectors (ID, class) can still match elements within shadow tree
  /// - The shadow boundary is formed by `<use>` and `<symbol>` elements
  SvgNode? _findMatchingAncestor(SvgNode node, CssSimpleSelector selector) {
    var current = node.parent;
    int ancestorDepth = 0;
    const maxAncestorDepth = 100; // Prevent infinite loops

    while (current != null && ancestorDepth < maxAncestorDepth) {
      ancestorDepth++;

      // Check for shadow DOM boundary - stop at use/symbol or explicit boundary
      // Per SVG spec, combinator selectors stop at shadow boundary
      if (_isShadowBoundary(current)) {
        return null;
      }
      // Also check for explicit shadow boundary ID
      if (shadowBoundaryId != null && current.id == shadowBoundaryId) {
        return null;
      }
      if (_matchNodeSelector(current, selector)) {
        return current;
      }
      current = current.parent;
    }
    return null;
  }

  /// Gets the immediately preceding sibling of a node.
  SvgNode? _getPreviousSibling(SvgNode node) {
    final parent = node.parent;
    if (parent == null) return null;
    final children = parent.children;
    final index = children.indexOf(node);
    if (index <= 0) return null;
    return children[index - 1];
  }

  /// Finds a preceding sibling matching the selector.
  SvgNode? _findMatchingPrecedingSibling(
    SvgNode node,
    CssSimpleSelector selector,
  ) {
    final parent = node.parent;
    if (parent == null) return null;
    final children = parent.children;
    final index = children.indexOf(node);
    for (int i = index - 1; i >= 0; i--) {
      if (_matchNodeSelector(children[i], selector)) {
        return children[i];
      }
    }
    return null;
  }

  /// Checks if a node represents a shadow DOM boundary.
  /// Use and symbol elements create shadow-like scopes.
  bool _isShadowBoundary(SvgNode node) {
    final tag = node.tagName.toLowerCase();
    return tag == 'use' || tag == 'symbol';
  }

  /// Matches a node against a simple selector.
  bool _matchNodeSelector(SvgNode node, CssSimpleSelector selector) {
    final tagName = node.tagName;
    final id = node.getAttributeValue('id')?.toString();
    final className = node.getAttributeValue('class')?.toString();
    final classes = (className ?? '')
        .split(RegExp(r'\s+'))
        .where((c) => c.isNotEmpty)
        .toSet();
    return _matchSimpleSelector(selector, node, tagName, id, classes);
  }

  /// Match a simple selector against a node, including pseudo-classes.
  bool _matchSimpleSelector(
    CssSimpleSelector selector,
    SvgNode node,
    String tagName,
    String? id,
    Set<String> classes,
  ) {
    // Check tag name
    if (selector.tagName != null && selector.tagName != '*') {
      if (selector.tagName!.toLowerCase() != tagName.toLowerCase()) {
        return false;
      }
    }

    // Check ID
    if (selector.id != null && selector.id != id) {
      return false;
    }

    // Check classes
    for (final requiredClass in selector.classes) {
      if (!classes.contains(requiredClass)) {
        return false;
      }
    }

    // Check attributes
    for (final attrSel in selector.attributes) {
      final attrValue = node.getRawAttributeValue(attrSel.attribute);
      if (!attrSel.matches(attrValue)) {
        return false;
      }
    }

    // Check pseudo-classes
    for (final pseudo in selector.pseudoClasses) {
      if (!_matchPseudoClass(pseudo, node, id)) {
        return false;
      }
    }

    // Check nth pseudo-classes
    for (final nthPseudo in selector.nthPseudoClasses) {
      if (!_matchNthPseudoClass(nthPseudo, node)) {
        return false;
      }
    }

    // Check :not() selectors
    for (final notSelector in selector.notSelectors) {
      // If the not selector matches, the overall selector doesn't match
      if (_matchSimpleSelector(notSelector, node, tagName, id, classes)) {
        return false;
      }
    }

    // Must have at least one positive constraint to match
    return selector.tagName != null ||
        selector.id != null ||
        selector.classes.isNotEmpty ||
        selector.attributes.isNotEmpty ||
        selector.pseudoClasses.isNotEmpty ||
        selector.nthPseudoClasses.isNotEmpty ||
        selector.notSelectors.isNotEmpty;
  }

  /// Check if a nth pseudo-class matches an element.
  bool _matchNthPseudoClass(CssNthPseudoClass nthPseudo, SvgNode node) {
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

  /// Check if a pseudo-class matches an element's current state.
  bool _matchPseudoClass(CssPseudoClass pseudo, SvgNode node, String? id) {
    // Structural pseudo-classes don't need ID or state tracking
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
        if (pseudoClassState == null || id == null) return false;
        return pseudoClassState!.isHovered(id);
      case CssPseudoClass.active:
        if (pseudoClassState == null || id == null) return false;
        return pseudoClassState!.isActive(id);
      case CssPseudoClass.focus:
        if (pseudoClassState == null || id == null) return false;
        return pseudoClassState!.isFocused(id);
      case CssPseudoClass.visited:
      case CssPseudoClass.link:
        // Not typically applicable to SVG elements
        return false;
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

  /// Checks if a selector matches a node.
  bool _selectorMatches(
    String selector,
    String tagName,
    String? id,
    Set<String> classes,
  ) {
    // Handle compound selectors (e.g., "rect.myClass#myId")
    final sel = selector.trim();

    // Check ID selector
    final idMatch = RegExp(r'#([\w-]+)').firstMatch(sel);
    if (idMatch != null && idMatch.group(1) != id) {
      return false;
    }

    // Check class selectors
    final classMatches = RegExp(r'\.([\w-]+)').allMatches(sel);
    for (final match in classMatches) {
      final requiredClass = match.group(1)!;
      if (!classes.contains(requiredClass)) {
        return false;
      }
    }

    // Check element type selector
    final elementMatch = RegExp(r'^([a-zA-Z][\w-]*)').firstMatch(sel);
    if (elementMatch != null) {
      final requiredElement = elementMatch.group(1)!;
      // Skip if starts with special character
      if (!sel.startsWith('.') &&
          !sel.startsWith('#') &&
          !sel.startsWith(':')) {
        if (requiredElement.toLowerCase() != tagName.toLowerCase()) {
          return false;
        }
      }
    }

    // If we have at least one constraint and didn't fail, it's a match
    // Also handle universal selector '*' and selectors that only have class/id
    return idMatch != null ||
        classMatches.isNotEmpty ||
        (elementMatch != null &&
            !sel.startsWith('.') &&
            !sel.startsWith('#')) ||
        sel == '*';
  }
}
