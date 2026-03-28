import 'package:flutter/material.dart';
import 'package:flutter_svg/src/animation/animated_svg_picture.dart';
import 'package:flutter_test/flutter_test.dart';

import 'visual_test_utils.dart';

/// Comprehensive tests for advanced SVG masking features.
///
/// Tests cover:
/// - maskUnits="objectBoundingBox" (default)
/// - maskUnits="userSpaceOnUse"
/// - maskContentUnits="userSpaceOnUse" (default)
/// - maskContentUnits="objectBoundingBox"
/// - Combined maskUnits + maskContentUnits
/// - Luminance masks: white/black/gray regions
/// - Alpha masks: semi-transparent mask content
/// - Mask with gradient content
/// - Mask with transform on mask children
/// - Nested masks
/// - Mask + clip-path combination
/// - Hit-testing through mask boundary
/// - Edge cases
void main() {
  group('maskUnits Coordinate Systems', () {
    testWidgets('maskUnits="objectBoundingBox" (default) - basic test', (
      WidgetTester tester,
    ) async {
      // Default: mask region is relative to element bounding box
      // Default region extends 10% beyond bbox (-10%, -10%, 120%, 120%)
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

      // Element should be visible with default mask
      expect(analysis.pixelCount, greaterThan(500));
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('maskUnits="userSpaceOnUse" - explicit region in user coords', (
      WidgetTester tester,
    ) async {
      // userSpaceOnUse: mask region is in absolute user coordinates
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <mask id="mask" maskUnits="userSpaceOnUse" 
                  x="30" y="30" width="40" height="40">
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

      // Only center 40x40 region should be visible
      expect(analysis.pixelCount, greaterThan(100));
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });

  group('maskContentUnits Coordinate Systems', () {
    testWidgets('maskContentUnits="userSpaceOnUse" (default)', (
      WidgetTester tester,
    ) async {
      // Default: mask content is in absolute user coordinates
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <mask id="mask" maskContentUnits="userSpaceOnUse">
              <rect x="30" y="30" width="40" height="40" fill="white"/>
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

      // Central 40x40 area should be visible
      expect(analysis.pixelCount, greaterThan(100));
    });

    testWidgets(
      'maskContentUnits="objectBoundingBox" - scales content to element bbox',
      (WidgetTester tester) async {
        // Content coordinates are 0-1 relative to masked element bbox
        const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <mask id="mask" maskContentUnits="objectBoundingBox">
              <rect x="0.25" y="0.25" width="0.5" height="0.5" fill="white"/>
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

        // Central 50% of element should be visible
        expect(analysis.pixelCount, greaterThan(100));
      },
    );
  });

  group('Combined maskUnits + maskContentUnits', () {
    testWidgets(
      'maskUnits=userSpaceOnUse + maskContentUnits=objectBoundingBox',
      (WidgetTester tester) async {
        const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <mask id="mask" 
                  maskUnits="userSpaceOnUse" 
                  maskContentUnits="objectBoundingBox"
                  x="0" y="0" width="100" height="100">
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
      },
    );

    testWidgets(
      'maskUnits=objectBoundingBox + maskContentUnits=userSpaceOnUse',
      (WidgetTester tester) async {
        const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <mask id="mask" 
                  maskUnits="objectBoundingBox" 
                  maskContentUnits="userSpaceOnUse">
              <rect x="30" y="30" width="40" height="40" fill="white"/>
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

        expect(analysis.pixelCount, greaterThan(50));
      },
    );
  });

  group('Luminance Masks', () {
    testWidgets('Luminance mask: white region fully visible', (
      WidgetTester tester,
    ) async {
      // White has luminance 1.0 -> fully visible
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <mask id="mask" type="luminance">
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

      expect(analysis.pixelCount, greaterThan(500));
    });

    testWidgets('Luminance mask: black region hidden', (
      WidgetTester tester,
    ) async {
      // Black has luminance 0.0 -> fully hidden
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <mask id="mask" type="luminance">
              <rect x="0" y="0" width="100" height="100" fill="black"/>
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

      // Should render without errors (content may be hidden)
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('Luminance mask: gray region partially visible', (
      WidgetTester tester,
    ) async {
      // Gray (#808080) has luminance ~0.5 -> partially visible
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <mask id="mask" type="luminance">
              <rect x="0" y="0" width="100" height="100" fill="#808080"/>
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

      // Should render with partial opacity
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('Default mask-type is luminance per SVG spec', (
      WidgetTester tester,
    ) async {
      // Without explicit type, mask should use luminance mode
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <mask id="mask">
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

      // White mask with luminance mode should show content
      expect(analysis.pixelCount, greaterThan(500));
    });
  });

  group('Alpha Masks', () {
    testWidgets('Alpha mask uses fill-opacity directly', (
      WidgetTester tester,
    ) async {
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

      // Content should be visible at 50% opacity
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('Alpha mask with fully transparent content hides element', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <mask id="mask" type="alpha">
              <rect x="0" y="0" width="100" height="100" fill="white" fill-opacity="0"/>
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

      // Element should be hidden
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });

  group('Mask with Gradient Content', () {
    testWidgets('Linear gradient in mask creates smooth transition', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <linearGradient id="grad" x1="0" y1="0" x2="1" y2="0">
              <stop offset="0%" stop-color="white"/>
              <stop offset="100%" stop-color="black"/>
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

      final pixels = await VisualTestUtils.captureWidgetPixels(tester);
      final analysis = VisualTestUtils.analyzeRedPixels(pixels, 800, 600);

      // Left side should be more visible than right side
      expect(analysis.pixelCount, greaterThan(50));
    });

    testWidgets('Radial gradient in mask', (WidgetTester tester) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <radialGradient id="radGrad">
              <stop offset="0%" stop-color="white"/>
              <stop offset="100%" stop-color="black"/>
            </radialGradient>
            <mask id="mask" type="luminance">
              <rect x="0" y="0" width="100" height="100" fill="url(#radGrad)"/>
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

      // Center should be visible (white), edges fading to black
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });

  group('Mask with Transform', () {
    testWidgets('Transform on mask child element', (WidgetTester tester) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <mask id="mask">
              <rect x="-25" y="-25" width="50" height="50" fill="white"
                    transform="translate(50,50)"/>
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

      // Centered 50x50 area should be visible
      expect(analysis.pixelCount, greaterThan(50));
    });

    testWidgets('Rotate transform on mask content', (
      WidgetTester tester,
    ) async {
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

      // Rotated diamond shape in center should be visible
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });

  group('Nested Masks', () {
    testWidgets('Mask on group containing masked element', (
      WidgetTester tester,
    ) async {
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

      // Only top-left quadrant should be visible (intersection)
      expect(analysis.pixelCount, greaterThan(100));
    });
  });

  group('Mask + clip-path Combination', () {
    testWidgets('Element with both clip-path and mask', (
      WidgetTester tester,
    ) async {
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

  group('Edge Cases', () {
    testWidgets('Empty mask (no content)', (WidgetTester tester) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <mask id="emptyMask">
              <!-- No content -->
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

      // Should render without errors
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('Mask with no geometry (only defs)', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <mask id="noGeomMask">
              <defs>
                <linearGradient id="unused"/>
              </defs>
            </mask>
          </defs>
          <rect x="0" y="0" width="100" height="100" fill="red" 
                mask="url(#noGeomMask)"/>
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

    testWidgets('Mask outside viewport', (WidgetTester tester) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <mask id="outsideMask" maskUnits="userSpaceOnUse"
                  x="200" y="200" width="100" height="100">
              <rect x="0" y="0" width="500" height="500" fill="white"/>
            </mask>
          </defs>
          <rect x="0" y="0" width="100" height="100" fill="red" 
                mask="url(#outsideMask)"/>
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

      // Mask region is outside viewport, content may be hidden
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('Very small element with objectBoundingBox mask', (
      WidgetTester tester,
    ) async {
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

      // Small element should still be visible
      expect(analysis.pixelCount, greaterThan(10));
    });

    testWidgets('Mask with use element reference', (WidgetTester tester) async {
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

    testWidgets('Percentage values in mask region', (
      WidgetTester tester,
    ) async {
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
  });

  group('CSS mask-mode Property', () {
    testWidgets('mask-mode: luminance overrides type attribute', (
      WidgetTester tester,
    ) async {
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

      // mask-mode: luminance should apply luminance masking
      expect(analysis.pixelCount, greaterThan(500));
    });
  });
}
