import 'package:flutter/material.dart';
import 'package:flutter_svg/src/animation/animated_svg_picture.dart';
import 'package:flutter_svg/src/animation/preserve_aspect_ratio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:ui' as ui;

// Tiny 4x2 red PNG as base64 (wider than tall for aspect ratio testing)
const _wideRedPngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAQAAAACCAYAAAB/qH1jAAAAD0lEQVR42mP8z8DwHwYBAAV/AfnLdGqDAAAAAElFTkSuQmCC';

// Tiny 2x4 blue PNG as base64 (taller than wide for aspect ratio testing)
const _tallBluePngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAIAAAAECAYAAACk7+45AAAAEUlEQVR42mNgYPj/nwGKoQwAFE4D+UlHcIoAAAAASUVORK5CYII=';

void main() {
  group('PreserveAspectRatio Unit Tests', () {
    group('All alignment combinations with meet', () {
      test('xMinYMin meet - align to top-left', () {
        final layout = resolveSvgViewportLayout(
          viewport: ui.Rect.fromLTWH(0, 0, 100, 100),
          sourceSize: const ui.Size(200, 100), // wider source
          preserveAspectRatio: 'xMinYMin meet',
        );

        // Scale to fit: source 200x100 into 100x100 viewport
        // Scale = min(100/200, 100/100) = 0.5
        // Dest size: 100x50
        // Position: top-left (0, 0)
        expect(layout.destinationRect.left, 0.0);
        expect(layout.destinationRect.top, 0.0);
        expect(layout.destinationRect.width, 100.0);
        expect(layout.destinationRect.height, 50.0);
        expect(layout.clipToViewport, false);
      });

      test('xMidYMin meet - align to top-center', () {
        final layout = resolveSvgViewportLayout(
          viewport: ui.Rect.fromLTWH(0, 0, 100, 100),
          sourceSize: const ui.Size(200, 100),
          preserveAspectRatio: 'xMidYMin meet',
        );

        expect(layout.destinationRect.left, 0.0);
        expect(layout.destinationRect.top, 0.0);
        expect(layout.destinationRect.width, 100.0);
        expect(layout.destinationRect.height, 50.0);
        expect(layout.clipToViewport, false);
      });

      test('xMaxYMin meet - align to top-right', () {
        final layout = resolveSvgViewportLayout(
          viewport: ui.Rect.fromLTWH(0, 0, 100, 100),
          sourceSize: const ui.Size(200, 100),
          preserveAspectRatio: 'xMaxYMin meet',
        );

        expect(layout.destinationRect.left, 0.0);
        expect(layout.destinationRect.top, 0.0);
        expect(layout.destinationRect.width, 100.0);
        expect(layout.destinationRect.height, 50.0);
        expect(layout.clipToViewport, false);
      });

      test('xMinYMid meet - align to middle-left', () {
        final layout = resolveSvgViewportLayout(
          viewport: ui.Rect.fromLTWH(0, 0, 100, 100),
          sourceSize: const ui.Size(200, 100),
          preserveAspectRatio: 'xMinYMid meet',
        );

        expect(layout.destinationRect.left, 0.0);
        expect(layout.destinationRect.top, 25.0); // Centered vertically
        expect(layout.destinationRect.width, 100.0);
        expect(layout.destinationRect.height, 50.0);
        expect(layout.clipToViewport, false);
      });

      test('xMidYMid meet (default) - align to center', () {
        final layout = resolveSvgViewportLayout(
          viewport: ui.Rect.fromLTWH(0, 0, 100, 100),
          sourceSize: const ui.Size(200, 100),
          preserveAspectRatio: 'xMidYMid meet',
        );

        expect(layout.destinationRect.left, 0.0);
        expect(layout.destinationRect.top, 25.0);
        expect(layout.destinationRect.width, 100.0);
        expect(layout.destinationRect.height, 50.0);
        expect(layout.clipToViewport, false);
      });

      test('xMaxYMid meet - align to middle-right', () {
        final layout = resolveSvgViewportLayout(
          viewport: ui.Rect.fromLTWH(0, 0, 100, 100),
          sourceSize: const ui.Size(200, 100),
          preserveAspectRatio: 'xMaxYMid meet',
        );

        expect(layout.destinationRect.left, 0.0);
        expect(layout.destinationRect.top, 25.0);
        expect(layout.destinationRect.width, 100.0);
        expect(layout.destinationRect.height, 50.0);
        expect(layout.clipToViewport, false);
      });

      test('xMinYMax meet - align to bottom-left', () {
        final layout = resolveSvgViewportLayout(
          viewport: ui.Rect.fromLTWH(0, 0, 100, 100),
          sourceSize: const ui.Size(200, 100),
          preserveAspectRatio: 'xMinYMax meet',
        );

        expect(layout.destinationRect.left, 0.0);
        expect(layout.destinationRect.top, 50.0); // Bottom
        expect(layout.destinationRect.width, 100.0);
        expect(layout.destinationRect.height, 50.0);
        expect(layout.clipToViewport, false);
      });

      test('xMidYMax meet - align to bottom-center', () {
        final layout = resolveSvgViewportLayout(
          viewport: ui.Rect.fromLTWH(0, 0, 100, 100),
          sourceSize: const ui.Size(200, 100),
          preserveAspectRatio: 'xMidYMax meet',
        );

        expect(layout.destinationRect.left, 0.0);
        expect(layout.destinationRect.top, 50.0);
        expect(layout.destinationRect.width, 100.0);
        expect(layout.destinationRect.height, 50.0);
        expect(layout.clipToViewport, false);
      });

      test('xMaxYMax meet - align to bottom-right', () {
        final layout = resolveSvgViewportLayout(
          viewport: ui.Rect.fromLTWH(0, 0, 100, 100),
          sourceSize: const ui.Size(200, 100),
          preserveAspectRatio: 'xMaxYMax meet',
        );

        expect(layout.destinationRect.left, 0.0);
        expect(layout.destinationRect.top, 50.0);
        expect(layout.destinationRect.width, 100.0);
        expect(layout.destinationRect.height, 50.0);
        expect(layout.clipToViewport, false);
      });
    });

    group('All alignment combinations with slice', () {
      test('xMinYMin slice - align to top-left, clips', () {
        final layout = resolveSvgViewportLayout(
          viewport: ui.Rect.fromLTWH(0, 0, 100, 100),
          sourceSize: const ui.Size(200, 100), // wider source
          preserveAspectRatio: 'xMinYMin slice',
        );

        // Scale to fill: max(100/200, 100/100) = 1.0
        // Dest size: 200x100, positioned at top-left
        expect(layout.destinationRect.left, 0.0);
        expect(layout.destinationRect.top, 0.0);
        expect(layout.destinationRect.width, 200.0);
        expect(layout.destinationRect.height, 100.0);
        expect(layout.clipToViewport, true);
      });

      test('xMidYMid slice - align to center, clips', () {
        final layout = resolveSvgViewportLayout(
          viewport: ui.Rect.fromLTWH(0, 0, 100, 100),
          sourceSize: const ui.Size(200, 100),
          preserveAspectRatio: 'xMidYMid slice',
        );

        // Centered: x = (100 - 200) / 2 = -50
        expect(layout.destinationRect.left, -50.0);
        expect(layout.destinationRect.top, 0.0);
        expect(layout.destinationRect.width, 200.0);
        expect(layout.destinationRect.height, 100.0);
        expect(layout.clipToViewport, true);
      });

      test('xMaxYMax slice - align to bottom-right, clips', () {
        final layout = resolveSvgViewportLayout(
          viewport: ui.Rect.fromLTWH(0, 0, 100, 100),
          sourceSize: const ui.Size(200, 100),
          preserveAspectRatio: 'xMaxYMax slice',
        );

        // Right: x = 100 - 200 = -100
        expect(layout.destinationRect.left, -100.0);
        expect(layout.destinationRect.top, 0.0);
        expect(layout.destinationRect.width, 200.0);
        expect(layout.destinationRect.height, 100.0);
        expect(layout.clipToViewport, true);
      });
    });

    group('Special cases', () {
      test('none - stretches to fill without preserving aspect ratio', () {
        final layout = resolveSvgViewportLayout(
          viewport: ui.Rect.fromLTWH(0, 0, 100, 100),
          sourceSize: const ui.Size(200, 100),
          preserveAspectRatio: 'none',
        );

        // Just returns the viewport rect directly
        expect(layout.destinationRect.left, 0.0);
        expect(layout.destinationRect.top, 0.0);
        expect(layout.destinationRect.width, 100.0);
        expect(layout.destinationRect.height, 100.0);
        expect(layout.clipToViewport, false);
      });

      test('default (null) defaults to xMidYMid meet', () {
        final layout = resolveSvgViewportLayout(
          viewport: ui.Rect.fromLTWH(0, 0, 100, 100),
          sourceSize: const ui.Size(200, 100),
          preserveAspectRatio: null,
        );

        // Same as xMidYMid meet
        expect(layout.destinationRect.left, 0.0);
        expect(layout.destinationRect.top, 25.0);
        expect(layout.destinationRect.width, 100.0);
        expect(layout.destinationRect.height, 50.0);
        expect(layout.clipToViewport, false);
      });

      test('empty string defaults to xMidYMid meet', () {
        final layout = resolveSvgViewportLayout(
          viewport: ui.Rect.fromLTWH(0, 0, 100, 100),
          sourceSize: const ui.Size(200, 100),
          preserveAspectRatio: '',
        );

        expect(layout.destinationRect.top, 25.0);
        expect(layout.clipToViewport, false);
      });

      test('defer keyword is ignored', () {
        final layout = resolveSvgViewportLayout(
          viewport: ui.Rect.fromLTWH(0, 0, 100, 100),
          sourceSize: const ui.Size(200, 100),
          preserveAspectRatio: 'defer xMinYMin meet',
        );

        expect(layout.destinationRect.left, 0.0);
        expect(layout.destinationRect.top, 0.0);
        expect(layout.clipToViewport, false);
      });

      test('zero size source returns viewport as-is', () {
        final layout = resolveSvgViewportLayout(
          viewport: ui.Rect.fromLTWH(10, 20, 100, 100),
          sourceSize: const ui.Size(0, 0),
          preserveAspectRatio: 'xMidYMid meet',
        );

        expect(layout.destinationRect.left, 10.0);
        expect(layout.destinationRect.top, 20.0);
        expect(layout.destinationRect.width, 100.0);
        expect(layout.destinationRect.height, 100.0);
        expect(layout.clipToViewport, false);
      });

      test('viewport with offset', () {
        final layout = resolveSvgViewportLayout(
          viewport: ui.Rect.fromLTWH(50, 50, 100, 100),
          sourceSize: const ui.Size(200, 100),
          preserveAspectRatio: 'xMidYMid meet',
        );

        // Should be centered within the offset viewport
        expect(layout.destinationRect.left, 50.0);
        expect(layout.destinationRect.top, 75.0);
        expect(layout.destinationRect.width, 100.0);
        expect(layout.destinationRect.height, 50.0);
      });

      test('tall source in wide viewport', () {
        final layout = resolveSvgViewportLayout(
          viewport: ui.Rect.fromLTWH(0, 0, 100, 50),
          sourceSize: const ui.Size(50, 100), // tall source
          preserveAspectRatio: 'xMidYMid meet',
        );

        // Scale = min(100/50, 50/100) = 0.5
        // Dest size: 25x50
        // Centered: x = (100 - 25) / 2 = 37.5
        expect(layout.destinationRect.left, 37.5);
        expect(layout.destinationRect.top, 0.0);
        expect(layout.destinationRect.width, 25.0);
        expect(layout.destinationRect.height, 50.0);
      });
    });
  });

  group('PreserveAspectRatio Image Rendering Tests', () {
    group('All alignment values with meet', () {
      testWidgets('xMinYMin meet', (tester) async {
        final svg = '''<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <image x="0" y="0" width="100" height="100" 
                 preserveAspectRatio="xMinYMin meet"
                 href="data:image/png;base64,$_wideRedPngBase64"/>
        </svg>''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AnimatedSvgPicture.string(svg, width: 200, height: 200),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('xMidYMin meet', (tester) async {
        final svg = '''<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <image x="0" y="0" width="100" height="100" 
                 preserveAspectRatio="xMidYMin meet"
                 href="data:image/png;base64,$_wideRedPngBase64"/>
        </svg>''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AnimatedSvgPicture.string(svg, width: 200, height: 200),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('xMaxYMin meet', (tester) async {
        final svg = '''<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <image x="0" y="0" width="100" height="100" 
                 preserveAspectRatio="xMaxYMin meet"
                 href="data:image/png;base64,$_wideRedPngBase64"/>
        </svg>''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AnimatedSvgPicture.string(svg, width: 200, height: 200),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('xMinYMid meet', (tester) async {
        final svg = '''<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <image x="0" y="0" width="100" height="100" 
                 preserveAspectRatio="xMinYMid meet"
                 href="data:image/png;base64,$_wideRedPngBase64"/>
        </svg>''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AnimatedSvgPicture.string(svg, width: 200, height: 200),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('xMidYMid meet (default)', (tester) async {
        final svg = '''<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <image x="0" y="0" width="100" height="100" 
                 preserveAspectRatio="xMidYMid meet"
                 href="data:image/png;base64,$_wideRedPngBase64"/>
        </svg>''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AnimatedSvgPicture.string(svg, width: 200, height: 200),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('xMaxYMid meet', (tester) async {
        final svg = '''<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <image x="0" y="0" width="100" height="100" 
                 preserveAspectRatio="xMaxYMid meet"
                 href="data:image/png;base64,$_wideRedPngBase64"/>
        </svg>''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AnimatedSvgPicture.string(svg, width: 200, height: 200),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('xMinYMax meet', (tester) async {
        final svg = '''<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <image x="0" y="0" width="100" height="100" 
                 preserveAspectRatio="xMinYMax meet"
                 href="data:image/png;base64,$_wideRedPngBase64"/>
        </svg>''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AnimatedSvgPicture.string(svg, width: 200, height: 200),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('xMidYMax meet', (tester) async {
        final svg = '''<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <image x="0" y="0" width="100" height="100" 
                 preserveAspectRatio="xMidYMax meet"
                 href="data:image/png;base64,$_wideRedPngBase64"/>
        </svg>''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AnimatedSvgPicture.string(svg, width: 200, height: 200),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('xMaxYMax meet', (tester) async {
        final svg = '''<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <image x="0" y="0" width="100" height="100" 
                 preserveAspectRatio="xMaxYMax meet"
                 href="data:image/png;base64,$_wideRedPngBase64"/>
        </svg>''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AnimatedSvgPicture.string(svg, width: 200, height: 200),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });
    });

    group('Slice mode variations', () {
      testWidgets('xMinYMin slice', (tester) async {
        final svg = '''<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <image x="0" y="0" width="100" height="100" 
                 preserveAspectRatio="xMinYMin slice"
                 href="data:image/png;base64,$_wideRedPngBase64"/>
        </svg>''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AnimatedSvgPicture.string(svg, width: 200, height: 200),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('xMidYMid slice', (tester) async {
        final svg = '''<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <image x="0" y="0" width="100" height="100" 
                 preserveAspectRatio="xMidYMid slice"
                 href="data:image/png;base64,$_wideRedPngBase64"/>
        </svg>''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AnimatedSvgPicture.string(svg, width: 200, height: 200),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('xMaxYMax slice', (tester) async {
        final svg = '''<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <image x="0" y="0" width="100" height="100" 
                 preserveAspectRatio="xMaxYMax slice"
                 href="data:image/png;base64,$_wideRedPngBase64"/>
        </svg>''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AnimatedSvgPicture.string(svg, width: 200, height: 200),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });
    });

    group('Special values', () {
      testWidgets('preserveAspectRatio="none" stretches image', (tester) async {
        final svg = '''<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <image x="0" y="0" width="100" height="100" 
                 preserveAspectRatio="none"
                 href="data:image/png;base64,$_wideRedPngBase64"/>
        </svg>''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AnimatedSvgPicture.string(svg, width: 200, height: 200),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('no preserveAspectRatio uses default', (tester) async {
        final svg = '''<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <image x="0" y="0" width="100" height="100" 
                 href="data:image/png;base64,$_wideRedPngBase64"/>
        </svg>''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AnimatedSvgPicture.string(svg, width: 200, height: 200),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('defer keyword is handled', (tester) async {
        final svg = '''<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <image x="0" y="0" width="100" height="100" 
                 preserveAspectRatio="defer xMidYMid meet"
                 href="data:image/png;base64,$_wideRedPngBase64"/>
        </svg>''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AnimatedSvgPicture.string(svg, width: 200, height: 200),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });
    });

    group('Tall image in different viewports', () {
      testWidgets('tall image with xMidYMid meet', (tester) async {
        final svg = '''<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <image x="0" y="0" width="100" height="100" 
                 preserveAspectRatio="xMidYMid meet"
                 href="data:image/png;base64,$_tallBluePngBase64"/>
        </svg>''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AnimatedSvgPicture.string(svg, width: 200, height: 200),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('tall image with xMinYMin slice', (tester) async {
        final svg = '''<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <image x="0" y="0" width="100" height="100" 
                 preserveAspectRatio="xMinYMin slice"
                 href="data:image/png;base64,$_tallBluePngBase64"/>
        </svg>''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AnimatedSvgPicture.string(svg, width: 200, height: 200),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });
    });
  });
}
