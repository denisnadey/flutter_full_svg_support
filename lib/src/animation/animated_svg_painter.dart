import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

import 'svg_dom.dart';
import 'svg_transform.dart';

/// CustomPainter для отрисовки анимированного SVG
///
/// Использует SvgDocument с уже применёнными анимированными значениями
/// атрибутов (через AnimatableSvgAttribute.effectiveValue).
///
/// Для статических поддеревьев (hasAnimations = false) можно использовать
/// cachedPicture для оптимизации.
class AnimatedSvgPainter extends CustomPainter {
  /// Создаёт painter для анимированного SVG
  AnimatedSvgPainter({required this.document, this.backgroundColor});

  /// SVG документ с актуальными (анимированными) значениями атрибутов
  final SvgDocument document;

  /// Фоновый цвет (опционально)
  final ui.Color? backgroundColor;

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
      ..translate(translateX, translateY)
      ..scale(scale, scale);
  }

  /// Рисует узел и его детей
  void _paintNode(ui.Canvas canvas, SvgNode node) {
    canvas.save();

    // Применяем transform если есть
    _applyTransform(canvas, node);

    // Рисуем сам узел в зависимости от типа
    switch (node.tagName) {
      case 'rect':
        _paintRect(canvas, node);
        break;
      case 'circle':
        _paintCircle(canvas, node);
        break;
      case 'ellipse':
        _paintEllipse(canvas, node);
        break;
      case 'path':
        _paintPath(canvas, node);
        break;
      case 'line':
        _paintLine(canvas, node);
        break;
      case 'g':
      case 'svg':
        // Группы не рисуются, только применяют атрибуты к детям
        break;
      default:
        // Игнорируем неподдерживаемые элементы (animate, text, etc.)
        break;
    }

    // Рекурсивно рисуем детей
    for (final child in node.children) {
      _paintNode(canvas, child);
    }

    canvas.restore();
  }

  /// Рисует <rect>
  void _paintRect(ui.Canvas canvas, SvgNode node) {
    final x = _getNumber(node, 'x') ?? 0.0;
    final y = _getNumber(node, 'y') ?? 0.0;
    final width = _getNumber(node, 'width') ?? 0.0;
    final height = _getNumber(node, 'height') ?? 0.0;
    final rx = _getNumber(node, 'rx') ?? 0.0;
    final ry = _getNumber(node, 'ry') ?? rx;

    if (width <= 0 || height <= 0) return;

    final rect = ui.Rect.fromLTWH(x, y, width, height);
    final paint = _createPaint(node);

    if (rx > 0 || ry > 0) {
      final rrect = ui.RRect.fromRectXY(rect, rx, ry);
      canvas.drawRRect(rrect, paint);
    } else {
      canvas.drawRect(rect, paint);
    }

    // Stroke если указан
    final strokePaint = _createStrokePaint(node);
    if (strokePaint != null) {
      if (rx > 0 || ry > 0) {
        final rrect = ui.RRect.fromRectXY(rect, rx, ry);
        canvas.drawRRect(rrect, strokePaint);
      } else {
        canvas.drawRect(rect, strokePaint);
      }
    }
  }

  /// Рисует <circle>
  void _paintCircle(ui.Canvas canvas, SvgNode node) {
    final cx = _getNumber(node, 'cx') ?? 0.0;
    final cy = _getNumber(node, 'cy') ?? 0.0;
    final r = _getNumber(node, 'r') ?? 0.0;

    if (r <= 0) return;

    final center = ui.Offset(cx, cy);
    final paint = _createPaint(node);

    canvas.drawCircle(center, r, paint);

    final strokePaint = _createStrokePaint(node);
    if (strokePaint != null) {
      canvas.drawCircle(center, r, strokePaint);
    }
  }

  /// Рисует <ellipse>
  void _paintEllipse(ui.Canvas canvas, SvgNode node) {
    final cx = _getNumber(node, 'cx') ?? 0.0;
    final cy = _getNumber(node, 'cy') ?? 0.0;
    final rx = _getNumber(node, 'rx') ?? 0.0;
    final ry = _getNumber(node, 'ry') ?? 0.0;

    if (rx <= 0 || ry <= 0) return;

    final rect = ui.Rect.fromCenter(
      center: ui.Offset(cx, cy),
      width: rx * 2,
      height: ry * 2,
    );
    final paint = _createPaint(node);

    canvas.drawOval(rect, paint);

    final strokePaint = _createStrokePaint(node);
    if (strokePaint != null) {
      canvas.drawOval(rect, strokePaint);
    }
  }

  /// Рисует <line>
  void _paintLine(ui.Canvas canvas, SvgNode node) {
    final x1 = _getNumber(node, 'x1') ?? 0.0;
    final y1 = _getNumber(node, 'y1') ?? 0.0;
    final x2 = _getNumber(node, 'x2') ?? 0.0;
    final y2 = _getNumber(node, 'y2') ?? 0.0;

    final strokePaint = _createStrokePaint(node);
    if (strokePaint != null) {
      canvas.drawLine(ui.Offset(x1, y1), ui.Offset(x2, y2), strokePaint);
    }
  }

  /// Рисует <path>
  void _paintPath(ui.Canvas canvas, SvgNode node) {
    final pathData = _getString(node, 'd');
    if (pathData == null || pathData.isEmpty) return;

    // TODO: Реализовать path parsing в следующем этапе
    // Пока пропускаем path элементы
  }

  /// Создаёт Paint для fill
  ui.Paint _createPaint(SvgNode node) {
    final paint = ui.Paint()..style = ui.PaintingStyle.fill;

    // Fill color
    final fill = _getColor(node, 'fill');
    if (fill != null) {
      paint.color = fill;
    } else {
      paint.color = const ui.Color(0xFF000000); // Чёрный по умолчанию
    }

    // Opacity
    final opacity = _getNumber(node, 'opacity') ?? 1.0;
    final fillOpacity = _getNumber(node, 'fill-opacity') ?? 1.0;
    final finalOpacity = (opacity * fillOpacity).clamp(0.0, 1.0);

    paint.color = paint.color.withOpacity(finalOpacity);

    return paint;
  }

  /// Создаёт Paint для stroke (или null если нет stroke)
  ui.Paint? _createStrokePaint(SvgNode node) {
    final stroke = _getColor(node, 'stroke');
    if (stroke == null) return null;

    final paint = ui.Paint()
      ..style = ui.PaintingStyle.stroke
      ..color = stroke;

    // Stroke width
    final strokeWidth = _getNumber(node, 'stroke-width') ?? 1.0;
    paint.strokeWidth = strokeWidth;

    // Opacity
    final opacity = _getNumber(node, 'opacity') ?? 1.0;
    final strokeOpacity = _getNumber(node, 'stroke-opacity') ?? 1.0;
    final finalOpacity = (opacity * strokeOpacity).clamp(0.0, 1.0);

    paint.color = paint.color.withOpacity(finalOpacity);

    return paint;
  }

  /// Получает числовое значение атрибута (с учётом анимации)
  double? _getNumber(SvgNode node, String attributeName) {
    final value = node.getAttributeValue(attributeName);
    if (value == null) return null;

    if (value is num) {
      return value.toDouble();
    }

    if (value is String) {
      return double.tryParse(value);
    }

    return null;
  }

  /// Получает строковое значение атрибута
  String? _getString(SvgNode node, String attributeName) {
    final value = node.getAttributeValue(attributeName);
    return value?.toString();
  }

  /// Получает цвет атрибута
  ui.Color? _getColor(SvgNode node, String attributeName) {
    final value = node.getAttributeValue(attributeName);
    if (value == null) return null;

    if (value is ui.Color) {
      return value;
    }

    // Попробовать распарсить строку
    if (value is String) {
      return _parseColor(value);
    }

    return null;
  }

  /// Парсит цвет из строки
  ui.Color? _parseColor(String colorStr) {
    final str = colorStr.trim().toLowerCase();

    // none
    if (str == 'none') return null;

    // Hex colors
    if (str.startsWith('#')) {
      final hex = str.substring(1);

      if (hex.length == 3) {
        // #RGB -> #RRGGBB
        final r = int.parse(hex[0] + hex[0], radix: 16);
        final g = int.parse(hex[1] + hex[1], radix: 16);
        final b = int.parse(hex[2] + hex[2], radix: 16);
        return ui.Color.fromARGB(255, r, g, b);
      } else if (hex.length == 6) {
        // #RRGGBB
        final value = int.parse(hex, radix: 16);
        return ui.Color(0xFF000000 | value);
      } else if (hex.length == 8) {
        // #RRGGBBAA
        final value = int.parse(hex, radix: 16);
        return ui.Color(value);
      }
    }

    // Named colors (базовые)
    const namedColors = {
      'black': ui.Color(0xFF000000),
      'white': ui.Color(0xFFFFFFFF),
      'red': ui.Color(0xFFFF0000),
      'green': ui.Color(0xFF008000),
      'blue': ui.Color(0xFF0000FF),
      'yellow': ui.Color(0xFFFFFF00),
      'cyan': ui.Color(0xFF00FFFF),
      'magenta': ui.Color(0xFFFF00FF),
      'gray': ui.Color(0xFF808080),
      'grey': ui.Color(0xFF808080),
    };

    return namedColors[str];
  }

  /// Применяет transform к canvas если атрибут задан
  void _applyTransform(ui.Canvas canvas, SvgNode node) {
    final transformStr = _getString(node, 'transform');
    if (transformStr == null || transformStr.isEmpty) return;

    // Парсим трансформации
    final transforms = SvgTransform.parse(transformStr);
    if (transforms.isEmpty) return;

    // Применяем каждую трансформацию в порядке объявления
    for (final transform in transforms) {
      switch (transform.type) {
        case SvgTransformType.translate:
          final tx = transform.values.isNotEmpty ? transform.values[0] : 0.0;
          final ty = transform.values.length > 1 ? transform.values[1] : 0.0;
          canvas.translate(tx, ty);

        case SvgTransformType.rotate:
          final angle = transform.values.isNotEmpty ? transform.values[0] : 0.0;
          final cx = transform.values.length > 1 ? transform.values[1] : 0.0;
          final cy = transform.values.length > 2 ? transform.values[2] : 0.0;

          // Rotate with center point
          if (cx != 0.0 || cy != 0.0) {
            canvas.translate(cx, cy);
            canvas.rotate(angle * 3.14159 / 180.0); // degrees to radians
            canvas.translate(-cx, -cy);
          } else {
            canvas.rotate(angle * 3.14159 / 180.0);
          }

        case SvgTransformType.scale:
          final sx = transform.values.isNotEmpty ? transform.values[0] : 1.0;
          final sy = transform.values.length > 1
              ? transform.values[1]
              : sx; // sy defaults to sx
          canvas.scale(sx, sy);

        case SvgTransformType.skewX:
          final angle = transform.values.isNotEmpty ? transform.values[0] : 0.0;
          final radians = angle * 3.14159 / 180.0;
          final tanValue = radians.isFinite ? radians : 0.0;
          // skewX matrix: [1, tan(angle), 0]
          //               [0,     1,      0]
          //               [0,     0,      1]
          final matrix = Matrix4.identity()
            ..setEntry(0, 1, tanValue); // Set skewX component
          canvas.transform(matrix.storage);

        case SvgTransformType.skewY:
          final angle = transform.values.isNotEmpty ? transform.values[0] : 0.0;
          final radians = angle * 3.14159 / 180.0;
          final tanValue = radians.isFinite ? radians : 0.0;
          // skewY matrix: [    1,      0, 0]
          //               [tan(angle), 1, 0]
          //               [    0,      0, 1]
          final matrix = Matrix4.identity()
            ..setEntry(1, 0, tanValue); // Set skewY component
          canvas.transform(matrix.storage);

        case SvgTransformType.matrix:
          if (transform.values.length >= 6) {
            // SVG matrix(a, b, c, d, e, f) maps to:
            // [a  c  e]
            // [b  d  f]
            // [0  0  1]
            final a = transform.values[0];
            final b = transform.values[1];
            final c = transform.values[2];
            final d = transform.values[3];
            final e = transform.values[4];
            final f = transform.values[5];

            final matrix = Matrix4.identity()
              ..setEntry(0, 0, a) // m11
              ..setEntry(1, 0, b) // m21
              ..setEntry(0, 1, c) // m12
              ..setEntry(1, 1, d) // m22
              ..setEntry(0, 3, e) // m14 (translateX)
              ..setEntry(1, 3, f); // m24 (translateY)
            canvas.transform(matrix.storage);
          }
          break;
      }
    }
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
