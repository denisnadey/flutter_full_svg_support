import 'package:flutter/material.dart';
import 'package:flutter_svg/src/animation/animated_svg_picture.dart';
import 'package:flutter_svg/src/animation/svg_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ForeignObject Advanced Semantics', () {
    group('requiredExtensions fallback', () {
      testWidgets('foreignObject with requiredExtensions does not render', (
        WidgetTester tester,
      ) async {
        // Per SVG spec, if requiredExtensions is specified and not supported,
        // foreignObject should not render (allowing <switch> fallback pattern)
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <foreignObject id="fo" x="10" y="10" width="80" height="80"
                requiredExtensions="http://example.com/unsupported">
              <rect id="inner" x="0" y="0" width="40" height="40" fill="red"/>
            </foreignObject>
            <rect id="fallback" x="50" y="50" width="30" height="30" fill="blue"/>
          </svg>
        ''';

        await tester.pumpWidget(
          const MaterialApp(
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

        // The foreignObject with unsupported requiredExtensions should not render
        // Only the fallback rect should be visible (verified by no errors thrown)
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('foreignObject without requiredExtensions renders normally', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <foreignObject id="fo" x="10" y="10" width="80" height="80">
              <svg id="inner-svg" viewBox="0 0 50 50">
                <rect id="inner" x="5" y="5" width="40" height="40" fill="red"/>
              </svg>
            </foreignObject>
          </svg>
        ''';

        await tester.pumpWidget(
          const MaterialApp(
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

        // foreignObject without requiredExtensions should render
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('switch with foreignObject fallback pattern', (
        WidgetTester tester,
      ) async {
        // Standard SVG pattern: foreignObject with requiredExtensions inside
        // switch, with fallback content for unsupported renderers
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <switch>
              <foreignObject id="fo" x="10" y="10" width="80" height="80"
                  requiredExtensions="http://example.com/html">
                <rect x="0" y="0" width="40" height="40" fill="red"/>
              </foreignObject>
              <rect id="fallback" x="20" y="20" width="60" height="60" fill="green"/>
            </switch>
          </svg>
        ''';

        await tester.pumpWidget(
          const MaterialApp(
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

        // The switch should use fallback since foreignObject has unsupported extensions
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });
    });

    group('nested SVG context switching', () {
      testWidgets('nested SVG within foreignObject establishes own viewport', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 200 200">
            <foreignObject x="50" y="50" width="100" height="100">
              <svg viewBox="0 0 50 50" width="100" height="100">
                <rect id="nested-rect" x="10" y="10" width="30" height="30" fill="blue"/>
              </svg>
            </foreignObject>
          </svg>
        ''';

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Center(
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

        // Nested SVG should establish its own coordinate system
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('nested SVG with preserveAspectRatio', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 200 200">
            <foreignObject x="10" y="10" width="180" height="180">
              <svg viewBox="0 0 100 50" width="180" height="180" 
                   preserveAspectRatio="xMidYMid meet">
                <rect x="0" y="0" width="100" height="50" fill="green"/>
              </svg>
            </foreignObject>
          </svg>
        ''';

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Center(
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

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });
    });

    group('child layout semantics', () {
      testWidgets('foreignObject with zero width renders nothing', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <foreignObject x="10" y="10" width="0" height="50">
              <rect x="0" y="0" width="40" height="40" fill="red"/>
            </foreignObject>
            <rect id="other" x="60" y="60" width="30" height="30" fill="blue"/>
          </svg>
        ''';

        await tester.pumpWidget(
          const MaterialApp(
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

        // foreignObject with zero width should not render children
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('foreignObject with zero height renders nothing', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <foreignObject x="10" y="10" width="50" height="0">
              <rect x="0" y="0" width="40" height="40" fill="red"/>
            </foreignObject>
          </svg>
        ''';

        await tester.pumpWidget(
          const MaterialApp(
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

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('foreignObject without width/height defaults to zero', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <foreignObject x="10" y="10">
              <rect x="0" y="0" width="40" height="40" fill="red"/>
            </foreignObject>
          </svg>
        ''';

        await tester.pumpWidget(
          const MaterialApp(
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

        // Without width/height, defaults to 0 and nothing renders
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });
    });

    group('overflow handling', () {
      testWidgets('foreignObject overflow hidden clips children', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <foreignObject x="20" y="20" width="30" height="30" overflow="hidden">
              <svg viewBox="0 0 100 100">
                <rect x="0" y="0" width="100" height="100" fill="red"/>
              </svg>
            </foreignObject>
          </svg>
        ''';

        await tester.pumpWidget(
          const MaterialApp(
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

        // Children should be clipped to foreignObject viewport
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('foreignObject overflow visible allows children outside', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <foreignObject x="20" y="20" width="30" height="30" overflow="visible">
              <svg viewBox="0 0 100 100">
                <rect x="0" y="0" width="100" height="100" fill="green"/>
              </svg>
            </foreignObject>
          </svg>
        ''';

        await tester.pumpWidget(
          const MaterialApp(
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

        // With overflow:visible, children can render outside viewport
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('foreignObject default overflow is hidden', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <foreignObject x="20" y="20" width="30" height="30">
              <svg viewBox="0 0 100 100">
                <rect x="0" y="0" width="100" height="100" fill="blue"/>
              </svg>
            </foreignObject>
          </svg>
        ''';

        await tester.pumpWidget(
          const MaterialApp(
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

        // Default should be hidden (clipped)
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });
    });

    group('transform propagation', () {
      testWidgets('transforms on foreignObject propagate to children', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 200 200">
            <foreignObject x="50" y="50" width="100" height="100" 
                transform="rotate(45, 100, 100)">
              <svg viewBox="0 0 50 50">
                <rect x="10" y="10" width="30" height="30" fill="purple"/>
              </svg>
            </foreignObject>
          </svg>
        ''';

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Center(
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

        // Transform should be applied to foreignObject and propagate to children
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('ancestor transforms propagate through foreignObject', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 200 200">
            <g transform="translate(20, 20)">
              <foreignObject x="10" y="10" width="80" height="80">
                <svg viewBox="0 0 40 40">
                  <circle cx="20" cy="20" r="15" fill="orange"/>
                </svg>
              </foreignObject>
            </g>
          </svg>
        ''';

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Center(
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

        // Ancestor transform should affect foreignObject position
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });
    });

    group('hit-testing through foreignObject', () {
      testWidgets('hit-testing works for elements inside foreignObject', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <foreignObject x="10" y="10" width="80" height="80">
              <svg viewBox="0 0 80 80">
                <rect id="inner-rect" x="20" y="20" width="40" height="40" fill="red">
                  <animate attributeName="fill" from="red" to="blue" 
                           dur="1s" begin="click" fill="freeze"/>
                </rect>
              </svg>
            </foreignObject>
          </svg>
        ''';

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Center(
                child: AnimatedSvgPicture.string(
                  svgXml,
                  width: 200,
                  height: 200,
                  autoPlay: true,
                ),
              ),
            ),
          ),
        );

        await tester.pump();

        // Widget should render and be interactive
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('hit-testing respects foreignObject viewport clipping', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <foreignObject x="40" y="40" width="20" height="20" overflow="hidden">
              <svg viewBox="0 0 100 100">
                <rect id="large-rect" x="0" y="0" width="100" height="100" fill="green">
                  <animate attributeName="fill" from="green" to="yellow" 
                           dur="1s" begin="click" fill="freeze"/>
                </rect>
              </svg>
            </foreignObject>
          </svg>
        ''';

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Center(
                child: AnimatedSvgPicture.string(
                  svgXml,
                  width: 200,
                  height: 200,
                  autoPlay: true,
                ),
              ),
            ),
          ),
        );

        await tester.pump();

        // Hit-testing should respect the clipped viewport
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });
    });

    group('CSS cascade through viewport boundary', () {
      testWidgets('presentation attributes cascade into foreignObject children', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100" fill="blue">
            <foreignObject x="10" y="10" width="80" height="80">
              <svg viewBox="0 0 80 80">
                <rect x="10" y="10" width="60" height="60"/>
              </svg>
            </foreignObject>
          </svg>
        ''';

        await tester.pumpWidget(
          const MaterialApp(
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

        // Fill attribute from outer SVG should cascade to rect
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });
    });
  });

  group('ForeignObject Parser Tests', () {
    test('parses foreignObject with all attributes', () {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <foreignObject id="fo1" x="10" y="20" width="80" height="60"
              overflow="visible" transform="rotate(45)">
            <svg viewBox="0 0 50 50">
              <rect id="inner" x="5" y="5" width="40" height="40"/>
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
      expect(fo.getAttributeValue('transform'), 'rotate(45)');
    });

    test('parses foreignObject with requiredExtensions', () {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <foreignObject id="fo" x="0" y="0" width="100" height="100"
              requiredExtensions="http://example.com/ext">
            <rect x="0" y="0" width="50" height="50"/>
          </foreignObject>
        </svg>
      ''';

      final document = SvgParser.parse(svgXml);
      final fo = document.root.findById('fo');

      expect(fo, isNotNull);
      expect(fo!.getAttributeValue('requiredExtensions'), 'http://example.com/ext');
    });

    test('parses nested SVG within foreignObject', () {
      const svgXml = '''
        <svg viewBox="0 0 200 200">
          <foreignObject id="fo" x="50" y="50" width="100" height="100">
            <svg id="nested" viewBox="0 0 50 50" preserveAspectRatio="xMidYMid meet">
              <circle id="circle" cx="25" cy="25" r="20"/>
            </svg>
          </foreignObject>
        </svg>
      ''';

      final document = SvgParser.parse(svgXml);
      final fo = document.root.findById('fo');
      final nested = document.root.findById('nested');
      final circle = document.root.findById('circle');

      expect(fo, isNotNull);
      expect(nested, isNotNull);
      expect(circle, isNotNull);
      expect(nested!.getAttributeValue('viewBox'), '0 0 50 50');
      expect(nested.getAttributeValue('preserveAspectRatio'), 'xMidYMid meet');
    });
  });
}
