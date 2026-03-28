/// Property inheritance for CSS cascade through use shadow boundaries.
part of 'css_cascade.dart';

/// Context for resolving CSS properties through <use> shadow boundaries.
///
/// This class encapsulates the cascade logic for use-referenced elements,
/// implementing the correct priority order per SVG 2 and CSS specifications:
///
/// 1. Inline style on referenced element (highest priority except !important)
/// 2. CSS rules from <style> blocks (by specificity, then source order)
/// 3. Presentation attributes on referenced element
/// 4. Inherited from <use> element (style attr, then presentation attrs)
/// 5. Inherited from use's ancestors
///
/// Only inheritable CSS properties flow through the use boundary.
///
/// Shadow Boundary Behavior:
/// Per SVG 2 spec, <use> creates a shadow-like scope:
/// - CSS selectors with combinators (>, ~, +, space) stop at shadow boundary
/// - Inherited CSS properties flow through the boundary
/// - Original definition context CSS rules still apply to referenced elements
/// - !important declarations from use context can override referenced content
class UseCascadeContext {
  const UseCascadeContext({
    required this.cssRules,
    this.useNode,
    this.parentContext,
    this.shadowRootId,
    this.nestingDepth = 0,
  });

  /// CSS rules from the document's <style> blocks.
  final List<CssSelectorRule> cssRules;

  /// The <use> element providing inherited properties.
  final SvgNode? useNode;

  /// Parent cascade context for nested <use> chains.
  final UseCascadeContext? parentContext;

  /// ID of the shadow root (referenced element ID) for boundary tracking.
  final String? shadowRootId;

  /// Depth of nesting for deeply nested use chains.
  final int nestingDepth;

  /// Maximum allowed nesting depth (matching Blink).
  static const int maxNestingDepth = 10;

  /// Creates a child context for nested use elements.
  UseCascadeContext createChildContext({
    required SvgNode useNode,
    String? shadowRootId,
  }) {
    return UseCascadeContext(
      cssRules: cssRules,
      useNode: useNode,
      parentContext: this,
      shadowRootId: shadowRootId,
      nestingDepth: nestingDepth + 1,
    );
  }

  /// Resolves a property with full cascade through use boundary.
  ///
  /// This method implements the correct cascade order:
  /// 1. Node's inline style (with !important check)
  /// 2. CSS rules from <style> matching node (by specificity)
  /// 3. Presentation attributes on node
  /// 4. Use element's style with !important (overrides referenced content)
  /// 5. Use element's inherited values (for inheritable properties only)
  String? resolvePropertyForUseContent(
    SvgNode node,
    String property, {
    bool isInheritable = true,
  }) {
    final normalizedProperty = property.trim().toLowerCase();
    final resolver = CssCascadeResolver(cssRules: cssRules);

    // Check for !important on use element first - it has highest priority
    // per SVG spec: use element's !important overrides referenced content
    final useImportantValue = _getUseImportantValue(normalizedProperty);
    if (useImportantValue != null) {
      return useImportantValue;
    }

    // 1. Check inline style on node (highest priority except !important)
    final inlineValue = _extractInlineStyleValue(node, normalizedProperty);
    final bool inlineHasImportant =
        inlineValue != null && inlineValue.contains('!important');
    final String? cleanInlineValue = inlineValue != null
        ? _stripImportant(inlineValue)
        : null;

    // If inline has !important, it wins over CSS rules
    if (inlineHasImportant &&
        cleanInlineValue != null &&
        cleanInlineValue.isNotEmpty) {
      return cleanInlineValue;
    }

    // 2. Check CSS rules from <style> (by specificity)
    String? cssRuleValue;
    bool cssHasImportant = false;
    if (cssRules.isNotEmpty) {
      final matchingRules = resolver._getMatchingRules(node);
      CssResolvedValue? winner;
      var order = 0;
      for (final matched in matchingRules) {
        final declaration = matched.rule.declarations[normalizedProperty];
        if (declaration != null) {
          final isImportant = declaration.contains('!important');
          final cleanValue = _stripImportant(declaration);
          if (cleanValue.isNotEmpty) {
            final candidate = CssResolvedValue(
              value: cleanValue,
              specificity: matched.specificity,
              order: order++,
              isImportant: isImportant,
            );
            if (winner == null) {
              winner = candidate;
            } else {
              winner = winner.winner(candidate);
            }
          }
        }
      }
      if (winner != null) {
        cssRuleValue = winner.value;
        cssHasImportant = winner.isImportant;
      }
    }

    // If CSS rule has !important, it beats inline (non-important)
    if (cssHasImportant && cssRuleValue != null) {
      return cssRuleValue;
    }

    // Non-important inline beats CSS rules
    if (cleanInlineValue != null && cleanInlineValue.isNotEmpty) {
      return cleanInlineValue;
    }

    // CSS rule (no inline)
    if (cssRuleValue != null) {
      return cssRuleValue;
    }

    // 3. Check presentation attribute on node
    final attrValue = node.getAttributeValue(normalizedProperty)?.toString();
    if (attrValue != null && attrValue.trim().isNotEmpty) {
      return attrValue.trim();
    }

    // 4 & 5. Check inherited from <use> element (only for inheritable properties)
    if (isInheritable && useNode != null) {
      return _getInheritedFromUse(normalizedProperty);
    }

    return null;
  }

  /// Gets !important value from use element if present.
  /// Per SVG spec, !important on use element overrides referenced content.
  String? _getUseImportantValue(String property) {
    if (useNode == null) return null;

    final useStyleValue = _extractInlineStyleValue(useNode!, property);
    if (useStyleValue != null && useStyleValue.contains('!important')) {
      return _stripImportant(useStyleValue);
    }

    // Check parent use context for !important values
    return parentContext?._getUseImportantValue(property);
  }

  /// Gets inherited value from use element chain.
  String? _getInheritedFromUse(String property) {
    if (useNode == null) return null;

    // Check use element's inline style first
    final useStyleValue = _extractInlineStyleValue(useNode!, property);
    if (useStyleValue != null) {
      return _stripImportant(useStyleValue);
    }

    // Check use element's presentation attribute
    final useAttrValue = useNode!.getAttributeValue(property)?.toString();
    if (useAttrValue != null && useAttrValue.trim().isNotEmpty) {
      return useAttrValue.trim();
    }

    // Check use element's ancestors
    SvgNode? ancestor = useNode!.parent;
    while (ancestor != null) {
      final ancestorStyleValue = _extractInlineStyleValue(ancestor, property);
      if (ancestorStyleValue != null) {
        return _stripImportant(ancestorStyleValue);
      }
      final ancestorAttrValue = ancestor
          .getAttributeValue(property)
          ?.toString();
      if (ancestorAttrValue != null && ancestorAttrValue.trim().isNotEmpty) {
        return ancestorAttrValue.trim();
      }
      ancestor = ancestor.parent;
    }

    // Check parent use context (for nested use chains)
    return parentContext?._getInheritedFromUse(property);
  }

  /// Checks if this context or any parent already references the given ID.
  /// Used to detect circular references.
  bool hasCircularReference(String targetId) {
    if (shadowRootId == targetId) return true;
    return parentContext?.hasCircularReference(targetId) ?? false;
  }

  /// Gets the outermost use element ID for event retargeting.
  String? get retargetedEventId {
    final root = rootContext;
    return root.useNode?.id;
  }

  /// Gets all use element IDs in the chain from outermost to current.
  /// Useful for event bubbling through nested use elements.
  List<String?> get useChainIds {
    final ids = <String?>[];
    UseCascadeContext? current = this;
    while (current != null) {
      ids.insert(0, current.useNode?.id);
      current = current.parentContext;
    }
    return ids;
  }

  /// Gets the root (outermost) use context.
  UseCascadeContext get rootContext {
    return parentContext?.rootContext ?? this;
  }

  /// Extracts value from inline style attribute.
  static String? _extractInlineStyleValue(SvgNode node, String property) {
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
  static String _stripImportant(String value) {
    return value
        .replaceFirst(RegExp(r'\s*!important\s*$', caseSensitive: false), '')
        .trim();
  }
}

/// Implementation of CssVariablesCascadeResolver that uses the CSS cascade
/// to resolve custom properties defined in style blocks.
class CssCascadeVariablesResolver extends CssVariablesCascadeResolver {
  CssCascadeVariablesResolver(this.cascadeResolver);

  /// The underlying cascade resolver with CSS rules.
  final CssCascadeResolver cascadeResolver;

  @override
  String? resolveCustomProperty(String name, SvgNode node) {
    // Use the cascade resolver to find custom property from matching rules
    // Custom properties follow normal cascade rules for specificity
    final matchingRules = cascadeResolver._getMatchingRules(node);

    // Build list of candidate values with their specificity
    CssResolvedValue? winner;
    var order = 0;

    for (final matched in matchingRules) {
      // Check if this rule has the custom property we're looking for
      final declaration = matched.rule.declarations[name];
      if (declaration != null) {
        final isImportant =
            declaration.endsWith('!important') ||
            declaration.contains('!important');
        final cleanValue = _stripImportant(declaration);
        if (cleanValue.isNotEmpty) {
          final candidate = CssResolvedValue(
            value: cleanValue,
            specificity: matched.specificity,
            order: order++,
            isImportant: isImportant,
          );
          if (winner == null) {
            winner = candidate;
          } else {
            winner = winner.winner(candidate);
          }
        }
      }
    }

    return winner?.value;
  }

  /// Strips !important from a value.
  String _stripImportant(String value) {
    return value
        .replaceFirst(RegExp(r'\s*!important\s*$', caseSensitive: false), '')
        .trim();
  }
}
