part of 'css_animations.dart';

/// CSS shorthand property expansion utilities for SVG styles.
///
/// This module expands CSS shorthand properties into their longhand equivalents
/// to ensure proper inheritance and animation support.
class CssShorthandExpander {
  /// Expands all shorthand properties in a map of CSS declarations.
  ///
  /// Returns a new map with shorthand properties expanded into their
  /// longhand equivalents. Original longhand properties take precedence.
  static Map<String, String> expandAll(Map<String, String> properties) {
    final result = <String, String>{};

    for (final entry in properties.entries) {
      final expanded = expandProperty(entry.key, entry.value);
      for (final expandedEntry in expanded.entries) {
        // Only set if not already explicitly defined
        result[expandedEntry.key] ??= expandedEntry.value;
      }
    }

    // Overlay original explicit longhand properties
    for (final entry in properties.entries) {
      if (!_isShorthandProperty(entry.key)) {
        result[entry.key] = entry.value;
      }
    }

    return result;
  }

  /// Expands a single CSS shorthand property into its longhand equivalents.
  ///
  /// Returns a map of property-value pairs. If the property is not a shorthand,
  /// returns a single-entry map with the original property.
  static Map<String, String> expandProperty(String property, String value) {
    final normalizedProperty = property.toLowerCase().trim();
    final normalizedValue = value.trim();

    switch (normalizedProperty) {
      case 'font':
        return _expandFont(normalizedValue);
      case 'animation':
        return _expandAnimation(normalizedValue);
      case 'transition':
        return _expandTransition(normalizedValue);
      case 'margin':
        return _expandBoxModel('margin', normalizedValue);
      case 'padding':
        return _expandBoxModel('padding', normalizedValue);
      case 'marker':
        return _expandMarker(normalizedValue);
      case 'border':
        return _expandBorder(normalizedValue);
      case 'border-width':
        return _expandBorderWidth(normalizedValue);
      case 'border-style':
        return _expandBorderStyle(normalizedValue);
      case 'border-color':
        return _expandBorderColor(normalizedValue);
      case 'border-radius':
        return _expandBorderRadius(normalizedValue);
      case 'background':
        return _expandBackground(normalizedValue);
      default:
        return {normalizedProperty: normalizedValue};
    }
  }

  /// Checks if a property is a shorthand that can be expanded.
  static bool _isShorthandProperty(String property) {
    const shorthands = {
      'font',
      'animation',
      'transition',
      'margin',
      'padding',
      'marker',
      'border',
      'border-width',
      'border-style',
      'border-color',
      'border-radius',
      'background',
    };
    return shorthands.contains(property.toLowerCase().trim());
  }

  // ============================================================
  // FONT SHORTHAND
  // ============================================================

  /// Expands font shorthand into its longhand properties.
  ///
  /// Format: font: [font-style] [font-variant] [font-weight] font-size[/line-height] font-family
  /// Example: font: italic small-caps bold 16px/1.5 Arial, sans-serif
  static Map<String, String> _expandFont(String value) {
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
      final sizeLineHeightMatch = RegExp(r'^([^\s/]+)/([^\s]+)$').firstMatch(sizeToken);

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

  static bool _isSystemFont(String value) {
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

  static bool _isFontStyle(String value) {
    const styles = {'normal', 'italic', 'oblique'};
    final lower = value.toLowerCase();
    // Also handle oblique with angle: oblique 10deg
    return styles.contains(lower) || lower.startsWith('oblique ');
  }

  static bool _isFontVariant(String value) {
    const variants = {'normal', 'small-caps'};
    return variants.contains(value.toLowerCase());
  }

  static bool _isFontWeight(String value) {
    const keywords = {
      'normal',
      'bold',
      'bolder',
      'lighter',
    };
    final lower = value.toLowerCase();
    if (keywords.contains(lower)) return true;

    // Numeric weights: 100-900
    final numeric = int.tryParse(value);
    return numeric != null && numeric >= 100 && numeric <= 900;
  }

  static bool _isFontSize(String value) {
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
    return RegExp(r'^[+-]?(\d+\.?\d*|\.\d+)(px|em|rem|pt|pc|in|cm|mm|ex|ch|vw|vh|vmin|vmax|%)?$', caseSensitive: false)
        .hasMatch(value);
  }

  static List<String> _tokenizeFontShorthand(String input) {
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

  // ============================================================
  // ANIMATION SHORTHAND (MULTIPLE ANIMATIONS)
  // ============================================================

  /// Expands animation shorthand, supporting multiple comma-separated animations.
  ///
  /// Format: animation: name duration timing-function delay iteration-count direction fill-mode play-state
  /// Multiple: animation: anim1 1s, anim2 2s ease-in
  static Map<String, String> _expandAnimation(String value) {
    // Split by comma, but preserve commas inside timing functions
    final animations = _splitAnimations(value);

    if (animations.length == 1) {
      return _expandSingleAnimation(animations.first);
    }

    // For multiple animations, expand each and combine with commas
    final names = <String>[];
    final durations = <String>[];
    final timingFunctions = <String>[];
    final delays = <String>[];
    final iterationCounts = <String>[];
    final directions = <String>[];
    final fillModes = <String>[];
    final playStates = <String>[];

    for (final anim in animations) {
      final expanded = _parseSingleAnimationToComponents(anim.trim());
      names.add(expanded['animation-name'] ?? 'none');
      durations.add(expanded['animation-duration'] ?? '0s');
      timingFunctions.add(expanded['animation-timing-function'] ?? 'ease');
      delays.add(expanded['animation-delay'] ?? '0s');
      iterationCounts.add(expanded['animation-iteration-count'] ?? '1');
      directions.add(expanded['animation-direction'] ?? 'normal');
      fillModes.add(expanded['animation-fill-mode'] ?? 'none');
      playStates.add(expanded['animation-play-state'] ?? 'running');
    }

    return {
      'animation-name': names.join(', '),
      'animation-duration': durations.join(', '),
      'animation-timing-function': timingFunctions.join(', '),
      'animation-delay': delays.join(', '),
      'animation-iteration-count': iterationCounts.join(', '),
      'animation-direction': directions.join(', '),
      'animation-fill-mode': fillModes.join(', '),
      'animation-play-state': playStates.join(', '),
    };
  }

  static Map<String, String> _expandSingleAnimation(String value) {
    return _parseSingleAnimationToComponents(value);
  }

  static Map<String, String> _parseSingleAnimationToComponents(String value) {
    final tokens = _tokenizeAnimationShorthand(value);
    if (tokens.isEmpty) {
      return {'animation': value};
    }

    String? name;
    String? duration;
    String? timingFunction;
    String? delay;
    String? iterationCount;
    String? direction;
    String? fillMode;
    String? playState;

    bool firstTimeFound = false;

    for (final token in tokens) {
      // Check for timing function (must be before other checks as cubic-bezier contains parens)
      if (_isTimingFunction(token)) {
        timingFunction = token;
        continue;
      }

      // Check for time value (duration or delay)
      if (_isTimeValue(token)) {
        if (!firstTimeFound) {
          duration = token;
          firstTimeFound = true;
        } else {
          delay = token;
        }
        continue;
      }

      // Check for iteration count
      if (token == 'infinite' || double.tryParse(token) != null) {
        iterationCount = token;
        continue;
      }

      // Check for direction
      if (_isAnimationDirection(token)) {
        direction = token;
        continue;
      }

      // Check for fill-mode
      if (_isAnimationFillMode(token)) {
        fillMode = token;
        continue;
      }

      // Check for play-state
      if (_isAnimationPlayState(token)) {
        playState = token;
        continue;
      }

      // Otherwise, it's the animation name
      if (name == null) {
        name = token;
      }
    }

    final result = <String, String>{};
    if (name != null) result['animation-name'] = name;
    if (duration != null) result['animation-duration'] = duration;
    if (timingFunction != null) result['animation-timing-function'] = timingFunction;
    if (delay != null) result['animation-delay'] = delay;
    if (iterationCount != null) result['animation-iteration-count'] = iterationCount;
    if (direction != null) result['animation-direction'] = direction;
    if (fillMode != null) result['animation-fill-mode'] = fillMode;
    if (playState != null) result['animation-play-state'] = playState;

    return result.isNotEmpty ? result : {'animation': value};
  }

  static bool _isTimeValue(String value) {
    return RegExp(r'^[+-]?(\d+\.?\d*|\.\d+)(ms|s)$', caseSensitive: false).hasMatch(value.trim());
  }

  static bool _isAnimationDirection(String value) {
    const directions = {'normal', 'reverse', 'alternate', 'alternate-reverse'};
    return directions.contains(value.toLowerCase());
  }

  static bool _isAnimationFillMode(String value) {
    const fillModes = {'none', 'forwards', 'backwards', 'both'};
    return fillModes.contains(value.toLowerCase());
  }

  static bool _isAnimationPlayState(String value) {
    const playStates = {'running', 'paused'};
    return playStates.contains(value.toLowerCase());
  }

  static List<String> _splitAnimations(String value) {
    final animations = <String>[];
    final buffer = StringBuffer();
    int parenDepth = 0;

    for (int i = 0; i < value.length; i++) {
      final char = value[i];

      if (char == '(') {
        parenDepth++;
        buffer.write(char);
        continue;
      }

      if (char == ')') {
        parenDepth--;
        buffer.write(char);
        continue;
      }

      if (char == ',' && parenDepth == 0) {
        if (buffer.isNotEmpty) {
          animations.add(buffer.toString().trim());
          buffer.clear();
        }
        continue;
      }

      buffer.write(char);
    }

    if (buffer.isNotEmpty) {
      animations.add(buffer.toString().trim());
    }

    return animations;
  }

  // ============================================================
  // TRANSITION SHORTHAND
  // ============================================================

  /// Expands transition shorthand into its longhand properties.
  ///
  /// Format: transition: property duration timing-function delay
  /// Multiple: transition: opacity 0.3s ease, transform 0.5s ease-in-out
  static Map<String, String> _expandTransition(String value) {
    final transitions = _splitAnimations(value); // Same comma handling

    if (transitions.length == 1) {
      return _expandSingleTransition(transitions.first);
    }

    final properties = <String>[];
    final durations = <String>[];
    final timingFunctions = <String>[];
    final delays = <String>[];

    for (final trans in transitions) {
      final expanded = _parseSingleTransitionToComponents(trans.trim());
      properties.add(expanded['transition-property'] ?? 'all');
      durations.add(expanded['transition-duration'] ?? '0s');
      timingFunctions.add(expanded['transition-timing-function'] ?? 'ease');
      delays.add(expanded['transition-delay'] ?? '0s');
    }

    return {
      'transition-property': properties.join(', '),
      'transition-duration': durations.join(', '),
      'transition-timing-function': timingFunctions.join(', '),
      'transition-delay': delays.join(', '),
    };
  }

  static Map<String, String> _expandSingleTransition(String value) {
    return _parseSingleTransitionToComponents(value);
  }

  static Map<String, String> _parseSingleTransitionToComponents(String value) {
    // Handle 'none' or 'inherit'
    final lower = value.toLowerCase().trim();
    if (lower == 'none' || lower == 'inherit' || lower == 'initial' || lower == 'unset') {
      return {'transition-property': lower};
    }

    final tokens = _tokenizeAnimationShorthand(value);
    if (tokens.isEmpty) {
      return {'transition': value};
    }

    String? property;
    String? duration;
    String? timingFunction;
    String? delay;

    bool firstTimeFound = false;

    for (final token in tokens) {
      // Check for timing function
      if (_isTimingFunction(token)) {
        timingFunction = token;
        continue;
      }

      // Check for time value
      if (_isTimeValue(token)) {
        if (!firstTimeFound) {
          duration = token;
          firstTimeFound = true;
        } else {
          delay = token;
        }
        continue;
      }

      // Otherwise, it's the property name
      if (property == null) {
        property = token;
      }
    }

    final result = <String, String>{};
    if (property != null) result['transition-property'] = property;
    if (duration != null) result['transition-duration'] = duration;
    if (timingFunction != null) result['transition-timing-function'] = timingFunction;
    if (delay != null) result['transition-delay'] = delay;

    return result.isNotEmpty ? result : {'transition': value};
  }

  // ============================================================
  // MARGIN / PADDING BOX MODEL SHORTHAND
  // ============================================================

  /// Expands margin/padding shorthand (1-4 values).
  ///
  /// - 1 value: all sides
  /// - 2 values: vertical | horizontal
  /// - 3 values: top | horizontal | bottom
  /// - 4 values: top | right | bottom | left
  static Map<String, String> _expandBoxModel(String property, String value) {
    final values = value.split(RegExp(r'\s+')).where((v) => v.isNotEmpty).toList();

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
  static Map<String, String> _expandMarker(String value) {
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
  static Map<String, String> _expandBorder(String value) {
    final tokens = value.split(RegExp(r'\s+')).where((v) => v.isNotEmpty).toList();

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

  static bool _isBorderStyle(String value) {
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

  static bool _isBorderWidth(String value) {
    const keywords = {'thin', 'medium', 'thick'};
    if (keywords.contains(value.toLowerCase())) return true;
    return RegExp(r'^[+-]?(\d+\.?\d*|\.\d+)(px|em|rem|pt)?$', caseSensitive: false).hasMatch(value);
  }

  /// Expands border-width shorthand (1-4 values).
  static Map<String, String> _expandBorderWidth(String value) {
    final values = value.split(RegExp(r'\s+')).where((v) => v.isNotEmpty).toList();

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
  static Map<String, String> _expandBorderStyle(String value) {
    final values = value.split(RegExp(r'\s+')).where((v) => v.isNotEmpty).toList();

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
  static Map<String, String> _expandBorderColor(String value) {
    final values = value.split(RegExp(r'\s+')).where((v) => v.isNotEmpty).toList();

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
  static Map<String, String> _expandBorderRadius(String value) {
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

  static List<String> _parseBorderRadiusValues(String value) {
    final values = value.split(RegExp(r'\s+')).where((v) => v.isNotEmpty).toList();

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
        return [values[0], values[1], values[2], values.length > 3 ? values[3] : values[1]];
    }
  }

  // ============================================================
  // BACKGROUND SHORTHAND
  // ============================================================

  /// Expands background shorthand into its longhand properties.
  ///
  /// Format: background: color image position/size repeat attachment origin clip
  static Map<String, String> _expandBackground(String value) {
    final lower = value.toLowerCase().trim();

    // Handle keywords
    if (lower == 'none' || lower == 'inherit' || lower == 'initial' || lower == 'unset') {
      return {'background-color': 'transparent', 'background-image': lower};
    }

    // Simple case: just a color
    if (_isBackgroundColor(value)) {
      return {'background-color': value};
    }

    // For more complex background values, return as-is (too complex to fully parse)
    // This handles images, gradients, etc.
    final result = <String, String>{};

    // Check for url()
    if (lower.contains('url(')) {
      result['background-image'] = value;
    } else {
      // Assume it's a color
      result['background-color'] = value;
    }

    return result.isNotEmpty ? result : {'background': value};
  }

  static bool _isBackgroundColor(String value) {
    final lower = value.toLowerCase().trim();
    // Named colors, hex, rgb, rgba, hsl, hsla
    if (lower.startsWith('#')) return true;
    if (lower.startsWith('rgb')) return true;
    if (lower.startsWith('hsl')) return true;
    // Check for common named colors
    return _isNamedColor(lower);
  }

  static bool _isNamedColor(String value) {
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
}
