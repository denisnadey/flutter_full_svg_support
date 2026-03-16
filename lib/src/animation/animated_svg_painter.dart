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
  });

  final String type;
  final Map<String, Object?> attributes;
  final List<_GradientStop> stops;
}

class _TextCursor {
  _TextCursor({required this.x, required this.y});

  double x;
  double y;
}

enum _SvgTextAnchor { start, middle, end }

enum _SvgDominantBaseline { alphabetic, central, textBeforeEdge, textAfterEdge }

enum _SvgTextLengthAdjust { spacing, spacingAndGlyphs }

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
    );
  }
}
