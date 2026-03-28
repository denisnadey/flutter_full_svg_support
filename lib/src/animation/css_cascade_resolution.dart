/// Cascade resolution logic for CSS properties.
part of 'css_cascade.dart';

/// Mixin providing cascade resolution functionality for CssCascadeResolver.
mixin _ResolutionMixin on _SelectorMatchingMixin {
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
