/// CSS Cascade and Specificity Resolution for SVG.
///
/// Implements proper CSS cascade rules per the CSS Cascading specification:
/// - Specificity calculation for selectors
/// - Cascade order (later declarations win when specificity is equal)
/// - !important handling
/// - Inheritance for inheritable properties
library;

import 'css_animations.dart';
import 'css_variables_calc.dart';
import 'svg_dom.dart';

part 'css_cascade_specificity.dart';
part 'css_cascade_selector_matching.dart';
part 'css_cascade_resolution.dart';
part 'css_cascade_inheritance.dart';

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
///
/// For use-referenced elements, the cascade order is:
/// 1. Inline style on referenced element (highest - specificity 1,0,0,0)
/// 2. !important declarations
/// 3. CSS rules from `<style>` blocks (by specificity, then source order)
/// 4. Presentation attributes on referenced element (specificity 0,0,0,0)
/// 5. Inherited from `<use>` element's style attribute (for inheritable props)
/// 6. Inherited from `<use>` element's presentation attributes (for inheritable props)
/// 7. Inherited from use's ancestors
///
/// Shadow Boundary Behavior:
/// Per SVG 2 spec, `<use>` creates a shadow-like scope:
/// - CSS selectors with combinators (>, ~, +, space) stop at shadow boundary
/// - Inherited CSS properties flow through the boundary
/// - The shadow root ID can be tracked to properly scope selector matching
class CssCascadeResolver with _SelectorMatchingMixin, _ResolutionMixin {
  CssCascadeResolver({required this.cssRules, this.shadowBoundaryId})
    : _ruleCache = {};

  /// All CSS rules from <style> elements.
  @override
  final List<CssSelectorRule> cssRules;

  /// ID of the shadow boundary root (for use-referenced content).
  /// When set, combinator selectors will stop at this boundary.
  @override
  final String? shadowBoundaryId;

  /// Cache of matching rules per node ID/class combination.
  @override
  final Map<String, List<_MatchedRule>> _ruleCache;

  /// Pseudo-class state for dynamic matching.
  @override
  SvgPseudoClassState? pseudoClassState;

  /// Creates a new resolver with shadow boundary for use content.
  CssCascadeResolver withShadowBoundary(String? boundaryId) {
    return CssCascadeResolver(cssRules: cssRules, shadowBoundaryId: boundaryId)
      ..pseudoClassState = pseudoClassState;
  }

  /// Clear the rule cache (call when pseudo-class state changes).
  void clearCache() {
    _ruleCache.clear();
  }
}

/// Internal class to track a matched rule with its specificity.
class _MatchedRule {
  const _MatchedRule({required this.rule, required this.specificity});
  final CssSelectorRule rule;
  final CssSpecificity specificity;
}
