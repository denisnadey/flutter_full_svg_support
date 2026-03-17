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
  List<_MatchedRule> _getMatchingRules(SvgNode node) {
    // Build cache key from node's identifying attributes
    final id = node.getAttributeValue('id')?.toString();
    final className = node.getAttributeValue('class')?.toString();
    final tagName = node.tagName;
    final cacheKey = '$tagName|${id ?? ''}|${className ?? ''}';

    if (_ruleCache.containsKey(cacheKey)) {
      return _ruleCache[cacheKey]!;
    }

    final matched = <_MatchedRule>[];
    final nodeClasses = (className ?? '')
        .split(RegExp(r'\s+'))
        .where((c) => c.isNotEmpty)
        .toSet();

    for (final rule in cssRules) {
      if (_selectorMatches(rule.selector, tagName, id, nodeClasses)) {
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
