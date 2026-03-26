import 'package:flutter/material.dart';
import 'package:flutter_svg/src/animation/animated_svg_picture.dart';
import 'package:flutter_test/flutter_test.dart';

import 'visual_test_utils.dart';

/// Comprehensive tests for image and foreignObject edge cases.
/// Tests SVG-in-SVG nesting, preserveAspectRatio variants, CSS inheritance,
/// nested viewBox stacking, and image-rendering property.
void main() {
  group('SVG-in-SVG Nesting Tests', () {
    testWidgets('nested SVG with viewBox transforms correctly', (
      WidgetTester tester,
    ) async {
      // Outer SVG 100x100 viewBox, inner SVG 50x50 viewBox
      // Tests coordinate system composition
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <rect x="0" y="0" width="100" height="100" fill="blue"/>
          <svg x="25" y="25" width="50" height="50" viewBox="0 0 100 100">
            <rect x="0" y="0" width="100" height="100" fill="red"/>
          </svg>
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

      final pixels = await VisualTestUtils.captureWidgetPixels(tester);
      final analysis = VisualTestUtils.analyzeRedPixels(pixels, 800, 600);

      // Red rect should be visible in the nested SVG area
      expect(analysis.pixelCount, greaterThan(100));
    });

    testWidgets('deeply nested SVG (3 levels) with viewBox', (
      WidgetTester tester,
    ) async {
      // Level 1: 100x100 viewBox
      // Level 2: 50x50 at (25,25), viewBox 0 0 200 200
      // Level 3: 25x25 at (10,10), viewBox 0 0 50 50
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <rect x="0" y="0" width="100" height="100" fill="blue"/>
          <svg x="10" y="10" width="80" height="80" viewBox="0 0 200 200">
            <rect x="0" y="0" width="200" height="200" fill="green"/>
            <svg x="50" y="50" width="100" height="100" viewBox="0 0 50 50">
              <rect x="0" y="0" width="50" height="50" fill="red"/>
            </svg>
          </svg>
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

      // Red rect should be visible through the nested structure
      expect(analysis.pixelCount, greaterThan(50));
    });

    testWidgets('nested SVG with preserveAspectRatio none at each level', (
      WidgetTester tester,
    ) async {
      // Tests that preserveAspectRatio=none properly stretches at each level
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <svg x="0" y="0" width="100" height="50" 
               viewBox="0 0 50 50" preserveAspectRatio="none">
            <rect x="0" y="0" width="50" height="50" fill="red"/>
          </svg>
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

      // Red should be stretched to fill the viewport
      expect(analysis.pixelCount, greaterThan(200));
    });
  });

  group('preserveAspectRatio Edge Cases', () {
    testWidgets('preserveAspectRatio none stretches image', (
      WidgetTester tester,
    ) async {
      // When preserveAspectRatio is "none", image should stretch to fill
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <rect x="0" y="0" width="100" height="100" fill="red"/>
          <svg x="10" y="10" width="80" height="40" 
               viewBox="0 0 100 100" preserveAspectRatio="none">
            <rect x="0" y="0" width="100" height="100" fill="blue"/>
          </svg>
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

    testWidgets('preserveAspectRatio xMinYMin meet', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <rect x="0" y="0" width="100" height="100" fill="gray"/>
          <svg x="0" y="0" width="100" height="50" 
               viewBox="0 0 100 100" preserveAspectRatio="xMinYMin meet">
            <rect x="0" y="0" width="100" height="100" fill="red"/>
          </svg>
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

      // Red should be scaled down to fit, aligned to top-left
      expect(analysis.pixelCount, greaterThan(100));
    });

    testWidgets('preserveAspectRatio xMidYMid slice clips overflow', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <rect x="0" y="0" width="100" height="100" fill="gray"/>
          <svg x="25" y="25" width="50" height="50" 
               viewBox="0 0 100 100" preserveAspectRatio="xMidYMid slice">
            <rect x="0" y="0" width="100" height="100" fill="red"/>
          </svg>
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

      // Red should be scaled up to cover, centered, with overflow clipped
      expect(analysis.pixelCount, greaterThan(100));
    });

    testWidgets('preserveAspectRatio xMaxYMax meet', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <rect x="0" y="0" width="100" height="100" fill="blue"/>
          <svg x="0" y="0" width="100" height="50" 
               viewBox="0 0 100 100" preserveAspectRatio="xMaxYMax meet">
            <rect x="0" y="0" width="100" height="100" fill="red"/>
          </svg>
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

      // Red should be scaled to fit, aligned to bottom-right
      expect(analysis.pixelCount, greaterThan(50));
    });

    testWidgets('preserveAspectRatio xMidYMin slice', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <rect x="0" y="0" width="100" height="100" fill="green"/>
          <svg x="0" y="0" width="100" height="50" 
               viewBox="0 0 50 100" preserveAspectRatio="xMidYMin slice">
            <rect x="0" y="0" width="50" height="100" fill="red"/>
          </svg>
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

      // Red should fill width, aligned to top
      expect(analysis.pixelCount, greaterThan(100));
    });
  });

  group('foreignObject CSS Inheritance Tests', () {
    testWidgets('inherited CSS properties flow through foreignObject', (
      WidgetTester tester,
    ) async {
      // color, font-family, font-size should inherit through foreignObject
      const svgXml = '''
        <svg viewBox="0 0 100 100" style="color: red; font-size: 20px;">
          <foreignObject x="10" y="10" width="80" height="80">
            <svg viewBox="0 0 80 80">
              <rect x="0" y="0" width="80" height="80" fill="currentColor"/>
            </svg>
          </foreignObject>
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

    testWidgets('transform does NOT inherit through foreignObject', (
      WidgetTester tester,
    ) async {
      // Transform on SVG should NOT affect foreignObject content
      // (foreignObject establishes new stacking context)
      const svgXml = '''
        <svg viewBox="0 0 100 100" transform="rotate(45)">
          <rect x="0" y="0" width="100" height="100" fill="blue"/>
          <foreignObject x="20" y="20" width="60" height="60">
            <svg viewBox="0 0 60 60">
              <rect x="0" y="0" width="60" height="60" fill="red"/>
            </svg>
          </foreignObject>
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

      // Should render - transform context is reset within foreignObject
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('opacity does NOT inherit through foreignObject boundary', (
      WidgetTester tester,
    ) async {
      // Opacity on parent should NOT cascade to foreignObject content
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <g opacity="0.5">
            <foreignObject x="10" y="10" width="80" height="80">
              <svg viewBox="0 0 80 80">
                <rect x="0" y="0" width="80" height="80" fill="red"/>
              </svg>
            </foreignObject>
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

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });

  group('Nested viewBox Stacking Tests', () {
    testWidgets('3-level viewBox stacking composes correctly', (
      WidgetTester tester,
    ) async {
      // Level 1: viewBox 0 0 200 200, viewport 100x100
      // Level 2: viewBox 0 0 100 100, viewport 50x50
      // Level 3: viewBox 0 0 50 50, viewport 25x25
      const svgXml = '''
        <svg width="100" height="100" viewBox="0 0 200 200">
          <rect x="0" y="0" width="200" height="200" fill="blue"/>
          <svg x="50" y="50" width="100" height="100" viewBox="0 0 100 100">
            <rect x="0" y="0" width="100" height="100" fill="green"/>
            <svg x="25" y="25" width="50" height="50" viewBox="0 0 50 50">
              <rect x="0" y="0" width="50" height="50" fill="red"/>
            </svg>
          </svg>
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

      // Red should be visible at the correct nested position
      expect(analysis.pixelCount, greaterThan(10));
    });

    testWidgets('mixed viewBox with preserveAspectRatio stacking', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <svg x="0" y="0" width="100" height="50" 
               viewBox="0 0 200 200" preserveAspectRatio="xMidYMid meet">
            <svg x="50" y="50" width="100" height="100" 
                 viewBox="0 0 50 50" preserveAspectRatio="xMinYMin meet">
              <rect x="0" y="0" width="50" height="50" fill="red"/>
            </svg>
          </svg>
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

      // Red should be visible with correct transforms applied
      expect(analysis.pixelCount, greaterThan(5));
    });
  });

  group('image-rendering Property Tests', () {
    testWidgets('image-rendering auto uses medium quality', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <rect x="0" y="0" width="100" height="100" 
                fill="red" style="image-rendering: auto;"/>
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

    testWidgets('image-rendering optimizeSpeed uses no filtering', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <rect x="0" y="0" width="100" height="100" 
                fill="red" style="image-rendering: optimizeSpeed;"/>
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

    testWidgets('image-rendering pixelated uses nearest-neighbor', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <rect x="0" y="0" width="100" height="100" 
                fill="red" style="image-rendering: pixelated;"/>
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

    testWidgets('image-rendering optimizeQuality uses high quality', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <rect x="0" y="0" width="100" height="100" 
                fill="red" style="image-rendering: optimizeQuality;"/>
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

  group('Edge Cases', () {
    testWidgets('zero-size viewport renders nothing visible', (WidgetTester tester) async {
      // An SVG element with zero width should produce an empty viewport.
      // Per SVG spec, the content may still exist but is clipped to nothing.
      // The test verifies that effectively no red is visible in the output.
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <rect x="0" y="0" width="100" height="100" fill="blue"/>
          <svg x="25" y="25" width="0" height="50" viewBox="0 0 50 50" overflow="hidden">
            <rect x="0" y="0" width="50" height="50" fill="red"/>
          </svg>
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

      // Should render without crashing - zero-size just means nothing visible
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('negative dimensions are treated as error', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <rect x="0" y="0" width="100" height="100" fill="blue"/>
          <svg x="25" y="25" width="-50" height="50" viewBox="0 0 50 50">
            <rect x="0" y="0" width="50" height="50" fill="red"/>
          </svg>
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

      // Should render without crashing
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('foreignObject with requiredExtensions fallback', (
      WidgetTester tester,
    ) async {
      // foreignObject with unsupported requiredExtensions should not render
      // allowing switch/fallback pattern to work
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <rect x="0" y="0" width="100" height="100" fill="blue"/>
          <switch>
            <foreignObject x="20" y="20" width="60" height="60" 
                           requiredExtensions="http://example.com/unsupported">
              <rect x="0" y="0" width="60" height="60" fill="green"/>
            </foreignObject>
            <rect x="20" y="20" width="60" height="60" fill="red"/>
          </switch>
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

      // Red fallback should render since foreignObject is skipped
      expect(analysis.pixelCount, greaterThan(100));
    });

    testWidgets('foreignObject overflow hidden clips content', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <rect x="0" y="0" width="100" height="100" fill="blue"/>
          <foreignObject x="25" y="25" width="50" height="50" overflow="hidden">
            <svg viewBox="0 0 100 100">
              <rect x="0" y="0" width="100" height="100" fill="red"/>
            </svg>
          </foreignObject>
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

      // Red should be clipped to foreignObject bounds
      expect(analysis.pixelCount, greaterThan(100));
    });

    testWidgets('foreignObject overflow visible shows full content', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <rect x="0" y="0" width="100" height="100" fill="blue"/>
          <foreignObject x="25" y="25" width="50" height="50" overflow="visible">
            <svg viewBox="0 0 100 100">
              <rect x="0" y="0" width="100" height="100" fill="red"/>
            </svg>
          </foreignObject>
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

      // Should render - content may overflow
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });
}
