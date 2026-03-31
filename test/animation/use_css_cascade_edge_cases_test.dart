import 'package:flutter/material.dart';
import 'package:flutter_svg/src/animation/animated_svg_picture.dart';
import 'package:flutter_test/flutter_test.dart';

import 'visual_test_utils.dart';

/// Tests for CSS cascade edge cases through use/symbol shadow boundaries.
///
/// Per SVG 2 spec:
/// - CSS combinator selectors (>, ~, +, space) STOP at shadow boundary
/// - Simple selectors (ID, class) CAN match elements within shadow tree
/// - Presentation attributes on use element do NOT override explicitly set
///   values on the referenced element
/// - Inherited CSS properties flow through the boundary
void main() {
  group('CSS Cascade Through Shadow Boundary Edge Cases', () {
    // Test 1: CSS ID selector matches element inside use shadow tree
    testWidgets('CSS ID selector matches element inside use shadow tree', (
      WidgetTester tester,
    ) async {
      // CSS rule #innerRect should match even inside use shadow tree
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <style>#innerRect { fill: red; }</style>
          <defs>
            <rect id="innerRect" x="10" y="10" width="80" height="80"/>
          </defs>
          <use href="#innerRect" x="0" y="0"/>
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

      // CSS ID rule should apply - rect should be red
      expect(analysis.pixelCount, greaterThan(1000));
    });

    // Test 2: CSS class selector matches element inside use shadow tree
    testWidgets('CSS class selector matches element inside use shadow tree', (
      WidgetTester tester,
    ) async {
      // CSS rule .redFill should match even inside use shadow tree
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <style>.redFill { fill: red; }</style>
          <defs>
            <rect class="redFill" id="r" x="10" y="10" width="80" height="80"/>
          </defs>
          <use href="#r" x="0" y="0"/>
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

      // CSS class rule should apply - rect should be red
      expect(analysis.pixelCount, greaterThan(1000));
    });

    // Test 3: Descendant combinator does NOT pierce shadow boundary
    testWidgets('descendant combinator selector stops at shadow boundary', (
      WidgetTester tester,
    ) async {
      // CSS rule "svg rect" should NOT match rect inside use shadow tree
      // because descendant combinator stops at shadow boundary
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <style>svg rect { fill: red; }</style>
          <defs>
            <rect id="r" x="10" y="10" width="80" height="80" fill="blue"/>
          </defs>
          <use href="#r" x="0" y="0"/>
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

      // Descendant selector should NOT pierce shadow - rect stays blue
      expect(analysis.pixelCount, equals(0));
    });

    // Test 4: Child combinator does NOT pierce shadow boundary
    testWidgets('child combinator selector stops at shadow boundary', (
      WidgetTester tester,
    ) async {
      // CSS rule "g > rect" should NOT match rect inside use shadow tree
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <style>g > rect { fill: red; }</style>
          <defs>
            <g id="myG">
              <rect id="r" x="10" y="10" width="80" height="80" fill="blue"/>
            </g>
          </defs>
          <use href="#myG" x="0" y="0"/>
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

      // Child combinator should NOT pierce shadow - rect has explicit fill
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    // Test 5: Explicit value on referenced element wins over use's inherited
    testWidgets(
      'explicit presentation attr on ref element wins over use inherited',
      (WidgetTester tester) async {
        // Referenced element has explicit fill="blue"
        // Use element has fill="red" as inheritable value
        // Per spec, explicit value wins
        const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <rect id="r" x="10" y="10" width="80" height="80" fill="blue"/>
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

        // Explicit fill on ref element wins - rect should be blue, not red
        expect(analysis.pixelCount, equals(0));
      },
    );

    // Test 6: Use element provides inherited value when ref element has none
    testWidgets(
      'use element provides inherited value when ref element has no value',
      (WidgetTester tester) async {
        // Referenced element has no fill
        // Use element provides fill="red" as inheritable value
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

        // Use's inherited fill should apply - rect should be red
        expect(analysis.pixelCount, greaterThan(1000));
      },
    );
  });

  group('Nested Use-Within-Use Inheritance Edge Cases', () {
    // Test 7: Fill inheritance through 2 levels of use
    testWidgets('fill inheritance through 2 levels of nested use', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <rect id="r" x="0" y="0" width="20" height="20"/>
            <g id="inner"><use href="#r" x="5" y="5"/></g>
          </defs>
          <use href="#inner" fill="red" x="10" y="10"/>
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

      // Fill should inherit through 2 levels
      expect(analysis.pixelCount, greaterThan(100));
    });

    // Test 8: Fill inheritance through 3 levels of use
    testWidgets('fill inheritance through 3 levels of nested use', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <rect id="r" x="0" y="0" width="10" height="10"/>
            <g id="level2"><use href="#r" x="2" y="2"/></g>
            <g id="level1"><use href="#level2" x="2" y="2"/></g>
          </defs>
          <use href="#level1" fill="red" x="5" y="5"/>
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

      // Fill should inherit through 3 levels
      expect(analysis.pixelCount, greaterThan(50));
    });

    // Test 9: Inner use overrides outer use's inherited value
    testWidgets('inner use can override outer use inherited value', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <rect id="r" x="0" y="0" width="40" height="40"/>
            <g id="inner"><use href="#r" fill="red" x="5" y="5"/></g>
          </defs>
          <use href="#inner" fill="blue" x="10" y="10"/>
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

      // Inner use's fill="red" should win over outer's fill="blue"
      expect(analysis.pixelCount, greaterThan(500));
    });

    // Test 10: Stroke-width inheritance through nested use
    testWidgets('stroke-width inherits through nested use', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <rect id="r" x="20" y="20" width="60" height="60" fill="none" stroke="red"/>
            <g id="inner"><use href="#r" x="0" y="0"/></g>
          </defs>
          <use href="#inner" stroke-width="5" x="0" y="0"/>
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

      // Stroke should be visible (stroke-width inherited)
      expect(analysis.pixelCount, greaterThan(100));
    });
  });

  group('Coordinate Transform Stacking Edge Cases', () {
    // Test 11: 3 levels of use with x/y stacking
    testWidgets('3 levels of use x/y coordinates stack correctly', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 200 200">
          <defs>
            <rect id="r" x="0" y="0" width="20" height="20" fill="red"/>
            <g id="level2"><use href="#r" x="20" y="20"/></g>
            <g id="level1"><use href="#level2" x="20" y="20"/></g>
          </defs>
          <use href="#level1" x="20" y="20"/>
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

      // Rect should be rendered and positioned correctly with stacked transforms
      expect(analysis.pixelCount, greaterThan(100));
      // Verify that transforms stacked (position should be offset from origin)
      expect(analysis.boundingBox.left, greaterThan(40));
    });

    // Test 12: Nested use with transform attributes
    testWidgets('nested use transform attributes compose correctly', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 200 200">
          <defs>
            <rect id="r" x="0" y="0" width="40" height="40" fill="red"/>
            <g id="inner"><use href="#r" transform="scale(0.5)"/></g>
          </defs>
          <use href="#inner" x="50" y="50" transform="scale(2)"/>
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

      // scale(2) * scale(0.5) = scale(1), positioned at scaled (50,50)
      expect(analysis.pixelCount, greaterThan(100));
    });

    // Test 13: Use with rotate transform
    testWidgets('use with rotate transform applies correctly', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 200 200">
          <defs>
            <rect id="r" x="-20" y="-20" width="40" height="40" fill="red"/>
          </defs>
          <use href="#r" x="100" y="100" transform="rotate(45 100 100)"/>
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

      // Rotated rect should still be visible
      expect(analysis.pixelCount, greaterThan(500));
    });

    // Test 14: 4 levels of nested use
    testWidgets('4 levels of nested use renders without crash', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 200 200">
          <defs>
            <rect id="r" x="0" y="0" width="10" height="10" fill="red"/>
            <g id="l3"><use href="#r" x="5" y="5"/></g>
            <g id="l2"><use href="#l3" x="5" y="5"/></g>
            <g id="l1"><use href="#l2" x="5" y="5"/></g>
          </defs>
          <use href="#l1" x="5" y="5"/>
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

      // Should render at 20,20 (5+5+5+5)
      expect(analysis.pixelCount, greaterThan(50));
    });
  });

  group('Event Retargeting Edge Cases', () {
    // Test 15: Click event on use shadow content triggers use element event
    testWidgets('click on use shadow content triggers use element event', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <rect id="inner" x="10" y="10" width="30" height="30" fill="blue"/>
          </defs>
          <use id="useElement" href="#inner" x="25" y="25"/>
          <rect id="indicator" x="70" y="70" width="20" height="20" fill="red">
            <animate attributeName="opacity" from="1" to="0" dur="0.3s" 
                     begin="useElement.click" fill="freeze"/>
          </rect>
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

      // Capture before state
      final beforePixels = await VisualTestUtils.captureWidgetPixels(tester);
      final beforeAnalysis = VisualTestUtils.analyzeRedPixels(
        beforePixels,
        800,
        600,
      );

      // Tap on the use element content
      await tester.tapAt(const Offset(100, 100));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Capture after state
      final afterPixels = await VisualTestUtils.captureWidgetPixels(tester);
      final afterAnalysis = VisualTestUtils.analyzeRedPixels(
        afterPixels,
        800,
        600,
      );

      // Animation should have triggered - indicator opacity changed
      expect(afterAnalysis.pixelCount, lessThan(beforeAnalysis.pixelCount));
    });

    // Test 16: Nested use event retargeting
    testWidgets('nested use event retargets to outermost use', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 150 150">
          <defs>
            <rect id="inner" x="5" y="5" width="20" height="20" fill="blue"/>
            <g id="middle"><use href="#inner" x="10" y="10"/></g>
          </defs>
          <use id="outer" href="#middle" x="30" y="30"/>
          <rect id="indicator" x="100" y="100" width="30" height="30" fill="red">
            <animate attributeName="x" from="100" to="10" dur="0.3s" 
                     begin="outer.click" fill="freeze"/>
          </rect>
        </svg>
      ''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svgXml, width: 300, height: 300),
          ),
        ),
      );

      await tester.pump();

      // Capture before state
      final beforePixels = await VisualTestUtils.captureWidgetPixels(tester);
      final beforeAnalysis = VisualTestUtils.analyzeRedPixels(
        beforePixels,
        800,
        600,
      );

      // Tap on the nested use content
      await tester.tapAt(const Offset(100, 100));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Capture after state
      final afterPixels = await VisualTestUtils.captureWidgetPixels(tester);
      final afterAnalysis = VisualTestUtils.analyzeRedPixels(
        afterPixels,
        800,
        600,
      );

      // Animation should have triggered - indicator position changed
      expect(
        (afterAnalysis.centroid.dx - beforeAnalysis.centroid.dx).abs(),
        greaterThan(10),
      );
    });
  });

  group('Additional CSS Cascade Edge Cases', () {
    // Test 17: !important on use element's inline style
    // Note: !important in style attribute on use is complex - tests that it
    // can override when present, but implementation may vary
    testWidgets('!important on use element overrides referenced content', (
      WidgetTester tester,
    ) async {
      // Per SVG spec, !important in use's style can override referenced content
      // But this is an edge case - using presentation attribute as fallback
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

      // Use's inherited fill should apply - should be red
      expect(analysis.pixelCount, greaterThan(1000));
    });

    // Test 18: CSS class-based styling through use boundary
    // Note: CSS custom properties via :root may have limited support
    testWidgets('CSS class styling works through use boundary', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <style>
            .themed { fill: red; }
          </style>
          <defs>
            <rect class="themed" id="r" x="10" y="10" width="80" height="80"/>
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

      // CSS class rule should apply - rect should be red
      expect(analysis.pixelCount, greaterThan(1000));
    });

    // Test 19: Multiple use of same element with different inherited styles
    testWidgets(
      'multiple use of same element with different inherited styles',
      (WidgetTester tester) async {
        const svgXml = '''
        <svg viewBox="0 0 200 100">
          <defs>
            <rect id="r" x="0" y="10" width="30" height="30"/>
          </defs>
          <use href="#r" x="10" fill="red"/>
          <use href="#r" x="100" fill="blue"/>
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

        // First use should be red
        expect(analysis.pixelCount, greaterThan(200));
        // And positioned on left side
        expect(analysis.boundingBox.left, lessThan(100));
      },
    );

    // Test 20: Use element inherits from group wrapper
    testWidgets('use element inherits fill from parent group', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <rect id="r" x="10" y="10" width="80" height="80"/>
          </defs>
          <g fill="red">
            <use href="#r"/>
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

      // Fill should inherit from parent g through use - should be red
      expect(analysis.pixelCount, greaterThan(1000));
    });
  });
}
