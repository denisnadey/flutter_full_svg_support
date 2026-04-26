/// Cascade resolution logic for CSS properties.
part of 'css_cascade.dart';

/// Mixin providing cascade resolution functionality for CssCascadeResolver.
mixin _ResolutionMixin on _SelectorMatchingMixin {
  /// Resolves a property from stylesheet rules only (<style> blocks).
  ///
  /// This intentionally excludes:
  /// - inline style attribute
  /// - presentation attributes
  /// - inheritance
  ///
  /// Callers that already resolve inline/presentation values separately should
  /// use this API to avoid stringifying typed attribute values (e.g. Color).
  String? resolveFromStyleRulesOnly(SvgNode node, String property) {
    final normalizedProperty = property.trim().toLowerCase();
    final matchingRules = _getMatchingRules(node);
    CssResolvedValue? winner;
    var order = 0;

    for (final matched in matchingRules) {
      final declaration = matched.rule.declarations[normalizedProperty];
      if (declaration == null) {
        order++;
        continue;
      }
      final isImportant =
          declaration.endsWith('!important') ||
          declaration.contains('!important');
      final cleanValue = _stripImportant(declaration);
      if (cleanValue.isEmpty) {
        order++;
        continue;
      }
      final candidate = CssResolvedValue(
        value: cleanValue,
        specificity: matched.specificity,
        order: order++,
        isImportant: isImportant,
      );
      winner = winner == null ? candidate : winner.winner(candidate);
    }

    return winner?.value;
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

  /// Extracts value from inline style attribute.
  ///
  /// This method properly handles CSS shorthand properties by expanding them
  /// before looking up the requested property. For example, if the style is
  /// `margin: 10px` and we're looking for `margin-top`, this will expand the
  /// shorthand and return `10px`.
  String? _extractInlineStyleValue(SvgNode node, String property) {
    final style = node.getAttributeValue('style')?.toString();
    if (style == null || style.trim().isEmpty) {
      return null;
    }

    // First, try direct match (fast path for non-shorthand properties)
    String? directValue;
    bool hasShorthands = false;
    final declarations = <(String, String)>[];

    for (final declaration in style.split(';')) {
      final parts = declaration.split(':');
      if (parts.length < 2) continue;

      final key = parts.first.trim().toLowerCase();
      final value = parts.sublist(1).join(':').trim();
      if (value.isEmpty) continue;

      declarations.add((key, value));

      if (key == property) {
        directValue = value;
      }

      // Check if this is a shorthand that might affect our target property
      if (CssShorthandExpander.isShorthandProperty(key)) {
        hasShorthands = true;
      }
    }

    // If we found a direct match and no shorthands, return it
    if (directValue != null && !hasShorthands) {
      return directValue;
    }

    // If there are shorthands, expand them and look for the property
    if (hasShorthands) {
      final expanded = CssShorthandExpander.expandAllOrdered(declarations);
      final expandedValue = expanded[property];
      if (expandedValue != null) {
        return expandedValue;
      }
    }

    // Return direct match if we had one (for cases where shorthand didn't
    // override our property)
    return directValue;
  }

  /// Strips !important from a value.
  String _stripImportant(String value) {
    return value
        .replaceFirst(RegExp(r'\s*!important\s*$', caseSensitive: false), '')
        .trim();
  }
}
