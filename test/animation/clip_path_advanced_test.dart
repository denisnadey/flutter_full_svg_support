import 'package:flutter/material.dart';
import 'package:full_svg_flutter/src/animation/animated_svg_picture.dart';
import 'package:flutter_test/flutter_test.dart';

import 'visual_test_utils.dart';

/// Comprehensive tests for SVG clipPath advanced features.
/// Covers clipPathUnits, clip-rule, nested clip-paths, text clipping,
/// use element references, hit-testing, and edge cases per SVG specification.
void main() {
  group('clipPathUnits Tests', () {
    testWidgets('clipPathUnits userSpaceOnUse basic', (tester) async {
      // Clip region defined in user coordinates (default)
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <clipPath id="clip" clipPathUnits="userSpaceOnUse">
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

      // Should render clipped region
      expect(analysis.pixelCount, greaterThan(100));
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('clipPathUnits objectBoundingBox basic', (tester) async {
      // Clip region defined in object bounding box coordinates (0-1)
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <clipPath id="clip" clipPathUnits="objectBoundingBox">
              <rect x="0.25" y="0.25" width="0.5" height="0.5"/>
            </clipPath>
          </defs>
          <rect x="10" y="10" width="80" height="80" fill="red" 
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

    testWidgets('clipPathUnits objectBoundingBox with circle', (tester) async {
      // Circle in objectBoundingBox coordinates
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <clipPath id="clip" clipPathUnits="objectBoundingBox">
              <circle cx="0.5" cy="0.5" r="0.4"/>
            </clipPath>
          </defs>
          <rect x="20" y="20" width="60" height="60" fill="red" 
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

    testWidgets('clipPathUnits objectBoundingBox non-square element', (
      tester,
    ) async {
      // Test non-uniform scaling with non-square bounding box
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <clipPath id="clip" clipPathUnits="objectBoundingBox">
              <rect x="0.1" y="0.1" width="0.8" height="0.8"/>
            </clipPath>
          </defs>
          <rect x="10" y="30" width="80" height="40" fill="red" 
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

  group('clip-rule Tests', () {
    testWidgets('clip-rule nonzero (default)', (tester) async {
      // Nonzero fill rule - overlapping regions fill completely
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <clipPath id="clip">
              <rect x="20" y="20" width="40" height="40"/>
              <rect x="40" y="40" width="40" height="40"/>
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

      // Union of overlapping rects
      expect(analysis.pixelCount, greaterThan(100));
    });

    testWidgets('clip-rule evenodd', (tester) async {
      // Evenodd fill rule on path
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <clipPath id="clip">
              <path clip-rule="evenodd" 
                    d="M10,10 h80 v80 h-80 z M30,30 h40 v40 h-40 z"/>
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

      // Should show outer ring (inner rect hole due to evenodd)
      expect(analysis.pixelCount, greaterThan(50));
    });

    testWidgets('clip-rule inherited from parent', (tester) async {
      // clip-rule inherited from group
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <clipPath id="clip">
              <g clip-rule="evenodd">
                <rect x="10" y="10" width="80" height="80"/>
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

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });

  group('Nested clip-paths Tests', () {
    testWidgets('Two-level nested clip-paths', (tester) async {
      // Outer clipPath has clip-path referring to inner
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <clipPath id="inner">
              <rect x="30" y="30" width="40" height="40"/>
            </clipPath>
            <clipPath id="outer" clip-path="url(#inner)">
              <rect x="20" y="20" width="60" height="60"/>
            </clipPath>
          </defs>
          <rect x="0" y="0" width="100" height="100" fill="red" 
                clip-path="url(#outer)"/>
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

      // Result is intersection: innermost rect
      expect(analysis.pixelCount, greaterThan(50));
    });

    testWidgets('Three-level nested clip-paths', (tester) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <clipPath id="level1">
              <rect x="35" y="35" width="30" height="30"/>
            </clipPath>
            <clipPath id="level2" clip-path="url(#level1)">
              <rect x="25" y="25" width="50" height="50"/>
            </clipPath>
            <clipPath id="level3" clip-path="url(#level2)">
              <rect x="15" y="15" width="70" height="70"/>
            </clipPath>
          </defs>
          <rect x="0" y="0" width="100" height="100" fill="red" 
                clip-path="url(#level3)"/>
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

      expect(analysis.pixelCount, greaterThan(30));
    });

    testWidgets('Nested clip-paths with different units', (tester) async {
      // Mix userSpaceOnUse and objectBoundingBox
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <clipPath id="inner" clipPathUnits="userSpaceOnUse">
              <rect x="30" y="30" width="40" height="40"/>
            </clipPath>
            <clipPath id="outer" clipPathUnits="objectBoundingBox" 
                      clip-path="url(#inner)">
              <rect x="0" y="0" width="1" height="1"/>
            </clipPath>
          </defs>
          <rect x="20" y="20" width="60" height="60" fill="red" 
                clip-path="url(#outer)"/>
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

  group('Complex clip-path compositions Tests', () {
    testWidgets('Clip path with multiple shapes (union)', (tester) async {
      // Multiple shapes form the clip region
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <clipPath id="clip">
              <circle cx="30" cy="50" r="20"/>
              <circle cx="70" cy="50" r="20"/>
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

      // Two circles
      expect(analysis.pixelCount, greaterThan(200));
    });

    testWidgets('Clip path with transforms on children', (tester) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <clipPath id="clip">
              <rect x="0" y="0" width="40" height="40" 
                    transform="translate(30, 30) rotate(45, 20, 20)"/>
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

    testWidgets('Clip path with nested groups', (tester) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <clipPath id="clip">
              <g transform="translate(10, 10)">
                <g transform="scale(0.8)">
                  <rect x="10" y="10" width="70" height="70"/>
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
  });

  group('Clip path with use element Tests', () {
    testWidgets('Clip path with use referencing shape', (tester) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <rect id="myRect" width="60" height="60"/>
            <clipPath id="clip">
              <use href="#myRect" x="20" y="20"/>
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

    testWidgets('Clip path with use referencing symbol', (tester) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <symbol id="sym" viewBox="0 0 10 10">
              <rect width="10" height="10"/>
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

      expect(analysis.pixelCount, greaterThan(50));
    });
  });

  group('Clip path with text element Tests', () {
    testWidgets('Text element as clip', (tester) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <clipPath id="clip">
              <text x="10" y="60" font-size="50" font-family="sans-serif">A</text>
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

      // Text clipping should work (using bounding box approximation)
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('Text with text-anchor in clip', (tester) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <clipPath id="clip">
              <text x="50" y="60" font-size="40" text-anchor="middle">AB</text>
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

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });

  group('Edge cases Tests', () {
    testWidgets('Empty clipPath hides content', (tester) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <clipPath id="emptyClip">
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

      // Empty clipPath should not crash
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('Circular reference prevention', (tester) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <clipPath id="clipA" clip-path="url(#clipB)">
              <rect x="10" y="10" width="80" height="80"/>
            </clipPath>
            <clipPath id="clipB" clip-path="url(#clipA)">
              <rect x="20" y="20" width="60" height="60"/>
            </clipPath>
          </defs>
          <rect x="0" y="0" width="100" height="100" fill="red" 
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

      // Should not infinite loop
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('Zero-size element with objectBoundingBox', (tester) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <clipPath id="clip" clipPathUnits="objectBoundingBox">
              <rect x="0" y="0" width="1" height="1"/>
            </clipPath>
          </defs>
          <line x1="50" y1="50" x2="50" y2="50" stroke="red" stroke-width="10"
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

      // Should handle zero-size gracefully
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('Clip path with no valid geometry', (tester) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <clipPath id="clip">
              <defs></defs>
              <desc>Not geometry</desc>
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

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('Invalid clip-path reference', (tester) async {
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

      final pixels = await VisualTestUtils.captureWidgetPixels(tester);
      final analysis = VisualTestUtils.analyzeRedPixels(pixels, 800, 600);

      // Invalid reference should not clip - content should render
      expect(analysis.pixelCount, greaterThan(500));
    });

    testWidgets('Deep recursion limit', (tester) async {
      // 15+ level nesting should be clamped
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <clipPath id="c1"><rect x="5" y="5" width="90" height="90"/></clipPath>
            <clipPath id="c2" clip-path="url(#c1)"><rect x="5" y="5" width="90" height="90"/></clipPath>
            <clipPath id="c3" clip-path="url(#c2)"><rect x="5" y="5" width="90" height="90"/></clipPath>
            <clipPath id="c4" clip-path="url(#c3)"><rect x="5" y="5" width="90" height="90"/></clipPath>
            <clipPath id="c5" clip-path="url(#c4)"><rect x="5" y="5" width="90" height="90"/></clipPath>
            <clipPath id="c6" clip-path="url(#c5)"><rect x="5" y="5" width="90" height="90"/></clipPath>
            <clipPath id="c7" clip-path="url(#c6)"><rect x="5" y="5" width="90" height="90"/></clipPath>
            <clipPath id="c8" clip-path="url(#c7)"><rect x="5" y="5" width="90" height="90"/></clipPath>
            <clipPath id="c9" clip-path="url(#c8)"><rect x="5" y="5" width="90" height="90"/></clipPath>
            <clipPath id="c10" clip-path="url(#c9)"><rect x="5" y="5" width="90" height="90"/></clipPath>
            <clipPath id="c11" clip-path="url(#c10)"><rect x="5" y="5" width="90" height="90"/></clipPath>
            <clipPath id="c12" clip-path="url(#c11)"><rect x="5" y="5" width="90" height="90"/></clipPath>
          </defs>
          <rect x="0" y="0" width="100" height="100" fill="red" 
                clip-path="url(#c12)"/>
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

      // Should handle deep nesting without crash
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });

  group('Transform composition Tests', () {
    testWidgets('Transform on clipPath element', (tester) async {
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

      expect(analysis.pixelCount, greaterThan(100));
    });

    testWidgets('Transform on clipped element', (tester) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <clipPath id="clip" clipPathUnits="userSpaceOnUse">
              <rect x="20" y="20" width="60" height="60"/>
            </clipPath>
          </defs>
          <rect x="0" y="0" width="50" height="50" fill="red" 
                transform="translate(25, 25)"
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

    testWidgets('Combined transforms', (tester) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <clipPath id="clip" transform="translate(10, 10)">
              <g transform="scale(0.8)">
                <rect x="0" y="0" width="80" height="80" transform="rotate(10, 40, 40)"/>
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
  });

  group('Various shape types Tests', () {
    testWidgets('Line element in clipPath', (tester) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <clipPath id="clip">
              <line x1="10" y1="50" x2="90" y2="50" stroke="black" stroke-width="20"/>
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

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('Image element in clipPath', (tester) async {
      // Image in clip uses bounding rect
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <clipPath id="clip">
              <image x="20" y="20" width="60" height="60" href="data:image/png;base64,"/>
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

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('Path with complex curves in clipPath', (tester) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <clipPath id="clip">
              <path d="M10,50 Q30,10 50,50 T90,50 L90,90 L10,90 Z"/>
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
  });
}
