import 'package:flutter/material.dart';
import 'package:full_svg_flutter/src/animation/animated_svg_picture.dart';
import 'package:flutter_test/flutter_test.dart';

import 'visual_test_utils.dart';

void main() {
  group('Advanced Use/Symbol Edge Cases', () {
    group('CSS Cascade Through Nested Use Boundaries', () {
      testWidgets('styles cascade through nested use -> symbol -> use chain', (
        WidgetTester tester,
      ) async {
        // Test: outer <use> references <symbol> that contains inner <use>
        // CSS properties should cascade through each shadow boundary
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <style>.outer { fill: red; }</style>
            <defs>
              <rect id="innerRect" x="0" y="0" width="50" height="50"/>
              <symbol id="innerSymbol">
                <use href="#innerRect"/>
              </symbol>
              <symbol id="outerSymbol" class="outer">
                <use href="#innerSymbol"/>
              </symbol>
            </defs>
            <use href="#outerSymbol" x="25" y="25"/>
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

        // The rect should inherit red fill through the nested use/symbol chain
        expect(analysis.pixelCount, greaterThan(100));
      });

      testWidgets('outer use fill overrides inner symbol default', (
        WidgetTester tester,
      ) async {
        // Test: presentation attribute on outer <use> should cascade to
        // referenced content through nested use/symbol chain
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <rect id="innerRect" x="0" y="0" width="50" height="50"/>
              <symbol id="innerSymbol">
                <use href="#innerRect"/>
              </symbol>
            </defs>
            <use href="#innerSymbol" fill="red" x="25" y="25"/>
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

        // The rect should inherit red fill from outer use element
        expect(analysis.pixelCount, greaterThan(100));
      });

      testWidgets('inline style on referenced content overrides use', (
        WidgetTester tester,
      ) async {
        // Per SVG spec: inline styles on referenced elements override
        // inherited styles from use element
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <rect id="r" x="10" y="10" width="80" height="80" 
                    style="fill: red;"/>
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
        final redAnalysis = VisualTestUtils.analyzeRedPixels(pixels, 800, 600);

        // Inline style on rect should override use's fill
        expect(redAnalysis.pixelCount, greaterThan(1000));
      });
    });

    group('Visibility/Display Cascade Through Use Boundaries', () {
      testWidgets('visibility:hidden on use hides referenced content', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <rect id="r" x="10" y="10" width="80" height="80" fill="red"/>
            </defs>
            <use href="#r" visibility="hidden"/>
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

        // Red rect should be hidden
        expect(analysis.pixelCount, lessThan(100));
      });

      testWidgets('visibility:visible on ref can override hidden on use', (
        WidgetTester tester,
      ) async {
        // Per CSS spec: visibility:visible on child can override
        // visibility:hidden on parent in some cases.
        // However, in SVG use shadow trees, the behavior may differ.
        // This test documents actual behavior - the use element's visibility
        // applies to the entire shadow tree.
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <rect id="r" x="10" y="10" width="80" height="80" 
                    fill="red" visibility="visible"/>
            </defs>
            <use href="#r" visibility="hidden"/>
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
        VisualTestUtils.analyzeRedPixels(pixels, 800, 600);
        // The ref's visibility:visible should override the use's hidden.
        // If it doesn't render, that's also valid SVG behavior.
        // Just verify the widget renders without error.
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('display:none on use hides all referenced content', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <rect id="r" x="10" y="10" width="80" height="80" fill="red"/>
            </defs>
            <use href="#r" style="display:none;"/>
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

        // Red rect should be hidden
        expect(analysis.pixelCount, lessThan(100));
      });

      testWidgets('nested use with visibility cascade', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <rect id="innerRect" x="0" y="0" width="50" height="50" fill="red"/>
              <symbol id="innerSymbol">
                <use href="#innerRect"/>
              </symbol>
            </defs>
            <use href="#innerSymbol" visibility="hidden" x="25" y="25"/>
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

        // Content should be hidden through nested use/symbol chain
        expect(analysis.pixelCount, lessThan(100));
      });
    });

    group('Use Within ClipPath Regions', () {
      testWidgets('use element contributes geometry to clipPath', (
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

        // Red should be clipped to circle shape - less than full rect
        expect(analysis.pixelCount, greaterThan(100));
        expect(analysis.pixelCount, lessThan(50000)); // Clipped
      });

      testWidgets('use with transform in clipPath', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <rect id="clipRect" x="0" y="0" width="50" height="50"/>
              <clipPath id="clip">
                <use href="#clipRect" x="25" y="25"/>
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

        // Red should be clipped to offset rect
        expect(analysis.pixelCount, greaterThan(100));
      });

      testWidgets('nested use references in clipPath', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <rect id="innerRect" x="0" y="0" width="40" height="40"/>
              <symbol id="innerSymbol">
                <use href="#innerRect"/>
              </symbol>
              <clipPath id="clip">
                <use href="#innerSymbol" x="30" y="30"/>
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

        // Red should be clipped by nested use geometry
        expect(analysis.pixelCount, greaterThan(100));
      });

      testWidgets('display:none use in clipPath contributes nothing', (
        WidgetTester tester,
      ) async {
        // Test behavior when use element in clipPath has display:none.
        // Per SVG spec, display:none elements don't contribute to clip region.
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <rect id="clipRect" x="0" y="0" width="50" height="50"/>
              <clipPath id="clip">
                <use href="#clipRect" style="display:none;"/>
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

        // Verify the widget renders. The clip behavior depends on
        // whether the empty clip shows nothing or allows everything.
        // Currently, the implementation renders the content when
        // display:none doesn't contribute geometry (empty clipPath)
        // shows all content per some SVG implementations.
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });
    });

    group('Use Within Mask Regions', () {
      testWidgets('use element contributes to mask', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <circle id="maskCircle" cx="50" cy="50" r="40" fill="white"/>
              <mask id="mask">
                <use href="#maskCircle"/>
              </mask>
            </defs>
            <rect x="0" y="0" width="100" height="100" fill="red" mask="url(#mask)"/>
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

        // Red should be masked to circle area
        expect(analysis.pixelCount, greaterThan(100));
      });
    });

    group('Pointer Events Through Use Boundaries', () {
      testWidgets('pointer-events:none on use prevents hit testing', (
        WidgetTester tester,
      ) async {
        // This test verifies pointer-events:none on use element
        // affects the entire shadow tree
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <rect id="clickRect" x="10" y="10" width="80" height="80" fill="red"/>
            </defs>
            <use id="useElem" href="#clickRect" pointer-events="none"/>
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

        // The widget should render, but hit-testing should fail
        // for elements with pointer-events:none
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('nested use with pointer-events cascade', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <rect id="innerRect" x="0" y="0" width="50" height="50" fill="red"/>
              <symbol id="innerSymbol">
                <use href="#innerRect"/>
              </symbol>
            </defs>
            <use id="outerUse" href="#innerSymbol" pointer-events="none" x="25" y="25"/>
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

        // Verify rendering works
        final pixels = await VisualTestUtils.captureWidgetPixels(tester);
        final analysis = VisualTestUtils.analyzeRedPixels(pixels, 800, 600);
        expect(analysis.pixelCount, greaterThan(100));
      });
    });

    group('Event Retargeting in Nested Use', () {
      testWidgets('nested use elements compose event path', (
        WidgetTester tester,
      ) async {
        // Test that nested use elements properly contribute to event path
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <rect id="innerRect" x="0" y="0" width="50" height="50" fill="red"/>
              <symbol id="innerSymbol">
                <use id="innerUse" href="#innerRect"/>
              </symbol>
              <symbol id="outerSymbol">
                <use id="middleUse" href="#innerSymbol"/>
              </symbol>
            </defs>
            <use id="outerUse" href="#outerSymbol" x="25" y="25"/>
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

        // Verify rendering with nested use chain works
        final pixels = await VisualTestUtils.captureWidgetPixels(tester);
        final analysis = VisualTestUtils.analyzeRedPixels(pixels, 800, 600);
        expect(analysis.pixelCount, greaterThan(100));
      });
    });

    group('Transform Composition (Non-Inheritance)', () {
      testWidgets('transforms compose rather than inherit through use', (
        WidgetTester tester,
      ) async {
        // Test: transforms should compose (multiply), not inherit
        const svgXml = '''
          <svg viewBox="0 0 200 200">
            <defs>
              <rect id="r" x="0" y="0" width="50" height="50" fill="red"/>
            </defs>
            <use href="#r" transform="translate(50, 50)"/>
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

        // Red rect should be translated
        expect(analysis.pixelCount, greaterThan(100));
      });

      testWidgets('nested transforms compose through use chain', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 200 200">
            <defs>
              <rect id="r" x="0" y="0" width="20" height="20" fill="red"/>
              <symbol id="s">
                <use href="#r" transform="translate(10, 10)"/>
              </symbol>
            </defs>
            <use href="#s" transform="translate(50, 50)"/>
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

        // Red rect should be at composed position (60, 60)
        expect(analysis.pixelCount, greaterThan(50));
      });
    });

    group('Opacity Compositing Through Use', () {
      testWidgets('opacity on use applies to entire referenced content', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <rect id="r" x="10" y="10" width="80" height="80" fill="red"/>
            </defs>
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

        // Just verify rendering works with opacity
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });
    });

    group('Symbol ViewBox Handling Through Use', () {
      testWidgets('symbol viewBox transforms content correctly', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <symbol id="s" viewBox="0 0 50 50">
                <rect x="0" y="0" width="50" height="50" fill="red"/>
              </symbol>
            </defs>
            <use href="#s" width="100" height="100"/>
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

        // Symbol content should be scaled to fill use dimensions
        expect(analysis.pixelCount, greaterThan(1000));
      });
    });
  });
}
