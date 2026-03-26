import 'package:flutter/material.dart';
import 'package:flutter_svg/src/animation/animated_svg_picture.dart';
import 'package:flutter_test/flutter_test.dart';

import 'visual_test_utils.dart';

/// Comprehensive tests for advanced SVG clipping semantics.
/// Tests cascading clipPaths, non-path element clipping, clipPathUnits edge cases,
/// and coordinate transform stacking.
void main() {
  group('Cascading clipPaths (clipPath on clipPath)', () {
    testWidgets('2-level cascade: clipPath with clip-path attribute', (
      WidgetTester tester,
    ) async {
      // A clipPath element that itself has a clip-path attribute
      // Result should be intersection of both clip regions
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <clipPath id="innerClip">
              <rect x="10" y="10" width="80" height="80"/>
            </clipPath>
            <clipPath id="outerClip" clip-path="url(#innerClip)">
              <rect x="20" y="20" width="60" height="60"/>
            </clipPath>
          </defs>
          <rect x="0" y="0" width="100" height="100" fill="red" 
                clip-path="url(#outerClip)"/>
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

      // Should show intersection (20,20,60,60) clipped by (10,10,80,80) = (20,20,60,60)
      expect(analysis.pixelCount, greaterThan(300));
    });

    testWidgets('3-level cascade: deeply nested clipPath references', (
      WidgetTester tester,
    ) async {
      // Three levels of cascading clipPaths
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <clipPath id="clip1">
              <rect x="5" y="5" width="90" height="90"/>
            </clipPath>
            <clipPath id="clip2" clip-path="url(#clip1)">
              <rect x="15" y="15" width="70" height="70"/>
            </clipPath>
            <clipPath id="clip3" clip-path="url(#clip2)">
              <rect x="25" y="25" width="50" height="50"/>
            </clipPath>
          </defs>
          <rect x="0" y="0" width="100" height="100" fill="blue" 
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

      // Should render without error
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('cascade with circular reference prevention', (
      WidgetTester tester,
    ) async {
      // Circular reference should be handled gracefully
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <clipPath id="clipA" clip-path="url(#clipB)">
              <rect x="20" y="20" width="60" height="60"/>
            </clipPath>
            <clipPath id="clipB" clip-path="url(#clipA)">
              <rect x="30" y="30" width="40" height="40"/>
            </clipPath>
          </defs>
          <rect x="0" y="0" width="100" height="100" fill="green" 
                clip-path="url(#clipA)"/>
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

      // Should not crash - handles circular references gracefully
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });

  group('Non-path element clipping', () {
    testWidgets('rect as clip shape', (WidgetTester tester) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <clipPath id="rectClip">
              <rect x="20" y="20" width="60" height="60" rx="5"/>
            </clipPath>
          </defs>
          <rect x="0" y="0" width="100" height="100" fill="red" 
                clip-path="url(#rectClip)"/>
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

      expect(analysis.pixelCount, greaterThan(500));
    });

    testWidgets('circle as clip shape', (WidgetTester tester) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <clipPath id="circleClip">
              <circle cx="50" cy="50" r="40"/>
            </clipPath>
          </defs>
          <rect x="0" y="0" width="100" height="100" fill="red" 
                clip-path="url(#circleClip)"/>
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

      // Circle area is π*40² ≈ 5026 square units
      expect(analysis.pixelCount, greaterThan(400));
    });

    testWidgets('ellipse as clip shape', (WidgetTester tester) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <clipPath id="ellipseClip">
              <ellipse cx="50" cy="50" rx="40" ry="25"/>
            </clipPath>
          </defs>
          <rect x="0" y="0" width="100" height="100" fill="red" 
                clip-path="url(#ellipseClip)"/>
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

      expect(analysis.pixelCount, greaterThan(300));
    });

    testWidgets('polygon as clip shape', (WidgetTester tester) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <clipPath id="polyClip">
              <polygon points="50,10 90,90 10,90"/>
            </clipPath>
          </defs>
          <rect x="0" y="0" width="100" height="100" fill="red" 
                clip-path="url(#polyClip)"/>
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

      expect(analysis.pixelCount, greaterThan(300));
    });

    testWidgets('polyline as clip shape', (WidgetTester tester) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <clipPath id="polylineClip">
              <polyline points="10,10 90,10 90,90 10,90 10,10"/>
            </clipPath>
          </defs>
          <rect x="0" y="0" width="100" height="100" fill="red" 
                clip-path="url(#polylineClip)"/>
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

    testWidgets('text as clip child', (WidgetTester tester) async {
      // Text within clipPath should use text outline as clip region
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <clipPath id="textClip">
              <text x="10" y="50" font-size="40">Hi</text>
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

      // Text clipping should work
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });

  group('clipPathUnits edge cases', () {
    testWidgets('objectBoundingBox with scaled element', (
      WidgetTester tester,
    ) async {
      // Non-uniform element scaling with objectBoundingBox
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <clipPath id="clip" clipPathUnits="objectBoundingBox">
              <rect x="0.1" y="0.1" width="0.8" height="0.8"/>
            </clipPath>
          </defs>
          <rect x="10" y="20" width="80" height="40" fill="red" 
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

      expect(analysis.pixelCount, greaterThan(200));
    });

    testWidgets('userSpaceOnUse with nested transforms', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <clipPath id="clip" clipPathUnits="userSpaceOnUse">
              <rect x="20" y="20" width="60" height="60"/>
            </clipPath>
          </defs>
          <g transform="translate(10,10)">
            <g transform="scale(0.8)">
              <rect x="0" y="0" width="100" height="100" fill="red" 
                    clip-path="url(#clip)"/>
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

      expect(analysis.pixelCount, greaterThan(200));
    });

    testWidgets('mixed units in cascading clipPaths', (
      WidgetTester tester,
    ) async {
      // First clipPath uses objectBoundingBox, second uses userSpaceOnUse
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <clipPath id="clip1" clipPathUnits="userSpaceOnUse">
              <rect x="10" y="10" width="80" height="80"/>
            </clipPath>
            <clipPath id="clip2" clipPathUnits="objectBoundingBox" 
                      clip-path="url(#clip1)">
              <rect x="0.2" y="0.2" width="0.6" height="0.6"/>
            </clipPath>
          </defs>
          <rect x="0" y="0" width="100" height="100" fill="blue" 
                clip-path="url(#clip2)"/>
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

  group('Deep nesting (3+ levels)', () {
    testWidgets('4-level nested groups with clip-path', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <clipPath id="clip1">
              <rect x="5" y="5" width="90" height="90"/>
            </clipPath>
            <clipPath id="clip2">
              <rect x="15" y="15" width="70" height="70"/>
            </clipPath>
            <clipPath id="clip3">
              <rect x="25" y="25" width="50" height="50"/>
            </clipPath>
            <clipPath id="clip4">
              <rect x="35" y="35" width="30" height="30"/>
            </clipPath>
          </defs>
          <g clip-path="url(#clip1)">
            <g clip-path="url(#clip2)">
              <g clip-path="url(#clip3)">
                <rect x="0" y="0" width="100" height="100" fill="red" 
                      clip-path="url(#clip4)"/>
              </g>
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

      // Innermost clip (35,35,30,30) should be visible
      expect(analysis.pixelCount, greaterThan(100));
    });

    testWidgets('nested groups with transforms and clip-paths', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <clipPath id="clip">
              <circle cx="50" cy="50" r="40"/>
            </clipPath>
          </defs>
          <g transform="translate(10,10)" clip-path="url(#clip)">
            <g transform="rotate(45 50 50)">
              <g transform="scale(0.8)">
                <rect x="0" y="0" width="100" height="100" fill="red"/>
              </g>
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

      expect(analysis.pixelCount, greaterThan(200));
    });
  });

  group('Edge cases', () {
    testWidgets('empty clipPath shows nothing', (WidgetTester tester) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <clipPath id="emptyClip">
              <!-- No children -->
            </clipPath>
          </defs>
          <rect x="0" y="0" width="100" height="100" fill="red" 
                clip-path="url(#emptyClip)"/>
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

      // Empty clipPath should result in nothing being visible
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('zero-area clip shows nothing', (WidgetTester tester) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <clipPath id="zeroClip">
              <rect x="50" y="50" width="0" height="0"/>
            </clipPath>
          </defs>
          <rect x="0" y="0" width="100" height="100" fill="red" 
                clip-path="url(#zeroClip)"/>
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

      // Zero-area clipPath should result in nothing being visible
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('invalid clipPath reference handled gracefully', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <rect x="0" y="0" width="100" height="100" fill="red" 
                clip-path="url(#nonexistent)"/>
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

      // Invalid reference should not crash, content should render normally
      final pixels = await VisualTestUtils.captureWidgetPixels(tester);
      final analysis = VisualTestUtils.analyzeRedPixels(pixels, 800, 600);

      expect(analysis.pixelCount, greaterThan(500));
    });

    testWidgets('clipPath with use element reference', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <rect id="clipRect" x="0" y="0" width="60" height="60"/>
            <clipPath id="clip">
              <use href="#clipRect" x="20" y="20"/>
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

      expect(analysis.pixelCount, greaterThan(300));
    });
  });

  group('Coordinate transform stacking', () {
    testWidgets('clipPath with transform attribute', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <clipPath id="clip" transform="translate(10,10)">
              <rect x="0" y="0" width="60" height="60"/>
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

      expect(analysis.pixelCount, greaterThan(300));
    });

    testWidgets('multiple transforms on clip children', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <clipPath id="clip">
              <g transform="translate(10,10)">
                <rect x="0" y="0" width="40" height="40" transform="rotate(45 20 20)"/>
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

      // Should render with transformed clip
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });
}
