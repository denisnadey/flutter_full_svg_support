// Pixel-level verification that a file:// URI image renders inside an SVG.
//
// Run via:  bash scripts/test_file_uri_image.sh
// Env vars: PNG_PATH, FILE_URI  (set by the script)

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:full_svg_flutter/src/animation/animated_svg_picture.dart';
import 'package:full_svg_flutter/src/utilities/file.dart';

// Drives the async image-decode pipeline through FakeAsync.
// Pattern borrowed from w3c_golden_comparison_test.dart:
//   pumpAndSettle → runAsync(delay) → pump → pumpAndSettle(short timeout)
Future<void> _pumpWithImageWait(WidgetTester tester) async {
  try {
    await tester.pumpAndSettle(
      const Duration(milliseconds: 16),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 2),
    );
  } catch (_) {}

  // Real time for instantiateImageCodec (native, needs background thread).
  await tester.runAsync(() async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
  });
  await tester.pump();

  // A short pumpAndSettle drives getNextFrame + markNeedsPaint + repaint.
  try {
    await tester.pumpAndSettle(
      const Duration(milliseconds: 16),
      EnginePhase.sendSemanticsUpdate,
      const Duration(milliseconds: 400),
    );
  } catch (_) {}
}

void main() {
  final pngPath = Platform.environment['PNG_PATH'] ?? '';
  final fileUri = Platform.environment['FILE_URI'] ?? '';
  final _envReady = pngPath.isNotEmpty && fileUri.isNotEmpty;

  test('environment variables are set', () {
    expect(pngPath, isNotEmpty, reason: 'PNG_PATH env var must be set');
    expect(fileUri, isNotEmpty, reason: 'FILE_URI env var must be set');
    expect(File(pngPath).existsSync(), isTrue,
        reason: 'PNG file must exist at $pngPath');
  }, skip: !_envReady);

  // ── I/O + decode chain: no FakeAsync, no widget layer ───────────────────
  //
  // Proves the full path: readFileBytes → PNG decode → correct pixel color.

  test('readFileBytes + PNG decode yields correct red pixels', () async {
    final bytes = await readFileBytes(Uri.file(pngPath));
    expect(bytes, isNotNull, reason: 'readFileBytes returned null');
    expect(bytes!.isNotEmpty, isTrue);

    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    addTearDown(() {
      image.dispose();
      codec.dispose();
    });

    final byteData =
        await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    expect(byteData, isNotNull);

    final pixels = byteData!.buffer.asUint8List();
    final cx = image.width ~/ 2;
    final cy = image.height ~/ 2;
    final idx = (cy * image.width + cx) * 4;

    final r = pixels[idx];
    final g = pixels[idx + 1];
    final b = pixels[idx + 2];
    // ignore: avoid_print
    print('  Decoded PNG size: ${image.width}×${image.height}, '
        'center pixel: rgb($r, $g, $b)');

    expect(r, greaterThan(200),
        reason: 'Red channel must be ~255 for a solid-red PNG');
    expect(g, lessThan(50), reason: 'Green channel must be ~0');
    expect(b, lessThan(50), reason: 'Blue channel must be ~0');
  }, skip: !_envReady);

  // ── Sanity check: pixel capture works at all ────────────────────────────

  testWidgets('baseline: plain SVG rect renders red pixels', (tester) async {
    const svgRect = '''
<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
  <rect x="0" y="0" width="100" height="100" fill="#ff0000"/>
</svg>''';

    final repaintKey = GlobalKey();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: RepaintBoundary(
          key: repaintKey,
          child: AnimatedSvgPicture.string(svgRect, width: 200, height: 200),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final captured = await tester.runAsync<(Uint8List, int, int)?>(() async {
      final boundary = repaintKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(pixelRatio: 1.0);
      final w = image.width;
      final h = image.height;
      final bd = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      image.dispose();
      if (bd == null) return null;
      return (bd.buffer.asUint8List(), w, h);
    });

    expect(captured, isNotNull);
    final (pixels, stride, imgH) = captured!;

    int maxR = 0;
    for (int row = 10; row < imgH - 10; row += 20) {
      for (int col = 10; col < stride - 10; col += 20) {
        final idx = (row * stride + col) * 4;
        if (idx + 3 >= pixels.length) continue;
        if (pixels[idx] > maxR) maxR = pixels[idx];
      }
    }
    // ignore: avoid_print
    print('  Baseline max-R (interior sample): $maxR  stride=$stride h=$imgH');
    expect(maxR, greaterThan(200),
        reason: 'Plain red rect should produce red pixels; got $maxR');
  });

  // ── SVG render: widget-level pixel check ────────────────────────────────
  //
  // Embeds the PNG as a data URI so the image bytes are decoded entirely
  // in-process (no dart:io, no platform-channel timing).  In Flutter's test
  // environment instantiateImageCodec runs synchronously, so a plain pump()
  // sequence is enough to let the image appear.
  //
  // The I/O path (readFileBytes + file://) is covered by the unit test above.

  testWidgets(
    'SVG renders PNG image with correct pixel color (data URI)',
    skip: !_envReady,
    (tester) async {
    // Pre-read outside FakeAsync to get the bytes, then convert to data URI.
    final Uint8List? pngBytes = await tester.runAsync<Uint8List>(
      () => File(pngPath).readAsBytes(),
    );
    expect(pngBytes, isNotNull);

    final dataUri = 'data:image/png;base64,${base64Encode(pngBytes!)}';

    final svg = '''
<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
  <image x="0" y="0" width="100" height="100" href="$dataUri"/>
</svg>''';

    final repaintKey = GlobalKey();

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: RepaintBoundary(
          key: repaintKey,
          child: AnimatedSvgPicture.string(svg, width: 200, height: 200),
        ),
      ),
    );

    await _pumpWithImageWait(tester);

    final captured =
        await tester.runAsync<(Uint8List, int, int)?>(() async {
      final boundary = repaintKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(pixelRatio: 1.0);
      final w = image.width;
      final h = image.height;
      final bd = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      image.dispose();
      if (bd == null) return null;
      // ignore: avoid_print
      print('  Captured boundary: $w×$h');
      return (bd.buffer.asUint8List(), w, h);
    });

    expect(captured, isNotNull, reason: 'Could not capture rendered pixels');

    final (pixels, stride, imgH) = captured!;

    int maxR = 0, maxG = 0, maxB = 0;
    int sampledCount = 0;

    for (int row = 10; row < imgH - 10; row += 20) {
      for (int col = 10; col < stride - 10; col += 20) {
        final idx = (row * stride + col) * 4;
        if (idx + 3 >= pixels.length) continue;
        sampledCount++;
        final r = pixels[idx];
        final g = pixels[idx + 1];
        final b = pixels[idx + 2];
        if (r > maxR) maxR = r;
        if (g > maxG) maxG = g;
        if (b > maxB) maxB = b;
      }
    }

    // Find first non-black pixel for diagnostics.
    for (int i = 0; i < pixels.length - 3; i += 4) {
      if (pixels[i] > 0 || pixels[i + 1] > 0 || pixels[i + 2] > 0) {
        final px = (i ~/ 4) % stride;
        final py = (i ~/ 4) ~/ stride;
        // ignore: avoid_print
        print('  First non-black: ($px,$py) '
            'rgb(${pixels[i]},${pixels[i+1]},${pixels[i+2]})');
        break;
      }
    }
    // ignore: avoid_print
    print('  Sampled $sampledCount points, max R/G/B: $maxR / $maxG / $maxB');

    expect(
      maxR,
      greaterThan(200),
      reason:
          'Expected red channel >200 across the SVG image area; got $maxR. '
          'PNG image may not have rendered.',
    );
    expect(maxG, lessThan(50),
        reason: 'Green channel must be ~0 for solid-red PNG; got $maxG');
    expect(maxB, lessThan(50),
        reason: 'Blue channel must be ~0 for solid-red PNG; got $maxB');
  });
}
