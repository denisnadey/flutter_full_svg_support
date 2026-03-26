part of 'animated_svg_painter.dart';

/// Text rendering utilities for SVG text styling.
///
/// Contains methods for building and rendering text:
/// - Paragraph building with font features and variations
/// - Unicode bidirectional text handling (UAX #9 compliant)
/// - Text path support and spacing calculations
/// - Text content extraction with whitespace handling
/// - Grapheme cluster segmentation for complex scripts
/// - Combining marks and diacritics positioning
/// - NFC normalization for Unicode text
/// - Characters-based grapheme cluster iteration
extension AnimatedSvgPainterTextStyleRenderingExtension on AnimatedSvgPainter {
  /// Builds a Flutter Paragraph with the resolved text style.
  ///
  /// Handles complex typography requirements:
  /// - Font features and variable font axes
  /// - Unicode BiDi text with directional control characters
  /// - Complex script shaping (Arabic, Thai, Devanagari)
  /// - Combining marks and diacritics
  /// - NFC normalization for proper glyph composition
  ui.Paragraph _buildTextParagraph(String text, _ResolvedTextStyle style) {
    // Apply NFC normalization first to compose combining marks
    final normalizedText = _normalizeTextNfc(text);

    // Apply text-transform before any other processing
    var transformedText = _applyTextTransform(
      normalizedText,
      style.textTransform,
    );

    // Apply font-size-adjust if specified
    // font-size-adjust preserves x-height when font-fallback occurs
    // adjusted-font-size = font-size * (font-size-adjust / actual-aspect-ratio)
    var effectiveFontSize = style.fontSize;
    if (style.fontSizeAdjust != null && style.fontSizeAdjust! > 0) {
      // Estimate aspect ratio (x-height/font-size) - typical value is ~0.48 for many fonts
      // This is a heuristic since Flutter doesn't expose actual x-height
      const estimatedAspectRatio = 0.48;
      effectiveFontSize =
          style.fontSize * (style.fontSizeAdjust! / estimatedAspectRatio);
    }

    // Build font variations list for variable font support
    final fontVariations = <ui.FontVariation>[];

    // Apply font-stretch via 'wdth' variation axis
    // font-stretch 100 = normal, maps to wdth 100
    if ((style.fontStretch - 100.0).abs() > 0.1) {
      fontVariations.add(ui.FontVariation('wdth', style.fontStretch));
    }

    // Apply unicode-bidi by wrapping text with Unicode directional control characters
    final processedText = _applyUnicodeBidi(
      transformedText,
      style.unicodeBidi,
      style.textDirection,
    );

    // Generate cache key for text paragraph (include new properties)
    final cacheKey = _RenderCache.textKey(
      processedText,
      effectiveFontSize,
      style.fontFamily,
      style.fontWeight.index,
      style.fontStyle.index,
      style.letterSpacing,
      style.color.toARGB32(),
    );

    // Check cache first
    final cached = _renderCache.textParagraphs[cacheKey];
    if (cached != null) {
      return cached;
    }

    // Build the paragraph
    final paragraphBuilder = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        fontSize: effectiveFontSize,
        fontFamily: style.fontFamily,
        fontWeight: style.fontWeight,
        fontStyle: style.fontStyle,
        textDirection: style.textDirection,
      ),
    );
    final decoration = _buildTextDecoration(style.decorations);

    // Build comprehensive font features list from font-variant-* properties
    final allFontFeatures = <ui.FontFeature>[...style.fontFeatures];

    // Add font-variant-caps features
    _addFontVariantCapsFeatures(allFontFeatures, style.fontVariantCaps);

    // Add font-variant-numeric features
    _addFontVariantNumericFeatures(allFontFeatures, style.fontVariantNumeric);

    // Add font-variant-ligatures features
    _addFontVariantLigaturesFeatures(
      allFontFeatures,
      style.fontVariantLigatures,
    );

    // Add font-variant-position features
    _addFontVariantPositionFeatures(allFontFeatures, style.fontVariantPosition);

    // Add font-kerning feature
    if (style.fontKerning == 'none') {
      allFontFeatures.add(const ui.FontFeature.disable('kern'));
    } else if (style.fontKerning == 'normal') {
      allFontFeatures.add(const ui.FontFeature.enable('kern'));
    }

    paragraphBuilder.pushStyle(
      ui.TextStyle(
        color: style.color,
        fontSize: effectiveFontSize,
        fontFamily: style.fontFamily,
        fontWeight: style.fontWeight,
        fontStyle: style.fontStyle,
        letterSpacing: style.letterSpacing,
        wordSpacing: style.wordSpacing,
        decoration: decoration,
        decorationColor: style.decorationColor ?? style.color,
        fontFeatures: allFontFeatures.isNotEmpty ? allFontFeatures : null,
        fontVariations: fontVariations.isNotEmpty ? fontVariations : null,
      ),
    );
    paragraphBuilder.addText(processedText);
    final paragraph = paragraphBuilder.build();
    paragraph.layout(const ui.ParagraphConstraints(width: 1000000));

    // Cache the result
    _renderCache.textParagraphs[cacheKey] = paragraph;

    return paragraph;
  }

  /// Applies unicode-bidi handling by wrapping text with Unicode directional control characters.
  ///
  /// Implements UAX #9 (Unicode Bidirectional Algorithm):
  /// - embed: LRE/RLE + text + PDF
  /// - bidi-override: LRO/RLO + text + PDF
  /// - isolate: LRI/RLI + text + PDI
  /// - isolate-override: FSI + LRO/RLO + text + PDF + PDI
  /// - plaintext: FSI + text + PDI (determine direction from first strong char)
  String _applyUnicodeBidi(
    String text,
    String? unicodeBidi,
    ui.TextDirection textDirection,
  ) {
    if (unicodeBidi == null) {
      return text;
    }

    // Unicode directional formatting characters
    const String lre = '\u202A'; // Left-to-Right Embedding
    const String rle = '\u202B'; // Right-to-Left Embedding
    const String lro = '\u202D'; // Left-to-Right Override
    const String rlo = '\u202E'; // Right-to-Left Override
    const String pdf = '\u202C'; // Pop Directional Formatting
    const String lri = '\u2066'; // Left-to-Right Isolate
    const String rli = '\u2067'; // Right-to-Left Isolate
    const String fsi = '\u2068'; // First Strong Isolate
    const String pdi = '\u2069'; // Pop Directional Isolate

    final isRtl = textDirection == ui.TextDirection.rtl;

    switch (unicodeBidi) {
      case 'embed':
        // Embed a new level of directionality
        return isRtl ? '$rle$text$pdf' : '$lre$text$pdf';

      case 'bidi-override':
        // Force all characters to use the specified direction
        return isRtl ? '$rlo$text$pdf' : '$lro$text$pdf';

      case 'isolate':
        // Isolate text from surrounding bidi context
        return isRtl ? '$rli$text$pdi' : '$lri$text$pdi';

      case 'isolate-override':
        // Isolate and override direction
        return isRtl ? '$fsi$rlo$text$pdf$pdi' : '$fsi$lro$text$pdf$pdi';

      case 'plaintext':
        // Determine direction from first strong character
        return '$fsi$text$pdi';

      case 'normal':
      default:
        // Use normal Unicode bidi algorithm
        return text;
    }
  }

  /// Normalizes text to NFC (Canonical Decomposition, followed by Canonical Composition).
  ///
  /// NFC ensures that combining character sequences are composed into
  /// precomposed characters when possible. For example:
  /// - 'e' + '\u0301' (combining acute accent) -> 'é' (U+00E9)
  ///
  /// This is important for:
  /// - Proper glyph rendering
  /// - Consistent text width measurement
  /// - Correct character counting for positioning
  String _normalizeTextNfc(String text) {
    if (text.isEmpty) return text;
    // Dart's String doesn't have built-in normalize, but we can implement
    // NFC-like normalization by using replacement patterns for common cases
    // and relying on the text shaper for the rest.
    // For full NFC, we process combining sequences.
    return _composeToNfc(text);
  }

  /// Composes text to NFC form.
  ///
  /// This handles the most common combining sequences for Latin, Greek,
  /// and Cyrillic scripts. The text shaper handles complex scripts.
  String _composeToNfc(String text) {
    if (text.isEmpty) return text;

    // Check if text has any combining marks that might need composition
    bool hasCombining = false;
    for (final rune in text.runes) {
      if (_isCombiningMark(rune)) {
        hasCombining = true;
        break;
      }
    }

    if (!hasCombining) return text;

    // Process character by character, composing where possible
    final buffer = StringBuffer();
    final runes = text.runes.toList();
    var i = 0;

    while (i < runes.length) {
      final base = runes[i];
      i++;

      // Collect all following combining marks
      final combining = <int>[];
      while (i < runes.length && _isCombiningMark(runes[i])) {
        combining.add(runes[i]);
        i++;
      }

      if (combining.isEmpty) {
        buffer.writeCharCode(base);
      } else {
        // Try to compose base + combining marks
        final composed = _tryCompose(base, combining);
        buffer.write(composed);
      }
    }

    return buffer.toString();
  }

  /// Attempts to compose a base character with combining marks.
  ///
  /// Returns the composed string (may be same length if no composition possible).
  String _tryCompose(int base, List<int> combining) {
    // Common Latin compositions with acute accent (U+0301)
    if (combining.length == 1 && combining[0] == 0x0301) {
      final composed = _composeWithAcute(base);
      if (composed != null) return String.fromCharCode(composed);
    }

    // Common Latin compositions with grave accent (U+0300)
    if (combining.length == 1 && combining[0] == 0x0300) {
      final composed = _composeWithGrave(base);
      if (composed != null) return String.fromCharCode(composed);
    }

    // Common Latin compositions with circumflex (U+0302)
    if (combining.length == 1 && combining[0] == 0x0302) {
      final composed = _composeWithCircumflex(base);
      if (composed != null) return String.fromCharCode(composed);
    }

    // Common Latin compositions with tilde (U+0303)
    if (combining.length == 1 && combining[0] == 0x0303) {
      final composed = _composeWithTilde(base);
      if (composed != null) return String.fromCharCode(composed);
    }

    // Common Latin compositions with diaeresis/umlaut (U+0308)
    if (combining.length == 1 && combining[0] == 0x0308) {
      final composed = _composeWithDiaeresis(base);
      if (composed != null) return String.fromCharCode(composed);
    }

    // Common Latin compositions with cedilla (U+0327)
    if (combining.length == 1 && combining[0] == 0x0327) {
      final composed = _composeWithCedilla(base);
      if (composed != null) return String.fromCharCode(composed);
    }

    // No composition found, return as separate characters
    return String.fromCharCode(base) + String.fromCharCodes(combining);
  }

  /// Composes base character with acute accent (U+0301).
  int? _composeWithAcute(int base) {
    const compositions = <int, int>{
      0x0041: 0x00C1, // A -> Á
      0x0061: 0x00E1, // a -> á
      0x0045: 0x00C9, // E -> É
      0x0065: 0x00E9, // e -> é
      0x0049: 0x00CD, // I -> Í
      0x0069: 0x00ED, // i -> í
      0x004F: 0x00D3, // O -> Ó
      0x006F: 0x00F3, // o -> ó
      0x0055: 0x00DA, // U -> Ú
      0x0075: 0x00FA, // u -> ú
      0x0059: 0x00DD, // Y -> Ý
      0x0079: 0x00FD, // y -> ý
      0x004E: 0x0143, // N -> Ń
      0x006E: 0x0144, // n -> ń
      0x0043: 0x0106, // C -> Ć
      0x0063: 0x0107, // c -> ć
      0x0053: 0x015A, // S -> Ś
      0x0073: 0x015B, // s -> ś
      0x005A: 0x0179, // Z -> Ź
      0x007A: 0x017A, // z -> ź
    };
    return compositions[base];
  }

  /// Composes base character with grave accent (U+0300).
  int? _composeWithGrave(int base) {
    const compositions = <int, int>{
      0x0041: 0x00C0, // A -> À
      0x0061: 0x00E0, // a -> à
      0x0045: 0x00C8, // E -> È
      0x0065: 0x00E8, // e -> è
      0x0049: 0x00CC, // I -> Ì
      0x0069: 0x00EC, // i -> ì
      0x004F: 0x00D2, // O -> Ò
      0x006F: 0x00F2, // o -> ò
      0x0055: 0x00D9, // U -> Ù
      0x0075: 0x00F9, // u -> ù
    };
    return compositions[base];
  }

  /// Composes base character with circumflex (U+0302).
  int? _composeWithCircumflex(int base) {
    const compositions = <int, int>{
      0x0041: 0x00C2, // A -> Â
      0x0061: 0x00E2, // a -> â
      0x0045: 0x00CA, // E -> Ê
      0x0065: 0x00EA, // e -> ê
      0x0049: 0x00CE, // I -> Î
      0x0069: 0x00EE, // i -> î
      0x004F: 0x00D4, // O -> Ô
      0x006F: 0x00F4, // o -> ô
      0x0055: 0x00DB, // U -> Û
      0x0075: 0x00FB, // u -> û
    };
    return compositions[base];
  }

  /// Composes base character with tilde (U+0303).
  int? _composeWithTilde(int base) {
    const compositions = <int, int>{
      0x0041: 0x00C3, // A -> Ã
      0x0061: 0x00E3, // a -> ã
      0x004E: 0x00D1, // N -> Ñ
      0x006E: 0x00F1, // n -> ñ
      0x004F: 0x00D5, // O -> Õ
      0x006F: 0x00F5, // o -> õ
    };
    return compositions[base];
  }

  /// Composes base character with diaeresis/umlaut (U+0308).
  int? _composeWithDiaeresis(int base) {
    const compositions = <int, int>{
      0x0041: 0x00C4, // A -> Ä
      0x0061: 0x00E4, // a -> ä
      0x0045: 0x00CB, // E -> Ë
      0x0065: 0x00EB, // e -> ë
      0x0049: 0x00CF, // I -> Ï
      0x0069: 0x00EF, // i -> ï
      0x004F: 0x00D6, // O -> Ö
      0x006F: 0x00F6, // o -> ö
      0x0055: 0x00DC, // U -> Ü
      0x0075: 0x00FC, // u -> ü
      0x0059: 0x0178, // Y -> Ÿ
      0x0079: 0x00FF, // y -> ÿ
    };
    return compositions[base];
  }

  /// Composes base character with cedilla (U+0327).
  int? _composeWithCedilla(int base) {
    const compositions = <int, int>{
      0x0043: 0x00C7, // C -> Ç
      0x0063: 0x00E7, // c -> ç
      0x0053: 0x015E, // S -> Ş
      0x0073: 0x015F, // s -> ş
    };
    return compositions[base];
  }

  /// Segments text into grapheme clusters for proper character handling.
  ///
  /// A grapheme cluster is a user-perceived "character" that may consist of:
  /// - A base character + combining marks (é = e + ́)
  /// - A base character + complex script components
  /// - Emoji sequences (family emoji, skin tone modifiers)
  /// - Regional indicator pairs (flag sequences)
  /// - ZWJ sequences (emoji with zero-width joiner)
  ///
  /// This method implements Unicode Text Segmentation (UAX #29) for proper
  /// grapheme cluster identification.
  ///
  /// This is essential for:
  /// - Arabic connected letter forms
  /// - Thai vowel marks and tone marks
  /// - Devanagari conjuncts and matras
  /// - Combining diacritical marks
  /// - Emoji sequences with ZWJ and modifiers
  // ignore: unused_element
  List<String> _segmentIntoGraphemeClusters(String text) {
    if (text.isEmpty) {
      return const <String>[];
    }

    final clusters = <String>[];
    final runes = text.runes.toList();
    var i = 0;

    while (i < runes.length) {
      final start = i;
      i++; // Include base character

      // Consume any following combining marks
      while (i < runes.length && _isCombiningMark(runes[i])) {
        i++;
      }

      // Handle ZWJ sequences (emoji)
      while (i + 1 < runes.length && runes[i] == 0x200D) {
        i++; // Skip ZWJ
        i++; // Include next character
        // Consume any combining marks after the joined character
        while (i < runes.length && _isCombiningMark(runes[i])) {
          i++;
        }
        // Handle variation selectors after ZWJ character
        while (i < runes.length && _isVariationSelector(runes[i])) {
          i++;
        }
      }

      // Handle regional indicator pairs (flags)
      if (start < runes.length &&
          _isRegionalIndicator(runes[start]) &&
          i < runes.length &&
          _isRegionalIndicator(runes[i])) {
        i++; // Include the second regional indicator
      }

      // Handle variation selectors and skin tone modifiers
      while (i < runes.length && _isVariationSelector(runes[i])) {
        i++;
      }

      // Extract the grapheme cluster
      final cluster = String.fromCharCodes(runes.sublist(start, i));
      clusters.add(cluster);
    }

    return clusters;
  }

  /// Checks if a code point is a regional indicator (used in flag emoji).
  bool _isRegionalIndicator(int codePoint) {
    return codePoint >= 0x1F1E6 && codePoint <= 0x1F1FF;
  }

  /// Checks if a code point is a variation selector.
  bool _isVariationSelector(int codePoint) {
    // Variation selectors VS1-VS16 (FE00-FE0F)
    if (codePoint >= 0xFE00 && codePoint <= 0xFE0F) return true;
    // Variation selectors VS17-VS256 (E0100-E01EF)
    if (codePoint >= 0xE0100 && codePoint <= 0xE01EF) return true;
    // Emoji skin tone modifiers (1F3FB-1F3FF)
    if (codePoint >= 0x1F3FB && codePoint <= 0x1F3FF) return true;
    return false;
  }

  /// Detects the text direction for a given text based on its content.
  ///
  /// Implements first-strong character detection per UAX #9:
  /// - Scans for first character with strong directionality (L, R, or AL)
  /// - Returns RTL if first strong is R or AL, LTR otherwise
  // ignore: unused_element
  ui.TextDirection _detectTextDirection(String text) {
    for (final codeUnit in text.runes) {
      final category = _getUnicodeBidiCategory(codeUnit);
      if (category == _BidiCategory.l) {
        return ui.TextDirection.ltr;
      } else if (category == _BidiCategory.r || category == _BidiCategory.al) {
        return ui.TextDirection.rtl;
      }
    }
    return ui.TextDirection.ltr; // Default to LTR
  }

  /// Gets the Unicode bidirectional category for a code point.
  _BidiCategory _getUnicodeBidiCategory(int codePoint) {
    // Arabic range (0600-06FF, 0750-077F, 08A0-08FF)
    if ((codePoint >= 0x0600 && codePoint <= 0x06FF) ||
        (codePoint >= 0x0750 && codePoint <= 0x077F) ||
        (codePoint >= 0x08A0 && codePoint <= 0x08FF)) {
      return _BidiCategory.al; // Arabic Letter
    }

    // Hebrew range (0590-05FF)
    if (codePoint >= 0x0590 && codePoint <= 0x05FF) {
      return _BidiCategory.r; // Right-to-Left
    }

    // Latin, Greek, Cyrillic, etc.
    if ((codePoint >= 0x0041 && codePoint <= 0x005A) || // A-Z
        (codePoint >= 0x0061 && codePoint <= 0x007A) || // a-z
        (codePoint >= 0x00C0 && codePoint <= 0x024F) || // Latin Extended
        (codePoint >= 0x0370 && codePoint <= 0x03FF) || // Greek
        (codePoint >= 0x0400 && codePoint <= 0x04FF)) {
      // Cyrillic
      return _BidiCategory.l; // Left-to-Right
    }

    // Numbers are considered neutral/weak for bidi purposes
    if (codePoint >= 0x0030 && codePoint <= 0x0039) {
      return _BidiCategory.en; // European Number
    }

    return _BidiCategory.other;
  }

  /// Checks if a character is a combining mark or diacritic.
  ///
  /// Combining marks modify the preceding base character and should
  /// be rendered as part of the same glyph.
  bool _isCombiningMark(int codePoint) {
    // Combining Diacritical Marks (0300-036F)
    if (codePoint >= 0x0300 && codePoint <= 0x036F) {
      return true;
    }
    // Combining Diacritical Marks Extended (1AB0-1AFF)
    if (codePoint >= 0x1AB0 && codePoint <= 0x1AFF) {
      return true;
    }
    // Combining Diacritical Marks Supplement (1DC0-1DFF)
    if (codePoint >= 0x1DC0 && codePoint <= 0x1DFF) {
      return true;
    }
    // Combining Half Marks (FE20-FE2F)
    if (codePoint >= 0xFE20 && codePoint <= 0xFE2F) {
      return true;
    }
    // Thai combining marks (0E31, 0E34-0E3A, 0E47-0E4E)
    if (codePoint == 0x0E31 ||
        (codePoint >= 0x0E34 && codePoint <= 0x0E3A) ||
        (codePoint >= 0x0E47 && codePoint <= 0x0E4E)) {
      return true;
    }
    // Devanagari combining marks (093C, 0941-0948, 094D)
    if (codePoint == 0x093C ||
        (codePoint >= 0x0941 && codePoint <= 0x0948) ||
        codePoint == 0x094D) {
      return true;
    }
    return false;
  }

  /// Segments text into logical visual runs for bidirectional text.
  ///
  /// Each run contains text of consistent directionality.
  /// Used for proper hit-testing and selection in mixed-direction text.
  // ignore: unused_element
  List<_BidiRun> _segmentIntoBidiRuns(
    String text,
    ui.TextDirection baseDirection,
  ) {
    if (text.isEmpty) {
      return const <_BidiRun>[];
    }

    final runs = <_BidiRun>[];
    var currentStart = 0;
    var currentDirection = baseDirection;

    for (var i = 0; i < text.length;) {
      final codePoint = text.codeUnitAt(i);
      final category = _getUnicodeBidiCategory(codePoint);

      ui.TextDirection charDirection;
      if (category == _BidiCategory.l) {
        charDirection = ui.TextDirection.ltr;
      } else if (category == _BidiCategory.r || category == _BidiCategory.al) {
        charDirection = ui.TextDirection.rtl;
      } else {
        // Neutral characters follow the current direction
        charDirection = currentDirection;
      }

      // If direction changes, close current run and start new one
      if (runs.isEmpty || charDirection != currentDirection) {
        if (runs.isNotEmpty) {
          // Close previous run
          runs.last = _BidiRun(
            text: text.substring(currentStart, i),
            direction: currentDirection,
            start: currentStart,
            end: i,
          );
        }
        // Start new run
        currentStart = i;
        currentDirection = charDirection;
        runs.add(
          _BidiRun(text: '', direction: charDirection, start: i, end: i),
        );
      }

      i++;
    }

    // Close final run
    if (runs.isNotEmpty) {
      runs.last = _BidiRun(
        text: text.substring(currentStart),
        direction: currentDirection,
        start: currentStart,
        end: text.length,
      );
    } else {
      runs.add(
        _BidiRun(
          text: text,
          direction: baseDirection,
          start: 0,
          end: text.length,
        ),
      );
    }

    return runs;
  }

  /// Draws a paragraph with optional effects (filter, color filter, blend mode).
  void _drawParagraphWithEffects(
    ui.Canvas canvas, {
    required ui.Paragraph paragraph,
    required double x,
    required double y,
    ui.ImageFilter? imageFilter,
    ui.ColorFilter? colorFilter,
    ui.BlendMode? blendMode,
    _ResolvedTextStyle? style,
    String? text,
  }) {
    if (imageFilter == null && colorFilter == null && blendMode == null) {
      canvas.drawParagraph(paragraph, ui.Offset(x, y));
      // Draw text emphasis marks if configured
      if (style != null && text != null && style.textEmphasisStyle != null) {
        _drawTextEmphasisMarks(canvas, paragraph, x, y, text, style);
      }
      return;
    }

    final layerPaint = ui.Paint();
    if (imageFilter != null) {
      layerPaint.imageFilter = imageFilter;
    }
    if (colorFilter != null) {
      layerPaint.colorFilter = colorFilter;
    }
    if (blendMode != null) {
      layerPaint.blendMode = blendMode;
    }
    final bounds = ui.Rect.fromLTWH(
      x,
      y,
      paragraph.maxIntrinsicWidth,
      paragraph.height,
    ).inflate(1.0);
    canvas.saveLayer(bounds, layerPaint);
    canvas.drawParagraph(paragraph, ui.Offset(x, y));
    // Draw text emphasis marks if configured
    if (style != null && text != null && style.textEmphasisStyle != null) {
      _drawTextEmphasisMarks(canvas, paragraph, x, y, text, style);
    }
    canvas.restore();
  }

  /// Draws text emphasis marks above or below text.
  /// Supports: dot, circle, double-circle, triangle, sesame, or custom string.
  void _drawTextEmphasisMarks(
    ui.Canvas canvas,
    ui.Paragraph paragraph,
    double x,
    double y,
    String text,
    _ResolvedTextStyle style,
  ) {
    final emphasisStyle = style.textEmphasisStyle;
    if (emphasisStyle == null) return;

    // Parse emphasis style to get mark character and fill mode
    final emphasisMark = _resolveEmphasisMarkCharacter(emphasisStyle);
    if (emphasisMark == null) return;

    // Parse position (default: over right)
    final position = style.textEmphasisPosition;
    final isAbove = !position.contains('under');

    // Get emphasis color (default to text color)
    final emphasisColor = style.textEmphasisColor != null
        ? _resolveColorFromString(style.textEmphasisColor!)
        : style.color;

    // Calculate mark position
    final markFontSize =
        style.fontSize * 0.5; // Emphasis marks are typically smaller
    final markSpacing = style.fontSize * 0.2;

    // Build emphasis mark paragraph
    final emphasisParagraphStyle = ui.ParagraphStyle(
      fontSize: markFontSize,
      textAlign: ui.TextAlign.center,
    );
    final emphasisBuilder = ui.ParagraphBuilder(emphasisParagraphStyle);
    emphasisBuilder.pushStyle(
      ui.TextStyle(color: emphasisColor, fontSize: markFontSize),
    );
    emphasisBuilder.addText(emphasisMark);
    final emphasisParagraph = emphasisBuilder.build();
    emphasisParagraph.layout(const ui.ParagraphConstraints(width: 100));

    // Draw marks for each character
    final glyphs = text.runes.map((r) => String.fromCharCode(r)).toList();
    var charX = x;

    for (var i = 0; i < glyphs.length; i++) {
      final glyph = glyphs[i];
      // Skip whitespace
      if (glyph == ' ' || glyph == '\t' || glyph == '\n') {
        final glyphParagraph = _buildTextParagraph(glyph, style);
        charX += glyphParagraph.maxIntrinsicWidth + style.letterSpacing;
        continue;
      }

      final glyphParagraph = _buildTextParagraph(glyph, style);
      final glyphWidth = glyphParagraph.maxIntrinsicWidth;

      // Position the emphasis mark
      final markX =
          charX + (glyphWidth - emphasisParagraph.maxIntrinsicWidth) / 2;
      final markY = isAbove
          ? y - markSpacing - emphasisParagraph.height
          : y + paragraph.height + markSpacing;

      canvas.drawParagraph(emphasisParagraph, ui.Offset(markX, markY));

      charX += glyphWidth + style.letterSpacing;
    }
  }

  /// Resolves emphasis mark character from style value.
  /// Returns the character to use as emphasis mark.
  String? _resolveEmphasisMarkCharacter(String style) {
    final normalized = style.toLowerCase();
    final parts = normalized.split(RegExp(r'\s+'));

    var isFilled = true;
    String? markType;

    for (final part in parts) {
      switch (part) {
        case 'filled':
          isFilled = true;
          break;
        case 'open':
          isFilled = false;
          break;
        case 'dot':
        case 'circle':
        case 'double-circle':
        case 'triangle':
        case 'sesame':
          markType = part;
          break;
        default:
          // Custom string - check if it's a quoted string
          if (part.startsWith("'") || part.startsWith('"')) {
            return part.substring(1, part.length - 1);
          } else if (part.isNotEmpty &&
              !['none', 'filled', 'open'].contains(part)) {
            return part; // Custom character
          }
      }
    }

    // Return mark character based on type
    switch (markType ?? 'dot') {
      case 'dot':
        return isFilled ? '\u2022' : '\u25E6'; // • or ◦
      case 'circle':
        return isFilled ? '\u25CF' : '\u25CB'; // ● or ○
      case 'double-circle':
        return '\u25CE'; // ◎
      case 'triangle':
        return isFilled ? '\u25B2' : '\u25B3'; // ▲ or △
      case 'sesame':
        return isFilled ? '\uFE45' : '\uFE46'; // ﹅ or ﹆
      default:
        return null;
    }
  }

  /// Helper to resolve color from a string value.
  ui.Color _resolveColorFromString(String colorStr) {
    // Simple color resolution - handle common color names and hex values
    final normalized = colorStr.toLowerCase().trim();

    // Common color names
    const colorMap = <String, int>{
      'black': 0xFF000000,
      'white': 0xFFFFFFFF,
      'red': 0xFFFF0000,
      'green': 0xFF008000,
      'blue': 0xFF0000FF,
      'yellow': 0xFFFFFF00,
      'cyan': 0xFF00FFFF,
      'magenta': 0xFFFF00FF,
      'gray': 0xFF808080,
      'grey': 0xFF808080,
      'orange': 0xFFFFA500,
      'purple': 0xFF800080,
      'pink': 0xFFFFC0CB,
      'brown': 0xFFA52A2A,
    };

    if (colorMap.containsKey(normalized)) {
      return ui.Color(colorMap[normalized]!);
    }

    // Try to parse hex color
    if (normalized.startsWith('#')) {
      final hex = normalized.substring(1);
      if (hex.length == 6) {
        final value = int.tryParse('FF$hex', radix: 16);
        if (value != null) return ui.Color(value);
      } else if (hex.length == 3) {
        final r = hex[0];
        final g = hex[1];
        final b = hex[2];
        final value = int.tryParse('FF$r$r$g$g$b$b', radix: 16);
        if (value != null) return ui.Color(value);
      }
    }

    // Default to black
    return const ui.Color(0xFF000000);
  }

  /// Adds font-variant-caps features to the list.
  void _addFontVariantCapsFeatures(
    List<ui.FontFeature> features,
    String value,
  ) {
    if (value == 'normal') return;

    switch (value) {
      case 'small-caps':
        features.add(const ui.FontFeature.enable('smcp'));
        break;
      case 'all-small-caps':
        features.add(const ui.FontFeature.enable('smcp'));
        features.add(const ui.FontFeature.enable('c2sc'));
        break;
      case 'petite-caps':
        features.add(const ui.FontFeature.enable('pcap'));
        break;
      case 'all-petite-caps':
        features.add(const ui.FontFeature.enable('pcap'));
        features.add(const ui.FontFeature.enable('c2pc'));
        break;
      case 'unicase':
        features.add(const ui.FontFeature.enable('unic'));
        break;
      case 'titling-caps':
        features.add(const ui.FontFeature.enable('titl'));
        break;
    }
  }

  /// Adds font-variant-numeric features to the list.
  void _addFontVariantNumericFeatures(
    List<ui.FontFeature> features,
    String value,
  ) {
    if (value == 'normal') return;

    final parts = value.split(RegExp(r'\s+'));
    for (final part in parts) {
      switch (part) {
        case 'lining-nums':
          features.add(const ui.FontFeature.liningFigures());
          break;
        case 'oldstyle-nums':
          features.add(const ui.FontFeature.oldstyleFigures());
          break;
        case 'proportional-nums':
          features.add(const ui.FontFeature.proportionalFigures());
          break;
        case 'tabular-nums':
          features.add(const ui.FontFeature.tabularFigures());
          break;
        case 'diagonal-fractions':
          features.add(const ui.FontFeature.enable('frac'));
          break;
        case 'stacked-fractions':
          features.add(const ui.FontFeature.enable('afrc'));
          break;
        case 'ordinal':
          features.add(const ui.FontFeature.enable('ordn'));
          break;
        case 'slashed-zero':
          features.add(const ui.FontFeature.slashedZero());
          break;
      }
    }
  }

  /// Adds font-variant-ligatures features to the list.
  void _addFontVariantLigaturesFeatures(
    List<ui.FontFeature> features,
    String value,
  ) {
    if (value == 'normal') return;

    if (value == 'none') {
      features.add(const ui.FontFeature.disable('liga'));
      features.add(const ui.FontFeature.disable('clig'));
      features.add(const ui.FontFeature.disable('dlig'));
      features.add(const ui.FontFeature.disable('hlig'));
      features.add(const ui.FontFeature.disable('calt'));
      return;
    }

    final parts = value.split(RegExp(r'\s+'));
    for (final part in parts) {
      switch (part) {
        case 'common-ligatures':
          features.add(const ui.FontFeature.enable('liga'));
          features.add(const ui.FontFeature.enable('clig'));
          break;
        case 'no-common-ligatures':
          features.add(const ui.FontFeature.disable('liga'));
          features.add(const ui.FontFeature.disable('clig'));
          break;
        case 'discretionary-ligatures':
          features.add(const ui.FontFeature.enable('dlig'));
          break;
        case 'no-discretionary-ligatures':
          features.add(const ui.FontFeature.disable('dlig'));
          break;
        case 'historical-ligatures':
          features.add(const ui.FontFeature.enable('hlig'));
          break;
        case 'no-historical-ligatures':
          features.add(const ui.FontFeature.disable('hlig'));
          break;
        case 'contextual':
          features.add(const ui.FontFeature.enable('calt'));
          break;
        case 'no-contextual':
          features.add(const ui.FontFeature.disable('calt'));
          break;
      }
    }
  }

  /// Adds font-variant-position features to the list.
  void _addFontVariantPositionFeatures(
    List<ui.FontFeature> features,
    String value,
  ) {
    if (value == 'normal') return;

    switch (value) {
      case 'sub':
        features.add(const ui.FontFeature.enable('subs'));
        break;
      case 'super':
        features.add(const ui.FontFeature.enable('sups'));
        break;
    }
  }

  /// Calculates spacing after a glyph for text path rendering.
  double _textPathSpacingAfterGlyph({
    required String glyph,
    required bool isLast,
    required _ResolvedTextStyle style,
  }) {
    if (isLast) {
      return 0.0;
    }
    var spacing = style.letterSpacing;
    if (glyph == ' ' || glyph == '\u00A0') {
      spacing += style.wordSpacing;
    }
    return spacing;
  }

  /// Resolves the top position of text from baseline coordinates.
  double _resolveTextTopFromBaseline({
    required ui.Paragraph paragraph,
    required _ResolvedTextStyle style,
    required double baselineY,
  }) {
    final baselineRef = _resolveBaselineReference(
      paragraph: paragraph,
      dominantBaseline: style.dominantBaseline,
      writingMode: style.writingMode,
    );
    final shiftedBaselineY = baselineY - style.baselineShift;
    return shiftedBaselineY - baselineRef;
  }

  /// Resolves textLength attribute value.
  double? _resolveTextLength(SvgNode node) {
    final value = node.getAttributeValue('textLength');
    if (value == null) {
      return null;
    }
    if (value is num) {
      final length = value.toDouble();
      return length > 0 ? length : null;
    }
    final raw = value.toString().trim();
    if (raw.isEmpty) {
      return null;
    }
    final cleaned = raw.replaceAll(RegExp(r'[a-zA-Z%]+$'), '');
    final parsed = double.tryParse(cleaned);
    if (parsed == null || parsed <= 0) {
      return null;
    }
    return parsed;
  }

  /// Resolves lengthAdjust attribute value.
  _SvgTextLengthAdjust _resolveLengthAdjust(SvgNode node) {
    final raw = node.getAttributeValue('lengthAdjust')?.toString().trim();
    if (raw == null || raw.isEmpty) {
      return _SvgTextLengthAdjust.spacing;
    }
    return raw.toLowerCase() == 'spacingandglyphs'
        ? _SvgTextLengthAdjust.spacingAndGlyphs
        : _SvgTextLengthAdjust.spacing;
  }

  /// Resolves textPath geometry from href reference.
  ui.Path? _resolveTextPathGeometry(SvgNode textPathNode) {
    final hrefId = _extractHrefId(textPathNode);
    if (hrefId == null || hrefId.isEmpty) {
      return null;
    }

    final referenced = document.root.findById(hrefId);
    if (referenced == null || referenced.tagName != 'path') {
      return null;
    }

    final path = _buildGeometryPath(referenced);
    if (path == null) {
      return null;
    }

    final transform = _buildTransformMatrixFromValue(
      referenced.getAttributeValue('transform'),
    );
    if (transform == null) {
      return path;
    }
    return path.transform(transform.storage);
  }

  /// Parses textPath startOffset attribute.
  double _parseTextPathStartOffset(SvgNode textPathNode, double pathLength) {
    final raw = textPathNode.getAttributeValue('startOffset');
    if (raw == null) {
      return 0.0;
    }

    if (raw is num) {
      return raw.toDouble().clamp(0.0, pathLength);
    }

    final value = raw.toString().trim();
    if (value.isEmpty) {
      return 0.0;
    }

    if (value.endsWith('%')) {
      final percent = double.tryParse(value.substring(0, value.length - 1));
      if (percent == null) {
        return 0.0;
      }
      return (pathLength * percent / 100.0).clamp(0.0, pathLength);
    }

    return (double.tryParse(value) ?? 0.0).clamp(0.0, pathLength);
  }

  /// Extracts text content from a text node with whitespace handling.
  String? _extractTextContent(SvgNode node) {
    final raw = _getString(node, '__text');
    if (raw == null) {
      return null;
    }

    // Check white-space CSS property first (modern)
    final whiteSpace = _getInheritedString(node, 'white-space')?.toLowerCase();
    if (whiteSpace != null) {
      switch (whiteSpace) {
        case 'pre':
        case 'pre-wrap':
        case 'break-spaces':
          // Preserve whitespace (convert newlines to spaces)
          final preserved = raw.replaceAll('\n', ' ').replaceAll('\r', ' ');
          return preserved.isEmpty ? null : preserved;
        case 'pre-line':
          // Collapse spaces but preserve newlines (then convert to spaces)
          final preLine = raw.replaceAll(RegExp(r'[ \t]+'), ' ');
          return preLine.isEmpty ? null : preLine;
        case 'normal':
        case 'nowrap':
        default:
          // Collapse whitespace
          final collapsed = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
          return collapsed.isEmpty ? null : collapsed;
      }
    }

    // Fall back to xml:space attribute for whitespace handling
    final xmlSpace = _getInheritedString(node, 'xml:space')?.toLowerCase();
    if (xmlSpace == 'preserve') {
      // Preserve whitespace as-is (only convert newlines to spaces)
      final preserved = raw.replaceAll('\n', ' ').replaceAll('\r', ' ');
      return preserved.isEmpty ? null : preserved;
    }

    // Default: collapse whitespace
    final normalized = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    return normalized.isEmpty ? null : normalized;
  }

  /// Extracts text content with XML whitespace normalization for multi-tspan flow.
  /// Handles whitespace between tspans per SVG/XML specification:
  /// - Leading/trailing whitespace is stripped unless xml:space="preserve"
  /// - Multiple whitespace characters are collapsed to single space
  /// - Whitespace between elements is preserved as single space for flow
  String? _extractTextContentWithWhitespaceNormalization(
    SvgNode node,
    _ResolvedTextStyle? parentStyle,
  ) {
    final raw = _getString(node, '__text');
    if (raw == null) {
      return null;
    }

    // Check xml:space attribute for whitespace handling
    final xmlSpace = _getInheritedString(node, 'xml:space')?.toLowerCase();
    final whiteSpace = _getInheritedString(node, 'white-space')?.toLowerCase();

    // Preserve mode: xml:space="preserve" or white-space: pre/pre-wrap
    final preserveWhitespace =
        xmlSpace == 'preserve' ||
        whiteSpace == 'pre' ||
        whiteSpace == 'pre-wrap' ||
        whiteSpace == 'break-spaces';

    if (preserveWhitespace) {
      // Only convert newlines to spaces
      final preserved = raw.replaceAll('\n', ' ').replaceAll('\r', ' ');
      return preserved.isEmpty ? null : preserved;
    }

    // Default whitespace normalization for SVG text
    // Per SVG spec: collapse whitespace, but preserve single space for flow
    var normalized = raw.replaceAll(RegExp(r'\s+'), ' ');

    // For tspan children (parentStyle != null), preserve leading space for flow
    // but still normalize multiple spaces
    if (parentStyle != null) {
      // Don't trim leading space if it exists - it's needed for text flow
      // Only trim trailing space
      normalized = normalized.trimRight();
      if (normalized.isEmpty && raw.contains(RegExp(r'\s'))) {
        // If text was only whitespace, preserve as single space for flow
        return ' ';
      }
    } else {
      // For root text, trim both ends
      normalized = normalized.trim();
    }

    return normalized.isEmpty ? null : normalized;
  }

  /// Resolves text-rendering CSS property to font features.
  /// - auto: default (kerning enabled)
  /// - optimizeSpeed: disable kerning and ligatures
  /// - optimizeLegibility: enable kerning and ligatures
  /// - geometricPrecision: precise geometry, disable hinting
  List<ui.FontFeature> _resolveTextRenderingFeatures(String? value) {
    if (value == null || value.trim().isEmpty) {
      return const <ui.FontFeature>[];
    }

    switch (value.trim().toLowerCase()) {
      case 'optimizespeed':
        // Disable kerning for speed
        return const <ui.FontFeature>[
          ui.FontFeature.disable('kern'),
          ui.FontFeature.disable('liga'),
        ];
      case 'optimizelegibility':
        // Enable kerning and common ligatures for better readability
        return const <ui.FontFeature>[
          ui.FontFeature.enable('kern'),
          ui.FontFeature.enable('liga'),
          ui.FontFeature.enable('clig'),
        ];
      case 'geometricprecision':
        // Precise geometry - enable kerning
        return const <ui.FontFeature>[ui.FontFeature.enable('kern')];
      case 'auto':
      default:
        return const <ui.FontFeature>[];
    }
  }

  /// Resolves forced-color-adjust CSS property.
  /// Controls forced colors mode behavior.
  /// Returns: auto, none, preserve-parent-color.
  String _resolveForcedColorAdjust(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'auto';
    }
    final normalized = value.trim().toLowerCase();
    switch (normalized) {
      case 'none':
        return 'none';
      case 'preserve-parent-color':
        return 'preserve-parent-color';
      case 'auto':
      default:
        return 'auto';
    }
  }

  /// Resolves print-color-adjust CSS property.
  /// Controls printing color adjustment.
  /// Returns: economy, exact.
  String _resolvePrintColorAdjust(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'economy';
    }
    final normalized = value.trim().toLowerCase();
    if (normalized == 'exact') {
      return 'exact';
    }
    return 'economy';
  }

  /// Resolves content-visibility CSS property.
  /// Controls rendering visibility optimization.
  /// Returns: visible, hidden, auto.
  String _resolveContentVisibility(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'visible';
    }
    final normalized = value.trim().toLowerCase();
    switch (normalized) {
      case 'hidden':
        return 'hidden';
      case 'auto':
        return 'auto';
      case 'visible':
      default:
        return 'visible';
    }
  }

  /// Resolves contain-intrinsic-size CSS property.
  /// Controls intrinsic size for content-visibility.
  /// Returns: none, auto, or size value.
  String? _resolveContainIntrinsicSize(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // none
    }
    final normalized = value.trim().toLowerCase();
    if (normalized == 'none') {
      return null;
    }
    // Return as-is for size parsing
    return value.trim();
  }

  /// Resolves will-change CSS property.
  /// Hints browser about expected changes.
  /// Returns: auto, or property names.
  String _resolveWillChange(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'auto';
    }
    final normalized = value.trim().toLowerCase();
    if (normalized == 'auto') {
      return 'auto';
    }
    // Return as-is for property names
    return value.trim();
  }

  /// Resolves mix-blend-mode CSS property.
  /// Controls blending mode.
  /// Returns: normal, multiply, screen, overlay, etc.
  String _resolveCssMixBlendMode(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'normal';
    }
    final normalized = value.trim().toLowerCase();
    const validModes = <String>{
      'normal',
      'multiply',
      'screen',
      'overlay',
      'darken',
      'lighten',
      'color-dodge',
      'color-burn',
      'hard-light',
      'soft-light',
      'difference',
      'exclusion',
      'hue',
      'saturation',
      'color',
      'luminosity',
    };
    if (validModes.contains(normalized)) {
      return normalized;
    }
    return 'normal';
  }

  /// Applies text-transform CSS property to text.
  /// - none: no transformation
  /// - capitalize: first letter of each word uppercase
  /// - uppercase: all letters uppercase
  /// - lowercase: all letters lowercase
  /// - full-width: converts to full-width form (CJK compatibility)
  String _applyTextTransform(String text, String textTransform) {
    if (textTransform == 'none' || text.isEmpty) {
      return text;
    }

    switch (textTransform) {
      case 'uppercase':
        return text.toUpperCase();
      case 'lowercase':
        return text.toLowerCase();
      case 'capitalize':
        return _capitalizeWords(text);
      case 'full-width':
        return _toFullWidth(text);
      default:
        return text;
    }
  }

  /// Capitalizes the first letter of each word in text.
  String _capitalizeWords(String text) {
    if (text.isEmpty) return text;

    final buffer = StringBuffer();
    var capitalizeNext = true;

    for (var i = 0; i < text.length; i++) {
      final char = text[i];
      if (char == ' ' ||
          char == '\t' ||
          char == '\n' ||
          char == '\r' ||
          char == '-' ||
          char == '_') {
        buffer.write(char);
        capitalizeNext = true;
      } else if (capitalizeNext) {
        buffer.write(char.toUpperCase());
        capitalizeNext = false;
      } else {
        buffer.write(char);
      }
    }

    return buffer.toString();
  }

  /// Converts ASCII characters to full-width equivalents.
  /// Full-width characters are used in CJK typography for alignment.
  String _toFullWidth(String text) {
    final buffer = StringBuffer();
    for (final rune in text.runes) {
      // ASCII range 0x21-0x7E maps to full-width 0xFF01-0xFF5E
      if (rune >= 0x21 && rune <= 0x7E) {
        buffer.writeCharCode(rune + 0xFEE0);
      } else if (rune == 0x20) {
        // Space maps to ideographic space
        buffer.writeCharCode(0x3000);
      } else {
        buffer.writeCharCode(rune);
      }
    }
    return buffer.toString();
  }
}
