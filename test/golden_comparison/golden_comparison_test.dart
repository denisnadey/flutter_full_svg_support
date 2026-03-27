// Copyright 2024 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Golden comparison test suite for SVG rendering.
///
/// This test file compares Flutter-rendered SVGs against browser golden
/// references captured via Puppeteer.
///
/// Run tests:
///   flutter test test/golden_comparison/golden_comparison_test.dart
///
/// Run with specific tag:
///   flutter test test/golden_comparison/golden_comparison_test.dart --tags=golden
@Tags(['golden'])
library golden_comparison_test;

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_svg/src/animation/animated_svg_picture.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/golden_capture/image_compare.dart';

/// Viewport dimensions matching browser capture.
const double kViewportWidth = 800.0;
const double kViewportHeight = 600.0;

/// Directory paths.
const String kBrowserGoldensDir = 'test/goldens/browser';
const String kFlutterGoldensDir = 'test/goldens/flutter';
const String kDiffOutputDir = 'test/goldens/diff';

/// Test case definition: (svgPath, goldenName, threshold)
typedef TestCase = (String svgPath, String goldenName, double threshold);

/// List of SVG test cases with their similarity thresholds.
/// Lower thresholds for complex SVGs (fonts: 0.90, filters: 0.85, simple shapes: 0.95)
final List<TestCase> testCases = [
  // Example assets (simpler ones first)
  ('example/assets/dart.svg', 'dart', 0.95),
  ('example/assets/flutter_logo.svg', 'flutter_logo', 0.95),
  ('example/assets/svg_currentcolor.svg', 'svg_currentcolor', 0.95),
  ('example/assets/text_transform.svg', 'text_transform', 0.90),

  // Custom test fixtures
  ('test/golden_comparison/svg_fixtures/text_basic.svg', 'text_basic', 0.90),
  (
    'test/golden_comparison/svg_fixtures/text_embedded_font.svg',
    'text_embedded_font',
    0.85
  ),
  ('test/golden_comparison/svg_fixtures/gradients.svg', 'gradients', 0.95),
  ('test/golden_comparison/svg_fixtures/transforms.svg', 'transforms', 0.95),
  ('test/golden_comparison/svg_fixtures/clip_mask.svg', 'clip_mask', 0.90),
  (
    'test/golden_comparison/svg_fixtures/filters_blur.svg',
    'filters_blur',
    0.85
  ),
  ('test/golden_comparison/svg_fixtures/text_tspan.svg', 'text_tspan', 0.90),
  (
    'test/golden_comparison/svg_fixtures/stroke_patterns.svg',
    'stroke_patterns',
    0.95
  ),

  // Complex example assets (may take longer to process)
  // Uncomment when needed:
  // ('example/assets/astronaut_helmet.svg', 'astronaut_helmet', 0.90),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Golden Comparison Tests', () {
    for (final (svgPath, name, threshold) in testCases) {
      testWidgets('Golden: $name matches browser render', (tester) async {
        // Check if browser golden exists
        final browserGoldenFile = File('$kBrowserGoldensDir/$name.png');
        if (!browserGoldenFile.existsSync()) {
          // ignore: avoid_print
          print('⚠️  Skipping $name: browser golden not found');
          return;
        }

        // Read SVG
        final svgFile = File(svgPath);
        if (!svgFile.existsSync()) {
          // ignore: avoid_print
          print('⚠️  Skipping $name: SVG file not found at $svgPath');
          return;
        }
        final svgString = svgFile.readAsStringSync();

        // Set viewport
        tester.view.physicalSize = const Size(kViewportWidth, kViewportHeight);
        tester.view.devicePixelRatio = 1.0;

        try {
          // Create a GlobalKey for the RepaintBoundary
          final repaintKey = GlobalKey();

          // Build and render widget
          await tester.pumpWidget(
            MaterialApp(
              debugShowCheckedModeBanner: false,
              home: Scaffold(
                backgroundColor: Colors.white,
                body: RepaintBoundary(
                  key: repaintKey,
                  child: SizedBox(
                    width: kViewportWidth,
                    height: kViewportHeight,
                    child: AnimatedSvgPicture.string(
                      svgString,
                      width: kViewportWidth,
                      height: kViewportHeight,
                      fit: BoxFit.contain,
                      autoPlay: false,
                    ),
                  ),
                ),
              ),
            ),
          );

          // Wait for rendering
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));

          // Additional pump for font loading
          await tester.pump(const Duration(milliseconds: 200));

          // Capture Flutter render
          final flutterPng = await tester.runAsync<Uint8List?>(() async {
            final boundary = repaintKey.currentContext?.findRenderObject()
                as RenderRepaintBoundary?;
            if (boundary == null) return null;

            final image = await boundary.toImage(pixelRatio: 1.0);
            final byteData =
                await image.toByteData(format: ui.ImageByteFormat.png);
            image.dispose();
            return byteData?.buffer.asUint8List();
          });

          if (flutterPng == null) {
            fail('Failed to capture $name - could not get PNG bytes');
          }

          // Save Flutter render
          final flutterFile = File('$kFlutterGoldensDir/$name.png');
          await flutterFile.parent.create(recursive: true);
          await flutterFile.writeAsBytes(flutterPng);

          // Compare
          final browserPng = browserGoldenFile.readAsBytesSync();
          final result = await compareImages(
            imageA: Uint8List.fromList(flutterPng),
            imageB: Uint8List.fromList(browserPng),
            perPixelThreshold: 0.05,
            generateDiff: true,
          );

          // Save diff
          if (result.diffImage != null) {
            final diffFile = File('$kDiffOutputDir/$name.png');
            await diffFile.parent.create(recursive: true);
            await diffFile.writeAsBytes(result.diffImage!);
          }

          // Report
          final percentage = (result.similarity * 100).toStringAsFixed(1);
          // ignore: avoid_print
          print(
            '$name: $percentage% similar '
            '(${result.differentPixels}/${result.totalPixels} different pixels)',
          );

          expect(
            result.similarity,
            greaterThanOrEqualTo(threshold),
            reason: '$name: similarity $percentage% '
                'is below threshold ${(threshold * 100).toStringAsFixed(0)}%',
          );
        } finally {
          // Reset viewport
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        }
      });
    }
  });

  // Summary test
  test('Print golden comparison summary', () {
    final browserDir = Directory(kBrowserGoldensDir);
    final flutterDir = Directory(kFlutterGoldensDir);
    final diffDir = Directory(kDiffOutputDir);

    if (!browserDir.existsSync()) {
      // ignore: avoid_print
      print('No browser goldens found');
      return;
    }

    final browserFiles = browserDir.listSync().whereType<File>().toList();
    final flutterCount =
        flutterDir.existsSync()
            ? flutterDir.listSync().whereType<File>().length
            : 0;
    final diffCount =
        diffDir.existsSync()
            ? diffDir.listSync().whereType<File>().length
            : 0;

    // ignore: avoid_print
    print('\n=== Golden Comparison Summary ===');
    // ignore: avoid_print
    print('Browser goldens: ${browserFiles.length}');
    // ignore: avoid_print
    print('Flutter goldens: $flutterCount');
    // ignore: avoid_print
    print('Diff images: $diffCount');
    // ignore: avoid_print
    print('================================\n');
  });
}
