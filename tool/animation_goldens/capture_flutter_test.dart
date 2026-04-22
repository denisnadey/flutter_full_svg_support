// Copyright 2024 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Flutter animation frame capture test.
///
/// Renders animated SVGs at specific time points and saves frames as PNGs
/// for comparison against browser golden references.
///
/// ## Running
///
///   flutter test tool/animation_goldens/capture_flutter_test.dart --tags animation_golden
///
/// ## Environment Variables
///
///   ANIM_DURATION=15   Total animation duration in seconds (default: 15)
///   ANIM_FRAMES=15     Number of frames to capture (default: 15)
///   ANIM_SUBSET=N      Run only N random SVGs for quick iteration
///
@Tags(['animation_golden'])
library capture_flutter_test;

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:full_svg_flutter/src/animation/animated_svg_controller.dart';
import 'package:full_svg_flutter/src/animation/animated_svg_picture.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Configuration from environment
// ---------------------------------------------------------------------------

final int _animDuration =
    int.tryParse(Platform.environment['ANIM_DURATION'] ?? '') ?? 15;

final int _animFrames =
    int.tryParse(Platform.environment['ANIM_FRAMES'] ?? '') ?? 15;

final int? _animSubset = int.tryParse(
  Platform.environment['ANIM_SUBSET'] ?? '',
);

// ---------------------------------------------------------------------------
// Directories
// ---------------------------------------------------------------------------

const String kSvgFixturesDir = 'test/animation_goldens/svg_fixtures';
const String kFlutterOutputDir = 'test/animation_goldens/flutter';

// ---------------------------------------------------------------------------
// Viewport (must match browser capture)
// ---------------------------------------------------------------------------

const double kViewportWidth = 800.0;
const double kViewportHeight = 600.0;

// ---------------------------------------------------------------------------
// Timeout per SVG (all frames)
// ---------------------------------------------------------------------------

const Timeout _testTimeout = Timeout(Duration(seconds: 120));

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Discover all SVG files in the fixtures directory.
List<FileSystemEntity> _discoverSvgFixtures() {
  final dir = Directory(kSvgFixturesDir);
  if (!dir.existsSync()) {
    return [];
  }
  final files =
      dir
          .listSync()
          .where((e) => e.path.toLowerCase().endsWith('.svg'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  return files;
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  var fixtures = _discoverSvgFixtures();
  if (fixtures.isEmpty) {
    // ignore: avoid_print
    print('No SVG fixtures found in $kSvgFixturesDir');
    return;
  }

  // Subset mode
  if (_animSubset != null &&
      _animSubset! > 0 &&
      _animSubset! < fixtures.length) {
    final shuffled = List<FileSystemEntity>.from(fixtures)..shuffle();
    fixtures = shuffled.take(_animSubset!).toList();
    // ignore: avoid_print
    print(
      '\nANIM_SUBSET=$_animSubset: Capturing ${fixtures.length} of ${_discoverSvgFixtures().length} SVGs\n',
    );
  }

  // ignore: avoid_print
  print('');
  // ignore: avoid_print
  print('=' * 60);
  // ignore: avoid_print
  print('  Flutter Animation Frame Capture');
  // ignore: avoid_print
  print('=' * 60);
  // ignore: avoid_print
  print('  Duration : ${_animDuration}s');
  // ignore: avoid_print
  print('  Frames   : $_animFrames');
  // ignore: avoid_print
  print('  SVGs     : ${fixtures.length}');
  // ignore: avoid_print
  print('=' * 60);
  // ignore: avoid_print
  print('');

  group('Animation Frame Capture', () {
    for (final fixture in fixtures) {
      final svgPath = fixture.path;
      final baseName = svgPath.split('/').last.replaceAll('.svg', '');

      testWidgets('Capture frames: $baseName', (tester) async {
        // ignore: avoid_print
        print('\n  Capturing: $baseName ($_animFrames frames)...');

        // Read SVG
        final svgFile = File(svgPath);
        if (!svgFile.existsSync()) {
          // ignore: avoid_print
          print('    SKIP: SVG file not found');
          return;
        }
        final svgString = svgFile.readAsStringSync();

        // Create output directory
        final outputDir = Directory('$kFlutterOutputDir/$baseName');
        await tester.runAsync(() async {
          if (!outputDir.existsSync()) {
            outputDir.createSync(recursive: true);
          }
        });

        // Set viewport
        tester.view.physicalSize = const Size(kViewportWidth, kViewportHeight);
        tester.view.devicePixelRatio = 1.0;

        try {
          // Create controller for seeking
          final controller = AnimatedSvgController();
          final repaintKey = GlobalKey();

          // Build widget — autoPlay false, we control time via seek.
          // White Container ensures background matches browser capture.
          await tester.pumpWidget(
            MaterialApp(
              debugShowCheckedModeBanner: false,
              home: RepaintBoundary(
                key: repaintKey,
                child: Container(
                  width: kViewportWidth,
                  height: kViewportHeight,
                  color: Colors.white,
                  child: AnimatedSvgPicture.string(
                    svgString,
                    width: kViewportWidth,
                    height: kViewportHeight,
                    fit: BoxFit.contain,
                    autoPlay: false,
                    controller: controller,
                  ),
                ),
              ),
            ),
          );

          // Initial pump to build widget tree
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 200));
          // Wait for async image decodes (e.g., large embedded WebP data URIs)
          // so frame_00 reflects a fully-loaded scene.
          await tester.pumpAndSettle(const Duration(milliseconds: 50));
          // Some codecs complete on background threads without scheduling extra
          // animation frames. Give them a short real-time window, then pump.
          await tester.runAsync(() async {
            await Future<void>.delayed(const Duration(milliseconds: 700));
          });
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 16));

          // Capture frames at each time point
          for (int i = 0; i < _animFrames; i++) {
            // Include both loop endpoints: t=0 and t=duration.
            final frameProgress = _animFrames > 1 ? i / (_animFrames - 1) : 0.0;
            final timeSeconds = _animDuration * frameProgress;
            final timeDuration = Duration(
              milliseconds: (timeSeconds * 1000).round(),
            );
            final frameIndex = i.toString().padLeft(2, '0');

            // Seek to the target time
            controller.seek(timeDuration);

            // Pump to process the seek and re-render
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 100));

            // Capture the frame
            final pngBytes = await tester.runAsync<Uint8List?>(() async {
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

            if (pngBytes == null) {
              // ignore: avoid_print
              print(
                '    WARN: Failed to capture frame $frameIndex (t=${timeSeconds.toStringAsFixed(1)}s)',
              );
              continue;
            }

            // Save frame
            await tester.runAsync(() async {
              final frameFile = File('${outputDir.path}/frame_$frameIndex.png');
              await frameFile.writeAsBytes(pngBytes);
            });
          }

          // ignore: avoid_print
          print(
            '    -> $_animFrames frames saved to $kFlutterOutputDir/$baseName/',
          );

          controller.dispose();
        } finally {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        }
      }, timeout: _testTimeout);
    }
  });
}
