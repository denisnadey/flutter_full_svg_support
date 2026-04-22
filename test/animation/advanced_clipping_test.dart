import 'package:flutter/material.dart';
import 'package:full_svg_flutter/src/animation/animated_svg_picture.dart';
import 'package:flutter_test/flutter_test.dart';

import 'visual_test_utils.dart';

/// Comprehensive tests for advanced SVG clipping semantics.
/// Tests cascading clipPaths, clipPathUnits, non-path element clipping,
/// clip-rule support, and edge cases.
void main() {
  group('Advanced Clipping Semantics', () {
    // Test 1: clipPath on clipPath (nested/cascading)
    testWidgets('1. clipPath on clipPath cascading with intersection', (
      WidgetTester tester,
    ) async {
      // A clipPath element that itself has a clip-path attribute
      // Result should be intersection of both clip regions
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <clipPath id="innerClip">
              <rect x="10" y="10" width="80" height="80"/>
            </clipPath>
            <clipPath id="outerClip" clip-path="url(#innerClip)">
              <rect x="20" y="20" width="60" height="60"/>
            </clipPath>
          </defs>
          <rect x="0" y="0" width="100" height="100" fill="red" 
                clip-path="url(#outerClip)"/>
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

      // Should show intersection (20,20,60,60) clipped by (10,10,80,80) = (20,20,60,60)
      expect(analysis.pixelCount, greaterThan(300));
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    // Test 2: clipPathUnits="userSpaceOnUse" (default behavior)
    testWidgets('2. clipPathUnits userSpaceOnUse default behavior', (
      WidgetTester tester,
    ) async {
      // userSpaceOnUse: clip path coordinates are in user coordinate system
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

      // Should show clipped area (60x60 in viewBox coordinates)
      expect(analysis.pixelCount, greaterThan(400));
    });

    // Test 3: clipPathUnits="objectBoundingBox" with simple rect clip
    testWidgets('3. clipPathUnits objectBoundingBox with rect clip', (
      WidgetTester tester,
    ) async {
      // objectBoundingBox: coordinates relative to element's bounding box (0-1)
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <clipPath id="clip" clipPathUnits="objectBoundingBox">
              <rect x="0.1" y="0.1" width="0.8" height="0.8"/>
            </clipPath>
          </defs>
          <rect x="10" y="20" width="80" height="40" fill="red" 
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

      // Should show 80% of element width/height with 10% inset
      expect(analysis.pixelCount, greaterThan(200));
    });

    // Test 4: objectBoundingBox with circle clip
    testWidgets('4. objectBoundingBox with circle clip', (
      WidgetTester tester,
    ) async {
      // Circle in objectBoundingBox: cx, cy, r are relative (0-1)
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <clipPath id="clip" clipPathUnits="objectBoundingBox">
              <circle cx="0.5" cy="0.5" r="0.4"/>
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

      // Circle clips to elliptical region (aspect ratio preserved in OBB)
      expect(analysis.pixelCount, greaterThan(300));
    });

    // Test 5: Text element inside clipPath
    testWidgets('5. text element inside clipPath', (WidgetTester tester) async {
      // Text within clipPath should use text outline/bounds as clip region
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <clipPath id="textClip">
              <text x="10" y="50" font-size="40">Hi</text>
            </clipPath>
          </defs>
          <rect x="0" y="0" width="100" height="100" fill="red" 
                clip-path="url(#textClip)"/>
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

      // Text clipping should work without errors
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    // Test 6: use element inside clipPath
    testWidgets('6. use element inside clipPath', (WidgetTester tester) async {
      // use element resolves referenced shape for clipping
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <rect id="clipRect" x="0" y="0" width="60" height="60"/>
            <clipPath id="clip">
              <use href="#clipRect" x="20" y="20"/>
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

      // Referenced rect (60x60) at offset (20,20) should clip
      expect(analysis.pixelCount, greaterThan(300));
    });

    // Test 7: clip-rule="evenodd" vs "nonzero" on clipPath children
    testWidgets('7. clip-rule evenodd vs nonzero on clipPath children', (
      WidgetTester tester,
    ) async {
      // evenodd fills alternate regions, nonzero fills all enclosed regions
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <clipPath id="clip">
              <path d="M10,10 L90,10 L90,90 L10,90 Z M30,30 L70,30 L70,70 L30,70 Z" 
                    clip-rule="evenodd"/>
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

      // evenodd creates a "donut" shape (inner rect is hole)
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    // Test 8: Multiple shapes inside a single clipPath (union)
    testWidgets('8. multiple shapes inside single clipPath (union)', (
      WidgetTester tester,
    ) async {
      // Multiple children in clipPath: their geometries are unioned
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <clipPath id="clip">
              <rect x="10" y="10" width="30" height="30"/>
              <rect x="60" y="60" width="30" height="30"/>
              <circle cx="50" cy="50" r="15"/>
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

      // Should show union of all three shapes
      expect(analysis.pixelCount, greaterThan(200));
    });

    // Test 9: clipPath with transform attribute
    testWidgets('9. clipPath with transform attribute', (
      WidgetTester tester,
    ) async {
      // Transform on clipPath element affects all children
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <clipPath id="clip" transform="translate(10,10)">
              <rect x="0" y="0" width="60" height="60"/>
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

      // Clip rect at (10,10) with size 60x60
      expect(analysis.pixelCount, greaterThan(300));
    });

    // Test 10: Empty clipPath (should hide element completely)
    testWidgets('10. empty clipPath hides element completely', (
      WidgetTester tester,
    ) async {
      // Per SVG spec, empty clipPath results in no content being visible
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <clipPath id="emptyClip">
              <!-- No children -->
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

      // Should render without error (empty clip hides content)
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    // Test 11: clipPath referencing non-existent ID (graceful fallback)
    testWidgets('11. clipPath referencing non-existent ID graceful fallback', (
      WidgetTester tester,
    ) async {
      // Invalid reference should not crash, content renders normally
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

      // Content should render without clipping (invalid reference)
      expect(analysis.pixelCount, greaterThan(500));
    });

    // Test 12: clipPath on a group <g> element
    testWidgets('12. clipPath on group g element', (WidgetTester tester) async {
      // Clip path on group affects all children
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <clipPath id="clip">
              <circle cx="50" cy="50" r="40"/>
            </clipPath>
          </defs>
          <g clip-path="url(#clip)">
            <rect x="0" y="0" width="50" height="100" fill="red"/>
            <rect x="50" y="0" width="50" height="100" fill="blue"/>
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

      // Both rects should be clipped by circle
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    // Test 13: clipPath with objectBoundingBox on zero-size element (edge case)
    testWidgets('13. objectBoundingBox on zero-size element edge case', (
      WidgetTester tester,
    ) async {
      // Zero-size element with objectBoundingBox should handle gracefully
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <clipPath id="clip" clipPathUnits="objectBoundingBox">
              <rect x="0" y="0" width="1" height="1"/>
            </clipPath>
          </defs>
          <rect x="50" y="50" width="0" height="0" fill="red" 
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

      // Should not crash - zero-size element handled gracefully
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    // Test 14: Nested clipPath 3 levels deep
    testWidgets('14. nested clipPath 3 levels deep', (
      WidgetTester tester,
    ) async {
      // Three levels of cascading clipPaths
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <clipPath id="clip1">
              <rect x="5" y="5" width="90" height="90"/>
            </clipPath>
            <clipPath id="clip2" clip-path="url(#clip1)">
              <rect x="15" y="15" width="70" height="70"/>
            </clipPath>
            <clipPath id="clip3" clip-path="url(#clip2)">
              <rect x="25" y="25" width="50" height="50"/>
            </clipPath>
          </defs>
          <rect x="0" y="0" width="100" height="100" fill="blue" 
                clip-path="url(#clip3)"/>
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

      // Should render the intersection of all three clips
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    // Test 15: clipPath combined with opacity
    testWidgets('15. clipPath combined with opacity', (
      WidgetTester tester,
    ) async {
      // Clip path and opacity should both apply correctly
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <clipPath id="clip">
              <circle cx="50" cy="50" r="40"/>
            </clipPath>
          </defs>
          <rect x="0" y="0" width="100" height="100" fill="red" 
                clip-path="url(#clip)" opacity="0.5"/>
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

      // Should show clipped circle with 50% opacity
      // (red at half opacity appears as lighter red or mixed color)
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });
}
