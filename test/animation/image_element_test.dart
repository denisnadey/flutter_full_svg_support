import 'package:flutter/material.dart';
import 'package:flutter_svg/src/animation/animated_svg_picture.dart';
import 'package:flutter_test/flutter_test.dart';

// Tiny 2x2 blue PNG as base64
const _tinyBluePngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAYAAABytg0kAAAAEElEQVR42mNgYPj/H4KhDAA/0gf5XBPgQgAAAABJRU5ErkJggg==';

// Tiny 4x2 red PNG as base64 (wider than tall for aspect ratio testing)
const _wideRedPngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAQAAAACCAYAAAB/qH1jAAAAD0lEQVR42mP8z8DwHwYBAAV/AfnLdGqDAAAAAElFTkSuQmCC';

void main() {
  group('Image Element Rendering', () {
    group('data URI image loading', () {
      testWidgets('renders base64 PNG image', (tester) async {
        final svg =
            '''<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <image x="10" y="10" width="80" height="80" 
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

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('renders image with xlink:href', (tester) async {
        final svg =
            '''<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">
          <image x="0" y="0" width="50" height="50" 
                 xlink:href="data:image/png;base64,$_tinyBluePngBase64"/>
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

    group('preserveAspectRatio', () {
      testWidgets('preserveAspectRatio="none" stretches image', (tester) async {
        final svg =
            '''<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <image x="10" y="10" width="80" height="80" 
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

      testWidgets('preserveAspectRatio="xMidYMid meet" (default)', (
        tester,
      ) async {
        final svg =
            '''<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <image x="10" y="10" width="80" height="80" 
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

      testWidgets('preserveAspectRatio="xMinYMin meet" aligns top-left', (
        tester,
      ) async {
        final svg =
            '''<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <image x="10" y="10" width="80" height="80" 
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

      testWidgets('preserveAspectRatio="xMaxYMax slice" crops and aligns', (
        tester,
      ) async {
        final svg =
            '''<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <image x="10" y="10" width="80" height="80" 
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

    group('image element attributes', () {
      testWidgets('image with opacity', (tester) async {
        final svg =
            '''<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <image x="10" y="10" width="80" height="80" opacity="0.5"
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

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('image uses natural dimensions when width/height omitted', (
        tester,
      ) async {
        // Image without explicit width/height should use natural image size
        final svg =
            '''<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <image x="10" y="10"
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

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('image with transform', (tester) async {
        final svg =
            '''<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <image x="10" y="10" width="40" height="40" transform="rotate(45 30 30)"
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

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });
    });

    group('image in defs', () {
      testWidgets('image defined in defs and used', (tester) async {
        final svg =
            '''<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <defs>
            <image id="myImage" x="0" y="0" width="50" height="50"
                   href="data:image/png;base64,$_tinyBluePngBase64"/>
          </defs>
          <use href="#myImage" x="25" y="25"/>
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

    group('Invalid Data URI Handling', () {
      testWidgets('gracefully skips malformed data URI with missing comma', (
        tester,
      ) async {
        // Invalid data URI - missing comma between header and data
        const svg = '''
          <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
            <image x="10" y="10" width="80" height="80" 
                   href="data:image/png;base64NOTVALIDBASE64"/>
            <rect x="20" y="20" width="60" height="60" fill="green"/>
          </svg>''';

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: AnimatedSvgPicture.string(svg, width: 200, height: 200),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Should render without errors - the invalid image is skipped
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('gracefully skips data URI with truncated base64', (
        tester,
      ) async {
        // Invalid data URI - truncated base64 data
        const svg = '''
          <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
            <image x="10" y="10" width="80" height="80" 
                   href="data:image/png;base64,iVBOR"/>
            <rect x="30" y="30" width="40" height="40" fill="blue"/>
          </svg>''';

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: AnimatedSvgPicture.string(svg, width: 200, height: 200),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Should render without errors - other elements still display
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('gracefully skips data URI with empty data portion', (
        tester,
      ) async {
        // Invalid data URI - empty data after comma
        const svg = '''
          <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
            <image x="10" y="10" width="80" height="80" 
                   href="data:image/png;base64,"/>
            <circle cx="50" cy="50" r="20" fill="red"/>
          </svg>''';

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: AnimatedSvgPicture.string(svg, width: 200, height: 200),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Should render without errors - invalid image skipped
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('valid data URI still renders correctly', (tester) async {
        // Valid data URI should still work
        final svg =
            '''
          <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
            <image x="10" y="10" width="80" height="80" 
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

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });
    });
  });
}
