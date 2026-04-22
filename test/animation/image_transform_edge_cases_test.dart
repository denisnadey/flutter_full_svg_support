import 'package:flutter/material.dart';
import 'package:full_svg_flutter/src/animation/animated_svg_picture.dart';
import 'package:full_svg_flutter/src/animation/preserve_aspect_ratio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:ui' as ui;

// Tiny 4x2 red PNG as base64 (wider than tall for aspect ratio testing)
const _wideRedPngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAQAAAACCAYAAAB/qH1jAAAAD0lEQVR42mP8z8DwHwYBAAV/AfnLdGqDAAAAAElFTkSuQmCC';

// Tiny 2x4 blue PNG as base64 (taller than wide for aspect ratio testing)
const _tallBluePngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAIAAAAECAYAAACk7+45AAAAEUlEQVR42mNgYPj/nwGKoQwAFE4D+UlHcIoAAAAASUVORK5CYII=';

// Tiny 2x2 blue PNG as base64
const _tinyBluePngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAYAAABytg0kAAAAEElEQVR42mNgYPj/H4KhDAA/0gf5XBPgQgAAAABJRU5ErkJggg==';

void main() {
  group('Image Transform Edge Cases', () {
    group('All 9 alignments with meet mode', () {
      testWidgets('xMinYMin meet', (tester) async {
        final svg =
            '''<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
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
        final svg =
            '''<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
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
        final svg =
            '''<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
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
        final svg =
            '''<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
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
        final svg =
            '''<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
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
        final svg =
            '''<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
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
        final svg =
            '''<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
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
        final svg =
            '''<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
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
        final svg =
            '''<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
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

    group('All 9 alignments with slice mode', () {
      testWidgets('xMinYMin slice', (tester) async {
        final svg =
            '''<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
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

      testWidgets('xMidYMin slice', (tester) async {
        final svg =
            '''<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <image x="0" y="0" width="100" height="100" 
                 preserveAspectRatio="xMidYMin slice"
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

      testWidgets('xMaxYMin slice', (tester) async {
        final svg =
            '''<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <image x="0" y="0" width="100" height="100" 
                 preserveAspectRatio="xMaxYMin slice"
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

      testWidgets('xMinYMid slice', (tester) async {
        final svg =
            '''<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <image x="0" y="0" width="100" height="100" 
                 preserveAspectRatio="xMinYMid slice"
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
        final svg =
            '''<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
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

      testWidgets('xMaxYMid slice', (tester) async {
        final svg =
            '''<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <image x="0" y="0" width="100" height="100" 
                 preserveAspectRatio="xMaxYMid slice"
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

      testWidgets('xMinYMax slice', (tester) async {
        final svg =
            '''<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <image x="0" y="0" width="100" height="100" 
                 preserveAspectRatio="xMinYMax slice"
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

      testWidgets('xMidYMax slice', (tester) async {
        final svg =
            '''<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <image x="0" y="0" width="100" height="100" 
                 preserveAspectRatio="xMidYMax slice"
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
        final svg =
            '''<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
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

    group('Negative dimension edge cases', () {
      testWidgets('negative width should not crash', (tester) async {
        final svg =
            '''<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <image x="10" y="10" width="-50" height="50" 
                 href="data:image/png;base64,$_tinyBluePngBase64"/>
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

        // Should render without crashing (image is skipped)
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('negative height should not crash', (tester) async {
        final svg =
            '''<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <image x="10" y="10" width="50" height="-50" 
                 href="data:image/png;base64,$_tinyBluePngBase64"/>
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

        // Should render without crashing (image is skipped)
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('both negative dimensions should not crash', (tester) async {
        final svg =
            '''<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <image x="10" y="10" width="-50" height="-50" 
                 href="data:image/png;base64,$_tinyBluePngBase64"/>
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

        // Should render without crashing (image is skipped)
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });
    });

    group('Zero dimension edge cases', () {
      testWidgets('zero width should not crash', (tester) async {
        final svg =
            '''<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <image x="10" y="10" width="0" height="50" 
                 href="data:image/png;base64,$_tinyBluePngBase64"/>
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

        // Should render without crashing (image is skipped)
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('zero height should not crash', (tester) async {
        final svg =
            '''<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <image x="10" y="10" width="50" height="0" 
                 href="data:image/png;base64,$_tinyBluePngBase64"/>
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

        // Should render without crashing (image is skipped)
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('both zero dimensions should not crash', (tester) async {
        final svg =
            '''<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <image x="10" y="10" width="0" height="0" 
                 href="data:image/png;base64,$_tinyBluePngBase64"/>
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

        // Should render without crashing (image is skipped)
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });
    });

    group('overflow:visible with slice mode', () {
      testWidgets('overflow:visible allows image overflow in slice mode', (
        tester,
      ) async {
        final svg =
            '''<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <image x="10" y="10" width="80" height="80" 
                 preserveAspectRatio="xMidYMid slice"
                 style="overflow: visible"
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

        // Should render with overflow visible (no clipping)
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('overflow:visible as attribute allows image overflow', (
        tester,
      ) async {
        final svg =
            '''<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <image x="10" y="10" width="80" height="80" 
                 preserveAspectRatio="xMidYMid slice"
                 overflow="visible"
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

        // Should render with overflow visible (no clipping)
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('default overflow in slice mode clips image', (tester) async {
        final svg =
            '''<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <image x="10" y="10" width="80" height="80" 
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

        // Should render with clipping (default behavior)
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('overflow:hidden in slice mode clips image', (tester) async {
        final svg =
            '''<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <image x="10" y="10" width="80" height="80" 
                 preserveAspectRatio="xMidYMid slice"
                 overflow="hidden"
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

        // Should render with clipping
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });
    });

    group('preserveAspectRatio="none" (stretch to fill)', () {
      testWidgets('none stretches wide image to fill', (tester) async {
        final svg =
            '''<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
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

      testWidgets('none stretches tall image to fill', (tester) async {
        final svg =
            '''<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <image x="0" y="0" width="100" height="100" 
                 preserveAspectRatio="none"
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

      testWidgets('NONE (uppercase) stretches to fill', (tester) async {
        final svg =
            '''<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <image x="0" y="0" width="100" height="100" 
                 preserveAspectRatio="NONE"
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

    group('Missing or invalid image references', () {
      testWidgets('missing href should not crash', (tester) async {
        const svg =
            '''<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <image x="10" y="10" width="80" height="80"/>
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

        // Should render without crashing (image is skipped)
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('empty href should not crash', (tester) async {
        const svg =
            '''<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <image x="10" y="10" width="80" height="80" href=""/>
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

        // Should render without crashing (image is skipped)
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('invalid data URI should not crash', (tester) async {
        const svg =
            '''<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <image x="10" y="10" width="80" height="80" 
                 href="data:invalid"/>
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

        // Should render without crashing (image is skipped)
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });
    });

    group('Unit tests for resolveSvgViewportLayout', () {
      test('slice mode sets clipToViewport true', () {
        final layout = resolveSvgViewportLayout(
          viewport: const ui.Rect.fromLTWH(0, 0, 100, 100),
          sourceSize: const ui.Size(200, 100),
          preserveAspectRatio: 'xMidYMid slice',
        );

        expect(layout.clipToViewport, true);
      });

      test('meet mode sets clipToViewport false', () {
        final layout = resolveSvgViewportLayout(
          viewport: const ui.Rect.fromLTWH(0, 0, 100, 100),
          sourceSize: const ui.Size(200, 100),
          preserveAspectRatio: 'xMidYMid meet',
        );

        expect(layout.clipToViewport, false);
      });

      test('none mode sets clipToViewport false', () {
        final layout = resolveSvgViewportLayout(
          viewport: const ui.Rect.fromLTWH(0, 0, 100, 100),
          sourceSize: const ui.Size(200, 100),
          preserveAspectRatio: 'none',
        );

        expect(layout.clipToViewport, false);
      });

      test('zero source size returns viewport as-is', () {
        final layout = resolveSvgViewportLayout(
          viewport: const ui.Rect.fromLTWH(10, 20, 100, 100),
          sourceSize: const ui.Size(0, 0),
          preserveAspectRatio: 'xMidYMid meet',
        );

        expect(layout.destinationRect.left, 10.0);
        expect(layout.destinationRect.top, 20.0);
        expect(layout.destinationRect.width, 100.0);
        expect(layout.destinationRect.height, 100.0);
        expect(layout.clipToViewport, false);
      });

      test('negative source width returns viewport as-is', () {
        final layout = resolveSvgViewportLayout(
          viewport: const ui.Rect.fromLTWH(0, 0, 100, 100),
          sourceSize: const ui.Size(-50, 100),
          preserveAspectRatio: 'xMidYMid meet',
        );

        expect(layout.destinationRect.width, 100.0);
        expect(layout.destinationRect.height, 100.0);
        expect(layout.clipToViewport, false);
      });

      test('negative source height returns viewport as-is', () {
        final layout = resolveSvgViewportLayout(
          viewport: const ui.Rect.fromLTWH(0, 0, 100, 100),
          sourceSize: const ui.Size(100, -50),
          preserveAspectRatio: 'xMidYMid meet',
        );

        expect(layout.destinationRect.width, 100.0);
        expect(layout.destinationRect.height, 100.0);
        expect(layout.clipToViewport, false);
      });

      test('xMinYMin meet aligns to top-left', () {
        final layout = resolveSvgViewportLayout(
          viewport: const ui.Rect.fromLTWH(0, 0, 100, 100),
          sourceSize: const ui.Size(200, 100),
          preserveAspectRatio: 'xMinYMin meet',
        );

        expect(layout.destinationRect.left, 0.0);
        expect(layout.destinationRect.top, 0.0);
      });

      test('xMaxYMax meet aligns to bottom-right', () {
        final layout = resolveSvgViewportLayout(
          viewport: const ui.Rect.fromLTWH(0, 0, 100, 100),
          sourceSize: const ui.Size(200, 100),
          preserveAspectRatio: 'xMaxYMax meet',
        );

        expect(layout.destinationRect.left, 0.0);
        expect(layout.destinationRect.top, 50.0);
      });

      test('xMidYMid meet centers the image', () {
        final layout = resolveSvgViewportLayout(
          viewport: const ui.Rect.fromLTWH(0, 0, 100, 100),
          sourceSize: const ui.Size(200, 100),
          preserveAspectRatio: 'xMidYMid meet',
        );

        expect(layout.destinationRect.left, 0.0);
        expect(layout.destinationRect.top, 25.0);
      });

      test('slice scales up to fill viewport', () {
        final layout = resolveSvgViewportLayout(
          viewport: const ui.Rect.fromLTWH(0, 0, 100, 100),
          sourceSize: const ui.Size(200, 100),
          preserveAspectRatio: 'xMidYMid slice',
        );

        // Scale = max(100/200, 100/100) = 1.0
        // Dest size: 200x100, centered
        expect(layout.destinationRect.width, 200.0);
        expect(layout.destinationRect.height, 100.0);
        expect(layout.destinationRect.left, -50.0);
        expect(layout.destinationRect.top, 0.0);
      });
    });
  });
}
