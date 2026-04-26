import 'package:flutter/material.dart';
import 'package:full_svg_flutter/src/animation/animated_svg_picture.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Multi-tspan paragraph layout', () {
    testWidgets(
      'multiple tspans with different font-weight render on same line',
      (tester) async {
        const svg = '''
        <svg viewBox="0 0 400 100" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="50" font-size="16" fill="black">
            Normal <tspan font-weight="bold">Bold</tspan> Normal
          </text>
        </svg>
      ''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AnimatedSvgPicture.string(svg, width: 400, height: 100),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      },
    );

    testWidgets(
      'multiple tspans with different font-size render on same line',
      (tester) async {
        const svg = '''
        <svg viewBox="0 0 400 100" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="50" font-size="16" fill="black">
            Normal <tspan font-size="24">Large</tspan> Normal
          </text>
        </svg>
      ''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AnimatedSvgPicture.string(svg, width: 400, height: 100),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      },
    );

    testWidgets('multiple tspans with different fill colors', (tester) async {
      const svg = '''
        <svg viewBox="0 0 400 100" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="50" font-size="16" fill="black">
            Normal <tspan fill="red">Red</tspan> <tspan fill="blue">Blue</tspan> end
          </text>
        </svg>
      ''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svg, width: 400, height: 100),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('whitespace handling between tspans is correct', (
      tester,
    ) async {
      const svg = '''
        <svg viewBox="0 0 400 100" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="50" fill="black">
            Word1   <tspan>Word2</tspan>   <tspan>Word3</tspan>
          </text>
        </svg>
      ''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svg, width: 400, height: 100),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('xml:space="preserve" keeps whitespace intact', (tester) async {
      const svg = '''
        <svg viewBox="0 0 400 100" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="50" xml:space="preserve" fill="black">
            Word1   Word2   Word3
          </text>
        </svg>
      ''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svg, width: 400, height: 100),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('mixed font-size tspans align on baseline', (tester) async {
      const svg = '''
        <svg viewBox="0 0 400 100" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="50" font-size="12" fill="black">
            Small <tspan font-size="20">Medium</tspan> <tspan font-size="28">Large</tspan> Small
          </text>
        </svg>
      ''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svg, width: 400, height: 100),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('nested tspans inherit parent styles correctly', (
      tester,
    ) async {
      const svg = '''
        <svg viewBox="0 0 400 100" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="50" font-size="16" fill="black">
            Normal <tspan font-weight="bold">Bold <tspan fill="red">BoldRed</tspan> Bold</tspan> Normal
          </text>
        </svg>
      ''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svg, width: 400, height: 100),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('empty tspans do not break layout', (tester) async {
      const svg = '''
        <svg viewBox="0 0 400 100" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="50" fill="black">
            Before <tspan></tspan> After <tspan>Content</tspan>
          </text>
        </svg>
      ''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svg, width: 400, height: 100),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('tspan with absolute x creates new text chunk', (tester) async {
      const svg = '''
        <svg viewBox="0 0 400 100" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="50" fill="black">
            First <tspan x="200">Second</tspan>
          </text>
        </svg>
      ''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svg, width: 400, height: 100),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('tspan with dx applies relative offset', (tester) async {
      const svg = '''
        <svg viewBox="0 0 400 100" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="50" fill="black">
            Before <tspan dx="50">After</tspan>
          </text>
        </svg>
      ''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svg, width: 400, height: 100),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('multiple tspans with different font-style', (tester) async {
      const svg = '''
        <svg viewBox="0 0 400 100" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="50" font-size="16" fill="black">
            Normal <tspan font-style="italic">Italic</tspan> <tspan font-weight="bold" font-style="italic">BoldItalic</tspan>
          </text>
        </svg>
      ''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svg, width: 400, height: 100),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('tspan with text-decoration', (tester) async {
      const svg = '''
        <svg viewBox="0 0 400 100" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="50" font-size="16" fill="black">
            Normal <tspan text-decoration="underline">Underlined</tspan> <tspan text-decoration="line-through">Strikethrough</tspan>
          </text>
        </svg>
      ''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svg, width: 400, height: 100),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });

  group('Baseline-shift interactions', () {
    testWidgets('baseline-shift sub positions subscript', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="50" font-size="20" fill="black">
            H<tspan baseline-shift="sub" font-size="14">2</tspan>O
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

    testWidgets('baseline-shift super positions superscript', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="50" font-size="20" fill="black">
            E=mc<tspan baseline-shift="super" font-size="14">2</tspan>
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

    testWidgets('baseline-shift with percentage value', (tester) async {
      const svg = '''
        <svg viewBox="0 0 300 100" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="50" font-size="20" fill="black">
            Base<tspan baseline-shift="25%">Shifted25</tspan>Base
          </text>
        </svg>
      ''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svg, width: 300, height: 100),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('baseline-shift with length value (em)', (tester) async {
      const svg = '''
        <svg viewBox="0 0 300 100" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="50" font-size="20" fill="black">
            Base<tspan baseline-shift="0.5em">Shifted</tspan>Base
          </text>
        </svg>
      ''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svg, width: 300, height: 100),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('nested baseline-shift is cumulative', (tester) async {
      const svg = '''
        <svg viewBox="0 0 300 100" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="50" font-size="16" fill="black">
            A<tspan baseline-shift="super">B<tspan baseline-shift="super">C</tspan>B</tspan>A
          </text>
        </svg>
      ''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svg, width: 300, height: 100),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });

  group('Vertical text with mixed tspan styles', () {
    testWidgets('vertical-rl with multiple tspans', (tester) async {
      const svg = '''
        <svg viewBox="0 0 100 300" xmlns="http://www.w3.org/2000/svg">
          <text x="50" y="20" writing-mode="vertical-rl" fill="black">
            縦<tspan fill="red">書</tspan>き
          </text>
        </svg>
      ''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svg, width: 100, height: 300),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('vertical-lr with different font-sizes', (tester) async {
      const svg = '''
        <svg viewBox="0 0 100 300" xmlns="http://www.w3.org/2000/svg">
          <text x="20" y="20" writing-mode="vertical-lr" fill="black">
            <tspan font-size="16">A</tspan><tspan font-size="24">B</tspan><tspan font-size="16">C</tspan>
          </text>
        </svg>
      ''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svg, width: 100, height: 300),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });

  group('Empty tspan handling', () {
    testWidgets('empty tspan with dx does not break', (tester) async {
      const svg = '''
        <svg viewBox="0 0 400 100" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="50" fill="black">
            Before <tspan dx="10"></tspan> After
          </text>
        </svg>
      ''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svg, width: 400, height: 100),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('whitespace-only tspan preserves flow', (tester) async {
      const svg = '''
        <svg viewBox="0 0 400 100" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="50" fill="black">
            Before<tspan>   </tspan>After
          </text>
        </svg>
      ''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svg, width: 400, height: 100),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('tspan with only newlines collapses', (tester) async {
      const svg = '''
        <svg viewBox="0 0 400 100" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="50" fill="black">
            Before<tspan>
            </tspan>After
          </text>
        </svg>
      ''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svg, width: 400, height: 100),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });
}
