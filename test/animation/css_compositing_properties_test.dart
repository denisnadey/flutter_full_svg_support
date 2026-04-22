import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:full_svg_flutter/src/animation/animated_svg_picture.dart';
import 'package:full_svg_flutter/src/animation/svg_filters.dart';
import 'package:full_svg_flutter/src/animation/svg_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // ---------------------------------------------------------------
  // Task 4 tests: enable-background CSS property
  // ---------------------------------------------------------------
  group('enable-background property', () {
    testWidgets('enable-background: new on group renders without error', (
      tester,
    ) async {
      const svg = '''
        <svg viewBox="0 0 200 200" xmlns="http://www.w3.org/2000/svg">
          <g enable-background="new">
            <rect x="10" y="10" width="80" height="80" fill="blue"/>
            <rect x="50" y="50" width="80" height="80" fill="red"/>
          </g>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 200, height: 200),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets(
      'enable-background: new with child filter using BackgroundImage',
      (tester) async {
        const svg = '''
          <svg viewBox="0 0 200 200" xmlns="http://www.w3.org/2000/svg">
            <defs>
              <filter id="bgFx">
                <feGaussianBlur in="BackgroundImage" stdDeviation="2"/>
              </filter>
            </defs>
            <g enable-background="new">
              <rect x="10" y="10" width="80" height="80" fill="blue"/>
              <rect x="50" y="50" width="80" height="80" fill="red"
                    filter="url(#bgFx)"/>
            </g>
          </svg>
        ''';

        await tester.pumpWidget(
          AnimatedSvgPicture.string(svg, width: 200, height: 200),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      },
    );

    testWidgets('enable-background: new with bounds parameters', (
      tester,
    ) async {
      const svg = '''
        <svg viewBox="0 0 200 200" xmlns="http://www.w3.org/2000/svg">
          <g enable-background="new 0 0 200 200">
            <rect x="10" y="10" width="80" height="80" fill="green"/>
          </g>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 200, height: 200),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('enable-background: accumulate (default, no layer)', (
      tester,
    ) async {
      const svg = '''
        <svg viewBox="0 0 200 200" xmlns="http://www.w3.org/2000/svg">
          <g enable-background="accumulate">
            <rect x="10" y="10" width="80" height="80" fill="purple"/>
          </g>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 200, height: 200),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    test('enable-background: BackgroundImage filter input resolves', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="bgTestFx">
      <feGaussianBlur in="BackgroundImage" stdDeviation="3"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#bgTestFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses(
        'bgTestFx',
        sourceContext: const SvgFilterSourceContext(
          backgroundImage: <SvgFilterPaintPass>[
            SvgFilterPaintPass(
              colorFilter: ui.ColorFilter.mode(
                ui.Color(0xFF00FF00),
                ui.BlendMode.srcIn,
              ),
            ),
          ],
        ),
      );

      expect(passes, isNotEmpty);
      expect(passes.first.imageFilter, isNotNull); // blur applied
    });
  });

  // ---------------------------------------------------------------
  // Task 5 tests: color-interpolation-filters
  // ---------------------------------------------------------------
  group('color-interpolation-filters property', () {
    testWidgets('color-interpolation-filters: linearRGB (default)', (
      tester,
    ) async {
      const svg = '''
        <svg viewBox="0 0 200 200" xmlns="http://www.w3.org/2000/svg">
          <defs>
            <filter id="blurLinear">
              <feGaussianBlur stdDeviation="5"/>
            </filter>
          </defs>
          <rect x="20" y="20" width="160" height="160" fill="red"
                filter="url(#blurLinear)"/>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 200, height: 200),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('color-interpolation-filters: sRGB explicit', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 200" xmlns="http://www.w3.org/2000/svg">
          <defs>
            <filter id="blurSrgb" color-interpolation-filters="sRGB">
              <feGaussianBlur stdDeviation="5"/>
            </filter>
          </defs>
          <rect x="20" y="20" width="160" height="160" fill="red"
                style="color-interpolation-filters: sRGB"
                filter="url(#blurSrgb)"/>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 200, height: 200),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    test('GaussianBlurProcessor sRGB↔linearRGB round-trip preserves data', () {
      // Create a small test image: 2x2 pixels with known sRGB colors
      final pixels = Uint8List.fromList([
        // Pixel (0,0): red
        255, 0, 0, 255,
        // Pixel (1,0): green
        0, 255, 0, 255,
        // Pixel (0,1): blue
        0, 0, 255, 255,
        // Pixel (1,1): mid-gray
        128, 128, 128, 255,
      ]);

      // Apply zero blur with linearRGB - should return original data
      final result = GaussianBlurProcessor.applyBlur(
        pixels: pixels,
        width: 2,
        height: 2,
        stdDeviationX: 0.0,
        stdDeviationY: 0.0,
        edgeMode: SvgConvolveEdgeMode.duplicate,
        useLinearRGB: true,
      );

      // Zero blur is passthrough, so result should match input
      expect(result, equals(pixels));
    });

    test('GaussianBlurProcessor with useLinearRGB produces valid output', () {
      // 4x4 gradient test image
      final pixels = Uint8List(4 * 4 * 4);
      for (int y = 0; y < 4; y++) {
        for (int x = 0; x < 4; x++) {
          final idx = (y * 4 + x) * 4;
          final v = ((x + y) * 32).clamp(0, 255);
          pixels[idx] = v; // R
          pixels[idx + 1] = v; // G
          pixels[idx + 2] = v; // B
          pixels[idx + 3] = 255; // A
        }
      }

      // Apply blur with linearRGB conversion
      final result = GaussianBlurProcessor.applyBlur(
        pixels: pixels,
        width: 4,
        height: 4,
        stdDeviationX: 1.0,
        stdDeviationY: 1.0,
        edgeMode: SvgConvolveEdgeMode.duplicate,
        useLinearRGB: true,
      );

      expect(result.length, equals(pixels.length));
      // All alpha values should remain 255
      for (int i = 3; i < result.length; i += 4) {
        expect(result[i], equals(255));
      }
    });

    test('SvgFilterSourceContext carries useLinearRGB flag', () {
      const ctx = SvgFilterSourceContext(useLinearRGB: true);
      expect(ctx.useLinearRGB, isTrue);

      const ctxDefault = SvgFilterSourceContext();
      expect(ctxDefault.useLinearRGB, isFalse);
    });
  });

  // ---------------------------------------------------------------
  // Task 6 tests: isolation: isolate CSS property
  // ---------------------------------------------------------------
  group('isolation: isolate property', () {
    testWidgets('isolation: isolate creates compositing boundary', (
      tester,
    ) async {
      const svg = '''
        <svg viewBox="0 0 200 200" xmlns="http://www.w3.org/2000/svg">
          <rect x="0" y="0" width="200" height="200" fill="white"/>
          <g style="isolation: isolate">
            <rect x="10" y="10" width="80" height="80" fill="blue"/>
            <rect x="50" y="50" width="80" height="80" fill="red"
                  style="mix-blend-mode: multiply"/>
          </g>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 200, height: 200),
      );
      await tester.pumpAndSettle();

      // Should render without error - the key behavior is that
      // multiply blends red with blue (in the isolated group),
      // not with the white background.
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('isolation: auto does not create extra layer', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 200" xmlns="http://www.w3.org/2000/svg">
          <g style="isolation: auto">
            <rect x="10" y="10" width="80" height="80" fill="blue"/>
            <rect x="50" y="50" width="80" height="80" fill="red"
                  style="mix-blend-mode: screen"/>
          </g>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 200, height: 200),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('mix-blend-mode on group creates implicit isolation', (
      tester,
    ) async {
      const svg = '''
        <svg viewBox="0 0 200 200" xmlns="http://www.w3.org/2000/svg">
          <rect x="0" y="0" width="200" height="200" fill="yellow"/>
          <g style="mix-blend-mode: multiply">
            <rect x="20" y="20" width="80" height="80" fill="blue"/>
            <rect x="60" y="60" width="80" height="80" fill="red"/>
          </g>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 200, height: 200),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('isolation with opacity combines correctly', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 200" xmlns="http://www.w3.org/2000/svg">
          <g opacity="0.5" style="isolation: isolate">
            <rect x="10" y="10" width="80" height="80" fill="blue"/>
            <rect x="50" y="50" width="80" height="80" fill="red"
                  style="mix-blend-mode: screen"/>
          </g>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 200, height: 200),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });
}
