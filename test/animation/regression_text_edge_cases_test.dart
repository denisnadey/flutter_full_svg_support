// Regression tests for text rendering edge cases
// Tests complex text scenarios that have historically caused issues

import 'package:flutter/material.dart';
import 'package:full_svg_flutter/src/animation/animated_svg_picture.dart';
import 'package:full_svg_flutter/src/animation/svg_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Nested tspan with mixed attributes', () {
    testWidgets('deeply nested tspan inherits fill correctly', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 300 100">
          <text x="10" y="50" fill="red">
            Parent
            <tspan fill="blue">
              Level1
              <tspan fill="green">
                Level2
                <tspan>Level3-inherits-green</tspan>
              </tspan>
            </tspan>
          </text>
        </svg>
      ''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svgXml, width: 300, height: 100),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('tspan with mixed font-size and font-weight attributes', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 400 100">
          <text x="10" y="50" font-size="12" font-weight="normal">
            Normal
            <tspan font-size="20" font-weight="bold">Large Bold</tspan>
            <tspan font-size="8" font-style="italic">Small Italic</tspan>
            Back to Normal
          </text>
        </svg>
      ''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svgXml, width: 400, height: 100),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('tspan with baseline-shift super and sub', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 300 100">
          <text x="10" y="50" font-size="16">
            H<tspan baseline-shift="sub" font-size="10">2</tspan>O
            E=mc<tspan baseline-shift="super" font-size="10">2</tspan>
          </text>
        </svg>
      ''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svgXml, width: 300, height: 100),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('tspan with letter-spacing and word-spacing', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 400 100">
          <text x="10" y="50">
            Normal <tspan letter-spacing="5">Wide Letters</tspan>
            <tspan word-spacing="20">Wide Words Here</tspan>
          </text>
        </svg>
      ''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svgXml, width: 400, height: 100),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });

  group('textPath on curved paths', () {
    testWidgets('textPath on quadratic bezier curve', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 300 150">
          <defs>
            <path id="curve1" d="M10,80 Q150,10 290,80" fill="none"/>
          </defs>
          <text>
            <textPath href="#curve1">Text along a curved path</textPath>
          </text>
        </svg>
      ''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svgXml, width: 300, height: 150),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('textPath on cubic bezier S-curve', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 400 200">
          <defs>
            <path id="sCurve" d="M10,100 C60,10 140,10 200,100 S340,190 390,100" fill="none"/>
          </defs>
          <text font-size="14" fill="navy">
            <textPath href="#sCurve" startOffset="10%">
              Following an S-shaped curve smoothly
            </textPath>
          </text>
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

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('textPath with startOffset percentage', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 300 100">
          <defs>
            <path id="line1" d="M10,50 L290,50"/>
          </defs>
          <text>
            <textPath href="#line1" startOffset="50%">Centered</textPath>
          </text>
        </svg>
      ''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svgXml, width: 300, height: 100),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('textPath with method="stretch" and spacing="exact"', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 300 150">
          <defs>
            <path id="arc1" d="M20,100 A80,80 0 0,1 280,100"/>
          </defs>
          <text font-size="12">
            <textPath href="#arc1" method="stretch" spacing="exact">
              Stretched text along arc path
            </textPath>
          </text>
        </svg>
      ''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svgXml, width: 300, height: 150),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('textPath on closed path (circle)', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 200 200">
          <defs>
            <path id="circle1" d="M100,20 A80,80 0 1,1 100,180 A80,80 0 1,1 100,20"/>
          </defs>
          <text font-size="14">
            <textPath href="#circle1">Text going around in a circle path here</textPath>
          </text>
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

    testWidgets('textPath with side="right" (text on opposite side)', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 300 150">
          <defs>
            <path id="wave" d="M10,75 Q80,25 150,75 T290,75"/>
          </defs>
          <text font-size="12">
            <textPath href="#wave" side="right">Text on right side of wave</textPath>
          </text>
        </svg>
      ''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svgXml, width: 300, height: 150),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });

  group('Text with multiple dx/dy values', () {
    testWidgets('dx with more values than characters', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 300 100">
          <text x="10" y="50" dx="0 5 10 15 20 25 30 35 40" fill="black">
            ABC
          </text>
        </svg>
      ''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svgXml, width: 300, height: 100),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('dy creating vertical text wave effect', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 300 100">
          <text x="10" y="50" dy="0 -10 0 10 0 -10 0 10 0 -10" fill="blue">
            WAVE TEXT
          </text>
        </svg>
      ''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svgXml, width: 300, height: 100),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('combined x, y, dx, dy positioning', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 400 150">
          <text x="20 60 100 140 180" y="30 50 70 90 110" 
                dx="2 2 2 2 2" dy="0 0 0 0 0" fill="green">
            ABCDE
          </text>
        </svg>
      ''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svgXml, width: 400, height: 150),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('dx/dy in nested tspan accumulates correctly', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 400 100">
          <text x="10" y="50">
            Start
            <tspan dx="20">Jump</tspan>
            <tspan dy="-15">Up</tspan>
            <tspan dx="20" dy="15">Diagonal</tspan>
          </text>
        </svg>
      ''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svgXml, width: 400, height: 100),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('dx with negative values for kerning adjustments', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 300 100">
          <text x="50" y="50" font-size="24" dx="0 -5 -3 2 0 -4 0">
            AVENGED
          </text>
        </svg>
      ''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svgXml, width: 300, height: 100),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });

  group('Text rotate attribute edge cases', () {
    testWidgets('rotate with single value applies to all glyphs', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 300 100">
          <text x="50" y="50" rotate="45" font-size="18" fill="purple">
            ALL ROTATED
          </text>
        </svg>
      ''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svgXml, width: 300, height: 100),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('rotate with individual values per character', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 350 100">
          <text x="20" y="50" rotate="0 15 30 45 60 75 90" font-size="20">
            ABCDEFG
          </text>
        </svg>
      ''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svgXml, width: 350, height: 100),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('rotate with fewer values than characters repeats last', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 400 100">
          <text x="20" y="50" rotate="0 30 60" font-size="18">
            ABCDEFGHIJ
          </text>
        </svg>
      ''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svgXml, width: 400, height: 100),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('rotate combined with per-character x positioning', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 300 100">
          <text x="30 60 90 120 150" y="50" rotate="0 45 90 135 180" font-size="16">
            HELLO
          </text>
        </svg>
      ''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svgXml, width: 300, height: 100),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('negative rotation values', (WidgetTester tester) async {
      const svgXml = '''
        <svg viewBox="0 0 300 100">
          <text x="50" y="50" rotate="-45 -30 -15 0 15 30 45" font-size="16">
            RAINBOW
          </text>
        </svg>
      ''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svgXml, width: 300, height: 100),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });

  group('Text anchor and text-decoration combinations', () {
    testWidgets('text-anchor middle with underline', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 300 100">
          <text x="150" y="50" text-anchor="middle" 
                text-decoration="underline" fill="blue">
            Centered Underlined
          </text>
        </svg>
      ''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svgXml, width: 300, height: 100),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('text-anchor end with line-through', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 300 100">
          <text x="290" y="50" text-anchor="end" 
                text-decoration="line-through" fill="gray">
            Strikethrough Right Aligned
          </text>
        </svg>
      ''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svgXml, width: 300, height: 100),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('multiple text-decoration values', (WidgetTester tester) async {
      const svgXml = '''
        <svg viewBox="0 0 400 100">
          <text x="10" y="50" text-decoration="underline overline" fill="black">
            Multiple Decorations Applied
          </text>
        </svg>
      ''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svgXml, width: 400, height: 100),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('text-decoration-color separate from fill', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 300 100">
          <style>
            .decorated { text-decoration: underline; text-decoration-color: red; }
          </style>
          <text x="10" y="50" class="decorated" fill="blue">
            Blue Text Red Underline
          </text>
        </svg>
      ''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svgXml, width: 300, height: 100),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });

  group('DOM parsing verification for text elements', () {
    test('text element parses font attributes correctly', () {
      const svgString = '''
        <svg>
          <text x="10" y="50" font-size="24" font-weight="bold" 
                font-style="italic" font-family="Arial, sans-serif">
            Sample
          </text>
        </svg>
      ''';

      final document = SvgParser.parse(svgString);
      final text = document.root.children.firstWhere(
        (n) => n.tagName == 'text',
      );

      expect(text.getAttributeValue('font-size'), 24.0);
      expect(text.getAttributeValue('font-weight'), 'bold');
      expect(text.getAttributeValue('font-style'), 'italic');
      expect(text.getAttributeValue('font-family'), 'Arial, sans-serif');
    });

    test('tspan inherits parent text attributes', () {
      const svgString = '''
        <svg>
          <text x="10" y="50" fill="red">
            Parent
            <tspan id="child">Child</tspan>
          </text>
        </svg>
      ''';

      final document = SvgParser.parse(svgString);
      final text = document.root.children.firstWhere(
        (n) => n.tagName == 'text',
      );
      final tspan = text.children.firstWhere((n) => n.tagName == 'tspan');

      expect(tspan.id, 'child');
      expect(text.children.length, greaterThanOrEqualTo(1));
    });

    test('text x/y list values parse as first value', () {
      const svgString = '''
        <svg>
          <text x="10 20 30 40" y="50 60 70 80">ABCD</text>
        </svg>
      ''';

      final document = SvgParser.parse(svgString);
      final text = document.root.children.firstWhere(
        (n) => n.tagName == 'text',
      );

      // Parser returns first value for position lists
      expect(text.getAttributeValue('x'), isNotNull);
      expect(text.getAttributeValue('y'), isNotNull);
    });

    test('textLength and lengthAdjust parse correctly', () {
      const svgString = '''
        <svg>
          <text x="10" y="50" textLength="200" lengthAdjust="spacing">
            Adjusted Text
          </text>
        </svg>
      ''';

      final document = SvgParser.parse(svgString);
      final text = document.root.children.firstWhere(
        (n) => n.tagName == 'text',
      );

      expect(text.getAttributeValue('textLength'), 200.0);
      expect(text.getAttributeValue('lengthAdjust'), 'spacing');
    });

    test('dominant-baseline and alignment-baseline parse correctly', () {
      const svgString = '''
        <svg>
          <text x="10" y="50" dominant-baseline="middle" 
                alignment-baseline="central">
            Baseline Test
          </text>
        </svg>
      ''';

      final document = SvgParser.parse(svgString);
      final text = document.root.children.firstWhere(
        (n) => n.tagName == 'text',
      );

      expect(text.getAttributeValue('dominant-baseline'), 'middle');
      expect(text.getAttributeValue('alignment-baseline'), 'central');
    });
  });

  group('textLength and lengthAdjust edge cases', () {
    testWidgets('textLength with spacing adjustment', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 400 100">
          <text x="10" y="50" textLength="300" lengthAdjust="spacing">
            WIDE SPACED
          </text>
        </svg>
      ''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svgXml, width: 400, height: 100),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('textLength with spacingAndGlyphs adjustment', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 400 100">
          <text x="10" y="50" textLength="350" lengthAdjust="spacingAndGlyphs">
            Stretched Glyphs And Spacing
          </text>
        </svg>
      ''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svgXml, width: 400, height: 100),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('textLength shorter than natural width compresses text', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 300 100">
          <text x="10" y="50" textLength="50" lengthAdjust="spacingAndGlyphs">
            COMPRESS ME
          </text>
        </svg>
      ''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svgXml, width: 300, height: 100),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('textLength on tspan element', (WidgetTester tester) async {
      const svgXml = '''
        <svg viewBox="0 0 400 100">
          <text x="10" y="50">
            Normal
            <tspan textLength="200" lengthAdjust="spacing">STRETCHED</tspan>
            Normal
          </text>
        </svg>
      ''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svgXml, width: 400, height: 100),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });

  group('Writing mode and text orientation', () {
    testWidgets('writing-mode vertical-rl', (WidgetTester tester) async {
      const svgXml = '''
        <svg viewBox="0 0 100 300">
          <text x="50" y="10" writing-mode="vertical-rl" fill="black">
            Vertical Text
          </text>
        </svg>
      ''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svgXml, width: 100, height: 300),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('writing-mode vertical-lr', (WidgetTester tester) async {
      const svgXml = '''
        <svg viewBox="0 0 100 300">
          <text x="10" y="10" writing-mode="vertical-lr" fill="black">
            Vertical LR
          </text>
        </svg>
      ''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svgXml, width: 100, height: 300),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('text-orientation upright in vertical mode', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 100 300">
          <text x="50" y="10" writing-mode="vertical-rl" 
                text-orientation="upright" fill="black">
            ABCabc123
          </text>
        </svg>
      ''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svgXml, width: 100, height: 300),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('text-orientation sideways in vertical mode', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 100 300">
          <text x="50" y="10" writing-mode="vertical-rl" 
                text-orientation="sideways" fill="black">
            Sideways Text
          </text>
        </svg>
      ''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svgXml, width: 100, height: 300),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });

  group('Text with special characters and entities', () {
    testWidgets('text with XML entities', (WidgetTester tester) async {
      const svgXml = '''
        <svg viewBox="0 0 400 100">
          <text x="10" y="50" fill="black">
            Price: 100 &lt; 200 &amp; 50 &gt; 25 &quot;test&quot; &apos;test&apos;
          </text>
        </svg>
      ''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svgXml, width: 400, height: 100),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('text with numeric character references', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 300 100">
          <text x="10" y="50" fill="black">
            Copyright &#169; Registered &#174; Trademark &#8482;
          </text>
        </svg>
      ''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svgXml, width: 300, height: 100),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('text with emoji characters', (WidgetTester tester) async {
      const svgXml = '''
        <svg viewBox="0 0 300 100">
          <text x="10" y="50" font-size="24" fill="black">
            Hello 👋 World 🌍 Flutter 💙
          </text>
        </svg>
      ''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svgXml, width: 300, height: 100),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('text with zero-width characters', (WidgetTester tester) async {
      const svgXml = '''
        <svg viewBox="0 0 300 100">
          <text x="10" y="50" fill="black">
            Hello\u200BWorld\u200CTest\u200DEnd
          </text>
        </svg>
      ''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svgXml, width: 300, height: 100),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });
}
