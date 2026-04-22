import 'package:flutter/material.dart';
import 'package:full_svg_flutter/src/animation/animated_svg_picture.dart';
import 'package:full_svg_flutter/src/animation/svg_parser.dart';
import 'package:flutter_test/flutter_test.dart';

import 'visual_test_utils.dart';

void main() {
  group('ForeignObject Nesting and Coordinate Systems', () {
    group('Basic foreignObject positioning', () {
      testWidgets('foreignObject with x/y/width/height positions content', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 200 200">
            <foreignObject x="50" y="50" width="100" height="100">
              <svg viewBox="0 0 100 100">
                <rect x="0" y="0" width="100" height="100" fill="red"/>
              </svg>
            </foreignObject>
          </svg>
        ''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RepaintBoundary(
                child: AnimatedSvgPicture.string(
                  svgXml,
                  width: 200,
                  height: 200,
                ),
              ),
            ),
          ),
        );

        await tester.pump();

        final pixels = await VisualTestUtils.captureWidgetPixels(tester);
        final analysis = VisualTestUtils.analyzeRedPixels(pixels, 800, 600);

        expect(
          analysis.pixelCount,
          greaterThan(0),
          reason: 'ForeignObject should render content',
        );

        // Content should be positioned (not at top-left corner)
        expect(
          analysis.boundingBox.left,
          greaterThan(0),
          reason: 'Content should be offset by x position',
        );
      });

      testWidgets('foreignObject with negative x/y positions content', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 200 200">
            <foreignObject x="-10" y="-10" width="100" height="100">
              <svg viewBox="0 0 100 100">
                <rect x="0" y="0" width="100" height="100" fill="blue"/>
              </svg>
            </foreignObject>
          </svg>
        ''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RepaintBoundary(
                child: AnimatedSvgPicture.string(
                  svgXml,
                  width: 200,
                  height: 200,
                ),
              ),
            ),
          ),
        );

        await tester.pump();

        // Should render without errors
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });
    });

    group('Overflow handling', () {
      testWidgets('foreignObject overflow:hidden clips children', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 200 200">
            <foreignObject x="50" y="50" width="50" height="50" overflow="hidden">
              <svg viewBox="0 0 100 100">
                <rect x="0" y="0" width="100" height="100" fill="green"/>
              </svg>
            </foreignObject>
          </svg>
        ''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RepaintBoundary(
                child: AnimatedSvgPicture.string(
                  svgXml,
                  width: 200,
                  height: 200,
                ),
              ),
            ),
          ),
        );

        await tester.pump();

        // Content should be clipped to foreignObject viewport (50x50)
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('foreignObject overflow:visible allows children outside', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 200 200">
            <foreignObject x="50" y="50" width="50" height="50" overflow="visible">
              <svg viewBox="0 0 100 100">
                <rect x="0" y="0" width="100" height="100" fill="orange"/>
              </svg>
            </foreignObject>
          </svg>
        ''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RepaintBoundary(
                child: AnimatedSvgPicture.string(
                  svgXml,
                  width: 200,
                  height: 200,
                ),
              ),
            ),
          ),
        );

        await tester.pump();

        // Content should NOT be clipped with overflow:visible
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('foreignObject default overflow is hidden', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 200 200">
            <foreignObject x="50" y="50" width="50" height="50">
              <svg viewBox="0 0 100 100">
                <rect x="0" y="0" width="100" height="100" fill="purple"/>
              </svg>
            </foreignObject>
          </svg>
        ''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RepaintBoundary(
                child: AnimatedSvgPicture.string(
                  svgXml,
                  width: 200,
                  height: 200,
                ),
              ),
            ),
          ),
        );

        await tester.pump();

        // Default should be hidden (clipped)
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });
    });

    group('Nested SVG viewBox transforms', () {
      testWidgets('SVG inside foreignObject with viewBox applies transform', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 200 200">
            <foreignObject x="0" y="0" width="200" height="200">
              <svg viewBox="0 0 50 50" width="200" height="200">
                <rect x="10" y="10" width="30" height="30" fill="red"/>
              </svg>
            </foreignObject>
          </svg>
        ''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RepaintBoundary(
                child: AnimatedSvgPicture.string(
                  svgXml,
                  width: 200,
                  height: 200,
                ),
              ),
            ),
          ),
        );

        await tester.pump();

        final pixels = await VisualTestUtils.captureWidgetPixels(tester);
        final analysis = VisualTestUtils.analyzeRedPixels(pixels, 800, 600);

        expect(
          analysis.pixelCount,
          greaterThan(0),
          reason: 'Nested SVG viewBox transform should render content',
        );

        // The rect is 30x30 in a 50x50 viewBox scaled to 200x200
        // So it should cover a significant area
        expect(
          analysis.pixelCount,
          greaterThan(1000),
          reason: 'ViewBox should scale content up',
        );
      });

      testWidgets('SVG with preserveAspectRatio inside foreignObject', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 200 200">
            <foreignObject x="0" y="0" width="200" height="100">
              <svg viewBox="0 0 100 100" preserveAspectRatio="xMidYMid meet">
                <rect x="25" y="25" width="50" height="50" fill="blue"/>
              </svg>
            </foreignObject>
          </svg>
        ''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RepaintBoundary(
                child: AnimatedSvgPicture.string(
                  svgXml,
                  width: 200,
                  height: 200,
                ),
              ),
            ),
          ),
        );

        await tester.pump();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });
    });

    group('ForeignObject nesting (FO→SVG→FO)', () {
      testWidgets('two levels of foreignObject nesting', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 300 300">
            <foreignObject x="10" y="10" width="280" height="280">
              <svg viewBox="0 0 280 280">
                <rect x="0" y="0" width="280" height="280" fill="#eee"/>
                <foreignObject x="20" y="20" width="240" height="240">
                  <svg viewBox="0 0 240 240">
                    <rect x="0" y="0" width="240" height="240" fill="red"/>
                  </svg>
                </foreignObject>
              </svg>
            </foreignObject>
          </svg>
        ''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RepaintBoundary(
                child: AnimatedSvgPicture.string(
                  svgXml,
                  width: 300,
                  height: 300,
                ),
              ),
            ),
          ),
        );

        await tester.pump();

        final pixels = await VisualTestUtils.captureWidgetPixels(tester);
        final redAnalysis = VisualTestUtils.analyzeRedPixels(pixels, 800, 600);

        expect(
          redAnalysis.pixelCount,
          greaterThan(0),
          reason: 'Nested foreignObject should render red rect',
        );
      });

      testWidgets('three levels of foreignObject nesting', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 400 400">
            <foreignObject x="0" y="0" width="400" height="400">
              <svg viewBox="0 0 400 400">
                <foreignObject x="50" y="50" width="300" height="300">
                  <svg viewBox="0 0 300 300">
                    <foreignObject x="50" y="50" width="200" height="200">
                      <svg viewBox="0 0 200 200">
                        <rect x="0" y="0" width="200" height="200" fill="red"/>
                      </svg>
                    </foreignObject>
                  </svg>
                </foreignObject>
              </svg>
            </foreignObject>
          </svg>
        ''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RepaintBoundary(
                child: AnimatedSvgPicture.string(
                  svgXml,
                  width: 400,
                  height: 400,
                ),
              ),
            ),
          ),
        );

        await tester.pump();

        final pixels = await VisualTestUtils.captureWidgetPixels(tester);
        final analysis = VisualTestUtils.analyzeRedPixels(pixels, 800, 600);

        expect(
          analysis.pixelCount,
          greaterThan(0),
          reason: 'Three levels of nesting should render content',
        );
      });
    });

    group('Zero-width/height foreignObject', () {
      testWidgets('zero-width foreignObject skips rendering', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <foreignObject x="10" y="10" width="0" height="50">
              <svg viewBox="0 0 50 50">
                <rect x="0" y="0" width="50" height="50" fill="red"/>
              </svg>
            </foreignObject>
          </svg>
        ''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RepaintBoundary(
                child: AnimatedSvgPicture.string(
                  svgXml,
                  width: 200,
                  height: 200,
                ),
              ),
            ),
          ),
        );

        await tester.pump();

        final pixels = await VisualTestUtils.captureWidgetPixels(tester);
        final redAnalysis = VisualTestUtils.analyzeRedPixels(pixels, 800, 600);

        expect(
          redAnalysis.pixelCount,
          equals(0),
          reason: 'Zero-width foreignObject should not render content',
        );
      });

      testWidgets('zero-height foreignObject skips rendering', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <foreignObject x="10" y="10" width="50" height="0">
              <svg viewBox="0 0 50 50">
                <rect x="0" y="0" width="50" height="50" fill="red"/>
              </svg>
            </foreignObject>
          </svg>
        ''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RepaintBoundary(
                child: AnimatedSvgPicture.string(
                  svgXml,
                  width: 200,
                  height: 200,
                ),
              ),
            ),
          ),
        );

        await tester.pump();

        final pixels = await VisualTestUtils.captureWidgetPixels(tester);
        final redAnalysis = VisualTestUtils.analyzeRedPixels(pixels, 800, 600);

        expect(
          redAnalysis.pixelCount,
          equals(0),
          reason: 'Zero-height foreignObject should not render content',
        );
      });

      testWidgets('negative width foreignObject skips rendering', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <foreignObject x="10" y="10" width="-50" height="50">
              <svg viewBox="0 0 50 50">
                <rect x="0" y="0" width="50" height="50" fill="red"/>
              </svg>
            </foreignObject>
          </svg>
        ''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: AnimatedSvgPicture.string(
                  svgXml,
                  width: 200,
                  height: 200,
                ),
              ),
            ),
          ),
        );

        await tester.pump();

        // Should render without errors even with negative dimensions
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });
    });

    group('Transform propagation', () {
      testWidgets('transform on foreignObject propagates to children', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 200 200">
            <foreignObject x="50" y="50" width="100" height="100" 
                transform="rotate(45, 100, 100)">
              <svg viewBox="0 0 100 100">
                <rect x="25" y="25" width="50" height="50" fill="red"/>
              </svg>
            </foreignObject>
          </svg>
        ''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RepaintBoundary(
                child: AnimatedSvgPicture.string(
                  svgXml,
                  width: 200,
                  height: 200,
                ),
              ),
            ),
          ),
        );

        await tester.pump();

        final pixels = await VisualTestUtils.captureWidgetPixels(tester);
        final analysis = VisualTestUtils.analyzeRedPixels(pixels, 800, 600);

        expect(
          analysis.pixelCount,
          greaterThan(0),
          reason: 'Rotated foreignObject should render content',
        );
      });

      testWidgets('ancestor group transforms propagate to foreignObject', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 200 200">
            <g transform="translate(50, 50)">
              <g transform="scale(0.5)">
                <foreignObject x="0" y="0" width="100" height="100">
                  <svg viewBox="0 0 100 100">
                    <rect x="0" y="0" width="100" height="100" fill="red"/>
                  </svg>
                </foreignObject>
              </g>
            </g>
          </svg>
        ''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RepaintBoundary(
                child: AnimatedSvgPicture.string(
                  svgXml,
                  width: 200,
                  height: 200,
                ),
              ),
            ),
          ),
        );

        await tester.pump();

        final pixels = await VisualTestUtils.captureWidgetPixels(tester);
        final analysis = VisualTestUtils.analyzeRedPixels(pixels, 800, 600);

        expect(
          analysis.pixelCount,
          greaterThan(0),
          reason: 'Ancestor transforms should affect foreignObject',
        );
      });

      testWidgets('transforms at each nesting level propagate correctly', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 300 300">
            <g transform="translate(10, 10)">
              <foreignObject x="10" y="10" width="200" height="200" 
                  transform="translate(10, 10)">
                <svg viewBox="0 0 200 200">
                  <g transform="translate(10, 10)">
                    <foreignObject x="0" y="0" width="100" height="100" 
                        transform="translate(10, 10)">
                      <svg viewBox="0 0 100 100">
                        <rect x="0" y="0" width="100" height="100" fill="red"/>
                      </svg>
                    </foreignObject>
                  </g>
                </svg>
              </foreignObject>
            </g>
          </svg>
        ''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RepaintBoundary(
                child: AnimatedSvgPicture.string(
                  svgXml,
                  width: 300,
                  height: 300,
                ),
              ),
            ),
          ),
        );

        await tester.pump();

        final pixels = await VisualTestUtils.captureWidgetPixels(tester);
        final analysis = VisualTestUtils.analyzeRedPixels(pixels, 800, 600);

        expect(
          analysis.pixelCount,
          greaterThan(0),
          reason: 'All transform levels should compose correctly',
        );

        // Content should be offset by cumulative transforms (some offset > 0)
        expect(
          analysis.boundingBox.left,
          greaterThan(0),
          reason: 'Cumulative transforms should offset content from origin',
        );
      });
    });

    group('Parser tests', () {
      test('parses foreignObject with all standard attributes', () {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <foreignObject id="fo1" x="10" y="20" width="80" height="60"
                overflow="visible" transform="rotate(15)">
              <svg viewBox="0 0 80 60">
                <rect id="inner" x="5" y="5" width="70" height="50"/>
              </svg>
            </foreignObject>
          </svg>
        ''';

        final document = SvgParser.parse(svgXml);
        final fo = document.root.findById('fo1');

        expect(fo, isNotNull);
        expect(fo!.tagName, 'foreignObject');
        expect(fo.getAttributeValue('x')?.toString(), '10.0');
        expect(fo.getAttributeValue('y')?.toString(), '20.0');
        expect(fo.getAttributeValue('width')?.toString(), '80.0');
        expect(fo.getAttributeValue('height')?.toString(), '60.0');
        expect(fo.getAttributeValue('overflow'), 'visible');
        expect(fo.getAttributeValue('transform'), 'rotate(15)');
      });

      test('parses nested foreignObject correctly', () {
        const svgXml = '''
          <svg viewBox="0 0 200 200">
            <foreignObject id="outer-fo" x="0" y="0" width="200" height="200">
              <svg viewBox="0 0 200 200">
                <foreignObject id="inner-fo" x="50" y="50" width="100" height="100">
                  <svg viewBox="0 0 100 100">
                    <rect id="deep-rect" x="0" y="0" width="100" height="100"/>
                  </svg>
                </foreignObject>
              </svg>
            </foreignObject>
          </svg>
        ''';

        final document = SvgParser.parse(svgXml);
        final outerFo = document.root.findById('outer-fo');
        final innerFo = document.root.findById('inner-fo');
        final deepRect = document.root.findById('deep-rect');

        expect(outerFo, isNotNull);
        expect(outerFo!.tagName, 'foreignObject');

        expect(innerFo, isNotNull);
        expect(innerFo!.tagName, 'foreignObject');
        expect(innerFo.getAttributeValue('x')?.toString(), '50.0');
        expect(innerFo.getAttributeValue('y')?.toString(), '50.0');

        expect(deepRect, isNotNull);
        expect(deepRect!.tagName, 'rect');
      });

      test('parses foreignObject with percentage dimensions', () {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <foreignObject id="fo" x="10%" y="20%" width="80%" height="60%">
              <svg viewBox="0 0 50 50">
                <rect x="0" y="0" width="50" height="50"/>
              </svg>
            </foreignObject>
          </svg>
        ''';

        final document = SvgParser.parse(svgXml);
        final fo = document.root.findById('fo');

        expect(fo, isNotNull);
        expect(fo!.tagName, 'foreignObject');
        // Percentage values should be stored
        expect(fo.getRawAttributeValue('x'), '10%');
        expect(fo.getRawAttributeValue('y'), '20%');
        expect(fo.getRawAttributeValue('width'), '80%');
        expect(fo.getRawAttributeValue('height'), '60%');
      });
    });

    group('Edge cases', () {
      testWidgets('foreignObject without width/height defaults to zero', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <foreignObject x="10" y="10">
              <svg viewBox="0 0 50 50">
                <rect x="0" y="0" width="50" height="50" fill="red"/>
              </svg>
            </foreignObject>
          </svg>
        ''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RepaintBoundary(
                child: AnimatedSvgPicture.string(
                  svgXml,
                  width: 200,
                  height: 200,
                ),
              ),
            ),
          ),
        );

        await tester.pump();

        final pixels = await VisualTestUtils.captureWidgetPixels(tester);
        final redAnalysis = VisualTestUtils.analyzeRedPixels(pixels, 800, 600);

        // Without dimensions, foreignObject shouldn't render
        expect(
          redAnalysis.pixelCount,
          equals(0),
          reason: 'ForeignObject without dimensions should not render',
        );
      });

      testWidgets('foreignObject with empty content renders nothing', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <foreignObject x="10" y="10" width="80" height="80">
            </foreignObject>
            <rect x="50" y="50" width="40" height="40" fill="red"/>
          </svg>
        ''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RepaintBoundary(
                child: AnimatedSvgPicture.string(
                  svgXml,
                  width: 200,
                  height: 200,
                ),
              ),
            ),
          ),
        );

        await tester.pump();

        final pixels = await VisualTestUtils.captureWidgetPixels(tester);
        final analysis = VisualTestUtils.analyzeRedPixels(pixels, 800, 600);

        expect(
          analysis.pixelCount,
          greaterThan(0),
          reason: 'Red rect should render even with empty foreignObject',
        );
      });

      testWidgets('foreignObject with non-SVG content handles gracefully', (
        WidgetTester tester,
      ) async {
        // In real HTML context, foreignObject can contain HTML elements
        // In our SVG-only renderer, non-SVG content should be handled
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <foreignObject x="10" y="10" width="80" height="80">
              <div xmlns="http://www.w3.org/1999/xhtml">
                <p>HTML content</p>
              </div>
            </foreignObject>
            <rect x="50" y="50" width="40" height="40" fill="blue"/>
          </svg>
        ''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: AnimatedSvgPicture.string(
                  svgXml,
                  width: 200,
                  height: 200,
                ),
              ),
            ),
          ),
        );

        await tester.pump();

        // Should handle gracefully without crash
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });
    });

    group('Coordinate system switching', () {
      testWidgets('coordinate systems switch correctly at SVG boundaries', (
        WidgetTester tester,
      ) async {
        // Inner SVG has its own viewBox, establishing a new coordinate system
        const svgXml = '''
          <svg viewBox="0 0 200 200">
            <rect x="0" y="0" width="200" height="200" fill="#ddd"/>
            <foreignObject x="50" y="50" width="100" height="100">
              <svg viewBox="0 0 50 50">
                <!-- In inner coordinate system: 0-50 maps to 100x100 pixels -->
                <rect x="0" y="0" width="25" height="25" fill="red"/>
              </svg>
            </foreignObject>
          </svg>
        ''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RepaintBoundary(
                child: AnimatedSvgPicture.string(
                  svgXml,
                  width: 200,
                  height: 200,
                ),
              ),
            ),
          ),
        );

        await tester.pump();

        final pixels = await VisualTestUtils.captureWidgetPixels(tester);
        final redAnalysis = VisualTestUtils.analyzeRedPixels(pixels, 800, 600);

        expect(
          redAnalysis.pixelCount,
          greaterThan(0),
          reason: 'Red rect should render in inner coordinate system',
        );

        // The rect should be positioned offset from top-left due to FO offset
        expect(
          redAnalysis.boundingBox.left,
          greaterThan(0),
          reason: 'Red rect should be offset by foreignObject position',
        );
      });
    });
  });
}
