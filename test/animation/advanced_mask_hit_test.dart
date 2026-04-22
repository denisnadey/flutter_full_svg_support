import 'package:flutter/material.dart';
import 'package:full_svg_flutter/src/animation/animated_svg_picture.dart';
import 'package:flutter_test/flutter_test.dart';

import 'visual_test_utils.dart';

/// Comprehensive tests for SVG mask edge cases and combinations.
///
/// Tests cover:
/// - Circular mask references (should be handled gracefully)
/// - Mask with text content
/// - Mask with multiple shapes
/// - Mask on SVG with non-uniform viewBox
/// - Deeply nested mask structure
/// - Alpha mask with gradient opacity
/// - Mask with rotated content
/// - Mask with scaled content
void main() {
  group('Mask Edge Cases - Circular References', () {
    testWidgets('circular mask reference handled gracefully (no crash)', (
      WidgetTester tester,
    ) async {
      // Circular reference should not cause infinite loop
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <mask id="maskA">
              <rect x="0" y="0" width="100" height="100" fill="white"
                    mask="url(#maskB)"/>
            </mask>
            <mask id="maskB">
              <rect x="0" y="0" width="100" height="100" fill="white"
                    mask="url(#maskA)"/>
            </mask>
          </defs>
          <rect x="0" y="0" width="100" height="100" fill="red" 
                mask="url(#maskA)"/>
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

      // Should render without hanging/crashing
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('self-referencing mask handled gracefully', (
      WidgetTester tester,
    ) async {
      // Self-reference should not cause infinite loop
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <mask id="selfMask">
              <rect x="0" y="0" width="100" height="100" fill="white"
                    mask="url(#selfMask)"/>
            </mask>
          </defs>
          <rect x="0" y="0" width="100" height="100" fill="red" 
                mask="url(#selfMask)"/>
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

      // Should render without hanging/crashing
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });

  group('Mask Edge Cases - Text Content', () {
    testWidgets('mask with text content renders correctly', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <mask id="textMask">
              <text x="10" y="50" font-size="40" fill="white">AB</text>
            </mask>
          </defs>
          <rect x="0" y="0" width="100" height="100" fill="red" 
                mask="url(#textMask)"/>
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

      // Text should create visible mask region
      final pixels = await VisualTestUtils.captureWidgetPixels(tester);
      final analysis = VisualTestUtils.analyzeRedPixels(pixels, 800, 600);

      // Should have some red pixels visible through text mask
      expect(analysis.pixelCount, greaterThan(10));
    });

    testWidgets('mask with tspan elements', (WidgetTester tester) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <mask id="tspanMask">
              <text x="10" y="50" font-size="20" fill="white">
                <tspan>A</tspan>
                <tspan x="40">B</tspan>
              </text>
            </mask>
          </defs>
          <rect x="0" y="0" width="100" height="100" fill="red" 
                mask="url(#tspanMask)"/>
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

      // Should render without errors
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });

  group('Mask Edge Cases - Multiple Shapes', () {
    testWidgets('mask with multiple circles', (WidgetTester tester) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <mask id="multiMask">
              <circle cx="25" cy="50" r="20" fill="white"/>
              <circle cx="75" cy="50" r="20" fill="white"/>
            </mask>
          </defs>
          <rect x="0" y="0" width="100" height="100" fill="red" 
                mask="url(#multiMask)"/>
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

      // Should show two circular regions
      expect(analysis.pixelCount, greaterThan(50));
    });

    testWidgets('mask with overlapping shapes', (WidgetTester tester) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <mask id="overlapMask">
              <circle cx="40" cy="50" r="30" fill="white"/>
              <circle cx="60" cy="50" r="30" fill="white"/>
            </mask>
          </defs>
          <rect x="0" y="0" width="100" height="100" fill="red" 
                mask="url(#overlapMask)"/>
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

      // Overlapping circles should combine
      expect(analysis.pixelCount, greaterThan(100));
    });

    testWidgets('mask with different shapes (rect, circle, path)', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <mask id="mixedMask">
              <rect x="10" y="10" width="20" height="20" fill="white"/>
              <circle cx="50" cy="50" r="15" fill="white"/>
              <path d="M70,70 L90,70 L80,90 Z" fill="white"/>
            </mask>
          </defs>
          <rect x="0" y="0" width="100" height="100" fill="red" 
                mask="url(#mixedMask)"/>
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

      // All shapes should be visible
      expect(analysis.pixelCount, greaterThan(50));
    });
  });

  group('Mask Edge Cases - Non-Uniform ViewBox', () {
    testWidgets('mask on SVG with non-uniform viewBox (wide)', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 200 100">
          <defs>
            <mask id="mask" maskContentUnits="objectBoundingBox">
              <rect x="0" y="0" width="1" height="1" fill="white"/>
            </mask>
          </defs>
          <rect x="50" y="25" width="100" height="50" fill="red" 
                mask="url(#mask)"/>
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

      final pixels = await VisualTestUtils.captureWidgetPixels(tester);
      final analysis = VisualTestUtils.analyzeRedPixels(pixels, 800, 600);

      // Non-uniform scaling should work correctly
      expect(analysis.pixelCount, greaterThan(100));
    });

    testWidgets('mask on SVG with non-uniform viewBox (tall)', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 100 200">
          <defs>
            <mask id="mask" maskContentUnits="objectBoundingBox">
              <rect x="0" y="0" width="1" height="1" fill="white"/>
            </mask>
          </defs>
          <rect x="25" y="50" width="50" height="100" fill="red" 
                mask="url(#mask)"/>
        </svg>
      ''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svgXml, width: 200, height: 400),
          ),
        ),
      );

      await tester.pump();

      final pixels = await VisualTestUtils.captureWidgetPixels(tester);
      final analysis = VisualTestUtils.analyzeRedPixels(pixels, 800, 600);

      // Non-uniform scaling should work correctly
      expect(analysis.pixelCount, greaterThan(100));
    });
  });

  group('Mask Edge Cases - Deep Nesting', () {
    testWidgets('deeply nested mask structure (3 levels)', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <mask id="mask1">
              <g mask="url(#mask2)">
                <rect x="0" y="0" width="100" height="100" fill="white"/>
              </g>
            </mask>
            <mask id="mask2">
              <g mask="url(#mask3)">
                <rect x="0" y="0" width="100" height="100" fill="white"/>
              </g>
            </mask>
            <mask id="mask3">
              <rect x="20" y="20" width="60" height="60" fill="white"/>
            </mask>
          </defs>
          <rect x="0" y="0" width="100" height="100" fill="red" 
                mask="url(#mask1)"/>
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

      // Deeply nested masks should render correctly
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('mask with deeply nested groups', (WidgetTester tester) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <mask id="nestedMask">
              <g>
                <g>
                  <g>
                    <rect x="20" y="20" width="60" height="60" fill="white"/>
                  </g>
                </g>
              </g>
            </mask>
          </defs>
          <rect x="0" y="0" width="100" height="100" fill="red" 
                mask="url(#nestedMask)"/>
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

  group('Mask Edge Cases - Alpha Gradient', () {
    testWidgets('alpha mask with linear gradient opacity', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <linearGradient id="alphaGrad" x1="0" y1="0" x2="1" y2="0">
              <stop offset="0%" stop-color="white" stop-opacity="1"/>
              <stop offset="100%" stop-color="white" stop-opacity="0"/>
            </linearGradient>
            <mask id="mask" type="alpha">
              <rect x="0" y="0" width="100" height="100" fill="url(#alphaGrad)"/>
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

      // Left side should be more visible than right side
      expect(analysis.pixelCount, greaterThan(50));
    });

    testWidgets('alpha mask with radial gradient opacity', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <radialGradient id="radAlphaGrad">
              <stop offset="0%" stop-color="white" stop-opacity="1"/>
              <stop offset="100%" stop-color="white" stop-opacity="0"/>
            </radialGradient>
            <mask id="mask" type="alpha">
              <rect x="0" y="0" width="100" height="100" fill="url(#radAlphaGrad)"/>
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

      // Center should be visible, edges fading
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });

  group('Mask Edge Cases - Transforms', () {
    testWidgets('mask with rotated content', (WidgetTester tester) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <mask id="mask">
              <rect x="25" y="25" width="50" height="50" fill="white"
                    transform="rotate(45, 50, 50)"/>
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

      // Rotated diamond should be visible
      expect(analysis.pixelCount, greaterThan(50));
    });

    testWidgets('mask with scaled content', (WidgetTester tester) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <mask id="mask">
              <rect x="0" y="0" width="100" height="100" fill="white"
                    transform="scale(0.5) translate(50, 50)"/>
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

      // Scaled mask should work
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('mask with skewX transform', (WidgetTester tester) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <mask id="mask">
              <rect x="20" y="30" width="60" height="40" fill="white"
                    transform="skewX(15)"/>
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

      // Skewed mask should work
      expect(analysis.pixelCount, greaterThan(50));
    });

    testWidgets('mask with matrix transform', (WidgetTester tester) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <mask id="mask">
              <rect x="20" y="20" width="60" height="60" fill="white"
                    transform="matrix(1, 0.2, 0, 1, 0, 0)"/>
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

      // Matrix transform should work
      expect(analysis.pixelCount, greaterThan(50));
    });
  });

  group('Mask Edge Cases - Use Element', () {
    testWidgets('mask with use element reference', (WidgetTester tester) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <rect id="maskShape" x="0" y="0" width="50" height="50"/>
            <mask id="mask">
              <use href="#maskShape" fill="white" x="25" y="25"/>
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

      // Use reference should work in mask
      expect(analysis.pixelCount, greaterThan(50));
    });

    testWidgets('mask with symbol use reference', (WidgetTester tester) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <symbol id="maskSymbol" viewBox="0 0 10 10">
              <circle cx="5" cy="5" r="5"/>
            </symbol>
            <mask id="mask">
              <use href="#maskSymbol" width="50" height="50" x="25" y="25" fill="white"/>
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

      // Symbol use in mask should work
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });

  group('Mask Combined Effects', () {
    testWidgets('mask + clip-path combination', (WidgetTester tester) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <clipPath id="clip">
              <rect x="10" y="10" width="80" height="80"/>
            </clipPath>
            <mask id="mask">
              <rect x="20" y="20" width="60" height="60" fill="white"/>
            </mask>
          </defs>
          <rect x="0" y="0" width="100" height="100" fill="red" 
                clip-path="url(#clip)" mask="url(#mask)"/>
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

      // Result should be intersection of clip and mask
      expect(analysis.pixelCount, greaterThan(100));
    });

    testWidgets('mask + filter combination', (WidgetTester tester) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <filter id="blur">
              <feGaussianBlur stdDeviation="2"/>
            </filter>
            <mask id="mask">
              <rect x="20" y="20" width="60" height="60" fill="white"/>
            </mask>
          </defs>
          <rect x="0" y="0" width="100" height="100" fill="red" 
                filter="url(#blur)" mask="url(#mask)"/>
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

      // Filter + mask should both be applied
      expect(analysis.pixelCount, greaterThan(50));
    });

    testWidgets('mask + opacity combination', (WidgetTester tester) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <mask id="mask">
              <rect x="20" y="20" width="60" height="60" fill="white"/>
            </mask>
          </defs>
          <rect x="0" y="0" width="100" height="100" fill="red" 
                mask="url(#mask)" opacity="0.5"/>
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

      // Mask + opacity should both be applied
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });
}
