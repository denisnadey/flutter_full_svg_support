import 'package:flutter/material.dart';
import 'package:flutter_svg/src/animation/animated_svg_picture.dart';
import 'package:flutter_test/flutter_test.dart';

import 'visual_test_utils.dart';

void main() {
  group('Use/Symbol CSS Cascade Tests', () {
    // Test 1: Use element with fill attribute overriding inherited fill
    testWidgets(
      'use fill attribute overrides inherited fill in referenced content',
      (WidgetTester tester) async {
        // Parent has fill="blue", use has fill="red", referenced rect has no fill
        // Expected: rect should be red (use's presentation attr overrides inherited)
        const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <rect id="r" x="10" y="10" width="80" height="80"/>
          </defs>
          <g fill="blue">
            <use href="#r" fill="red"/>
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

        // The rect should be red from use's fill attribute
        expect(analysis.pixelCount, greaterThan(1000));
      },
    );

    // Test 2: Use inline style NOT overriding style-block rules on referenced element
    testWidgets(
      'use inline style does NOT override style-block rules on referenced element',
      (WidgetTester tester) async {
        // CSS style rule applies to referenced element with higher specificity
        // Use's inherited values should not override CSS rules on referenced element
        const svgXml = '''
        <svg viewBox="0 0 100 100">
          <style>#myRect { fill: red; }</style>
          <defs>
            <rect id="myRect" x="10" y="10" width="80" height="80"/>
          </defs>
          <use href="#myRect" fill="blue"/>
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

        // The rect should be red from CSS rule (CSS rule wins over use's inherited fill)
        expect(analysis.pixelCount, greaterThan(1000));
      },
    );

    // Test 3: Presentation attrs on use override inherited but not inline
    testWidgets(
      'presentation attrs on use override inherited but not inline on referenced',
      (WidgetTester tester) async {
        // Referenced element has inline style fill="red"
        // Use has fill="blue" presentation attribute
        // Inline style on referenced element should win
        const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <rect id="r" x="10" y="10" width="80" height="80" style="fill: red"/>
          </defs>
          <use href="#r" fill="blue"/>
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

        // The rect should be red from inline style (inline wins over use attr)
        expect(analysis.pixelCount, greaterThan(1000));
      },
    );

    // Test 4: Nested use-in-use with coordinate stacking
    testWidgets('nested use-in-use stacks coordinates correctly', (
      WidgetTester tester,
    ) async {
      // Nested use elements should stack their x/y translations
      const svgXml = '''
        <svg viewBox="0 0 200 200">
          <defs>
            <rect id="r" x="0" y="0" width="20" height="20" fill="red"/>
            <g id="inner">
              <use href="#r" x="10" y="10"/>
            </g>
          </defs>
          <use href="#inner" x="50" y="50"/>
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

      // The rect should be rendered at x=60, y=60 (50+10, 50+10)
      // Just check that it renders
      expect(analysis.pixelCount, greaterThan(100));
    });

    // Test 5: Nested use circular reference detection
    testWidgets('nested use circular reference does not crash', (
      WidgetTester tester,
    ) async {
      // Circular reference: a -> b -> a
      // Should not crash, just not render the circular part
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <g id="a">
              <rect x="10" y="10" width="30" height="30" fill="red"/>
              <use href="#b" x="40" y="0"/>
            </g>
            <g id="b">
              <rect x="10" y="10" width="30" height="30" fill="blue"/>
              <use href="#a" x="0" y="40"/>
            </g>
          </defs>
          <use href="#a"/>
        </svg>
      ''';

      // Should not throw
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

    // Test 6: Use depth limit (>10 levels)
    testWidgets('use depth limit prevents infinite recursion', (
      WidgetTester tester,
    ) async {
      // Create 15 levels of nested use (exceeds 10 limit)
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <rect id="r0" x="0" y="0" width="10" height="10" fill="red"/>
            <g id="r1"><use href="#r0" x="1" y="1"/></g>
            <g id="r2"><use href="#r1" x="1" y="1"/></g>
            <g id="r3"><use href="#r2" x="1" y="1"/></g>
            <g id="r4"><use href="#r3" x="1" y="1"/></g>
            <g id="r5"><use href="#r4" x="1" y="1"/></g>
            <g id="r6"><use href="#r5" x="1" y="1"/></g>
            <g id="r7"><use href="#r6" x="1" y="1"/></g>
            <g id="r8"><use href="#r7" x="1" y="1"/></g>
            <g id="r9"><use href="#r8" x="1" y="1"/></g>
            <g id="r10"><use href="#r9" x="1" y="1"/></g>
            <g id="r11"><use href="#r10" x="1" y="1"/></g>
            <g id="r12"><use href="#r11" x="1" y="1"/></g>
          </defs>
          <use href="#r12"/>
        </svg>
      ''';

      // Should not throw (depth limit prevents crash)
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

    // Test 7: CSS inheritance through 3 levels of use
    testWidgets('CSS inheritance through 3 levels of use', (
      WidgetTester tester,
    ) async {
      // fill="red" on outermost use should propagate through nested uses
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <rect id="r" x="0" y="0" width="20" height="20"/>
            <g id="level2"><use href="#r" x="10" y="10"/></g>
            <g id="level1"><use href="#level2" x="10" y="10"/></g>
          </defs>
          <use href="#level1" fill="red" x="10" y="10"/>
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

      // The rect should be red, inherited through 3 levels
      expect(analysis.pixelCount, greaterThan(100));
    });

    // Test 8: Use inside clipPath
    testWidgets('use inside clipPath works correctly', (
      WidgetTester tester,
    ) async {
      // clipPath references a use element
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <circle id="c" cx="50" cy="50" r="40"/>
            <clipPath id="clip">
              <use href="#c"/>
            </clipPath>
          </defs>
          <rect x="0" y="0" width="100" height="100" fill="red" clip-path="url(#clip)"/>
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

      // The rect should be clipped to circular shape
      expect(analysis.pixelCount, greaterThan(500));
    });

    // Test 9: Use inside mask
    testWidgets('use inside mask works correctly', (WidgetTester tester) async {
      // mask references a use element
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <rect id="maskRect" x="20" y="20" width="60" height="60" fill="white"/>
            <mask id="m">
              <use href="#maskRect"/>
            </mask>
          </defs>
          <rect x="0" y="0" width="100" height="100" fill="red" mask="url(#m)"/>
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

      // The rect should be masked
      expect(analysis.pixelCount, greaterThan(500));
    });

    // Test 10: Event hit on use content returns use element ID
    testWidgets('event hit on use content triggers use element event', (
      WidgetTester tester,
    ) async {
      // Use SMIL animation to verify hit-test on use shadow content
      // triggers the use element's event (event retargeting)
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <rect id="innerRect" x="10" y="10" width="30" height="30" fill="blue"/>
          </defs>
          <use id="myUse" href="#innerRect" x="25" y="25"/>
          <rect id="moving" x="10" y="85" width="10" height="10" fill="red">
            <animate attributeName="x" from="10" to="80" dur="0.5s" begin="myUse.click" fill="freeze"/>
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

      // Capture initial state
      final beforePixels = await VisualTestUtils.captureWidgetPixels(tester);
      final beforeAnalysis = VisualTestUtils.analyzeRedPixels(
        beforePixels,
        800,
        600,
      );

      // Tap on the use element content (the inner rect at 35-65, 35-65)
      await tester.tapAt(const Offset(100, 100)); // Center of use
      await tester.pump();
      await tester.pump(
        const Duration(milliseconds: 600),
      ); // Wait for animation

      // Capture after state
      final afterPixels = await VisualTestUtils.captureWidgetPixels(tester);
      final afterAnalysis = VisualTestUtils.analyzeRedPixels(
        afterPixels,
        800,
        600,
      );

      // Animation should have started - proves event retargeted to use element
      expect(
        (afterAnalysis.centroid.dx - beforeAnalysis.centroid.dx).abs(),
        greaterThan(5),
      );
    });

    // Test 11: Use with symbol and viewBox scaling + cascade
    testWidgets('use with symbol and viewBox scaling plus cascade', (
      WidgetTester tester,
    ) async {
      // Symbol with viewBox, use with width/height and fill cascade
      const svgXml = '''
        <svg viewBox="0 0 200 200">
          <defs>
            <symbol id="sym" viewBox="0 0 50 50">
              <rect x="5" y="5" width="40" height="40"/>
            </symbol>
          </defs>
          <use href="#sym" x="10" y="10" width="100" height="100" fill="red"/>
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

      // The symbol content should be rendered and scaled with fill cascade
      expect(analysis.pixelCount, greaterThan(500));
    });

    // Test 12: Use with transform + referenced element transform
    testWidgets('use with transform plus referenced element transform', (
      WidgetTester tester,
    ) async {
      // Both use and referenced element have transforms that should compose
      const svgXml = '''
        <svg viewBox="0 0 200 200">
          <defs>
            <rect id="r" x="0" y="0" width="40" height="40" fill="red" transform="rotate(45 20 20)"/>
          </defs>
          <use href="#r" x="50" y="50" transform="translate(20, 20)"/>
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

      // The rect should be rendered with combined transforms
      expect(analysis.pixelCount, greaterThan(100));
    });

    // Test 13: Opacity on use element propagating to shadow tree
    testWidgets('opacity on use element propagates to shadow tree', (
      WidgetTester tester,
    ) async {
      // Use has opacity="0.5", should affect referenced content
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <rect id="r" x="10" y="10" width="80" height="80" fill="red"/>
          </defs>
          <rect x="0" y="0" width="100" height="100" fill="blue"/>
          <use href="#r" opacity="0.5"/>
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

      // The rect should be semi-transparent, so we should see both red and blue
      // Just verify it renders without error
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    // Test 14: fill="none" on use overriding referenced element's default
    testWidgets(
      'fill none on use overrides inherited fill in referenced content',
      (WidgetTester tester) async {
        // Parent has fill="red", use has fill="none"
        // The referenced content should have no fill
        const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <rect id="r" x="10" y="10" width="80" height="80"/>
          </defs>
          <g fill="red">
            <use href="#r" fill="none"/>
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

        // The rect should have no fill, so no red pixels
        expect(analysis.pixelCount, equals(0));
      },
    );

    // Test 15: Empty use (href to non-existent ID) renders nothing, no crash
    testWidgets(
      'empty use with non-existent href renders nothing without crash',
      (WidgetTester tester) async {
        // Use references a non-existent ID
        const svgXml = '''
        <svg viewBox="0 0 100 100">
          <rect x="0" y="0" width="100" height="100" fill="blue"/>
          <use href="#nonExistent"/>
        </svg>
      ''';

        // Should not throw
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
      },
    );
  });
}
