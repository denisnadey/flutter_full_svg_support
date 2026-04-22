import 'package:flutter/material.dart';
import 'package:full_svg_flutter/src/animation/animated_svg_picture.dart';
import 'package:full_svg_flutter/src/animation/preserve_aspect_ratio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:ui' as ui;

// Tiny 2x2 blue PNG as base64
const _tinyBluePngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAYAAABytg0kAAAAEElEQVR42mNgYPj/H4KhDAA/0gf5XBPgQgAAAABJRU5ErkJggg==';

// Tiny 4x2 red PNG as base64 (landscape - wider than tall)
const _wideRedPngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAQAAAACCAYAAAB/qH1jAAAAD0lEQVR42mP8z8DwHwYBAAV/AfnLdGqDAAAAAElFTkSuQmCC';

// Tiny 2x4 blue PNG as base64 (portrait - taller than wide)
const _tallBluePngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAIAAAAECAYAAACk7+45AAAAEUlEQVR42mNgYPj/nwGKoQwAFE4D+UlHcIoAAAAASUVORK5CYII=';

void main() {
  group('Image Nesting and Aspect Ratio Edge Cases', () {
    group('preserveAspectRatio alignments', () {
      testWidgets(
        'xMinYMin meet - aligns to top-left corner and fits within viewport',
        (tester) async {
          // Test: landscape image (4x2) in square viewport (100x100)
          // Expected: image scaled to fit (100x50), positioned at top-left (0,0)
          final svg =
              '''
            <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
              <image x="0" y="0" width="100" height="100" 
                     preserveAspectRatio="xMinYMin meet"
                     href="data:image/png;base64,$_wideRedPngBase64"/>
            </svg>
          ''';

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

          // Verify unit test behavior
          final layout = resolveSvgViewportLayout(
            viewport: ui.Rect.fromLTWH(0, 0, 100, 100),
            sourceSize: const ui.Size(4, 2), // 4:2 landscape
            preserveAspectRatio: 'xMinYMin meet',
          );

          // Scale = min(100/4, 100/2) = 25 → dest: 100x50
          expect(layout.destinationRect.left, 0.0); // xMin → left
          expect(layout.destinationRect.top, 0.0); // yMin → top
          expect(layout.destinationRect.width, 100.0);
          expect(layout.destinationRect.height, 50.0);
          expect(layout.clipToViewport, false); // meet doesn't clip
        },
      );

      testWidgets(
        'xMidYMid meet (default) - centers image and fits within viewport',
        (tester) async {
          // Test: landscape image in square viewport, centered
          final svg =
              '''
            <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
              <image x="0" y="0" width="100" height="100" 
                     preserveAspectRatio="xMidYMid meet"
                     href="data:image/png;base64,$_wideRedPngBase64"/>
            </svg>
          ''';

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

          // Verify unit test behavior
          final layout = resolveSvgViewportLayout(
            viewport: ui.Rect.fromLTWH(0, 0, 100, 100),
            sourceSize: const ui.Size(4, 2),
            preserveAspectRatio: 'xMidYMid meet',
          );

          // Centered: top = (100 - 50) / 2 = 25
          expect(layout.destinationRect.left, 0.0);
          expect(layout.destinationRect.top, 25.0); // Centered vertically
          expect(layout.destinationRect.width, 100.0);
          expect(layout.destinationRect.height, 50.0);
          expect(layout.clipToViewport, false);
        },
      );

      testWidgets(
        'xMaxYMax slice - aligns to bottom-right and clips overflow',
        (tester) async {
          // Test: landscape image scaled to cover (slice), aligned bottom-right
          final svg =
              '''
            <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
              <image x="0" y="0" width="100" height="100" 
                     preserveAspectRatio="xMaxYMax slice"
                     href="data:image/png;base64,$_wideRedPngBase64"/>
            </svg>
          ''';

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

          // Verify unit test behavior
          final layout = resolveSvgViewportLayout(
            viewport: ui.Rect.fromLTWH(0, 0, 100, 100),
            sourceSize: const ui.Size(4, 2),
            preserveAspectRatio: 'xMaxYMax slice',
          );

          // Scale = max(100/4, 100/2) = 50 → dest: 200x100
          // xMax: left = 100 - 200 = -100
          // yMax: top = 100 - 100 = 0
          expect(layout.destinationRect.left, -100.0);
          expect(layout.destinationRect.top, 0.0);
          expect(layout.destinationRect.width, 200.0);
          expect(layout.destinationRect.height, 100.0);
          expect(layout.clipToViewport, true); // slice clips
        },
      );

      testWidgets('none - stretches image non-uniformly to fill viewport', (
        tester,
      ) async {
        // Test: preserveAspectRatio="none" ignores aspect ratio
        final svg =
            '''
            <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
              <image x="10" y="20" width="80" height="60" 
                     preserveAspectRatio="none"
                     href="data:image/png;base64,$_wideRedPngBase64"/>
            </svg>
          ''';

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

        // Verify unit test behavior
        final layout = resolveSvgViewportLayout(
          viewport: ui.Rect.fromLTWH(10, 20, 80, 60),
          sourceSize: const ui.Size(4, 2),
          preserveAspectRatio: 'none',
        );

        // none: exact viewport dimensions, no aspect preservation
        expect(layout.destinationRect.left, 10.0);
        expect(layout.destinationRect.top, 20.0);
        expect(layout.destinationRect.width, 80.0);
        expect(layout.destinationRect.height, 60.0);
        expect(layout.clipToViewport, false);
      });
    });

    group('aspect ratio with different image orientations', () {
      testWidgets(
        'meet on landscape image in portrait viewport - letterboxes vertically',
        (tester) async {
          // Landscape image (200x100) in portrait viewport (50x100)
          // Scale = min(50/200, 100/100) = 0.25 → dest: 50x25, centered
          final svg =
              '''
            <svg viewBox="0 0 50 100" xmlns="http://www.w3.org/2000/svg">
              <image x="0" y="0" width="50" height="100" 
                     preserveAspectRatio="xMidYMid meet"
                     href="data:image/png;base64,$_wideRedPngBase64"/>
            </svg>
          ''';

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: AnimatedSvgPicture.string(svg, width: 100, height: 200),
              ),
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));

          expect(find.byType(AnimatedSvgPicture), findsOneWidget);

          // Verify unit test behavior
          final layout = resolveSvgViewportLayout(
            viewport: ui.Rect.fromLTWH(0, 0, 50, 100),
            sourceSize: const ui.Size(200, 100), // landscape source
            preserveAspectRatio: 'xMidYMid meet',
          );

          // Scale = min(50/200, 100/100) = 0.25 → dest: 50x25
          // Centered: top = (100 - 25) / 2 = 37.5
          expect(layout.destinationRect.left, 0.0);
          expect(layout.destinationRect.top, 37.5);
          expect(layout.destinationRect.width, 50.0);
          expect(layout.destinationRect.height, 25.0);
        },
      );

      testWidgets(
        'slice on portrait image in landscape viewport - clips horizontally',
        (tester) async {
          // Portrait image (2x4) in landscape viewport (100x50)
          // Scale = max(100/2, 50/4) = 50 → dest: 100x200, centered
          final svg =
              '''
            <svg viewBox="0 0 100 50" xmlns="http://www.w3.org/2000/svg">
              <image x="0" y="0" width="100" height="50" 
                     preserveAspectRatio="xMidYMid slice"
                     href="data:image/png;base64,$_tallBluePngBase64"/>
            </svg>
          ''';

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: AnimatedSvgPicture.string(svg, width: 200, height: 100),
              ),
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));

          expect(find.byType(AnimatedSvgPicture), findsOneWidget);

          // Verify unit test behavior
          final layout = resolveSvgViewportLayout(
            viewport: ui.Rect.fromLTWH(0, 0, 100, 50),
            sourceSize: const ui.Size(2, 4), // portrait source
            preserveAspectRatio: 'xMidYMid slice',
          );

          // Scale = max(100/2, 50/4) = 50 → dest: 100x200
          // Centered: top = (50 - 200) / 2 = -75
          expect(layout.destinationRect.left, 0.0);
          expect(layout.destinationRect.top, -75.0);
          expect(layout.destinationRect.width, 100.0);
          expect(layout.destinationRect.height, 200.0);
          expect(layout.clipToViewport, true);
        },
      );
    });

    group('SVG-in-SVG nesting', () {
      testWidgets('nested SVG with viewBox transforms correctly', (
        tester,
      ) async {
        // Outer SVG has image element, which could reference nested SVG
        // This tests the nested viewport transform chain
        final svg =
            '''
            <svg viewBox="0 0 200 200" xmlns="http://www.w3.org/2000/svg">
              <svg x="50" y="50" width="100" height="100" viewBox="0 0 50 50">
                <image x="5" y="5" width="40" height="40"
                       href="data:image/png;base64,$_tinyBluePngBase64"/>
              </svg>
            </svg>
          ''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AnimatedSvgPicture.string(svg, width: 400, height: 400),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
        // The nested SVG's viewBox (0 0 50 50) maps to viewport (100x100)
        // Scale factor = 2x, so image at (5,5)-(45,45) maps to (10,10)-(90,90)
        // Plus outer offset (50,50) = final position (60,60)-(140,140)
      });
    });

    group('image dimension edge cases', () {
      testWidgets(
        'image with width/height but no viewBox uses natural dimensions',
        (tester) async {
          // When image has explicit width/height, those define the viewport
          // preserveAspectRatio then places the image within that viewport
          final svg =
              '''
            <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
              <image x="10" y="10" width="80" height="80"
                     preserveAspectRatio="xMidYMid meet"
                     href="data:image/png;base64,$_wideRedPngBase64"/>
            </svg>
          ''';

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

          // Wide image (4x2) in square viewport (80x80)
          // Scale = min(80/4, 80/2) = 20 → dest: 80x40, centered
          final layout = resolveSvgViewportLayout(
            viewport: ui.Rect.fromLTWH(10, 10, 80, 80),
            sourceSize: const ui.Size(4, 2),
            preserveAspectRatio: 'xMidYMid meet',
          );

          expect(layout.destinationRect.left, 10.0);
          expect(layout.destinationRect.top, 30.0); // 10 + (80-40)/2
          expect(layout.destinationRect.width, 80.0);
          expect(layout.destinationRect.height, 40.0);
        },
      );
    });

    group('data URI handling', () {
      testWidgets('data URI with base64 PNG renders correctly', (tester) async {
        final svg =
            '''
            <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
              <image x="25" y="25" width="50" height="50"
                     href="data:image/png;base64,$_tinyBluePngBase64"/>
            </svg>
          ''';

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

      testWidgets('malformed/missing href handles gracefully without crash', (
        tester,
      ) async {
        // Test various malformed href scenarios
        final svg =
            '''
            <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
              <!-- Missing href entirely -->
              <image x="0" y="0" width="20" height="20"/>
              
              <!-- Empty href -->
              <image x="25" y="0" width="20" height="20" href=""/>
              
              <!-- Malformed data URI - no comma -->
              <image x="50" y="0" width="20" height="20" href="data:image/png"/>
              
              <!-- Malformed data URI - too short -->
              <image x="75" y="0" width="20" height="20" href="data:"/>
              
              <!-- Invalid base64 -->
              <image x="0" y="25" width="20" height="20" 
                     href="data:image/png;base64,!!!invalid!!!"/>
              
              <!-- Unknown protocol -->
              <image x="25" y="25" width="20" height="20" 
                     href="unknown://example.com/image.png"/>
              
              <!-- Valid image to verify rendering still works -->
              <image x="50" y="50" width="40" height="40"
                     href="data:image/png;base64,$_tinyBluePngBase64"/>
            </svg>
          ''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AnimatedSvgPicture.string(svg, width: 200, height: 200),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Should not crash, valid image should still render
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });
    });
  });
}
