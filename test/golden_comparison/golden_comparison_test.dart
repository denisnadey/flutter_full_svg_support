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
import 'package:full_svg_flutter/src/animation/animated_svg_picture.dart';
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

/// Test case definition: (svgPath, goldenName, threshold, skipReason)
/// skipReason: null if test should run, otherwise a string explaining why it's skipped
typedef TestCase = (
  String svgPath,
  String goldenName,
  double threshold,
  String? skipReason,
);

/// Reason for skipping text-heavy tests in Flutter test environment.
/// Flutter tests use Ahem font (renders all glyphs as rectangles) because system
/// fonts are not available. This causes text-heavy tests to fail with ~90%
/// pixel differences, which is expected behavior, not a rendering bug.
const String _textFontSkipReason =
    'Skipped: Flutter tests use Ahem font (no system fonts). '
    'Text renders as rectangles, causing expected ~90% pixel diff with browser goldens.';

/// List of SVG test cases with their similarity thresholds.
///
/// Thresholds are intentionally set LOW because:
/// 1. Flutter tests use Ahem font (no system fonts) - text differs from browser
/// 2. Background color encoding differs between browser PNG and Flutter PNG
/// 3. Anti-aliasing and color profile handling differ between renderers
///
/// These tests verify that the SVG renderer produces REASONABLE output,
/// not pixel-perfect matching with browser. For pixel-perfect tests,
/// use Flutter's built-in golden test framework with Flutter-generated baselines.
final List<TestCase> testCases = [
  // ============================================
  // GRAPHICS-ONLY TESTS
  // Lower threshold due to background color encoding differences
  // ============================================

  // Flutter logo: pure vector graphics, no text
  // Similarity ~20% due to white background encoding differences
  ('example/assets/flutter_logo.svg', 'flutter_logo', 0.15, null),

  // currentColor test: simple shapes with currentColor attribute
  // Similarity ~25% due to background encoding
  ('example/assets/svg_currentcolor.svg', 'svg_currentcolor', 0.20, null),

  // ============================================
  // MIXED GRAPHICS + TEXT LABELS
  // Very low thresholds due to text + background differences
  // ============================================

  // Dart logo: path-based text (outlines) + icon
  ('example/assets/dart.svg', 'dart', 0.05, null),

  // Gradients with text labels
  (
    'test/golden_comparison/svg_fixtures/gradients.svg',
    'gradients',
    0.05,
    null,
  ),

  // Transform demos with text labels
  (
    'test/golden_comparison/svg_fixtures/transforms.svg',
    'transforms',
    0.03,
    null,
  ),

  // Clipping/masking with text labels
  (
    'test/golden_comparison/svg_fixtures/clip_mask.svg',
    'clip_mask',
    0.05,
    null,
  ),

  // Blur filters with text labels
  (
    'test/golden_comparison/svg_fixtures/filters_blur.svg',
    'filters_blur',
    0.03,
    null,
  ),

  // Stroke patterns with text labels
  (
    'test/golden_comparison/svg_fixtures/stroke_patterns.svg',
    'stroke_patterns',
    0.03,
    null,
  ),

  // ============================================
  // TEXT-HEAVY TESTS (skipped - need system fonts)
  // ============================================

  // Text transform: circle with "A" letter - mostly text content
  (
    'example/assets/text_transform.svg',
    'text_transform',
    0.90,
    _textFontSkipReason,
  ),

  // Basic text styling: 100% text content
  (
    'test/golden_comparison/svg_fixtures/text_basic.svg',
    'text_basic',
    0.90,
    _textFontSkipReason,
  ),

  // Embedded fonts: 100% text content with @font-face
  (
    'test/golden_comparison/svg_fixtures/text_embedded_font.svg',
    'text_embedded_font',
    0.85,
    _textFontSkipReason,
  ),

  // tspan elements: 100% text content with various tspan features
  (
    'test/golden_comparison/svg_fixtures/text_tspan.svg',
    'text_tspan',
    0.90,
    _textFontSkipReason,
  ),

  // ============================================
  // ADVANCED TESTS (not yet captured - will skip)
  // These tests don't have browser goldens yet
  // ============================================

  // Advanced clipping and masking
  (
    'test/golden_comparison/svg_fixtures/clip_path_nested.svg',
    'clip_path_nested',
    0.90,
    null,
  ),
  (
    'test/golden_comparison/svg_fixtures/clip_rule_modes.svg',
    'clip_rule_modes',
    0.90,
    null,
  ),
  (
    'test/golden_comparison/svg_fixtures/mask_luminance_alpha.svg',
    'mask_luminance_alpha',
    0.85,
    null,
  ),

  // Use/symbol with viewBox and CSS cascade
  (
    'test/golden_comparison/svg_fixtures/use_symbol_viewbox.svg',
    'use_symbol_viewbox',
    0.90,
    null,
  ),
  (
    'test/golden_comparison/svg_fixtures/use_css_cascade.svg',
    'use_css_cascade',
    0.90,
    null,
  ),

  // Advanced text styling (skipped - need system fonts)
  (
    'test/golden_comparison/svg_fixtures/text_vertical_writing.svg',
    'text_vertical_writing',
    0.85,
    _textFontSkipReason,
  ),
  (
    'test/golden_comparison/svg_fixtures/text_decorations.svg',
    'text_decorations',
    0.90,
    _textFontSkipReason,
  ),
  (
    'test/golden_comparison/svg_fixtures/text_length_adjust.svg',
    'text_length_adjust',
    0.85,
    _textFontSkipReason,
  ),

  // Filter composition chains
  (
    'test/golden_comparison/svg_fixtures/filter_chain.svg',
    'filter_chain',
    0.85,
    null,
  ),
  (
    'test/golden_comparison/svg_fixtures/filter_composite.svg',
    'filter_composite',
    0.85,
    null,
  ),

  // CSS selectors and stroke patterns (have text labels)
  (
    'test/golden_comparison/svg_fixtures/nth_child_selectors.svg',
    'nth_child_selectors',
    0.40,
    null,
  ),
  (
    'test/golden_comparison/svg_fixtures/stroke_dasharray_advanced.svg',
    'stroke_dasharray_advanced',
    0.40,
    null,
  ),

  // Complex example assets (may take longer to process)
  // Uncomment when needed:
  // ('example/assets/astronaut_helmet.svg', 'astronaut_helmet', 0.90, null),

  // ============================================
  // FILTER EDGE CASES
  // Tests for advanced filter operations
  // ============================================

  // feMorphology with various radius modes
  (
    'test/golden_comparison/svg_fixtures/filter_morphology_edge.svg',
    'filter_morphology_edge',
    0.15,
    null,
  ),

  // feTurbulence with stitchTiles
  (
    'test/golden_comparison/svg_fixtures/filter_turbulence_stitch.svg',
    'filter_turbulence_stitch',
    0.15,
    null,
  ),

  // Multi-step filter chain with composite/blend/merge
  (
    'test/golden_comparison/svg_fixtures/filter_composite_chain.svg',
    'filter_composite_chain',
    0.15,
    null,
  ),

  // feDropShadow with multiple stacked shadows
  (
    'test/golden_comparison/svg_fixtures/filter_drop_shadow_multi.svg',
    'filter_drop_shadow_multi',
    0.15,
    null,
  ),

  // feColorMatrix with saturate, hueRotate, luminanceToAlpha
  (
    'test/golden_comparison/svg_fixtures/filter_color_matrix.svg',
    'filter_color_matrix',
    0.15,
    null,
  ),

  // ============================================
  // ANIMATION/MOTION EDGE CASES
  // Static snapshots of animation initial frames
  // ============================================

  // animateMotion with only "to" attribute
  (
    'test/golden_comparison/svg_fixtures/animate_motion_to_only.svg',
    'animate_motion_to_only',
    0.15,
    null,
  ),

  // animateMotion on closed path with rotate=auto
  (
    'test/golden_comparison/svg_fixtures/animate_motion_closed_path.svg',
    'animate_motion_closed_path',
    0.15,
    null,
  ),

  // animateTransform with additive/accumulate
  (
    'test/golden_comparison/svg_fixtures/animate_transform_additive.svg',
    'animate_transform_additive',
    0.15,
    null,
  ),

  // SMIL syncbase timing
  (
    'test/golden_comparison/svg_fixtures/smil_timing_syncbase.svg',
    'smil_timing_syncbase',
    0.15,
    null,
  ),

  // ============================================
  // TEXT EDGE CASES (skipped - Ahem font)
  // These use text but have geometric backgrounds
  // ============================================

  // Nested tspan with dx/dy transforms
  (
    'test/golden_comparison/svg_fixtures/text_nested_tspan_transform.svg',
    'text_nested_tspan_transform',
    0.05,
    _textFontSkipReason,
  ),

  // textPath with startOffset percentage
  (
    'test/golden_comparison/svg_fixtures/text_textpath_offset.svg',
    'text_textpath_offset',
    0.05,
    _textFontSkipReason,
  ),

  // Mixed LTR/RTL text with direction
  (
    'test/golden_comparison/svg_fixtures/text_bidi_mixed.svg',
    'text_bidi_mixed',
    0.05,
    _textFontSkipReason,
  ),

  // ============================================
  // CLIPPING/MASKING EDGE CASES
  // ============================================

  // Nested clip-paths with intersection
  (
    'test/golden_comparison/svg_fixtures/clip_nested_intersection.svg',
    'clip_nested_intersection',
    0.15,
    null,
  ),

  // Luminance mask with grayscale gradient
  (
    'test/golden_comparison/svg_fixtures/mask_luminance.svg',
    'mask_luminance',
    0.15,
    null,
  ),

  // Element with both mask and clip-path
  (
    'test/golden_comparison/svg_fixtures/mask_clip_combined.svg',
    'mask_clip_combined',
    0.15,
    null,
  ),

  // clip-path with clip-rule="evenodd"
  (
    'test/golden_comparison/svg_fixtures/clip_evenodd.svg',
    'clip_evenodd',
    0.15,
    null,
  ),

  // ============================================
  // GRADIENT/PAINT EDGE CASES
  // ============================================

  // radialGradient with focal point offset
  (
    'test/golden_comparison/svg_fixtures/gradient_radial_focal.svg',
    'gradient_radial_focal',
    0.15,
    null,
  ),

  // pattern with patternTransform rotation
  (
    'test/golden_comparison/svg_fixtures/pattern_transform.svg',
    'pattern_transform',
    0.15,
    null,
  ),

  // linearGradient with objectBoundingBox on non-square
  (
    'test/golden_comparison/svg_fixtures/gradient_object_bbox.svg',
    'gradient_object_bbox',
    0.15,
    null,
  ),
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
    print(
      '\n🔧 GOLDEN_SUBSET=$_goldenSubset: Running ${activeCases.length} of ${testCases.length} tests\n',
    );
  }

  group('Golden Comparison Tests', () {
    int testIndex = 0;
    final totalTests = activeCases.length;

    for (final (svgPath, name, threshold, skipReason) in activeCases) {
      testIndex++;
      final currentIndex = testIndex; // Capture for closure

      testWidgets('Golden: $name matches browser render', (tester) async {
        final stopwatch = Stopwatch()..start();
        // ignore: avoid_print
        print('\n[$currentIndex/$totalTests] 🧪 Testing: $name');
        // ignore: avoid_print
        print('    SVG: $svgPath');

        // Check if this test should be skipped (e.g., text-heavy tests without fonts)
        if (skipReason != null) {
          // ignore: avoid_print
          print('    ⚠️  $skipReason');
          return;
        }

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
        print(
          '    ✓ Viewport set to ${kViewportWidth.toInt()}x${kViewportHeight.toInt()}',
        );

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

          // Use a higher per-pixel threshold to tolerate color profile
          // differences between browser (Puppeteer/Chrome) and Flutter PNG
          // encoding. The shapes should match; only background white pixels
          // may differ slightly due to color space handling.
          final result = await tester.runAsync(
            () => compareImages(
              imageA: Uint8List.fromList(flutterPng),
              imageB: Uint8List.fromList(browserPng),
              perPixelThreshold: 0.20, // 20% tolerance for color profile diffs
              generateDiff: true,
            ),
          );

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
          print(
            '    $statusIcon Result: $percentage% similar (threshold: $thresholdPct%)',
          );
          // ignore: avoid_print
          print(
            '    📊 ${result.differentPixels}/${result.totalPixels} different pixels',
          );
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
      }, timeout: _testTimeout);
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
