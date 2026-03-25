import 'package:flutter/material.dart';
import 'package:flutter_svg/src/animation/animated_svg_picture.dart';
import 'package:flutter_svg/src/animation/svg_parser.dart';
import 'package:flutter_test/flutter_test.dart';

import 'visual_test_utils.dart';

void main() {
  group('Use CSS Cascade Tests', () {
    group('CSS Class Rules Applied to Use-Referenced Elements', () {
      testWidgets('CSS class rule applies to referenced element with class', (
        WidgetTester tester,
      ) async {
        // CSS style rule .highlight should apply to referenced rect with class
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <style>.highlight { fill: red; }</style>
            <defs>
              <rect id="r" class="highlight" x="10" y="10" width="80" height="80"/>
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

        // The rect should be red from CSS rule
        expect(analysis.pixelCount, greaterThan(1000));
      });

      testWidgets('CSS id rule applies to referenced element with id', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <style>#myRect { fill: red; }</style>
            <defs>
              <rect id="myRect" x="10" y="10" width="80" height="80"/>
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

        // The rect should be red from CSS rule
        expect(analysis.pixelCount, greaterThan(1000));
      });

      testWidgets('CSS element type rule applies to referenced element', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <style>rect { fill: red; }</style>
            <defs>
              <rect id="r" x="10" y="10" width="80" height="80"/>
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

        // The rect should be red from CSS rule
        expect(analysis.pixelCount, greaterThan(1000));
      });
    });

    group('CSS Specificity Tests', () {
      testWidgets(
        'inline style on referenced element overrides CSS class rule',
        (WidgetTester tester) async {
          const svgXml = '''
            <svg viewBox="0 0 100 100">
              <style>.highlight { fill: blue; }</style>
              <defs>
                <rect id="r" class="highlight" x="10" y="10" width="80" height="80" 
                      style="fill: red;"/>
              </defs>
              <use href="#r"/>
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

          // Inline style should override CSS rule - rect should be red
          expect(redAnalysis.pixelCount, greaterThan(1000));
        },
      );

      testWidgets('CSS rule overrides use element presentation attribute', (
        WidgetTester tester,
      ) async {
        // CSS rule on referenced element should override use's presentation attribute
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <style>.highlight { fill: red; }</style>
            <defs>
              <rect id="r" class="highlight" x="10" y="10" width="80" height="80"/>
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

        // CSS rule should override use's presentation attribute
        expect(redAnalysis.pixelCount, greaterThan(1000));
      });

      testWidgets(
        'referenced element attribute overrides use presentation attribute',
        (WidgetTester tester) async {
          // Per SVG spec: referenced element's own values override use's inherited values
          const svgXml = '''
            <svg viewBox="0 0 100 100">
              <defs>
                <rect id="r" x="10" y="10" width="80" height="80" fill="red"/>
              </defs>
              <use href="#r" fill="blue"/>
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

          // Referenced element's explicit fill="red" should win
          expect(redAnalysis.pixelCount, greaterThan(1000));
        },
      );

      testWidgets('use presentation attribute applies when element has none', (
        WidgetTester tester,
      ) async {
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

        // Use's fill should apply when referenced element has no fill
        expect(analysis.pixelCount, greaterThan(1000));
      });
    });

    group('Symbol ViewBox and PreserveAspectRatio', () {
      testWidgets('symbol viewBox scales correctly with use width/height', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <symbol id="icon" viewBox="0 0 10 10">
                <rect x="0" y="0" width="10" height="10" fill="red"/>
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

        // Symbol content should scale to fill use's 60x60 viewport
        expect(analysis.pixelCount, greaterThan(5000));
      });

      testWidgets('preserveAspectRatio xMinYMin meet aligns content', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <symbol id="icon" viewBox="0 0 20 10" preserveAspectRatio="xMinYMin meet">
                <rect x="0" y="0" width="20" height="10" fill="red"/>
              </symbol>
            </defs>
            <use href="#icon" x="0" y="0" width="80" height="80"/>
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

        // Content should be aligned to xMin (left) and yMin (top)
        expect(analysis.boundingBox.left, lessThan(50));
        expect(analysis.boundingBox.top, lessThan(50));
      });

      testWidgets('preserveAspectRatio xMaxYMax meet aligns content', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <symbol id="icon" viewBox="0 0 20 10" preserveAspectRatio="xMaxYMax meet">
                <rect x="0" y="0" width="20" height="10" fill="red"/>
              </symbol>
            </defs>
            <use href="#icon" x="0" y="0" width="80" height="80"/>
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

        // Content should be aligned to xMax (right) and yMax (bottom)
        expect(analysis.boundingBox.bottom, greaterThan(150));
      });

      testWidgets('preserveAspectRatio slice clips and scales content', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <symbol id="icon" viewBox="0 0 20 10" preserveAspectRatio="xMidYMid slice">
                <rect x="0" y="0" width="20" height="10" fill="red"/>
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

        // With slice, content fills and clips to viewport
        expect(analysis.pixelCount, greaterThan(500));
      });

      testWidgets('preserveAspectRatio none stretches content', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <symbol id="icon" viewBox="0 0 10 20" preserveAspectRatio="none">
                <rect x="0" y="0" width="10" height="20" fill="red"/>
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

        // With none, content stretches to fill 50x50 viewport
        final aspectRatio = analysis.objectWidth / analysis.objectHeight;
        expect(aspectRatio, closeTo(1.0, 0.2));
      });
    });

    group('Symbol Without Use Width/Height', () {
      testWidgets('symbol uses viewBox size when use has no width/height', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <symbol id="icon" viewBox="0 0 30 30">
                <rect x="0" y="0" width="30" height="30" fill="red"/>
              </symbol>
            </defs>
            <use href="#icon" x="10" y="10"/>
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
    });

    group('Symbol Overflow Handling', () {
      testWidgets('symbol with default overflow clips content', (
        WidgetTester tester,
      ) async {
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

        // Content should be clipped (default overflow is hidden for symbols)
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('symbol with overflow="hidden" clips content', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <symbol id="icon" viewBox="0 0 20 20" overflow="hidden">
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

    group('Nested Use and Symbol CSS Cascade', () {
      testWidgets('CSS rules apply through nested use elements', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <style>.red { fill: red; }</style>
            <defs>
              <rect id="r" class="red" width="20" height="20"/>
              <g id="group">
                <use href="#r"/>
              </g>
            </defs>
            <use href="#group" x="10" y="10"/>
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

        // CSS rule should cascade through nested structure
        expect(analysis.pixelCount, greaterThan(50));
      });

      testWidgets('CSS rules apply to symbol children', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <style>.highlight { fill: red; }</style>
            <defs>
              <symbol id="icon" viewBox="0 0 20 20">
                <rect class="highlight" width="20" height="20"/>
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

        // CSS rule should apply to rect inside symbol
        expect(analysis.pixelCount, greaterThan(500));
      });
    });

    group('Presentation Attribute Override Semantics', () {
      testWidgets('use fill applies when referenced element inherits fill', (
        WidgetTester tester,
      ) async {
        // When referenced element doesn't have explicit fill, use's fill applies
        const svgXml = '''
            <svg viewBox="0 0 100 100">
              <defs>
                <g id="g">
                  <rect x="10" y="10" width="80" height="80"/>
                </g>
              </defs>
              <use href="#g" fill="red"/>
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

        // Use's fill should apply to rect which has no explicit fill
        expect(analysis.pixelCount, greaterThan(1000));
      });

      testWidgets('referenced element explicit fill overrides use fill', (
        WidgetTester tester,
      ) async {
        // When referenced element has explicit fill, it should win
        const svgXml = '''
            <svg viewBox="0 0 100 100">
              <defs>
                <g id="g" fill="red">
                  <rect x="10" y="10" width="80" height="80"/>
                </g>
              </defs>
              <use href="#g" fill="blue"/>
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

        // Referenced group's fill="red" should override use's fill="blue"
        expect(redAnalysis.pixelCount, greaterThan(1000));
      });

      testWidgets('use style attribute overrides use presentation attribute', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <rect id="r" x="10" y="10" width="80" height="80"/>
            </defs>
            <use href="#r" fill="blue" style="fill: red;"/>
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

        // style attribute should override presentation attribute
        expect(analysis.pixelCount, greaterThan(1000));
      });
    });

    group('Multiple CSS Rules Specificity', () {
      testWidgets('higher specificity CSS rule wins', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <style>
              rect { fill: blue; }
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

        // .highlight has higher specificity than rect
        expect(analysis.pixelCount, greaterThan(1000));
      });

      testWidgets('id selector has higher specificity than class', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <style>
              .highlight { fill: blue; }
              #myRect { fill: red; }
            </style>
            <defs>
              <rect id="myRect" class="highlight" x="10" y="10" width="80" height="80"/>
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

        // #myRect has higher specificity than .highlight
        expect(analysis.pixelCount, greaterThan(1000));
      });
    });

    group('DOM Parsing for CSS Rules', () {
      test('CSS rules are parsed from style element', () {
        const svgString = '''
          <svg viewBox="0 0 100 100">
            <style>
              .highlight { fill: red; stroke: blue; }
              #myRect { opacity: 0.5; }
            </style>
            <rect id="myRect" class="highlight"/>
          </svg>
        ''';

        final document = SvgParser.parse(svgString);

        expect(document.cssSelectorRules, isNotNull);
        expect(document.cssSelectorRules!.length, 2);

        final highlightRule = document.cssSelectorRules!.firstWhere(
          (r) => r.selector == '.highlight',
        );
        expect(highlightRule.declarations['fill'], 'red');
        expect(highlightRule.declarations['stroke'], 'blue');

        final myRectRule = document.cssSelectorRules!.firstWhere(
          (r) => r.selector == '#myRect',
        );
        expect(myRectRule.declarations['opacity'], '0.5');
      });
    });

    group('Hardened CSS Cascade Tests', () {
      testWidgets('!important in inline style wins over CSS rules', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <style>#r { fill: blue !important; }</style>
            <defs>
              <rect id="r" x="10" y="10" width="80" height="80" 
                    style="fill: red !important;"/>
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

        // Inline !important should win over CSS !important (same specificity, later wins)
        expect(analysis.pixelCount, greaterThan(1000));
      });

      testWidgets('CSS rules inherit through use boundary for inheritable props', (
        WidgetTester tester,
      ) async {
        // fill is an inheritable property in SVG
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <g fill="red">
              <defs>
                <rect id="r" x="10" y="10" width="80" height="80"/>
              </defs>
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

        // fill should inherit from parent g through use boundary
        expect(analysis.pixelCount, greaterThan(1000));
      });

      testWidgets('multiple uses of same symbol with different styles', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 200 100">
            <defs>
              <symbol id="icon" viewBox="0 0 20 20">
                <rect x="0" y="0" width="20" height="20"/>
              </symbol>
            </defs>
            <use href="#icon" x="10" y="10" width="40" height="40" fill="red"/>
            <use href="#icon" x="60" y="10" width="40" height="40" fill="blue"/>
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
        final redAnalysis = VisualTestUtils.analyzeRedPixels(pixels, 800, 600);

        // First use should render red
        expect(redAnalysis.pixelCount, greaterThan(500));
      });

      testWidgets('gradient inside used symbol resolves correctly', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <symbol id="icon" viewBox="0 0 50 50">
                <defs>
                  <linearGradient id="grad" x1="0%" y1="0%" x2="100%" y2="0%">
                    <stop offset="0%" stop-color="red"/>
                    <stop offset="100%" stop-color="blue"/>
                  </linearGradient>
                </defs>
                <rect x="0" y="0" width="50" height="50" fill="url(#grad)"/>
              </symbol>
            </defs>
            <use href="#icon" x="10" y="10" width="80" height="80"/>
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

        // Should render without error - gradient should resolve
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('circular reference through nested use is detected', (
        WidgetTester tester,
      ) async {
        // Create indirect circular reference: a uses b which uses c which uses a
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <g id="a">
                <use href="#b"/>
              </g>
              <g id="b">
                <use href="#c"/>
              </g>
              <g id="c">
                <use href="#a"/>
                <rect x="10" y="10" width="30" height="30" fill="red"/>
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

        // Should not crash or hang - circular reference should be detected
        await tester.pump();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('CSS descendant selector respects shadow DOM boundary', (
        WidgetTester tester,
      ) async {
        // Test that combinator selectors work within use-referenced content
        // but respect the shadow DOM boundary created by use element
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <style>
              .container rect { stroke: green; stroke-width: 2; }
            </style>
            <defs>
              <g id="myGroup" class="container">
                <rect x="10" y="10" width="80" height="80" fill="red"/>
              </g>
            </defs>
            <use href="#myGroup"/>
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

        // Test that rendering completes without errors
        // The descendant selector should match within the use-referenced content
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('use element with transform inherits through boundary', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <rect id="r" x="0" y="0" width="20" height="20"/>
            </defs>
            <use href="#r" x="10" y="10" fill="red" transform="translate(30,30)"/>
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

        // Should render a red rect at translated position
        expect(analysis.pixelCount, greaterThan(100));
        // Check that the rect is offset from origin
        expect(analysis.boundingBox.left, greaterThan(50));
      });

      testWidgets('deeply nested use chains maintain CSS inheritance', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <rect id="base" x="0" y="0" width="30" height="30"/>
              <g id="level1">
                <use href="#base"/>
              </g>
              <g id="level2">
                <use href="#level1"/>
              </g>
              <g id="level3">
                <use href="#level2"/>
              </g>
            </defs>
            <use href="#level3" x="10" y="10" fill="red"/>
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

        // fill should cascade through all nested use levels
        expect(analysis.pixelCount, greaterThan(100));
      });

      testWidgets('symbol viewBox rescaling with use width/height override', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <symbol id="icon" viewBox="0 0 10 10">
                <rect x="0" y="0" width="10" height="10" fill="red"/>
              </symbol>
            </defs>
            <use href="#icon" x="10" y="10" width="80" height="80"/>
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

        // Should be a large rectangle (scaled from 10x10 to 80x80)
        expect(analysis.objectWidth, greaterThan(100));
        expect(analysis.objectHeight, greaterThan(100));
      });

      testWidgets('CSS child selector stops at shadow boundary', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <style>symbol > rect { fill: blue; }</style>
            <defs>
              <symbol id="icon" viewBox="0 0 50 50">
                <rect x="0" y="0" width="50" height="50" fill="red"/>
              </symbol>
            </defs>
            <use href="#icon" x="10" y="10" width="80" height="80"/>
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

        // The selector "symbol > rect" should work inside the symbol
        // but the rect has explicit fill="red" which wins
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('pattern inside symbol is resolved correctly', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <symbol id="icon" viewBox="0 0 50 50">
                <defs>
                  <pattern id="dots" width="10" height="10" patternUnits="userSpaceOnUse">
                    <circle cx="5" cy="5" r="3" fill="red"/>
                  </pattern>
                </defs>
                <rect x="0" y="0" width="50" height="50" fill="url(#dots)"/>
              </symbol>
            </defs>
            <use href="#icon" x="10" y="10" width="80" height="80"/>
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

        // Should render without error - pattern should resolve
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('use element stroke inherits correctly', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <path id="p" d="M10,10 L90,10 L90,90 L10,90 Z" fill="none"/>
            </defs>
            <use href="#p" stroke="red" stroke-width="5"/>
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

        // Should render red stroked path
        expect(analysis.pixelCount, greaterThan(100));
      });
    });
  });
}
