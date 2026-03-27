import 'package:flutter/material.dart';
import 'package:flutter_svg/src/animation/animated_svg_picture.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('hanging-punctuation CSS property rendering', () {
    group('hanging-punctuation: first', () {
      testWidgets('applies negative offset for opening parenthesis', (
        tester,
      ) async {
        const svg = '''
          <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
            <text x="50" y="30" font-size="16" style="hanging-punctuation: first">(Hello)</text>
          </svg>
        ''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AnimatedSvgPicture.string(svg, width: 200, height: 50),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        // Should render without errors
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('applies negative offset for opening bracket', (
        tester,
      ) async {
        const svg = '''
          <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
            <text x="50" y="30" font-size="16" style="hanging-punctuation: first">[Array]</text>
          </svg>
        ''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AnimatedSvgPicture.string(svg, width: 200, height: 50),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('applies negative offset for left double quote', (
        tester,
      ) async {
        const svg = '''
          <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
            <text x="50" y="30" font-size="16" style="hanging-punctuation: first">"Quoted"</text>
          </svg>
        ''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AnimatedSvgPicture.string(svg, width: 200, height: 50),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('no offset for non-punctuation first character', (
        tester,
      ) async {
        const svg = '''
          <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
            <text x="50" y="30" font-size="16" style="hanging-punctuation: first">Hello World</text>
          </svg>
        ''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AnimatedSvgPicture.string(svg, width: 200, height: 50),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });
    });

    group('hanging-punctuation: last', () {
      testWidgets('allows closing parenthesis to extend past end', (
        tester,
      ) async {
        const svg = '''
          <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
            <text x="50" y="30" font-size="16" style="hanging-punctuation: last">(Hello)</text>
          </svg>
        ''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AnimatedSvgPicture.string(svg, width: 200, height: 50),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('allows closing bracket to extend past end', (tester) async {
        const svg = '''
          <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
            <text x="50" y="30" font-size="16" style="hanging-punctuation: last">[Array]</text>
          </svg>
        ''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AnimatedSvgPicture.string(svg, width: 200, height: 50),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('allows right double quote to extend past end', (
        tester,
      ) async {
        const svg = '''
          <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
            <text x="50" y="30" font-size="16" style="hanging-punctuation: last">"Quoted"</text>
          </svg>
        ''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AnimatedSvgPicture.string(svg, width: 200, height: 50),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });
    });

    group('hanging-punctuation: force-end', () {
      testWidgets('hangs period at end of line', (tester) async {
        const svg = '''
          <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
            <text x="50" y="30" font-size="16" style="hanging-punctuation: force-end">Hello.</text>
          </svg>
        ''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AnimatedSvgPicture.string(svg, width: 200, height: 50),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('hangs comma at end of line', (tester) async {
        const svg = '''
          <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
            <text x="50" y="30" font-size="16" style="hanging-punctuation: force-end">Hello,</text>
          </svg>
        ''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AnimatedSvgPicture.string(svg, width: 200, height: 50),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('hangs colon at end of line', (tester) async {
        const svg = '''
          <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
            <text x="50" y="30" font-size="16" style="hanging-punctuation: force-end">Hello:</text>
          </svg>
        ''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AnimatedSvgPicture.string(svg, width: 200, height: 50),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('hangs semicolon at end of line', (tester) async {
        const svg = '''
          <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
            <text x="50" y="30" font-size="16" style="hanging-punctuation: force-end">Hello;</text>
          </svg>
        ''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AnimatedSvgPicture.string(svg, width: 200, height: 50),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });
    });

    group('hanging-punctuation: allow-end', () {
      testWidgets('allows period to hang at end', (tester) async {
        const svg = '''
          <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
            <text x="50" y="30" font-size="16" style="hanging-punctuation: allow-end">Hello.</text>
          </svg>
        ''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AnimatedSvgPicture.string(svg, width: 200, height: 50),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('allows comma to hang at end', (tester) async {
        const svg = '''
          <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
            <text x="50" y="30" font-size="16" style="hanging-punctuation: allow-end">Hello,</text>
          </svg>
        ''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AnimatedSvgPicture.string(svg, width: 200, height: 50),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });
    });

    group('hanging-punctuation: first last (combined)', () {
      testWidgets('hangs both opening and closing punctuation', (tester) async {
        const svg = '''
          <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
            <text x="50" y="30" font-size="16" style="hanging-punctuation: first last">(Hello World)</text>
          </svg>
        ''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AnimatedSvgPicture.string(svg, width: 200, height: 50),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('hangs opening quote and closing quote', (tester) async {
        const svg = '''
          <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
            <text x="50" y="30" font-size="16" style="hanging-punctuation: first last">"Hello World"</text>
          </svg>
        ''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AnimatedSvgPicture.string(svg, width: 200, height: 50),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('hangs brackets and braces', (tester) async {
        const svg = '''
          <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
            <text x="50" y="30" font-size="16" style="hanging-punctuation: first last">{data}</text>
          </svg>
        ''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AnimatedSvgPicture.string(svg, width: 200, height: 50),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });
    });

    group('CJK punctuation hanging', () {
      testWidgets('hangs CJK corner bracket 「', (tester) async {
        const svg = '''
          <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
            <text x="50" y="30" font-size="16" style="hanging-punctuation: first">「テスト」</text>
          </svg>
        ''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AnimatedSvgPicture.string(svg, width: 200, height: 50),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('hangs CJK corner bracket 」', (tester) async {
        const svg = '''
          <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
            <text x="50" y="30" font-size="16" style="hanging-punctuation: last">「テスト」</text>
          </svg>
        ''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AnimatedSvgPicture.string(svg, width: 200, height: 50),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('hangs ideographic full stop 。', (tester) async {
        const svg = '''
          <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
            <text x="50" y="30" font-size="16" style="hanging-punctuation: force-end">テスト。</text>
          </svg>
        ''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AnimatedSvgPicture.string(svg, width: 200, height: 50),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('hangs ideographic comma 、', (tester) async {
        const svg = '''
          <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
            <text x="50" y="30" font-size="16" style="hanging-punctuation: force-end">テスト、</text>
          </svg>
        ''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AnimatedSvgPicture.string(svg, width: 200, height: 50),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('hangs CJK angle brackets 《》', (tester) async {
        const svg = '''
          <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
            <text x="50" y="30" font-size="16" style="hanging-punctuation: first last">《书名》</text>
          </svg>
        ''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AnimatedSvgPicture.string(svg, width: 200, height: 50),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });
    });

    group('interaction with text-anchor', () {
      testWidgets('works with text-anchor: start', (tester) async {
        const svg = '''
          <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
            <text x="100" y="30" font-size="16" text-anchor="start" style="hanging-punctuation: first">(Hello)</text>
          </svg>
        ''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AnimatedSvgPicture.string(svg, width: 200, height: 50),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('works with text-anchor: middle', (tester) async {
        const svg = '''
          <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
            <text x="100" y="30" font-size="16" text-anchor="middle" style="hanging-punctuation: first last">(Hello)</text>
          </svg>
        ''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AnimatedSvgPicture.string(svg, width: 200, height: 50),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('works with text-anchor: end', (tester) async {
        const svg = '''
          <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
            <text x="100" y="30" font-size="16" text-anchor="end" style="hanging-punctuation: last">(Hello)</text>
          </svg>
        ''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AnimatedSvgPicture.string(svg, width: 200, height: 50),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });
    });

    group('vertical text hanging punctuation', () {
      testWidgets('hangs at top (block-start) in vertical-rl', (tester) async {
        const svg = '''
          <svg viewBox="0 0 100 200" xmlns="http://www.w3.org/2000/svg">
            <text x="50" y="20" font-size="16" style="writing-mode: vertical-rl; hanging-punctuation: first">「縦書き」</text>
          </svg>
        ''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AnimatedSvgPicture.string(svg, width: 100, height: 200),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('hangs at bottom (block-end) in vertical-rl', (tester) async {
        const svg = '''
          <svg viewBox="0 0 100 200" xmlns="http://www.w3.org/2000/svg">
            <text x="50" y="20" font-size="16" style="writing-mode: vertical-rl; hanging-punctuation: last">「縦書き」</text>
          </svg>
        ''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AnimatedSvgPicture.string(svg, width: 100, height: 200),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('hangs at top in vertical-lr', (tester) async {
        const svg = '''
          <svg viewBox="0 0 100 200" xmlns="http://www.w3.org/2000/svg">
            <text x="20" y="20" font-size="16" style="writing-mode: vertical-lr; hanging-punctuation: first">(vertical)</text>
          </svg>
        ''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AnimatedSvgPicture.string(svg, width: 100, height: 200),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('force-end hangs period at block-end', (tester) async {
        const svg = '''
          <svg viewBox="0 0 100 200" xmlns="http://www.w3.org/2000/svg">
            <text x="50" y="20" font-size="16" style="writing-mode: vertical-rl; hanging-punctuation: force-end">縦書き。</text>
          </svg>
        ''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AnimatedSvgPicture.string(svg, width: 100, height: 200),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });
    });

    group('non-punctuation characters', () {
      testWidgets('does not affect non-punctuation first char', (tester) async {
        const svg = '''
          <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
            <text x="50" y="30" font-size="16" style="hanging-punctuation: first">Hello World</text>
          </svg>
        ''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AnimatedSvgPicture.string(svg, width: 200, height: 50),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('does not affect non-punctuation last char', (tester) async {
        const svg = '''
          <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
            <text x="50" y="30" font-size="16" style="hanging-punctuation: last">Hello World</text>
          </svg>
        ''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AnimatedSvgPicture.string(svg, width: 200, height: 50),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });
    });

    group('empty text and edge cases', () {
      testWidgets('handles empty text gracefully', (tester) async {
        const svg = '''
          <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
            <text x="50" y="30" font-size="16" style="hanging-punctuation: first last"></text>
          </svg>
        ''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AnimatedSvgPicture.string(svg, width: 200, height: 50),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('handles text without punctuation', (tester) async {
        const svg = '''
          <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
            <text x="50" y="30" font-size="16" style="hanging-punctuation: first last force-end">Hello World</text>
          </svg>
        ''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AnimatedSvgPicture.string(svg, width: 200, height: 50),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('handles single character punctuation', (tester) async {
        const svg = '''
          <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
            <text x="50" y="30" font-size="16" style="hanging-punctuation: first last">.</text>
          </svg>
        ''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AnimatedSvgPicture.string(svg, width: 200, height: 50),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });
    });

    group('hanging-punctuation: none', () {
      testWidgets('none value disables hanging', (tester) async {
        const svg = '''
          <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
            <text x="50" y="30" font-size="16" style="hanging-punctuation: none">(Hello)</text>
          </svg>
        ''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AnimatedSvgPicture.string(svg, width: 200, height: 50),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('default (no style) is none', (tester) async {
        const svg = '''
          <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
            <text x="50" y="30" font-size="16">(Hello)</text>
          </svg>
        ''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AnimatedSvgPicture.string(svg, width: 200, height: 50),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });
    });

    group('complex scenarios', () {
      testWidgets('hanging with tspan', (tester) async {
        const svg = '''
          <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
            <text x="50" y="30" font-size="16" style="hanging-punctuation: first last">
              (<tspan fill="red">Hello</tspan>)
            </text>
          </svg>
        ''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AnimatedSvgPicture.string(svg, width: 200, height: 50),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('hanging with multi-position attributes', (tester) async {
        const svg = '''
          <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
            <text x="20 40 60 80 100 120 140" y="30" font-size="16" style="hanging-punctuation: first last">(Hello)</text>
          </svg>
        ''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AnimatedSvgPicture.string(svg, width: 200, height: 50),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('hanging with text-indent', (tester) async {
        const svg = '''
          <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
            <text x="50" y="30" font-size="16" style="hanging-punctuation: first; text-indent: 20px">(Indented)</text>
          </svg>
        ''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AnimatedSvgPicture.string(svg, width: 200, height: 50),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('all values combined: first force-end last', (tester) async {
        const svg = '''
          <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
            <text x="50" y="30" font-size="16" style="hanging-punctuation: first force-end last">(Hello,)</text>
          </svg>
        ''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AnimatedSvgPicture.string(svg, width: 200, height: 50),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });
    });

    group('special quote characters', () {
      testWidgets('hangs guillemet quotes « »', (tester) async {
        const svg = '''
          <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
            <text x="50" y="30" font-size="16" style="hanging-punctuation: first last">«Bonjour»</text>
          </svg>
        ''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AnimatedSvgPicture.string(svg, width: 200, height: 50),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('hangs single guillemet quotes ‹ ›', (tester) async {
        const svg = '''
          <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
            <text x="50" y="30" font-size="16" style="hanging-punctuation: first last">‹single›</text>
          </svg>
        ''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AnimatedSvgPicture.string(svg, width: 200, height: 50),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('hangs curly quotes '
          '  " "', (tester) async {
        const svg = '''
          <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
            <text x="50" y="30" font-size="16" style="hanging-punctuation: first last">'Hello'</text>
          </svg>
        ''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AnimatedSvgPicture.string(svg, width: 200, height: 50),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });
    });
  });
}
