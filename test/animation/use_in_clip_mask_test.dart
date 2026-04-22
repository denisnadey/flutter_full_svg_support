import 'package:flutter/material.dart';
import 'package:full_svg_flutter/src/animation/animated_svg_picture.dart';
import 'package:flutter_test/flutter_test.dart';

import 'visual_test_utils.dart';

/// Comprehensive tests for use element resolution within clip-path and mask definitions.
///
/// Tests cover:
/// 1. Use element within clip-path with referenced shapes
/// 2. Symbol viewBox mapping in mask coordinate space
/// 3. clipPathUnits="objectBoundingBox" with use elements
/// 4. Transform handling on referenced elements
/// 5. Nested use within clip/mask contexts
void main() {
  group('Use element within clip-path', () {
    testWidgets('use element referencing rect inside clipPath', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <rect id="clipRect" x="20" y="20" width="60" height="60"/>
            <clipPath id="clip">
              <use href="#clipRect"/>
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

      // Content should be clipped to the rect referenced by use
      expect(analysis.pixelCount, greaterThan(500));
      // Should be roughly centered (20-80 in 100x100 viewBox)
      expect(analysis.boundingBox.left, greaterThanOrEqualTo(30));
    });

    testWidgets('use element referencing circle inside clipPath', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <circle id="clipCircle" cx="50" cy="50" r="30"/>
            <clipPath id="clip">
              <use href="#clipCircle"/>
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

      // Circle clip should produce visible output
      expect(analysis.pixelCount, greaterThan(500));
    });

    testWidgets('use element referencing path inside clipPath', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <path id="clipPath" d="M25,25 L75,25 L75,75 L25,75 Z"/>
            <clipPath id="clip">
              <use href="#clipPath"/>
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

      // Path clip should work
      expect(analysis.pixelCount, greaterThan(500));
    });

    testWidgets('use element with x/y offset inside clipPath', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <rect id="smallRect" width="40" height="40"/>
            <clipPath id="clip">
              <use href="#smallRect" x="30" y="30"/>
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

      // Clip should be offset by use x/y
      expect(analysis.pixelCount, greaterThan(300));
      expect(analysis.boundingBox.left, greaterThan(50));
      expect(analysis.boundingBox.top, greaterThan(50));
    });

    testWidgets('use with transform inside clipPath', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <rect id="r" x="0" y="0" width="30" height="30"/>
            <clipPath id="clip">
              <use href="#r" transform="translate(35,35) rotate(45,15,15)"/>
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

      // Transformed clip should render
      expect(analysis.pixelCount, greaterThan(100));
    });
  });

  group('Symbol viewBox in mask', () {
    testWidgets('use referencing symbol with viewBox in mask', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <symbol id="sym" viewBox="0 0 20 20">
              <rect x="0" y="0" width="20" height="20" fill="white"/>
            </symbol>
            <mask id="mask">
              <use href="#sym" x="25" y="25" width="50" height="50"/>
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

      // Symbol viewBox should be mapped to 50x50 area
      expect(analysis.pixelCount, greaterThan(500));
    });

    testWidgets('symbol with preserveAspectRatio in mask', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <symbol id="sym" viewBox="0 0 10 20" preserveAspectRatio="xMidYMid meet">
              <rect x="0" y="0" width="10" height="20" fill="white"/>
            </symbol>
            <mask id="mask">
              <use href="#sym" x="10" y="10" width="60" height="60"/>
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

      // Content should be preserved with aspect ratio
      expect(analysis.pixelCount, greaterThan(300));
      // With meet, the width should be smaller (1:2 aspect into 60x60)
      expect(analysis.objectHeight, greaterThan(analysis.objectWidth * 0.5));
    });

    testWidgets('maskContentUnits objectBoundingBox with use', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <rect id="maskRect" x="0.2" y="0.2" width="0.6" height="0.6" fill="white"/>
            <mask id="mask" maskContentUnits="objectBoundingBox">
              <use href="#maskRect"/>
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

      // Content should be scaled relative to masked element bounds
      expect(analysis.pixelCount, greaterThan(300));
    });
  });

  group('clipPathUnits objectBoundingBox with use', () {
    testWidgets('use element within objectBoundingBox clipPath', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <rect id="obbRect" x="0.2" y="0.2" width="0.6" height="0.6"/>
            <clipPath id="clip" clipPathUnits="objectBoundingBox">
              <use href="#obbRect"/>
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

      // Clip should be scaled relative to element bounds (0.2-0.8 = 60% of 80 = 48)
      expect(analysis.pixelCount, greaterThan(300));
    });

    testWidgets('use with x/y in objectBoundingBox clipPath', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <rect id="r" width="0.4" height="0.4"/>
            <clipPath id="clip" clipPathUnits="objectBoundingBox">
              <use href="#r" x="0.3" y="0.3"/>
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

      // Clip should be at 30% offset with 40% size
      expect(analysis.pixelCount, greaterThan(200));
    });

    testWidgets('use referencing circle in objectBoundingBox clipPath', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <circle id="c" cx="0.5" cy="0.5" r="0.4"/>
            <clipPath id="clip" clipPathUnits="objectBoundingBox">
              <use href="#c"/>
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

      // Circle clip should work in objectBoundingBox mode
      expect(analysis.pixelCount, greaterThan(200));
    });
  });

  group('Referenced element with own transform', () {
    testWidgets('use referencing transformed rect in clipPath', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <rect id="r" x="0" y="0" width="40" height="40" 
                  transform="translate(30,30)"/>
            <clipPath id="clip">
              <use href="#r"/>
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

      // Referenced element's transform should be applied
      expect(analysis.pixelCount, greaterThan(300));
      expect(analysis.boundingBox.left, greaterThan(50));
    });

    testWidgets('use with transform referencing transformed element', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <rect id="r" x="0" y="0" width="20" height="20" 
                  transform="translate(10,10)"/>
            <clipPath id="clip">
              <use href="#r" transform="translate(30,30)"/>
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

      // Both transforms should stack
      expect(analysis.pixelCount, greaterThan(50));
      // Position should be at 40,40 (10+30)
      expect(analysis.boundingBox.left, greaterThan(70));
    });
  });

  group('Nested use within clip/mask', () {
    testWidgets('nested use elements in clipPath', (WidgetTester tester) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <rect id="base" width="40" height="40"/>
            <use id="level1" href="#base"/>
            <clipPath id="clip">
              <use href="#level1" x="30" y="30"/>
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

      // Nested use should resolve correctly
      expect(analysis.pixelCount, greaterThan(200));
    });

    testWidgets('use referencing group inside clipPath', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <g id="shapes">
              <circle cx="30" cy="30" r="20"/>
              <circle cx="70" cy="70" r="20"/>
            </g>
            <clipPath id="clip">
              <use href="#shapes"/>
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

      // Group with multiple shapes should contribute all shapes to clip
      expect(analysis.pixelCount, greaterThan(300));
    });

    testWidgets('use referencing symbol inside mask', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <symbol id="sym">
              <rect x="10" y="10" width="80" height="80" fill="white"/>
            </symbol>
            <mask id="mask">
              <use href="#sym"/>
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

      // Symbol content should contribute to mask
      expect(analysis.pixelCount, greaterThan(500));
    });
  });

  group('Edge cases', () {
    testWidgets('circular reference in clipPath use is handled', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <use id="a" href="#b"/>
            <use id="b" href="#a"/>
            <clipPath id="clip">
              <use href="#a"/>
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

      // Should not crash, circular reference should be caught
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('use referencing non-existent element in clipPath', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <clipPath id="clip">
              <use href="#nonexistent"/>
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

      // Should render without crashing (empty clip or full content)
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('use with display:none inside clipPath', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <rect id="r" x="20" y="20" width="60" height="60"/>
            <clipPath id="clip">
              <use href="#r" style="display: none;"/>
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

      // display:none use should not contribute to clip
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });
}
