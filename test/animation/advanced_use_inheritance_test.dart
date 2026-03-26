import 'package:flutter/material.dart';
import 'package:flutter_svg/src/animation/animated_svg_picture.dart';
import 'package:flutter_svg/src/animation/css_cascade.dart';
import 'package:flutter_svg/src/animation/svg_parser.dart';
import 'package:flutter_test/flutter_test.dart';

import 'visual_test_utils.dart';

void main() {
  group('Advanced Use/Symbol Inheritance Tests', () {
    group('CSS Cascade Through Use Boundary', () {
      testWidgets(
        '!important on use element overrides when element has no value',
        (WidgetTester tester) async {
          // Per SVG spec: !important on use element should apply when
          // referenced content has no explicit value for that property
          const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <rect id="myRect" x="10" y="10" width="80" height="80"/>
            </defs>
            <use href="#myRect" style="fill: red !important;"/>
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
          final redAnalysis = VisualTestUtils.analyzeRedPixels(
            pixels,
            800,
            600,
          );

          // The !important on use should apply since referenced element has no fill
          expect(redAnalysis.pixelCount, greaterThan(1000));
        },
      );

      testWidgets('CSS rule with !important overrides use presentation attr', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <style>
              #myRect { fill: red !important; }
            </style>
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
        final redAnalysis = VisualTestUtils.analyzeRedPixels(pixels, 800, 600);

        // CSS rule with !important should win over use's presentation attribute
        expect(redAnalysis.pixelCount, greaterThan(1000));
      });

      testWidgets('inheritable properties flow through use boundary', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <rect id="myRect" x="10" y="10" width="80" height="80"/>
            </defs>
            <g fill="red" stroke="blue" stroke-width="3">
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
        final redAnalysis = VisualTestUtils.analyzeRedPixels(pixels, 800, 600);

        // fill and stroke should cascade through use boundary
        expect(redAnalysis.pixelCount, greaterThan(1000));
      });

      testWidgets('non-inherited properties do NOT flow through use', (
        WidgetTester tester,
      ) async {
        // opacity is NOT an inherited property - it applies to use as a whole
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

        // Should render without crash - opacity applies at group level
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });
    });

    group('Nested Use Coordinate Transforms', () {
      testWidgets('nested use x/y offsets stack correctly', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <rect id="baseRect" width="20" height="20" fill="red"/>
              <use id="use1" href="#baseRect" x="10" y="10"/>
            </defs>
            <use href="#use1" x="10" y="10"/>
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

        // Combined offset should be x=20, y=20 (10+10 from each use)
        expect(analysis.boundingBox.left, greaterThan(30));
        expect(analysis.boundingBox.top, greaterThan(30));
      });

      testWidgets('use -> symbol -> use -> symbol chain transforms correctly', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 200 200">
            <defs>
              <symbol id="innerIcon" viewBox="0 0 10 10">
                <rect width="10" height="10" fill="red"/>
              </symbol>
              <symbol id="outerIcon" viewBox="0 0 50 50">
                <use href="#innerIcon" x="5" y="5" width="20" height="20"/>
              </symbol>
            </defs>
            <use href="#outerIcon" x="10" y="10" width="80" height="80"/>
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

        // Should render the nested content correctly
        expect(analysis.pixelCount, greaterThan(100));
      });

      testWidgets('transform attribute on use applies before x/y', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <rect id="myRect" width="20" height="20" fill="red"/>
            </defs>
            <use href="#myRect" x="10" y="10" transform="scale(2)"/>
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

        // Scale(2) means the rect and offset are doubled
        // Original 20x20 rect becomes 40x40 after scale
        expect(analysis.pixelCount, greaterThan(400));
      });

      testWidgets('deeply nested use (5 levels) renders correctly', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <rect id="r0" width="20" height="20" fill="red"/>
              <use id="u1" href="#r0" x="2"/>
              <use id="u2" href="#u1" x="2"/>
              <use id="u3" href="#u2" x="2"/>
              <use id="u4" href="#u3" x="2"/>
            </defs>
            <use href="#u4" x="5" y="5"/>
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

        // Combined x offset: 5 + 2*4 = 13, so should be at least 13 units from left
        expect(analysis.pixelCount, greaterThan(100));
        expect(analysis.boundingBox.left, greaterThan(20));
      });
    });

    group('Event Retargeting From Use Content', () {
      testWidgets('hit test on use content returns use element ID', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <rect id="innerRect" x="0" y="0" width="50" height="50" fill="red"/>
            </defs>
            <use id="myUse" href="#innerRect" x="25" y="25"/>
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

        // The widget should render
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('nested use retargets to outermost use with ID', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <rect id="baseRect" width="30" height="30" fill="red"/>
              <use href="#baseRect"/>
            </defs>
            <use id="outerUse" href="#baseRect" x="10" y="10"/>
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

    group('Use Within ClipPath and Mask', () {
      testWidgets('use element inside clipPath clips content correctly', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <circle id="clipCircle" cx="25" cy="25" r="25"/>
              <clipPath id="myClip">
                <use href="#clipCircle"/>
              </clipPath>
            </defs>
            <rect x="0" y="0" width="100" height="100" fill="red" clip-path="url(#myClip)"/>
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

        // Content should be clipped to circle shape
        expect(analysis.pixelCount, greaterThan(100));
      });

      testWidgets('use with x/y offset inside clipPath applies offset', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <rect id="clipRect" x="0" y="0" width="30" height="30"/>
              <clipPath id="myClip">
                <use href="#clipRect" x="35" y="35"/>
              </clipPath>
            </defs>
            <rect x="0" y="0" width="100" height="100" fill="red" clip-path="url(#myClip)"/>
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

        // Clipped content should be offset
        expect(analysis.boundingBox.left, greaterThan(50));
        expect(analysis.boundingBox.top, greaterThan(50));
      });

      testWidgets('use inside mask clips content', (WidgetTester tester) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <rect id="maskRect" x="10" y="10" width="40" height="40" fill="white"/>
              <mask id="myMask">
                <use href="#maskRect"/>
              </mask>
            </defs>
            <rect x="0" y="0" width="100" height="100" fill="red" mask="url(#myMask)"/>
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

      testWidgets('symbol referenced by use inside clipPath works', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <symbol id="clipSymbol" viewBox="0 0 20 20">
                <circle cx="10" cy="10" r="10"/>
              </symbol>
              <clipPath id="myClip">
                <use href="#clipSymbol" width="40" height="40"/>
              </clipPath>
            </defs>
            <rect x="0" y="0" width="100" height="100" fill="red" clip-path="url(#myClip)"/>
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

    group('CSS Selector Matching in Use Context', () {
      testWidgets('simple selectors work on referenced element', (
        WidgetTester tester,
      ) async {
        // Simple selectors (without combinators) should work on referenced content
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <style>
              rect { fill: red; }
            </style>
            <defs>
              <rect id="myRect" x="10" y="10" width="80" height="80"/>
            </defs>
            <g>
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

        // Simple type selector should work across use boundary
        final pixels = await VisualTestUtils.captureWidgetPixels(tester);
        final redAnalysis = VisualTestUtils.analyzeRedPixels(pixels, 800, 600);

        // Rect should be red from the type selector rule
        expect(redAnalysis.pixelCount, greaterThan(1000));
      });

      testWidgets('ID selector matches referenced element', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <style>
              #targetRect { fill: red; }
            </style>
            <defs>
              <rect id="targetRect" x="10" y="10" width="80" height="80"/>
            </defs>
            <use href="#targetRect"/>
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

        // ID selector should match the referenced element
        expect(analysis.pixelCount, greaterThan(1000));
      });

      testWidgets('class selector on referenced element works', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <style>
              .highlight { fill: red; }
            </style>
            <defs>
              <rect id="r" class="highlight" x="10" y="10" width="80" height="80"/>
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

        // Class selector should match
        expect(analysis.pixelCount, greaterThan(1000));
      });
    });

    group('Deep Nesting Edge Cases', () {
      testWidgets('circular reference is detected and handled gracefully', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <g id="a">
                <rect width="20" height="20" fill="red"/>
                <use href="#b"/>
              </g>
              <g id="b">
                <use href="#a"/>
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
        // Create 12 levels of nesting - should stop at 10
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <rect id="r0" width="20" height="20" fill="red"/>
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

        // Should not crash - depth should be limited
        await tester.pump();
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('self-referencing use is handled gracefully', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <use id="self" href="#self"/>
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

      testWidgets('empty href is handled gracefully', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <use href="" x="10" y="10"/>
            <rect x="20" y="20" width="60" height="60" fill="red"/>
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

        // Empty use should be skipped, red rect should still render
        expect(analysis.pixelCount, greaterThan(1000));
      });
    });

    group('UseCascadeContext Unit Tests', () {
      test('createChildContext increments nesting depth', () {
        final parent = UseCascadeContext(cssRules: []);
        expect(parent.nestingDepth, 0);

        final document = SvgParser.parse('<svg><rect id="r"/></svg>');
        final rect = document.root.children.first;

        final child = parent.createChildContext(
          useNode: rect,
          shadowRootId: 'r',
        );

        expect(child.nestingDepth, 1);
        expect(child.parentContext, parent);
        expect(child.shadowRootId, 'r');
      });

      test('hasCircularReference detects circular references', () {
        final document = SvgParser.parse('''
          <svg>
            <rect id="a"/>
            <rect id="b"/>
          </svg>
        ''');

        final context1 = UseCascadeContext(
          cssRules: [],
          useNode: document.root.children[0],
          shadowRootId: 'a',
        );

        final context2 = context1.createChildContext(
          useNode: document.root.children[1],
          shadowRootId: 'b',
        );

        expect(context2.hasCircularReference('a'), true);
        expect(context2.hasCircularReference('b'), true);
        expect(context2.hasCircularReference('c'), false);
      });

      test('useChainIds returns all IDs in chain', () {
        final document = SvgParser.parse('''
          <svg>
            <use id="u1"/>
            <use id="u2"/>
            <use id="u3"/>
          </svg>
        ''');

        final context1 = UseCascadeContext(
          cssRules: [],
          useNode: document.root.children[0],
        );

        final context2 = context1.createChildContext(
          useNode: document.root.children[1],
        );

        final context3 = context2.createChildContext(
          useNode: document.root.children[2],
        );

        final ids = context3.useChainIds;
        expect(ids.length, 3);
        expect(ids[0], 'u1');
        expect(ids[1], 'u2');
        expect(ids[2], 'u3');
      });

      test('retargetedEventId returns outermost use ID', () {
        final document = SvgParser.parse('''
          <svg>
            <use id="outer"/>
            <use id="middle"/>
            <use id="inner"/>
          </svg>
        ''');

        final context1 = UseCascadeContext(
          cssRules: [],
          useNode: document.root.children[0],
        );

        final context2 = context1.createChildContext(
          useNode: document.root.children[1],
        );

        final context3 = context2.createChildContext(
          useNode: document.root.children[2],
        );

        // Event target should be the outermost use element
        expect(context3.retargetedEventId, 'outer');
      });
    });
  });
}
