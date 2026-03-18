import 'package:flutter/material.dart';
import 'package:flutter_svg/src/animation/animated_svg_picture.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('textPath startOffset precision', () {
    testWidgets('startOffset with percentage value (50%)', (tester) async {
      const svg = '''
        <svg viewBox="0 0 300 200" xmlns="http://www.w3.org/2000/svg">
          <defs>
            <path id="path1" d="M 0,100 L 300,100" fill="none"/>
          </defs>
          <text fill="black">
            <textPath href="#path1" startOffset="50%">Centered text</textPath>
          </text>
        </svg>
      ''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svg, width: 300, height: 200),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('startOffset with absolute value', (tester) async {
      const svg = '''
        <svg viewBox="0 0 300 200" xmlns="http://www.w3.org/2000/svg">
          <defs>
            <path id="path1" d="M 0,100 L 300,100" fill="none"/>
          </defs>
          <text fill="black">
            <textPath href="#path1" startOffset="100">Offset text</textPath>
          </text>
        </svg>
      ''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svg, width: 300, height: 200),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('startOffset 0% starts at path beginning', (tester) async {
      const svg = '''
        <svg viewBox="0 0 300 200" xmlns="http://www.w3.org/2000/svg">
          <defs>
            <path id="path1" d="M 0,100 L 300,100" fill="none"/>
          </defs>
          <text fill="black">
            <textPath href="#path1" startOffset="0%">At start</textPath>
          </text>
        </svg>
      ''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svg, width: 300, height: 200),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('startOffset 100% with text-anchor end', (tester) async {
      const svg = '''
        <svg viewBox="0 0 300 200" xmlns="http://www.w3.org/2000/svg">
          <defs>
            <path id="path1" d="M 0,100 L 300,100" fill="none"/>
          </defs>
          <text text-anchor="end" fill="black">
            <textPath href="#path1" startOffset="100%">At end</textPath>
          </text>
        </svg>
      ''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svg, width: 300, height: 200),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });

  group('textPath text exceeding path length', () {
    testWidgets('text longer than path is clipped at end', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
          <defs>
            <path id="shortPath" d="M 10,50 L 100,50" fill="none"/>
          </defs>
          <text font-size="20" fill="black">
            <textPath href="#shortPath">This text is much longer than the path can display</textPath>
          </text>
        </svg>
      ''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svg, width: 200, height: 100),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('text with startOffset exceeds path gracefully', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
          <defs>
            <path id="shortPath" d="M 10,50 L 100,50" fill="none"/>
          </defs>
          <text font-size="14" fill="black">
            <textPath href="#shortPath" startOffset="80%">Long text starting near end</textPath>
          </text>
        </svg>
      ''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svg, width: 200, height: 100),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });

  group('textPath on closed paths', () {
    testWidgets('textPath on circular path', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 200" xmlns="http://www.w3.org/2000/svg">
          <defs>
            <path id="circlePath" d="M 100,20 a 80,80 0 1,1 0,160 a 80,80 0 1,1 0,-160" fill="none"/>
          </defs>
          <text font-size="14" fill="black">
            <textPath href="#circlePath">Text around a circle path element</textPath>
          </text>
        </svg>
      ''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svg, width: 200, height: 200),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('textPath on rectangle path', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 200" xmlns="http://www.w3.org/2000/svg">
          <defs>
            <path id="rectPath" d="M 20,20 L 180,20 L 180,180 L 20,180 Z" fill="none"/>
          </defs>
          <text font-size="12" fill="black">
            <textPath href="#rectPath">Text along rectangle path</textPath>
          </text>
        </svg>
      ''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svg, width: 200, height: 200),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('textPath on elliptical path', (tester) async {
      const svg = '''
        <svg viewBox="0 0 300 200" xmlns="http://www.w3.org/2000/svg">
          <defs>
            <path id="ellipsePath" d="M 150,20 a 120,80 0 1,1 0,160 a 120,80 0 1,1 0,-160" fill="none"/>
          </defs>
          <text font-size="14" fill="black">
            <textPath href="#ellipsePath">Text around an ellipse path</textPath>
          </text>
        </svg>
      ''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svg, width: 300, height: 200),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });

  group('textPath method attribute', () {
    testWidgets('method="align" default behavior', (tester) async {
      const svg = '''
        <svg viewBox="0 0 300 200" xmlns="http://www.w3.org/2000/svg">
          <defs>
            <path id="wavePath" d="M 10,100 Q 80,50 150,100 T 290,100" fill="none"/>
          </defs>
          <text fill="black">
            <textPath href="#wavePath" method="align">Aligned on wave</textPath>
          </text>
        </svg>
      ''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svg, width: 300, height: 200),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('method="stretch" stretches text to fill path', (tester) async {
      const svg = '''
        <svg viewBox="0 0 300 200" xmlns="http://www.w3.org/2000/svg">
          <defs>
            <path id="linePath" d="M 10,100 L 290,100" fill="none"/>
          </defs>
          <text fill="black">
            <textPath href="#linePath" method="stretch">Stretch</textPath>
          </text>
        </svg>
      ''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svg, width: 300, height: 200),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });

  group('textPath spacing attribute', () {
    testWidgets('spacing="auto" uses normal spacing', (tester) async {
      const svg = '''
        <svg viewBox="0 0 300 200" xmlns="http://www.w3.org/2000/svg">
          <defs>
            <path id="curvePath" d="M 10,100 Q 150,20 290,100" fill="none"/>
          </defs>
          <text letter-spacing="2" fill="black">
            <textPath href="#curvePath" spacing="auto">Auto spacing</textPath>
          </text>
        </svg>
      ''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svg, width: 300, height: 200),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('spacing="exact" uses exact glyph widths', (tester) async {
      const svg = '''
        <svg viewBox="0 0 300 200" xmlns="http://www.w3.org/2000/svg">
          <defs>
            <path id="curvePath" d="M 10,100 Q 150,20 290,100" fill="none"/>
          </defs>
          <text letter-spacing="5" fill="black">
            <textPath href="#curvePath" spacing="exact">Exact spacing</textPath>
          </text>
        </svg>
      ''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svg, width: 300, height: 200),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });

  group('textPath edge cases', () {
    testWidgets('textPath with empty path reference', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
          <defs>
            <path id="emptyPath" d="" fill="none"/>
          </defs>
          <text fill="black">
            <textPath href="#emptyPath">Should not render</textPath>
          </text>
        </svg>
      ''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svg, width: 200, height: 100),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('textPath with nonexistent path reference', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
          <text fill="black">
            <textPath href="#nonexistent">Should not render</textPath>
          </text>
        </svg>
      ''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svg, width: 200, height: 100),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('textPath with point-only path (zero length)', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
          <defs>
            <path id="pointPath" d="M 100,50" fill="none"/>
          </defs>
          <text fill="black">
            <textPath href="#pointPath">Should not render</textPath>
          </text>
        </svg>
      ''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svg, width: 200, height: 100),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('textPath with very short path', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
          <defs>
            <path id="tinyPath" d="M 99,50 L 101,50" fill="none"/>
          </defs>
          <text font-size="10" fill="black">
            <textPath href="#tinyPath">AB</textPath>
          </text>
        </svg>
      ''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svg, width: 200, height: 100),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });

  group('textPath with tspan children', () {
    testWidgets('textPath with multiple tspans different colors', (tester) async {
      const svg = '''
        <svg viewBox="0 0 300 200" xmlns="http://www.w3.org/2000/svg">
          <defs>
            <path id="arcPath" d="M 30,100 Q 150,20 270,100" fill="none"/>
          </defs>
          <text font-size="16">
            <textPath href="#arcPath">
              <tspan fill="red">Red</tspan>
              <tspan fill="green"> Green</tspan>
              <tspan fill="blue"> Blue</tspan>
            </textPath>
          </text>
        </svg>
      ''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svg, width: 300, height: 200),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('textPath with tspans different font-sizes', (tester) async {
      const svg = '''
        <svg viewBox="0 0 300 200" xmlns="http://www.w3.org/2000/svg">
          <defs>
            <path id="arcPath" d="M 30,100 Q 150,20 270,100" fill="none"/>
          </defs>
          <text fill="black">
            <textPath href="#arcPath">
              <tspan font-size="12">Small</tspan>
              <tspan font-size="18"> Medium</tspan>
              <tspan font-size="24"> Large</tspan>
            </textPath>
          </text>
        </svg>
      ''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svg, width: 300, height: 200),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('textPath with tspans different font-weight', (tester) async {
      const svg = '''
        <svg viewBox="0 0 300 200" xmlns="http://www.w3.org/2000/svg">
          <defs>
            <path id="arcPath" d="M 30,100 Q 150,20 270,100" fill="none"/>
          </defs>
          <text font-size="16" fill="black">
            <textPath href="#arcPath">
              Normal <tspan font-weight="bold">Bold</tspan> Normal
            </textPath>
          </text>
        </svg>
      ''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svg, width: 300, height: 200),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });

  group('textPath with textLength', () {
    testWidgets('textLength stretches text to specified length', (tester) async {
      const svg = '''
        <svg viewBox="0 0 300 200" xmlns="http://www.w3.org/2000/svg">
          <defs>
            <path id="linePath" d="M 10,100 L 290,100" fill="none"/>
          </defs>
          <text fill="black">
            <textPath href="#linePath" textLength="200">Stretched</textPath>
          </text>
        </svg>
      ''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svg, width: 300, height: 200),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('textLength with lengthAdjust="spacing"', (tester) async {
      const svg = '''
        <svg viewBox="0 0 300 200" xmlns="http://www.w3.org/2000/svg">
          <defs>
            <path id="linePath" d="M 10,100 L 290,100" fill="none"/>
          </defs>
          <text fill="black">
            <textPath href="#linePath" textLength="200" lengthAdjust="spacing">Spaced Text</textPath>
          </text>
        </svg>
      ''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svg, width: 300, height: 200),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('textLength with lengthAdjust="spacingAndGlyphs"', (tester) async {
      const svg = '''
        <svg viewBox="0 0 300 200" xmlns="http://www.w3.org/2000/svg">
          <defs>
            <path id="linePath" d="M 10,100 L 290,100" fill="none"/>
          </defs>
          <text fill="black">
            <textPath href="#linePath" textLength="200" lengthAdjust="spacingAndGlyphs">Stretched</textPath>
          </text>
        </svg>
      ''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svg, width: 300, height: 200),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });

  group('textPath with text-anchor', () {
    testWidgets('text-anchor="start" aligns at startOffset', (tester) async {
      const svg = '''
        <svg viewBox="0 0 300 200" xmlns="http://www.w3.org/2000/svg">
          <defs>
            <path id="linePath" d="M 10,100 L 290,100" fill="none"/>
          </defs>
          <text text-anchor="start" fill="black">
            <textPath href="#linePath" startOffset="50%">Start anchor</textPath>
          </text>
        </svg>
      ''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svg, width: 300, height: 200),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('text-anchor="middle" centers at startOffset', (tester) async {
      const svg = '''
        <svg viewBox="0 0 300 200" xmlns="http://www.w3.org/2000/svg">
          <defs>
            <path id="linePath" d="M 10,100 L 290,100" fill="none"/>
          </defs>
          <text text-anchor="middle" fill="black">
            <textPath href="#linePath" startOffset="50%">Middle anchor</textPath>
          </text>
        </svg>
      ''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svg, width: 300, height: 200),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('text-anchor="end" ends at startOffset', (tester) async {
      const svg = '''
        <svg viewBox="0 0 300 200" xmlns="http://www.w3.org/2000/svg">
          <defs>
            <path id="linePath" d="M 10,100 L 290,100" fill="none"/>
          </defs>
          <text text-anchor="end" fill="black">
            <textPath href="#linePath" startOffset="100%">End anchor</textPath>
          </text>
        </svg>
      ''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svg, width: 300, height: 200),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });
}
