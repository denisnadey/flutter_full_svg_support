part of 'css_animations.dart';

/// Font shorthand expansion utilities.
///
/// Contains methods for expanding CSS font shorthand property
/// into its longhand equivalents.

// ============================================================
// FONT SHORTHAND
// ============================================================

/// CSS2.1 initial values for font longhand properties.
const _fontInitialValues = <String, String>{
  'font-style': 'normal',
  'font-variant': 'normal',
  'font-weight': 'normal',
  'font-size': 'medium',
  'line-height': 'normal',
  'font-family': 'inherit',
};

/// System font keywords per CSS2.1.
/// These map to system UI fonts and cannot be decomposed.
const _systemFontKeywords = <String>{
  'caption',
  'icon',
  'menu',
  'message-box',
  'small-caption',
  'status-bar',
  // CSS-wide keywords
  'inherit',
  'initial',
  'unset',
  'revert',
  'revert-layer',
};

/// Expands font shorthand into its longhand properties.
///
/// Format: font: [font-style] [font-variant] [font-weight] [font-stretch]
///              font-size[/line-height] font-family
///
/// Per CSS2.1:
/// - font-size and font-family are REQUIRED (except for system fonts)
/// - Missing optional values reset to their initial values
/// - System fonts (caption, icon, menu, etc.) are kept as single value
/// - Optional values (style, variant, weight, stretch) can appear in any order
///
/// Examples:
/// - `font: italic small-caps bold 16px/1.5 Arial, sans-serif`
/// - `font: bold 14px monospace` (italic and small-caps reset to normal)
/// - `font: caption` (system font keyword)
Map<String, String> _expandFont(String value) {
  final trimmedValue = value.trim();

  // Handle system fonts and CSS-wide keywords
  if (_isSystemFont(trimmedValue)) {
    // System fonts are kept as-is, but we also set longhand properties
    // to allow proper cascade behavior
    return {
      'font': trimmedValue,
      // Mark that this is a system font (for rendering layer)
      '_font-system': trimmedValue,
    };
  }

  // Tokenize preserving quoted strings and commas for font-family
  final tokens = _tokenizeFontShorthand(trimmedValue);
  if (tokens.isEmpty) {
    return {'font': trimmedValue};
  }

  // Start with initial values - per CSS spec, font shorthand resets
  // all omitted properties to their initial values
  final result = Map<String, String>.from(_fontInitialValues);

  int tokenIndex = 0;
  bool foundFontSize = false;

  // Parse optional properties (style, variant, weight, stretch) in any order
  // Per CSS spec, these can appear in any order before font-size
  while (tokenIndex < tokens.length && !foundFontSize) {
    final token = tokens[tokenIndex];

    // Check optional properties first before checking font-size
    // This is important because numeric values like 500 are valid as both
    // font-weight (100-900) and font-size (without unit)
    if (_isFontStyle(token) && result['font-style'] == 'normal') {
      result['font-style'] = token;
      tokenIndex++;
      continue;
    }

    if (_isFontVariant(token) && result['font-variant'] == 'normal') {
      result['font-variant'] = token;
      tokenIndex++;
      continue;
    }

    if (_isFontWeight(token) && result['font-weight'] == 'normal') {
      result['font-weight'] = token;
      tokenIndex++;
      continue;
    }

    if (_isFontStretch(token) && !result.containsKey('font-stretch')) {
      result['font-stretch'] = token;
      tokenIndex++;
      continue;
    }

    // Check for font-size (required value)
    // If we find it, stop parsing optional properties
    final sizeLineHeightMatch = RegExp(
      r'^([^\s/]+)/([^\s]+)$',
    ).firstMatch(token);
    if (sizeLineHeightMatch != null) {
      result['font-size'] = sizeLineHeightMatch.group(1)!;
      result['line-height'] = sizeLineHeightMatch.group(2)!;
      foundFontSize = true;
      tokenIndex++;
      break;
    }

    if (_isFontSize(token)) {
      result['font-size'] = token;
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
      break;
    }

    // If we can't match the token as an optional property or font-size,
    // it might be the start of font-family or an unrecognized value
    break;
  }

  // Remaining tokens are font-family (required per CSS2.1)
  if (tokenIndex < tokens.length) {
    final familyTokens = tokens.sublist(tokenIndex);
    result['font-family'] = familyTokens.join(' ');
  }

  // If we didn't find a font-size, this might not be a valid shorthand
  // Return original value to avoid breaking things
  if (!foundFontSize) {
    return {'font': trimmedValue};
  }

  return result;
}

bool _isSystemFont(String value) {
  return _systemFontKeywords.contains(value.toLowerCase());
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

/// Checks if a value is a valid font-stretch keyword.
bool _isFontStretch(String value) {
  const stretchKeywords = {
    'ultra-condensed',
    'extra-condensed',
    'condensed',
    'semi-condensed',
    'normal',
    'semi-expanded',
    'expanded',
    'extra-expanded',
    'ultra-expanded',
  };
  return stretchKeywords.contains(value.toLowerCase());
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
