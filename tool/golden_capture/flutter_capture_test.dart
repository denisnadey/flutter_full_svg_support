// ignore_for_file: avoid_print
// Copyright 2024 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Flutter test file for capturing SVG renders and comparing against browser goldens.
///
/// This test file:
/// 1. Loads SVG files from example/assets/
/// 2. Renders them at fixed 800x600 viewport
/// 3. Captures PNG screenshots
/// 4. Compares against browser golden references
///
/// Run capture tests:
///   flutter test tool/golden_capture/flutter_capture_test.dart --tags=capture
///
/// Run comparison tests:
///   flutter test tool/golden_capture/flutter_capture_test.dart --tags=compare
@Tags(['golden'])
library;

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:full_svg_flutter/src/animation/animated_svg_picture.dart';
import 'package:flutter_test/flutter_test.dart';

import 'image_compare.dart';

/// Default viewport dimensions matching browser capture.
const double kViewportWidth = 800.0;
const double kViewportHeight = 600.0;

/// Default similarity threshold (95%).
const double kDefaultThreshold = 0.95;

/// Directory paths.
const String kSvgAssetsDir = 'example/assets/simple';
const String kBrowserGoldensDir = 'test/goldens/browser';
const String kFlutterGoldensDir = 'test/goldens/flutter';
const String kDiffOutputDir = 'test/goldens/diff';

/// List of SVG files to test.
/// Add SVG filenames (without .svg extension) to include in testing.
final List<String> svgTestFiles = [
  // Core shapes
  'rect',
  'circle',
  'ellipse',
  'line',
  'polyline',
  'polygon',
  'path',

  // Text
  'text_basic',

  // Transforms
  'transform_translate',
  'transform_rotate',
  'transform_scale',

  // Gradients
  'linearGradient',
  'radialGradient',

  // Clipping & Masking
  'clipPath_basic',
  'mask_basic',

  // Use & Symbols
  'use_basic',
  'symbol_basic',
];

void main() {
  // Set up test environment
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SVG Capture Tests', () {
    // Generate capture tests for each SVG file
    for (final svgName in _getAvailableSvgFiles()) {
      testWidgets('Capture $svgName', (WidgetTester tester) async {
        await _captureSvg(tester, svgName);
      }, tags: ['capture']);
    }
  });

  group('SVG Comparison Tests', () {
    // Generate comparison tests for each SVG file
    for (final svgName in _getAvailableSvgFiles()) {
      testWidgets('Compare $svgName: Flutter vs Browser', (
        WidgetTester tester,
      ) async {
        await _compareSvg(tester, svgName);
      }, tags: ['compare']);
    }
  });

  group('Full Pipeline Tests', () {
    // Capture and compare in one test
    for (final svgName in _getAvailableSvgFiles()) {
      testWidgets('Full test $svgName', (WidgetTester tester) async {
        // First capture
        await _captureSvg(tester, svgName);

        // Then compare (if browser golden exists)
        final browserGoldenFile = File('$kBrowserGoldensDir/$svgName.png');
        if (browserGoldenFile.existsSync()) {
          await _compareSvg(tester, svgName);
        } else {
          print('  ⚠️ Skipping comparison - no browser golden for $svgName');
        }
      }, tags: ['full']);
    }
  });
}

/// Gets list of available SVG files from the assets directory.
List<String> _getAvailableSvgFiles() {
  final dir = Directory(kSvgAssetsDir);
  if (!dir.existsSync()) {
    // Fall back to predefined list if directory doesn't exist
    return svgTestFiles;
  }

  final svgFiles = <String>[];
  for (final entity in dir.listSync()) {
    if (entity is File && entity.path.endsWith('.svg')) {
      final name = entity.path.split('/').last.replaceAll('.svg', '');
      svgFiles.add(name);
    }
  }

  // Sort for consistent ordering
  svgFiles.sort();

  // If no files found, use predefined list
  return svgFiles.isNotEmpty ? svgFiles : svgTestFiles;
}

/// Captures an SVG file to PNG.
Future<void> _captureSvg(WidgetTester tester, String svgName) async {
  print('📸 Capturing $svgName...');

  // Load SVG file
  final svgFile = File('$kSvgAssetsDir/$svgName.svg');
  if (!svgFile.existsSync()) {
    print('  ⚠️ SVG file not found: ${svgFile.path}');
    return;
  }

  final svgString = svgFile.readAsStringSync();

  // Set fixed viewport
  tester.view.physicalSize = const Size(kViewportWidth, kViewportHeight);
  tester.view.devicePixelRatio = 1.0;

  // Create a GlobalKey for the RepaintBoundary
  final repaintKey = GlobalKey();

  try {
    // Build widget with RepaintBoundary for capture
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
                autoPlay: false, // Static capture
              ),
            ),
          ),
        ),
      ),
    );

    // Wait for rendering (don't use pumpAndSettle with animations)
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Capture to PNG
    final pngBytes = await tester.runAsync<Uint8List?>(() async {
      final boundary =
          repaintKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) {
        return null;
      }

      final image = await boundary.toImage(pixelRatio: 1.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();

      return byteData?.buffer.asUint8List();
    });

    if (pngBytes == null) {
      fail('Failed to capture $svgName - could not get PNG bytes');
    }

    // Save to output directory
    final outputFile = File('$kFlutterGoldensDir/$svgName.png');
    await outputFile.parent.create(recursive: true);
    await outputFile.writeAsBytes(pngBytes);

    print('  ✅ Saved: ${outputFile.path} (${pngBytes.length} bytes)');
  } finally {
    // Reset viewport
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  }
}

/// Compares Flutter-rendered SVG against browser golden.
Future<void> _compareSvg(WidgetTester tester, String svgName) async {
  print('🔍 Comparing $svgName...');

  // Load Flutter golden
  final flutterGoldenFile = File('$kFlutterGoldensDir/$svgName.png');
  if (!flutterGoldenFile.existsSync()) {
    print('  ⚠️ Flutter golden not found: ${flutterGoldenFile.path}');
    print('  Run capture tests first: flutter test ... --tags=capture');
    return;
  }

  // Load browser golden
  final browserGoldenFile = File('$kBrowserGoldensDir/$svgName.png');
  if (!browserGoldenFile.existsSync()) {
    print('  ⚠️ Browser golden not found: ${browserGoldenFile.path}');
    print('  Run browser capture first: node tool/golden_capture/capture.js');
    return;
  }

  final flutterPng = flutterGoldenFile.readAsBytesSync();
  final browserPng = browserGoldenFile.readAsBytesSync();

  // Compare images
  final result = await compareImages(
    imageA: flutterPng,
    imageB: browserPng,
    perPixelThreshold: 0.05,
    generateDiff: true,
  );

  // Report results
  final percentage = (result.similarity * 100).toStringAsFixed(1);
  print(
    '  $svgName: $percentage% similar '
    '(${result.differentPixels} different pixels out of ${result.totalPixels})',
  );

  // Save diff image if available
  if (result.diffImage != null) {
    final diffFile = File('$kDiffOutputDir/$svgName.png');
    await diffFile.parent.create(recursive: true);
    await diffFile.writeAsBytes(result.diffImage!);
    print('  📊 Diff saved: ${diffFile.path}');
  }

  // Assert similarity threshold
  expect(
    result.passed(kDefaultThreshold),
    isTrue,
    reason:
        '$svgName: similarity ${result.similarity.toStringAsFixed(3)} '
        'below threshold $kDefaultThreshold',
  );

  print('  ✅ PASSED');
}

/// Captures a single SVG string to PNG bytes (utility function).
///
/// This can be used programmatically from other tests.
Future<Uint8List?> captureSvgToPng(
  WidgetTester tester,
  String svgString, {
  double width = kViewportWidth,
  double height = kViewportHeight,
  Duration? initialTime,
  bool autoPlay = false,
}) async {
  final repaintKey = GlobalKey();

  // Set viewport
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1.0;

  try {
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Colors.white,
          body: RepaintBoundary(
            key: repaintKey,
            child: SizedBox(
              width: width,
              height: height,
              child: AnimatedSvgPicture.string(
                svgString,
                width: width,
                height: height,
                fit: BoxFit.contain,
                autoPlay: autoPlay,
                initialTime: initialTime,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    return await tester.runAsync<Uint8List?>(() async {
      final boundary =
          repaintKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) return null;

      final image = await boundary.toImage(pixelRatio: 1.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();

      return byteData?.buffer.asUint8List();
    });
  } finally {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  }
}

/// Batch comparison result for multiple SVGs.
class BatchComparisonResult {
  BatchComparisonResult({
    required this.results,
    required this.passed,
    required this.failed,
    required this.skipped,
  });

  final Map<String, ImageCompareResult> results;
  final List<String> passed;
  final List<String> failed;
  final List<String> skipped;

  double get passRate => results.isEmpty ? 0.0 : passed.length / results.length;

  void printSummary() {
    print('\n📊 Batch Comparison Summary');
    print('=' * 50);
    print('Passed: ${passed.length}');
    print('Failed: ${failed.length}');
    print('Skipped: ${skipped.length}');
    print('Pass Rate: ${(passRate * 100).toStringAsFixed(1)}%');

    if (failed.isNotEmpty) {
      print('\nFailed tests:');
      for (final name in failed) {
        final result = results[name];
        if (result != null) {
          print('  ❌ $name: ${(result.similarity * 100).toStringAsFixed(1)}%');
        }
      }
    }
    print('=' * 50);
  }
}

/// Runs batch comparison for all available SVGs.
Future<BatchComparisonResult> runBatchComparison({
  double threshold = kDefaultThreshold,
}) async {
  final results = <String, ImageCompareResult>{};
  final passed = <String>[];
  final failed = <String>[];
  final skipped = <String>[];

  for (final svgName in _getAvailableSvgFiles()) {
    final flutterGoldenFile = File('$kFlutterGoldensDir/$svgName.png');
    final browserGoldenFile = File('$kBrowserGoldensDir/$svgName.png');

    if (!flutterGoldenFile.existsSync() || !browserGoldenFile.existsSync()) {
      skipped.add(svgName);
      continue;
    }

    final flutterPng = flutterGoldenFile.readAsBytesSync();
    final browserPng = browserGoldenFile.readAsBytesSync();

    final result = await compareImages(
      imageA: flutterPng,
      imageB: browserPng,
      perPixelThreshold: 0.05,
      generateDiff: false,
    );

    results[svgName] = result;

    if (result.passed(threshold)) {
      passed.add(svgName);
    } else {
      failed.add(svgName);
    }
  }

  return BatchComparisonResult(
    results: results,
    passed: passed,
    failed: failed,
    skipped: skipped,
  );
}
