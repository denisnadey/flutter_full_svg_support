part of 'css_animations.dart';

/// Box model and other shorthand expansion utilities.
///
/// Contains methods for expanding CSS box model shorthand properties
/// (margin, padding, border) and other shorthands (marker, background)
/// into their longhand equivalents.

// ============================================================
// MARGIN / PADDING BOX MODEL SHORTHAND
// ============================================================

/// Expands margin/padding shorthand (1-4 values).
///
/// - 1 value: all sides
/// - 2 values: vertical | horizontal
/// - 3 values: top | horizontal | bottom
/// - 4 values: top | right | bottom | left
Map<String, String> _expandBoxModel(String property, String value) {
  final values = value
      .split(RegExp(r'\s+'))
      .where((v) => v.isNotEmpty)
      .toList();

  if (values.isEmpty) {
    return {property: value};
  }

  String top, right, bottom, left;

  switch (values.length) {
    case 1:
      top = right = bottom = left = values[0];
      break;
    case 2:
      top = bottom = values[0];
      right = left = values[1];
      break;
    case 3:
      top = values[0];
      right = left = values[1];
      bottom = values[2];
      break;
    case 4:
    default:
      top = values[0];
      right = values[1];
      bottom = values[2];
      left = values.length > 3 ? values[3] : values[1];
      break;
  }

  return {
    '$property-top': top,
    '$property-right': right,
    '$property-bottom': bottom,
    '$property-left': left,
  };
}

// ============================================================
// MARKER SHORTHAND (SVG-specific)
// ============================================================

/// Expands SVG marker shorthand into marker-start, marker-mid, marker-end.
///
/// Format: marker: url(#markerId) | none
Map<String, String> _expandMarker(String value) {
  final normalizedValue = value.trim();
  return {
    'marker-start': normalizedValue,
    'marker-mid': normalizedValue,
    'marker-end': normalizedValue,
  };
}

// ============================================================
// BORDER SHORTHAND
// ============================================================

/// Expands border shorthand into width, style, color.
///
/// Format: border: width style color
Map<String, String> _expandBorder(String value) {
  final tokens = value
      .split(RegExp(r'\s+'))
      .where((v) => v.isNotEmpty)
      .toList();

  String? width;
  String? style;
  String? color;

  for (final token in tokens) {
    if (_isBorderStyle(token)) {
      style = token;
    } else if (_isBorderWidth(token)) {
      width = token;
    } else {
      // Assume it's a color
      color = token;
    }
  }

  final result = <String, String>{};
  if (width != null) {
    result['border-top-width'] = width;
    result['border-right-width'] = width;
    result['border-bottom-width'] = width;
    result['border-left-width'] = width;
  }
  if (style != null) {
    result['border-top-style'] = style;
    result['border-right-style'] = style;
    result['border-bottom-style'] = style;
    result['border-left-style'] = style;
  }
  if (color != null) {
    result['border-top-color'] = color;
    result['border-right-color'] = color;
    result['border-bottom-color'] = color;
    result['border-left-color'] = color;
  }

  return result.isNotEmpty ? result : {'border': value};
}

bool _isBorderStyle(String value) {
  const styles = {
    'none',
    'hidden',
    'dotted',
    'dashed',
    'solid',
    'double',
    'groove',
    'ridge',
    'inset',
    'outset',
  };
  return styles.contains(value.toLowerCase());
}

bool _isBorderWidth(String value) {
  const keywords = {'thin', 'medium', 'thick'};
  if (keywords.contains(value.toLowerCase())) return true;
  return RegExp(
    r'^[+-]?(\d+\.?\d*|\.\d+)(px|em|rem|pt)?$',
    caseSensitive: false,
  ).hasMatch(value);
}

/// Expands border-width shorthand (1-4 values).
Map<String, String> _expandBorderWidth(String value) {
  final values = value
      .split(RegExp(r'\s+'))
      .where((v) => v.isNotEmpty)
      .toList();

  if (values.isEmpty) {
    return {'border-width': value};
  }

  String top, right, bottom, left;

  switch (values.length) {
    case 1:
      top = right = bottom = left = values[0];
      break;
    case 2:
      top = bottom = values[0];
      right = left = values[1];
      break;
    case 3:
      top = values[0];
      right = left = values[1];
      bottom = values[2];
      break;
    case 4:
    default:
      top = values[0];
      right = values[1];
      bottom = values[2];
      left = values.length > 3 ? values[3] : values[1];
      break;
  }

  return {
    'border-top-width': top,
    'border-right-width': right,
    'border-bottom-width': bottom,
    'border-left-width': left,
  };
}

/// Expands border-style shorthand (1-4 values).
Map<String, String> _expandBorderStyle(String value) {
  final values = value
      .split(RegExp(r'\s+'))
      .where((v) => v.isNotEmpty)
      .toList();

  if (values.isEmpty) {
    return {'border-style': value};
  }

  String top, right, bottom, left;

  switch (values.length) {
    case 1:
      top = right = bottom = left = values[0];
      break;
    case 2:
      top = bottom = values[0];
      right = left = values[1];
      break;
    case 3:
      top = values[0];
      right = left = values[1];
      bottom = values[2];
      break;
    case 4:
    default:
      top = values[0];
      right = values[1];
      bottom = values[2];
      left = values.length > 3 ? values[3] : values[1];
      break;
  }

  return {
    'border-top-style': top,
    'border-right-style': right,
    'border-bottom-style': bottom,
    'border-left-style': left,
  };
}

/// Expands border-color shorthand (1-4 values).
Map<String, String> _expandBorderColor(String value) {
  final values = value
      .split(RegExp(r'\s+'))
      .where((v) => v.isNotEmpty)
      .toList();

  if (values.isEmpty) {
    return {'border-color': value};
  }

  String top, right, bottom, left;

  switch (values.length) {
    case 1:
      top = right = bottom = left = values[0];
      break;
    case 2:
      top = bottom = values[0];
      right = left = values[1];
      break;
    case 3:
      top = values[0];
      right = left = values[1];
      bottom = values[2];
      break;
    case 4:
    default:
      top = values[0];
      right = values[1];
      bottom = values[2];
      left = values.length > 3 ? values[3] : values[1];
      break;
  }

  return {
    'border-top-color': top,
    'border-right-color': right,
    'border-bottom-color': bottom,
    'border-left-color': left,
  };
}

/// Expands border-radius shorthand.
Map<String, String> _expandBorderRadius(String value) {
  // Handle the / syntax for horizontal/vertical radii
  final parts = value.split('/');
  if (parts.length == 2) {
    final horizontal = _parseBorderRadiusValues(parts[0].trim());
    final vertical = _parseBorderRadiusValues(parts[1].trim());
    return {
      'border-top-left-radius': '${horizontal[0]} ${vertical[0]}',
      'border-top-right-radius': '${horizontal[1]} ${vertical[1]}',
      'border-bottom-right-radius': '${horizontal[2]} ${vertical[2]}',
      'border-bottom-left-radius': '${horizontal[3]} ${vertical[3]}',
    };
  }

  final values = _parseBorderRadiusValues(value);
  return {
    'border-top-left-radius': values[0],
    'border-top-right-radius': values[1],
    'border-bottom-right-radius': values[2],
    'border-bottom-left-radius': values[3],
  };
}

List<String> _parseBorderRadiusValues(String value) {
  final values = value
      .split(RegExp(r'\s+'))
      .where((v) => v.isNotEmpty)
      .toList();

  if (values.isEmpty) {
    return ['0', '0', '0', '0'];
  }

  switch (values.length) {
    case 1:
      return [values[0], values[0], values[0], values[0]];
    case 2:
      return [values[0], values[1], values[0], values[1]];
    case 3:
      return [values[0], values[1], values[2], values[1]];
    case 4:
    default:
      return [
        values[0],
        values[1],
        values[2],
        values.length > 3 ? values[3] : values[1],
      ];
  }
}

// ============================================================
// BACKGROUND SHORTHAND
// ============================================================

/// Expands background shorthand into its longhand properties.
///
/// Format: background: color image position/size repeat attachment origin clip
Map<String, String> _expandBackground(String value) {
  final lower = value.toLowerCase().trim();

  // Handle keywords
  if (lower == 'none' ||
      lower == 'inherit' ||
      lower == 'initial' ||
      lower == 'unset') {
    return {'background-color': 'transparent', 'background-image': lower};
  }

  // Simple case: just a color
  if (_isBackgroundColor(value) && !value.contains(' ')) {
    return {'background-color': value};
  }

  final result = <String, String>{};

  // Extract url() or gradient function
  final imageMatch = RegExp(
    r'(url\([^)]+\)|(?:linear-gradient|radial-gradient|repeating-linear-gradient|repeating-radial-gradient|conic-gradient)\([^)]+\))',
    caseSensitive: false,
  ).firstMatch(value);

  if (imageMatch != null) {
    result['background-image'] = imageMatch.group(0)!;

    // Extract remaining tokens (not inside the function call)
    final remaining = value.replaceFirst(imageMatch.group(0)!, '').trim();
    _parseBackgroundTokens(remaining, result);

    // Apply defaults for unspecified properties when image is specified
    result['background-color'] ??= 'transparent';
    result['background-position'] ??= '0% 0%';
    result['background-size'] ??= 'auto';
    result['background-repeat'] ??= 'repeat';
  } else {
    // No image found, might just be a color or other values
    final tokens = _tokenizeBackgroundValue(value);
    for (final token in tokens) {
      if (_isBackgroundColor(token)) {
        result['background-color'] = token;
      } else if (_isBackgroundRepeat(token)) {
        result['background-repeat'] = token;
      } else if (_isBackgroundPosition(token)) {
        result['background-position'] = token;
      }
    }
  }

  return result.isNotEmpty ? result : {'background': value};
}

/// Parses remaining background tokens (after image extraction)
void _parseBackgroundTokens(String remaining, Map<String, String> result) {
  final tokens = _tokenizeBackgroundValue(remaining);
  for (final token in tokens) {
    if (_isBackgroundRepeat(token)) {
      result['background-repeat'] = token;
    } else if (_isBackgroundPosition(token)) {
      if (result.containsKey('background-position')) {
        result['background-position'] =
            '${result['background-position']} $token';
      } else {
        result['background-position'] = token;
      }
    } else if (_isBackgroundColor(token)) {
      result['background-color'] = token;
    }
  }
}

/// Tokenizes background value, preserving function calls
List<String> _tokenizeBackgroundValue(String value) {
  final tokens = <String>[];
  final buffer = StringBuffer();
  int parenDepth = 0;

  for (int i = 0; i < value.length; i++) {
    final char = value[i];

    if (char == '(') {
      parenDepth++;
      buffer.write(char);
    } else if (char == ')') {
      parenDepth--;
      buffer.write(char);
    } else if (char == ' ' && parenDepth == 0) {
      if (buffer.isNotEmpty) {
        tokens.add(buffer.toString().trim());
        buffer.clear();
      }
    } else {
      buffer.write(char);
    }
  }

  if (buffer.isNotEmpty) {
    tokens.add(buffer.toString().trim());
  }

  return tokens.where((t) => t.isNotEmpty).toList();
}

/// Checks if a token is a background repeat value
bool _isBackgroundRepeat(String value) {
  const repeatValues = {
    'repeat',
    'repeat-x',
    'repeat-y',
    'no-repeat',
    'space',
    'round',
  };
  return repeatValues.contains(value.toLowerCase());
}

/// Checks if a token is a background position value
bool _isBackgroundPosition(String value) {
  const positionKeywords = {'top', 'right', 'bottom', 'left', 'center'};
  final lower = value.toLowerCase();
  if (positionKeywords.contains(lower)) return true;
  // Check for percentage or length values
  return RegExp(r'^[+-]?(\d+\.?\d*|\.\d+)(%|px|em|rem|pt)?$').hasMatch(value);
}

bool _isBackgroundColor(String value) {
  final lower = value.toLowerCase().trim();
  // Named colors, hex, rgb, rgba, hsl, hsla
  if (lower.startsWith('#')) return true;
  if (lower.startsWith('rgb')) return true;
  if (lower.startsWith('hsl')) return true;
  // Check for common named colors
  return _isNamedColor(lower);
}

bool _isNamedColor(String value) {
  const namedColors = {
    'transparent',
    'currentcolor',
    'black',
    'white',
    'red',
    'green',
    'blue',
    'yellow',
    'cyan',
    'magenta',
    'orange',
    'purple',
    'pink',
    'brown',
    'gray',
    'grey',
    // Add more as needed
  };
  return namedColors.contains(value.toLowerCase());
}

// ============================================================
// OFFSET SHORTHAND (CSS Motion Path)
// ============================================================

/// Expands offset shorthand into its longhand properties.
///
/// Format: offset: path distance rotate
/// Examples:
///   offset: path("M 0 0 L 100 100")
///   offset: path("M 0 0 L 100 100") 50%
///   offset: path("M 0 0 L 100 100") 50% auto
///   offset: none
///   offset: url(#myPath) 25% reverse
///   offset: ray(45deg closest-side)
///   offset: polygon(0 0, 100% 0, 100% 100%)
Map<String, String> _expandOffset(String value) {
  final lower = value.toLowerCase().trim();

  // Handle 'none' keyword
  if (lower == 'none') {
    return {
      'offset-path': 'none',
      'offset-distance': '0',
      'offset-rotate': 'auto',
    };
  }

  final result = <String, String>{};

  // Try to extract path(), url(), ray(), or polygon() function
  final pathMatch = RegExp(
    r'(path\([^)]+\)|url\([^)]+\)|ray\([^)]+\)|polygon\([^)]+\))',
    caseSensitive: false,
  ).firstMatch(value);

  if (pathMatch != null) {
    result['offset-path'] = pathMatch.group(0)!;

    // Extract remaining tokens
    final remaining = value.replaceFirst(pathMatch.group(0)!, '').trim();
    _parseOffsetTokens(remaining, result);
  } else {
    // No recognized path function, return as-is
    return {'offset': value};
  }

  return result;
}

/// Parses remaining offset tokens (after path extraction)
void _parseOffsetTokens(String remaining, Map<String, String> result) {
  final tokens = remaining
      .split(RegExp(r'\s+'))
      .where((t) => t.isNotEmpty)
      .toList();

  for (final token in tokens) {
    // Check for distance (percentage or length)
    if (_isOffsetDistance(token)) {
      result['offset-distance'] = token;
    }
    // Check for rotate keywords
    else if (_isOffsetRotate(token)) {
      result['offset-rotate'] = token;
    }
  }
}

/// Checks if a token is an offset-distance value
bool _isOffsetDistance(String value) {
  // Percentage or length
  return RegExp(r'^[+-]?(\d+\.?\d*|\.\d+)(%|px|em|rem|pt)?$').hasMatch(value);
}

/// Checks if a token is an offset-rotate value
bool _isOffsetRotate(String value) {
  const rotateKeywords = {'auto', 'reverse', 'auto-reverse'};
  final lower = value.toLowerCase();
  if (rotateKeywords.contains(lower)) return true;
  // Check for angle values
  return RegExp(
    r'^[+-]?(\d+\.?\d*|\.\d+)(deg|rad|grad|turn)?$',
  ).hasMatch(value);
}
