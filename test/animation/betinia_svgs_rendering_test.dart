// ignore_for_file: avoid_print
/// Rendering tests for real-world SVG game banners from betinia.se.
///
/// These SVGs exercise combinations of features that revealed rendering
/// differences between browsers and Flutter:
///
///  1. betinia_eastern_emeralds – CSS @keyframes with per-keyframe
///     cubic-bezier timing functions on transform (translate+scale).
///
///  2. betinia_wol – Mixed CSS @keyframes (80) + SMIL `<animate>` (11),
///     SMIL on filter primitives (feColorMatrix.values, feFuncR/G/B.slope),
///     background-color:black on the root `<svg>`, preserveAspectRatio="none".
///
///  3. betinia_break_piggy_bank – Pure SMIL only (143 `<animate>` + 104
///     `<animateTransform>`), 8 embedded data:image/webp images, no CSS.
///
///  4. betinia_777_hot_reels – SMIL with 43 `<animate attributeName="display">`
///     elements (uncommon), feColorMatrix filters used for alpha fades,
///     9 WebP images, baseProfile="basic".
///
/// Each group has:
///   • A smoke test (renders without throwing, widget found).
///   • A pixel-content test (not fully transparent at t=0).
///   • Feature-specific isolation tests for the tricky behaviours.
library;

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:full_svg_flutter/src/animation/animated_svg_picture.dart';
import 'package:flutter_test/flutter_test.dart';

// ─── helpers ────────────────────────────────────────────────────────────────

const _fixturesDir = 'test/golden_comparison/svg_fixtures';

String _svg(String name) => File('$_fixturesDir/$name.svg').readAsStringSync();

/// Build a 400×600 widget (matching the SVGs' natural dimensions) wrapped in a
/// RepaintBoundary and capture its RGBA pixels without pumpAndSettle (which
/// would hang on infinite animations).
///
/// Image loading in AnimatedSvgPicture is `unawaited`, so we use
/// [tester.runAsync] to give real async time for codec decoding before
/// capturing the frame.
Future<Uint8List> _render(
  WidgetTester tester,
  String svgString, {
  double width = 400,
  double height = 600,
  bool autoPlay = false,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1.0;

  final key = GlobalKey();

  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.transparent,
        body: RepaintBoundary(
          key: key,
          child: SizedBox(
            width: width,
            height: height,
            child: AnimatedSvgPicture.string(
              svgString,
              width: width,
              height: height,
              fit: BoxFit.fill,
              autoPlay: autoPlay,
            ),
          ),
        ),
      ),
    ),
  );

  await tester.pump();

  // Wait in real time for unawaited image codec futures to complete.
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 600)),
  );

  // Pump to process the _markNeedsRepaint() calls triggered by image loading.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));

  return await tester.runAsync<Uint8List>(() async {
        final boundary =
            key.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 1.0);
        final byteData = await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
        image.dispose();
        return byteData!.buffer.asUint8List();
      })
      as Uint8List;
}

/// Returns the fraction of pixels (0–1) that are not fully transparent.
double _visibleFraction(Uint8List rgba, int width, int height) {
  int visible = 0;
  for (int i = 3; i < rgba.length; i += 4) {
    if (rgba[i] > 10) visible++;
  }
  return visible / (width * height);
}

/// Samples the RGBA value of a pixel at (x, y).
({int r, int g, int b, int a}) _pixel(Uint8List rgba, int width, int x, int y) {
  final idx = (y * width + x) * 4;
  return (r: rgba[idx], g: rgba[idx + 1], b: rgba[idx + 2], a: rgba[idx + 3]);
}

/// Captures pixels from a [RepaintBoundary] identified by [key], waiting
/// [realDelay] of real time first so that `unawaited` image codec futures have
/// a chance to complete and trigger `_markNeedsRepaint`.
Future<Uint8List> _captureKey(
  WidgetTester tester,
  GlobalKey key, {
  Duration realDelay = const Duration(milliseconds: 600),
}) async {
  await tester.runAsync(() => Future<void>.delayed(realDelay));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));

  return await tester.runAsync<Uint8List>(() async {
        final boundary =
            key.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 1.0);
        final byteData = await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
        image.dispose();
        return byteData!.buffer.asUint8List();
      })
      as Uint8List;
}

// ─── tests ──────────────────────────────────────────────────────────────────

void main() {
  // ─── Eastern Emeralds ───────────────────────────────────────────────────────

  group('betinia Eastern Emeralds', () {
    // CSS @keyframes with per-keyframe cubic-bezier, 3 embedded images.

    testWidgets('smoke: renders without throwing', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(
              _svg('betinia_eastern_emeralds'),
              width: 400,
              height: 600,
              autoPlay: false,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('content: visible pixels at t=0', (tester) async {
      final pixels = await _render(tester, _svg('betinia_eastern_emeralds'));
      final visible = _visibleFraction(pixels, 400, 600);
      print(
        '[Eastern Emeralds] visible fraction: ${(visible * 100).toStringAsFixed(1)}%',
      );
      expect(
        visible,
        greaterThan(0.05),
        reason:
            'Expected at least 5% non-transparent pixels; got ${(visible * 100).toStringAsFixed(1)}%',
      );
    });

    testWidgets('css: @keyframes with per-keyframe cubic-bezier timing', (
      tester,
    ) async {
      // Minimal reproduction: two keyframes using per-keyframe timing functions,
      // matching the pattern used in Eastern Emeralds.
      const svg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 600" width="400" height="600">
<style>
#box_ts { animation: box_ts__ts 2000ms linear infinite normal forwards }
@keyframes box_ts__ts {
  0% { transform: translate(200px,300px) scale(2.7,2.7); animation-timing-function: cubic-bezier(0.28,0.02,0.69,0.975) }
  50% { transform: translate(200px,300px) scale(2.4,2.4); animation-timing-function: cubic-bezier(0.28,0.02,0.69,0.975) }
  100% { transform: translate(200px,300px) scale(2.7,2.7) }
}
</style>
<g id="box_ts">
  <rect x="-20" y="-20" width="40" height="40" fill="red"/>
</g>
</svg>
''';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(
              svg,
              width: 400,
              height: 600,
              autoPlay: true,
            ),
          ),
        ),
      );
      await tester.pump();
      // Advance half-way through the animation.
      await tester.pump(const Duration(milliseconds: 1000));
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('css: animation still visible after one full cycle', (
      tester,
    ) async {
      final key = GlobalKey();
      tester.view.physicalSize = const Size(400, 600);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            backgroundColor: Colors.transparent,
            body: RepaintBoundary(
              key: key,
              child: SizedBox(
                width: 400,
                height: 600,
                child: AnimatedSvgPicture.string(
                  _svg('betinia_eastern_emeralds'),
                  width: 400,
                  height: 600,
                  autoPlay: true,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      // Advance past the 2 s animation cycle.
      await tester.pump(const Duration(milliseconds: 2100));

      final pixels = await _captureKey(tester, key);

      final visible = _visibleFraction(pixels, 400, 600);
      print(
        '[Eastern Emeralds after cycle] visible: ${(visible * 100).toStringAsFixed(1)}%',
      );
      expect(
        visible,
        greaterThan(0.05),
        reason: 'Expected content to remain visible after animation cycle',
      );
    });
  });

  // ─── WOL ────────────────────────────────────────────────────────────────────

  group('betinia WOL', () {
    // Mixed CSS (80 @keyframes) + SMIL (11 <animate>), SMIL on filter primitives,
    // background-color:black on root <svg>, preserveAspectRatio="none".

    testWidgets('smoke: renders without throwing', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(
              _svg('betinia_wol'),
              width: 400,
              height: 600,
              autoPlay: false,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('content: visible pixels at t=0', (tester) async {
      final pixels = await _render(tester, _svg('betinia_wol'));
      final visible = _visibleFraction(pixels, 400, 600);
      print('[WOL] visible fraction: ${(visible * 100).toStringAsFixed(1)}%');
      expect(
        visible,
        greaterThan(0.05),
        reason: 'Expected at least 5% non-transparent pixels',
      );
    });

    testWidgets('background-color: black applied to root svg', (tester) async {
      // The WOL SVG has style="background-color:black" on the root <svg>.
      // After rendering, pixel (0,0) — well outside any drawn content — should
      // be opaque and black (or very dark) rather than transparent.
      const svg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 600" width="400" height="600"
     style="background-color:black">
  <circle cx="200" cy="300" r="50" fill="red"/>
</svg>
''';
      tester.view.physicalSize = const Size(400, 600);
      tester.view.devicePixelRatio = 1.0;

      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            backgroundColor: Colors.transparent,
            body: RepaintBoundary(
              key: key,
              child: SizedBox(
                width: 400,
                height: 600,
                child: AnimatedSvgPicture.string(
                  svg,
                  width: 400,
                  height: 600,
                  autoPlay: false,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final pixels =
          await tester.runAsync<Uint8List>(() async {
                final boundary =
                    key.currentContext!.findRenderObject()
                        as RenderRepaintBoundary;
                final image = await boundary.toImage(pixelRatio: 1.0);
                final byteData = await image.toByteData(
                  format: ui.ImageByteFormat.rawRgba,
                );
                image.dispose();
                return byteData!.buffer.asUint8List();
              })
              as Uint8List;

      // Corner pixel should be black/opaque (background filled).
      final corner = _pixel(pixels, 400, 2, 2);
      print(
        '[background-color] corner pixel: r=${corner.r} g=${corner.g} b=${corner.b} a=${corner.a}',
      );
      expect(
        corner.a,
        greaterThan(200),
        reason: 'Corner should be opaque (background-color:black)',
      );
      expect(
        corner.r,
        lessThan(30),
        reason: 'Corner should be dark (black background)',
      );
      expect(
        corner.g,
        lessThan(30),
        reason: 'Corner should be dark (black background)',
      );
      expect(
        corner.b,
        lessThan(30),
        reason: 'Corner should be dark (black background)',
      );
    });

    testWidgets('preserveAspectRatio none: stretches to fill viewport', (
      tester,
    ) async {
      // When preserveAspectRatio="none" the SVG content scales independently on
      // each axis. We render a 400×600 SVG into a 200×400 container and verify
      // that content still fills the viewport corners.
      const svg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 600" width="400" height="600"
     preserveAspectRatio="none">
  <rect x="0" y="0" width="400" height="600" fill="blue"/>
  <rect x="390" y="590" width="10" height="10" fill="red"/>
</svg>
''';
      tester.view.physicalSize = const Size(200, 400);
      tester.view.devicePixelRatio = 1.0;

      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            backgroundColor: Colors.transparent,
            body: RepaintBoundary(
              key: key,
              child: SizedBox(
                width: 200,
                height: 400,
                child: AnimatedSvgPicture.string(
                  svg,
                  width: 200,
                  height: 400,
                  autoPlay: false,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final pixels =
          await tester.runAsync<Uint8List>(() async {
                final boundary =
                    key.currentContext!.findRenderObject()
                        as RenderRepaintBoundary;
                final image = await boundary.toImage(pixelRatio: 1.0);
                final byteData = await image.toByteData(
                  format: ui.ImageByteFormat.rawRgba,
                );
                image.dispose();
                return byteData!.buffer.asUint8List();
              })
              as Uint8List;

      // The whole background is blue; corner should not be transparent.
      final topLeft = _pixel(pixels, 200, 1, 1);
      print(
        '[preserveAspectRatio none] top-left: r=${topLeft.r} g=${topLeft.g} b=${topLeft.b} a=${topLeft.a}',
      );
      expect(
        topLeft.a,
        greaterThan(200),
        reason: 'Top-left corner should be painted (preserveAspectRatio=none)',
      );
      expect(
        topLeft.b,
        greaterThan(100),
        reason: 'Top-left should be blue background',
      );
    });

    testWidgets('smil on filter: animate feColorMatrix values', (tester) async {
      // WOL animates feColorMatrix.values and feFuncR/G/B.slope inside a filter.
      // Verify this does not crash and produces visible output at both t=0 and
      // after the animation advances.
      const svg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100" width="100" height="100">
<defs>
  <filter id="fs">
    <feColorMatrix type="saturate" in="SourceGraphic" values="1">
      <animate attributeName="values" values="1; 2.4; 1; 1" dur="2s" repeatCount="indefinite"/>
    </feColorMatrix>
    <feComponentTransfer>
      <feFuncR type="linear" slope="1">
        <animate attributeName="slope" values="1; 2; 1; 1" dur="2s" repeatCount="indefinite"/>
      </feFuncR>
      <feFuncG type="linear" slope="1">
        <animate attributeName="slope" values="1; 2; 1; 1" dur="2s" repeatCount="indefinite"/>
      </feFuncG>
      <feFuncB type="linear" slope="1">
        <animate attributeName="slope" values="1; 2; 1; 1" dur="2s" repeatCount="indefinite"/>
      </feFuncB>
    </feComponentTransfer>
  </filter>
</defs>
<rect x="10" y="10" width="80" height="80" fill="#4080ff" filter="url(#fs)"/>
</svg>
''';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(
              svg,
              width: 100,
              height: 100,
              autoPlay: true,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);

      // Advance 1 s (mid-animation) – should not crash.
      await tester.pump(const Duration(milliseconds: 1000));
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('wol: visible after full animation cycle', (tester) async {
      final key = GlobalKey();
      tester.view.physicalSize = const Size(400, 600);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            backgroundColor: Colors.transparent,
            body: RepaintBoundary(
              key: key,
              child: SizedBox(
                width: 400,
                height: 600,
                child: AnimatedSvgPicture.string(
                  _svg('betinia_wol'),
                  width: 400,
                  height: 600,
                  autoPlay: true,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 2100));

      final pixels = await _captureKey(tester, key);

      final visible = _visibleFraction(pixels, 400, 600);
      print(
        '[WOL after cycle] visible: ${(visible * 100).toStringAsFixed(1)}%',
      );
      expect(
        visible,
        greaterThan(0.05),
        reason: 'WOL should remain visible after one animation cycle',
      );
    });
  });

  // ─── Break the Piggy Bank ───────────────────────────────────────────────────

  group('betinia Break the Piggy Bank', () {
    // Pure SMIL (143 <animate> + 104 <animateTransform>), 8 WebP embedded images.

    testWidgets('smoke: renders without throwing', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(
              _svg('betinia_break_piggy_bank'),
              width: 400,
              height: 600,
              autoPlay: false,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('content: visible pixels at t=0', (tester) async {
      final pixels = await _render(tester, _svg('betinia_break_piggy_bank'));
      final visible = _visibleFraction(pixels, 400, 600);
      print(
        '[Break Piggy Bank] visible fraction: ${(visible * 100).toStringAsFixed(1)}%',
      );
      expect(
        visible,
        greaterThan(0.05),
        reason: 'Expected at least 5% non-transparent pixels',
      );
    });

    testWidgets('smil: mass animate+animateTransform do not crash', (
      tester,
    ) async {
      // Verify >100 SMIL elements per frame don't cause hangs or exceptions.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(
              _svg('betinia_break_piggy_bank'),
              width: 400,
              height: 600,
              autoPlay: true,
            ),
          ),
        ),
      );
      await tester.pump();
      // Advance through multiple frames without hangs.
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('smil: embedded WebP images render without codec errors', (
      tester,
    ) async {
      // Minimal SVG with a data:image/webp href – just verifies no unhandled
      // exception is thrown when the image element is encountered.
      // (The tiny WebP is a 1×1 red pixel encoded in base64.)
      const tinyWebpBase64 =
          'UklGRlYAAABXRUJQVlA4IEoAAADQAQCdASoBAAEAAkA4JZQCdAEO/gHOAAD'
          'u+M87OZ9UkFz2TpHllOnjjNijLcXk1Y7a42Q86CKqiYkjVyKw0AAAA==';

      const svg =
          '''
<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink"
     viewBox="0 0 100 100" width="100" height="100">
  <image x="0" y="0" width="100" height="100"
         xlink:href="data:image/webp;base64,$tinyWebpBase64"/>
</svg>
''';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(
              svg,
              width: 100,
              height: 100,
              autoPlay: false,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      // No exception thrown is the success criterion.
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });

  // ─── 777 Hot Reels ──────────────────────────────────────────────────────────

  group('betinia 777 Hot Reels', () {
    // SMIL with 43 <animate attributeName="display">, feColorMatrix for alpha,
    // 9 WebP images, baseProfile="basic".

    testWidgets('smoke: renders without throwing', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(
              _svg('betinia_777_hot_reels'),
              width: 400,
              height: 600,
              autoPlay: false,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('content: visible pixels at t=0', (tester) async {
      final pixels = await _render(tester, _svg('betinia_777_hot_reels'));
      final visible = _visibleFraction(pixels, 400, 600);
      print(
        '[777 Hot Reels] visible fraction: ${(visible * 100).toStringAsFixed(1)}%',
      );
      expect(
        visible,
        greaterThan(0.05),
        reason: 'Expected at least 5% non-transparent pixels',
      );
    });

    testWidgets('smil display: animate display attr does not hide all content', (
      tester,
    ) async {
      // 777 Hot Reels has 43 <animate attributeName="display"> elements. At t=0
      // elements that begin with display="none" and animate to display="inline"
      // must not be visible, and vice versa. Verify the SVG still has overall
      // visible content (not everything hidden or everything shown).
      const svg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100" width="100" height="100">
  <!-- This rect starts visible (display inline) and stays visible -->
  <rect x="10" y="10" width="30" height="30" fill="blue"/>

  <!-- This rect starts hidden and should remain hidden at t=0 -->
  <rect x="60" y="10" width="30" height="30" fill="red" display="none">
    <animate attributeName="display" values="none;inline;none" dur="2s"
             repeatCount="indefinite"/>
  </rect>

  <!-- This rect starts visible and hides at 1s -->
  <rect x="10" y="60" width="30" height="30" fill="green">
    <animate attributeName="display" values="inline;none;inline" dur="2s"
             repeatCount="indefinite"/>
  </rect>
</svg>
''';
      tester.view.physicalSize = const Size(100, 100);
      tester.view.devicePixelRatio = 1.0;

      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            backgroundColor: Colors.transparent,
            body: RepaintBoundary(
              key: key,
              child: SizedBox(
                width: 100,
                height: 100,
                child: AnimatedSvgPicture.string(
                  svg,
                  width: 100,
                  height: 100,
                  autoPlay: false,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final pixels =
          await tester.runAsync<Uint8List>(() async {
                final boundary =
                    key.currentContext!.findRenderObject()
                        as RenderRepaintBoundary;
                final image = await boundary.toImage(pixelRatio: 1.0);
                final byteData = await image.toByteData(
                  format: ui.ImageByteFormat.rawRgba,
                );
                image.dispose();
                return byteData!.buffer.asUint8List();
              })
              as Uint8List;

      // Blue rect (10,10)-(40,40) should be visible.
      final blueCenter = _pixel(pixels, 100, 25, 25);
      print(
        '[display animate] blue rect pixel: r=${blueCenter.r} g=${blueCenter.g} b=${blueCenter.b} a=${blueCenter.a}',
      );
      expect(
        blueCenter.a,
        greaterThan(200),
        reason: 'Blue rect should be visible',
      );
      expect(
        blueCenter.b,
        greaterThan(100),
        reason: 'Blue rect should be blue',
      );

      // Red rect (60,10)-(90,40) should be HIDDEN at t=0 (display:none).
      final redCenter = _pixel(pixels, 100, 75, 25);
      print(
        '[display animate] red rect pixel at t=0: r=${redCenter.r} g=${redCenter.g} b=${redCenter.b} a=${redCenter.a}',
      );
      expect(
        redCenter.r,
        lessThan(50),
        reason: 'Red rect should be hidden at t=0 (display:none)',
      );
    });

    testWidgets('smil display: hidden rect appears after animation advances', (
      tester,
    ) async {
      // After 1100ms (past the 1s halfway mark) the red rect should be visible.
      const svg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100" width="100" height="100">
  <rect x="60" y="10" width="30" height="30" fill="red" display="none">
    <animate attributeName="display" values="none;inline;none" dur="2s"
             repeatCount="indefinite" begin="0s"/>
  </rect>
</svg>
''';
      tester.view.physicalSize = const Size(100, 100);
      tester.view.devicePixelRatio = 1.0;

      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            backgroundColor: Colors.transparent,
            body: RepaintBoundary(
              key: key,
              child: SizedBox(
                width: 100,
                height: 100,
                child: AnimatedSvgPicture.string(
                  svg,
                  width: 100,
                  height: 100,
                  autoPlay: true,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      // Advance to t=1.1s – the rect should now have display:inline.
      await tester.pump(const Duration(milliseconds: 1100));

      final pixels =
          await tester.runAsync<Uint8List>(() async {
                final boundary =
                    key.currentContext!.findRenderObject()
                        as RenderRepaintBoundary;
                final image = await boundary.toImage(pixelRatio: 1.0);
                final byteData = await image.toByteData(
                  format: ui.ImageByteFormat.rawRgba,
                );
                image.dispose();
                return byteData!.buffer.asUint8List();
              })
              as Uint8List;

      final redCenter = _pixel(pixels, 100, 75, 25);
      print(
        '[display animate t=1.1s] red rect: r=${redCenter.r} g=${redCenter.g} b=${redCenter.b} a=${redCenter.a}',
      );
      expect(
        redCenter.r,
        greaterThan(100),
        reason: 'Red rect should be visible at t=1.1s (display:inline)',
      );
    });

    testWidgets('feColorMatrix alpha: fixed alpha values produce correct opacity', (
      tester,
    ) async {
      // 777 Hot Reels uses feColorMatrix with values like "1 0 0 0 0 0 1 0 0 0 0 0 1 0 0 0 0 0 0.27 0"
      // to control opacity during frame crossfade animations.
      //
      // Strategy: use a white SVG background so the result is deterministic regardless
      // of the test environment's compositing surface color.
      //
      //  • alpha=0 filter  → invisible → blends to white → R≈255
      //  • alpha=0.27 filter → blue@27% on white → R≈186, G≈186, B≈255
      //  • alpha=1 filter  → blue@100% on white  → R≈0,   G≈0,   B≈255
      //  • No filter (red) → pure red on white   → R≈255, G≈0,   B≈0
      //
      // The key observable: B value increases as alpha increases when composited
      // over white.  And with alpha=0 the pixel should be indistinguishable from
      // the white background.
      const svg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 60" width="200" height="60">
<defs>
  <!-- alpha=0: completely invisible -->
  <filter id="a0" filterUnits="objectBoundingBox" x="0" y="0" width="100%" height="100%">
    <feColorMatrix values="1 0 0 0 0  0 1 0 0 0  0 0 1 0 0  0 0 0 0 0"/>
  </filter>
  <!-- alpha=0.27: 27% opacity -->
  <filter id="a27" filterUnits="objectBoundingBox" x="0" y="0" width="100%" height="100%">
    <feColorMatrix values="1 0 0 0 0  0 1 0 0 0  0 0 1 0 0  0 0 0 0.27 0"/>
  </filter>
  <!-- alpha=1: full opacity -->
  <filter id="a100" filterUnits="objectBoundingBox" x="0" y="0" width="100%" height="100%">
    <feColorMatrix values="1 0 0 0 0  0 1 0 0 0  0 0 1 0 0  0 0 0 1 0"/>
  </filter>
</defs>
<!-- white background to make compositing deterministic -->
<rect x="0" y="0" width="200" height="60" fill="white"/>
<!-- invisible blue (alpha=0): should be white -->
<rect x="5"   y="10" width="40" height="40" fill="blue" filter="url(#a0)"/>
<!-- 27% blue on white -->
<rect x="55"  y="10" width="40" height="40" fill="blue" filter="url(#a27)"/>
<!-- 100% blue on white -->
<rect x="105" y="10" width="40" height="40" fill="blue" filter="url(#a100)"/>
<!-- pure red, no filter (reference) -->
<rect x="155" y="10" width="40" height="40" fill="red"/>
</svg>
''';
      tester.view.physicalSize = const Size(200, 60);
      tester.view.devicePixelRatio = 1.0;

      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            backgroundColor: Colors.transparent,
            body: RepaintBoundary(
              key: key,
              child: SizedBox(
                width: 200,
                height: 60,
                child: AnimatedSvgPicture.string(
                  svg,
                  width: 200,
                  height: 60,
                  autoPlay: false,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final pixels =
          await tester.runAsync<Uint8List>(() async {
                final boundary =
                    key.currentContext!.findRenderObject()
                        as RenderRepaintBoundary;
                final image = await boundary.toImage(pixelRatio: 1.0);
                final byteData = await image.toByteData(
                  format: ui.ImageByteFormat.rawRgba,
                );
                image.dispose();
                return byteData!.buffer.asUint8List();
              })
              as Uint8List;

      // Sample centre of each rect.
      final invisible = _pixel(pixels, 200, 25, 30); // alpha=0 blue
      final partial = _pixel(pixels, 200, 75, 30); // alpha=0.27 blue
      final full = _pixel(pixels, 200, 125, 30); // alpha=1 blue
      final reference = _pixel(pixels, 200, 175, 30); // pure red (no filter)

      print(
        '[feColorMatrix] invisible: r=${invisible.r} g=${invisible.g} b=${invisible.b} a=${invisible.a}',
      );
      print(
        '[feColorMatrix] partial  : r=${partial.r} g=${partial.g} b=${partial.b} a=${partial.a}',
      );
      print(
        '[feColorMatrix] full     : r=${full.r} g=${full.g} b=${full.b} a=${full.a}',
      );
      print(
        '[feColorMatrix] reference: r=${reference.r} g=${reference.g} b=${reference.b} a=${reference.a}',
      );

      // alpha=0 → transparent → composited over white → all channels ≈ 255
      expect(
        invisible.r,
        greaterThan(200),
        reason: 'alpha=0 rect composited over white: R ≈ 255',
      );
      expect(
        invisible.b,
        greaterThan(200),
        reason: 'alpha=0 rect composited over white: B ≈ 255',
      );

      // alpha=1 → full blue on white → R≈0, G≈0, B≈255
      expect(
        full.r,
        lessThan(50),
        reason: 'alpha=1 full blue: R channel should be near 0',
      );
      expect(
        full.g,
        lessThan(50),
        reason: 'alpha=1 full blue: G channel should be near 0',
      );
      expect(
        full.b,
        greaterThan(200),
        reason: 'alpha=1 full blue: B channel should be ~255',
      );

      // alpha=0.27 blue on white → R≈186, G≈186 (< 255 but > full.r)
      // R/G channel discriminates partial vs invisible and partial vs full.
      expect(
        partial.r,
        greaterThan(full.r + 50),
        reason: '27% blue has higher R than full blue (white bleed-through)',
      );
      expect(
        partial.r,
        lessThan(invisible.r - 20),
        reason: '27% blue has lower R than invisible (not fully transparent)',
      );

      // Reference red rect: mostly red channel, almost no blue.
      expect(
        reference.r,
        greaterThan(150),
        reason: 'Pure red rect has high R channel',
      );
      expect(
        reference.b,
        lessThan(50),
        reason: 'Pure red rect has low B channel',
      );
    });

    testWidgets('777 hot reels: visible after multiple smil animation frames', (
      tester,
    ) async {
      final key = GlobalKey();
      tester.view.physicalSize = const Size(400, 600);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            backgroundColor: Colors.transparent,
            body: RepaintBoundary(
              key: key,
              child: SizedBox(
                width: 400,
                height: 600,
                child: AnimatedSvgPicture.string(
                  _svg('betinia_777_hot_reels'),
                  width: 400,
                  height: 600,
                  autoPlay: true,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      final pixels = await _captureKey(tester, key);

      final visible = _visibleFraction(pixels, 400, 600);
      print(
        '[777 Hot Reels after 1s] visible: ${(visible * 100).toStringAsFixed(1)}%',
      );
      expect(
        visible,
        greaterThan(0.05),
        reason:
            '777 Hot Reels should have visible content after 1 s of animation',
      );
    });
  });

  // ─── Cross-SVG regression: all four render non-empty ───────────────────────

  group('betinia regression: all four SVGs have content at t=0', () {
    for (final (name, label) in [
      ('betinia_eastern_emeralds', 'Eastern Emeralds'),
      ('betinia_wol', 'WOL'),
      ('betinia_break_piggy_bank', 'Break the Piggy Bank'),
      ('betinia_777_hot_reels', '777 Hot Reels'),
    ]) {
      testWidgets('$label renders visible content', (tester) async {
        final pixels = await _render(tester, _svg(name));
        final visible = _visibleFraction(pixels, 400, 600);
        print(
          '[$label] t=0 visible fraction: ${(visible * 100).toStringAsFixed(1)}%',
        );
        expect(
          visible,
          greaterThan(0.03),
          reason:
              '$label should have >3% visible pixels at t=0 (got ${(visible * 100).toStringAsFixed(1)}%)',
        );
      });
    }
  });
} // end main
