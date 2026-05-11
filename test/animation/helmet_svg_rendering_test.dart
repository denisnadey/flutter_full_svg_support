import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:full_svg_flutter/src/animation/animated_svg_picture.dart';
import 'package:full_svg_flutter/src/animation/preserve_aspect_ratio.dart';

void main() {
  late String helmetSvg;

  setUpAll(() {
    helmetSvg = File('example/assets/helmet.svg').readAsStringSync();
  });

  // ── Basic rendering ─────────────────────────────────────────────────────────

  group('helmet.svg basic rendering', () {
    testWidgets('renders without error (clipToViewBox=false default)',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(
              helmetSvg,
              width: 400,
              height: 600,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('renders without error (clipToViewBox=true)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(
              helmetSvg,
              width: 400,
              height: 600,
              clipToViewBox: true,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });

  // ── clipToViewBox pixel-level clipping ──────────────────────────────────────

  group('clipToViewBox overflow clipping', () {
    // Use a minimal SVG that has the same overflow pattern as helmet.svg:
    // elements translated below the viewBox bottom edge (y > viewBox height).
    // helmet.svg has coins animated to translate(203px, 615px) while viewBox
    // height is 600 — those coins should be invisible with clipToViewBox=true.
    //
    // preserveAspectRatio="xMinYMin meet" + widget 200px tall:
    //   scale = min(100/100, 200/100) = 1.0, no translate → SVG occupies
    //   widget y=0..100 exactly; widget y=100..199 is below the viewBox.
    const overflowSvg = '''
<svg viewBox="0 0 100 100" preserveAspectRatio="xMinYMin meet"
     xmlns="http://www.w3.org/2000/svg">
  <rect x="10" y="10" width="80" height="80" fill="red"/>
  <rect x="10" y="110" width="80" height="20" fill="blue"/>
</svg>''';
    // The blue rect is at y=110..130 which is entirely outside the 0-100 viewBox.

    bool hasContentInRows(
      List<int> bytes,
      int width,
      int height,
      int yStart,
      int yEnd,
    ) {
      for (int y = yStart; y < yEnd && y < height; y++) {
        for (int x = 0; x < width; x++) {
          final base = (y * width + x) * 4;
          if (bytes[base + 3] > 5) return true;
        }
      }
      return false;
    }

    Future<({List<int> bytes, int width, int height})> renderAndCapture(
      WidgetTester tester,
      String svg, {
      required bool clip,
      double widgetH = 200,
    }) async {
      tester.view.physicalSize = Size(100, widgetH);
      tester.view.devicePixelRatio = 1.0;
      final key = GlobalKey();

      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: AnimatedSvgPicture.string(
            svg,
            width: 100,
            height: widgetH,
            clipToViewBox: clip,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final result = await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 1.0);
        final byteData =
            await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        final w = image.width;
        final h = image.height;
        image.dispose();
        return (
          bytes: byteData!.buffer.asUint8List().toList(),
          width: w,
          height: h,
        );
      });
      return result!;
    }

    testWidgets('clipToViewBox=true hides content below viewBox bottom',
        (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final r = await renderAndCapture(tester, overflowSvg, clip: true);
      // SVG viewBox is 0-100 with xMinYMin meet; widget is 200px tall.
      // scale=1, no translate → viewBox occupies widget y=0..100 exactly.
      // Rows 100..199 are below the viewBox boundary.
      // With clipToViewBox=true those rows must be empty.
      expect(
        hasContentInRows(r.bytes, r.width, r.height, 100, 200),
        isFalse,
        reason:
            'Content at y=110..130 should be clipped when clipToViewBox=true',
      );
    });

    testWidgets('clipToViewBox=false allows content below viewBox bottom',
        (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final r = await renderAndCapture(tester, overflowSvg, clip: false);
      // The blue rect is at SVG y=110..130 → widget y=110..130.
      // Rows 110..130 are below the viewBox but within the 200px widget.
      expect(
        hasContentInRows(r.bytes, r.width, r.height, 110, 130),
        isTrue,
        reason:
            'Content at y=110..130 should be visible when clipToViewBox=false',
      );
    });
  });

  // ── preserveAspectRatio="none" on root SVG ───────────────────────────────────

  group('root SVG preserveAspectRatio="none"', () {
    // helmet.svg root: viewBox="0 0 400 600" preserveAspectRatio="none".
    // When placed in a non-400×600 container the content must stretch
    // (not letterbox). Verify via resolveSvgViewportLayout unit test.

    test('none → destination fills the whole viewport regardless of aspect',
        () {
      // Simulate: viewBox 400x600 placed in a 200x600 widget (half width).
      final layout = resolveSvgViewportLayout(
        viewport: ui.Rect.fromLTWH(0, 0, 200, 600),
        sourceSize: const ui.Size(400, 600),
        preserveAspectRatio: 'none',
      );
      expect(layout.destinationRect, ui.Rect.fromLTWH(0, 0, 200, 600),
          reason: 'none must stretch to fill viewport without letterboxing');
      expect(layout.clipToViewport, isFalse);
    });

    test('none → fills tall viewport without letterboxing', () {
      final layout = resolveSvgViewportLayout(
        viewport: ui.Rect.fromLTWH(0, 0, 400, 800),
        sourceSize: const ui.Size(400, 600),
        preserveAspectRatio: 'none',
      );
      expect(layout.destinationRect, ui.Rect.fromLTWH(0, 0, 400, 800));
    });

    test('default (xMidYMid meet) → letterboxes in a wide viewport', () {
      // Contrast with default: viewBox 400x600 in 800x600 → letterboxed.
      final layout = resolveSvgViewportLayout(
        viewport: ui.Rect.fromLTWH(0, 0, 800, 600),
        sourceSize: const ui.Size(400, 600),
        preserveAspectRatio: 'xMidYMid meet',
      );
      // scale = min(800/400, 600/600) = min(2, 1) = 1 → dest 400x600 centred
      expect(layout.destinationRect.width, 400.0);
      expect(layout.destinationRect.height, 600.0);
      expect(layout.destinationRect.left, 200.0, reason: 'centred horizontally');
    });

    testWidgets('helmet.svg in non-native container does not throw',
        (tester) async {
      // Render in 200x900 — strongly non-native aspect ratio.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(
              helmetSvg,
              width: 200,
              height: 900,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });

  // ── Overflow behaviour specific to helmet.svg animations ───────────────────

  group('helmet.svg coin overflow (browser vs playground)', () {
    // The helmet SVG contains CSS-animated coins that translate to y≈615,
    // which is 15px below the 600px viewBox bottom.
    // Browser default: overflow:hidden → coins clipped.
    // Playground default (clipToViewBox=false) → coins visible outside SVG.

    // helmet.svg has preserveAspectRatio="none" so it stretches to fill any
    // container. To verify clipping we replace the preserveAspectRatio with
    // "xMinYMin meet" so the SVG occupies the top 600px of an 800px widget,
    // leaving rows 600..799 as the "overflow zone".
    testWidgets('clipToViewBox=true matches browser clipping behaviour',
        (tester) async {
      // Build a modified version of helmet.svg that uses xMinYMin meet
      // so the 400x600 viewBox occupies widget y=0..600 in a 400x800 widget.
      // background-color:black is intentionally kept — after the fix it is
      // drawn inside the clip and must not appear below y=600.
      final modifiedSvg = helmetSvg.replaceFirst(
        RegExp(r'preserveAspectRatio="[^"]*"'),
        'preserveAspectRatio="xMinYMin meet"',
      );

      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: AnimatedSvgPicture.string(
            modifiedSvg,
            width: 400,
            height: 800,
            clipToViewBox: true,
          ),
        ),
      );
      await tester.pump();
      // Advance animation so the coins near y=615 become visible if unclipped.
      await tester.pump(const Duration(milliseconds: 300));

      final result = await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 1.0);
        final byteData =
            await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        final w = image.width;
        final h = image.height;
        image.dispose();
        return (
          bytes: byteData!.buffer.asUint8List().toList(),
          width: w,
          height: h,
        );
      });
      expect(result, isNotNull);
      final bytes = result!.bytes;
      final imgW = result.width;
      final imgH = result.height;

      // With xMinYMin meet: viewBox 400x600 in widget 400x800 → scale=1,
      // SVG occupies widget y=0..600. Rows 600..799 must be empty with clip.
      var foundLeakedPixel = false;
      for (int y = 600; y < 800 && y < imgH; y++) {
        for (int x = 0; x < imgW; x++) {
          final base = (y * imgW + x) * 4;
          if (bytes[base + 3] > 10) {
            foundLeakedPixel = true;
          }
        }
      }
      expect(
        foundLeakedPixel,
        isFalse,
        reason:
            'With clipToViewBox=true no content should appear below the 600px viewBox boundary',
      );
    });
  });
}
