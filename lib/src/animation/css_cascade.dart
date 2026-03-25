/// CSS Cascade and Specificity Resolution for SVG.
///
/// Implements proper CSS cascade rules per the CSS Cascading specification:
/// - Specificity calculation for selectors
/// - Cascade order (later declarations win when specificity is equal)
/// - !important handling
/// - Inheritance for inheritable properties
library;

import 'css_animations.dart';
import 'svg_dom.dart';

/// CSS Specificity value represented as (a, b, c, d) where:
/// - a: inline styles (1 if inline, 0 otherwise)
/// - b: ID selectors count
/// - c: class, attribute, pseudo-class selectors count
/// - d: element type and pseudo-element selectors count
class CssSpecificity implements Comparable<CssSpecificity> {
  /// Creates a CSS specificity value.
  const CssSpecificity(this.a, this.b, this.c, this.d);

  /// Inline style specificity - highest priority.
  static const CssSpecificity inline = CssSpecificity(1, 0, 0, 0);

  /// Zero specificity - for user agent defaults.
  static const CssSpecificity zero = CssSpecificity(0, 0, 0, 0);

  /// Inline style indicator (1 = inline style).
  final int a;

  /// ID selector count.
  final int b;

  /// Class, attribute, pseudo-class selector count.
  final int c;

  /// Element type and pseudo-element selector count.
  final int d;

  @override
  int compareTo(CssSpecificity other) {
    if (a != other.a) return a.compareTo(other.a);
    if (b != other.b) return b.compareTo(other.b);
    if (c != other.c) return c.compareTo(other.c);
    return d.compareTo(other.d);
  }

  bool operator <(CssSpecificity other) => compareTo(other) < 0;
  bool operator <=(CssSpecificity other) => compareTo(other) <= 0;
  bool operator >(CssSpecificity other) => compareTo(other) > 0;
  bool operator >=(CssSpecificity other) => compareTo(other) >= 0;

  @override
  bool operator ==(Object other) =>
      other is CssSpecificity &&
      a == other.a &&
      b == other.b &&
      c == other.c &&
      d == other.d;

  @override
  int get hashCode => Object.hash(a, b, c, d);

  @override
  String toString() => 'CssSpecificity($a, $b, $c, $d)';
}

/// A resolved CSS property value with its specificity and source order.
class CssResolvedValue {
  const CssResolvedValue({
    required this.value,
    required this.specificity,
    required this.order,
    this.isImportant = false,
  });

  /// The property value.
  final String value;

  /// Specificity of the selector that provided this value.
  final CssSpecificity specificity;

  /// Source order (higher = later in stylesheet).
  final int order;

  /// Whether this value has !important.
  final bool isImportant;

  /// Compares two values for cascade order.
  /// Returns positive if this value wins, negative if other wins.
  int compareCascade(CssResolvedValue other) {
    // !important always wins over non-important
    if (isImportant != other.isImportant) {
      return isImportant ? 1 : -1;
    }
    // Higher specificity wins
    final specCompare = specificity.compareTo(other.specificity);
    if (specCompare != 0) return specCompare;
    // Later source order wins
    return order.compareTo(other.order);
  }

  /// Returns the winning value between this and other.
  CssResolvedValue winner(CssResolvedValue other) {
    return compareCascade(other) >= 0 ? this : other;
  }
}

/// Calculates CSS specificity from a selector string.
class CssSpecificityCalculator {
  /// Calculates specificity for a CSS selector.
  ///
  /// Supports:
  /// - ID selectors: #myId -> (0, 1, 0, 0)
  /// - Class selectors: .myClass -> (0, 0, 1, 0)
  /// - Attribute selectors: [attr], [attr=value] -> (0, 0, 1, 0)
  /// - Pseudo-classes: :hover, :first-child -> (0, 0, 1, 0)
  /// - Element types: rect, circle -> (0, 0, 0, 1)
  /// - Pseudo-elements: ::before, ::after -> (0, 0, 0, 1)
  /// - Universal selector: * -> (0, 0, 0, 0)
  /// - Compound selectors: #id.class -> (0, 1, 1, 0)
  /// - Combinator selectors: div > span, div span -> sum of parts
  static CssSpecificity calculate(String selector) {
    int idCount = 0;
    int classCount = 0;
    int elementCount = 0;

    // Normalize and clean selector
    var sel = selector.trim();
    if (sel.isEmpty) return CssSpecificity.zero;

    // Split by combinators (space, >, +, ~) while preserving parts
    final parts = _splitByCombinators(sel);

    for (final part in parts) {
      if (part.isEmpty || part == '*') continue;

      // Count ID selectors
      idCount += '#'.allMatches(part).length;

      // Count class selectors
      classCount += '.'.allMatches(part).length;

      // Count attribute selectors [...]
      classCount += RegExp(r'\[[^\]]+\]').allMatches(part).length;

      // Count pseudo-classes (single colon, but not pseudo-elements)
      // Must use negative lookbehind to exclude double colons
      final pseudoClassMatches = RegExp(r'(?<!:):[a-zA-Z-]+').allMatches(part);
      classCount += pseudoClassMatches.length;

      // Count pseudo-elements (double colon)
      final pseudoElementMatches = RegExp(r'::[a-zA-Z-]+').allMatches(part);
      elementCount += pseudoElementMatches.length;

      // Count element type selectors
      // Extract element name at the start (before any #, ., :, [)
      final elementMatch = RegExp(r'^([a-zA-Z][a-zA-Z0-9-]*)').firstMatch(part);
      if (elementMatch != null) {
        final elem = elementMatch.group(1)!;
        if (elem != '*') {
          elementCount++;
        }
      }
    }

    return CssSpecificity(0, idCount, classCount, elementCount);
  }

  /// Splits a selector by combinators while preserving each simple selector.
  static List<String> _splitByCombinators(String selector) {
    // Split by whitespace, >, +, ~ (CSS combinators)
    return selector
        .split(RegExp(r'\s*[>\+~\s]\s*'))
        .where((s) => s.isNotEmpty)
        .toList();
  }
}

/// CSS properties that are inherited by default per CSS specification.
const Set<String> cssInheritableProperties = {
  // Color properties
  'color',

  // Font properties
  'font',
  'font-family',
  'font-size',
  'font-size-adjust',
  'font-stretch',
  'font-style',
  'font-variant',
  'font-variant-caps',
  'font-variant-ligatures',
  'font-variant-numeric',
  'font-weight',
  'font-feature-settings',
  'font-variation-settings',

  // Text properties
  'letter-spacing',
  'line-height',
  'text-align',
  'text-indent',
  'text-transform',
  'white-space',
  'word-spacing',
  'word-break',
  'word-wrap',
  'overflow-wrap',
  'direction',
  'writing-mode',
  'text-orientation',
  'dominant-baseline',
  'alignment-baseline',
  'baseline-shift',

  // SVG specific inheritable properties
  'fill',
  'fill-opacity',
  'fill-rule',
  'stroke',
  'stroke-opacity',
  'stroke-width',
  'stroke-linecap',
  'stroke-linejoin',
  'stroke-miterlimit',
  'stroke-dasharray',
  'stroke-dashoffset',
  'marker',
  'marker-start',
  'marker-mid',
  'marker-end',
  'paint-order',
  'color-interpolation',
  'color-interpolation-filters',
  'color-rendering',
  'shape-rendering',
  'text-rendering',
  'image-rendering',

  // Visibility
  'visibility',
  'pointer-events',
  'cursor',

  // Text decoration (partially inheritable)
  'text-decoration',
  'text-decoration-line',
  'text-decoration-style',
  'text-decoration-color',

  // Text emphasis
  'text-emphasis',
  'text-emphasis-color',
  'text-emphasis-position',
  'text-emphasis-style',

  // Ruby
  'ruby-align',
  'ruby-position',

  // List styles
  'list-style',
  'list-style-image',
  'list-style-position',
  'list-style-type',

  // Misc
  'quotes',
  'tab-size',
  'hyphens',
  'orphans',
  'widows',
};

/// Resolves CSS styles for an SVG node using proper cascade rules.
class CssCascadeResolver {
  CssCascadeResolver({required this.cssRules}) : _ruleCache = {};

  /// All CSS rules from <style> elements.
  final List<CssSelectorRule> cssRules;

  /// Cache of matching rules per node ID/class combination.
  final Map<String, List<_MatchedRule>> _ruleCache;

  /// Pseudo-class state for dynamic matching.
  SvgPseudoClassState? pseudoClassState;

  /// Clear the rule cache (call when pseudo-class state changes).
  void clearCache() {
    _ruleCache.clear();
  }

  /// Resolves a CSS property value for a node with full cascade support.
  ///
  /// Resolution order (highest to lowest priority):
  /// 1. Inline style attribute (with !important check)
  /// 2. CSS rules from <style> (by specificity, then source order)
  /// 3. Presentation attributes (like fill="red")
  /// 4. Inherited value from parent (for inheritable properties only)
  String? resolveProperty(
    SvgNode node,
    String property, {
    bool checkInheritance = true,
  }) {
    final normalizedProperty = property.trim().toLowerCase();

    // Build list of candidate values with their specificity
    final candidates = <CssResolvedValue>[];
    var order = 0;

    // 1. Check inline style attribute (highest priority except !important)
    final inlineValue = _extractInlineStyleValue(node, normalizedProperty);
    if (inlineValue != null) {
      final isImportant =
          inlineValue.endsWith('!important') ||
          inlineValue.contains('!important');
      final cleanValue = _stripImportant(inlineValue);
      if (cleanValue.isNotEmpty) {
        candidates.add(
          CssResolvedValue(
            value: cleanValue,
            specificity: CssSpecificity.inline,
            order: 1000000, // Inline always has highest order
            isImportant: isImportant,
          ),
        );
      }
    }

    // 2. Check CSS rules from <style> elements
    final matchingRules = _getMatchingRules(node);
    for (final matched in matchingRules) {
      final declaration = matched.rule.declarations[normalizedProperty];
      if (declaration != null) {
        final isImportant =
            declaration.endsWith('!important') ||
            declaration.contains('!important');
        final cleanValue = _stripImportant(declaration);
        if (cleanValue.isNotEmpty) {
          candidates.add(
            CssResolvedValue(
              value: cleanValue,
              specificity: matched.specificity,
              order: order++,
              isImportant: isImportant,
            ),
          );
        }
      }
    }

    // 3. Check presentation attribute (lowest specificity)
    final attrValue = node.getAttributeValue(normalizedProperty)?.toString();
    if (attrValue != null && attrValue.trim().isNotEmpty) {
      candidates.add(
        CssResolvedValue(
          value: attrValue.trim(),
          specificity: CssSpecificity.zero,
          order: -1, // Presentation attributes come before CSS rules
          isImportant: false,
        ),
      );
    }

    // Find winning value from candidates
    CssResolvedValue? winner;
    for (final candidate in candidates) {
      if (winner == null) {
        winner = candidate;
      } else {
        winner = winner.winner(candidate);
      }
    }

    // If we have a winner that's not 'inherit', return it
    if (winner != null && winner.value != 'inherit') {
      return winner.value;
    }

    // 4. Handle inheritance
    if (checkInheritance) {
      // If value is explicitly 'inherit' or property is inheritable and no value set
      final shouldInherit =
          winner?.value == 'inherit' ||
          (winner == null &&
              cssInheritableProperties.contains(normalizedProperty));

      if (shouldInherit && node.parent != null) {
        return resolveProperty(node.parent!, property, checkInheritance: true);
      }
    }

    return winner?.value;
  }

  /// Resolves a property value, checking only the node itself (no inheritance).
  String? resolveOwnProperty(SvgNode node, String property) {
    return resolveProperty(node, property, checkInheritance: false);
  }

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
  SvgNode? _findMatchingAncestor(SvgNode node, CssSimpleSelector selector) {
    var current = node.parent;
    while (current != null) {
      // Check for shadow DOM boundary - stop at use/symbol
      if (_isShadowBoundary(current)) {
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
        selector.notSelectors.isNotEmpty;
  }

  /// Check if a pseudo-class matches an element's current state.
  bool _matchPseudoClass(CssPseudoClass pseudo, SvgNode node, String? id) {
    if (pseudoClassState == null || id == null) {
      // No state tracking available - pseudo-classes don't match
      return false;
    }

    switch (pseudo) {
      case CssPseudoClass.hover:
        return pseudoClassState!.isHovered(id);
      case CssPseudoClass.active:
        return pseudoClassState!.isActive(id);
      case CssPseudoClass.focus:
        return pseudoClassState!.isFocused(id);
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

  /// Extracts value from inline style attribute.
  String? _extractInlineStyleValue(SvgNode node, String property) {
    final style = node.getAttributeValue('style')?.toString();
    if (style == null || style.trim().isEmpty) {
      return null;
    }

    for (final declaration in style.split(';')) {
      final parts = declaration.split(':');
      if (parts.length < 2) continue;

      final key = parts.first.trim().toLowerCase();
      if (key != property) continue;

      return parts.sublist(1).join(':').trim();
    }
    return null;
  }

  /// Strips !important from a value.
  String _stripImportant(String value) {
    return value
        .replaceFirst(RegExp(r'\s*!important\s*$', caseSensitive: false), '')
        .trim();
  }
}

/// Internal class to track a matched rule with its specificity.
class _MatchedRule {
  const _MatchedRule({required this.rule, required this.specificity});
  final CssSelectorRule rule;
  final CssSpecificity specificity;
}
