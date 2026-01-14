import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Утилиты для детального визуального тестирования анимаций
class VisualTestUtils {
  /// Захватить скриншот виджета и вернуть пиксели (БЕЗ pumpAndSettle)
  static Future<Uint8List> captureWidgetPixels(WidgetTester tester) async {
    // НЕ вызываем pumpAndSettle - это зависает на бесконечных анимациях!

    final finder = find.byType(RepaintBoundary).first;
    final renderObject = tester.renderObject(finder);
    final boundary = renderObject as RenderRepaintBoundary;

    // Use runAsync to properly handle async image capture
    final pixels = await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1.0);
      final byteData = await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );

      print('Image size: ${image.width}x${image.height}');

      final result = byteData!.buffer.asUint8List();

      // ВАЖНО: Dispose image чтобы освободить нативные ресурсы
      image.dispose();

      return result;
    });

    return pixels!;
  }

  /// Проанализировать пиксели и найти красные пиксели (rect)
  static PixelAnalysis analyzeRedPixels(
    Uint8List pixels,
    int width,
    int height,
  ) {
    final redPixels = <Offset>[];

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final offset = (y * width + x) * 4;
        final r = pixels[offset];
        final g = pixels[offset + 1];
        final b = pixels[offset + 2];
        final a = pixels[offset + 3];

        // Красный цвет (с небольшим допуском)
        if (r > 200 && g < 100 && b < 100 && a > 200) {
          redPixels.add(Offset(x.toDouble(), y.toDouble()));
        }
      }
    }

    return PixelAnalysis(pixels: redPixels, width: width, height: height);
  }

  /// Вычислить хеш пикселей для сравнения
  static String computePixelHash(Uint8List pixels) {
    int hash = 0;
    for (int i = 0; i < pixels.length; i++) {
      hash = ((hash << 5) - hash) + pixels[i];
      hash = hash & 0xFFFFFFFF; // 32-bit
    }
    return hash.toRadixString(16);
  }

  /// Сравнить два набора пикселей и вычислить процент различий
  static double computePixelDifference(Uint8List pixels1, Uint8List pixels2) {
    if (pixels1.length != pixels2.length) {
      return 100.0;
    }

    int differentPixels = 0;
    for (int i = 0; i < pixels1.length; i += 4) {
      final r1 = pixels1[i];
      final g1 = pixels1[i + 1];
      final b1 = pixels1[i + 2];

      final r2 = pixels2[i];
      final g2 = pixels2[i + 1];
      final b2 = pixels2[i + 2];

      // Считаем пиксель разным если хоть один канал отличается больше чем на 10
      if ((r1 - r2).abs() > 10 ||
          (g1 - g2).abs() > 10 ||
          (b1 - b2).abs() > 10) {
        differentPixels++;
      }
    }

    return (differentPixels * 100.0) / (pixels1.length / 4);
  }
}

/// Результат анализа пикселей
class PixelAnalysis {
  PixelAnalysis({
    required this.pixels,
    required this.width,
    required this.height,
  });

  final List<Offset> pixels;
  final int width;
  final int height;

  /// Вычислить ограничивающий прямоугольник (bounding box)
  Rect get boundingBox {
    if (pixels.isEmpty) return Rect.zero;

    double minX = pixels.first.dx;
    double maxX = pixels.first.dx;
    double minY = pixels.first.dy;
    double maxY = pixels.first.dy;

    for (final p in pixels) {
      if (p.dx < minX) minX = p.dx;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dy > maxY) maxY = p.dy;
    }

    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  /// Центр масс объекта
  Offset get centroid {
    if (pixels.isEmpty) return Offset.zero;

    double sumX = 0;
    double sumY = 0;

    for (final p in pixels) {
      sumX += p.dx;
      sumY += p.dy;
    }

    return Offset(sumX / pixels.length, sumY / pixels.length);
  }

  /// Количество пикселей
  int get pixelCount => pixels.length;

  /// Ширина bounding box
  double get objectWidth => boundingBox.width;

  /// Высота bounding box
  double get objectHeight => boundingBox.height;

  /// Приблизительный угол поворота на основе распределения пикселей
  /// Использует моменты второго порядка для определения ориентации
  double get estimatedRotationAngle {
    if (pixels.length < 4) return 0.0;

    final center = centroid;

    // Вычисляем моменты второго порядка
    double mu20 = 0; // Момент по x^2
    double mu02 = 0; // Момент по y^2
    double mu11 = 0; // Смешанный момент xy

    for (final p in pixels) {
      final dx = p.dx - center.dx;
      final dy = p.dy - center.dy;
      mu20 += dx * dx;
      mu02 += dy * dy;
      mu11 += dx * dy;
    }

    // Угол ориентации из главной оси
    final angle = 0.5 * math.atan2(2 * mu11, mu20 - mu02);

    // Конвертируем в градусы
    return angle * 180 / math.pi;
  }

  /// Проверить повернулся ли объект относительно другого анализа
  bool isRotatedComparedTo(PixelAnalysis other, {double tolerance = 5.0}) {
    final angleDiff = (estimatedRotationAngle - other.estimatedRotationAngle)
        .abs();
    return angleDiff > tolerance;
  }

  /// Проверить сместился ли объект
  bool isTranslatedComparedTo(PixelAnalysis other, {double tolerance = 2.0}) {
    final centerDiff = (centroid - other.centroid).distance;
    return centerDiff > tolerance;
  }

  /// Проверить изменился ли размер
  bool isScaledComparedTo(PixelAnalysis other, {double tolerance = 2.0}) {
    final widthDiff = (objectWidth - other.objectWidth).abs();
    final heightDiff = (objectHeight - other.objectHeight).abs();
    return widthDiff > tolerance || heightDiff > tolerance;
  }

  @override
  String toString() {
    return 'PixelAnalysis(\n'
        '  pixelCount: $pixelCount,\n'
        '  centroid: (${centroid.dx.toStringAsFixed(1)}, ${centroid.dy.toStringAsFixed(1)}),\n'
        '  boundingBox: ${boundingBox.toString()},\n'
        '  size: ${objectWidth.toStringAsFixed(1)} x ${objectHeight.toStringAsFixed(1)},\n'
        '  estimatedRotation: ${estimatedRotationAngle.toStringAsFixed(1)}°\n'
        ')';
  }

  /// Детальный отчет для тестов
  String toDetailedReport() {
    return '''
=== Детальный визуальный анализ ===
Количество красных пикселей: $pixelCount
Центр масс: (${centroid.dx.toStringAsFixed(2)}, ${centroid.dy.toStringAsFixed(2)})
Bounding Box: 
  - Левый верхний: (${boundingBox.left.toStringAsFixed(2)}, ${boundingBox.top.toStringAsFixed(2)})
  - Правый нижний: (${boundingBox.right.toStringAsFixed(2)}, ${boundingBox.bottom.toStringAsFixed(2)})
  - Размер: ${objectWidth.toStringAsFixed(2)} x ${objectHeight.toStringAsFixed(2)}
Приблизительный угол поворота: ${estimatedRotationAngle.toStringAsFixed(2)}°
================================
''';
  }
}
