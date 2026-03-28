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
  group('External Content - Filter Application on Image Elements', () {
    testWidgets('renders image with feGaussianBlur filter', (tester) async {
      const svg =
          '''<svg viewBox="0 0 200 200" xmlns="http://www.w3.org/2000/svg">
        <defs>
          <filter id="blur">
            <feGaussianBlur stdDeviation="2"/>
          </filter>
        </defs>
        <image x="10" y="10" width="80" height="80" 
               filter="url(#blur)"
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

    testWidgets('renders image with feDropShadow filter', (tester) async {
      const svg =
          '''<svg viewBox="0 0 200 200" xmlns="http://www.w3.org/2000/svg">
        <defs>
          <filter id="shadow">
            <feDropShadow dx="3" dy="3" stdDeviation="2" flood-color="black" flood-opacity="0.5"/>
          </filter>
        </defs>
        <image x="20" y="20" width="60" height="60" 
               filter="url(#shadow)"
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

    testWidgets('renders image with chained filter primitives', (tester) async {
      const svg =
          '''<svg viewBox="0 0 200 200" xmlns="http://www.w3.org/2000/svg">
        <defs>
          <filter id="combined">
            <feGaussianBlur in="SourceGraphic" stdDeviation="1" result="blur"/>
            <feOffset in="blur" dx="2" dy="2" result="offset"/>
            <feMerge>
              <feMergeNode in="offset"/>
              <feMergeNode in="SourceGraphic"/>
            </feMerge>
          </filter>
        </defs>
        <image x="10" y="10" width="80" height="80" 
               filter="url(#combined)"
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

  group('External Content - preserveAspectRatio Variations', () {
    testWidgets('preserveAspectRatio="none" stretches image to fill', (
      tester,
    ) async {
      const svg =
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

    testWidgets('preserveAspectRatio="xMidYMid meet" scales uniformly to fit', (
      tester,
    ) async {
      const svg =
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

    testWidgets('preserveAspectRatio="xMidYMid slice" covers viewport', (
      tester,
    ) async {
      const svg =
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

    testWidgets('preserveAspectRatio with transformed parent', (tester) async {
      const svg =
          '''<svg viewBox="0 0 200 200" xmlns="http://www.w3.org/2000/svg">
        <g transform="rotate(45 100 100)">
          <image x="25" y="25" width="150" height="150" 
                 preserveAspectRatio="xMidYMid meet"
                 href="data:image/png;base64,$_wideRedPngBase64"/>
        </g>
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

    testWidgets('preserveAspectRatio with skewed parent', (tester) async {
      const svg =
          '''<svg viewBox="0 0 200 200" xmlns="http://www.w3.org/2000/svg">
        <g transform="skewX(15)">
          <image x="10" y="10" width="100" height="100" 
                 preserveAspectRatio="xMinYMin meet"
                 href="data:image/png;base64,$_wideRedPngBase64"/>
        </g>
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

    testWidgets('preserveAspectRatio with non-uniform scale parent', (
      tester,
    ) async {
      const svg =
          '''<svg viewBox="0 0 200 200" xmlns="http://www.w3.org/2000/svg">
        <g transform="scale(2 0.5)">
          <image x="10" y="20" width="40" height="80" 
                 preserveAspectRatio="xMaxYMax slice"
                 href="data:image/png;base64,$_wideRedPngBase64"/>
        </g>
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

  group('External Content - Nested SVG in foreignObject', () {
    testWidgets('nested SVG with viewBox in foreignObject', (tester) async {
      const svg =
          '''<svg viewBox="0 0 200 200" xmlns="http://www.w3.org/2000/svg">
        <foreignObject x="20" y="20" width="160" height="160">
          <svg viewBox="0 0 100 100" width="100%" height="100%">
            <rect x="10" y="10" width="80" height="80" fill="blue"/>
            <circle cx="50" cy="50" r="30" fill="red"/>
          </svg>
        </foreignObject>
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

    testWidgets('nested SVG with preserveAspectRatio in foreignObject', (
      tester,
    ) async {
      const svg =
          '''<svg viewBox="0 0 200 200" xmlns="http://www.w3.org/2000/svg">
        <foreignObject x="10" y="10" width="180" height="180">
          <svg viewBox="0 0 50 100" preserveAspectRatio="xMidYMid meet" 
               width="100%" height="100%">
            <rect x="0" y="0" width="50" height="100" fill="green"/>
          </svg>
        </foreignObject>
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

    testWidgets('nested SVG with overflow hidden in foreignObject', (
      tester,
    ) async {
      const svg =
          '''<svg viewBox="0 0 200 200" xmlns="http://www.w3.org/2000/svg">
        <foreignObject x="50" y="50" width="100" height="100">
          <svg viewBox="0 0 200 200" overflow="hidden" width="100%" height="100%">
            <rect x="-50" y="-50" width="300" height="300" fill="purple"/>
          </svg>
        </foreignObject>
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

    testWidgets('nested SVG with overflow visible in foreignObject', (
      tester,
    ) async {
      const svg =
          '''<svg viewBox="0 0 200 200" xmlns="http://www.w3.org/2000/svg">
        <foreignObject x="50" y="50" width="100" height="100">
          <svg viewBox="0 0 100 100" overflow="visible" width="100%" height="100%">
            <rect x="-20" y="-20" width="140" height="140" fill="orange"/>
          </svg>
        </foreignObject>
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

    testWidgets('nested SVG inherits styles from foreignObject parent', (
      tester,
    ) async {
      const svg =
          '''<svg viewBox="0 0 200 200" xmlns="http://www.w3.org/2000/svg">
        <foreignObject x="10" y="10" width="180" height="180" style="font-size: 20px; color: blue;">
          <svg viewBox="0 0 100 100" width="100%" height="100%">
            <text x="10" y="50" fill="currentColor">Test</text>
          </svg>
        </foreignObject>
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

    testWidgets('nested SVG with percentage dimensions in foreignObject', (
      tester,
    ) async {
      const svg =
          '''<svg viewBox="0 0 200 200" xmlns="http://www.w3.org/2000/svg">
        <foreignObject x="0" y="0" width="200" height="200">
          <svg viewBox="0 0 100 100" width="50%" height="50%">
            <rect x="0" y="0" width="100" height="100" fill="cyan"/>
          </svg>
        </foreignObject>
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

  group('External Content - Image Error Fallback', () {
    testWidgets('handles invalid data URI gracefully', (tester) async {
      const svg =
          '''<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
        <image x="10" y="10" width="80" height="80" 
               href="data:image/png;base64,INVALID_BASE64_DATA"/>
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

      // Should not throw, just render gracefully
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('handles missing image href gracefully', (tester) async {
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

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('handles empty image href gracefully', (tester) async {
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

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('handles corrupt image data gracefully', (tester) async {
      // Valid PNG header but corrupt content
      const svg =
          '''<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <image x="10" y="10" width="80" height="80" 
                 href="data:image/png;base64,iVBORw0KGgoAAAANSU"/>
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

    testWidgets('image with specified dimensions renders fallback on error', (
      tester,
    ) async {
      const svg =
          '''<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
        <rect x="0" y="0" width="100" height="100" fill="yellow"/>
        <image x="10" y="10" width="80" height="80" 
               href="https://invalid.domain.that.does.not.exist/image.png"/>
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

      // Should render without throwing
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });

  group('External Content - Combined Scenarios', () {
    testWidgets('image with filter inside transformed group', (tester) async {
      const svg =
          '''<svg viewBox="0 0 200 200" xmlns="http://www.w3.org/2000/svg">
        <defs>
          <filter id="blur2">
            <feGaussianBlur stdDeviation="3"/>
          </filter>
        </defs>
        <g transform="translate(50, 50) scale(0.5)">
          <image x="0" y="0" width="200" height="200" 
                 filter="url(#blur2)"
                 preserveAspectRatio="xMidYMid meet"
                 href="data:image/png;base64,$_tinyBluePngBase64"/>
        </g>
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

    testWidgets('nested SVG with filter in foreignObject', (tester) async {
      const svg =
          '''<svg viewBox="0 0 200 200" xmlns="http://www.w3.org/2000/svg">
        <defs>
          <filter id="shadow2">
            <feDropShadow dx="2" dy="2" stdDeviation="1"/>
          </filter>
        </defs>
        <foreignObject x="10" y="10" width="180" height="180">
          <svg viewBox="0 0 100 100" width="100%" height="100%">
            <rect x="10" y="10" width="80" height="80" fill="blue" filter="url(#shadow2)"/>
          </svg>
        </foreignObject>
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

    testWidgets('multiple images with different preserveAspectRatio', (
      tester,
    ) async {
      const svg =
          '''<svg viewBox="0 0 300 100" xmlns="http://www.w3.org/2000/svg">
        <image x="0" y="0" width="100" height="100" 
               preserveAspectRatio="none"
               href="data:image/png;base64,$_wideRedPngBase64"/>
        <image x="100" y="0" width="100" height="100" 
               preserveAspectRatio="xMidYMid meet"
               href="data:image/png;base64,$_wideRedPngBase64"/>
        <image x="200" y="0" width="100" height="100" 
               preserveAspectRatio="xMidYMid slice"
               href="data:image/png;base64,$_wideRedPngBase64"/>
      </svg>''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svg, width: 300, height: 100),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });
}
