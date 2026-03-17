import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

import 'css_named_colors.dart';
import 'path_data.dart';
import 'path_parser.dart';
import 'preserve_aspect_ratio.dart';
import 'switch_processing.dart';
import 'svg_dom.dart';
import 'svg_filters.dart';
import 'svg_transform.dart';

part 'animated_svg_painter_use.dart';
part 'animated_svg_painter_tree.dart';
part 'animated_svg_painter_clip_mask.dart';
part 'animated_svg_painter_clip_mask_geometry.dart';
part 'animated_svg_painter_clip_mask_units.dart';
part 'animated_svg_painter_shapes.dart';
part 'animated_svg_painter_shapes_rect.dart';
part 'animated_svg_painter_shapes_image.dart';
part 'animated_svg_painter_shapes_paths.dart';
part 'animated_svg_painter_text_paint.dart';
part 'animated_svg_painter_text_style.dart';
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
  });

  /// SVG документ с актуальными (анимированными) значениями атрибутов
  final SvgDocument document;

  /// Фоновый цвет (опционально)
  final ui.Color? backgroundColor;

  /// Decoded raster images keyed by raw `href`/`xlink:href` value.
  final Map<String, ui.Image> imagesByHref;

  final Map<String, _ResolvedGradientDefinition?> _gradientCache =
      <String, _ResolvedGradientDefinition?>{};
  final Map<String, _ResolvedMarkerDefinition?> _markerCache =
      <String, _ResolvedMarkerDefinition?>{};
  final Map<String, _ResolvedPatternDefinition?> _patternCache =
      <String, _ResolvedPatternDefinition?>{};
  final Map<String, ui.Image?> _patternTileCache = <String, ui.Image?>{};
  bool _currentPassPaintFill = true;
  bool _currentPassPaintStroke = true;

  @override
  void paint(ui.Canvas canvas, ui.Size size) {
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
  }

  /// Вычисляет матрицу трансформации для viewBox
  Matrix4 _computeViewBoxTransform(ui.Size size) {
    final viewBox = document.viewBox;

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
}

enum _SvgTextAnchor { start, middle, end }

enum _SvgDominantBaseline { alphabetic, central, textBeforeEdge, textAfterEdge }

enum _SvgTextLengthAdjust { spacing, spacingAndGlyphs }

/// SVG textPath spacing attribute values.
enum _SvgTextPathSpacing { auto, exact }

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
    );
  }
}
