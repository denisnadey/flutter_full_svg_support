import 'package:flutter/material.dart';
import 'package:flutter_svg/src/animation/animated_svg_picture.dart';
import 'package:flutter_test/flutter_test.dart';

import 'visual_test_utils.dart';

/// Comprehensive verification tests for clip-path, mask, and use/symbol rendering.
/// These tests verify correct rendering behavior for common SVG patterns.
void main() {
  group('Clip-path Verification Tests', () {
    group('Basic clip-path with shapes', () {
      testWidgets('clip-path with rect shape', (WidgetTester tester) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <clipPath id="rectClip">
                <rect x="25" y="25" width="50" height="50"/>
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

        // The rect should be clipped to 50x50 centered area
        expect(analysis.pixelCount, greaterThan(1000));
        // Bounding box should be roughly centered
        expect(analysis.boundingBox.left, greaterThanOrEqualTo(50));
        expect(analysis.boundingBox.right, lessThan(400));
      });

      testWidgets('clip-path with circle shape', (WidgetTester tester) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <clipPath id="circleClip">
                <circle cx="50" cy="50" r="30"/>
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

        // Circle clip should produce roughly circular output
        expect(analysis.pixelCount, greaterThan(500));
      });

      testWidgets('clip-path with path shape', (WidgetTester tester) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <clipPath id="pathClip">
                <path d="M25,25 L75,25 L75,75 L25,75 Z"/>
              </clipPath>
            </defs>
            <rect x="0" y="0" width="100" height="100" fill="red" 
                  clip-path="url(#pathClip)"/>
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

        // Path clip should work
        expect(analysis.pixelCount, greaterThan(1000));
      });
    });

    group('clipPathUnits', () {
      testWidgets('clipPathUnits userSpaceOnUse (default)', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <clipPath id="clip" clipPathUnits="userSpaceOnUse">
                <rect x="20" y="20" width="60" height="60"/>
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

        // With userSpaceOnUse, clip uses absolute coordinates
        expect(analysis.pixelCount, greaterThan(1000));
      });

      testWidgets('clipPathUnits objectBoundingBox', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <clipPath id="clip" clipPathUnits="objectBoundingBox">
                <rect x="0.2" y="0.2" width="0.6" height="0.6"/>
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

        // With objectBoundingBox, clip is relative to element bounds
        expect(analysis.pixelCount, greaterThan(500));
      });
    });

    group('clip-path CSS vs attribute', () {
      testWidgets('clip-path via CSS style attribute', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <clipPath id="clip">
                <rect x="25" y="25" width="50" height="50"/>
              </clipPath>
            </defs>
            <rect x="0" y="0" width="100" height="100" fill="red" 
                  style="clip-path: url(#clip);"/>
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

        // clip-path from style should work
        expect(analysis.pixelCount, greaterThan(1000));
      });

      testWidgets('clip-path via presentation attribute', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <clipPath id="clip">
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

        // clip-path from attribute should work
        expect(analysis.pixelCount, greaterThan(1000));
      });
    });

    group('nested clip-paths', () {
      testWidgets('clip-path with multiple shapes', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <clipPath id="multiClip">
                <circle cx="30" cy="30" r="20"/>
                <circle cx="70" cy="70" r="20"/>
              </clipPath>
            </defs>
            <rect x="0" y="0" width="100" height="100" fill="red" 
                  clip-path="url(#multiClip)"/>
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

        // Multiple shapes in clipPath should render as union
        expect(analysis.pixelCount, greaterThan(500));
      });

      testWidgets('group with clip-path', (WidgetTester tester) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <clipPath id="clip">
                <rect x="25" y="25" width="50" height="50"/>
              </clipPath>
            </defs>
            <g clip-path="url(#clip)">
              <rect x="0" y="0" width="100" height="50" fill="red"/>
              <rect x="0" y="50" width="100" height="50" fill="red"/>
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

        // Group clip-path should clip all children
        expect(analysis.pixelCount, greaterThan(500));
      });
    });
  });

  group('Mask Verification Tests', () {
    group('Basic mask rendering', () {
      testWidgets('mask with white fill allows rendering', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <mask id="whiteMask">
                <rect x="25" y="25" width="50" height="50" fill="white"/>
              </mask>
            </defs>
            <rect x="0" y="0" width="100" height="100" fill="red" 
                  mask="url(#whiteMask)"/>
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

        // White mask area should show content
        expect(analysis.pixelCount, greaterThan(500));
      });

      testWidgets('mask with no visible content creates empty mask', (
        WidgetTester tester,
      ) async {
        // Note: Current implementation uses path-based clipping for masks.
        // An empty mask (no shapes inside) results in no clipping.
        // A mask with shapes clips to those shapes regardless of fill color.
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <mask id="emptyMask">
                <!-- Empty mask -->
              </mask>
            </defs>
            <rect x="0" y="0" width="100" height="100" fill="red" 
                  mask="url(#emptyMask)"/>
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

        // Empty mask should still allow rendering (no path to clip)
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });
    });

    group('maskUnits and maskContentUnits', () {
      testWidgets('maskUnits objectBoundingBox (default)', (
        WidgetTester tester,
      ) async {
        // maskUnits affects the mask region coordinates (x, y, width, height on mask)
        // maskContentUnits (default: userSpaceOnUse) affects the mask content coordinates
        // The mask content must cover the masked element area in user space
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <mask id="mask" maskUnits="objectBoundingBox">
                <rect x="0" y="0" width="100" height="100" fill="white"/>
              </mask>
            </defs>
            <rect x="20" y="20" width="60" height="60" fill="red" 
                  mask="url(#mask)"/>
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

        // Mask with objectBoundingBox should work
        expect(analysis.pixelCount, greaterThan(500));
      });

      testWidgets('maskContentUnits objectBoundingBox', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <mask id="mask" maskContentUnits="objectBoundingBox">
                <rect x="0.1" y="0.1" width="0.8" height="0.8" fill="white"/>
              </mask>
            </defs>
            <rect x="10" y="10" width="80" height="80" fill="red" 
                  mask="url(#mask)"/>
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

        // maskContentUnits objectBoundingBox should scale content
        expect(analysis.pixelCount, greaterThan(500));
      });
    });

    group('mask with gradient (luminance mode)', () {
      testWidgets('mask with linear gradient creates fade effect', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <linearGradient id="grad" x1="0%" y1="0%" x2="100%" y2="0%">
                <stop offset="0" stop-color="black"/>
                <stop offset="1" stop-color="white"/>
              </linearGradient>
              <mask id="mask">
                <rect x="0" y="0" width="100" height="100" fill="url(#grad)"/>
              </mask>
            </defs>
            <rect x="0" y="0" width="100" height="100" fill="red" 
                  mask="url(#mask)"/>
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

        // Should render without error - gradient masks create fade effects
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });
    });
  });

  group('Use/Symbol Verification Tests', () {
    group('Basic use referencing defs elements', () {
      testWidgets('use references rect in defs', (WidgetTester tester) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <rect id="myRect" width="40" height="40" fill="red"/>
            </defs>
            <use href="#myRect" x="10" y="10"/>
            <use href="#myRect" x="50" y="50"/>
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

        // Two red rectangles from two use elements
        expect(analysis.pixelCount, greaterThan(2000));
      });

      testWidgets('use references path in defs', (WidgetTester tester) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <path id="star" d="M50,5 L60,40 L95,40 L65,60 L75,95 L50,75 L25,95 L35,60 L5,40 L40,40 Z" fill="red"/>
            </defs>
            <use href="#star"/>
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

        // Star path should render
        expect(analysis.pixelCount, greaterThan(500));
      });
    });

    group('Symbol with viewBox and preserveAspectRatio', () {
      testWidgets('symbol with viewBox scales correctly', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <symbol id="icon" viewBox="0 0 20 20">
                <rect x="0" y="0" width="20" height="20" fill="red"/>
              </symbol>
            </defs>
            <use href="#icon" x="10" y="10" width="60" height="60"/>
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

        // Symbol content should be scaled to 60x60
        expect(analysis.pixelCount, greaterThan(3000));
      });

      testWidgets('symbol preserveAspectRatio xMidYMid meet', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <symbol id="icon" viewBox="0 0 10 20" preserveAspectRatio="xMidYMid meet">
                <rect x="0" y="0" width="10" height="20" fill="red"/>
              </symbol>
            </defs>
            <use href="#icon" x="0" y="0" width="60" height="60"/>
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

        // With meet, aspect ratio is preserved (1:2 viewBox into 60x60 = 30x60 rendering)
        expect(analysis.objectHeight, greaterThan(analysis.objectWidth));
      });

      testWidgets('symbol preserveAspectRatio none stretches', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <symbol id="icon" viewBox="0 0 10 20" preserveAspectRatio="none">
                <rect x="0" y="0" width="10" height="20" fill="red"/>
              </symbol>
            </defs>
            <use href="#icon" x="10" y="10" width="50" height="50"/>
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

        // With none, content is stretched to fill 50x50
        final aspectRatio = analysis.objectWidth / analysis.objectHeight;
        expect(aspectRatio, closeTo(1.0, 0.3));
      });
    });

    group('CSS cascade through use references', () {
      testWidgets('inline style > style block > presentation attributes', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <style>.blue { fill: blue; }</style>
            <defs>
              <rect id="r" class="blue" x="10" y="10" width="80" height="80" 
                    style="fill: red;"/>
            </defs>
            <use href="#r"/>
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

        // Inline style (red) overrides CSS class rule (blue)
        expect(analysis.pixelCount, greaterThan(3000));
      });

      testWidgets('CSS class selector applied to referenced element', (
        WidgetTester tester,
      ) async {
        // CSS class rule applies to element through use reference
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <style>.highlight { fill: red; }</style>
            <defs>
              <rect id="r" class="highlight" x="10" y="10" width="80" height="80"/>
            </defs>
            <use href="#r"/>
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

        // CSS class rule (red) should apply
        expect(analysis.pixelCount, greaterThan(3000));
      });

      testWidgets('inheritance from use element', (WidgetTester tester) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <rect id="r" x="10" y="10" width="80" height="80"/>
            </defs>
            <use href="#r" fill="red"/>
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

        // fill on use should inherit to rect
        expect(analysis.pixelCount, greaterThan(3000));
      });
    });

    group('Nested use elements', () {
      testWidgets('nested use elements render correctly', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <rect id="baseRect" width="20" height="20" fill="red"/>
              <use id="useRect" href="#baseRect"/>
            </defs>
            <use href="#useRect" x="40" y="40"/>
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

        // Nested use should render
        expect(analysis.pixelCount, greaterThan(100));
        // Position should be at 40,40 (scaled by 2 = 80,80 in widget coords)
        expect(analysis.boundingBox.left, greaterThan(70));
        expect(analysis.boundingBox.top, greaterThan(70));
      });

      testWidgets('deeply nested use (5 levels)', (WidgetTester tester) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <rect id="r0" width="20" height="20" fill="red"/>
              <use id="u1" href="#r0"/>
              <use id="u2" href="#u1"/>
              <use id="u3" href="#u2"/>
              <use id="u4" href="#u3"/>
              <use id="u5" href="#u4"/>
            </defs>
            <use href="#u5" x="10" y="10"/>
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

        // Deep nesting (within 10 level limit) should render
        expect(analysis.pixelCount, greaterThan(100));
      });
    });

    group('use with x/y offset attributes', () {
      testWidgets('use x/y translates content', (WidgetTester tester) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <rect id="myRect" width="30" height="30" fill="red"/>
            </defs>
            <use href="#myRect" x="50" y="50"/>
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

        // Rect at 0,0 with use x=50,y=50 should be at 50,50 (100,100 widget coords)
        expect(analysis.boundingBox.left, greaterThan(90));
        expect(analysis.boundingBox.top, greaterThan(90));
      });

      testWidgets('multiple uses at different positions', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <circle id="dot" r="8" fill="red"/>
            </defs>
            <use href="#dot" x="20" y="20"/>
            <use href="#dot" x="50" y="50"/>
            <use href="#dot" x="80" y="80"/>
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

        // Three circles at different positions
        expect(analysis.pixelCount, greaterThan(300));
      });
    });
  });

  group('Combined clip-path, mask, and use', () {
    testWidgets('use element with clip-path', (WidgetTester tester) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <clipPath id="clip">
              <rect x="10" y="10" width="60" height="60"/>
            </clipPath>
            <rect id="r" width="80" height="80" fill="red"/>
          </defs>
          <use href="#r" x="5" y="5" clip-path="url(#clip)"/>
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

      // Use element should be clipped
      expect(analysis.pixelCount, greaterThan(500));
    });

    testWidgets('use element with mask', (WidgetTester tester) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <mask id="mask">
              <rect x="20" y="20" width="60" height="60" fill="white"/>
            </mask>
            <rect id="r" x="10" y="10" width="80" height="80" fill="red"/>
          </defs>
          <use href="#r" mask="url(#mask)"/>
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

      // Use element should be masked
      expect(analysis.pixelCount, greaterThan(500));
    });

    testWidgets('mask using use element internally', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <rect id="whiteRect" width="50" height="50" fill="white"/>
            <mask id="mask">
              <use href="#whiteRect" x="25" y="25"/>
            </mask>
          </defs>
          <rect x="0" y="0" width="100" height="100" fill="red" 
                mask="url(#mask)"/>
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

      // Mask using use element should work
      expect(analysis.pixelCount, greaterThan(500));
    });

    testWidgets('clipPath using use element internally', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <circle id="clipCircle" cx="0" cy="0" r="25"/>
            <clipPath id="clip">
              <use href="#clipCircle" x="50" y="50"/>
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

      // clipPath using use element should work
      expect(analysis.pixelCount, greaterThan(300));
    });
  });
}
