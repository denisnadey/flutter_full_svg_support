import 'package:flutter_svg/src/animation/animated_svg_picture.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Bidi Text Edge Cases', () {
    group('Mixed RTL/LTR in single tspan', () {
      testWidgets('Mixed Hebrew and English in single tspan', (tester) async {
        // Tests interleaved RTL/LTR text within a single tspan element
        const svg = '''
          <svg viewBox="0 0 400 100" xmlns="http://www.w3.org/2000/svg">
            <text x="10" y="30" font-size="16">
              <tspan>Hello שלום World עולם</tspan>
            </text>
          </svg>
        ''';

        await tester.pumpWidget(
          AnimatedSvgPicture.string(svg, width: 400, height: 100),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('Arabic numerals interleaved with Arabic text', (
        tester,
      ) async {
        // Numbers should remain LTR even in RTL context
        const svg = '''
          <svg viewBox="0 0 400 100" xmlns="http://www.w3.org/2000/svg">
            <text x="350" y="30" font-size="16" direction="rtl">
              <tspan>السعر 123.45 دولار</tspan>
            </text>
          </svg>
        ''';

        await tester.pumpWidget(
          AnimatedSvgPicture.string(svg, width: 400, height: 100),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('Multiple direction changes in single tspan', (
        tester,
      ) async {
        const svg = '''
          <svg viewBox="0 0 500 100" xmlns="http://www.w3.org/2000/svg">
            <text x="10" y="30" font-size="16">
              <tspan>LTR עברית LTR2 العربية LTR3</tspan>
            </text>
          </svg>
        ''';

        await tester.pumpWidget(
          AnimatedSvgPicture.string(svg, width: 500, height: 100),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });
    });

    group('BDO Element Semantics', () {
      testWidgets('bdo with dir="ltr" forces LTR direction', (tester) async {
        const svg = '''
          <svg viewBox="0 0 300 100" xmlns="http://www.w3.org/2000/svg">
            <text x="10" y="30" font-size="16">
              <bdo dir="ltr">שלום</bdo>
            </text>
          </svg>
        ''';

        await tester.pumpWidget(
          AnimatedSvgPicture.string(svg, width: 300, height: 100),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('bdo with dir="rtl" forces RTL direction', (tester) async {
        const svg = '''
          <svg viewBox="0 0 300 100" xmlns="http://www.w3.org/2000/svg">
            <text x="200" y="30" font-size="16">
              <bdo dir="rtl">HELLO</bdo>
            </text>
          </svg>
        ''';

        await tester.pumpWidget(
          AnimatedSvgPicture.string(svg, width: 300, height: 100),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('bdo with dir="auto" detects direction from content', (
        tester,
      ) async {
        const svg = '''
          <svg viewBox="0 0 400 150" xmlns="http://www.w3.org/2000/svg">
            <text x="10" y="30" font-size="16">
              <bdo dir="auto">Hello World</bdo>
            </text>
            <text x="300" y="60" font-size="16">
              <bdo dir="auto">שלום עולם</bdo>
            </text>
          </svg>
        ''';

        await tester.pumpWidget(
          AnimatedSvgPicture.string(svg, width: 400, height: 150),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('nested bdo elements with opposite directions', (
        tester,
      ) async {
        const svg = '''
          <svg viewBox="0 0 400 100" xmlns="http://www.w3.org/2000/svg">
            <text x="10" y="30" font-size="16">
              <bdo dir="rtl">
                Outer RTL
                <bdo dir="ltr">Inner LTR</bdo>
              </bdo>
            </text>
          </svg>
        ''';

        await tester.pumpWidget(
          AnimatedSvgPicture.string(svg, width: 400, height: 100),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });
    });

    group('Direction + unicode-bidi Interaction', () {
      testWidgets('unicode-bidi: plaintext determines direction from content', (
        tester,
      ) async {
        const svg = '''
          <svg viewBox="0 0 400 100" xmlns="http://www.w3.org/2000/svg">
            <text x="10" y="30" font-size="16" unicode-bidi="plaintext">
              שלום this should detect RTL from first strong char
            </text>
          </svg>
        ''';

        await tester.pumpWidget(
          AnimatedSvgPicture.string(svg, width: 400, height: 100),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('unicode-bidi: isolate-override combines both behaviors', (
        tester,
      ) async {
        const svg = '''
          <svg viewBox="0 0 400 100" xmlns="http://www.w3.org/2000/svg">
            <text x="10" y="30" font-size="16">
              Before
              <tspan unicode-bidi="isolate-override" direction="rtl">ABC123</tspan>
              After
            </text>
          </svg>
        ''';

        await tester.pumpWidget(
          AnimatedSvgPicture.string(svg, width: 400, height: 100),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('direction from CSS style attribute', (tester) async {
        const svg = '''
          <svg viewBox="0 0 300 100" xmlns="http://www.w3.org/2000/svg">
            <text x="280" y="30" font-size="16" style="direction: rtl; unicode-bidi: bidi-override">
              REVERSED TEXT
            </text>
          </svg>
        ''';

        await tester.pumpWidget(
          AnimatedSvgPicture.string(svg, width: 300, height: 100),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('unicode-bidi: embed with nested direction changes', (
        tester,
      ) async {
        const svg = '''
          <svg viewBox="0 0 500 100" xmlns="http://www.w3.org/2000/svg">
            <text x="10" y="30" font-size="16" direction="ltr">
              <tspan unicode-bidi="embed" direction="rtl">
                עברית
                <tspan unicode-bidi="embed" direction="ltr">English</tspan>
              </tspan>
            </text>
          </svg>
        ''';

        await tester.pumpWidget(
          AnimatedSvgPicture.string(svg, width: 500, height: 100),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });
    });

    group('Cursor/Selection in Mixed Direction', () {
      testWidgets('RTL text with LTR numbers maintains correct order', (
        tester,
      ) async {
        const svg = '''
          <svg viewBox="0 0 400 100" xmlns="http://www.w3.org/2000/svg">
            <text x="350" y="30" font-size="16" direction="rtl" text-anchor="end">
              מחיר: \$99.99
            </text>
          </svg>
        ''';

        await tester.pumpWidget(
          AnimatedSvgPicture.string(svg, width: 400, height: 100),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('Complex mixed script positioning with explicit coordinates', (
        tester,
      ) async {
        const svg = '''
          <svg viewBox="0 0 500 100" xmlns="http://www.w3.org/2000/svg">
            <text font-size="16" direction="ltr">
              <tspan x="10" y="30">Start</tspan>
              <tspan direction="rtl">עברית</tspan>
              <tspan>Middle</tspan>
              <tspan direction="rtl">العربية</tspan>
              <tspan>End</tspan>
            </text>
          </svg>
        ''';

        await tester.pumpWidget(
          AnimatedSvgPicture.string(svg, width: 500, height: 100),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('Per-character dx/dy with RTL text', (tester) async {
        const svg = '''
          <svg viewBox="0 0 400 100" xmlns="http://www.w3.org/2000/svg">
            <text x="300" y="50" font-size="16" direction="rtl"
                  dx="0 5 10 15 20" dy="0 2 4 2 0">
              שלום!
            </text>
          </svg>
        ''';

        await tester.pumpWidget(
          AnimatedSvgPicture.string(svg, width: 400, height: 100),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });
    });

    group('Edge Cases', () {
      testWidgets('Empty bdo element', (tester) async {
        const svg = '''
          <svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
            <text x="10" y="30" font-size="16">
              Before<bdo dir="rtl"></bdo>After
            </text>
          </svg>
        ''';

        await tester.pumpWidget(
          AnimatedSvgPicture.string(svg, width: 200, height: 100),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('Single character RTL in LTR context', (tester) async {
        const svg = '''
          <svg viewBox="0 0 300 100" xmlns="http://www.w3.org/2000/svg">
            <text x="10" y="30" font-size="16">
              A<tspan direction="rtl">ש</tspan>B
            </text>
          </svg>
        ''';

        await tester.pumpWidget(
          AnimatedSvgPicture.string(svg, width: 300, height: 100),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('RTL punctuation handling', (tester) async {
        const svg = '''
          <svg viewBox="0 0 400 100" xmlns="http://www.w3.org/2000/svg">
            <text x="350" y="30" font-size="16" direction="rtl">
              "שלום, עולם!" - ברכה
            </text>
          </svg>
        ''';

        await tester.pumpWidget(
          AnimatedSvgPicture.string(svg, width: 400, height: 100),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('Multiple scripts in text-anchor middle alignment', (
        tester,
      ) async {
        const svg = '''
          <svg viewBox="0 0 400 100" xmlns="http://www.w3.org/2000/svg">
            <text x="200" y="30" font-size="16" text-anchor="middle">
              English עברית 中文 العربية
            </text>
          </svg>
        ''';

        await tester.pumpWidget(
          AnimatedSvgPicture.string(svg, width: 400, height: 100),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });
    });
  });
}
