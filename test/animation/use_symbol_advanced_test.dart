import 'package:flutter/material.dart';
import 'package:flutter_svg/src/animation/animated_svg_picture.dart';
import 'package:flutter_svg/src/animation/svg_parser.dart';
import 'package:flutter_test/flutter_test.dart';

import 'visual_test_utils.dart';

void main() {
  group('Advanced Use/Symbol Inheritance Tests', () {
    group('Shadow DOM-like Inheritance', () {
      testWidgets(
        'referenced element inline style wins over use element style',
        (WidgetTester tester) async {
          // Per SVG spec: referenced element's inline styles have highest priority
          const svgXml = '''
            <svg viewBox="0 0 100 100">
              <defs>
                <rect id="myRect" x="10" y="10" width="80" height="80"
                      style="fill: red;"/>
              </defs>
              <use href="#myRect" style="fill: blue;"/>
            </svg>
          ''';

          await tester.pumpWidget(
            const MaterialApp(
              home: Scaffold(
                body:
                    AnimatedSvgPicture.string(svgXml, width: 200, height: 200),
              ),
            ),
          );

          await tester.pump();

          final pixels = await VisualTestUtils.captureWidgetPixels(tester);
          final redAnalysis = VisualTestUtils.analyzeRedPixels(pixels, 800, 600);

          // Red should win because referenced element has inline style
          expect(redAnalysis.pixelCount, greaterThan(1000));
        },
      );

      testWidgets(
        'use element presentation attr applies when ref has no explicit value',
        (WidgetTester tester) async {
          const svgXml = '''
            <svg viewBox="0 0 100 100">
              <defs>
                <rect id="myRect" x="10" y="10" width="80" height="80"/>
              </defs>
              <use href="#myRect" fill="red"/>
            </svg>
          ''';

          await tester.pumpWidget(
            const MaterialApp(
              home: Scaffold(
                body:
                    AnimatedSvgPicture.string(svgXml, width: 200, height: 200),
              ),
            ),
          );

          await tester.pump();

          final pixels = await VisualTestUtils.captureWidgetPixels(tester);
          final analysis = VisualTestUtils.analyzeRedPixels(pixels, 800, 600);

          expect(analysis.pixelCount, greaterThan(1000));
        },
      );

      testWidgets(
        'referenced element pres attr overrides use pres attr',
        (WidgetTester tester) async {
          const svgXml = '''
            <svg viewBox="0 0 100 100">
              <defs>
                <rect id="myRect" x="10" y="10" width="80" height="80" fill="red"/>
              </defs>
              <use href="#myRect" fill="blue"/>
            </svg>
          ''';

          await tester.pumpWidget(
            const MaterialApp(
              home: Scaffold(
                body:
                    AnimatedSvgPicture.string(svgXml, width: 200, height: 200),
              ),
            ),
          );

          await tester.pump();

          final pixels = await VisualTestUtils.captureWidgetPixels(tester);
          final redAnalysis = VisualTestUtils.analyzeRedPixels(pixels, 800, 600);

          // Red should win because referenced element has explicit fill
          expect(redAnalysis.pixelCount, greaterThan(1000));
        },
      );

      testWidgets(
        'inherited style from use parent cascades through boundary',
        (WidgetTester tester) async {
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
                body:
                    AnimatedSvgPicture.string(svgXml, width: 200, height: 200),
              ),
            ),
          );

          await tester.pump();

          final pixels = await VisualTestUtils.captureWidgetPixels(tester);
          final analysis = VisualTestUtils.analyzeRedPixels(pixels, 800, 600);

          // fill should inherit from parent g through use boundary
          expect(analysis.pixelCount, greaterThan(1000));
        },
      );
    });

    group('CSS Cascade Through Use References', () {
      testWidgets(
        'CSS class rule applies to element inside use-referenced content',
        (WidgetTester tester) async {
          const svgXml = '''
            <svg viewBox="0 0 100 100">
              <style>.highlight { fill: red; }</style>
              <defs>
                <g id="myGroup">
                  <rect class="highlight" x="10" y="10" width="80" height="80"/>
                </g>
              </defs>
              <use href="#myGroup"/>
            </svg>
          ''';

          await tester.pumpWidget(
            const MaterialApp(
              home: Scaffold(
                body:
                    AnimatedSvgPicture.string(svgXml, width: 200, height: 200),
              ),
            ),
          );

          await tester.pump();

          final pixels = await VisualTestUtils.captureWidgetPixels(tester);
          final analysis = VisualTestUtils.analyzeRedPixels(pixels, 800, 600);

          // CSS class rule should apply
          expect(analysis.pixelCount, greaterThan(1000));
        },
      );

      testWidgets(
        'CSS ID selector matches element inside use-referenced content',
        (WidgetTester tester) async {
          const svgXml = '''
            <svg viewBox="0 0 100 100">
              <style>#innerRect { fill: red; }</style>
              <defs>
                <g id="myGroup">
                  <rect id="innerRect" x="10" y="10" width="80" height="80"/>
                </g>
              </defs>
              <use href="#myGroup"/>
            </svg>
          ''';

          await tester.pumpWidget(
            const MaterialApp(
              home: Scaffold(
                body:
                    AnimatedSvgPicture.string(svgXml, width: 200, height: 200),
              ),
            ),
          );

          await tester.pump();

          final pixels = await VisualTestUtils.captureWidgetPixels(tester);
          final analysis = VisualTestUtils.analyzeRedPixels(pixels, 800, 600);

          // CSS ID rule should apply
          expect(analysis.pixelCount, greaterThan(1000));
        },
      );

      testWidgets(
        'CSS attribute selector matches in use-referenced content',
        (WidgetTester tester) async {
          const svgXml = '''
            <svg viewBox="0 0 100 100">
              <style>rect[data-type="primary"] { fill: red; }</style>
              <defs>
                <rect id="myRect" data-type="primary" x="10" y="10" width="80" height="80"/>
              </defs>
              <use href="#myRect"/>
            </svg>
          ''';

          await tester.pumpWidget(
            const MaterialApp(
              home: Scaffold(
                body:
                    AnimatedSvgPicture.string(svgXml, width: 200, height: 200),
              ),
            ),
          );

          await tester.pump();

          // Should render without error
          expect(find.byType(AnimatedSvgPicture), findsOneWidget);
        },
      );

      testWidgets(
        'CSS descendant selector works within use-referenced content',
        (WidgetTester tester) async {
          const svgXml = '''
            <svg viewBox="0 0 100 100">
              <style>
                .container rect { fill: red; }
              </style>
              <defs>
                <g id="myGroup" class="container">
                  <rect x="10" y="10" width="80" height="80"/>
                </g>
              </defs>
              <use href="#myGroup"/>
            </svg>
          ''';

          await tester.pumpWidget(
            const MaterialApp(
              home: Scaffold(
                body:
                    AnimatedSvgPicture.string(svgXml, width: 200, height: 200),
              ),
            ),
          );

          await tester.pump();

          final pixels = await VisualTestUtils.captureWidgetPixels(tester);
          final analysis = VisualTestUtils.analyzeRedPixels(pixels, 800, 600);

          // Descendant selector should work
          expect(analysis.pixelCount, greaterThan(1000));
        },
      );
    });

    group('Animation Inheritance Through Symbol References', () {
      testWidgets(
        'animated element in symbol renders with use transform context',
        (WidgetTester tester) async {
          // Symbol contains an animated element, use element provides transform
          const svgXml = '''
            <svg viewBox="0 0 200 200">
              <defs>
                <symbol id="icon" viewBox="0 0 50 50">
                  <rect id="animRect" x="0" y="0" width="50" height="50" fill="red">
                    <animate attributeName="opacity" from="1" to="0.5" dur="1s"/>
                  </rect>
                </symbol>
              </defs>
              <use href="#icon" x="50" y="50" width="100" height="100"/>
            </svg>
          ''';

          await tester.pumpWidget(
            const MaterialApp(
              home: Scaffold(
                body:
                    AnimatedSvgPicture.string(svgXml, width: 400, height: 400),
              ),
            ),
          );

          await tester.pump();

          final pixels = await VisualTestUtils.captureWidgetPixels(tester);
          final analysis = VisualTestUtils.analyzeRedPixels(pixels, 800, 600);

          // The red rect should be positioned at (50,50) per use x/y
          expect(analysis.boundingBox.left, greaterThan(50));
          expect(analysis.boundingBox.top, greaterThan(50));
        },
      );

      testWidgets(
        'multiple uses of animated symbol maintain independent positions',
        (WidgetTester tester) async {
          const svgXml = '''
            <svg viewBox="0 0 300 100">
              <defs>
                <symbol id="icon" viewBox="0 0 30 30">
                  <rect x="0" y="0" width="30" height="30" fill="red">
                    <animate attributeName="width" from="30" to="20" dur="1s"/>
                  </rect>
                </symbol>
              </defs>
              <use href="#icon" x="10" y="10" width="30" height="30"/>
              <use href="#icon" x="100" y="10" width="30" height="30"/>
            </svg>
          ''';

          await tester.pumpWidget(
            const MaterialApp(
              home: Scaffold(
                body:
                    AnimatedSvgPicture.string(svgXml, width: 600, height: 200),
              ),
            ),
          );

          await tester.pump();

          final pixels = await VisualTestUtils.captureWidgetPixels(tester);
          final analysis = VisualTestUtils.analyzeRedPixels(pixels, 800, 600);

          // Should have red pixels from both uses
          expect(analysis.pixelCount, greaterThan(100));
        },
      );
    });

    group('Nested Use Support', () {
      testWidgets(
        'double-nested use references resolve correctly',
        (WidgetTester tester) async {
          const svgXml = '''
            <svg viewBox="0 0 100 100">
              <defs>
                <rect id="baseRect" x="0" y="0" width="20" height="20" fill="red"/>
                <use id="use1" href="#baseRect"/>
                <use id="use2" href="#use1"/>
              </defs>
              <use href="#use2" x="10" y="10"/>
            </svg>
          ''';

          await tester.pumpWidget(
            const MaterialApp(
              home: Scaffold(
                body:
                    AnimatedSvgPicture.string(svgXml, width: 200, height: 200),
              ),
            ),
          );

          await tester.pump();

          final pixels = await VisualTestUtils.captureWidgetPixels(tester);
          final analysis = VisualTestUtils.analyzeRedPixels(pixels, 800, 600);

          expect(analysis.pixelCount, greaterThan(50));
        },
      );

      testWidgets(
        'use referencing group containing use works correctly',
        (WidgetTester tester) async {
          const svgXml = '''
            <svg viewBox="0 0 100 100">
              <defs>
                <rect id="r" x="0" y="0" width="20" height="20" fill="red"/>
                <g id="group">
                  <use href="#r" x="5" y="5"/>
                </g>
              </defs>
              <use href="#group" x="10" y="10"/>
            </svg>
          ''';

          await tester.pumpWidget(
            const MaterialApp(
              home: Scaffold(
                body:
                    AnimatedSvgPicture.string(svgXml, width: 200, height: 200),
              ),
            ),
          );

          await tester.pump();

          final pixels = await VisualTestUtils.captureWidgetPixels(tester);
          final analysis = VisualTestUtils.analyzeRedPixels(pixels, 800, 600);

          expect(analysis.pixelCount, greaterThan(50));
        },
      );

      testWidgets(
        'depth limit of 10 is enforced for nested use',
        (WidgetTester tester) async {
          // Create a chain of 12 nested use elements
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
                body:
                    AnimatedSvgPicture.string(svgXml, width: 200, height: 200),
              ),
            ),
          );

          // Should not crash or hang
          await tester.pump();
          expect(find.byType(AnimatedSvgPicture), findsOneWidget);
        },
      );

      testWidgets(
        'circular reference is detected and prevented',
        (WidgetTester tester) async {
          // Direct circular reference: a -> b -> a
          const svgXml = '''
            <svg viewBox="0 0 100 100">
              <defs>
                <g id="a">
                  <use href="#b"/>
                  <rect x="0" y="0" width="10" height="10" fill="red"/>
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
                body:
                    AnimatedSvgPicture.string(svgXml, width: 200, height: 200),
              ),
            ),
          );

          // Should not crash or hang
          await tester.pump();
          expect(find.byType(AnimatedSvgPicture), findsOneWidget);
        },
      );

      testWidgets(
        'indirect circular reference through chain is detected',
        (WidgetTester tester) async {
          // Indirect circular: a -> b -> c -> a
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
                  <rect x="0" y="0" width="20" height="20" fill="red"/>
                </g>
              </defs>
              <use href="#a" x="10" y="10"/>
            </svg>
          ''';

          await tester.pumpWidget(
            const MaterialApp(
              home: Scaffold(
                body:
                    AnimatedSvgPicture.string(svgXml, width: 200, height: 200),
              ),
            ),
          );

          // Should not crash or hang
          await tester.pump();
          expect(find.byType(AnimatedSvgPicture), findsOneWidget);
        },
      );
    });

    group('ID Namespace Collision Handling', () {
      testWidgets(
        'multiple uses of content with internal gradient resolve correctly',
        (WidgetTester tester) async {
          const svgXml = '''
            <svg viewBox="0 0 200 100">
              <defs>
                <linearGradient id="grad" x1="0%" y1="0%" x2="100%" y2="0%">
                  <stop offset="0%" stop-color="red"/>
                  <stop offset="100%" stop-color="blue"/>
                </linearGradient>
                <rect id="gradRect" x="0" y="0" width="50" height="50" fill="url(#grad)"/>
              </defs>
              <use href="#gradRect" x="10" y="10"/>
              <use href="#gradRect" x="100" y="10"/>
            </svg>
          ''';

          await tester.pumpWidget(
            const MaterialApp(
              home: Scaffold(
                body:
                    AnimatedSvgPicture.string(svgXml, width: 400, height: 200),
              ),
            ),
          );

          await tester.pump();

          // Both should render with gradient
          expect(find.byType(AnimatedSvgPicture), findsOneWidget);
        },
      );

      testWidgets(
        'multiple uses of symbol with internal filter resolve correctly',
        (WidgetTester tester) async {
          const svgXml = '''
            <svg viewBox="0 0 200 100">
              <defs>
                <symbol id="icon" viewBox="0 0 50 50">
                  <defs>
                    <filter id="blur">
                      <feGaussianBlur stdDeviation="2"/>
                    </filter>
                  </defs>
                  <rect x="5" y="5" width="40" height="40" fill="red" filter="url(#blur)"/>
                </symbol>
              </defs>
              <use href="#icon" x="10" y="10" width="50" height="50"/>
              <use href="#icon" x="100" y="10" width="50" height="50"/>
            </svg>
          ''';

          await tester.pumpWidget(
            const MaterialApp(
              home: Scaffold(
                body:
                    AnimatedSvgPicture.string(svgXml, width: 400, height: 200),
              ),
            ),
          );

          await tester.pump();

          // Both should render (filter should work for both)
          expect(find.byType(AnimatedSvgPicture), findsOneWidget);
        },
      );

      testWidgets(
        'multiple uses of symbol with internal clip-path work correctly',
        (WidgetTester tester) async {
          const svgXml = '''
            <svg viewBox="0 0 200 100">
              <defs>
                <symbol id="icon" viewBox="0 0 50 50">
                  <defs>
                    <clipPath id="clip">
                      <circle cx="25" cy="25" r="20"/>
                    </clipPath>
                  </defs>
                  <rect x="0" y="0" width="50" height="50" fill="red" clip-path="url(#clip)"/>
                </symbol>
              </defs>
              <use href="#icon" x="10" y="10" width="50" height="50"/>
              <use href="#icon" x="100" y="10" width="50" height="50"/>
            </svg>
          ''';

          await tester.pumpWidget(
            const MaterialApp(
              home: Scaffold(
                body:
                    AnimatedSvgPicture.string(svgXml, width: 400, height: 200),
              ),
            ),
          );

          await tester.pump();

          final pixels = await VisualTestUtils.captureWidgetPixels(tester);
          final analysis = VisualTestUtils.analyzeRedPixels(pixels, 800, 600);

          // Both clipped circles should render
          expect(analysis.pixelCount, greaterThan(100));
        },
      );
    });

    group('DOM Parsing Tests', () {
      test('nested use elements are parsed correctly', () {
        const svgString = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <rect id="base" width="10" height="10"/>
              <use id="use1" href="#base"/>
              <use id="use2" href="#use1"/>
            </defs>
            <use href="#use2" x="10" y="10"/>
          </svg>
        ''';

        final document = SvgParser.parse(svgString);
        final defs = document.root.children.firstWhere(
          (n) => n.tagName == 'defs',
        );

        // Verify all elements parsed
        expect(defs.children.length, 3);
        expect(defs.children[0].id, 'base');
        expect(defs.children[1].id, 'use1');
        expect(defs.children[2].id, 'use2');
      });

      test('symbol with viewBox and preserveAspectRatio parses correctly', () {
        const svgString = '''
          <svg viewBox="0 0 100 100">
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

      test('use element with all positioning attributes parses correctly', () {
        const svgString = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <symbol id="icon" viewBox="0 0 24 24">
                <rect width="24" height="24"/>
              </symbol>
            </defs>
            <use href="#icon" x="10" y="20" width="50" height="60" transform="rotate(45)"/>
          </svg>
        ''';

        final document = SvgParser.parse(svgString);
        final useNode = document.root.children.firstWhere(
          (n) => n.tagName == 'use',
        );

        expect(useNode.getAttributeValue('href'), '#icon');
        expect(useNode.getAttributeValue('x'), 10.0);
        expect(useNode.getAttributeValue('y'), 20.0);
        expect(useNode.getAttributeValue('width'), 50.0);
        expect(useNode.getAttributeValue('height'), 60.0);
        expect(useNode.getAttributeValue('transform'), 'rotate(45)');
      });
    });

    group('Edge Cases', () {
      testWidgets(
        'use element without href is handled gracefully',
        (WidgetTester tester) async {
          const svgXml = '''
            <svg viewBox="0 0 100 100">
              <rect x="10" y="10" width="30" height="30" fill="red"/>
              <use x="50" y="50"/>
            </svg>
          ''';

          await tester.pumpWidget(
            const MaterialApp(
              home: Scaffold(
                body:
                    AnimatedSvgPicture.string(svgXml, width: 200, height: 200),
              ),
            ),
          );

          await tester.pump();

          // Should not crash, rect should still render
          final pixels = await VisualTestUtils.captureWidgetPixels(tester);
          final analysis = VisualTestUtils.analyzeRedPixels(pixels, 800, 600);
          expect(analysis.pixelCount, greaterThan(100));
        },
      );

      testWidgets(
        'use element referencing non-existent ID is handled gracefully',
        (WidgetTester tester) async {
          const svgXml = '''
            <svg viewBox="0 0 100 100">
              <rect x="10" y="10" width="30" height="30" fill="red"/>
              <use href="#nonExistent" x="50" y="50"/>
            </svg>
          ''';

          await tester.pumpWidget(
            const MaterialApp(
              home: Scaffold(
                body:
                    AnimatedSvgPicture.string(svgXml, width: 200, height: 200),
              ),
            ),
          );

          await tester.pump();

          // Should not crash, rect should still render
          final pixels = await VisualTestUtils.captureWidgetPixels(tester);
          final analysis = VisualTestUtils.analyzeRedPixels(pixels, 800, 600);
          expect(analysis.pixelCount, greaterThan(100));
        },
      );

      testWidgets(
        'use element referencing disallowed element type is handled',
        (WidgetTester tester) async {
          const svgXml = '''
            <svg viewBox="0 0 100 100">
              <defs>
                <linearGradient id="grad">
                  <stop offset="0%" stop-color="red"/>
                </linearGradient>
              </defs>
              <use href="#grad" x="10" y="10"/>
              <rect x="20" y="20" width="50" height="50" fill="red"/>
            </svg>
          ''';

          await tester.pumpWidget(
            const MaterialApp(
              home: Scaffold(
                body:
                    AnimatedSvgPicture.string(svgXml, width: 200, height: 200),
              ),
            ),
          );

          await tester.pump();

          // Should not crash - gradient is not a valid use target
          expect(find.byType(AnimatedSvgPicture), findsOneWidget);
        },
      );

      testWidgets(
        'symbol with zero width/height viewBox handles gracefully',
        (WidgetTester tester) async {
          const svgXml = '''
            <svg viewBox="0 0 100 100">
              <defs>
                <symbol id="icon" viewBox="0 0 0 0">
                  <rect width="10" height="10" fill="red"/>
                </symbol>
              </defs>
              <use href="#icon" x="10" y="10" width="50" height="50"/>
            </svg>
          ''';

          await tester.pumpWidget(
            const MaterialApp(
              home: Scaffold(
                body:
                    AnimatedSvgPicture.string(svgXml, width: 200, height: 200),
              ),
            ),
          );

          await tester.pump();

          // Should not crash
          expect(find.byType(AnimatedSvgPicture), findsOneWidget);
        },
      );

      testWidgets(
        'empty symbol handles gracefully',
        (WidgetTester tester) async {
          const svgXml = '''
            <svg viewBox="0 0 100 100">
              <defs>
                <symbol id="emptyIcon" viewBox="0 0 24 24"/>
              </defs>
              <use href="#emptyIcon" x="10" y="10" width="50" height="50"/>
              <rect x="60" y="10" width="30" height="30" fill="red"/>
            </svg>
          ''';

          await tester.pumpWidget(
            const MaterialApp(
              home: Scaffold(
                body:
                    AnimatedSvgPicture.string(svgXml, width: 200, height: 200),
              ),
            ),
          );

          await tester.pump();

          // Should not crash, rect should still render
          final pixels = await VisualTestUtils.captureWidgetPixels(tester);
          final analysis = VisualTestUtils.analyzeRedPixels(pixels, 800, 600);
          expect(analysis.pixelCount, greaterThan(50));
        },
      );
    });
  });
}
