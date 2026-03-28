part of 'animated_svg_painter.dart';

class _ResolvedTextStyle {
  const _ResolvedTextStyle({
    required this.color,
    required this.fontSize,
    required this.fontFamily,
    required this.fontWeight,
    required this.fontStyle,
    required this.textAnchor,
    required this.dominantBaseline,
    required this.baselineShift,
    required this.letterSpacing,
    required this.wordSpacing,
    this.decorations = const <_SvgTextDecoration>{},
    this.decorationColor,
    this.writingMode = _SvgWritingMode.horizontalTb,
    this.fontFeatures = const <ui.FontFeature>[],
    this.textDirection = ui.TextDirection.ltr,
    this.glyphOrientationVertical,
    this.unicodeBidi,
    this.fontStretch = 100.0,
    this.fontSizeAdjust,
    this.tabSize = 8,
    this.textIndent = 0.0,
    this.wordBreak = 'normal',
    this.overflowWrap = 'normal',
    this.textTransform = 'none',
    this.hyphens = 'manual',
    this.lineBreak = 'auto',
    this.hangingPunctuation = 'none',
    this.textCombineUpright = 'none',
    this.textOrientation = 'mixed',
    this.textUnderlinePosition = 'auto',
    this.textUnderlineOffset,
    this.textDecorationThickness,
    this.textDecorationSkipInk = 'auto',
    this.textDecorationSkip = 'objects',
    this.textDecorationStyle = 'solid',
    this.textShadow,
    this.whiteSpace = 'normal',
    this.textOverflow = 'clip',
    this.verticalAlign = 0.0,
    this.lineHeight,
    this.fontKerning = 'auto',
    this.fontVariantNumeric = 'normal',
    this.textJustify = 'auto',
    this.fontVariantLigatures = 'normal',
    this.fontVariantCaps = 'normal',
    this.fontOpticalSizing = 'auto',
    this.paintOrder = 'normal',
    this.textAlignLast = 'auto',
    this.fontSynthesis = 'weight style small-caps',
    this.fontVariantPosition = 'normal',
    this.fontVariantEastAsian = 'normal',
    this.textEmphasis,
    this.textEmphasisPosition = 'over right',
    this.textEmphasisColor,
    this.rubyAlign = 'space-around',
    this.rubyPosition = 'over',
    this.textEmphasisStyle,
    this.quotes,
    this.initialLetter,
    this.textSpacing = 'normal',
    this.fontLanguageOverride,
    this.fontVariantAlternates,
    this.textWrap = 'wrap',
    this.fontPalette,
    this.forcedColorAdjust = 'auto',
    this.printColorAdjust = 'economy',
    this.textDecorationLine = 'none',
    this.fontVariationSettings,
    this.cssTextDecorationColor,
    this.cssDirection = 'ltr',
    this.contentVisibility = 'visible',
    this.containIntrinsicSize,
    this.willChange = 'auto',
    this.hyphenateCharacter = 'auto',
    this.cssMixBlendMode = 'normal',
  });

  final ui.Color color;
  final double fontSize;
  final String? fontFamily;
  final ui.FontWeight fontWeight;
  final ui.FontStyle fontStyle;
  final _SvgTextAnchor textAnchor;
  final _SvgDominantBaseline dominantBaseline;
  final double baselineShift;
  final double letterSpacing;
  final double wordSpacing;

  /// Set of active text decorations (underline, overline, line-through).
  final Set<_SvgTextDecoration> decorations;

  /// Optional decoration color (defaults to text color).
  final ui.Color? decorationColor;

  /// Writing mode for vertical text support.
  final _SvgWritingMode writingMode;

  /// Font features for font-variant support (small-caps, etc.).
  final List<ui.FontFeature> fontFeatures;

  /// Text direction for RTL/LTR support.
  final ui.TextDirection textDirection;

  /// Glyph orientation angle for vertical text (null = auto).
  final double? glyphOrientationVertical;

  /// Unicode bidirectional text handling mode.
  final String? unicodeBidi;

  /// Font stretch width percentage (100 = normal, 50 = ultra-condensed, 200 = ultra-expanded).
  final double fontStretch;

  /// Font size adjust ratio (x-height / font-size) for cross-font consistency.
  final double? fontSizeAdjust;

  /// Tab character width in spaces (default 8).
  final int tabSize;

  /// Text indentation in user units.
  final double textIndent;

  /// Word breaking mode (normal, break-all, keep-all, break-word).
  final String wordBreak;

  /// Overflow wrapping mode (normal, break-word, anywhere).
  final String overflowWrap;

  /// Text transformation mode (none, capitalize, uppercase, lowercase).
  final String textTransform;

  /// Hyphenation mode (none, manual, auto).
  final String hyphens;

  /// Line breaking strictness (auto, loose, normal, strict, anywhere).
  final String lineBreak;

  /// Hanging punctuation mode (none, first, last, force-end, allow-end).
  final String hangingPunctuation;

  /// Text combine upright mode for vertical writing (none, all, digits).
  final String textCombineUpright;

  /// Text orientation for vertical writing (mixed, upright, sideways).
  final String textOrientation;

  /// Text underline position (auto, under, left, right).
  final String textUnderlinePosition;

  /// Text underline offset in user units (null = auto).
  final double? textUnderlineOffset;

  /// Text decoration thickness in user units (null = auto/from-font).
  final double? textDecorationThickness;

  /// Text decoration skip ink mode (auto, all, none).
  final String textDecorationSkipInk;

  /// Text decoration skip mode (objects, spaces, etc.).
  final String textDecorationSkip;

  /// Text decoration style (solid, double, dotted, dashed, wavy).
  final String textDecorationStyle;

  /// Text shadow CSS value (null = none).
  final String? textShadow;

  /// White-space handling mode (normal, nowrap, pre, pre-wrap, pre-line, break-spaces).
  final String whiteSpace;

  /// Text overflow handling (clip, ellipsis, or custom string).
  final String textOverflow;

  /// Vertical alignment offset in user units.
  final double verticalAlign;

  /// Line height in user units (null = normal).
  final double? lineHeight;

  /// Font kerning mode (auto, normal, none).
  final String fontKerning;

  /// Font variant numeric mode.
  final String fontVariantNumeric;

  /// Text justification method (auto, none, inter-word, inter-character).
  final String textJustify;

  /// Font variant ligatures mode.
  final String fontVariantLigatures;

  /// Font variant caps mode.
  final String fontVariantCaps;

  /// Font optical sizing mode (auto, none).
  final String fontOpticalSizing;

  /// Paint order (normal, fill stroke markers, etc.).
  final String paintOrder;

  /// Text align last mode (auto, start, end, left, right, center, justify).
  final String textAlignLast;

  /// Font synthesis mode (none, or weight/style/small-caps).
  final String fontSynthesis;

  /// Font variant position mode (normal, sub, super).
  final String fontVariantPosition;

  /// Font variant East Asian mode.
  final String fontVariantEastAsian;

  /// Text emphasis style (null = none).
  final String? textEmphasis;

  /// Text emphasis position (over right, under left, etc.).
  final String textEmphasisPosition;

  /// Text emphasis color (null = currentColor).
  final String? textEmphasisColor;

  /// Ruby alignment (space-around, start, center, space-between).
  final String rubyAlign;

  /// Ruby position (over, under, inter-character, alternate).
  final String rubyPosition;

  /// Text emphasis style (null = none).
  final String? textEmphasisStyle;

  /// Quotes style (null = auto).
  final String? quotes;

  /// Initial letter (null = normal).
  final String? initialLetter;

  /// Text spacing for CJK (normal, none, auto).
  final String textSpacing;

  /// Font language override (null = normal).
  final String? fontLanguageOverride;

  /// Font variant alternates (null = normal).
  final String? fontVariantAlternates;

  /// Text wrap mode (wrap, nowrap, balance, pretty, stable).
  final String textWrap;

  /// Font palette (null = normal, light, dark, or custom).
  final String? fontPalette;

  /// Forced color adjust (auto, none, preserve-parent-color).
  final String forcedColorAdjust;

  /// Print color adjust (economy, exact).
  final String printColorAdjust;

  /// Text decoration line (none, or combination).
  final String textDecorationLine;

  /// Font variation settings (null = normal).
  final String? fontVariationSettings;

  /// CSS text decoration color (null = currentColor).
  final String? cssTextDecorationColor;

  /// CSS direction (ltr, rtl).
  final String cssDirection;

  /// Content visibility (visible, hidden, auto).
  final String contentVisibility;

  /// Contain intrinsic size (null = none).
  final String? containIntrinsicSize;

  /// Will change (auto, or property names).
  final String willChange;

  /// Hyphenate character (auto, or custom character).
  final String hyphenateCharacter;

  /// CSS mix-blend-mode (normal, multiply, screen, etc.).
  final String cssMixBlendMode;

  _ResolvedTextStyle copyWith({
    ui.Color? color,
    double? fontSize,
    String? fontFamily,
    ui.FontWeight? fontWeight,
    ui.FontStyle? fontStyle,
    _SvgTextAnchor? textAnchor,
    _SvgDominantBaseline? dominantBaseline,
    double? baselineShift,
    double? letterSpacing,
    double? wordSpacing,
    Set<_SvgTextDecoration>? decorations,
    ui.Color? decorationColor,
    _SvgWritingMode? writingMode,
    List<ui.FontFeature>? fontFeatures,
    ui.TextDirection? textDirection,
    double? glyphOrientationVertical,
    String? unicodeBidi,
    double? fontStretch,
    double? fontSizeAdjust,
    int? tabSize,
    double? textIndent,
    String? wordBreak,
    String? overflowWrap,
    String? textTransform,
    String? hyphens,
    String? lineBreak,
    String? hangingPunctuation,
    String? textCombineUpright,
    String? textOrientation,
    String? textUnderlinePosition,
    double? textUnderlineOffset,
    double? textDecorationThickness,
    String? textDecorationSkipInk,
    String? textDecorationSkip,
    String? textDecorationStyle,
    String? textShadow,
    String? whiteSpace,
    String? textOverflow,
    double? verticalAlign,
    double? lineHeight,
    String? fontKerning,
    String? fontVariantNumeric,
    String? textJustify,
    String? fontVariantLigatures,
    String? fontVariantCaps,
    String? fontOpticalSizing,
    String? paintOrder,
    String? textAlignLast,
    String? fontSynthesis,
    String? fontVariantPosition,
    String? fontVariantEastAsian,
    String? textEmphasis,
    String? textEmphasisPosition,
    String? textEmphasisColor,
    String? rubyAlign,
    String? rubyPosition,
    String? textEmphasisStyle,
    String? quotes,
    String? initialLetter,
    String? textSpacing,
    String? fontLanguageOverride,
    String? fontVariantAlternates,
    String? textWrap,
    String? fontPalette,
    String? forcedColorAdjust,
    String? printColorAdjust,
    String? textDecorationLine,
    String? fontVariationSettings,
    String? cssTextDecorationColor,
    String? cssDirection,
    String? contentVisibility,
    String? containIntrinsicSize,
    String? willChange,
    String? hyphenateCharacter,
    String? cssMixBlendMode,
  }) {
    return _ResolvedTextStyle(
      color: color ?? this.color,
      fontSize: fontSize ?? this.fontSize,
      fontFamily: fontFamily ?? this.fontFamily,
      fontWeight: fontWeight ?? this.fontWeight,
      fontStyle: fontStyle ?? this.fontStyle,
      textAnchor: textAnchor ?? this.textAnchor,
      dominantBaseline: dominantBaseline ?? this.dominantBaseline,
      baselineShift: baselineShift ?? this.baselineShift,
      letterSpacing: letterSpacing ?? this.letterSpacing,
      wordSpacing: wordSpacing ?? this.wordSpacing,
      decorations: decorations ?? this.decorations,
      decorationColor: decorationColor ?? this.decorationColor,
      writingMode: writingMode ?? this.writingMode,
      fontFeatures: fontFeatures ?? this.fontFeatures,
      textDirection: textDirection ?? this.textDirection,
      glyphOrientationVertical:
          glyphOrientationVertical ?? this.glyphOrientationVertical,
      unicodeBidi: unicodeBidi ?? this.unicodeBidi,
      fontStretch: fontStretch ?? this.fontStretch,
      fontSizeAdjust: fontSizeAdjust ?? this.fontSizeAdjust,
      tabSize: tabSize ?? this.tabSize,
      textIndent: textIndent ?? this.textIndent,
      wordBreak: wordBreak ?? this.wordBreak,
      overflowWrap: overflowWrap ?? this.overflowWrap,
      textTransform: textTransform ?? this.textTransform,
      hyphens: hyphens ?? this.hyphens,
      lineBreak: lineBreak ?? this.lineBreak,
      hangingPunctuation: hangingPunctuation ?? this.hangingPunctuation,
      textCombineUpright: textCombineUpright ?? this.textCombineUpright,
      textOrientation: textOrientation ?? this.textOrientation,
      textUnderlinePosition:
          textUnderlinePosition ?? this.textUnderlinePosition,
      textUnderlineOffset: textUnderlineOffset ?? this.textUnderlineOffset,
      textDecorationThickness:
          textDecorationThickness ?? this.textDecorationThickness,
      textDecorationSkipInk:
          textDecorationSkipInk ?? this.textDecorationSkipInk,
      textDecorationSkip: textDecorationSkip ?? this.textDecorationSkip,
      textDecorationStyle: textDecorationStyle ?? this.textDecorationStyle,
      textShadow: textShadow ?? this.textShadow,
      whiteSpace: whiteSpace ?? this.whiteSpace,
      textOverflow: textOverflow ?? this.textOverflow,
      verticalAlign: verticalAlign ?? this.verticalAlign,
      lineHeight: lineHeight ?? this.lineHeight,
      fontKerning: fontKerning ?? this.fontKerning,
      fontVariantNumeric: fontVariantNumeric ?? this.fontVariantNumeric,
      textJustify: textJustify ?? this.textJustify,
      fontVariantLigatures: fontVariantLigatures ?? this.fontVariantLigatures,
      fontVariantCaps: fontVariantCaps ?? this.fontVariantCaps,
      fontOpticalSizing: fontOpticalSizing ?? this.fontOpticalSizing,
      paintOrder: paintOrder ?? this.paintOrder,
      textAlignLast: textAlignLast ?? this.textAlignLast,
      fontSynthesis: fontSynthesis ?? this.fontSynthesis,
      fontVariantPosition: fontVariantPosition ?? this.fontVariantPosition,
      fontVariantEastAsian: fontVariantEastAsian ?? this.fontVariantEastAsian,
      textEmphasis: textEmphasis ?? this.textEmphasis,
      textEmphasisPosition: textEmphasisPosition ?? this.textEmphasisPosition,
      textEmphasisColor: textEmphasisColor ?? this.textEmphasisColor,
      rubyAlign: rubyAlign ?? this.rubyAlign,
      rubyPosition: rubyPosition ?? this.rubyPosition,
      textEmphasisStyle: textEmphasisStyle ?? this.textEmphasisStyle,
      quotes: quotes ?? this.quotes,
      initialLetter: initialLetter ?? this.initialLetter,
      textSpacing: textSpacing ?? this.textSpacing,
      fontLanguageOverride: fontLanguageOverride ?? this.fontLanguageOverride,
      fontVariantAlternates:
          fontVariantAlternates ?? this.fontVariantAlternates,
      textWrap: textWrap ?? this.textWrap,
      fontPalette: fontPalette ?? this.fontPalette,
      forcedColorAdjust: forcedColorAdjust ?? this.forcedColorAdjust,
      printColorAdjust: printColorAdjust ?? this.printColorAdjust,
      textDecorationLine: textDecorationLine ?? this.textDecorationLine,
      fontVariationSettings:
          fontVariationSettings ?? this.fontVariationSettings,
      cssTextDecorationColor:
          cssTextDecorationColor ?? this.cssTextDecorationColor,
      cssDirection: cssDirection ?? this.cssDirection,
      contentVisibility: contentVisibility ?? this.contentVisibility,
      containIntrinsicSize: containIntrinsicSize ?? this.containIntrinsicSize,
      willChange: willChange ?? this.willChange,
      hyphenateCharacter: hyphenateCharacter ?? this.hyphenateCharacter,
      cssMixBlendMode: cssMixBlendMode ?? this.cssMixBlendMode,
    );
  }
}
