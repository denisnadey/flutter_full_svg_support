part of 'animated_svg_painter.dart';

extension AnimatedSvgPainterTextStyleExtension on AnimatedSvgPainter {
  _ResolvedTextStyle _resolveTextStyle(SvgNode node) {
    final fontSize = (_getInheritedNumber(node, 'font-size') ?? 16.0).clamp(
      1.0,
      4096.0,
    );
    final fillValue = _getInheritedAttributeValue(node, 'fill');
    final fillColor =
        _resolveColorForNode(fillValue, node) ?? const ui.Color(0xFF000000);
    final opacity = (_getInheritedNumber(node, 'opacity') ?? 1.0).clamp(
      0.0,
      1.0,
    );
    final fillOpacity = (_getInheritedNumber(node, 'fill-opacity') ?? 1.0)
        .clamp(0.0, 1.0);
    final color = _applyOpacity(fillColor, opacity * fillOpacity);
    final fontFamily = _getInheritedString(node, 'font-family');
    final fontWeight = _resolveFontWeight(
      _getInheritedString(node, 'font-weight'),
    );
    final fontStyle = _resolveFontStyle(
      _getInheritedString(node, 'font-style'),
    );
    final textAnchor = _resolveTextAnchor(
      _getInheritedString(node, 'text-anchor'),
    );
    final dominantBaseline = _resolveDominantBaseline(
      _getInheritedString(node, 'dominant-baseline') ??
          _getInheritedString(node, 'alignment-baseline'),
    );
    final lineHeight = _resolveLineHeight(
      _getInheritedString(node, 'line-height'),
      fontSize,
    );
    final baselineShift = _resolveBaselineShift(
      _getInheritedAttributeValue(node, 'baseline-shift'),
      fontSize,
      lineHeight: lineHeight,
    );
    final letterSpacing = (_getInheritedNumber(node, 'letter-spacing') ?? 0.0)
        .clamp(-1024.0, 1024.0);
    final wordSpacing = (_getInheritedNumber(node, 'word-spacing') ?? 0.0)
        .clamp(-1024.0, 1024.0);
    final decorations = _resolveTextDecoration(
      _getInheritedString(node, 'text-decoration'),
    );
    final decorationColorValue = _getInheritedAttributeValue(
      node,
      'text-decoration-color',
    );
    final decorationColor = decorationColorValue != null
        ? _resolveColorForNode(decorationColorValue, node)
        : null;
    final writingMode = _resolveWritingMode(
      _getInheritedString(node, 'writing-mode'),
    );
    final fontFeatures = _resolveFontVariant(
      _getInheritedString(node, 'font-variant'),
    );
    final textRenderingFeatures = _resolveTextRenderingFeatures(
      _getInheritedString(node, 'text-rendering'),
    );
    // Merge font features from font-variant and text-rendering
    final allFontFeatures = <ui.FontFeature>[
      ...fontFeatures,
      ...textRenderingFeatures,
    ];
    final textDirection = _resolveTextDirection(
      _getInheritedString(node, 'direction'),
    );
    final glyphOrientationVertical = _resolveGlyphOrientationVertical(
      _getInheritedString(node, 'glyph-orientation-vertical'),
    );
    final unicodeBidi = _resolveUnicodeBidi(
      _getInheritedString(node, 'unicode-bidi'),
    );
    final fontStretch = _resolveFontStretch(
      _getInheritedString(node, 'font-stretch'),
    );
    final fontSizeAdjust = _resolveFontSizeAdjust(
      _getInheritedString(node, 'font-size-adjust'),
    );
    final tabSize = _resolveTabSize(_getInheritedString(node, 'tab-size'));
    final textIndent = _resolveTextIndent(
      _getInheritedString(node, 'text-indent'),
      fontSize,
    );
    final wordBreak = _resolveWordBreak(
      _getInheritedString(node, 'word-break'),
    );
    // overflow-wrap, also check word-wrap as legacy fallback
    final overflowWrap = _resolveOverflowWrap(
      _getInheritedString(node, 'overflow-wrap') ??
          _getInheritedString(node, 'word-wrap'),
    );
    final textTransform = _resolveTextTransform(
      _getInheritedString(node, 'text-transform'),
    );
    final hyphens = _resolveHyphens(_getInheritedString(node, 'hyphens'));
    final lineBreak = _resolveLineBreak(
      _getInheritedString(node, 'line-break'),
    );
    final hangingPunctuation = _resolveHangingPunctuation(
      _getInheritedString(node, 'hanging-punctuation'),
    );
    final textCombineUpright = _resolveTextCombineUpright(
      _getInheritedString(node, 'text-combine-upright'),
    );
    final textOrientation = _resolveTextOrientation(
      _getInheritedString(node, 'text-orientation'),
    );
    final textUnderlinePosition = _resolveTextUnderlinePosition(
      _getInheritedString(node, 'text-underline-position'),
    );
    final textUnderlineOffset = _resolveTextUnderlineOffset(
      _getInheritedString(node, 'text-underline-offset'),
      fontSize,
    );
    final textDecorationThickness = _resolveTextDecorationThickness(
      _getInheritedString(node, 'text-decoration-thickness'),
      fontSize,
    );
    final textDecorationSkipInk = _resolveTextDecorationSkipInk(
      _getInheritedString(node, 'text-decoration-skip-ink'),
    );
    final textDecorationSkip = _resolveTextDecorationSkip(
      _getInheritedString(node, 'text-decoration-skip'),
    );
    final textDecorationStyle = _resolveTextDecorationStyle(
      _getInheritedString(node, 'text-decoration-style'),
    );
    final textShadow = _resolveTextShadow(
      _getInheritedString(node, 'text-shadow'),
    );
    final whiteSpace = _resolveWhiteSpace(
      _getInheritedString(node, 'white-space'),
    );
    final textOverflow = _resolveTextOverflow(
      _getInheritedString(node, 'text-overflow'),
    );
    final verticalAlign = _resolveVerticalAlign(
      _getInheritedString(node, 'vertical-align'),
      fontSize,
    );
    final fontKerning = _resolveFontKerning(
      _getInheritedString(node, 'font-kerning'),
    );
    final fontVariantNumeric = _resolveFontVariantNumeric(
      _getInheritedString(node, 'font-variant-numeric'),
    );
    final textJustify = _resolveTextJustify(
      _getInheritedString(node, 'text-justify'),
    );
    final fontVariantLigatures = _resolveFontVariantLigatures(
      _getInheritedString(node, 'font-variant-ligatures'),
    );
    final fontVariantCaps = _resolveFontVariantCaps(
      _getInheritedString(node, 'font-variant-caps'),
    );
    final fontOpticalSizing = _resolveFontOpticalSizing(
      _getInheritedString(node, 'font-optical-sizing'),
    );
    final paintOrder = _resolvePaintOrder(
      _getInheritedString(node, 'paint-order'),
    );
    final textAlignLast = _resolveTextAlignLast(
      _getInheritedString(node, 'text-align-last'),
    );
    final fontSynthesis = _resolveFontSynthesis(
      _getInheritedString(node, 'font-synthesis'),
    );
    final fontVariantPosition = _resolveFontVariantPosition(
      _getInheritedString(node, 'font-variant-position'),
    );
    final fontVariantEastAsian = _resolveFontVariantEastAsian(
      _getInheritedString(node, 'font-variant-east-asian'),
    );
    final textEmphasis = _resolveTextEmphasis(
      _getInheritedString(node, 'text-emphasis'),
    );
    final textEmphasisPosition = _resolveTextEmphasisPosition(
      _getInheritedString(node, 'text-emphasis-position'),
    );
    final textEmphasisColor = _resolveTextEmphasisColor(
      _getInheritedString(node, 'text-emphasis-color'),
    );
    final rubyAlign = _resolveRubyAlign(
      _getInheritedString(node, 'ruby-align'),
    );
    final rubyPosition = _resolveRubyPosition(
      _getInheritedString(node, 'ruby-position'),
    );
    final textEmphasisStyle = _resolveTextEmphasisStyle(
      _getInheritedString(node, 'text-emphasis-style'),
    );
    final quotes = _resolveQuotes(_getInheritedString(node, 'quotes'));
    final initialLetter = _resolveInitialLetter(
      _getInheritedString(node, 'initial-letter'),
    );
    final textSpacing = _resolveTextSpacing(
      _getInheritedString(node, 'text-spacing'),
    );
    final fontLanguageOverride = _resolveFontLanguageOverride(
      _getInheritedString(node, 'font-language-override'),
    );
    final fontVariantAlternates = _resolveFontVariantAlternates(
      _getInheritedString(node, 'font-variant-alternates'),
    );
    final textWrap = _resolveTextWrap(_getInheritedString(node, 'text-wrap'));
    final fontPalette = _resolveFontPalette(
      _getInheritedString(node, 'font-palette'),
    );
    final forcedColorAdjust = _resolveForcedColorAdjust(
      _getInheritedString(node, 'forced-color-adjust'),
    );
    final printColorAdjust = _resolvePrintColorAdjust(
      _getInheritedString(node, 'print-color-adjust'),
    );
    final textDecorationLine = _resolveTextDecorationLine(
      _getInheritedString(node, 'text-decoration-line'),
    );
    final fontVariationSettings = _resolveFontVariationSettings(
      _getInheritedString(node, 'font-variation-settings'),
    );
    final cssTextDecorationColor = _resolveCssTextDecorationColor(
      _getInheritedString(node, 'text-decoration-color'),
    );
    final cssDirection = _resolveCssDirection(
      _getInheritedString(node, 'direction'),
    );
    final contentVisibility = _resolveContentVisibility(
      _getInheritedString(node, 'content-visibility'),
    );
    final containIntrinsicSize = _resolveContainIntrinsicSize(
      _getInheritedString(node, 'contain-intrinsic-size'),
    );
    final willChange = _resolveWillChange(
      _getInheritedString(node, 'will-change'),
    );
    final hyphenateCharacter = _resolveHyphenateCharacter(
      _getInheritedString(node, 'hyphenate-character'),
    );
    final cssMixBlendMode = _resolveCssMixBlendMode(
      _getInheritedString(node, 'mix-blend-mode'),
    );

    return _ResolvedTextStyle(
      color: color,
      fontSize: fontSize,
      fontFamily: fontFamily,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      textAnchor: textAnchor,
      dominantBaseline: dominantBaseline,
      baselineShift: baselineShift,
      letterSpacing: letterSpacing,
      wordSpacing: wordSpacing,
      decorations: decorations,
      decorationColor: decorationColor,
      writingMode: writingMode,
      fontFeatures: allFontFeatures,
      textDirection: textDirection,
      glyphOrientationVertical: glyphOrientationVertical,
      unicodeBidi: unicodeBidi,
      fontStretch: fontStretch,
      fontSizeAdjust: fontSizeAdjust,
      tabSize: tabSize,
      textIndent: textIndent,
      wordBreak: wordBreak,
      overflowWrap: overflowWrap,
      textTransform: textTransform,
      hyphens: hyphens,
      lineBreak: lineBreak,
      hangingPunctuation: hangingPunctuation,
      textCombineUpright: textCombineUpright,
      textOrientation: textOrientation,
      textUnderlinePosition: textUnderlinePosition,
      textUnderlineOffset: textUnderlineOffset,
      textDecorationThickness: textDecorationThickness,
      textDecorationSkipInk: textDecorationSkipInk,
      textDecorationSkip: textDecorationSkip,
      textDecorationStyle: textDecorationStyle,
      textShadow: textShadow,
      whiteSpace: whiteSpace,
      textOverflow: textOverflow,
      verticalAlign: verticalAlign,
      lineHeight: lineHeight,
      fontKerning: fontKerning,
      fontVariantNumeric: fontVariantNumeric,
      textJustify: textJustify,
      fontVariantLigatures: fontVariantLigatures,
      fontVariantCaps: fontVariantCaps,
      fontOpticalSizing: fontOpticalSizing,
      paintOrder: paintOrder,
      textAlignLast: textAlignLast,
      fontSynthesis: fontSynthesis,
      fontVariantPosition: fontVariantPosition,
      fontVariantEastAsian: fontVariantEastAsian,
      textEmphasis: textEmphasis,
      textEmphasisPosition: textEmphasisPosition,
      textEmphasisColor: textEmphasisColor,
      rubyAlign: rubyAlign,
      rubyPosition: rubyPosition,
      textEmphasisStyle: textEmphasisStyle,
      quotes: quotes,
      initialLetter: initialLetter,
      textSpacing: textSpacing,
      fontLanguageOverride: fontLanguageOverride,
      fontVariantAlternates: fontVariantAlternates,
      textWrap: textWrap,
      fontPalette: fontPalette,
      forcedColorAdjust: forcedColorAdjust,
      printColorAdjust: printColorAdjust,
      textDecorationLine: textDecorationLine,
      fontVariationSettings: fontVariationSettings,
      cssTextDecorationColor: cssTextDecorationColor,
      cssDirection: cssDirection,
      contentVisibility: contentVisibility,
      containIntrinsicSize: containIntrinsicSize,
      willChange: willChange,
      hyphenateCharacter: hyphenateCharacter,
      cssMixBlendMode: cssMixBlendMode,
    );
  }

  _SvgWritingMode _resolveWritingMode(String? value) {
    if (value == null || value.trim().isEmpty) {
      return _SvgWritingMode.horizontalTb;
    }
    switch (value.trim().toLowerCase()) {
      case 'vertical-rl':
      case 'tb-rl': // legacy SVG 1.1
        return _SvgWritingMode.verticalRl;
      case 'vertical-lr':
      case 'tb': // legacy SVG 1.1
        return _SvgWritingMode.verticalLr;
      case 'horizontal-tb':
      case 'lr-tb': // legacy SVG 1.1
      case 'lr': // legacy
      default:
        return _SvgWritingMode.horizontalTb;
    }
  }

  /// Resolves font-variant CSS property to Flutter FontFeatures.
  /// Supports: normal, small-caps, all-small-caps, petite-caps, all-petite-caps,
  /// unicase, titling-caps
  List<ui.FontFeature> _resolveFontVariant(String? value) {
    if (value == null || value.trim().isEmpty || value.trim() == 'normal') {
      return const <ui.FontFeature>[];
    }

    final features = <ui.FontFeature>[];
    final parts = value.toLowerCase().split(RegExp(r'\s+'));

    for (final part in parts) {
      switch (part.trim()) {
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
        case 'oldstyle-nums':
          features.add(const ui.FontFeature.oldstyleFigures());
          break;
        case 'lining-nums':
          features.add(const ui.FontFeature.liningFigures());
          break;
        case 'tabular-nums':
          features.add(const ui.FontFeature.tabularFigures());
          break;
        case 'proportional-nums':
          features.add(const ui.FontFeature.proportionalFigures());
          break;
      }
    }

    return features;
  }

  /// Resolves direction CSS property to Flutter TextDirection.
  /// Supports: ltr (default), rtl
  ui.TextDirection _resolveTextDirection(String? value) {
    if (value == null || value.trim().isEmpty) {
      return ui.TextDirection.ltr;
    }
    switch (value.trim().toLowerCase()) {
      case 'rtl':
        return ui.TextDirection.rtl;
      case 'ltr':
      default:
        return ui.TextDirection.ltr;
    }
  }

  /// Resolves glyph-orientation-vertical attribute.
  /// Returns angle in degrees for vertical text glyph rotation.
  /// - auto: automatic (returns null, handled by layout)
  /// - 0deg, 0: upright glyphs
  /// - 90deg, 90: rotated 90 degrees clockwise
  double? _resolveGlyphOrientationVertical(String? value) {
    if (value == null ||
        value.trim().isEmpty ||
        value.trim().toLowerCase() == 'auto') {
      return null; // auto orientation
    }
    final normalized = value.trim().toLowerCase().replaceAll('deg', '');
    return double.tryParse(normalized);
  }

  /// Resolves unicode-bidi attribute for bidirectional text handling.
  /// Returns Flutter TextDirection modifier or null for normal.
  /// - normal: use inherited direction
  /// - embed: embed a level of directionality
  /// - isolate: isolate from surrounding text
  /// - bidi-override: override inherited direction for all chars
  /// - isolate-override: combine isolate and override
  /// - plaintext: determine direction from first strong character
  String? _resolveUnicodeBidi(String? value) {
    if (value == null ||
        value.trim().isEmpty ||
        value.trim().toLowerCase() == 'normal') {
      return null;
    }
    return value.trim().toLowerCase();
  }

  /// Resolves font-stretch attribute to width percentage.
  /// Returns width as percentage (100 = normal).
  /// Supports keywords and percentage values.
  double _resolveFontStretch(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 100.0; // normal
    }
    final normalized = value.trim().toLowerCase();

    // Handle percentage values
    if (normalized.endsWith('%')) {
      final numStr = normalized.substring(0, normalized.length - 1);
      return double.tryParse(numStr)?.clamp(50.0, 200.0) ?? 100.0;
    }

    // Handle keyword values
    switch (normalized) {
      case 'ultra-condensed':
        return 50.0;
      case 'extra-condensed':
        return 62.5;
      case 'condensed':
        return 75.0;
      case 'semi-condensed':
        return 87.5;
      case 'normal':
        return 100.0;
      case 'semi-expanded':
        return 112.5;
      case 'expanded':
        return 125.0;
      case 'extra-expanded':
        return 150.0;
      case 'ultra-expanded':
        return 200.0;
      default:
        return double.tryParse(normalized)?.clamp(50.0, 200.0) ?? 100.0;
    }
  }

  /// Resolves font-size-adjust attribute.
  /// Returns aspect ratio value (x-height / font-size) or null if none.
  /// This is used to scale font size to maintain consistent x-height
  /// when fallback fonts have different aspect ratios.
  double? _resolveFontSizeAdjust(String? value) {
    if (value == null ||
        value.trim().isEmpty ||
        value.trim().toLowerCase() == 'none') {
      return null;
    }
    return double.tryParse(value.trim());
  }

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

  /// Resolves text-combine-upright CSS property for vertical writing.
  /// Returns combination mode (none, all, digits <count>).
  String _resolveTextCombineUpright(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'none';
    }
    final normalized = value.trim().toLowerCase();
    if (normalized == 'all') {
      return 'all';
    }
    // Check for "digits" with optional count
    if (normalized.startsWith('digits')) {
      final match = RegExp(r'digits\s*(\d+)?').firstMatch(normalized);
      if (match != null) {
        final count = match.group(1);
        return count != null ? 'digits $count' : 'digits 2';
      }
    }
    return 'none';
  }

  /// Resolves text-orientation CSS property for vertical writing.
  /// Returns orientation mode (mixed, upright, sideways).
  String _resolveTextOrientation(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'mixed';
    }
    final normalized = value.trim().toLowerCase();
    switch (normalized) {
      case 'upright':
      case 'sideways':
      case 'sideways-right': // Legacy alias
        return normalized == 'sideways-right' ? 'sideways' : normalized;
      case 'mixed':
      default:
        return 'mixed';
    }
  }

  /// Resolves text-underline-position CSS property.
  /// Returns underline position (auto, under, left, right).
  String _resolveTextUnderlinePosition(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'auto';
    }
    final normalized = value.trim().toLowerCase();
    // Can have multiple values like "under left"
    final parts = normalized.split(RegExp(r'\s+'));
    final validValues = <String>{};
    for (final part in parts) {
      switch (part) {
        case 'under':
        case 'left':
        case 'right':
        case 'from-font':
          validValues.add(part);
          break;
        case 'auto':
          return 'auto';
      }
    }
    return validValues.isEmpty ? 'auto' : validValues.join(' ');
  }

  /// Resolves text-underline-offset CSS property.
  /// Returns offset value in user units or null for auto.
  double? _resolveTextUnderlineOffset(String? value, double fontSize) {
    if (value == null ||
        value.trim().isEmpty ||
        value.trim().toLowerCase() == 'auto') {
      return null;
    }
    final normalized = value.trim().toLowerCase();
    // Handle em units
    if (normalized.endsWith('em')) {
      final numStr = normalized.substring(0, normalized.length - 2);
      return (double.tryParse(numStr) ?? 0.0) * fontSize;
    }
    // Handle px units
    if (normalized.endsWith('px')) {
      final numStr = normalized.substring(0, normalized.length - 2);
      return double.tryParse(numStr);
    }
    // Plain number treated as px
    return double.tryParse(normalized);
  }

  /// Resolves text-decoration-thickness CSS property.
  /// Returns thickness value in user units or null for auto/from-font.
  double? _resolveTextDecorationThickness(String? value, double fontSize) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    final normalized = value.trim().toLowerCase();
    if (normalized == 'auto' || normalized == 'from-font') {
      return null;
    }
    // Handle em units
    if (normalized.endsWith('em')) {
      final numStr = normalized.substring(0, normalized.length - 2);
      return (double.tryParse(numStr) ?? 0.0) * fontSize;
    }
    // Handle px units
    if (normalized.endsWith('px')) {
      final numStr = normalized.substring(0, normalized.length - 2);
      return double.tryParse(numStr);
    }
    // Handle percentage (relative to 1em)
    if (normalized.endsWith('%')) {
      final pctStr = normalized.substring(0, normalized.length - 1);
      final pct = double.tryParse(pctStr);
      if (pct != null) {
        return fontSize * pct / 100;
      }
      return null;
    }
    // Plain number treated as px
    return double.tryParse(normalized);
  }

  /// Resolves text-decoration-skip-ink CSS property.
  /// Controls how underlines/overlines interact with glyph descenders/ascenders.
  /// Returns: auto, all, or none.
  String _resolveTextDecorationSkipInk(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'auto';
    }
    final normalized = value.trim().toLowerCase();
    switch (normalized) {
      case 'all':
        return 'all';
      case 'none':
        return 'none';
      case 'auto':
      default:
        return 'auto';
    }
  }

  /// Resolves text-decoration-skip CSS property.
  /// Controls what elements text decoration lines skip over.
  /// Returns space-separated values: none, objects, spaces, leading-spaces,
  /// trailing-spaces, edges, box-decoration.
  String _resolveTextDecorationSkip(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'objects';
    }
    final normalized = value.trim().toLowerCase();
    // Parse valid keywords
    final validKeywords = <String>{
      'none',
      'objects',
      'spaces',
      'leading-spaces',
      'trailing-spaces',
      'edges',
      'box-decoration',
    };
    if (normalized == 'none') {
      return 'none';
    }
    final parts = normalized.split(RegExp(r'\s+'));
    final result = parts.where((p) => validKeywords.contains(p)).toList();
    return result.isEmpty ? 'objects' : result.join(' ');
  }

  /// Resolves text-decoration-style CSS property.
  /// Controls the style of the decoration line.
  /// Returns: solid, double, dotted, dashed, or wavy.
  String _resolveTextDecorationStyle(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'solid';
    }
    final normalized = value.trim().toLowerCase();
    switch (normalized) {
      case 'double':
        return 'double';
      case 'dotted':
        return 'dotted';
      case 'dashed':
        return 'dashed';
      case 'wavy':
        return 'wavy';
      case 'solid':
      default:
        return 'solid';
    }
  }

  /// Resolves text-shadow CSS property.
  /// Returns normalized shadow string or null for none.
  /// Format: "offset-x offset-y blur-radius color" (multiple comma-separated)
  String? _resolveTextShadow(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    final normalized = value.trim().toLowerCase();
    if (normalized == 'none' ||
        normalized == 'inherit' ||
        normalized == 'initial') {
      return null;
    }
    // Return the value as-is for further processing
    return value.trim();
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

  /// Resolves font-kerning CSS property.
  /// Controls kerning behavior.
  /// Returns: auto, normal, or none.
  String _resolveFontKerning(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'auto';
    }
    final normalized = value.trim().toLowerCase();
    switch (normalized) {
      case 'normal':
        return 'normal';
      case 'none':
        return 'none';
      case 'auto':
      default:
        return 'auto';
    }
  }

  /// Resolves font-variant-numeric CSS property.
  /// Controls numeric glyph variants.
  /// Returns space-separated values or 'normal'.
  String _resolveFontVariantNumeric(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'normal';
    }
    final normalized = value.trim().toLowerCase();
    if (normalized == 'normal' || normalized == 'inherit') {
      return 'normal';
    }
    // Valid keywords for numeric variants
    final validKeywords = <String>{
      'lining-nums',
      'oldstyle-nums',
      'proportional-nums',
      'tabular-nums',
      'diagonal-fractions',
      'stacked-fractions',
      'ordinal',
      'slashed-zero',
    };
    final parts = normalized.split(RegExp(r'\s+'));
    final result = parts.where((p) => validKeywords.contains(p)).toList();
    return result.isEmpty ? 'normal' : result.join(' ');
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

  /// Resolves font-variant-ligatures CSS property.
  /// Controls ligature usage.
  /// Returns: normal, none, or specific ligature keywords.
  String _resolveFontVariantLigatures(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'normal';
    }
    final normalized = value.trim().toLowerCase();
    if (normalized == 'normal' || normalized == 'inherit') {
      return 'normal';
    }
    if (normalized == 'none') {
      return 'none';
    }
    // Valid keywords
    final validKeywords = <String>{
      'common-ligatures',
      'no-common-ligatures',
      'discretionary-ligatures',
      'no-discretionary-ligatures',
      'historical-ligatures',
      'no-historical-ligatures',
      'contextual',
      'no-contextual',
    };
    final parts = normalized.split(RegExp(r'\s+'));
    final result = parts.where((p) => validKeywords.contains(p)).toList();
    return result.isEmpty ? 'normal' : result.join(' ');
  }

  /// Resolves font-variant-caps CSS property.
  /// Controls capital letter glyph variants.
  /// Returns: normal, small-caps, all-small-caps, petite-caps, all-petite-caps, unicase, titling-caps.
  String _resolveFontVariantCaps(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'normal';
    }
    final normalized = value.trim().toLowerCase();
    switch (normalized) {
      case 'small-caps':
        return 'small-caps';
      case 'all-small-caps':
        return 'all-small-caps';
      case 'petite-caps':
        return 'petite-caps';
      case 'all-petite-caps':
        return 'all-petite-caps';
      case 'unicase':
        return 'unicase';
      case 'titling-caps':
        return 'titling-caps';
      case 'normal':
      default:
        return 'normal';
    }
  }

  /// Resolves font-optical-sizing CSS property.
  /// Controls optical sizing.
  /// Returns: auto or none.
  String _resolveFontOpticalSizing(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'auto';
    }
    final normalized = value.trim().toLowerCase();
    if (normalized == 'none') {
      return 'none';
    }
    return 'auto';
  }

  /// Resolves paint-order CSS property.
  /// Controls the order of fill, stroke, and markers.
  /// Returns: normal, or space-separated list of fill/stroke/markers.
  String _resolvePaintOrder(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'normal';
    }
    final normalized = value.trim().toLowerCase();
    if (normalized == 'normal') {
      return 'normal';
    }
    // Valid keywords
    final validKeywords = <String>{'fill', 'stroke', 'markers'};
    final parts = normalized.split(RegExp(r'\s+'));
    final result = parts.where((p) => validKeywords.contains(p)).toList();
    return result.isEmpty ? 'normal' : result.join(' ');
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

  /// Resolves font-synthesis CSS property.
  /// Controls automatic font synthesis.
  /// Returns: none, or space-separated list of weight/style/small-caps.
  String _resolveFontSynthesis(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'weight style small-caps';
    }
    final normalized = value.trim().toLowerCase();
    if (normalized == 'none') {
      return 'none';
    }
    // Valid keywords
    final validKeywords = <String>{'weight', 'style', 'small-caps'};
    final parts = normalized.split(RegExp(r'\s+'));
    final result = parts.where((p) => validKeywords.contains(p)).toList();
    return result.isEmpty ? 'weight style small-caps' : result.join(' ');
  }

  /// Resolves font-variant-position CSS property.
  /// Controls subscript/superscript glyph variants.
  /// Returns: normal, sub, or super.
  String _resolveFontVariantPosition(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'normal';
    }
    final normalized = value.trim().toLowerCase();
    switch (normalized) {
      case 'sub':
        return 'sub';
      case 'super':
        return 'super';
      case 'normal':
      default:
        return 'normal';
    }
  }

  /// Resolves font-variant-east-asian CSS property.
  /// Controls East Asian font variants.
  /// Returns: normal, or space-separated list of keywords.
  String _resolveFontVariantEastAsian(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'normal';
    }
    final normalized = value.trim().toLowerCase();
    if (normalized == 'normal') {
      return 'normal';
    }
    // Valid keywords
    final validKeywords = <String>{
      'jis78',
      'jis83',
      'jis90',
      'jis04',
      'simplified',
      'traditional',
      'full-width',
      'proportional-width',
      'ruby',
    };
    final parts = normalized.split(RegExp(r'\s+'));
    final result = parts.where((p) => validKeywords.contains(p)).toList();
    return result.isEmpty ? 'normal' : result.join(' ');
  }

  /// Resolves text-emphasis CSS property.
  /// Controls emphasis marks for text.
  /// Returns: none, or emphasis style string.
  String? _resolveTextEmphasis(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    final normalized = value.trim().toLowerCase();
    if (normalized == 'none') {
      return null;
    }
    // Return as-is for further processing
    return value.trim();
  }

  /// Resolves text-emphasis-position CSS property.
  /// Controls position of emphasis marks.
  /// Returns: over, under, over right, under left, etc.
  String _resolveTextEmphasisPosition(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'over right';
    }
    final normalized = value.trim().toLowerCase();
    // Valid combinations: over/under + right/left
    final validKeywords = <String>{'over', 'under', 'right', 'left'};
    final parts = normalized.split(RegExp(r'\s+'));
    final result = parts.where((p) => validKeywords.contains(p)).toList();
    return result.isEmpty ? 'over right' : result.join(' ');
  }

  /// Resolves text-emphasis-color CSS property.
  /// Controls color of emphasis marks.
  /// Returns: null for currentColor, or color string.
  String? _resolveTextEmphasisColor(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // currentColor
    }
    final normalized = value.trim().toLowerCase();
    if (normalized == 'currentcolor') {
      return null;
    }
    return value.trim();
  }

  /// Resolves ruby-align CSS property.
  /// Controls alignment of ruby text.
  /// Returns: space-around, start, center, space-between.
  String _resolveRubyAlign(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'space-around';
    }
    final normalized = value.trim().toLowerCase();
    switch (normalized) {
      case 'start':
        return 'start';
      case 'center':
        return 'center';
      case 'space-between':
        return 'space-between';
      case 'space-around':
      default:
        return 'space-around';
    }
  }

  /// Resolves ruby-position CSS property.
  /// Controls position of ruby text.
  /// Returns: over, under, inter-character, alternate.
  String _resolveRubyPosition(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'over';
    }
    final normalized = value.trim().toLowerCase();
    switch (normalized) {
      case 'under':
        return 'under';
      case 'inter-character':
        return 'inter-character';
      case 'alternate':
        return 'alternate';
      case 'over':
      default:
        return 'over';
    }
  }

  /// Resolves text-emphasis-style CSS property.
  /// Controls style of emphasis marks.
  /// Returns: none, filled, open, dot, circle, double-circle, triangle, sesame.
  String? _resolveTextEmphasisStyle(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    final normalized = value.trim().toLowerCase();
    if (normalized == 'none') {
      return null;
    }
    // Return as-is for further processing
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
    // Return as-is for further processing (quote pairs)
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

  /// Resolves font-language-override CSS property.
  /// Controls OpenType language system.
  /// Returns: normal, or language tag.
  String? _resolveFontLanguageOverride(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // normal
    }
    final normalized = value.trim().toLowerCase();
    if (normalized == 'normal') {
      return null;
    }
    // Return as-is for language tag
    return value.trim();
  }

  /// Resolves font-variant-alternates CSS property.
  /// Controls OpenType stylistic alternates.
  /// Returns: normal, or alternate functions.
  String? _resolveFontVariantAlternates(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // normal
    }
    final normalized = value.trim().toLowerCase();
    if (normalized == 'normal') {
      return null;
    }
    // Return as-is for alternate functions
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

  /// Resolves font-palette CSS property.
  /// Controls color font palettes.
  /// Returns: normal, light, dark, or palette name.
  String? _resolveFontPalette(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // normal
    }
    final normalized = value.trim().toLowerCase();
    if (normalized == 'normal') {
      return null;
    }
    if (normalized == 'light' || normalized == 'dark') {
      return normalized;
    }
    // Return as-is for custom palette
    return value.trim();
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

  /// Resolves text-decoration-line CSS property.
  /// Controls which lines to display.
  /// Returns: none, or combination of underline/overline/line-through/blink.
  String _resolveTextDecorationLine(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'none';
    }
    final normalized = value.trim().toLowerCase();
    if (normalized == 'none') {
      return 'none';
    }
    // Valid keywords
    final validKeywords = <String>{
      'underline',
      'overline',
      'line-through',
      'blink',
    };
    final parts = normalized.split(RegExp(r'\s+'));
    final result = parts.where((p) => validKeywords.contains(p)).toList();
    return result.isEmpty ? 'none' : result.join(' ');
  }

  /// Resolves font-variation-settings CSS property.
  /// Controls variable font axes.
  /// Returns: normal, or axis settings string.
  String? _resolveFontVariationSettings(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // normal
    }
    final normalized = value.trim().toLowerCase();
    if (normalized == 'normal') {
      return null;
    }
    // Return as-is for axis settings
    return value.trim();
  }

  /// Resolves text-decoration-color CSS property.
  /// Controls color of text decorations.
  /// Returns: null for currentColor, or color string.
  String? _resolveCssTextDecorationColor(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // currentColor
    }
    final normalized = value.trim().toLowerCase();
    if (normalized == 'currentcolor') {
      return null;
    }
    return value.trim();
  }

  /// Resolves direction CSS property.
  /// Controls text direction.
  /// Returns: ltr or rtl.
  String _resolveCssDirection(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'ltr';
    }
    final normalized = value.trim().toLowerCase();
    if (normalized == 'rtl') {
      return 'rtl';
    }
    return 'ltr';
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

  Set<_SvgTextDecoration> _resolveTextDecoration(String? value) {
    if (value == null || value.trim().isEmpty || value.trim() == 'none') {
      return const <_SvgTextDecoration>{};
    }
    final result = <_SvgTextDecoration>{};
    final parts = value.toLowerCase().split(RegExp(r'\s+'));
    for (final part in parts) {
      switch (part.trim()) {
        case 'underline':
          result.add(_SvgTextDecoration.underline);
          break;
        case 'overline':
          result.add(_SvgTextDecoration.overline);
          break;
        case 'line-through':
          result.add(_SvgTextDecoration.lineThrough);
          break;
      }
    }
    return result;
  }

  ui.TextDecoration _buildTextDecoration(Set<_SvgTextDecoration> decorations) {
    if (decorations.isEmpty) {
      return ui.TextDecoration.none;
    }
    final list = <ui.TextDecoration>[];
    if (decorations.contains(_SvgTextDecoration.underline)) {
      list.add(ui.TextDecoration.underline);
    }
    if (decorations.contains(_SvgTextDecoration.overline)) {
      list.add(ui.TextDecoration.overline);
    }
    if (decorations.contains(_SvgTextDecoration.lineThrough)) {
      list.add(ui.TextDecoration.lineThrough);
    }
    return ui.TextDecoration.combine(list);
  }

  ui.Paragraph _buildTextParagraph(String text, _ResolvedTextStyle style) {
    // Apply font-size-adjust if specified
    // font-size-adjust preserves x-height when font-fallback occurs
    // adjusted-font-size = font-size * (font-size-adjust / actual-aspect-ratio)
    var effectiveFontSize = style.fontSize;
    if (style.fontSizeAdjust != null && style.fontSizeAdjust! > 0) {
      // Estimate aspect ratio (x-height/font-size) - typical value is ~0.48 for many fonts
      // This is a heuristic since Flutter doesn't expose actual x-height
      const estimatedAspectRatio = 0.48;
      effectiveFontSize = style.fontSize * (style.fontSizeAdjust! / estimatedAspectRatio);
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
      text,
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
        fontFeatures: style.fontFeatures.isNotEmpty ? style.fontFeatures : null,
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
        return isRtl
            ? '$fsi$rlo$text$pdf$pdi'
            : '$fsi$lro$text$pdf$pdi';

      case 'plaintext':
        // Determine direction from first strong character
        return '$fsi$text$pdi';

      case 'normal':
      default:
        // Use normal Unicode bidi algorithm
        return text;
    }
  }

  void _drawParagraphWithEffects(
    ui.Canvas canvas, {
    required ui.Paragraph paragraph,
    required double x,
    required double y,
    ui.ImageFilter? imageFilter,
    ui.ColorFilter? colorFilter,
    ui.BlendMode? blendMode,
  }) {
    if (imageFilter == null && colorFilter == null && blendMode == null) {
      canvas.drawParagraph(paragraph, ui.Offset(x, y));
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
    canvas.restore();
  }

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

  double _resolveTextTopFromBaseline({
    required ui.Paragraph paragraph,
    required _ResolvedTextStyle style,
    required double baselineY,
  }) {
    final baselineRef = _resolveBaselineReference(
      paragraph: paragraph,
      dominantBaseline: style.dominantBaseline,
    );
    final shiftedBaselineY = baselineY - style.baselineShift;
    return shiftedBaselineY - baselineRef;
  }

  /// Resolves baseline offset from paragraph metrics.
  /// Returns the y-offset from the paragraph top to the specified baseline.
  double _resolveBaselineReference({
    required ui.Paragraph paragraph,
    required _SvgDominantBaseline dominantBaseline,
  }) {
    // Get font metrics from paragraph
    final height = paragraph.height;
    final alphabeticBaseline = paragraph.alphabeticBaseline;
    final ideographicBaseline = paragraph.ideographicBaseline;

    // Calculate approximate ascent from alphabetic baseline
    // alphabeticBaseline is the distance from top to baseline
    final ascent = alphabeticBaseline;

    // Approximate x-height as ~50% of ascent (typical for Latin fonts)
    final xHeight = ascent * 0.5;

    return switch (dominantBaseline) {
      _SvgDominantBaseline.alphabetic => alphabeticBaseline,
      _SvgDominantBaseline.central => height / 2,
      _SvgDominantBaseline.middle => height / 2,
      _SvgDominantBaseline.textBeforeEdge => 0.0,
      _SvgDominantBaseline.textAfterEdge => height,
      // Hanging baseline: approximately 80% of ascent from top
      // Used for Indic scripts where the main stroke hangs from the top
      _SvgDominantBaseline.hanging => ascent * 0.8,
      // Mathematical baseline: centered on math operators
      // Typically at x-height / 2 + some offset (~50% of x-height above baseline)
      _SvgDominantBaseline.mathematical => alphabeticBaseline - xHeight * 0.5,
      // Ideographic baseline: at the bottom of the ideographic em box
      // Use the ideographicBaseline if available, else approximate
      _SvgDominantBaseline.ideographic => ideographicBaseline,
    };
  }

  /// Resolves dominant-baseline or alignment-baseline attribute value.
  /// SVG 2 spec: https://www.w3.org/TR/SVG2/text.html#DominantBaselineProperty
  _SvgDominantBaseline _resolveDominantBaseline(String? rawValue) {
    switch (rawValue?.trim().toLowerCase()) {
      case 'middle':
        return _SvgDominantBaseline.middle;
      case 'central':
        return _SvgDominantBaseline.central;
      case 'text-before-edge':
      case 'before-edge':
      case 'text-top':
        return _SvgDominantBaseline.textBeforeEdge;
      case 'text-after-edge':
      case 'after-edge':
      case 'text-bottom':
        return _SvgDominantBaseline.textAfterEdge;
      case 'hanging':
        return _SvgDominantBaseline.hanging;
      case 'mathematical':
        return _SvgDominantBaseline.mathematical;
      case 'ideographic':
        return _SvgDominantBaseline.ideographic;
      case 'alphabetic':
      case 'auto':
      default:
        return _SvgDominantBaseline.alphabetic;
    }
  }

  /// Resolves baseline-shift attribute value.
  /// Supports: baseline, sub, super, percentage, length values.
  /// Per SVG spec, percentage is relative to line-height (computed height of line box).
  double _resolveBaselineShift(
    Object? rawValue,
    double fontSize, {
    double? lineHeight,
  }) {
    if (rawValue == null) {
      return 0.0;
    }
    if (rawValue is num) {
      return rawValue.toDouble().clamp(-4096.0, 4096.0);
    }
    final value = rawValue.toString().trim().toLowerCase();
    if (value.isEmpty || value == 'baseline') {
      return 0.0;
    }
    // Subscript: shift down by a factor of font-size
    // Blink uses ~0.3em descent from baseline
    if (value == 'sub') {
      return -fontSize * 0.3;
    }
    // Superscript: shift up by a factor of font-size
    // Blink uses ~0.4em above baseline
    if (value == 'super') {
      return fontSize * 0.4;
    }
    // Percentage: relative to line-height (or 1.2 * fontSize as default)
    if (value.endsWith('%')) {
      final percent = double.tryParse(value.substring(0, value.length - 1));
      if (percent == null) {
        return 0.0;
      }
      // Use line-height if provided, otherwise default to 1.2 * fontSize
      final effectiveLineHeight = lineHeight ?? (fontSize * 1.2);
      return (effectiveLineHeight * percent / 100.0).clamp(-4096.0, 4096.0);
    }
    // em units: relative to font-size
    if (value.endsWith('em')) {
      final em = double.tryParse(value.substring(0, value.length - 2));
      if (em != null) {
        return (fontSize * em).clamp(-4096.0, 4096.0);
      }
      return 0.0;
    }
    // ex units: relative to x-height (~0.5 * font-size)
    if (value.endsWith('ex')) {
      final ex = double.tryParse(value.substring(0, value.length - 2));
      if (ex != null) {
        return (fontSize * 0.5 * ex).clamp(-4096.0, 4096.0);
      }
      return 0.0;
    }
    // Plain number or px: treat as user units
    final numeric = double.tryParse(value.replaceAll(RegExp(r'[a-z]+$'), ''));
    return (numeric ?? 0.0).clamp(-4096.0, 4096.0);
  }

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

  _SvgTextLengthAdjust _resolveLengthAdjust(SvgNode node) {
    final raw = node.getAttributeValue('lengthAdjust')?.toString().trim();
    if (raw == null || raw.isEmpty) {
      return _SvgTextLengthAdjust.spacing;
    }
    return raw.toLowerCase() == 'spacingandglyphs'
        ? _SvgTextLengthAdjust.spacingAndGlyphs
        : _SvgTextLengthAdjust.spacing;
  }

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
}
