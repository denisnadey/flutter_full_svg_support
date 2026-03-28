// Copyright 2024 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Golden comparison test suite for SVG rendering.
///
/// This test file compares Flutter-rendered SVGs against browser golden
/// references captured via Puppeteer.
///
/// ## Running Tests
///
/// Full test suite (all golden tests):
///   flutter test test/golden_comparison/golden_comparison_test.dart
///
/// Run with specific tag:
///   flutter test --tags=golden
///
/// Exclude golden tests during development:
///   flutter test --exclude-tags golden
///
/// ## Subset Mode (for faster development iteration)
///
/// Run only N random test cases:
///   GOLDEN_SUBSET=3 flutter test test/golden_comparison/golden_comparison_test.dart
///
/// Run specific test by name:
///   flutter test test/golden_comparison/golden_comparison_test.dart --name "dart"
///
/// ## Timeouts
///
/// Each test has a 30-second timeout. If a test hangs, it will fail fast
/// rather than blocking indefinitely.
///
/// ## Progress Logging
///
/// Tests print progress to stdout showing:
///   - Which test is running (e.g., "[1/12] Testing: dart")
///   - Time elapsed per test
///   - Overall progress percentage
///
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

/// Environment variable to run only a subset of tests.
/// Set GOLDEN_SUBSET=N to run only N test cases.
final int? _goldenSubset = int.tryParse(
  Platform.environment['GOLDEN_SUBSET'] ?? '',
);

/// Timeout for each individual golden test.
const Timeout _testTimeout = Timeout(Duration(seconds: 30));

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
    0.85,
  ),
  ('test/golden_comparison/svg_fixtures/gradients.svg', 'gradients', 0.95),
  ('test/golden_comparison/svg_fixtures/transforms.svg', 'transforms', 0.95),
  ('test/golden_comparison/svg_fixtures/clip_mask.svg', 'clip_mask', 0.90),
  (
    'test/golden_comparison/svg_fixtures/filters_blur.svg',
    'filters_blur',
    0.85,
  ),
  ('test/golden_comparison/svg_fixtures/text_tspan.svg', 'text_tspan', 0.90),
  (
    'test/golden_comparison/svg_fixtures/stroke_patterns.svg',
    'stroke_patterns',
    0.95,
  ),

  // Complex example assets (may take longer to process)
  // Uncomment when needed:
  // ('example/assets/astronaut_helmet.svg', 'astronaut_helmet', 0.90),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Determine which test cases to run
  List<TestCase> activeCases = testCases;
  if (_goldenSubset != null && _goldenSubset! > 0) {
    // Shuffle and take subset for faster development iteration
    final shuffled = List<TestCase>.from(testCases)..shuffle();
    activeCases = shuffled.take(_goldenSubset!).toList();
    // ignore: avoid_print
    print('\n🔧 GOLDEN_SUBSET=$_goldenSubset: Running ${activeCases.length} of ${testCases.length} tests\n');
  }

  group('Golden Comparison Tests', () {
    int testIndex = 0;
    final totalTests = activeCases.length;

    for (final (svgPath, name, threshold) in activeCases) {
      testIndex++;
      final currentIndex = testIndex; // Capture for closure

      testWidgets(
        'Golden: $name matches browser render',
        (tester) async {
          final stopwatch = Stopwatch()..start();
          // ignore: avoid_print
          print('\n[$currentIndex/$totalTests] 🧪 Testing: $name');
          // ignore: avoid_print
          print('    SVG: $svgPath');
          // Check if browser golden exists
          final browserGoldenFile = File('$kBrowserGoldensDir/$name.png');
          if (!browserGoldenFile.existsSync()) {
            // ignore: avoid_print
            print('    ⚠️  Skipping: browser golden not found');
            return;
          }
          // ignore: avoid_print
          print('    ✓ Browser golden found');

          // Read SVG
          final svgFile = File(svgPath);
          if (!svgFile.existsSync()) {
            // ignore: avoid_print
            print('    ⚠️  Skipping: SVG file not found');
            return;
          }
          final svgString = svgFile.readAsStringSync();
          // ignore: avoid_print
          print('    ✓ SVG loaded (${svgString.length} bytes)');

          // Set viewport
          tester.view.physicalSize = const Size(kViewportWidth, kViewportHeight);
          tester.view.devicePixelRatio = 1.0;
          // ignore: avoid_print
          print('    ✓ Viewport set to ${kViewportWidth.toInt()}x${kViewportHeight.toInt()}');

          try {
            // Create a GlobalKey for the RepaintBoundary
            final repaintKey = GlobalKey();

            // ignore: avoid_print
            print('    ⏳ Building widget...');

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

          // ignore: avoid_print
          print('    ✓ Widget built');

          // Wait for rendering
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));

          // Additional pump for font loading
          await tester.pump(const Duration(milliseconds: 200));
          // ignore: avoid_print
          print('    ✓ Render pumped');

          // Capture Flutter render with timeout
          // ignore: avoid_print
          print('    ⏳ Capturing Flutter render...');
          final flutterPng = await tester.runAsync<Uint8List?>(() async {
            final boundary =
                repaintKey.currentContext?.findRenderObject()
                    as RenderRepaintBoundary?;
            if (boundary == null) return null;

            final image = await boundary.toImage(pixelRatio: 1.0);
            final byteData = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            image.dispose();
            return byteData?.buffer.asUint8List();
          });

          if (flutterPng == null) {
            fail('Failed to capture $name - could not get PNG bytes');
          }
          // ignore: avoid_print
          print('    ✓ Flutter render captured (${flutterPng.length} bytes)');

          // Save Flutter render (wrap in runAsync to avoid blocking)
          // ignore: avoid_print
          print('    ⏳ Saving Flutter golden...');
          await tester.runAsync(() async {
            final flutterFile = File('$kFlutterGoldensDir/$name.png');
            await flutterFile.parent.create(recursive: true);
            await flutterFile.writeAsBytes(flutterPng);
          });
          // ignore: avoid_print
          print('    ✓ Flutter golden saved');

          // Compare (wrap in runAsync to avoid blocking)
          // ignore: avoid_print
          print('    ⏳ Comparing images...');
          final browserPng = browserGoldenFile.readAsBytesSync();
          final result = await tester.runAsync(() => compareImages(
            imageA: Uint8List.fromList(flutterPng),
            imageB: Uint8List.fromList(browserPng),
            perPixelThreshold: 0.05,
            generateDiff: true,
          ));

          if (result == null) {
            fail('Failed to compare images for $name');
          }
          // ignore: avoid_print
          print('    ✓ Comparison complete');

          // Save diff (wrap in runAsync to avoid blocking)
          if (result.diffImage != null) {
            await tester.runAsync(() async {
              final diffFile = File('$kDiffOutputDir/$name.png');
              await diffFile.parent.create(recursive: true);
              await diffFile.writeAsBytes(result.diffImage!);
            });
          }

          // Report
          stopwatch.stop();
          final percentage = (result.similarity * 100).toStringAsFixed(1);
          final thresholdPct = (threshold * 100).toStringAsFixed(0);
          final elapsed = stopwatch.elapsedMilliseconds;
          final passed = result.similarity >= threshold;
          final statusIcon = passed ? '✅' : '❌';

          // ignore: avoid_print
          print('    $statusIcon Result: $percentage% similar (threshold: $thresholdPct%)');
          // ignore: avoid_print
          print('    📊 ${result.differentPixels}/${result.totalPixels} different pixels');
          // ignore: avoid_print
          print('    ⏱️  Completed in ${elapsed}ms');
          // ignore: avoid_print
          print('    📁 Diff saved to: $kDiffOutputDir/$name.png');

          expect(
            result.similarity,
            greaterThanOrEqualTo(threshold),
            reason:
                '$name: similarity $percentage% '
                'is below threshold ${(threshold * 100).toStringAsFixed(0)}%',
          );
        } finally {
          // Reset viewport
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        }
      },
        timeout: _testTimeout,
      );
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
    final flutterCount = flutterDir.existsSync()
        ? flutterDir.listSync().whereType<File>().length
        : 0;
    final diffCount = diffDir.existsSync()
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
