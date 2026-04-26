import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Utilities for detailed visual testing of animations
class VisualTestUtils {
  /// Capture a screenshot of the widget and return pixels (WITHOUT pumpAndSettle)
  static Future<Uint8List> captureWidgetPixels(WidgetTester tester) async {
    // Do NOT call pumpAndSettle — it hangs on infinite animations!

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

      // IMPORTANT: Dispose image to free native resources
      image.dispose();

      return result;
    });

    return pixels!;
  }

  /// Analyze pixels and find red pixels (rect)
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

        // Red color (with a small tolerance)
        if (r > 200 && g < 100 && b < 100 && a > 200) {
          redPixels.add(Offset(x.toDouble(), y.toDouble()));
        }
      }
    }

    return PixelAnalysis(pixels: redPixels, width: width, height: height);
  }

  /// Compute a pixel hash for comparison
  static String computePixelHash(Uint8List pixels) {
    int hash = 0;
    for (int i = 0; i < pixels.length; i++) {
      hash = ((hash << 5) - hash) + pixels[i];
      hash = hash & 0xFFFFFFFF; // 32-bit
    }
    return hash.toRadixString(16);
  }

  /// Compare two pixel sets and compute the percentage of differences
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

      // Count a pixel as different if any channel differs by more than 10
      if ((r1 - r2).abs() > 10 ||
          (g1 - g2).abs() > 10 ||
          (b1 - b2).abs() > 10) {
        differentPixels++;
      }
    }

    return (differentPixels * 100.0) / (pixels1.length / 4);
  }
}

/// Result of pixel analysis
class PixelAnalysis {
  PixelAnalysis({
    required this.pixels,
    required this.width,
    required this.height,
  });

  final List<Offset> pixels;
  final int width;
  final int height;

  /// Compute the bounding box
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

  /// Center of mass of the object
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

  /// Number of pixels
  int get pixelCount => pixels.length;

  /// Width of the bounding box
  double get objectWidth => boundingBox.width;

  /// Height of the bounding box
  double get objectHeight => boundingBox.height;

  /// Approximate rotation angle based on pixel distribution
  /// Uses second-order moments to determine orientation
  double get estimatedRotationAngle {
    if (pixels.length < 4) return 0.0;

    final center = centroid;

    // Compute second-order moments
    double mu20 = 0; // Moment for x^2
    double mu02 = 0; // Moment for y^2
    double mu11 = 0; // Mixed moment xy

    for (final p in pixels) {
      final dx = p.dx - center.dx;
      final dy = p.dy - center.dy;
      mu20 += dx * dx;
      mu02 += dy * dy;
      mu11 += dx * dy;
    }

    // Orientation angle from the principal axis
    final angle = 0.5 * math.atan2(2 * mu11, mu20 - mu02);

    // Convert to degrees
    return angle * 180 / math.pi;
  }

  /// Check whether the object has rotated relative to another analysis
  bool isRotatedComparedTo(PixelAnalysis other, {double tolerance = 5.0}) {
    final angleDiff = (estimatedRotationAngle - other.estimatedRotationAngle)
        .abs();
    return angleDiff > tolerance;
  }

  /// Check whether the object has translated
  bool isTranslatedComparedTo(PixelAnalysis other, {double tolerance = 2.0}) {
    final centerDiff = (centroid - other.centroid).distance;
    return centerDiff > tolerance;
  }

  /// Check whether the size has changed
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

  /// Detailed report for tests
  String toDetailedReport() {
    return '''
=== Detailed Visual Analysis ===
Red pixel count: $pixelCount
Center of mass: (${centroid.dx.toStringAsFixed(2)}, ${centroid.dy.toStringAsFixed(2)})
Bounding Box:
  - Top left: (${boundingBox.left.toStringAsFixed(2)}, ${boundingBox.top.toStringAsFixed(2)})
  - Bottom right: (${boundingBox.right.toStringAsFixed(2)}, ${boundingBox.bottom.toStringAsFixed(2)})
  - Size: ${objectWidth.toStringAsFixed(2)} x ${objectHeight.toStringAsFixed(2)}
Estimated rotation angle: ${estimatedRotationAngle.toStringAsFixed(2)}°
================================
''';
  }
}
