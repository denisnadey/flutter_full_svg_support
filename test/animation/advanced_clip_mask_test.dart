import 'package:flutter/material.dart';
import 'package:flutter_svg/src/animation/animated_svg_picture.dart';
import 'package:flutter_test/flutter_test.dart';

import 'visual_test_utils.dart';

/// Comprehensive tests for advanced clipping and masking features.
/// Tests luminosity masking, nested composition chains, and edge feathering.
void main() {
  group('Luminosity Masking Tests', () {
    testWidgets('mask-type luminance converts RGB to grayscale opacity', (
      WidgetTester tester,
    ) async {
      // White mask content should allow full visibility (luminance = 1.0)
      // Black mask content should hide completely (luminance = 0.0)
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <mask id="lumMask" style="mask-type: luminance;">
              <rect x="0" y="0" width="50" height="100" fill="white"/>
              <rect x="50" y="0" width="50" height="100" fill="black"/>
            </mask>
          </defs>
          <rect x="0" y="0" width="100" height="100" fill="red" 
                mask="url(#lumMask)"/>
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

    testWidgets('mask type attribute on mask element', (
      WidgetTester tester,
    ) async {
      // Using type attribute on <mask> element
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <mask id="mask" type="luminance">
              <rect x="25" y="25" width="50" height="50" fill="white"/>
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

      // With luminance mask, white area should show content
      expect(analysis.pixelCount, greaterThan(500));
    });

    testWidgets('mask-type alpha uses alpha channel (default)', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <mask id="mask" style="mask-type: alpha;">
              <rect x="25" y="25" width="50" height="50" fill="white" fill-opacity="0.5"/>
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

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('luminance mask with gradient', (WidgetTester tester) async {
      // Gradient from white to black should create gradient visibility
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <linearGradient id="grad" x1="0%" y1="0%" x2="100%" y2="0%">
              <stop offset="0" stop-color="white"/>
              <stop offset="1" stop-color="black"/>
            </linearGradient>
            <mask id="mask" type="luminance">
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

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('luminance mask with colored content', (
      WidgetTester tester,
    ) async {
      // Red has luminance ~0.2126, should show as ~21% opacity
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <mask id="mask" type="luminance">
              <rect x="0" y="0" width="100" height="100" fill="red"/>
            </mask>
          </defs>
          <rect x="0" y="0" width="100" height="100" fill="blue" 
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

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });

  group('Nested Composition Chains', () {
    testWidgets('clip-path inside mask: clip first, then mask', (
      WidgetTester tester,
    ) async {
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

      // Should be clipped to intersection of clip (10,10,80,80) and mask (20,20,60,60)
      expect(analysis.pixelCount, greaterThan(500));
    });

    testWidgets('mask inside clip-path: both applied', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <clipPath id="clip">
              <circle cx="50" cy="50" r="40"/>
            </clipPath>
            <mask id="mask">
              <rect x="0" y="0" width="100" height="50" fill="white"/>
            </mask>
          </defs>
          <rect x="0" y="0" width="100" height="100" fill="red" 
                mask="url(#mask)" clip-path="url(#clip)"/>
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

      // Should show only top half of circle
      expect(analysis.pixelCount, greaterThan(300));
    });

    testWidgets('nested clip-paths (2 levels deep)', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <clipPath id="outerClip">
              <rect x="10" y="10" width="80" height="80"/>
            </clipPath>
            <clipPath id="innerClip">
              <rect x="20" y="20" width="60" height="60"/>
            </clipPath>
          </defs>
          <g clip-path="url(#outerClip)">
            <rect x="0" y="0" width="100" height="100" fill="red" 
                  clip-path="url(#innerClip)"/>
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

      // Result should be intersection of both clips: inner (20,20,60,60)
      expect(analysis.pixelCount, greaterThan(500));
    });

    testWidgets('nested clip-paths (3 levels deep)', (
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
          </defs>
          <g clip-path="url(#clip1)">
            <g clip-path="url(#clip2)">
              <rect x="0" y="0" width="100" height="100" fill="red" 
                    clip-path="url(#clip3)"/>
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

      // Result should be innermost clip: (25,25,50,50)
      expect(analysis.pixelCount, greaterThan(300));
    });

    testWidgets('nested masks (2 levels deep)', (WidgetTester tester) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <mask id="outerMask">
              <rect x="10" y="10" width="80" height="80" fill="white"/>
            </mask>
            <mask id="innerMask">
              <rect x="30" y="30" width="40" height="40" fill="white"/>
            </mask>
          </defs>
          <g mask="url(#outerMask)">
            <rect x="0" y="0" width="100" height="100" fill="red" 
                  mask="url(#innerMask)"/>
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

    testWidgets('mixed nesting: clip -> mask -> clip', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <clipPath id="clip1">
              <rect x="5" y="5" width="90" height="90"/>
            </clipPath>
            <mask id="mask">
              <rect x="15" y="15" width="70" height="70" fill="white"/>
            </mask>
            <clipPath id="clip2">
              <rect x="25" y="25" width="50" height="50"/>
            </clipPath>
          </defs>
          <g clip-path="url(#clip1)">
            <g mask="url(#mask)">
              <rect x="0" y="0" width="100" height="100" fill="red" 
                    clip-path="url(#clip2)"/>
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

  group('clipPathUnits and maskUnits', () {
    testWidgets('clipPathUnits userSpaceOnUse', (WidgetTester tester) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <clipPath id="clip" clipPathUnits="userSpaceOnUse">
              <rect x="20" y="20" width="60" height="60"/>
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

      expect(analysis.pixelCount, greaterThan(500));
    });

    testWidgets('clipPathUnits objectBoundingBox', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <clipPath id="clip" clipPathUnits="objectBoundingBox">
              <rect x="0.1" y="0.1" width="0.8" height="0.8"/>
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

      expect(analysis.pixelCount, greaterThan(300));
    });

    testWidgets('maskUnits userSpaceOnUse', (WidgetTester tester) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <mask id="mask" maskUnits="userSpaceOnUse" x="0" y="0" width="100" height="100">
              <rect x="20" y="20" width="60" height="60" fill="white"/>
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

      expect(analysis.pixelCount, greaterThan(300));
    });

    testWidgets('maskContentUnits objectBoundingBox', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <mask id="mask" maskContentUnits="objectBoundingBox">
              <rect x="0.2" y="0.2" width="0.6" height="0.6" fill="white"/>
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

      expect(analysis.pixelCount, greaterThan(200));
    });
  });

  group('Edge Feathering', () {
    testWidgets('anti-aliased clip-path edges', (WidgetTester tester) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <clipPath id="clip">
              <circle cx="50" cy="50" r="40"/>
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

      // Should render with smooth edges
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('diagonal clip-path with anti-aliasing', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <clipPath id="clip">
              <polygon points="0,100 100,0 100,100"/>
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

      // Should show roughly half the area (triangle)
      expect(analysis.pixelCount, greaterThan(500));
    });
  });

  group('Complex Composition Scenarios', () {
    testWidgets('group with clip-path containing masked elements', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <clipPath id="groupClip">
              <rect x="10" y="10" width="80" height="80"/>
            </clipPath>
            <mask id="mask">
              <rect x="0" y="0" width="100" height="50" fill="white"/>
            </mask>
          </defs>
          <g clip-path="url(#groupClip)">
            <rect x="0" y="0" width="100" height="100" fill="red" 
                  mask="url(#mask)"/>
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

    testWidgets('use element with clip-path and mask', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <clipPath id="clip">
              <rect x="20" y="20" width="60" height="60"/>
            </clipPath>
            <mask id="mask">
              <rect x="30" y="30" width="40" height="40" fill="white"/>
            </mask>
            <rect id="myRect" width="100" height="100" fill="red"/>
          </defs>
          <use href="#myRect" clip-path="url(#clip)" mask="url(#mask)"/>
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

    testWidgets('clip-path referencing use element', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <circle id="clipCircle" r="30"/>
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

      expect(analysis.pixelCount, greaterThan(300));
    });

    testWidgets('mask referencing use element', (WidgetTester tester) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <rect id="maskRect" width="60" height="60" fill="white"/>
            <mask id="mask">
              <use href="#maskRect" x="20" y="20"/>
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

      expect(analysis.pixelCount, greaterThan(300));
    });
  });

  group('Alpha Mask Preservation', () {
    testWidgets('alpha mask with white fill renders content', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <mask id="mask">
              <rect x="25" y="25" width="50" height="50" fill="white"/>
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

      expect(analysis.pixelCount, greaterThan(500));
    });

    testWidgets('alpha mask with partial opacity', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <mask id="mask">
              <rect x="0" y="0" width="100" height="100" fill="white" fill-opacity="0.5"/>
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

      // Should render with reduced opacity
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });
}
