part of 'animated_svg_painter.dart';

/// Main text style resolution extension for SVG text rendering.
///
/// This extension provides the main `_resolveTextStyle` method that
/// orchestrates resolution of all text-related CSS properties by
/// delegating to specialized resolver methods in the part files:
/// - animated_svg_painter_text_style_font.dart - font property resolvers
/// - animated_svg_painter_text_style_decoration.dart - text decoration resolvers
/// - animated_svg_painter_text_style_layout.dart - text layout resolvers
/// - animated_svg_painter_text_style_positioning.dart - text positioning resolvers
/// - animated_svg_painter_text_style_rendering.dart - paragraph building/rendering
///
/// Also provides helpers for BiDi (bidirectional) text support:
/// - Effective anchor calculation for RTL text
/// - Direction-aware positioning
/// - Mixed direction tspan handling
extension AnimatedSvgPainterTextStyleExtension on AnimatedSvgPainter {
  /// Resolves all text style properties for an SVG node.
  ///
  /// This method gathers all relevant CSS properties for text rendering
  /// and returns a [_ResolvedTextStyle] containing the computed values.
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
    final fontFamily = _resolveFontFamily(
      _getInheritedString(node, 'font-family'),
    );
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
    final fontFeatureSettings = _resolveFontFeatureSettings(
      _getInheritedString(node, 'font-feature-settings'),
    );
    // Merge font features from font-variant, text-rendering, and font-feature-settings
    final allFontFeatures = <ui.FontFeature>[
      ...fontFeatures,
      ...textRenderingFeatures,
      ...fontFeatureSettings,
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

  /// Computes the effective text anchor for RTL text direction.
  ///
  /// Per SVG spec, when direction is RTL:
  /// - `start` means right-aligned (end of inline direction)
  /// - `end` means left-aligned (start of inline direction)
  /// - `middle` remains centered
  ///
  /// This is used during rendering to properly position text chunks.
  // ignore: unused_element
  _SvgTextAnchor _computeEffectiveAnchor(
    _SvgTextAnchor anchor,
    ui.TextDirection direction,
  ) {
    if (direction == ui.TextDirection.ltr) {
      return anchor;
    }
    // RTL mode: swap start and end
    switch (anchor) {
      case _SvgTextAnchor.start:
        return _SvgTextAnchor.end;
      case _SvgTextAnchor.end:
        return _SvgTextAnchor.start;
      case _SvgTextAnchor.middle:
        return _SvgTextAnchor.middle;
    }
  }

  /// Checks if a resolved text style is for RTL direction.
  // ignore: unused_element
  bool _isRtlStyle(_ResolvedTextStyle style) {
    return style.textDirection == ui.TextDirection.rtl;
  }

  /// Resolves text direction from a node, considering inheritance.
  ///
  /// The direction attribute can be set on:
  /// - The text element itself
  /// - A parent tspan element
  /// - A parent g element
  /// - Via CSS style attribute
  ui.TextDirection _resolveEffectiveTextDirection(SvgNode node) {
    final dirValue = _getInheritedString(node, 'direction');
    return _resolveTextDirection(dirValue);
  }

  /// Computes per-character position adjustment for RTL text.
  ///
  /// For RTL text with per-character positioning (dx/dy lists),
  /// the positions need to be applied in visual order, which is
  /// opposite to the logical order for RTL scripts.
  ///
  /// [positions] - List of dx or dy values
  /// [charCount] - Number of characters in the text
  /// [isRtl] - Whether the text direction is RTL
  ///
  /// Returns adjusted positions list for rendering order.
  // ignore: unused_element
  List<double> _adjustPositionsForDirection(
    List<double> positions,
    int charCount,
    bool isRtl,
  ) {
    if (!isRtl || positions.isEmpty) {
      return positions;
    }
    // For RTL text, the positions are applied in visual (reversed) order
    // but we keep the same relative positioning semantics
    return positions;
  }

  /// Determines if a tspan introduces a direction change from its parent.
  ///
  /// This is important for proper BiDi rendering where nested tspans
  /// may have different directions.
  // ignore: unused_element
  bool _hasDirectionChange(SvgNode node, _ResolvedTextStyle? parentStyle) {
    if (parentStyle == null) return false;

    final nodeDirection = _resolveEffectiveTextDirection(node);
    return nodeDirection != parentStyle.textDirection;
  }
}
