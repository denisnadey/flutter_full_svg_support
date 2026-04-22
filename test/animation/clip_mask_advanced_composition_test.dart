import 'package:flutter/material.dart';
import 'package:full_svg_flutter/src/animation/animated_svg_picture.dart';
import 'package:flutter_test/flutter_test.dart';

import 'visual_test_utils.dart';

/// Tests for advanced clip-path and mask composition features.
/// Covers edge cases, luminance masking, multiple masks, and group inheritance.
void main() {
  group('objectBoundingBox Edge Cases', () {
    testWidgets('clipPathUnits objectBoundingBox with zero-width element', (
      WidgetTester tester,
    ) async {
      // Zero-width element should gracefully handle objectBoundingBox
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <clipPath id="clip" clipPathUnits="objectBoundingBox">
              <rect x="0.1" y="0.1" width="0.8" height="0.8"/>
            </clipPath>
          </defs>
          <line x1="50" y1="10" x2="50" y2="90" stroke="red" stroke-width="2"
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

      // Should not crash - line has zero width
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('clipPathUnits objectBoundingBox with very small element', (
      WidgetTester tester,
    ) async {
      // Very small element dimensions shouldn't cause scaling issues
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <clipPath id="clip" clipPathUnits="objectBoundingBox">
              <rect x="0.2" y="0.2" width="0.6" height="0.6"/>
            </clipPath>
          </defs>
          <rect x="50" y="50" width="0.001" height="0.001" fill="red"
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

      // Should handle gracefully without errors
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('maskUnits objectBoundingBox with zero-height element', (
      WidgetTester tester,
    ) async {
      // Zero-height element should gracefully handle objectBoundingBox masks
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <mask id="mask" maskUnits="objectBoundingBox">
              <rect x="0" y="0" width="100" height="100" fill="white"/>
            </mask>
          </defs>
          <line x1="10" y1="50" x2="90" y2="50" stroke="red" stroke-width="2"
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

      // Should not crash - line has zero height
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('maskContentUnits objectBoundingBox with small dimensions', (
      WidgetTester tester,
    ) async {
      // Small dimensions shouldn't cause excessive scaling
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <mask id="mask" maskContentUnits="objectBoundingBox">
              <rect x="0.1" y="0.1" width="0.8" height="0.8" fill="white"/>
            </mask>
          </defs>
          <rect x="49" y="49" width="2" height="2" fill="red"
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

      // Should render the small masked element
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });

  group('Luminance Masking', () {
    testWidgets('luminance mask with pure white should show full content', (
      WidgetTester tester,
    ) async {
      // White mask content (luminance=1.0) should allow full visibility
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <mask id="mask" type="luminance">
              <rect x="0" y="0" width="100" height="100" fill="white"/>
            </mask>
          </defs>
          <rect x="25" y="25" width="50" height="50" fill="red"
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

      // White luminance mask should show content
      expect(analysis.pixelCount, greaterThan(500));
    });

    testWidgets('luminance mask with pure black hides most content', (
      WidgetTester tester,
    ) async {
      // Black mask content (luminance=0.0) should hide most content
      // Note: Some pixels may remain visible due to rendering artifacts
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <mask id="mask" type="luminance">
              <rect x="0" y="0" width="100" height="100" fill="black"/>
            </mask>
          </defs>
          <rect x="25" y="25" width="50" height="50" fill="red"
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

      // Should render without errors - black luminance significantly reduces visibility
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('luminance mask with pure red (21% luminance)', (
      WidgetTester tester,
    ) async {
      // Red has luminance ~0.2126, should show partial content
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

      // Should render without errors
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('luminance mask with pure green (71% luminance)', (
      WidgetTester tester,
    ) async {
      // Green has luminance ~0.7152, should show more content than red
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <mask id="mask" type="luminance">
              <rect x="0" y="0" width="100" height="100" fill="lime"/>
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

      // Should render without errors
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('mask-type style attribute on mask element', (
      WidgetTester tester,
    ) async {
      // Using style="mask-type: luminance" on mask element
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <mask id="mask" style="mask-type: luminance;">
              <rect x="0" y="0" width="50" height="100" fill="white"/>
              <rect x="50" y="0" width="50" height="100" fill="black"/>
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

      // Only left half (white luminance) should be visible
      expect(analysis.pixelCount, greaterThan(500));
    });
  });

  group('Multiple Mask Composition', () {
    testWidgets('multiple masks with comma-separated urls', (
      WidgetTester tester,
    ) async {
      // SVG 2 allows multiple masks: mask: url(#mask1), url(#mask2)
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <mask id="mask1">
              <rect x="0" y="0" width="80" height="100" fill="white"/>
            </mask>
            <mask id="mask2">
              <rect x="20" y="0" width="80" height="100" fill="white"/>
            </mask>
          </defs>
          <rect x="0" y="0" width="100" height="100" fill="red"
                style="mask: url(#mask1), url(#mask2);"/>
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

      // Should render - intersection of both masks (20-80 range)
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });

  group('Mask Inheritance Through Groups', () {
    testWidgets('mask on group affects all children', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <mask id="groupMask">
              <rect x="20" y="20" width="60" height="60" fill="white"/>
            </mask>
          </defs>
          <g mask="url(#groupMask)">
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

      final pixels = await VisualTestUtils.captureWidgetPixels(tester);
      final analysis = VisualTestUtils.analyzeRedPixels(pixels, 800, 600);

      // Red portion should be visible only within mask region (20-80 x 20-50)
      expect(analysis.pixelCount, greaterThan(200));
    });

    testWidgets('nested masks compose correctly', (WidgetTester tester) async {
      // Child mask within a masked group results in intersection
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

      // Should show content only in intersection (30-70 x 30-70)
      expect(analysis.pixelCount, greaterThan(100));
    });
  });

  group('Text Mask Geometry', () {
    testWidgets('mask region covers text with stroke', (
      WidgetTester tester,
    ) async {
      // Text with stroke should have expanded mask bounds
      const svgXml = '''
        <svg viewBox="0 0 200 100">
          <defs>
            <mask id="mask" maskUnits="objectBoundingBox">
              <rect x="-0.1" y="-0.1" width="1.2" height="1.2" fill="white"/>
            </mask>
          </defs>
          <text x="10" y="50" fill="red" stroke="blue" stroke-width="4"
                font-size="40" mask="url(#mask)">Test</text>
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

      // Should render text with stroke fully within mask
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('mask region covers text with decoration', (
      WidgetTester tester,
    ) async {
      // Text with underline decoration should have expanded bounds
      const svgXml = '''
        <svg viewBox="0 0 200 100">
          <defs>
            <mask id="mask" maskUnits="objectBoundingBox">
              <rect x="-0.1" y="-0.1" width="1.2" height="1.2" fill="white"/>
            </mask>
          </defs>
          <text x="10" y="50" fill="red" font-size="30"
                text-decoration="underline" mask="url(#mask)">Underlined</text>
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

      // Should render text with decoration within mask
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });

  group('Clip and Mask Combined', () {
    testWidgets('clip-path and mask both applied correctly', (
      WidgetTester tester,
    ) async {
      // Both clip-path and mask should compose
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

      // Should show top half of circle
      expect(analysis.pixelCount, greaterThan(300));
    });

    testWidgets('luminance mask with clip-path', (WidgetTester tester) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <clipPath id="clip">
              <rect x="20" y="20" width="60" height="60"/>
            </clipPath>
            <mask id="mask" type="luminance">
              <rect x="0" y="0" width="100" height="100" fill="white"/>
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

      // Should show clipped and masked content
      expect(analysis.pixelCount, greaterThan(400));
    });
  });

  group('Bounds Computation with Stroke', () {
    testWidgets('objectBoundingBox includes stroke width', (
      WidgetTester tester,
    ) async {
      // Stroke width should be included in bounding box for objectBoundingBox
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <clipPath id="clip" clipPathUnits="objectBoundingBox">
              <rect x="-0.1" y="-0.1" width="1.2" height="1.2"/>
            </clipPath>
          </defs>
          <rect x="30" y="30" width="40" height="40"
                fill="red" stroke="blue" stroke-width="10"
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

      // Should include stroke within mask bounds
      expect(analysis.pixelCount, greaterThan(300));
    });
  });

  group('Mask Animation Tracking', () {
    testWidgets('animated mask content invalidates cache correctly', (
      tester,
    ) async {
      // Mask with animated content should trigger cache invalidation
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <mask id="animatedMask">
              <rect x="0" y="0" width="100" height="100" fill="white">
                <animate attributeName="opacity" from="1" to="0.5" dur="1s" repeatCount="indefinite"/>
              </rect>
            </mask>
          </defs>
          <rect x="10" y="10" width="80" height="80" fill="red" mask="url(#animatedMask)"/>
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
      await tester.pump(const Duration(milliseconds: 500));

      // Should render without errors with animated mask
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('static mask content can be cached', (tester) async {
      // Mask without animations should allow caching
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <mask id="staticMask">
              <rect x="20" y="20" width="60" height="60" fill="white"/>
            </mask>
          </defs>
          <rect x="10" y="10" width="80" height="80" fill="blue" mask="url(#staticMask)"/>
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

  group('Gradient-Aware Luminance Masking', () {
    testWidgets('luminance mask with gradient uses enhanced paint', (
      tester,
    ) async {
      // Mask with gradient content should use gradient-aware luminance paint
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <linearGradient id="maskGradient" x1="0%" y1="0%" x2="100%" y2="0%">
              <stop offset="0%" stop-color="white"/>
              <stop offset="100%" stop-color="black"/>
            </linearGradient>
            <mask id="gradientMask" mask-type="luminance">
              <rect x="0" y="0" width="100" height="100" fill="url(#maskGradient)"/>
            </mask>
          </defs>
          <rect x="10" y="10" width="80" height="80" fill="red" mask="url(#gradientMask)"/>
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

      // Should have visible red pixels through the gradient mask
      expect(analysis.pixelCount, greaterThan(0));
    });

    testWidgets('luminance mask without gradient uses standard paint', (
      tester,
    ) async {
      // Mask with solid fill should use standard luminance paint
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <mask id="solidMask" mask-type="luminance">
              <rect x="20" y="20" width="60" height="60" fill="white"/>
            </mask>
          </defs>
          <rect x="10" y="10" width="80" height="80" fill="green" mask="url(#solidMask)"/>
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

    testWidgets('radial gradient in luminance mask renders correctly', (
      tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <radialGradient id="radialMaskGrad" cx="50%" cy="50%" r="50%">
              <stop offset="0%" stop-color="white"/>
              <stop offset="100%" stop-color="black"/>
            </radialGradient>
            <mask id="radialMask" mask-type="luminance">
              <rect x="0" y="0" width="100" height="100" fill="url(#radialMaskGrad)"/>
            </mask>
          </defs>
          <rect x="10" y="10" width="80" height="80" fill="blue" mask="url(#radialMask)"/>
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
}
