part of 'animated_svg_painter.dart';

/// Text layout resolvers for SVG text styling.
///
/// Contains resolver methods for text layout CSS properties:
/// - tab-size, text-indent, white-space, text-overflow
/// - word-break, overflow-wrap, text-wrap, line-break
/// - text-transform, hyphens, hyphenate-character
/// - line-height, vertical-align
extension AnimatedSvgPainterTextStyleLayoutExtension on AnimatedSvgPainter {
  /// Resolves tab-size CSS property.
  /// Returns number of spaces a tab character equals (default 8).
  /// Supports both number and length values.
  int _resolveTabSize(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 8; // CSS default
    }
    final normalized = value.trim().toLowerCase();
    final parsed = int.tryParse(normalized);
    if (parsed != null) {
      return parsed.clamp(1, 32);
    }
    // For length values like "4em", extract the number
    final match = RegExp(r'^(\d+)').firstMatch(normalized);
    if (match != null) {
      return int.tryParse(match.group(1)!)?.clamp(1, 32) ?? 8;
    }
    return 8;
  }

  /// Resolves text-indent CSS property.
  /// Returns indentation in user units (default 0).
  double _resolveTextIndent(String? value, double fontSize) {
    if (value == null || value.trim().isEmpty) {
      return 0.0;
    }
    final normalized = value.trim().toLowerCase();
    // Handle percentage values
    if (normalized.endsWith('%')) {
      final pctStr = normalized.substring(0, normalized.length - 1);
      final pct = double.tryParse(pctStr);
      if (pct != null) {
        // Percentage relative to containing block width, approximate with fontSize * 10
        return fontSize * pct / 10;
      }
      return 0.0;
    }
    // Handle em units
    if (normalized.endsWith('em')) {
      final numStr = normalized.substring(0, normalized.length - 2);
      return (double.tryParse(numStr) ?? 0.0) * fontSize;
    }
    // Handle px units
    if (normalized.endsWith('px')) {
      final numStr = normalized.substring(0, normalized.length - 2);
      return double.tryParse(numStr) ?? 0.0;
    }
    // Plain number treated as px
    return double.tryParse(normalized) ?? 0.0;
  }

  /// Resolves word-break CSS property.
  /// Returns the word breaking mode (normal, break-all, keep-all, break-word).
  String _resolveWordBreak(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'normal';
    }
    final normalized = value.trim().toLowerCase();
    switch (normalized) {
      case 'break-all':
      case 'keep-all':
      case 'break-word':
        return normalized;
      case 'normal':
      default:
        return 'normal';
    }
  }

  /// Resolves overflow-wrap CSS property (also known as word-wrap).
  /// Returns the overflow wrapping mode (normal, break-word, anywhere).
  String _resolveOverflowWrap(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'normal';
    }
    final normalized = value.trim().toLowerCase();
    switch (normalized) {
      case 'break-word':
      case 'anywhere':
        return normalized;
      case 'normal':
      default:
        return 'normal';
    }
  }

  /// Resolves text-transform CSS property.
  /// Returns the text transformation mode.
  String _resolveTextTransform(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'none';
    }
    final normalized = value.trim().toLowerCase();
    switch (normalized) {
      case 'capitalize':
      case 'uppercase':
      case 'lowercase':
      case 'full-width':
      case 'full-size-kana':
        return normalized;
      case 'none':
      default:
        return 'none';
    }
  }

  /// Resolves hyphens CSS property.
  /// Returns the hyphenation mode (none, manual, auto).
  String _resolveHyphens(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'manual';
    }
    final normalized = value.trim().toLowerCase();
    switch (normalized) {
      case 'none':
      case 'auto':
        return normalized;
      case 'manual':
      default:
        return 'manual';
    }
  }

  /// Resolves line-break CSS property.
  /// Returns the line breaking strictness (auto, loose, normal, strict, anywhere).
  String _resolveLineBreak(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'auto';
    }
    final normalized = value.trim().toLowerCase();
    switch (normalized) {
      case 'loose':
      case 'normal':
      case 'strict':
      case 'anywhere':
        return normalized;
      case 'auto':
      default:
        return 'auto';
    }
  }

  /// Resolves white-space CSS property.
  /// Controls how whitespace is handled in text.
  /// Returns: normal, nowrap, pre, pre-wrap, pre-line, break-spaces.
  String _resolveWhiteSpace(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'normal';
    }
    final normalized = value.trim().toLowerCase();
    switch (normalized) {
      case 'nowrap':
        return 'nowrap';
      case 'pre':
        return 'pre';
      case 'pre-wrap':
        return 'pre-wrap';
      case 'pre-line':
        return 'pre-line';
      case 'break-spaces':
        return 'break-spaces';
      case 'normal':
      default:
        return 'normal';
    }
  }

  /// Resolves text-overflow CSS property.
  /// Controls how overflowed text is represented.
  /// Returns: clip, ellipsis, or custom string.
  String _resolveTextOverflow(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'clip';
    }
    final normalized = value.trim().toLowerCase();
    if (normalized == 'ellipsis') {
      return 'ellipsis';
    }
    if (normalized == 'clip') {
      return 'clip';
    }
    // Custom string value
    return value.trim();
  }

  /// Resolves text-wrap CSS property.
  /// Controls text wrapping behavior.
  /// Returns: wrap, nowrap, balance, pretty, stable.
  String _resolveTextWrap(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'wrap';
    }
    final normalized = value.trim().toLowerCase();
    switch (normalized) {
      case 'nowrap':
        return 'nowrap';
      case 'balance':
        return 'balance';
      case 'pretty':
        return 'pretty';
      case 'stable':
        return 'stable';
      case 'wrap':
      default:
        return 'wrap';
    }
  }

  /// Resolves line-height CSS property.
  /// Returns line height in user units, or null for normal.
  /// Can be a number, length, or percentage.
  double? _resolveLineHeight(String? value, double fontSize) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    final normalized = value.trim().toLowerCase();
    if (normalized == 'normal' || normalized == 'inherit') {
      return null;
    }
    // Handle percentage
    if (normalized.endsWith('%')) {
      final pct = double.tryParse(
        normalized.substring(0, normalized.length - 1),
      );
      if (pct != null) {
        return fontSize * pct / 100;
      }
    }
    // Handle em units
    if (normalized.endsWith('em')) {
      final em = double.tryParse(
        normalized.substring(0, normalized.length - 2),
      );
      if (em != null) {
        return fontSize * em;
      }
    }
    // Handle px units
    if (normalized.endsWith('px')) {
      return double.tryParse(normalized.substring(0, normalized.length - 2));
    }
    // Plain number (unitless multiplier)
    final num = double.tryParse(normalized);
    if (num != null) {
      return fontSize * num;
    }
    return null;
  }

  /// Resolves vertical-align CSS property.
  /// Returns baseline offset in user units.
  /// Keywords: baseline, sub, super, text-top, text-bottom, middle, top, bottom
  /// Or a length/percentage value.
  double _resolveVerticalAlign(String? value, double fontSize) {
    if (value == null || value.trim().isEmpty) {
      return 0.0;
    }
    final normalized = value.trim().toLowerCase();
    switch (normalized) {
      case 'baseline':
        return 0.0;
      case 'sub':
        return -fontSize * 0.3;
      case 'super':
        return fontSize * 0.4;
      case 'text-top':
        return fontSize * 0.8;
      case 'text-bottom':
        return -fontSize * 0.2;
      case 'middle':
        return fontSize * 0.35;
      case 'top':
        return fontSize;
      case 'bottom':
        return -fontSize * 0.25;
      default:
        // Handle length/percentage values
        if (normalized.endsWith('%')) {
          final pct = double.tryParse(
            normalized.substring(0, normalized.length - 1),
          );
          if (pct != null) {
            return fontSize * pct / 100;
          }
        }
        if (normalized.endsWith('em')) {
          final em = double.tryParse(
            normalized.substring(0, normalized.length - 2),
          );
          if (em != null) {
            return fontSize * em;
          }
        }
        if (normalized.endsWith('px')) {
          return double.tryParse(
                normalized.substring(0, normalized.length - 2),
              ) ??
              0.0;
        }
        return double.tryParse(normalized) ?? 0.0;
    }
  }

 /// Resolves hanging-punctuation CSS property.
  /// Returns the hanging punctuation mode (none, first, last, force-end, allow-end).
  String _resolveHangingPunctuation(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'none';
    }
    final normalized = value.trim().toLowerCase();
    // Could be multiple values like "first last"
    final parts = normalized.split(RegExp(r'\s+'));
    final validValues = <String>{};
    for (final part in parts) {
      switch (part) {
        case 'first':
        case 'last':
        case 'force-end':
        case 'allow-end':
          validValues.add(part);
          break;
        case 'none':
          return 'none';
      }
    }
    return validValues.isEmpty ? 'none' : validValues.join(' ');
  }

  /// Checks if a character is a start-edge hanging punctuation (opening brackets, quotes).
  /// These hang at the start of the first line when 'first' is specified.
  bool _isStartHangingPunctuation(String char) {
    if (char.isEmpty) return false;
    final codeUnit = char.codeUnitAt(0);

    // Opening punctuation (Ps category) - ASCII and common
    const openingPunctuation = <int>{
      0x0028, // ( LEFT PARENTHESIS
      0x005B, // [ LEFT SQUARE BRACKET
      0x007B, // { LEFT CURLY BRACKET
      0x2018, // ' LEFT SINGLE QUOTATION MARK
      0x201C, // " LEFT DOUBLE QUOTATION MARK
      0x00AB, // « LEFT-POINTING DOUBLE ANGLE QUOTATION MARK
      0x2039, // ‹ SINGLE LEFT-POINTING ANGLE QUOTATION MARK
    };

    // CJK opening punctuation
    const cjkOpeningPunctuation = <int>{
      0x3008, // 〈 LEFT ANGLE BRACKET
      0x300A, // 《 LEFT DOUBLE ANGLE BRACKET
      0x300C, // 「 LEFT CORNER BRACKET
      0x300E, // 『 LEFT WHITE CORNER BRACKET
      0x3010, // 【 LEFT BLACK LENTICULAR BRACKET
      0x3014, // 〔 LEFT TORTOISE SHELL BRACKET
      0x3016, // 〖 LEFT WHITE LENTICULAR BRACKET
      0x3018, // 〘 LEFT WHITE TORTOISE SHELL BRACKET
      0x301A, // 〚 LEFT WHITE SQUARE BRACKET
      0xFF08, // （ FULLWIDTH LEFT PARENTHESIS
      0xFF3B, // ［ FULLWIDTH LEFT SQUARE BRACKET
      0xFF5B, // ｛ FULLWIDTH LEFT CURLY BRACKET
      0xFE59, // ﹙ SMALL LEFT PARENTHESIS
      0xFE5B, // ﹛ SMALL LEFT CURLY BRACKET
      0xFE5D, // ﹝ SMALL LEFT TORTOISE SHELL BRACKET
    };

    return openingPunctuation.contains(codeUnit) ||
        cjkOpeningPunctuation.contains(codeUnit);
  }

  /// Checks if a character is an end-edge hanging punctuation (closing brackets, quotes).
  /// These hang at the end of the last line when 'last' is specified.
  bool _isEndHangingPunctuation(String char) {
    if (char.isEmpty) return false;
    final codeUnit = char.codeUnitAt(0);

    // Closing punctuation (Pe category) - ASCII and common
    const closingPunctuation = <int>{
      0x0029, // ) RIGHT PARENTHESIS
      0x005D, // ] RIGHT SQUARE BRACKET
      0x007D, // } RIGHT CURLY BRACKET
      0x2019, // ' RIGHT SINGLE QUOTATION MARK
      0x201D, // " RIGHT DOUBLE QUOTATION MARK
      0x00BB, // » RIGHT-POINTING DOUBLE ANGLE QUOTATION MARK
      0x203A, // › SINGLE RIGHT-POINTING ANGLE QUOTATION MARK
    };

    // CJK closing punctuation
    const cjkClosingPunctuation = <int>{
      0x3009, // 〉 RIGHT ANGLE BRACKET
      0x300B, // 》 RIGHT DOUBLE ANGLE BRACKET
      0x300D, // 」 RIGHT CORNER BRACKET
      0x300F, // 』 RIGHT WHITE CORNER BRACKET
      0x3011, // 】 RIGHT BLACK LENTICULAR BRACKET
      0x3015, // 〕 RIGHT TORTOISE SHELL BRACKET
      0x3017, // 〗 RIGHT WHITE LENTICULAR BRACKET
      0x3019, // 〙 RIGHT WHITE TORTOISE SHELL BRACKET
      0x301B, // 〛 RIGHT WHITE SQUARE BRACKET
      0xFF09, // ） FULLWIDTH RIGHT PARENTHESIS
      0xFF3D, // ］ FULLWIDTH RIGHT SQUARE BRACKET
      0xFF5D, // ｝ FULLWIDTH RIGHT CURLY BRACKET
      0xFE5A, // ﹚ SMALL RIGHT PARENTHESIS
      0xFE5C, // ﹜ SMALL RIGHT CURLY BRACKET
      0xFE5E, // ﹞ SMALL RIGHT TORTOISE SHELL BRACKET
    };

    return closingPunctuation.contains(codeUnit) ||
        cjkClosingPunctuation.contains(codeUnit);
  }

  /// Checks if a character is a stop/comma punctuation.
  /// These hang at line ends when 'force-end' or 'allow-end' is specified.
  bool _isStopCommaPunctuation(String char) {
    if (char.isEmpty) return false;
    final codeUnit = char.codeUnitAt(0);

    // Stops and commas (Po subset)
    const stopCommaPunctuation = <int>{
      0x002C, // , COMMA
      0x002E, // . FULL STOP
      0x003A, // : COLON
      0x003B, // ; SEMICOLON
      0x3001, // 、 IDEOGRAPHIC COMMA
      0x3002, // 。 IDEOGRAPHIC FULL STOP
      0xFF0C, // ， FULLWIDTH COMMA
      0xFF0E, // ． FULLWIDTH FULL STOP
      0xFF1A, // ： FULLWIDTH COLON
      0xFF1B, // ； FULLWIDTH SEMICOLON
      0xFE50, // ﹐ SMALL COMMA
      0xFE51, // ﹑ SMALL IDEOGRAPHIC COMMA
      0xFE52, // ﹒ SMALL FULL STOP
    };

    return stopCommaPunctuation.contains(codeUnit);
  }

  /// Calculates hanging punctuation info for text rendering.
  /// Returns a record with startHangWidth and endHangWidth.
  /// - startHangWidth: width to hang at start (negative offset for first char)
  /// - endHangWidth: width to hang at end (allow char to extend past edge)
  ({double startHangWidth, double endHangWidth}) _calculateHangingPunctuation({
    required String text,
    required _ResolvedTextStyle style,
    required bool isFirstLine,
    required bool isLastLine,
  }) {
    if (text.isEmpty || style.hangingPunctuation == 'none') {
      return (startHangWidth: 0.0, endHangWidth: 0.0);
    }

    final hangingModes = style.hangingPunctuation.split(' ').toSet();
    double startHangWidth = 0.0;
    double endHangWidth = 0.0;

    // Handle 'first' - opening punctuation at start of first line
    if (hangingModes.contains('first') && isFirstLine && text.isNotEmpty) {
      final firstChar = String.fromCharCode(text.runes.first);
      if (_isStartHangingPunctuation(firstChar)) {
        // Measure the first character's width
        startHangWidth = _measureCharWidth(firstChar, style);
      }
    }

    // Handle 'last' - closing punctuation at end of last line
    if (hangingModes.contains('last') && isLastLine && text.isNotEmpty) {
      final lastChar = String.fromCharCode(text.runes.last);
      if (_isEndHangingPunctuation(lastChar)) {
        endHangWidth = _measureCharWidth(lastChar, style);
      }
    }

    // Handle 'force-end' - stop/comma at end of any line forced to hang
    if (hangingModes.contains('force-end') && text.isNotEmpty) {
      final lastChar = String.fromCharCode(text.runes.last);
      if (_isStopCommaPunctuation(lastChar)) {
        endHangWidth = _measureCharWidth(lastChar, style);
      }
    }

    // Handle 'allow-end' - stop/comma hangs only if line would overflow
    // For now, treat similar to force-end as we don't have line box info here
    // The actual allow-end logic would require knowing the line box width
    if (hangingModes.contains('allow-end') &&
        !hangingModes.contains('force-end') &&
        text.isNotEmpty) {
      final lastChar = String.fromCharCode(text.runes.last);
      if (_isStopCommaPunctuation(lastChar)) {
        // Mark it as potentially hanging; actual decision happens at layout
        endHangWidth = _measureCharWidth(lastChar, style);
      }
    }

    return (startHangWidth: startHangWidth, endHangWidth: endHangWidth);
  }

  /// Measures the advance width of a single character.
  double _measureCharWidth(String char, _ResolvedTextStyle style) {
    final paragraph = _buildTextParagraph(char, style);
    return paragraph.maxIntrinsicWidth;
  }

  /// Resolves text-justify CSS property.
  /// Controls text justification method.
  /// Returns: auto, none, inter-word, or inter-character.
  String _resolveTextJustify(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'auto';
    }
    final normalized = value.trim().toLowerCase();
    switch (normalized) {
      case 'none':
        return 'none';
      case 'inter-word':
        return 'inter-word';
      case 'inter-character':
        return 'inter-character';
      case 'auto':
      default:
        return 'auto';
    }
  }

  /// Resolves text-align-last CSS property.
  /// Controls alignment of the last line of text.
  /// Returns: auto, start, end, left, right, center, justify.
  String _resolveTextAlignLast(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'auto';
    }
    final normalized = value.trim().toLowerCase();
    switch (normalized) {
      case 'start':
        return 'start';
      case 'end':
        return 'end';
      case 'left':
        return 'left';
      case 'right':
        return 'right';
      case 'center':
        return 'center';
      case 'justify':
        return 'justify';
      case 'auto':
      default:
        return 'auto';
    }
  }

  /// Resolves hyphenate-character CSS property.
  /// Controls hyphenation character.
  /// Returns: auto, or custom character string.
  String _resolveHyphenateCharacter(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'auto';
    }
    final normalized = value.trim().toLowerCase();
    if (normalized == 'auto') {
      return 'auto';
    }
    // Return as-is for custom character
    return value.trim();
  }

  /// Resolves quotes CSS property.
  /// Controls quotation marks used.
  /// Returns: auto, none, or quote strings.
  String? _resolveQuotes(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // auto
    }
    final normalized = value.trim().toLowerCase();
    if (normalized == 'auto' || normalized == 'none') {
      return normalized;
    }
    // Return as-is for quote pairs
    return value.trim();
  }

  /// Resolves initial-letter CSS property.
  /// Controls drop caps / initial letters.
  /// Returns: normal, or size value.
  String? _resolveInitialLetter(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // normal
    }
    final normalized = value.trim().toLowerCase();
    if (normalized == 'normal') {
      return null;
    }
    // Return as-is for size value parsing
    return value.trim();
  }

  /// Resolves text-spacing CSS property.
  /// Controls spacing adjustments for CJK punctuation.
  /// Returns: normal, none, auto, or combination.
  String _resolveTextSpacing(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'normal';
    }
    final normalized = value.trim().toLowerCase();
    switch (normalized) {
      case 'none':
        return 'none';
      case 'auto':
        return 'auto';
      case 'normal':
      default:
        return 'normal';
    }
  }
}
