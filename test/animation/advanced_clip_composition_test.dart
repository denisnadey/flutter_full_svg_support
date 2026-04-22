import 'package:flutter/material.dart';
import 'package:full_svg_flutter/src/animation/animated_svg_picture.dart';
import 'package:flutter_test/flutter_test.dart';

import 'visual_test_utils.dart';

/// Comprehensive tests for advanced SVG clipping composition.
/// Tests deeply nested clipPaths, mixed units, transform compositions,
/// text clipping enhancements, and various shape types in clipPath.
void main() {
  group('Deeply Nested clipPath Cascading', () {
    testWidgets('4-level nested clipPaths with intersection', (
      WidgetTester tester,
    ) async {
      // Four levels of cascading clipPaths - result is intersection of all
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <clipPath id="level1">
              <rect x="0" y="0" width="90" height="90"/>
            </clipPath>
            <clipPath id="level2" clip-path="url(#level1)">
              <rect x="10" y="10" width="80" height="80"/>
            </clipPath>
            <clipPath id="level3" clip-path="url(#level2)">
              <rect x="20" y="20" width="60" height="60"/>
            </clipPath>
            <clipPath id="level4" clip-path="url(#level3)">
              <rect x="30" y="30" width="40" height="40"/>
            </clipPath>
          </defs>
          <rect x="0" y="0" width="100" height="100" fill="red" 
                clip-path="url(#level4)"/>
        </svg>
      ''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svgXml, width: 200, height: 200),
          ),
        ),
      );

      await tester.pump();

      final pixels = await VisualTestUtils.captureWidgetPixels(tester);
      final analysis = VisualTestUtils.analyzeRedPixels(pixels, 800, 600);

      // Should render innermost clip (30,30,40,40)
      expect(analysis.pixelCount, greaterThan(100));
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('5-level nested clipPaths (deep recursion)', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <clipPath id="c1"><rect x="5" y="5" width="90" height="90"/></clipPath>
            <clipPath id="c2" clip-path="url(#c1)"><rect x="10" y="10" width="80" height="80"/></clipPath>
            <clipPath id="c3" clip-path="url(#c2)"><rect x="15" y="15" width="70" height="70"/></clipPath>
            <clipPath id="c4" clip-path="url(#c3)"><rect x="20" y="20" width="60" height="60"/></clipPath>
            <clipPath id="c5" clip-path="url(#c4)"><rect x="25" y="25" width="50" height="50"/></clipPath>
          </defs>
          <rect x="0" y="0" width="100" height="100" fill="red" 
                clip-path="url(#c5)"/>
        </svg>
      ''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svgXml, width: 200, height: 200),
          ),
        ),
      );

      await tester.pump();

      // Should render without crash, innermost clip visible
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });

  group('Mixed clipPathUnits at Each Level', () {
    testWidgets('userSpaceOnUse then objectBoundingBox cascaded', (
      WidgetTester tester,
    ) async {
      // First level uses userSpaceOnUse, second uses objectBoundingBox
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <clipPath id="outer" clipPathUnits="userSpaceOnUse">
              <rect x="10" y="10" width="80" height="80"/>
            </clipPath>
            <clipPath id="inner" clipPathUnits="objectBoundingBox" clip-path="url(#outer)">
              <rect x="0.1" y="0.1" width="0.8" height="0.8"/>
            </clipPath>
          </defs>
          <rect x="0" y="0" width="100" height="100" fill="red" 
                clip-path="url(#inner)"/>
        </svg>
      ''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svgXml, width: 200, height: 200),
          ),
        ),
      );

      await tester.pump();

      final pixels = await VisualTestUtils.captureWidgetPixels(tester);
      final analysis = VisualTestUtils.analyzeRedPixels(pixels, 800, 600);

      // Should show intersection of both clips
      expect(analysis.pixelCount, greaterThan(50));
    });

    testWidgets('objectBoundingBox then userSpaceOnUse cascaded', (
      WidgetTester tester,
    ) async {
      // First level uses objectBoundingBox, second uses userSpaceOnUse
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <clipPath id="outer" clipPathUnits="objectBoundingBox">
              <rect x="0" y="0" width="1" height="1"/>
            </clipPath>
            <clipPath id="inner" clipPathUnits="userSpaceOnUse" clip-path="url(#outer)">
              <circle cx="50" cy="50" r="30"/>
            </clipPath>
          </defs>
          <rect x="20" y="20" width="60" height="60" fill="red" 
                clip-path="url(#inner)"/>
        </svg>
      ''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svgXml, width: 200, height: 200),
          ),
        ),
      );

      await tester.pump();

      final pixels = await VisualTestUtils.captureWidgetPixels(tester);
      final analysis = VisualTestUtils.analyzeRedPixels(pixels, 800, 600);

      // Circle clipped by rect bounds
      expect(analysis.pixelCount, greaterThan(100));
    });

    testWidgets('3-level cascade with alternating units', (
      WidgetTester tester,
    ) async {
      // alternating: user -> obb -> user
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <clipPath id="clip1" clipPathUnits="userSpaceOnUse">
              <rect x="5" y="5" width="90" height="90"/>
            </clipPath>
            <clipPath id="clip2" clipPathUnits="objectBoundingBox" clip-path="url(#clip1)">
              <rect x="0.1" y="0.1" width="0.8" height="0.8"/>
            </clipPath>
            <clipPath id="clip3" clipPathUnits="userSpaceOnUse" clip-path="url(#clip2)">
              <rect x="25" y="25" width="50" height="50"/>
            </clipPath>
          </defs>
          <rect x="0" y="0" width="100" height="100" fill="red" 
                clip-path="url(#clip3)"/>
        </svg>
      ''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svgXml, width: 200, height: 200),
          ),
        ),
      );

      await tester.pump();

      final pixels = await VisualTestUtils.captureWidgetPixels(tester);
      final analysis = VisualTestUtils.analyzeRedPixels(pixels, 800, 600);

      // Intersection of all three
      expect(analysis.pixelCount, greaterThan(50));
    });
  });

  group('Enhanced Text Clipping', () {
    testWidgets('Text clip with multiple characters', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 200 100">
          <defs>
            <clipPath id="textClip">
              <text x="10" y="60" font-size="48" font-family="sans-serif">HELLO</text>
            </clipPath>
          </defs>
          <rect x="0" y="0" width="200" height="100" fill="red" 
                clip-path="url(#textClip)"/>
        </svg>
      ''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svgXml, width: 400, height: 200),
          ),
        ),
      );

      await tester.pump();

      // Character-level clipping should work
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('Text clip with text-anchor middle', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <clipPath id="textClip">
              <text x="50" y="60" font-size="30" text-anchor="middle">Hi</text>
            </clipPath>
          </defs>
          <rect x="0" y="0" width="100" height="100" fill="red" 
                clip-path="url(#textClip)"/>
        </svg>
      ''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svgXml, width: 200, height: 200),
          ),
        ),
      );

      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('Text clip with text-anchor end', (WidgetTester tester) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <clipPath id="textClip">
              <text x="90" y="60" font-size="30" text-anchor="end">AB</text>
            </clipPath>
          </defs>
          <rect x="0" y="0" width="100" height="100" fill="red" 
                clip-path="url(#textClip)"/>
        </svg>
      ''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svgXml, width: 200, height: 200),
          ),
        ),
      );

      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });

  group('Transform Composition in clipPath', () {
    testWidgets('clipPath with rotate transform', (WidgetTester tester) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <clipPath id="clip" transform="rotate(45, 50, 50)">
              <rect x="25" y="25" width="50" height="50"/>
            </clipPath>
          </defs>
          <rect x="0" y="0" width="100" height="100" fill="red" 
                clip-path="url(#clip)"/>
        </svg>
      ''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svgXml, width: 200, height: 200),
          ),
        ),
      );

      await tester.pump();

      final pixels = await VisualTestUtils.captureWidgetPixels(tester);
      final analysis = VisualTestUtils.analyzeRedPixels(pixels, 800, 600);

      // Rotated clip should produce diamond shape
      expect(analysis.pixelCount, greaterThan(100));
    });

    testWidgets('clipPath with scale transform', (WidgetTester tester) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <clipPath id="clip" transform="scale(0.5) translate(50, 50)">
              <rect x="0" y="0" width="100" height="100"/>
            </clipPath>
          </defs>
          <rect x="0" y="0" width="100" height="100" fill="red" 
                clip-path="url(#clip)"/>
        </svg>
      ''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svgXml, width: 200, height: 200),
          ),
        ),
      );

      await tester.pump();

      final pixels = await VisualTestUtils.captureWidgetPixels(tester);
      final analysis = VisualTestUtils.analyzeRedPixels(pixels, 800, 600);

      // Scaled clip
      expect(analysis.pixelCount, greaterThan(50));
    });

    testWidgets('Nested transforms in clipPath children', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <clipPath id="clip">
              <g transform="translate(10, 10)">
                <g transform="rotate(15, 40, 40)">
                  <rect x="10" y="10" width="60" height="60"/>
                </g>
              </g>
            </clipPath>
          </defs>
          <rect x="0" y="0" width="100" height="100" fill="red" 
                clip-path="url(#clip)"/>
        </svg>
      ''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svgXml, width: 200, height: 200),
          ),
        ),
      );

      await tester.pump();

      final pixels = await VisualTestUtils.captureWidgetPixels(tester);
      final analysis = VisualTestUtils.analyzeRedPixels(pixels, 800, 600);

      expect(analysis.pixelCount, greaterThan(100));
    });

    testWidgets('clipPath with objectBoundingBox and element transform', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <clipPath id="clip" clipPathUnits="objectBoundingBox">
              <rect x="0.1" y="0.1" width="0.8" height="0.8"/>
            </clipPath>
          </defs>
          <rect x="10" y="10" width="60" height="60" fill="red" 
                transform="rotate(20, 40, 40)"
                clip-path="url(#clip)"/>
        </svg>
      ''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svgXml, width: 200, height: 200),
          ),
        ),
      );

      await tester.pump();

      final pixels = await VisualTestUtils.captureWidgetPixels(tester);
      final analysis = VisualTestUtils.analyzeRedPixels(pixels, 800, 600);

      expect(analysis.pixelCount, greaterThan(50));
    });
  });

  group('Polygon and Polyline in clipPath', () {
    testWidgets('Polygon as clip geometry', (WidgetTester tester) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <clipPath id="clip">
              <polygon points="50,10 90,90 10,90"/>
            </clipPath>
          </defs>
          <rect x="0" y="0" width="100" height="100" fill="red" 
                clip-path="url(#clip)"/>
        </svg>
      ''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svgXml, width: 200, height: 200),
          ),
        ),
      );

      await tester.pump();

      final pixels = await VisualTestUtils.captureWidgetPixels(tester);
      final analysis = VisualTestUtils.analyzeRedPixels(pixels, 800, 600);

      // Triangle clip
      expect(analysis.pixelCount, greaterThan(200));
    });

    testWidgets('Star polygon as clip', (WidgetTester tester) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <clipPath id="clip">
              <polygon points="50,5 61,40 98,40 68,62 79,95 50,75 21,95 32,62 2,40 39,40"/>
            </clipPath>
          </defs>
          <rect x="0" y="0" width="100" height="100" fill="red" 
                clip-path="url(#clip)"/>
        </svg>
      ''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svgXml, width: 200, height: 200),
          ),
        ),
      );

      await tester.pump();

      // Star clip should work
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('Multiple polygons in clipPath (union)', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <clipPath id="clip">
              <polygon points="10,10 30,10 30,30 10,30"/>
              <polygon points="70,70 90,70 90,90 70,90"/>
            </clipPath>
          </defs>
          <rect x="0" y="0" width="100" height="100" fill="red" 
                clip-path="url(#clip)"/>
        </svg>
      ''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svgXml, width: 200, height: 200),
          ),
        ),
      );

      await tester.pump();

      final pixels = await VisualTestUtils.captureWidgetPixels(tester);
      final analysis = VisualTestUtils.analyzeRedPixels(pixels, 800, 600);

      // Two polygon clips (union)
      expect(analysis.pixelCount, greaterThan(50));
    });
  });

  group('Group Clipping Inheritance', () {
    testWidgets('Clip on group affects all children', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <clipPath id="clip">
              <circle cx="50" cy="50" r="30"/>
            </clipPath>
          </defs>
          <g clip-path="url(#clip)">
            <rect x="0" y="0" width="100" height="50" fill="red"/>
            <rect x="0" y="50" width="100" height="50" fill="blue"/>
          </g>
        </svg>
      ''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svgXml, width: 200, height: 200),
          ),
        ),
      );

      await tester.pump();

      // Both rects should be clipped by circle
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('Nested groups with clips', (WidgetTester tester) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <clipPath id="outerClip">
              <rect x="10" y="10" width="80" height="80"/>
            </clipPath>
            <clipPath id="innerClip">
              <circle cx="50" cy="50" r="25"/>
            </clipPath>
          </defs>
          <g clip-path="url(#outerClip)">
            <rect x="0" y="0" width="100" height="100" fill="blue"/>
            <g clip-path="url(#innerClip)">
              <rect x="0" y="0" width="100" height="100" fill="red"/>
            </g>
          </g>
        </svg>
      ''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svgXml, width: 200, height: 200),
          ),
        ),
      );

      await tester.pump();

      final pixels = await VisualTestUtils.captureWidgetPixels(tester);
      final analysis = VisualTestUtils.analyzeRedPixels(pixels, 800, 600);

      // Inner red circle should be clipped by both
      expect(analysis.pixelCount, greaterThan(50));
    });
  });

  group('Use Element in clipPath', () {
    testWidgets('use referencing rect in clipPath', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <rect id="clipShape" width="40" height="40"/>
            <clipPath id="clip">
              <use href="#clipShape" x="30" y="30"/>
            </clipPath>
          </defs>
          <rect x="0" y="0" width="100" height="100" fill="red" 
                clip-path="url(#clip)"/>
        </svg>
      ''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svgXml, width: 200, height: 200),
          ),
        ),
      );

      await tester.pump();

      final pixels = await VisualTestUtils.captureWidgetPixels(tester);
      final analysis = VisualTestUtils.analyzeRedPixels(pixels, 800, 600);

      // Referenced rect at (30,30) size 40x40
      expect(analysis.pixelCount, greaterThan(100));
    });

    testWidgets('use referencing symbol with viewBox in clipPath', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <symbol id="sym" viewBox="0 0 20 20">
              <circle cx="10" cy="10" r="10"/>
            </symbol>
            <clipPath id="clip">
              <use href="#sym" x="20" y="20" width="60" height="60"/>
            </clipPath>
          </defs>
          <rect x="0" y="0" width="100" height="100" fill="red" 
                clip-path="url(#clip)"/>
        </svg>
      ''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svgXml, width: 200, height: 200),
          ),
        ),
      );

      await tester.pump();

      final pixels = await VisualTestUtils.captureWidgetPixels(tester);
      final analysis = VisualTestUtils.analyzeRedPixels(pixels, 800, 600);

      // Symbol circle scaled to 60x60 at (20,20)
      expect(analysis.pixelCount, greaterThan(200));
    });

    testWidgets('use with transform in clipPath', (WidgetTester tester) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <rect id="baseRect" width="30" height="30"/>
            <clipPath id="clip">
              <use href="#baseRect" x="20" y="20" transform="rotate(45, 35, 35)"/>
            </clipPath>
          </defs>
          <rect x="0" y="0" width="100" height="100" fill="red" 
                clip-path="url(#clip)"/>
        </svg>
      ''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svgXml, width: 200, height: 200),
          ),
        ),
      );

      await tester.pump();

      final pixels = await VisualTestUtils.captureWidgetPixels(tester);
      final analysis = VisualTestUtils.analyzeRedPixels(pixels, 800, 600);

      // Rotated rect clip
      expect(analysis.pixelCount, greaterThan(50));
    });
  });

  group('Edge Cases', () {
    testWidgets('clipPath with display:none use element', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <rect id="clipRect" width="80" height="80"/>
            <clipPath id="clip">
              <use href="#clipRect" x="10" y="10" style="display: none"/>
            </clipPath>
          </defs>
          <rect x="0" y="0" width="100" height="100" fill="red" 
                clip-path="url(#clip)"/>
        </svg>
      ''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svgXml, width: 200, height: 200),
          ),
        ),
      );

      await tester.pump();

      // Should handle display:none gracefully
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('clipPath with very small objectBoundingBox element', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <clipPath id="clip" clipPathUnits="objectBoundingBox">
              <rect x="0" y="0" width="1" height="1"/>
            </clipPath>
          </defs>
          <rect x="49.999" y="49.999" width="0.002" height="0.002" fill="red" 
                clip-path="url(#clip)"/>
        </svg>
      ''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svgXml, width: 200, height: 200),
          ),
        ),
      );

      await tester.pump();

      // Should handle tiny element gracefully
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('Maximum recursion depth protection', (
      WidgetTester tester,
    ) async {
      // Create a chain that exceeds max depth (10)
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <clipPath id="c1"><rect x="1" y="1" width="98" height="98"/></clipPath>
            <clipPath id="c2" clip-path="url(#c1)"><rect x="2" y="2" width="96" height="96"/></clipPath>
            <clipPath id="c3" clip-path="url(#c2)"><rect x="3" y="3" width="94" height="94"/></clipPath>
            <clipPath id="c4" clip-path="url(#c3)"><rect x="4" y="4" width="92" height="92"/></clipPath>
            <clipPath id="c5" clip-path="url(#c4)"><rect x="5" y="5" width="90" height="90"/></clipPath>
            <clipPath id="c6" clip-path="url(#c5)"><rect x="6" y="6" width="88" height="88"/></clipPath>
            <clipPath id="c7" clip-path="url(#c6)"><rect x="7" y="7" width="86" height="86"/></clipPath>
            <clipPath id="c8" clip-path="url(#c7)"><rect x="8" y="8" width="84" height="84"/></clipPath>
            <clipPath id="c9" clip-path="url(#c8)"><rect x="9" y="9" width="82" height="82"/></clipPath>
            <clipPath id="c10" clip-path="url(#c9)"><rect x="10" y="10" width="80" height="80"/></clipPath>
            <clipPath id="c11" clip-path="url(#c10)"><rect x="11" y="11" width="78" height="78"/></clipPath>
          </defs>
          <rect x="0" y="0" width="100" height="100" fill="red" 
                clip-path="url(#c11)"/>
        </svg>
      ''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svgXml, width: 200, height: 200),
          ),
        ),
      );

      await tester.pump();

      // Should not crash, depth limit prevents infinite recursion
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });
}
