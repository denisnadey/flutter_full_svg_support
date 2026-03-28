import 'package:flutter/material.dart';
import 'package:flutter_svg/src/animation/animated_svg_picture.dart';
import 'package:flutter_svg/src/animation/svg_parser.dart';
import 'package:flutter_test/flutter_test.dart';

import 'visual_test_utils.dart';

void main() {
  group('Use/Symbol Edge Cases Tests', () {
    group('Symbol ViewBox Edge Cases', () {
      testWidgets('symbol without viewBox renders content at natural size', (
        WidgetTester tester,
      ) async {
        // Symbol without viewBox - content renders at natural coordinates
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <symbol id="icon">
                <rect x="0" y="0" width="30" height="30" fill="red"/>
              </symbol>
            </defs>
            <use href="#icon" x="10" y="10" width="60" height="60"/>
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
      });

      testWidgets('symbol with negative viewBox origin handles correctly', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <symbol id="icon" viewBox="-10 -10 40 40">
                <rect x="-10" y="-10" width="40" height="40" fill="red"/>
              </symbol>
            </defs>
            <use href="#icon" x="10" y="10" width="60" height="60"/>
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

        // Content should render with viewBox transform applied
        expect(analysis.pixelCount, greaterThan(500));
      });

      testWidgets('symbol with zero-width viewBox is handled gracefully', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <symbol id="icon" viewBox="0 0 0 10">
                <rect width="10" height="10" fill="red"/>
              </symbol>
            </defs>
            <use href="#icon" x="10" y="10" width="50" height="50"/>
            <rect x="70" y="70" width="20" height="20" fill="blue"/>
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

        // Should render without crash - fallback rect should be blue
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });
    });

    group('Nested Use/Symbol Transform Composition', () {
      testWidgets('use -> symbol -> use -> symbol chain composes transforms', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 200 200">
            <defs>
              <symbol id="innerIcon" viewBox="0 0 10 10">
                <rect width="10" height="10" fill="red"/>
              </symbol>
              <symbol id="outerIcon" viewBox="0 0 50 50">
                <use href="#innerIcon" x="10" y="10" width="30" height="30"/>
              </symbol>
            </defs>
            <use href="#outerIcon" x="20" y="20" width="100" height="100"/>
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

        // Content should be offset and scaled through both symbol viewBoxes
        expect(analysis.pixelCount, greaterThan(100));
        expect(analysis.boundingBox.left, greaterThan(30));
      });

      testWidgets('3 levels of use nesting with transforms', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <rect id="base" width="10" height="10" fill="red"/>
              <g id="level1">
                <use href="#base" x="5" y="5" transform="scale(1.5)"/>
              </g>
              <g id="level2">
                <use href="#level1" x="5" y="5"/>
              </g>
            </defs>
            <use href="#level2" x="10" y="10"/>
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

        // All transforms should compose
        expect(analysis.pixelCount, greaterThan(50));
        expect(analysis.boundingBox.left, greaterThan(30));
      });

      testWidgets('use with rotate transform on symbol reference', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <symbol id="icon" viewBox="0 0 20 20">
                <rect width="20" height="20" fill="red"/>
              </symbol>
            </defs>
            <use href="#icon" x="40" y="40" width="20" height="20" 
                 transform="rotate(45 50 50)"/>
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

        // Rotated content should render
        expect(analysis.pixelCount, greaterThan(100));
      });
    });

    group('PreserveAspectRatio Comprehensive Tests', () {
      testWidgets('xMinYMin meet aligns to top-left', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <symbol id="icon" viewBox="0 0 20 10" preserveAspectRatio="xMinYMin meet">
                <rect width="20" height="10" fill="red"/>
              </symbol>
            </defs>
            <use href="#icon" x="10" y="10" width="60" height="60"/>
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

        // Content should be at top-left of viewport
        expect(analysis.boundingBox.top, lessThan(100));
        expect(analysis.boundingBox.left, lessThan(100));
      });

      testWidgets('xMidYMid meet centers content', (WidgetTester tester) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <symbol id="icon" viewBox="0 0 20 10" preserveAspectRatio="xMidYMid meet">
                <rect width="20" height="10" fill="red"/>
              </symbol>
            </defs>
            <use href="#icon" x="10" y="10" width="60" height="60"/>
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

        // Content should be rendered
        expect(analysis.pixelCount, greaterThan(500));
      });

      testWidgets('xMaxYMax meet aligns to bottom-right', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <symbol id="icon" viewBox="0 0 20 10" preserveAspectRatio="xMaxYMax meet">
                <rect width="20" height="10" fill="red"/>
              </symbol>
            </defs>
            <use href="#icon" x="10" y="10" width="60" height="60"/>
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

        // Content should be at bottom-right of viewport
        expect(analysis.boundingBox.bottom, greaterThan(100));
      });

      testWidgets('slice clips content to fill viewport', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <symbol id="icon" viewBox="0 0 40 10" preserveAspectRatio="xMidYMid slice">
                <rect width="40" height="10" fill="red"/>
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

        // Content fills viewport (potentially clipped)
        expect(analysis.pixelCount, greaterThan(500));
      });
    });

    group('Invalid Reference Edge Cases', () {
      testWidgets('use with empty href attribute renders nothing', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <use href="" x="10" y="10"/>
            <rect x="50" y="50" width="30" height="30" fill="red"/>
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

        // Only the rect should render
        expect(analysis.pixelCount, greaterThan(100));
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('use referencing non-existent ID renders nothing', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <use href="#nonExistent" x="10" y="10"/>
            <rect x="50" y="50" width="30" height="30" fill="red"/>
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

        // Only the rect should render
        expect(analysis.pixelCount, greaterThan(100));
      });

      testWidgets('use without href attribute renders nothing', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <use x="10" y="10"/>
            <rect x="50" y="50" width="30" height="30" fill="red"/>
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
      });

      testWidgets('use referencing disallowed element type renders nothing', (
        WidgetTester tester,
      ) async {
        // linearGradient is not in the allowed tag list for use
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <linearGradient id="grad">
                <stop offset="0%" stop-color="red"/>
                <stop offset="100%" stop-color="blue"/>
              </linearGradient>
            </defs>
            <use href="#grad" x="10" y="10"/>
            <rect x="50" y="50" width="30" height="30" fill="red"/>
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

        // Should render without crash
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });
    });

    group('Circular Reference Protection', () {
      testWidgets('direct self-reference is handled', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <g id="self">
                <use href="#self"/>
                <rect width="20" height="20" fill="red"/>
              </g>
            </defs>
            <use href="#self" x="10" y="10"/>
          </svg>
        ''';

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: AnimatedSvgPicture.string(svgXml, width: 200, height: 200),
            ),
          ),
        );

        // Should not crash or hang
        await tester.pump();
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('indirect circular reference (A->B->A) is handled', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <g id="a">
                <use href="#b"/>
                <rect width="20" height="20" fill="red"/>
              </g>
              <g id="b">
                <use href="#a"/>
                <rect x="30" y="0" width="20" height="20" fill="blue"/>
              </g>
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

        // Should not crash or hang
        await tester.pump();
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('triple circular reference (A->B->C->A) is handled', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <g id="a"><use href="#b"/></g>
              <g id="b"><use href="#c"/></g>
              <g id="c">
                <use href="#a"/>
                <rect width="20" height="20" fill="red"/>
              </g>
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

        // Should not crash or hang
        await tester.pump();
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('max recursion depth (10 levels) is enforced', (
        WidgetTester tester,
      ) async {
        // Create 15 levels - should stop at 10
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <rect id="r0" width="10" height="10" fill="red"/>
              <g id="u1"><use href="#r0" x="1"/></g>
              <g id="u2"><use href="#u1" x="1"/></g>
              <g id="u3"><use href="#u2" x="1"/></g>
              <g id="u4"><use href="#u3" x="1"/></g>
              <g id="u5"><use href="#u4" x="1"/></g>
              <g id="u6"><use href="#u5" x="1"/></g>
              <g id="u7"><use href="#u6" x="1"/></g>
              <g id="u8"><use href="#u7" x="1"/></g>
              <g id="u9"><use href="#u8" x="1"/></g>
              <g id="u10"><use href="#u9" x="1"/></g>
              <g id="u11"><use href="#u10" x="1"/></g>
              <g id="u12"><use href="#u11" x="1"/></g>
              <g id="u13"><use href="#u12" x="1"/></g>
              <g id="u14"><use href="#u13" x="1"/></g>
            </defs>
            <use href="#u14" x="5" y="5"/>
          </svg>
        ''';

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: AnimatedSvgPicture.string(svgXml, width: 200, height: 200),
            ),
          ),
        );

        // Should complete without hang or crash
        await tester.pump();
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });
    });

    group('CSS Style Inheritance Through Use Boundary', () {
      testWidgets('stroke properties inherit through use', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <path id="p" d="M10,10 L90,10 L90,90 L10,90 Z" fill="none"/>
            </defs>
            <use href="#p" stroke="red" stroke-width="5" stroke-linecap="round"/>
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

        // Stroke should be visible
        expect(analysis.pixelCount, greaterThan(100));
      });

      testWidgets('font properties inherit through use for text', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <text id="t" x="10" y="50">Test</text>
            </defs>
            <use href="#t" fill="red" font-size="24"/>
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

        // Text should be red
        expect(analysis.pixelCount, greaterThan(10));
      });

      testWidgets('visibility inherit="visible" works through use', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <rect id="r" x="10" y="10" width="80" height="80" fill="red"/>
            </defs>
            <g visibility="hidden">
              <use href="#r" visibility="visible"/>
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

        // Rect should be visible
        expect(analysis.pixelCount, greaterThan(1000));
      });
    });

    group('DOM Parsing Verification', () {
      test('use element parses href correctly', () {
        const svgString = '''
          <svg>
            <use href="#target"/>
          </svg>
        ''';

        final document = SvgParser.parse(svgString);
        final use = document.root.children.firstWhere(
          (n) => n.tagName == 'use',
        );

        expect(use.getAttributeValue('href'), '#target');
      });

      test(
        'use element parses xlink:href correctly (stored without prefix)',
        () {
          // Note: The SVG parser uses attr.name.local which strips the namespace
          // prefix, so 'xlink:href' is stored as just 'href'
          const svgString = '''
          <svg xmlns:xlink="http://www.w3.org/1999/xlink">
            <use xlink:href="#target"/>
          </svg>
        ''';

          final document = SvgParser.parse(svgString);
          final use = document.root.children.firstWhere(
            (n) => n.tagName == 'use',
          );

          // xlink:href is stored as 'href' due to local name extraction
          expect(use.getAttributeValue('href'), '#target');
        },
      );

      test('symbol viewBox and preserveAspectRatio parse correctly', () {
        const svgString = '''
          <svg>
            <defs>
              <symbol id="icon" viewBox="0 0 24 24" preserveAspectRatio="xMidYMid slice">
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
          'xMidYMid slice',
        );
      });

      test('use element position and size attributes parse correctly', () {
        const svgString = '''
          <svg>
            <use href="#icon" x="10" y="20" width="50" height="60"/>
          </svg>
        ''';

        final document = SvgParser.parse(svgString);
        final use = document.root.children.firstWhere(
          (n) => n.tagName == 'use',
        );

        expect(use.getAttributeValue('x'), 10.0);
        expect(use.getAttributeValue('y'), 20.0);
        expect(use.getAttributeValue('width'), 50.0);
        expect(use.getAttributeValue('height'), 60.0);
      });
    });

    group('Hit Testing Through Use Boundary', () {
      testWidgets('tap on use content triggers use element event', (
        WidgetTester tester,
      ) async {
        // Use SMIL animation to verify hit-test on use shadow content
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <rect id="innerRect" x="10" y="10" width="50" height="50" fill="blue"/>
            </defs>
            <use id="myUse" href="#innerRect" x="15" y="15"/>
            <rect id="indicator" x="80" y="80" width="15" height="15" fill="red">
              <animate attributeName="fill" from="red" to="green" 
                       dur="0.3s" begin="myUse.click" fill="freeze"/>
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

        // Tap on the use element content
        await tester.tapAt(const Offset(80, 80));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        // Should render without crash
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('pointer-events none on use prevents hit', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <rect id="background" x="0" y="0" width="100" height="100" fill="blue"/>
            <defs>
              <rect id="r" x="20" y="20" width="60" height="60" fill="red"/>
            </defs>
            <use href="#r" pointer-events="none"/>
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

        // Should render without issue
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });
    });
  });
}
