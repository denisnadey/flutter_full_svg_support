import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:full_svg_flutter/src/animation/animated_svg_picture.dart';
import 'package:flutter_test/flutter_test.dart';

({int r, int g, int b, int a}) _sampleRgba(
  Uint8List rgba,
  int width,
  int x,
  int y,
) {
  final offset = (y * width + x) * 4;
  return (
    r: rgba[offset],
    g: rgba[offset + 1],
    b: rgba[offset + 2],
    a: rgba[offset + 3],
  );
}

void main() {
  group('currentColor keyword', () {
    testWidgets('currentColor in fill uses inherited color property', (
      tester,
    ) async {
      const svg = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <g color="blue">
            <rect x="10" y="10" width="80" height="80" fill="currentColor"/>
          </g>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 100, height: 100),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('currentColor in stroke uses inherited color property', (
      tester,
    ) async {
      const svg = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <g color="#FF0000">
            <rect x="10" y="10" width="80" height="80" 
                  fill="none" stroke="currentColor" stroke-width="5"/>
          </g>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 100, height: 100),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('currentColor inherits through multiple levels', (
      tester,
    ) async {
      const svg = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <g color="green">
            <g>
              <g>
                <circle cx="50" cy="50" r="40" fill="currentColor"/>
              </g>
            </g>
          </g>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 100, height: 100),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('currentColor defaults to black when no color property', (
      tester,
    ) async {
      const svg = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <rect x="10" y="10" width="80" height="80" fill="currentColor"/>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 100, height: 100),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('currentColor case-insensitive', (tester) async {
      const svg = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <g color="red">
            <rect x="10" y="10" width="30" height="30" fill="CURRENTCOLOR"/>
            <rect x="50" y="10" width="30" height="30" fill="CurrentColor"/>
            <rect x="10" y="50" width="30" height="30" fill="currentcolor"/>
          </g>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 100, height: 100),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('currentColor on root element', (tester) async {
      const svg = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg" color="purple">
          <rect x="10" y="10" width="80" height="80" fill="currentColor"/>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 100, height: 100),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('currentColor via style attribute', (tester) async {
      const svg = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <g style="color: orange">
            <rect x="10" y="10" width="80" height="80" fill="currentColor"/>
          </g>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 100, height: 100),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('currentColor in both fill and stroke', (tester) async {
      const svg = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <g color="teal">
            <rect x="20" y="20" width="60" height="60" 
                  fill="currentColor" stroke="currentColor" 
                  stroke-width="5" fill-opacity="0.3"/>
          </g>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 100, height: 100),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('currentColor override at child level', (tester) async {
      const svg = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <g color="red">
            <rect x="10" y="10" width="35" height="35" fill="currentColor"/>
            <g color="blue">
              <rect x="55" y="10" width="35" height="35" fill="currentColor"/>
            </g>
          </g>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 100, height: 100),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('currentColor with text', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
          <g color="#3366CC">
            <text x="10" y="50" fill="currentColor" font-size="24">Hello</text>
          </g>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 200, height: 100),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('currentColor with path', (tester) async {
      const svg = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <g color="crimson">
            <path d="M10,50 Q50,10 90,50 Q50,90 10,50" fill="currentColor"/>
          </g>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 100, height: 100),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('currentColor with ellipse', (tester) async {
      const svg = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <g color="indigo">
            <ellipse cx="50" cy="50" rx="40" ry="25" fill="currentColor"/>
          </g>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 100, height: 100),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('currentColor with line stroke', (tester) async {
      const svg = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <g color="coral">
            <line x1="10" y1="10" x2="90" y2="90" 
                  stroke="currentColor" stroke-width="5"/>
          </g>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 100, height: 100),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('currentColor with polyline', (tester) async {
      const svg = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <g color="mediumseagreen">
            <polyline points="10,90 50,10 90,90" 
                      fill="none" stroke="currentColor" stroke-width="3"/>
          </g>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 100, height: 100),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('currentColor with polygon', (tester) async {
      const svg = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <g color="gold">
            <polygon points="50,10 90,90 10,90" fill="currentColor"/>
          </g>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 100, height: 100),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('currentColor works with inherit and gradient stop-color', (
      tester,
    ) async {
      const svg = '''
        <svg viewBox="0 0 100 60" xmlns="http://www.w3.org/2000/svg">
          <defs>
            <linearGradient id="g" color="green">
              <stop offset="0%" stop-color="#60F"/>
              <stop offset="50%" stop-color="currentColor"/>
              <stop offset="100%" stop-color="#FF6"/>
            </linearGradient>
          </defs>
          <g color="green">
            <g color="inherit" fill="none" stroke="none">
              <circle cx="20" cy="20" r="10" fill="currentColor"/>
              <circle cx="50" cy="20" r="10" stroke="currentColor" stroke-width="2"/>
            </g>
          </g>
          <rect x="10" y="40" width="80" height="10" fill="url(#g)"/>
        </svg>
      ''';

      final key = GlobalKey();
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: RepaintBoundary(
              key: key,
              child: AnimatedSvgPicture.string(
                svg,
                width: 200,
                height: 120,
                fit: BoxFit.fill,
                autoPlay: false,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final raw = await tester.runAsync<Uint8List?>(() async {
        final boundary =
            key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
        if (boundary == null) {
          return null;
        }
        final image = await boundary.toImage(pixelRatio: 1.0);
        final byteData = await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
        image.dispose();
        return byteData?.buffer.asUint8List();
      });

      expect(raw, isNotNull);
      final rgba = raw!;

      // Filled circle center should resolve currentColor -> green.
      final fillCenter = _sampleRgba(rgba, 200, 40, 40);
      expect(fillCenter.g, greaterThanOrEqualTo(120));
      expect(fillCenter.r, lessThan(80));
      expect(fillCenter.b, lessThan(80));

      // Stroked circle top edge should resolve currentColor -> green.
      final strokeTop = _sampleRgba(rgba, 200, 100, 20);
      expect(strokeTop.g, greaterThanOrEqualTo(110));
      expect(strokeTop.r, lessThan(100));

      // Gradient midpoint should use stop-color=currentColor -> green.
      final gradientMid = _sampleRgba(rgba, 200, 100, 90);
      expect(gradientMid.g, greaterThanOrEqualTo(110));
      expect(gradientMid.r, lessThan(100));
      expect(gradientMid.b, lessThan(100));
    });

    testWidgets(
      'inherited fill=currentColor resolves in property source context',
      (tester) async {
        const svg = '''
          <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
            <g fill="currentColor" color="lime">
              <rect x="20" y="20" width="60" height="60" color="red"/>
            </g>
          </svg>
        ''';

        final key = GlobalKey();
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Center(
              child: RepaintBoundary(
                key: key,
                child: AnimatedSvgPicture.string(
                  svg,
                  width: 200,
                  height: 200,
                  fit: BoxFit.fill,
                  autoPlay: false,
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        final raw = await tester.runAsync<Uint8List?>(() async {
          final boundary =
              key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
          if (boundary == null) {
            return null;
          }
          final image = await boundary.toImage(pixelRatio: 1.0);
          final byteData = await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          );
          image.dispose();
          return byteData?.buffer.asUint8List();
        });

        expect(raw, isNotNull);
        final rgba = raw!;

        // Rectangle center should be green from ancestor color="lime", not red.
        final center = _sampleRgba(rgba, 200, 100, 100);
        expect(center.g, greaterThanOrEqualTo(220));
        expect(center.r, lessThan(80));
        expect(center.b, lessThan(80));
      },
    );
  });
}
