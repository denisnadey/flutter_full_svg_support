part of 'css_animations.dart';

/// CSS Pseudo-class types
enum CssPseudoClass {
  /// :hover - element is being hovered by pointer
  hover,

  /// :active - element is being activated (pressed)
  active,

  /// :focus - element has focus
  focus,

  /// :visited - link has been visited (not typically applicable to SVG)
  visited,

  /// :link - unvisited link (not typically applicable to SVG)
  link,

  /// :first-child - element is the first child of its parent
  firstChild,

  /// :last-child - element is the last child of its parent
  lastChild,

  /// :only-child - element is the only child of its parent
  onlyChild,

  /// :empty - element has no children
  empty,

  /// :root - element is the root of the document
  root,

  /// :first-of-type - element is first sibling of its type
  firstOfType,

  /// :last-of-type - element is last sibling of its type
  lastOfType,

  /// :only-of-type - element is only sibling of its type
  onlyOfType,
}

/// Represents an :nth-child, :nth-last-child, :nth-of-type, or :nth-last-of-type
/// pseudo-class with An+B formula.
class CssNthPseudoClass {
  const CssNthPseudoClass({
    required this.type,
    required this.a,
    required this.b,
  });

  /// The type of nth pseudo-class
  final CssNthType type;

  /// The 'A' coefficient in the An+B formula
  final int a;

  /// The 'B' offset in the An+B formula
  final int b;

  /// Parse an An+B formula string.
  /// Supports: "odd", "even", "2n", "3n+1", "-n+3", "5", etc.
  static CssNthPseudoClass? parse(CssNthType type, String formula) {
    final normalized = formula.trim().toLowerCase();

    // Special keywords
    if (normalized == 'odd') {
      return CssNthPseudoClass(type: type, a: 2, b: 1);
    }
    if (normalized == 'even') {
      return CssNthPseudoClass(type: type, a: 2, b: 0);
    }

    // Parse An+B formula
    // Examples: "2n", "3n+1", "-n+3", "n", "5", "-2n-1"
    final regex = RegExp(r'^(-?\d*)n([+-]\d+)?$|^([+-]?\d+)$');
    final match = regex.firstMatch(normalized);

    if (match == null) return null;

    int a = 0;
    int b = 0;

    if (match.group(3) != null) {
      // Just a number like "5"
      b = int.tryParse(match.group(3)!) ?? 0;
    } else {
      // An+B pattern
      final aStr = match.group(1) ?? '';
      if (aStr.isEmpty || aStr == '-') {
        a = aStr == '-' ? -1 : 1;
      } else {
        a = int.tryParse(aStr) ?? 1;
      }

      final bStr = match.group(2);
      if (bStr != null) {
        b = int.tryParse(bStr) ?? 0;
      }
    }

    return CssNthPseudoClass(type: type, a: a, b: b);
  }

  /// Check if the given 1-based index matches this An+B formula.
  bool matches(int index) {
    if (a == 0) {
      // Just check if index == b
      return index == b;
    }

    // Solve An + B = index for n >= 0
    // n = (index - b) / a
    final diff = index - b;
    if (a > 0) {
      return diff >= 0 && diff % a == 0;
    } else {
      // Negative A means we count backwards
      return diff <= 0 && (-diff) % (-a) == 0;
    }
  }

  @override
  String toString() {
    final typeStr = switch (type) {
      CssNthType.nthChild => 'nth-child',
      CssNthType.nthLastChild => 'nth-last-child',
      CssNthType.nthOfType => 'nth-of-type',
      CssNthType.nthLastOfType => 'nth-last-of-type',
    };
    if (a == 0) return ':$typeStr($b)';
    final bStr = b >= 0 ? '+$b' : '$b';
    return ':$typeStr(${a}n$bStr)';
  }
}

/// Types of nth-* pseudo-classes
enum CssNthType {
  /// :nth-child(An+B)
  nthChild,

  /// :nth-last-child(An+B)
  nthLastChild,

  /// :nth-of-type(An+B)
  nthOfType,

  /// :nth-last-of-type(An+B)
  nthLastOfType,
}

/// Context for CSS selector matching that includes element state.
class CssSelectorMatchContext {
  const CssSelectorMatchContext({
    this.hoveredElementIds = const {},
    this.activeElementIds = const {},
    this.focusedElementId,
  });

  /// Set of element IDs currently being hovered.
  final Set<String> hoveredElementIds;

  /// Set of element IDs currently active (pressed).
  final Set<String> activeElementIds;

  /// The ID of the currently focused element.
  final String? focusedElementId;

  /// Check if an element has a specific pseudo-class state.
  bool hasState(String? elementId, CssPseudoClass pseudoClass) {
    if (elementId == null) return false;
    switch (pseudoClass) {
      case CssPseudoClass.hover:
        return hoveredElementIds.contains(elementId);
      case CssPseudoClass.active:
        return activeElementIds.contains(elementId);
      case CssPseudoClass.focus:
        return focusedElementId == elementId;
      default:
        return false;
    }
  }
}

/// CSS Combinator types
enum CssCombinator {
  /// No combinator (simple selector sequence)
  none,

  /// Descendant combinator (space): `g rect`
  descendant,

  /// Child combinator (>): `g > rect`
  child,

  /// Adjacent sibling (+): `rect + circle`
  adjacentSibling,

  /// General sibling (~): `rect ~ circle`
  generalSibling,
}

/// CSS Attribute selector match type
enum CssAttributeMatch {
  /// [attr] — has attribute
  exists,

  /// [attr=value] — exact match
  exact,

  /// [attr~=value] — space-separated list contains value
  includes,

  /// [attr|=value] — exact or prefix with hyphen (language prefix)
  dashPrefix,

  /// [attr^=value] — starts with
  prefix,

  /// [attr$=value] — ends with
  suffix,

  /// [attr*=value] — contains substring
  substring,
}

/// Represents an attribute selector like [attr], [attr=value], etc.
class CssAttributeSelector {
  const CssAttributeSelector({
    required this.attribute,
    required this.matchType,
    this.value,
    this.caseInsensitive = false,
  });

  /// Attribute name
  final String attribute;

  /// Match type
  final CssAttributeMatch matchType;

  /// Value to match (null for [attr] existence check)
  final String? value;

  /// Case-insensitive flag (i modifier)
  final bool caseInsensitive;

  /// Check if attribute matches the given attribute value
  bool matches(String? attrValue) {
    if (matchType == CssAttributeMatch.exists) {
      return attrValue != null;
    }

    if (attrValue == null || value == null) return false;

    final testValue = caseInsensitive ? attrValue.toLowerCase() : attrValue;
    final matchValue = caseInsensitive ? value!.toLowerCase() : value!;

    switch (matchType) {
      case CssAttributeMatch.exists:
        return true;
      case CssAttributeMatch.exact:
        return testValue == matchValue;
      case CssAttributeMatch.includes:
        return testValue.split(RegExp(r'\s+')).contains(matchValue);
      case CssAttributeMatch.dashPrefix:
        return testValue == matchValue || testValue.startsWith('$matchValue-');
      case CssAttributeMatch.prefix:
        return testValue.startsWith(matchValue);
      case CssAttributeMatch.suffix:
        return testValue.endsWith(matchValue);
      case CssAttributeMatch.substring:
        return testValue.contains(matchValue);
    }
  }

  @override
  String toString() {
    if (matchType == CssAttributeMatch.exists) {
      return '[$attribute]';
    }
    final op = switch (matchType) {
      CssAttributeMatch.exact => '=',
      CssAttributeMatch.includes => '~=',
      CssAttributeMatch.dashPrefix => '|=',
      CssAttributeMatch.prefix => '^=',
      CssAttributeMatch.suffix => r'$=',
      CssAttributeMatch.substring => '*=',
      CssAttributeMatch.exists => '',
    };
    return '[$attribute$op"$value"${caseInsensitive ? ' i' : ''}]';
  }
}

/// A simple selector component (tag, class, id, attribute, or pseudo-class)
class CssSimpleSelector {
  const CssSimpleSelector({
    this.tagName,
    this.id,
    this.classes = const [],
    this.attributes = const [],
    this.pseudoClasses = const [],
    this.nthPseudoClasses = const [],
    this.notSelectors = const [],
  });

  /// Tag name (null for universal selector *)
  final String? tagName;

  /// ID selector (without #)
  final String? id;

  /// Class names (without .)
  final List<String> classes;

  /// Attribute selectors
  final List<CssAttributeSelector> attributes;

  /// Pseudo-classes (:hover, :active, :focus, etc.)
  final List<CssPseudoClass> pseudoClasses;

  /// Nth-type pseudo-classes (:nth-child, :nth-of-type, etc.)
  final List<CssNthPseudoClass> nthPseudoClasses;

  /// Selectors inside :not() - elements matching these are excluded
  final List<CssSimpleSelector> notSelectors;

  /// Whether this is a universal selector
  bool get isUniversal =>
      tagName == '*' ||
      (tagName == null &&
          id == null &&
          classes.isEmpty &&
          attributes.isEmpty &&
          pseudoClasses.isEmpty &&
          nthPseudoClasses.isEmpty &&
          notSelectors.isEmpty);

  /// Whether this selector has any pseudo-class requirements
  bool get hasPseudoClasses =>
      pseudoClasses.isNotEmpty ||
      nthPseudoClasses.isNotEmpty ||
      notSelectors.isNotEmpty;

  @override
  String toString() {
    final buf = StringBuffer();
    if (tagName != null) buf.write(tagName);
    if (id != null) buf.write('#$id');
    for (final c in classes) {
      buf.write('.$c');
    }
    for (final a in attributes) {
      buf.write(a);
    }
    for (final pc in pseudoClasses) {
      buf.write(':${_pseudoClassToString(pc)}');
    }
    for (final nthPc in nthPseudoClasses) {
      buf.write(nthPc);
    }
    for (final notSel in notSelectors) {
      buf.write(':not($notSel)');
    }
    return buf.isEmpty ? '*' : buf.toString();
  }
}

/// Convert pseudo-class enum to CSS string
String _pseudoClassToString(CssPseudoClass pc) {
  switch (pc) {
    case CssPseudoClass.hover:
      return 'hover';
    case CssPseudoClass.active:
      return 'active';
    case CssPseudoClass.focus:
      return 'focus';
    case CssPseudoClass.visited:
      return 'visited';
    case CssPseudoClass.link:
      return 'link';
    case CssPseudoClass.firstChild:
      return 'first-child';
    case CssPseudoClass.lastChild:
      return 'last-child';
    case CssPseudoClass.onlyChild:
      return 'only-child';
    case CssPseudoClass.empty:
      return 'empty';
    case CssPseudoClass.root:
      return 'root';
    case CssPseudoClass.firstOfType:
      return 'first-of-type';
    case CssPseudoClass.lastOfType:
      return 'last-of-type';
    case CssPseudoClass.onlyOfType:
      return 'only-of-type';
  }
}

/// A compound selector with combinator (e.g., `g > rect`)
class CssSelectorPart {
  const CssSelectorPart({required this.selector, required this.combinator});

  /// The simple selector
  final CssSimpleSelector selector;

  /// Combinator before this selector (none for the first part)
  final CssCombinator combinator;

  @override
  String toString() {
    final combStr = switch (combinator) {
      CssCombinator.none => '',
      CssCombinator.descendant => ' ',
      CssCombinator.child => ' > ',
      CssCombinator.adjacentSibling => ' + ',
      CssCombinator.generalSibling => ' ~ ',
    };
    return '$combStr$selector';
  }
}

/// A complete CSS selector (chain of simple selectors with combinators)
class CssSelector {
  const CssSelector(this.parts);

  /// Chain of selector parts (first part has combinator == none)
  final List<CssSelectorPart> parts;

  /// Check if this is a simple selector (no combinators)
  bool get isSimple => parts.length == 1;

  /// Get the last (rightmost) selector part — the subject
  CssSelectorPart get subject => parts.last;

  @override
  String toString() => parts.map((p) => p.toString()).join();
}

// =============================================================================
// Selector Parser
// =============================================================================

/// Parse a CSS selector string into a CssSelector object
CssSelector? _parseCssSelector(String selectorStr) {
  final str = selectorStr.trim();
  if (str.isEmpty) return null;

  final parts = <CssSelectorPart>[];
  var pos = 0;

  CssCombinator nextCombinator = CssCombinator.none;

  while (pos < str.length) {
    // Skip whitespace and capture combinators
    final startPos = pos;
    pos = _skipWhitespace(str, pos);
    final hadWhitespace = pos > startPos;

    if (pos >= str.length) break;

    // Check for explicit combinators
    final c = str[pos];
    if (c == '>') {
      nextCombinator = CssCombinator.child;
      pos++;
      pos = _skipWhitespace(str, pos);
    } else if (c == '+') {
      nextCombinator = CssCombinator.adjacentSibling;
      pos++;
      pos = _skipWhitespace(str, pos);
    } else if (c == '~') {
      nextCombinator = CssCombinator.generalSibling;
      pos++;
      pos = _skipWhitespace(str, pos);
    } else if (hadWhitespace && parts.isNotEmpty) {
      // Whitespace is descendant combinator
      nextCombinator = CssCombinator.descendant;
    }

    if (pos >= str.length) break;

    // Parse simple selector
    final (simpleSelector, newPos) = _parseSimpleSelector(str, pos);
    if (simpleSelector == null) break;

    parts.add(
      CssSelectorPart(selector: simpleSelector, combinator: nextCombinator),
    );

    pos = newPos;
    nextCombinator = CssCombinator.none;
  }

  return parts.isEmpty ? null : CssSelector(parts);
}

int _skipWhitespace(String str, int pos) {
  while (pos < str.length &&
      (str[pos] == ' ' ||
          str[pos] == '\t' ||
          str[pos] == '\n' ||
          str[pos] == '\r')) {
    pos++;
  }
  return pos;
}

(CssSimpleSelector?, int) _parseSimpleSelector(String str, int startPos) {
  var pos = startPos;
  String? tagName;
  String? id;
  final classes = <String>[];
  final attributes = <CssAttributeSelector>[];
  final pseudoClasses = <CssPseudoClass>[];
  final nthPseudoClasses = <CssNthPseudoClass>[];
  final notSelectors = <CssSimpleSelector>[];

  // Parse tag name or universal selector
  if (pos < str.length) {
    final c = str[pos];
    if (c == '*') {
      tagName = '*';
      pos++;
    } else if (_isNameStart(c)) {
      final (name, newPos) = _parseIdent(str, pos);
      tagName = name;
      pos = newPos;
    }
  }

  // Parse additional components: #id, .class, [attr], :pseudo
  while (pos < str.length) {
    final c = str[pos];

    if (c == '#') {
      // ID selector
      pos++;
      final (name, newPos) = _parseIdent(str, pos);
      if (name.isNotEmpty) {
        id = name;
      }
      pos = newPos;
    } else if (c == '.') {
      // Class selector
      pos++;
      final (name, newPos) = _parseIdent(str, pos);
      if (name.isNotEmpty) {
        classes.add(name);
      }
      pos = newPos;
    } else if (c == '[') {
      // Attribute selector
      final (attrSel, newPos) = _parseAttributeSelector(str, pos);
      if (attrSel != null) {
        attributes.add(attrSel);
      }
      pos = newPos;
    } else if (c == ':') {
      // Pseudo-class or pseudo-element
      pos++;
      if (pos < str.length && str[pos] == ':') {
        // ::pseudo-element - skip for now
        pos++;
        final (_, newPos) = _parseIdent(str, pos);
        pos = newPos;
      } else {
        // :pseudo-class - parse it
        final (pseudoName, newPos) = _parseIdent(str, pos);
        pos = newPos;
        final lowerPseudo = pseudoName.toLowerCase();

        // Handle :not() pseudo-class
        if (lowerPseudo == 'not' && pos < str.length && str[pos] == '(') {
          pos++; // skip (
          pos = _skipWhitespace(str, pos);

          // Parse the inner selector(s)
          final (innerSelector, innerEndPos) = _parseSimpleSelector(str, pos);
          if (innerSelector != null) {
            notSelectors.add(innerSelector);
          }
          pos = innerEndPos;
          pos = _skipWhitespace(str, pos);

          // Skip to closing )
          if (pos < str.length && str[pos] == ')') {
            pos++;
          }
        } else if (pos < str.length && str[pos] == '(') {
          // Functional pseudo-classes like :nth-child(2n+1)
          var depth = 1;
          pos++;
          final argStart = pos;
          while (pos < str.length && depth > 0) {
            if (str[pos] == '(') depth++;
            if (str[pos] == ')') depth--;
            pos++;
          }
          final argContent = str.substring(argStart, pos - 1).trim();

          // Parse nth-* pseudo-classes
          final nthType = _parseNthType(lowerPseudo);
          if (nthType != null) {
            final nthPseudo = CssNthPseudoClass.parse(nthType, argContent);
            if (nthPseudo != null) {
              nthPseudoClasses.add(nthPseudo);
            }
          }
        } else {
          // Simple pseudo-classes
          final parsedPseudo = _parsePseudoClass(lowerPseudo);
          if (parsedPseudo != null) {
            pseudoClasses.add(parsedPseudo);
          }
        }
      }
    } else {
      // End of simple selector
      break;
    }
  }

  if (tagName == null &&
      id == null &&
      classes.isEmpty &&
      attributes.isEmpty &&
      pseudoClasses.isEmpty &&
      nthPseudoClasses.isEmpty &&
      notSelectors.isEmpty) {
    return (null, startPos);
  }

  return (
    CssSimpleSelector(
      tagName: tagName,
      id: id,
      classes: classes,
      attributes: attributes,
      pseudoClasses: pseudoClasses,
      nthPseudoClasses: nthPseudoClasses,
      notSelectors: notSelectors,
    ),
    pos,
  );
}

/// Parse an nth-* pseudo-class type from name
CssNthType? _parseNthType(String name) {
  switch (name) {
    case 'nth-child':
      return CssNthType.nthChild;
    case 'nth-last-child':
      return CssNthType.nthLastChild;
    case 'nth-of-type':
      return CssNthType.nthOfType;
    case 'nth-last-of-type':
      return CssNthType.nthLastOfType;
    default:
      return null;
  }
}

/// Parse a pseudo-class name into enum value
CssPseudoClass? _parsePseudoClass(String name) {
  switch (name) {
    case 'hover':
      return CssPseudoClass.hover;
    case 'active':
      return CssPseudoClass.active;
    case 'focus':
      return CssPseudoClass.focus;
    case 'visited':
      return CssPseudoClass.visited;
    case 'link':
      return CssPseudoClass.link;
    case 'first-child':
      return CssPseudoClass.firstChild;
    case 'last-child':
      return CssPseudoClass.lastChild;
    case 'only-child':
      return CssPseudoClass.onlyChild;
    case 'empty':
      return CssPseudoClass.empty;
    case 'root':
      return CssPseudoClass.root;
    case 'first-of-type':
      return CssPseudoClass.firstOfType;
    case 'last-of-type':
      return CssPseudoClass.lastOfType;
    case 'only-of-type':
      return CssPseudoClass.onlyOfType;
    default:
      return null;
  }
}

(CssAttributeSelector?, int) _parseAttributeSelector(String str, int startPos) {
  if (startPos >= str.length || str[startPos] != '[') {
    return (null, startPos);
  }

  var pos = startPos + 1;
  pos = _skipWhitespace(str, pos);

  // Parse attribute name
  final (attrName, nameEndPos) = _parseIdent(str, pos);
  if (attrName.isEmpty) {
    // Skip to ] and return null
    while (pos < str.length && str[pos] != ']') {
      pos++;
    }
    if (pos < str.length) {
      pos++;
    }
    return (null, pos);
  }
  pos = nameEndPos;
  pos = _skipWhitespace(str, pos);

  // Check for ] (existence check)
  if (pos >= str.length || str[pos] == ']') {
    if (pos < str.length) {
      pos++;
    }
    return (
      CssAttributeSelector(
        attribute: attrName,
        matchType: CssAttributeMatch.exists,
      ),
      pos,
    );
  }

  // Parse operator
  CssAttributeMatch matchType;
  final c = str[pos];
  if (c == '=') {
    matchType = CssAttributeMatch.exact;
    pos++;
  } else if (pos + 1 < str.length && str[pos + 1] == '=') {
    matchType = switch (c) {
      '~' => CssAttributeMatch.includes,
      '|' => CssAttributeMatch.dashPrefix,
      '^' => CssAttributeMatch.prefix,
      r'$' => CssAttributeMatch.suffix,
      '*' => CssAttributeMatch.substring,
      _ => CssAttributeMatch.exact,
    };
    pos += 2;
  } else {
    // Invalid operator, skip to ]
    while (pos < str.length && str[pos] != ']') {
      pos++;
    }
    if (pos < str.length) {
      pos++;
    }
    return (null, pos);
  }

  pos = _skipWhitespace(str, pos);

  // Parse value
  String value;
  if (pos < str.length && (str[pos] == '"' || str[pos] == "'")) {
    final quote = str[pos];
    pos++;
    final valueStart = pos;
    while (pos < str.length && str[pos] != quote) {
      if (str[pos] == '\\' && pos + 1 < str.length) pos++;
      pos++;
    }
    value = str.substring(valueStart, pos);
    if (pos < str.length) pos++;
  } else {
    final (ident, newPos) = _parseIdent(str, pos);
    value = ident;
    pos = newPos;
  }

  pos = _skipWhitespace(str, pos);

  // Check for case-insensitive flag
  bool caseInsensitive = false;
  if (pos < str.length && (str[pos] == 'i' || str[pos] == 'I')) {
    caseInsensitive = true;
    pos++;
    pos = _skipWhitespace(str, pos);
  }

  // Skip to ]
  while (pos < str.length && str[pos] != ']') {
    pos++;
  }
  if (pos < str.length) {
    pos++;
  }

  return (
    CssAttributeSelector(
      attribute: attrName,
      matchType: matchType,
      value: value,
      caseInsensitive: caseInsensitive,
    ),
    pos,
  );
}

(String, int) _parseIdent(String str, int startPos) {
  var pos = startPos;
  while (pos < str.length && _isNameChar(str[pos])) {
    pos++;
  }
  return (str.substring(startPos, pos), pos);
}

bool _isNameStart(String c) {
  if (c.isEmpty) return false;
  final code = c.codeUnitAt(0);
  return (code >= 65 && code <= 90) || // A-Z
      (code >= 97 && code <= 122) || // a-z
      code == 95 || // _
      code >= 128; // non-ASCII
}

bool _isNameChar(String c) {
  if (c.isEmpty) return false;
  final code = c.codeUnitAt(0);
  return _isNameStart(c) ||
      (code >= 48 && code <= 57) || // 0-9
      code == 45; // -
}
