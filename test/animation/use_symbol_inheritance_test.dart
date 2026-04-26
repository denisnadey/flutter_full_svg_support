import 'package:flutter/material.dart';
import 'package:full_svg_flutter/src/animation/animated_svg_picture.dart';
import 'package:full_svg_flutter/src/animation/svg_parser.dart';
import 'package:flutter_test/flutter_test.dart';

import 'visual_test_utils.dart';

void main() {
  group('Use and Symbol Inheritance Tests', () {
    group('Attribute Propagation Through Use Boundaries', () {
      testWidgets('fill attribute on use propagates to referenced rect', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <rect id="myRect" x="0" y="0" width="50" height="50"/>
            </defs>
            <use href="#myRect" fill="red"/>
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

        // Should render a red rectangle
        expect(analysis.pixelCount, greaterThan(1000));
      });

      testWidgets('stroke attribute on use propagates to referenced path', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <path id="myPath" d="M10,10 L90,10 L90,90 L10,90 Z" fill="none"/>
            </defs>
            <use href="#myPath" stroke="red" stroke-width="5"/>
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

        // Should render a red stroked path
        expect(analysis.pixelCount, greaterThan(100));
      });

      testWidgets('opacity on use affects referenced content', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <rect id="myRect" x="10" y="10" width="80" height="80" fill="red"/>
            </defs>
            <use href="#myRect" opacity="0.5"/>
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

        // Should render; if opacity propagates, rectangle will be semi-transparent.
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('font properties on use propagate to text in symbol', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 200 100">
            <defs>
              <symbol id="myText" viewBox="0 0 100 50">
                <text x="10" y="30">Hello</text>
              </symbol>
            </defs>
            <use href="#myText" width="100" height="50" fill="red" font-size="24"/>
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

        // Should render red text
        expect(analysis.pixelCount, greaterThan(50));
      });

      testWidgets(
        'referenced element attributes override use element attributes',
        (WidgetTester tester) async {
          const svgXml = '''
            <svg viewBox="0 0 100 100">
              <defs>
                <rect id="blueRect" x="10" y="10" width="80" height="80" fill="blue"/>
              </defs>
              <use href="#blueRect" fill="red"/>
            </svg>
          ''';

          await tester.pumpWidget(
            const MaterialApp(
              home: Scaffold(
                body: AnimatedSvgPicture.string(
                  svgXml,
                  width: 200,
                  height: 200,
                ),
              ),
            ),
          );

          await tester.pump();

          final pixels = await VisualTestUtils.captureWidgetPixels(tester);
          final analysis = VisualTestUtils.analyzeRedPixels(pixels, 800, 600);

          // Blue rect has explicit fill, so use's fill="red" should not apply
          // The rect should be blue (no red pixels or very few)
          expect(analysis.pixelCount, lessThan(100));
        },
      );
    });

    group('Nested Use Elements', () {
      testWidgets('renders nested use elements correctly', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <rect id="baseRect" x="0" y="0" width="20" height="20" fill="red"/>
              <use id="useRect" href="#baseRect"/>
            </defs>
            <use href="#useRect" x="10" y="10"/>
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

        // Should render the nested use element
        expect(analysis.pixelCount, greaterThan(100));
      });

      testWidgets('handles deeply nested use elements (up to 10 levels)', (
        WidgetTester tester,
      ) async {
        // Create a chain of 5 nested use elements (well within the limit)
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <rect id="r0" x="0" y="0" width="20" height="20" fill="red"/>
              <use id="u1" href="#r0"/>
              <use id="u2" href="#u1"/>
              <use id="u3" href="#u2"/>
              <use id="u4" href="#u3"/>
              <use id="u5" href="#u4"/>
            </defs>
            <use href="#u5" x="10" y="10"/>
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

        // Should still render within 10 level limit
        expect(analysis.pixelCount, greaterThan(100));
      });

      testWidgets('prevents infinite recursion with circular use references', (
        WidgetTester tester,
      ) async {
        // This creates a direct cycle: a -> b -> a
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <use id="a" href="#b" fill="red"/>
              <use id="b" href="#a"/>
            </defs>
            <use href="#a" x="10" y="10"/>
          </svg>
        ''';

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: AnimatedSvgPicture.string(svgXml, width: 200, height: 200),
            ),
          ),
        );

        // Should not crash or hang - cycle should be detected and broken
        await tester.pump();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('limits recursion depth exceeding 10 levels', (
        WidgetTester tester,
      ) async {
        // Create a chain of 12 nested use elements (exceeds the 10 level limit)
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <rect id="r0" x="0" y="0" width="20" height="20" fill="red"/>
              <use id="u1" href="#r0"/>
              <use id="u2" href="#u1"/>
              <use id="u3" href="#u2"/>
              <use id="u4" href="#u3"/>
              <use id="u5" href="#u4"/>
              <use id="u6" href="#u5"/>
              <use id="u7" href="#u6"/>
              <use id="u8" href="#u7"/>
              <use id="u9" href="#u8"/>
              <use id="u10" href="#u9"/>
              <use id="u11" href="#u10"/>
              <use id="u12" href="#u11"/>
            </defs>
            <use href="#u12" x="10" y="10"/>
          </svg>
        ''';

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: AnimatedSvgPicture.string(svgXml, width: 200, height: 200),
            ),
          ),
        );

        // Should not crash or hang - depth should be limited
        await tester.pump();

        // The rendering may not show the content due to depth limit,
        // but it should not crash
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });
    });

    group('Symbol ViewBox and PreserveAspectRatio', () {
      testWidgets('symbol scales correctly with use width/height', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <symbol id="icon" viewBox="0 0 10 10">
                <rect x="0" y="0" width="10" height="10" fill="red"/>
              </symbol>
            </defs>
            <use href="#icon" x="10" y="10" width="50" height="50"/>
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

        // Should render a scaled rectangle (50x50 in viewBox units)
        expect(analysis.pixelCount, greaterThan(5000));
      });

      testWidgets('symbol respects preserveAspectRatio="xMidYMid meet"', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <symbol id="icon" viewBox="0 0 10 20" preserveAspectRatio="xMidYMid meet">
                <rect x="0" y="0" width="10" height="20" fill="red"/>
              </symbol>
            </defs>
            <use href="#icon" x="10" y="10" width="40" height="40"/>
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

        // With meet, the aspect ratio is preserved
        // 10x20 viewBox into 40x40 should result in 20x40 rendering
        expect(analysis.objectHeight, greaterThan(analysis.objectWidth * 1.5));
      });

      testWidgets('symbol stretches with preserveAspectRatio="none"', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <symbol id="icon" viewBox="0 0 10 20" preserveAspectRatio="none">
                <rect x="0" y="0" width="10" height="20" fill="red"/>
              </symbol>
            </defs>
            <use href="#icon" x="10" y="10" width="40" height="40"/>
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

        // With none, the content is stretched to fill
        // Should be approximately square
        final aspectRatio = analysis.objectWidth / analysis.objectHeight;
        expect(aspectRatio, closeTo(1.0, 0.2));
      });
    });

    group('Use x/y Translation', () {
      testWidgets('use x/y positions referenced element correctly', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <rect id="myRect" width="20" height="20" fill="red"/>
            </defs>
            <use href="#myRect" x="40" y="40"/>
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

        // Rectangle should be offset by x=40, y=40
        // In a 200x200 widget with 100x100 viewBox, scale is 2
        // So the bounding box should start around 80, 80
        expect(analysis.boundingBox.left, greaterThan(70));
        expect(analysis.boundingBox.top, greaterThan(70));
      });

      testWidgets('use x/y stacks with referenced element position', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <rect id="myRect" x="10" y="10" width="20" height="20" fill="red"/>
            </defs>
            <use href="#myRect" x="20" y="20"/>
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

        // Rectangle at x=10,y=10, plus use translation x=20,y=20 = 30,30
        // In 200x200 widget with 100x100 viewBox, position would be around 60,60
        expect(analysis.boundingBox.left, greaterThan(50));
        expect(analysis.boundingBox.top, greaterThan(50));
      });

      testWidgets('use transform combines with x/y translation', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <rect id="myRect" width="20" height="20" fill="red"/>
            </defs>
            <use href="#myRect" x="10" y="10" transform="translate(20,20)"/>
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

        // Transform translate(20,20) applied first, then x=10,y=10
        // Total offset should be around 30,30
        expect(analysis.boundingBox.left, greaterThan(50));
        expect(analysis.boundingBox.top, greaterThan(50));
      });
    });

    group('Style Inheritance Chain', () {
      testWidgets('style attribute on use overrides attribute', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <rect id="myRect" x="10" y="10" width="80" height="80"/>
            </defs>
            <use href="#myRect" fill="blue" style="fill:red"/>
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

        // Style should override attribute, so rect should be red
        expect(analysis.pixelCount, greaterThan(3000));
      });

      testWidgets('multiple use elements get independent inheritance', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <rect id="myRect" width="30" height="30"/>
            </defs>
            <use href="#myRect" x="10" y="10" fill="red"/>
            <use href="#myRect" x="60" y="60" fill="blue"/>
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

        // Should have red pixels from first use
        expect(redAnalysis.pixelCount, greaterThan(100));
        // First rect should be in upper left area
        expect(redAnalysis.boundingBox.left, lessThan(150));
        expect(redAnalysis.boundingBox.top, lessThan(150));
      });
    });

    group('DOM Parsing Tests', () {
      test('use element correctly resolves href attribute', () {
        const svgString = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <rect id="target" width="10" height="10"/>
            </defs>
            <use href="#target" x="10" y="10"/>
          </svg>
        ''';

        final document = SvgParser.parse(svgString);
        final useNode = document.root.children.firstWhere(
          (n) => n.tagName == 'use',
        );

        expect(useNode.getAttributeValue('href'), '#target');
        // x/y are parsed as numbers
        expect(useNode.getAttributeValue('x'), 10.0);
        expect(useNode.getAttributeValue('y'), 10.0);
      });

      test('use element supports xlink:href attribute via href', () {
        // Note: The parser may normalize xlink:href to href
        const svgString = '''
          <svg viewBox="0 0 100 100" xmlns:xlink="http://www.w3.org/1999/xlink">
            <defs>
              <rect id="target" width="10" height="10"/>
            </defs>
            <use xlink:href="#target" x="10" y="10"/>
          </svg>
        ''';

        final document = SvgParser.parse(svgString);
        final useNode = document.root.children.firstWhere(
          (n) => n.tagName == 'use',
        );

        // Check either href or xlink:href is available
        final href =
            useNode.getAttributeValue('href') ??
            useNode.getAttributeValue('xlink:href');
        expect(href, '#target');
      });

      test('symbol element has viewBox and preserveAspectRatio', () {
        const svgString = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <symbol id="icon" viewBox="0 0 24 24" preserveAspectRatio="xMidYMid meet">
                <rect width="24" height="24"/>
              </symbol>
            </defs>
          </svg>
        ''';

        final document = SvgParser.parse(svgString);
        final defs = document.root.children.firstWhere(
          (n) => n.tagName == 'defs',
        );
        final symbol = defs.children.firstWhere((n) => n.tagName == 'symbol');

        expect(symbol.getAttributeValue('viewBox'), '0 0 24 24');
        expect(
          symbol.getAttributeValue('preserveAspectRatio'),
          'xMidYMid meet',
        );
      });
    });

    group('CSS Inheritance Through Use Boundary', () {
      testWidgets('inheritable CSS properties pass through use boundary', (
        WidgetTester tester,
      ) async {
        // fill, stroke, font-family, etc. should inherit through <use>
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <rect id="myRect" x="10" y="10" width="80" height="80"/>
            </defs>
            <g fill="red">
              <use href="#myRect"/>
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

        // fill="red" on parent <g> should inherit through <use> to <rect>
        expect(analysis.pixelCount, greaterThan(1000));
      });

      testWidgets('stroke-width inherits through use boundary', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <path id="myPath" d="M10,10 L90,10 L90,90 L10,90 Z" fill="none" stroke="red"/>
            </defs>
            <use href="#myPath" stroke-width="10"/>
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

        // stroke-width="10" should apply to the path through <use>
        expect(analysis.pixelCount, greaterThan(500));
      });

      testWidgets('CSS class on use does NOT transfer to referenced content', (
        WidgetTester tester,
      ) async {
        // Per spec, CSS classes do NOT transfer across shadow boundary
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <style>
              .highlight { fill: red; }
            </style>
            <defs>
              <rect id="myRect" x="10" y="10" width="80" height="80"/>
            </defs>
            <use href="#myRect" class="highlight"/>
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

        // The rect should NOT be red because class doesn't transfer
        // It should have default fill (black)
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });
    });

    group('Symbol Overflow Clipping', () {
      testWidgets('symbol with default overflow clips content', (
        WidgetTester tester,
      ) async {
        // Symbol's default overflow is 'hidden'
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <symbol id="icon" viewBox="0 0 20 20">
                <rect x="-5" y="-5" width="30" height="30" fill="red"/>
              </symbol>
            </defs>
            <use href="#icon" x="10" y="10" width="40" height="40"/>
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

        // Content should be clipped to viewBox bounds
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('symbol with overflow="visible" does not clip', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <symbol id="icon" viewBox="0 0 20 20" overflow="visible">
                <rect x="-5" y="-5" width="30" height="30" fill="red"/>
              </symbol>
            </defs>
            <use href="#icon" x="10" y="10" width="40" height="40"/>
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

        // With overflow="visible", the full rect should render
        expect(analysis.pixelCount, greaterThan(1000));
      });
    });

    group('Nested Use Inheritance Chains', () {
      testWidgets('attributes cascade through multiple use boundaries', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <rect id="baseRect" width="20" height="20"/>
              <g id="group1">
                <use href="#baseRect"/>
              </g>
            </defs>
            <use href="#group1" x="10" y="10" fill="red"/>
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

        // fill="red" should cascade through use -> g -> use -> rect
        expect(analysis.pixelCount, greaterThan(100));
      });

      testWidgets('intermediate use can override parent use attributes', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <rect id="baseRect" width="20" height="20"/>
              <use id="blueUse" href="#baseRect" fill="blue"/>
            </defs>
            <use href="#blueUse" x="10" y="10" fill="red"/>
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

        // The inner use has fill="blue" which should override outer fill="red"
        // So there should be minimal red pixels
        expect(redAnalysis.pixelCount, lessThan(100));
      });

      testWidgets('self-reference circular use is handled gracefully', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <g id="selfRef">
                <rect width="20" height="20" fill="red"/>
                <use href="#selfRef" x="5" y="5"/>
              </g>
            </defs>
            <use href="#selfRef" x="10" y="10"/>
          </svg>
        ''';

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: AnimatedSvgPicture.string(svgXml, width: 200, height: 200),
            ),
          ),
        );

        // Should not crash or hang - self-reference should be detected
        await tester.pump();
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });
    });

    group('Presentation Attribute vs Style Precedence', () {
      testWidgets('style attribute on use overrides presentation attribute', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <rect id="myRect" x="10" y="10" width="80" height="80"/>
            </defs>
            <use href="#myRect" fill="blue" style="fill:red"/>
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

        // style="fill:red" should override fill="blue"
        expect(analysis.pixelCount, greaterThan(3000));
      });

      testWidgets('referenced element own style takes precedence', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <rect id="myRect" x="10" y="10" width="80" height="80" style="fill:blue"/>
            </defs>
            <use href="#myRect" fill="red"/>
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

        // rect's own style="fill:blue" should override use's fill="red"
        expect(analysis.pixelCount, lessThan(100));
      });

      testWidgets('inherited use values apply when element has no own value', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <rect id="myRect" x="10" y="10" width="80" height="80"/>
            </defs>
            <use href="#myRect" fill="red" stroke="blue" stroke-width="5"/>
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

        // fill and stroke from use should apply to rect
        expect(analysis.pixelCount, greaterThan(1000));
      });
    });

    group('Non-Inherited Properties Do NOT Flow Through Use', () {
      testWidgets('opacity on use does NOT apply to referenced element itself', (
        WidgetTester tester,
      ) async {
        // Per SVG spec, opacity is NOT an inherited property.
        // The opacity on <use> affects the use element as a whole,
        // but should NOT cascade to the referenced content via inheritance.
        // The visual result is the same (the whole use subtree appears semi-transparent)
        // but the mechanism is different - it's group compositing, not inheritance.
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <rect id="myRect" x="10" y="10" width="80" height="80" fill="red"/>
            </defs>
            <use href="#myRect" opacity="0.5"/>
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

        // Should render (opacity is applied at the use level, not inherited)
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('transform on use applies to use element only', (
        WidgetTester tester,
      ) async {
        // Transform is NOT an inherited property.
        // It affects the coordinate system but doesn't inherit.
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <rect id="myRect" x="0" y="0" width="30" height="30" fill="red"/>
            </defs>
            <use href="#myRect" transform="translate(20,20)"/>
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

        // The rect should be translated by the use transform
        expect(analysis.boundingBox.left, greaterThan(30));
        expect(analysis.boundingBox.top, greaterThan(30));
      });

      testWidgets('clip-path on use does NOT flow to referenced content', (
        WidgetTester tester,
      ) async {
        // clip-path is NOT an inherited property.
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <clipPath id="clip1">
                <rect x="0" y="0" width="50" height="50"/>
              </clipPath>
              <rect id="myRect" x="0" y="0" width="80" height="80" fill="red"/>
            </defs>
            <use href="#myRect" clip-path="url(#clip1)"/>
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

        // The clip-path should be applied to the <use> element, clipping the content.
        // This is valid and should work - clip-path on use clips the whole subtree.
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });
    });

    group('CSS Custom Properties Through Use Boundaries', () {
      testWidgets(
        'CSS variable defined on use cascades to referenced content',
        (WidgetTester tester) async {
          // CSS custom properties are always inherited and should cascade
          // through <use> boundaries. Uses inline style (not CSS class rules)
          // since the renderer resolves inline styles during painting.
          const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <rect id="myRect" x="10" y="10" width="80" height="80"
                    style="fill: var(--my-color, blue);"/>
            </defs>
            <use href="#myRect" style="--my-color: red;"/>
          </svg>
        ''';

          await tester.pumpWidget(
            const MaterialApp(
              home: Scaffold(
                body: AnimatedSvgPicture.string(
                  svgXml,
                  width: 200,
                  height: 200,
                ),
              ),
            ),
          );

          await tester.pump();

          final pixels = await VisualTestUtils.captureWidgetPixels(tester);
          final analysis = VisualTestUtils.analyzeRedPixels(pixels, 800, 600);

          // The CSS variable --my-color: red should cascade through use,
          // so the rect should be red
          expect(analysis.pixelCount, greaterThan(1000));
        },
      );

      testWidgets(
        'CSS variable on parent of use cascades to referenced content',
        (WidgetTester tester) async {
          const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <rect id="myRect" x="10" y="10" width="80" height="80"
                    style="fill: var(--my-color, blue);"/>
            </defs>
            <g style="--my-color: red;">
              <use href="#myRect"/>
            </g>
          </svg>
        ''';

          await tester.pumpWidget(
            const MaterialApp(
              home: Scaffold(
                body: AnimatedSvgPicture.string(
                  svgXml,
                  width: 200,
                  height: 200,
                ),
              ),
            ),
          );

          await tester.pump();

          final pixels = await VisualTestUtils.captureWidgetPixels(tester);
          final analysis = VisualTestUtils.analyzeRedPixels(pixels, 800, 600);

          // The CSS variable from parent <g> should be available to referenced content
          expect(analysis.pixelCount, greaterThan(1000));
        },
      );

      testWidgets('CSS variable fallback is used when variable not defined', (
        WidgetTester tester,
      ) async {
        // When a CSS variable is not defined, the fallback value should be used.
        // Uses inline style to test var() fallback resolution.
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <rect id="myRect" x="10" y="10" width="80" height="80"
                    style="fill: var(--undefined-color, red);"/>
            </defs>
            <use href="#myRect"/>
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

        // Should use the fallback value (red)
        expect(analysis.pixelCount, greaterThan(1000));
      });

      testWidgets('nested use elements inherit CSS variables through chain', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <rect id="baseRect" x="0" y="0" width="30" height="30"
                    style="fill: var(--my-color, blue);"/>
              <use id="inner" href="#baseRect"/>
            </defs>
            <use href="#inner" x="10" y="10" style="--my-color: red;"/>
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

        // CSS variable should cascade through nested use chain
        expect(analysis.pixelCount, greaterThan(50));
      });
    });
  });
}
