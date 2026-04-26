part of 'css_animations.dart';

List<CssKeyframes> _parseKeyframes(String cssText) {
  final keyframes = <CssKeyframes>[];

  // Regular expression for @keyframes with support for nested curly braces
  final keyframesRegex = RegExp(
    r'@keyframes\s+([\w-]+)\s*\{',
    multiLine: true,
    caseSensitive: false,
  );

  int pos = 0;
  while (pos < cssText.length) {
    final remainingText = cssText.substring(pos);
    final match = keyframesRegex.firstMatch(remainingText);
    if (match == null) break;

    final name = match.group(1)!.trim();
    final relativeStart = match.end;
    final start = pos + relativeStart;

    // Find the closing brace, accounting for nesting
    int depth = 1;
    int end = start;
    while (end < cssText.length && depth > 0) {
      if (cssText[end] == '{') depth++;
      if (cssText[end] == '}') depth--;
      end++;
    }

    if (depth == 0) {
      final body = cssText.substring(start, end - 1);
      final keyframeList = _parseKeyframeBody(body);
      keyframes.add(CssKeyframes(name: name, keyframes: keyframeList));
    }

    pos = end;
  }

  return keyframes;
}

List<CssSelectorRule> _parseSelectorRules(String cssText) {
  final rules = <CssSelectorRule>[];

  // Step 1: remove @keyframes blocks so their curly braces don't interfere.
  final strippedCss = _stripAtRuleBlocks(cssText);

  // Step 2: look for blocks of the form `selector { ... }`.
  // Supported: #id, .class, element, #id.class, etc.
  // Not supported: a > b, a ~ b (descendant combinator).
  int pos = 0;
  while (pos < strippedCss.length) {
    // Find the nearest opening brace.
    final braceOpen = strippedCss.indexOf('{', pos);
    if (braceOpen == -1) break;

    // Extract the selector (everything before '{', trimmed).
    final rawSelector = strippedCss.substring(pos, braceOpen).trim();

    // Find the closing brace (no nesting — simple rules).
    final braceClose = strippedCss.indexOf('}', braceOpen + 1);
    if (braceClose == -1) break;

    final body = strippedCss.substring(braceOpen + 1, braceClose);
    pos = braceClose + 1;

    // Skip empty selectors or @-rules.
    if (rawSelector.isEmpty || rawSelector.startsWith('@')) continue;

    // Handle comma-separated multi-selectors: `#a, .b { ... }`.
    final selectors = rawSelector
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final declarations = _parseProperties(body);
    if (declarations.isEmpty) continue;

    for (final sel in selectors) {
      rules.add(CssSelectorRule(selector: sel, declarations: declarations));
    }
  }

  return rules;
}

/// Removes all @-rule blocks (such as @keyframes) from CSS text, replacing
/// them with spaces of the same length (to preserve offsets if needed).
String _stripAtRuleBlocks(String css) {
  // Simple approach: replace each @... {...} block with spaces.
  final result = StringBuffer();
  int pos = 0;
  while (pos < css.length) {
    // Look for the '@' character.
    final atPos = css.indexOf('@', pos);
    if (atPos == -1) {
      result.write(css.substring(pos));
      break;
    }
    // Copy everything before '@'.
    result.write(css.substring(pos, atPos));
    // Look for '{' after '@'.
    final braceOpen = css.indexOf('{', atPos);
    if (braceOpen == -1) {
      // No '{' found — end of file.
      break;
    }
    // Skip the block accounting for nesting.
    int depth = 1;
    int end = braceOpen + 1;
    while (end < css.length && depth > 0) {
      if (css[end] == '{') depth++;
      if (css[end] == '}') depth--;
      end++;
    }
    // Replace with spaces.
    result.write(' ' * (end - atPos));
    pos = end;
  }
  return result.toString();
}

/// Parses the body of a @keyframes block
List<CssKeyframe> _parseKeyframeBody(String body) {
  final keyframes = <CssKeyframe>[];

  // Parse keyframe rules:
  //   0% { ... }, 16.666667% { ... }, from { ... }, to { ... }
  // and selector lists:
  //   0%, 50% { ... }
  final keyframeRegex = RegExp(
    r'((?:\d*\.?\d+%|from|to)(?:\s*,\s*(?:\d*\.?\d+%|from|to))*)\s*\{([^}]*)\}',
    multiLine: true,
    caseSensitive: false,
  );

  final matches = keyframeRegex.allMatches(body);

  for (final match in matches) {
    final selectorsStr = match.group(1)!;
    final propertiesStr = match.group(2)!;

    // Parse CSS properties
    final properties = _parseProperties(propertiesStr);

    // Extract per-keyframe animation-timing-function (not an animatable property)
    final perKeyframeTiming = properties.remove('animation-timing-function');

    final selectors = selectorsStr
        .split(',')
        .map((s) => s.trim().toLowerCase())
        .where((s) => s.isNotEmpty);

    for (final selector in selectors) {
      // Convert offset to a number in range 0.0-1.0
      final offset = switch (selector) {
        'from' => 0.0,
        'to' => 1.0,
        _ => (double.tryParse(selector.replaceAll('%', '')) ?? 0.0) / 100.0,
      };

      keyframes.add(
        CssKeyframe(
          offset: offset,
          properties: Map<String, String>.from(properties),
          timingFunction: perKeyframeTiming,
        ),
      );
    }
  }

  // Sort by offset
  keyframes.sort((a, b) => a.offset.compareTo(b.offset));

  return keyframes;
}

/// Parses CSS properties from a string
Map<String, String> _parseProperties(String propertiesStr) {
  final properties = <String, String>{};

  // Split by ; and parse each property
  final lines = propertiesStr.split(';');

  for (final line in lines) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) continue;

    final colonIndex = trimmed.indexOf(':');
    if (colonIndex == -1) continue;

    final name = trimmed.substring(0, colonIndex).trim();
    final value = trimmed.substring(colonIndex + 1).trim();

    if (name.isNotEmpty && value.isNotEmpty) {
      properties[name] = value;
    }
  }

  return properties;
}

/// Parses CSS properties and returns them as ordered list of (name, value) pairs.
///
/// This preserves declaration order which is important for proper cascade
/// resolution when shorthands and longhands interact.
List<(String, String)> _parsePropertiesOrdered(String propertiesStr) {
  final declarations = <(String, String)>[];

  final lines = propertiesStr.split(';');

  for (final line in lines) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) continue;

    final colonIndex = trimmed.indexOf(':');
    if (colonIndex == -1) continue;

    final name = trimmed.substring(0, colonIndex).trim().toLowerCase();
    final value = trimmed.substring(colonIndex + 1).trim();

    if (name.isNotEmpty && value.isNotEmpty) {
      declarations.add((name, value));
    }
  }

  return declarations;
}

/// Parses CSS properties from string and expands shorthand properties.
///
/// This is the preferred function for parsing CSS that may contain
/// shorthand properties like font, margin, padding, animation, etc.
///
/// Per CSS cascade rules, when shorthand and longhand properties are declared
/// at the same specificity level, the later declaration wins. This function
/// preserves declaration order to ensure proper cascade behavior.
Map<String, String> _parsePropertiesWithShorthandExpansion(
  String propertiesStr,
) {
  final orderedDeclarations = _parsePropertiesOrdered(propertiesStr);
  return CssShorthandExpander.expandAllOrdered(orderedDeclarations);
}
