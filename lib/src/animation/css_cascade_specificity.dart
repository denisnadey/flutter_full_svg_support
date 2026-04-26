/// Specificity calculation for CSS selectors.
part of 'css_cascade.dart';

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
