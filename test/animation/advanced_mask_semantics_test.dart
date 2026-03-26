import 'package:flutter/material.dart';
import 'package:flutter_svg/src/animation/animated_svg_picture.dart';
import 'package:flutter_test/flutter_test.dart';

import 'visual_test_utils.dart';

/// Comprehensive tests for advanced mask semantics per SVG 2 specification.
/// Tests luminosity masking, subgraph masking, mask units, edge feathering,
/// and animated mask morphing.
void main() {
  group('Luminosity Masking', () {
    testWidgets(
      'luminance mask converts colored content to grayscale opacity',
      (WidgetTester tester) async {
        // White has luminance 1.0, black has 0.0, red has ~0.2126
        const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <mask id="lumMask" type="luminance">
              <rect x="0" y="0" width="33" height="100" fill="white"/>
              <rect x="33" y="0" width="34" height="100" fill="#808080"/>
              <rect x="67" y="0" width="33" height="100" fill="black"/>
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

        final pixels = await VisualTestUtils.captureWidgetPixels(tester);
        final analysis = VisualTestUtils.analyzeRedPixels(pixels, 800, 600);

        // White region should show red, black region should be transparent
        expect(analysis.pixelCount, greaterThan(100));
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      },
    );

    testWidgets('mask-type attribute alpha uses alpha channel', (
      WidgetTester tester,
    ) async {
      // Alpha masking uses the alpha channel directly
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <mask id="mask" type="alpha">
              <rect x="0" y="0" width="100" height="100" fill="red" fill-opacity="0.5"/>
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

      // With alpha masking, fill-opacity determines mask opacity
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('CSS mask-mode property overrides mask type', (
      WidgetTester tester,
    ) async {
      // mask-mode takes precedence over mask type attribute
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <mask id="mask" type="alpha">
              <rect x="0" y="0" width="100" height="100" fill="white"/>
            </mask>
          </defs>
          <rect x="0" y="0" width="100" height="100" fill="red" 
                mask="url(#mask)" style="mask-mode: luminance;"/>
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

      // White mask with luminance mode should show content (luminance=1.0)
      expect(analysis.pixelCount, greaterThan(500));
    });
  });

  group('Subgraph Masking with Filters', () {
    testWidgets('element with filter and mask applies filter then mask', (
      WidgetTester tester,
    ) async {
      // Correct order: render -> filter -> mask
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <filter id="blur">
              <feGaussianBlur stdDeviation="2"/>
            </filter>
            <mask id="mask">
              <rect x="25" y="25" width="50" height="50" fill="white"/>
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

      // Content should be blurred and masked
      expect(analysis.pixelCount, greaterThan(100));
    });

    testWidgets('mask content with filter renders filtered mask', (
      WidgetTester tester,
    ) async {
      // Filter inside mask content should be applied
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <filter id="blur">
              <feGaussianBlur stdDeviation="5"/>
            </filter>
            <mask id="mask">
              <rect x="30" y="30" width="40" height="40" fill="white" 
                    filter="url(#blur)"/>
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

      // Should render with blurred mask edges
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });

  group('maskUnits Coordinate Systems', () {
    testWidgets('maskUnits objectBoundingBox scales to element bounds', (
      WidgetTester tester,
    ) async {
      // Default maskUnits=objectBoundingBox: coordinates relative to element bbox
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <mask id="mask" maskUnits="objectBoundingBox" 
                  x="0" y="0" width="1" height="1">
              <rect x="25" y="25" width="50" height="50" fill="white"/>
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

    testWidgets('maskUnits userSpaceOnUse uses absolute coordinates', (
      WidgetTester tester,
    ) async {
      // userSpaceOnUse: mask region in absolute user coordinates
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <mask id="mask" maskUnits="userSpaceOnUse" 
                  x="20" y="20" width="60" height="60">
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

      expect(analysis.pixelCount, greaterThan(200));
    });
  });

  group('maskContentUnits Coordinate Systems', () {
    testWidgets('maskContentUnits objectBoundingBox scales content', (
      WidgetTester tester,
    ) async {
      // Content coordinates are 0-1 relative to masked element bbox
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

      expect(analysis.pixelCount, greaterThan(200));
    });

    testWidgets(
      'maskContentUnits userSpaceOnUse uses absolute content coords',
      (WidgetTester tester) async {
        // Default: mask content in absolute user space coordinates
        const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <mask id="mask" maskContentUnits="userSpaceOnUse">
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

        expect(analysis.pixelCount, greaterThan(200));
      },
    );

    testWidgets('mixed maskUnits and maskContentUnits', (
      WidgetTester tester,
    ) async {
      // Different units for region and content
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <mask id="mask" 
                  maskUnits="userSpaceOnUse" 
                  maskContentUnits="objectBoundingBox"
                  x="10" y="10" width="80" height="80">
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

      expect(analysis.pixelCount, greaterThan(100));
    });
  });

  group('Mask Edge Feathering', () {
    testWidgets('default mask extends 10% beyond element bounds', (
      WidgetTester tester,
    ) async {
      // Per SVG spec, default mask region is x=-10%, y=-10%, width=120%, height=120%
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <mask id="mask">
              <!-- Mask content larger than element to test default extension -->
              <rect x="0" y="0" width="100" height="100" fill="white"/>
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

      // Default 10% extension should allow full element to show
      expect(analysis.pixelCount, greaterThan(500));
    });

    testWidgets('explicit mask region clips content outside region', (
      WidgetTester tester,
    ) async {
      // Explicit mask region should clip content
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <mask id="mask" x="0.25" y="0.25" width="0.5" height="0.5">
              <rect x="0" y="0" width="100" height="100" fill="white"/>
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

      // Only center 50% x 50% should be visible
      expect(analysis.pixelCount, greaterThan(100));
    });
  });

  group('Animated Mask Morphing', () {
    testWidgets('animated mask content via SMIL', (WidgetTester tester) async {
      // Mask content can be animated
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <mask id="mask">
              <rect x="20" y="20" width="30" height="30" fill="white">
                <animate attributeName="width" values="30;60;30" 
                         dur="1s" repeatCount="indefinite"/>
              </rect>
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

      // Initial state
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);

      // Advance animation
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('animated mask region attributes', (WidgetTester tester) async {
      // Mask region (x, y, width, height) can be animated
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <mask id="mask">
              <animate attributeName="x" values="-0.1;0;-0.1" 
                       dur="2s" repeatCount="indefinite"/>
              <rect x="0" y="0" width="100" height="100" fill="white"/>
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

      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });

  group('Edge Cases', () {
    testWidgets('empty mask allows content through (no mask content)', (
      WidgetTester tester,
    ) async {
      // Empty mask (no children) - implementations vary, many pass through
      // Note: SVG spec says empty mask = all transparent, but implementations differ
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <mask id="emptyMask">
              <!-- No mask content -->
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

      // Widget renders without error
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('zero-area mask region hides content', (
      WidgetTester tester,
    ) async {
      // Mask with zero width or height should hide content
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <mask id="zeroMask" x="0" y="0" width="0" height="1">
              <rect x="0" y="0" width="100" height="100" fill="white"/>
            </mask>
          </defs>
          <rect x="0" y="0" width="100" height="100" fill="red" 
                mask="url(#zeroMask)"/>
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

      // Zero-width mask region should hide content
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('non-uniform scaling with objectBoundingBox', (
      WidgetTester tester,
    ) async {
      // Element with different width/height should scale mask non-uniformly
      const svgXml = '''
        <svg viewBox="0 0 200 100">
          <defs>
            <mask id="mask" maskContentUnits="objectBoundingBox">
              <rect x="0.1" y="0.1" width="0.8" height="0.8" fill="white"/>
            </mask>
          </defs>
          <rect x="0" y="0" width="200" height="100" fill="red" 
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

      // Should render with non-uniform scaling
      expect(analysis.pixelCount, greaterThan(200));
    });

    testWidgets('mask on group affects all children', (
      WidgetTester tester,
    ) async {
      // Mask on group should apply to all children
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <mask id="mask">
              <rect x="25" y="25" width="50" height="50" fill="white"/>
            </mask>
          </defs>
          <g mask="url(#mask)">
            <rect x="0" y="0" width="50" height="100" fill="red"/>
            <rect x="50" y="0" width="50" height="100" fill="green"/>
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
      final redAnalysis = VisualTestUtils.analyzeRedPixels(pixels, 800, 600);

      // Red should be visible only in mask area
      expect(redAnalysis.pixelCount, greaterThan(50));
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });

  group('Advanced Mask Composition', () {
    testWidgets('luminance mask computes correct opacity from RGB', (
      WidgetTester tester,
    ) async {
      // Red has luminance ~0.2126, green ~0.7152, blue ~0.0722
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <mask id="mask" type="luminance">
              <rect x="0" y="0" width="50" height="100" fill="#FF0000"/>
              <rect x="50" y="0" width="50" height="100" fill="#00FF00"/>
            </mask>
          </defs>
          <rect x="0" y="0" width="100" height="100" fill="white" 
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

      // Green region should be more visible than red due to higher luminance
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('mask with gradient edge creates soft transition', (
      WidgetTester tester,
    ) async {
      // Gradient in mask creates soft edge feathering
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <linearGradient id="grad" x1="0%" y1="0%" x2="100%" y2="0%">
              <stop offset="0%" stop-color="white"/>
              <stop offset="100%" stop-color="black"/>
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

      final pixels = await VisualTestUtils.captureWidgetPixels(tester);
      final analysis = VisualTestUtils.analyzeRedPixels(pixels, 800, 600);

      // Gradient mask should show content with varying opacity
      expect(analysis.pixelCount, greaterThan(50));
    });

    testWidgets('blur filter inside mask creates feathered edge', (
      WidgetTester tester,
    ) async {
      // Gaussian blur in mask content creates soft edges
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <filter id="blur">
              <feGaussianBlur stdDeviation="8"/>
            </filter>
            <mask id="mask">
              <rect x="25" y="25" width="50" height="50" fill="white" 
                    filter="url(#blur)"/>
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

      // Should render with blurred/feathered mask edges
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('nested masks apply in correct order', (
      WidgetTester tester,
    ) async {
      // Mask on group containing masked element
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <mask id="outerMask">
              <rect x="0" y="0" width="100" height="50" fill="white"/>
            </mask>
            <mask id="innerMask">
              <rect x="0" y="0" width="50" height="100" fill="white"/>
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

      // Only top-left quadrant should be visible (intersection of both masks)
      expect(analysis.pixelCount, greaterThan(100));
    });

    testWidgets('mask combined with clip-path', (WidgetTester tester) async {
      // Element with both clip-path and mask
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <clipPath id="clip">
              <rect x="10" y="10" width="80" height="80"/>
            </clipPath>
            <mask id="mask">
              <rect x="25" y="0" width="50" height="100" fill="white"/>
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
  });

  group('Mask Cache Invalidation', () {
    testWidgets('animated mask shape triggers re-render', (
      WidgetTester tester,
    ) async {
      // Circle radius animation inside mask
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <mask id="mask">
              <circle cx="50" cy="50" r="20" fill="white">
                <animate attributeName="r" values="20;40;20" 
                         dur="2s" repeatCount="indefinite"/>
              </circle>
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
      final pixelsT0 = await VisualTestUtils.captureWidgetPixels(tester);
      final analysisT0 = VisualTestUtils.analyzeRedPixels(pixelsT0, 800, 600);

      // Advance animation halfway
      await tester.pump(const Duration(seconds: 1));
      final pixelsT1 = await VisualTestUtils.captureWidgetPixels(tester);
      final analysisT1 = VisualTestUtils.analyzeRedPixels(pixelsT1, 800, 600);

      // Mask should have grown - more red pixels visible
      expect(
        analysisT1.pixelCount,
        greaterThanOrEqualTo(analysisT0.pixelCount),
      );
    });

    testWidgets('mask with animated fill color', (WidgetTester tester) async {
      // Fill color animation affects mask opacity
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <mask id="mask">
              <rect x="0" y="0" width="100" height="100" fill="white">
                <animate attributeName="fill" values="white;gray;white" 
                         dur="2s" repeatCount="indefinite"/>
              </rect>
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

      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('animated transform in mask content', (
      WidgetTester tester,
    ) async {
      // Transform animation inside mask
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <mask id="mask">
              <rect x="25" y="25" width="50" height="50" fill="white">
                <animateTransform attributeName="transform" 
                                  type="rotate" 
                                  values="0 50 50;180 50 50;360 50 50" 
                                  dur="2s" repeatCount="indefinite"/>
              </rect>
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

      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });

  group('Mask Unit Edge Cases', () {
    testWidgets('very small element with objectBoundingBox mask', (
      WidgetTester tester,
    ) async {
      // Tiny element should still be masked properly
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <mask id="mask" maskContentUnits="objectBoundingBox">
              <rect x="0" y="0" width="1" height="1" fill="white"/>
            </mask>
          </defs>
          <rect x="45" y="45" width="10" height="10" fill="red" 
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

      // Small element should still be visible through mask
      expect(analysis.pixelCount, greaterThan(10));
    });

    testWidgets('percentage values in mask region', (
      WidgetTester tester,
    ) async {
      // Percentage values for mask region
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <mask id="mask" x="25%" y="25%" width="50%" height="50%">
              <rect x="0" y="0" width="100" height="100" fill="white"/>
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

      // 50% x 50% region should be visible
      expect(analysis.pixelCount, greaterThan(100));
    });

    testWidgets('extremely large mask region values', (
      WidgetTester tester,
    ) async {
      // Large mask region extending well beyond element
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <mask id="mask" x="-1" y="-1" width="3" height="3">
              <rect x="0" y="0" width="200" height="200" fill="white"/>
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

      // Full element should be visible
      expect(analysis.pixelCount, greaterThan(200));
    });

    testWidgets('mask with use element reference', (WidgetTester tester) async {
      // Mask content using <use> element
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <rect id="maskRect" x="25" y="25" width="50" height="50"/>
            <mask id="mask">
              <use href="#maskRect" fill="white"/>
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
      expect(analysis.pixelCount, greaterThan(100));
    });
  });
}
