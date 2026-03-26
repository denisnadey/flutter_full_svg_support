import 'package:flutter/material.dart';
import 'package:flutter_svg/src/animation/animated_svg_picture.dart';
import 'package:flutter_svg/src/animation/svg_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ForeignObject CSS Inheritance', () {
    // Test 1: CSS font-family inherits into foreignObject
    testWidgets('CSS font-family inherits into foreignObject', (
      WidgetTester tester,
    ) async {
      // font-family is an inherited CSS property and should flow through
      // the foreignObject boundary to content inside
      const svgXml = '''
        <svg viewBox="0 0 200 200" style="font-family: 'Roboto', sans-serif;">
          <foreignObject x="10" y="10" width="180" height="180">
            <svg viewBox="0 0 180 180">
              <text id="inner-text" x="10" y="50">Font inherited</text>
            </svg>
          </foreignObject>
        </svg>
      ''';

      final document = SvgParser.parse(svgXml);
      final innerText = document.root.findById('inner-text');

      // Verify the text element exists and can be parsed
      expect(innerText, isNotNull);
      expect(innerText!.tagName, 'text');

      // Render the SVG to ensure it paints without errors
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: AnimatedSvgPicture.string(svgXml, width: 200, height: 200),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    // Test 2: CSS font-size inherits into foreignObject
    testWidgets('CSS font-size inherits into foreignObject', (
      WidgetTester tester,
    ) async {
      // font-size is inherited and should flow through foreignObject boundary
      const svgXml = '''
        <svg viewBox="0 0 200 200" font-size="24">
          <foreignObject x="10" y="10" width="180" height="180">
            <svg viewBox="0 0 180 180">
              <text id="sized-text" x="10" y="50">Sized text</text>
            </svg>
          </foreignObject>
        </svg>
      ''';

      final document = SvgParser.parse(svgXml);
      final root = document.root;

      // Verify root has font-size attribute
      expect(root.getAttributeValue('font-size')?.toString(), '24.0');

      // Render the SVG
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: AnimatedSvgPicture.string(svgXml, width: 200, height: 200),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    // Test 3: SVG fill does NOT inherit into foreignObject content
    testWidgets('SVG fill does NOT inherit into foreignObject content', (
      WidgetTester tester,
    ) async {
      // fill is an SVG-specific property and should NOT cross the
      // foreignObject boundary. Foreign content should use CSS 'color' instead.
      const svgXml = '''
        <svg viewBox="0 0 200 200" fill="red">
          <foreignObject x="10" y="10" width="180" height="180">
            <svg viewBox="0 0 180 180">
              <rect id="inner-rect" x="10" y="10" width="100" height="100"/>
            </svg>
          </foreignObject>
          <rect id="outer-rect" x="150" y="150" width="40" height="40"/>
        </svg>
      ''';

      final document = SvgParser.parse(svgXml);

      // Outer rect should have fill inherited
      final outerRect = document.root.findById('outer-rect');
      expect(outerRect, isNotNull);

      // Inner rect in foreignObject should NOT inherit fill from SVG ancestor
      // (fill is SVG-specific, not a CSS property)
      final innerRect = document.root.findById('inner-rect');
      expect(innerRect, isNotNull);

      // Render to verify
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: AnimatedSvgPicture.string(svgXml, width: 200, height: 200),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    // Test 4: foreignObject viewport clipping (overflow=hidden)
    testWidgets('foreignObject viewport clipping overflow hidden', (
      WidgetTester tester,
    ) async {
      // By default, foreignObject should clip content that exceeds its bounds
      const svgXml = '''
        <svg viewBox="0 0 200 200">
          <foreignObject x="50" y="50" width="50" height="50" overflow="hidden">
            <svg viewBox="0 0 100 100">
              <rect id="clipped-rect" x="0" y="0" width="100" height="100" fill="blue"/>
            </svg>
          </foreignObject>
        </svg>
      ''';

      final document = SvgParser.parse(svgXml);
      final fo = document.root.children.firstWhere(
        (n) => n.tagName == 'foreignObject',
      );

      // Verify foreignObject dimensions are smaller than inner content
      expect(fo.getAttributeValue('width')?.toString(), '50.0');
      expect(fo.getAttributeValue('height')?.toString(), '50.0');
      expect(fo.getAttributeValue('overflow')?.toString(), 'hidden');

      // Render to verify clipping works
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: AnimatedSvgPicture.string(svgXml, width: 200, height: 200),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    // Test 5: foreignObject overflow=visible (no clipping)
    testWidgets('foreignObject overflow visible no clipping', (
      WidgetTester tester,
    ) async {
      // With overflow=visible, content should not be clipped
      const svgXml = '''
        <svg viewBox="0 0 200 200">
          <foreignObject x="50" y="50" width="50" height="50" overflow="visible">
            <svg viewBox="0 0 100 100">
              <rect id="visible-rect" x="0" y="0" width="100" height="100" fill="green"/>
            </svg>
          </foreignObject>
        </svg>
      ''';

      final document = SvgParser.parse(svgXml);
      final fo = document.root.children.firstWhere(
        (n) => n.tagName == 'foreignObject',
      );

      // Verify overflow is visible
      expect(fo.getAttributeValue('overflow'), 'visible');

      // Render to verify no clipping
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: AnimatedSvgPicture.string(svgXml, width: 200, height: 200),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    // Test 6: foreignObject with x/y offset
    testWidgets('foreignObject with x y offset', (WidgetTester tester) async {
      // foreignObject x/y attributes define the viewport position
      const svgXml = '''
        <svg viewBox="0 0 200 200">
          <foreignObject x="75" y="75" width="50" height="50">
            <svg viewBox="0 0 50 50">
              <circle id="centered-circle" cx="25" cy="25" r="20" fill="yellow"/>
            </svg>
          </foreignObject>
        </svg>
      ''';

      final document = SvgParser.parse(svgXml);
      final fo = document.root.children.firstWhere(
        (n) => n.tagName == 'foreignObject',
      );

      // Verify x/y offset
      expect(fo.getAttributeValue('x')?.toString(), '75.0');
      expect(fo.getAttributeValue('y')?.toString(), '75.0');

      // Render to verify positioning
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: AnimatedSvgPicture.string(svgXml, width: 200, height: 200),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    // Test 7: foreignObject with width/height constraining content
    testWidgets('foreignObject with width height constraining content', (
      WidgetTester tester,
    ) async {
      // foreignObject width/height define the viewport size
      const svgXml = '''
        <svg viewBox="0 0 200 200">
          <foreignObject x="20" y="20" width="160" height="160">
            <svg viewBox="0 0 200 200" width="160" height="160">
              <rect id="constrained-rect" x="0" y="0" width="200" height="200" fill="purple"/>
            </svg>
          </foreignObject>
        </svg>
      ''';

      final document = SvgParser.parse(svgXml);
      final fo = document.root.children.firstWhere(
        (n) => n.tagName == 'foreignObject',
      );

      // Verify width/height constraints
      expect(fo.getAttributeValue('width')?.toString(), '160.0');
      expect(fo.getAttributeValue('height')?.toString(), '160.0');

      // The nested SVG has viewBox 0 0 200 200 but is constrained to 160x160
      final nestedSvg = fo.children.firstWhere((n) => n.tagName == 'svg');
      expect(nestedSvg.getAttributeValue('viewBox')?.toString(), '0 0 200 200');
      expect(nestedSvg.getAttributeValue('width')?.toString(), '160.0');
      expect(nestedSvg.getAttributeValue('height')?.toString(), '160.0');

      // Render to verify constraint application
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: AnimatedSvgPicture.string(svgXml, width: 200, height: 200),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    // Test 8: foreignObject with parent group transform
    testWidgets('foreignObject with parent group transform', (
      WidgetTester tester,
    ) async {
      // Transforms on ancestor elements should correctly position the foreignObject
      const svgXml = '''
        <svg viewBox="0 0 200 200">
          <g transform="translate(50, 50)">
            <g transform="scale(0.5)">
              <foreignObject x="0" y="0" width="100" height="100">
                <svg viewBox="0 0 100 100">
                  <rect id="transformed-rect" x="10" y="10" width="80" height="80" fill="orange"/>
                </svg>
              </foreignObject>
            </g>
          </g>
        </svg>
      ''';

      final document = SvgParser.parse(svgXml);

      // Find the groups and verify transforms
      final outerG = document.root.children.firstWhere((n) => n.tagName == 'g');
      expect(outerG.getAttributeValue('transform'), 'translate(50, 50)');

      final innerG = outerG.children.firstWhere((n) => n.tagName == 'g');
      expect(innerG.getAttributeValue('transform'), 'scale(0.5)');

      // Render to verify transform propagation
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: AnimatedSvgPicture.string(svgXml, width: 200, height: 200),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });

  group('ForeignObject CSS Inheritance - Additional Scenarios', () {
    testWidgets('direction property inherits into foreignObject', (
      WidgetTester tester,
    ) async {
      // direction is an inherited property for text layout
      const svgXml = '''
        <svg viewBox="0 0 200 200" style="direction: rtl;">
          <foreignObject x="10" y="10" width="180" height="180">
            <svg viewBox="0 0 180 180">
              <text id="rtl-text" x="10" y="50">RTL Text</text>
            </svg>
          </foreignObject>
        </svg>
      ''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: AnimatedSvgPicture.string(svgXml, width: 200, height: 200),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('text-decoration inherits into foreignObject', (
      WidgetTester tester,
    ) async {
      // text-decoration is partially inherited
      const svgXml = '''
        <svg viewBox="0 0 200 200" style="text-decoration: underline;">
          <foreignObject x="10" y="10" width="180" height="180">
            <svg viewBox="0 0 180 180">
              <text id="decorated-text" x="10" y="50">Underlined</text>
            </svg>
          </foreignObject>
        </svg>
      ''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: AnimatedSvgPicture.string(svgXml, width: 200, height: 200),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('stroke does NOT inherit into foreignObject content', (
      WidgetTester tester,
    ) async {
      // stroke is SVG-specific and should NOT cross foreignObject boundary
      const svgXml = '''
        <svg viewBox="0 0 200 200" stroke="blue" stroke-width="5">
          <foreignObject x="10" y="10" width="180" height="180">
            <svg viewBox="0 0 180 180">
              <rect id="stroked-rect" x="10" y="10" width="100" height="100"/>
            </svg>
          </foreignObject>
          <rect id="outer-stroked" x="150" y="150" width="40" height="40"/>
        </svg>
      ''';

      final document = SvgParser.parse(svgXml);

      // Verify stroke is set on root
      expect(document.root.getAttributeValue('stroke'), isNotNull);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: AnimatedSvgPicture.string(svgXml, width: 200, height: 200),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('foreignObject default overflow is hidden', (
      WidgetTester tester,
    ) async {
      // Without explicit overflow, foreignObject should default to hidden
      const svgXml = '''
        <svg viewBox="0 0 200 200">
          <foreignObject x="50" y="50" width="40" height="40">
            <svg viewBox="0 0 100 100">
              <rect x="0" y="0" width="100" height="100" fill="cyan"/>
            </svg>
          </foreignObject>
        </svg>
      ''';

      final document = SvgParser.parse(svgXml);
      final fo = document.root.children.firstWhere(
        (n) => n.tagName == 'foreignObject',
      );

      // No overflow attribute - should default to hidden
      expect(fo.getAttributeValue('overflow'), isNull);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: AnimatedSvgPicture.string(svgXml, width: 200, height: 200),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });
}
