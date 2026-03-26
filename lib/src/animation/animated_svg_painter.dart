import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

import 'css_animations.dart';
import 'css_cascade.dart';
import 'css_named_colors.dart';
import 'css_variables_calc.dart';
import 'path_data.dart';
import 'path_parser.dart';
import 'preserve_aspect_ratio.dart';
import 'switch_processing.dart';
import 'svg_dom.dart';
import 'svg_filters.dart';
import 'svg_transform.dart';
import 'transform_3d.dart';

part 'animated_svg_painter_use.dart';
part 'animated_svg_painter_tree.dart';
part 'animated_svg_painter_clip_mask.dart';
part 'animated_svg_painter_clip_mask_geometry.dart';
part 'animated_svg_painter_clip_mask_units.dart';
part 'animated_svg_painter_clip_mask_advanced.dart';
part 'animated_svg_painter_clip_mask_composition.dart';
part 'animated_svg_painter_shapes.dart';
part 'animated_svg_painter_shapes_rect.dart';
part 'animated_svg_painter_shapes_image.dart';
part 'animated_svg_painter_shapes_paths.dart';
part 'animated_svg_painter_text_paint.dart';
part 'animated_svg_painter_text_style.dart';
part 'animated_svg_painter_text_style_font.dart';
part 'animated_svg_painter_text_style_decoration.dart';
part 'animated_svg_painter_text_style_layout.dart';
part 'animated_svg_painter_text_style_positioning.dart';
part 'animated_svg_painter_text_style_rendering.dart';
part 'animated_svg_painter_geometry.dart';
part 'animated_svg_painter_paints.dart';
part 'animated_svg_painter_gradients.dart';
part 'animated_svg_painter_gradients_resolver.dart';
part 'animated_svg_painter_gradients_values.dart';
part 'animated_svg_painter_matrix.dart';
part 'animated_svg_painter_values.dart';
part 'animated_svg_painter_transform.dart';
part 'animated_svg_painter_markers.dart';
part 'animated_svg_painter_patterns.dart';
part 'animated_svg_painter_paint_order.dart';

/// Performance cache for render-time computed values.
///
/// This cache stores expensive-to-compute values that can be reused between
/// frames when the underlying SVG elements haven't changed. Cache keys include
/// element ID and a hash of relevant attributes to ensure proper invalidation.
class _RenderCache {
  /// Cached gradient shaders keyed by gradient ID + paint bounds hash.
  final Map<String, ui.Shader> gradientShaders = <String, ui.Shader>{};

  /// Cached pattern images keyed by pattern ID + target bounds hash.
  final Map<String, ui.Image> patternImages = <String, ui.Image>{};

  /// Cached text paragraphs keyed by text content + style hash.
  final Map<String, ui.Paragraph> textParagraphs = <String, ui.Paragraph>{};

  /// Cached hit-test paths keyed by element ID + geometry hash.
  final Map<String, ui.Path> hitTestPaths = <String, ui.Path>{};

  /// Last animation time when cache was valid.
  double? _lastAnimationTime;

  /// Initialize or update cache state for new frame.
  void prepareFrame(double? animationTime, bool hasAnimations) {
    // If animation time changed, invalidate caches that depend on animated values
    if (_lastAnimationTime != animationTime && hasAnimations) {
      gradientShaders.clear();
      patternImages.clear();
      textParagraphs.clear();
      hitTestPaths.clear();
    }
    _lastAnimationTime = animationTime;
  }

  /// Clears all caches.
  void clear() {
    gradientShaders.clear();
    patternImages.clear();
    textParagraphs.clear();
    hitTestPaths.clear();
    _lastAnimationTime = null;
  }

  /// Generate a cache key for gradient shader.
  static String gradientKey(
    String gradientId,
    ui.Rect bounds,
    Map<String, Object?> attributes,
  ) {
    final boundsHash =
        '${bounds.left.toStringAsFixed(2)}_'
        '${bounds.top.toStringAsFixed(2)}_'
        '${bounds.width.toStringAsFixed(2)}_'
        '${bounds.height.toStringAsFixed(2)}';
    final attrHash = attributes.entries
        .map((e) => '${e.key}:${e.value}')
        .join('|');
    return 'g:$gradientId|b:$boundsHash|a:${attrHash.hashCode}';
  }

  /// Generate a cache key for pattern image.
  static String patternKey(
    String patternId,
    ui.Rect bounds,
    int tileWidth,
    int tileHeight,
  ) {
    final boundsHash =
        '${bounds.left.toStringAsFixed(2)}_'
        '${bounds.top.toStringAsFixed(2)}_'
        '${bounds.width.toStringAsFixed(2)}_'
        '${bounds.height.toStringAsFixed(2)}';
    return 'p:$patternId|b:$boundsHash|tw:$tileWidth|th:$tileHeight';
  }

  /// Generate a cache key for text paragraph.
  static String textKey(
    String text,
    double fontSize,
    String? fontFamily,
    int fontWeightIndex,
    int fontStyleIndex,
    double letterSpacing,
    int colorValue,
  ) {
    return 't:${text.hashCode}|fs:${fontSize.toStringAsFixed(1)}|'
        'ff:${fontFamily ?? "def"}|fw:$fontWeightIndex|'
        'fst:$fontStyleIndex|ls:${letterSpacing.toStringAsFixed(2)}|'
        'c:$colorValue';
  }
}

/// CustomPainter для отрисовки анимированного SVG
///
/// Использует SvgDocument с уже применёнными анимированными значениями
/// атрибутов (через AnimatableSvgAttribute.effectiveValue).
///
/// Для статических поддеревьев (hasAnimations = false) можно использовать
/// cachedPicture для оптимизации.
class AnimatedSvgPainter extends CustomPainter {
  /// Создаёт painter для анимированного SVG
  AnimatedSvgPainter({
    required this.document,
    this.backgroundColor,
    this.imagesByHref = const <String, ui.Image>{},
    this.animationTime,
    this.hasAnimations = false,
    _RenderCache? renderCache,
  }) : _renderCache = renderCache ?? _RenderCache();

  /// SVG документ с актуальными (анимированными) значениями атрибутов
  final SvgDocument document;

  /// Фоновый цвет (опционально)
  final ui.Color? backgroundColor;

  /// Decoded raster images keyed by raw `href`/`xlink:href` value.
  final Map<String, ui.Image> imagesByHref;

  /// Current animation time in seconds (for cache invalidation).
  final double? animationTime;

  /// Whether the document has animations.
  final bool hasAnimations;

  /// Performance cache for computed render values.
  final _RenderCache _renderCache;

  final Map<String, _ResolvedGradientDefinition?> _gradientCache =
      <String, _ResolvedGradientDefinition?>{};
  final Map<String, _ResolvedMarkerDefinition?> _markerCache =
      <String, _ResolvedMarkerDefinition?>{};
  final Map<String, _ResolvedPatternDefinition?> _patternCache =
      <String, _ResolvedPatternDefinition?>{};
  bool _currentPassPaintFill = true;
  bool _currentPassPaintStroke = true;

  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    // Prepare cache for this frame
    _renderCache.prepareFrame(animationTime, hasAnimations);

    // Clear definition caches when animation time changes, so animated
    // stop-color, marker, and pattern values are re-read from DOM nodes.
    if (hasAnimations) {
      _gradientCache.clear();
      _markerCache.clear();
      _patternCache.clear();
    }

    // Set up CSS rules from document for use-referenced content resolution
    _currentDocumentCssRules = document.cssSelectorRules;

    // Применяем фон если указан
    if (backgroundColor != null) {
      canvas.drawRect(
        ui.Rect.fromLTWH(0, 0, size.width, size.height),
        ui.Paint()..color = backgroundColor!,
      );
    }

    // Вычисляем трансформацию viewBox → size
    final transform = _computeViewBoxTransform(size);

    canvas.save();
    canvas.transform(transform.storage);

    // Рисуем корневой узел
    _paintNode(canvas, document.root);

    canvas.restore();

    // Clean up global CSS rules reference
    _currentDocumentCssRules = null;
  }

  /// Вычисляет матрицу трансформации для viewBox
  Matrix4 _computeViewBoxTransform(ui.Size size) {
    // Use active viewBox (from <view> element if selected, otherwise root viewBox)
    final viewBox = document.activeViewBox;

    if (viewBox == null) {
      // Без viewBox используем 1:1 масштаб
      return Matrix4.identity();
    }

    // Вычисляем scale для fit
    final scaleX = size.width / viewBox.width;
    final scaleY = size.height / viewBox.height;
    final scale = scaleX < scaleY ? scaleX : scaleY;

    // Центрируем
    final translateX =
        (size.width - viewBox.width * scale) / 2 - viewBox.left * scale;
    final translateY =
        (size.height - viewBox.height * scale) / 2 - viewBox.top * scale;

    return Matrix4.identity()
      ..translateByDouble(translateX, translateY, 0, 1)
      ..scaleByDouble(scale, scale, 1, 1);
  }

  /// Рисует узел и его детей
  void _paintNode(ui.Canvas canvas, SvgNode node, {Set<String>? useStack}) {
    _paintNodeImpl(this, canvas, node, useStack: useStack);
  }

  @override
  bool shouldRepaint(AnimatedSvgPainter oldDelegate) {
    // Всегда перерисовываем, так как анимации могут изменить значения
    return true;
  }

  @override
  bool shouldRebuildSemantics(AnimatedSvgPainter oldDelegate) {
    return false;
  }
}

enum _GradientAxis { x, y, radius }

class _GradientLength {
  const _GradientLength(this.value, this.isPercent);

  final double value;
  final bool isPercent;
}

class _UseViewportTransform {
  const _UseViewportTransform({required this.matrix, required this.clipRect});

  final Matrix4 matrix;
  final ui.Rect? clipRect;
}

class _GradientStop {
  const _GradientStop({required this.offset, required this.color});

  final double offset;
  final ui.Color color;
}

class _ResolvedGradientDefinition {
  const _ResolvedGradientDefinition({
    required this.type,
    required this.attributes,
    required this.stops,
    this.useLinearRGB = false,
  });

  final String type;
  final Map<String, Object?> attributes;
  final List<_GradientStop> stops;
  final bool useLinearRGB;
}

class _TextCursor {
  _TextCursor({required this.x, required this.y});

  double x;
  double y;

  /// Character index for consuming multi-position attribute lists.
  int charIndex = 0;

  /// Character index within the current text chunk (for text-anchor calculation).
  int chunkCharIndex = 0;

  /// Whether this is the first line of text (for text-indent).
  bool isFirstLine = false;
}

enum _SvgTextAnchor { start, middle, end }

/// SVG dominant-baseline and alignment-baseline attribute values.
enum _SvgDominantBaseline {
  /// Default alphabetic baseline.
  alphabetic,

  /// Central baseline (middle of em box).
  central,

  /// Top of em box.
  textBeforeEdge,

  /// Bottom of em box.
  textAfterEdge,

  /// Hanging baseline (for Indic scripts, ~80% of ascent).
  hanging,

  /// Mathematical baseline (centered on operators, ~50% of x-height).
  mathematical,

  /// Ideographic baseline (for CJK, at bottom of em box).
  ideographic,

  /// Middle baseline (deprecated, same as central).
  middle,
}

enum _SvgTextLengthAdjust { spacing, spacingAndGlyphs }

/// SVG textPath spacing attribute values.
enum _SvgTextPathSpacing { auto, exact }

/// SVG textPath method attribute values.
/// - align: Glyphs are aligned with the path (default)
/// - stretch: Glyphs are stretched/compressed to fit the path
enum _SvgTextPathMethod { align, stretch }

/// SVG text-decoration line types.
enum _SvgTextDecoration { underline, overline, lineThrough }

/// SVG writing-mode attribute values.
enum _SvgWritingMode { horizontalTb, verticalRl, verticalLr }

/// SVG markerUnits attribute values.
enum _SvgMarkerUnits { userSpaceOnUse, strokeWidth }

/// SVG marker orient attribute values.
enum _SvgMarkerOrient { auto, autoStartReverse, angle }

/// Resolved marker definition.
class _ResolvedMarkerDefinition {
  const _ResolvedMarkerDefinition({
    required this.node,
    required this.refX,
    required this.refY,
    required this.markerWidth,
    required this.markerHeight,
    required this.markerUnits,
    required this.orient,
    required this.orientAngle,
    this.viewBox,
  });

  final SvgNode node;
  final double refX;
  final double refY;
  final double markerWidth;
  final double markerHeight;
  final _SvgMarkerUnits markerUnits;
  final _SvgMarkerOrient orient;
  final double orientAngle;
  final ui.Rect? viewBox;
}

/// SVG patternUnits / patternContentUnits attribute values.
enum _SvgPatternUnits { userSpaceOnUse, objectBoundingBox }

/// Resolved pattern definition.
class _ResolvedPatternDefinition {
  const _ResolvedPatternDefinition({
    required this.node,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.patternUnits,
    required this.patternContentUnits,
    this.viewBox,
    this.patternTransform,
  });

  final SvgNode node;
  final double x;
  final double y;
  final double width;
  final double height;
  final _SvgPatternUnits patternUnits;
  final _SvgPatternUnits patternContentUnits;
  final ui.Rect? viewBox;
  final Matrix4? patternTransform;
}

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
    );
  }
}
