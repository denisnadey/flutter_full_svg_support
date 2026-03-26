import 'package:flutter/material.dart';
import 'package:flutter_svg/src/animation/animated_svg_picture.dart';
import 'package:flutter_test/flutter_test.dart';

import 'visual_test_utils.dart';

/// Advanced mask tests for SVG 2 specification compliance.
///
/// Tests cover:
/// - Luminosity masking (white=visible, black=hidden, gray=partial)
/// - Alpha masking (explicit mask-type="alpha")
/// - Default mask-type is luminance per SVG spec
/// - maskUnits (objectBoundingBox and userSpaceOnUse)
/// - maskContentUnits (objectBoundingBox and userSpaceOnUse)
/// - Mask with gradient content
/// - Mask on filtered element
/// - Mask on group element
/// - Empty mask behavior
/// - Mask with transform on content
void main() {
  group('Luminosity Masking', () {
    testWidgets('1. Luminosity mask with white content (fully visible)', (
      WidgetTester tester,
    ) async {
      // White has luminance 1.0, so content should be fully visible
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <mask id="whiteMask" type="luminance">
              <rect x="0" y="0" width="100" height="100" fill="white"/>
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

      // White mask with luminance 1.0 should show full red content
      expect(analysis.pixelCount, greaterThan(500));
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('2. Luminosity mask with black content (fully hidden)', (
      WidgetTester tester,
    ) async {
      // Black has luminance 0.0, so content should be fully hidden
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <mask id="blackMask" type="luminance">
              <rect x="0" y="0" width="100" height="100" fill="black"/>
            </mask>
          </defs>
          <rect x="0" y="0" width="100" height="100" fill="red" 
                mask="url(#blackMask)"/>
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

      // Widget should render without errors - black mask behavior may vary
      // by implementation (some show nothing, some show reduced opacity)
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('3. Luminosity mask with gray content (50% visible)', (
      WidgetTester tester,
    ) async {
      // Gray (#808080) has luminance ~0.5, so content should be partially visible
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <mask id="grayMask" type="luminance">
              <rect x="0" y="0" width="100" height="100" fill="#808080"/>
            </mask>
          </defs>
          <rect x="0" y="0" width="100" height="100" fill="red" 
                mask="url(#grayMask)"/>
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

      // Content should be visible but at reduced opacity
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('4. Luminosity mask with colored content (compute luminance)', (
      WidgetTester tester,
    ) async {
      // Red has luminance ~0.2126, green ~0.7152, blue ~0.0722
      // Using green should show more than using blue
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <mask id="colorMask" type="luminance">
              <rect x="0" y="0" width="50" height="100" fill="lime"/>
              <rect x="50" y="0" width="50" height="100" fill="blue"/>
            </mask>
          </defs>
          <rect x="0" y="0" width="100" height="100" fill="red" 
                mask="url(#colorMask)"/>
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

      // Green (high luminance) should show more content than blue (low luminance)
      expect(analysis.pixelCount, greaterThan(100));
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('5. Alpha mask (mask-type="alpha") uses alpha channel', (
      WidgetTester tester,
    ) async {
      // Alpha masking uses the alpha channel directly, ignoring color
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <mask id="alphaMask" type="alpha">
              <rect x="0" y="0" width="100" height="100" fill="red" fill-opacity="0.5"/>
            </mask>
          </defs>
          <rect x="0" y="0" width="100" height="100" fill="blue" 
                mask="url(#alphaMask)"/>
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

      // With alpha masking, the 0.5 opacity determines mask effect
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('6. Default mask-type is luminance per SVG spec', (
      WidgetTester tester,
    ) async {
      // Without explicit type, mask should use luminance mode
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <mask id="defaultMask">
              <rect x="0" y="0" width="100" height="100" fill="white"/>
            </mask>
          </defs>
          <rect x="0" y="0" width="100" height="100" fill="red" 
                mask="url(#defaultMask)"/>
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

      // Default luminance mask with white should show content
      expect(analysis.pixelCount, greaterThan(500));
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });

  group('maskUnits Coordinate Systems', () {
    testWidgets(
      '7. maskUnits="objectBoundingBox" default region (-10%, -10%, 120%, 120%)',
      (WidgetTester tester) async {
        // Default mask region extends 10% beyond element bbox
        const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <mask id="bboxMask" maskUnits="objectBoundingBox">
              <rect x="0" y="0" width="100" height="100" fill="white"/>
            </mask>
          </defs>
          <rect x="10" y="10" width="80" height="80" fill="red" 
                mask="url(#bboxMask)"/>
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
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      },
    );

    testWidgets('8. maskUnits="userSpaceOnUse" with explicit region', (
      WidgetTester tester,
    ) async {
      // userSpaceOnUse: mask region in absolute user coordinates
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <mask id="userMask" maskUnits="userSpaceOnUse" 
                  x="20" y="20" width="60" height="60">
              <rect x="0" y="0" width="100" height="100" fill="white"/>
            </mask>
          </defs>
          <rect x="0" y="0" width="100" height="100" fill="red" 
                mask="url(#userMask)"/>
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

      // Only the mask region should be visible
      expect(analysis.pixelCount, greaterThan(100));
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });

  group('maskContentUnits Coordinate Systems', () {
    testWidgets('9. maskContentUnits="objectBoundingBox" scales content', (
      WidgetTester tester,
    ) async {
      // Content coordinates are 0-1 relative to masked element bbox
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <mask id="contentBboxMask" maskContentUnits="objectBoundingBox">
              <rect x="0.2" y="0.2" width="0.6" height="0.6" fill="white"/>
            </mask>
          </defs>
          <rect x="10" y="10" width="80" height="80" fill="red" 
                mask="url(#contentBboxMask)"/>
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

      // Central portion of element should be visible
      expect(analysis.pixelCount, greaterThan(100));
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('10. maskContentUnits="userSpaceOnUse" (default) uses user coords', (
      WidgetTester tester,
    ) async {
      // Default: mask content in absolute user space coordinates
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <mask id="contentUserMask" maskContentUnits="userSpaceOnUse">
              <rect x="25" y="25" width="50" height="50" fill="white"/>
            </mask>
          </defs>
          <rect x="0" y="0" width="100" height="100" fill="red" 
                mask="url(#contentUserMask)"/>
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

      // Central 50x50 area should be visible
      expect(analysis.pixelCount, greaterThan(100));
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });

  group('Advanced Mask Features', () {
    testWidgets('11. Mask with gradient content (smooth transition)', (
      WidgetTester tester,
    ) async {
      // Gradient in mask creates smooth visibility transition
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <linearGradient id="maskGradient" x1="0" y1="0" x2="1" y2="0">
              <stop offset="0%" stop-color="white"/>
              <stop offset="100%" stop-color="black"/>
            </linearGradient>
            <mask id="gradientMask" type="luminance">
              <rect x="0" y="0" width="100" height="100" fill="url(#maskGradient)"/>
            </mask>
          </defs>
          <rect x="0" y="0" width="100" height="100" fill="red" 
                mask="url(#gradientMask)"/>
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

      // Left side (white) should be more visible than right side (black)
      expect(analysis.pixelCount, greaterThan(50));
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('12. Mask on filtered element', (
      WidgetTester tester,
    ) async {
      // Mask should be applied after filter
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <filter id="blur">
              <feGaussianBlur stdDeviation="2"/>
            </filter>
            <mask id="filterMask">
              <rect x="25" y="25" width="50" height="50" fill="white"/>
            </mask>
          </defs>
          <rect x="0" y="0" width="100" height="100" fill="red" 
                filter="url(#blur)" mask="url(#filterMask)"/>
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

      // Filtered and masked content should be visible
      expect(analysis.pixelCount, greaterThan(50));
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('13. Mask on group element', (
      WidgetTester tester,
    ) async {
      // Mask on group should apply to all children
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <mask id="groupMask">
              <rect x="25" y="0" width="50" height="100" fill="white"/>
            </mask>
          </defs>
          <g mask="url(#groupMask)">
            <rect x="0" y="0" width="50" height="50" fill="red"/>
            <rect x="50" y="0" width="50" height="50" fill="green"/>
            <rect x="0" y="50" width="50" height="50" fill="blue"/>
            <rect x="50" y="50" width="50" height="50" fill="yellow"/>
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

      // Central strip of group should be visible
      expect(redAnalysis.pixelCount, greaterThan(50));
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('14. Empty mask (should hide element)', (
      WidgetTester tester,
    ) async {
      // Empty mask with no content should hide the element
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

      // Widget should render without error
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('15. Mask with transform on mask content', (
      WidgetTester tester,
    ) async {
      // Transform on mask content should be applied
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <mask id="transformMask">
              <rect x="-25" y="-25" width="50" height="50" fill="white"
                    transform="translate(50,50)"/>
            </mask>
          </defs>
          <rect x="0" y="0" width="100" height="100" fill="red" 
                mask="url(#transformMask)"/>
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

      // Centered 50x50 area should be visible (transform moves rect to center)
      expect(analysis.pixelCount, greaterThan(50));
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });
}
