part of 'css_animations.dart';

/// Font shorthand expansion utilities.
///
/// Contains methods for expanding CSS font shorthand property
/// into its longhand equivalents.

// ============================================================
// FONT SHORTHAND
// ============================================================

/// Expands font shorthand into its longhand properties.
///
/// Format: font: [font-style] [font-variant] [font-weight] font-size[/line-height] font-family
/// Example: font: italic small-caps bold 16px/1.5 Arial, sans-serif
Map<String, String> _expandFont(String value) {
  final result = <String, String>{};

  // Handle system fonts and special keywords
  if (_isSystemFont(value)) {
    result['font'] = value;
    return result;
  }

  // Tokenize preserving quoted strings and commas for font-family
  final tokens = _tokenizeFontShorthand(value);
  if (tokens.isEmpty) {
    return {'font': value};
  }

  int tokenIndex = 0;
  bool foundFontSize = false;

  // Parse optional font-style
  if (tokenIndex < tokens.length && _isFontStyle(tokens[tokenIndex])) {
    result['font-style'] = tokens[tokenIndex];
    tokenIndex++;
  }

  // Parse optional font-variant
  if (tokenIndex < tokens.length && _isFontVariant(tokens[tokenIndex])) {
    result['font-variant'] = tokens[tokenIndex];
    tokenIndex++;
  }

  // Parse optional font-weight
  if (tokenIndex < tokens.length && _isFontWeight(tokens[tokenIndex])) {
    result['font-weight'] = tokens[tokenIndex];
    tokenIndex++;
  }

  // Parse required font-size (possibly with line-height)
  if (tokenIndex < tokens.length) {
    final sizeToken = tokens[tokenIndex];
    final sizeLineHeightMatch = RegExp(
      r'^([^\s/]+)/([^\s]+)$',
    ).firstMatch(sizeToken);

    if (sizeLineHeightMatch != null) {
      result['font-size'] = sizeLineHeightMatch.group(1)!;
      result['line-height'] = sizeLineHeightMatch.group(2)!;
      foundFontSize = true;
      tokenIndex++;
    } else if (_isFontSize(sizeToken)) {
      result['font-size'] = sizeToken;
      foundFontSize = true;
      tokenIndex++;

      // Check for separate line-height after /
      if (tokenIndex < tokens.length && tokens[tokenIndex] == '/') {
        tokenIndex++;
        if (tokenIndex < tokens.length) {
          result['line-height'] = tokens[tokenIndex];
          tokenIndex++;
        }
      }
    }
  }

  // Remaining tokens are font-family
  if (tokenIndex < tokens.length) {
    final familyTokens = tokens.sublist(tokenIndex);
    result['font-family'] = familyTokens.join(' ');
  }

  // If we didn't find a font-size, this might not be a valid shorthand
  if (!foundFontSize && result.isEmpty) {
    return {'font': value};
  }

  return result;
}

bool _isSystemFont(String value) {
  const systemFonts = {
    'caption',
    'icon',
    'menu',
    'message-box',
    'small-caption',
    'status-bar',
    'inherit',
    'initial',
    'unset',
  };
  return systemFonts.contains(value.toLowerCase());
}

bool _isFontStyle(String value) {
  const styles = {'normal', 'italic', 'oblique'};
  final lower = value.toLowerCase();
  // Also handle oblique with angle: oblique 10deg
  return styles.contains(lower) || lower.startsWith('oblique ');
}

bool _isFontVariant(String value) {
  const variants = {'normal', 'small-caps'};
  return variants.contains(value.toLowerCase());
}

bool _isFontWeight(String value) {
  const keywords = {'normal', 'bold', 'bolder', 'lighter'};
  final lower = value.toLowerCase();
  if (keywords.contains(lower)) return true;

  // Numeric weights: 100-900
  final numeric = int.tryParse(value);
  return numeric != null && numeric >= 100 && numeric <= 900;
}

bool _isFontSize(String value) {
  // Absolute sizes
  const absoluteSizes = {
    'xx-small',
    'x-small',
    'small',
    'medium',
    'large',
    'x-large',
    'xx-large',
    'xxx-large',
  };
  // Relative sizes
  const relativeSizes = {'smaller', 'larger'};

  final lower = value.toLowerCase();
  if (absoluteSizes.contains(lower) || relativeSizes.contains(lower)) {
    return true;
  }

  // Length or percentage value
  return RegExp(
    r'^[+-]?(\d+\.?\d*|\.\d+)(px|em|rem|pt|pc|in|cm|mm|ex|ch|vw|vh|vmin|vmax|%)?$',
    caseSensitive: false,
  ).hasMatch(value);
}

List<String> _tokenizeFontShorthand(String input) {
  final tokens = <String>[];
  final buffer = StringBuffer();
  bool inQuote = false;
  String? quoteChar;

  for (int i = 0; i < input.length; i++) {
    final char = input[i];

    if (inQuote) {
      buffer.write(char);
      if (char == quoteChar) {
        inQuote = false;
        quoteChar = null;
      }
      continue;
    }

    if (char == '"' || char == "'") {
      inQuote = true;
      quoteChar = char;
      buffer.write(char);
      continue;
    }

    if (char == ',' || char.trim().isEmpty) {
      if (buffer.isNotEmpty) {
        tokens.add(buffer.toString().trim());
        buffer.clear();
      }
      if (char == ',') {
        // Keep comma as part of next token for font-family list
        if (tokens.isNotEmpty) {
          tokens[tokens.length - 1] += ',';
        }
      }
      continue;
    }

    buffer.write(char);
  }

  if (buffer.isNotEmpty) {
    tokens.add(buffer.toString().trim());
  }

  return tokens.where((t) => t.isNotEmpty).toList();
}
