import 'package:flutter_svg/src/animation/animated_svg_picture.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Text BiDi and Complex Scripts Support', () {
    group('Direction Attribute', () {
      testWidgets('Simple RTL text with direction="rtl"', (tester) async {
        // Hebrew text "שלום" (Shalom) with RTL direction
        const svg = '''
          <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
            <text x="100" y="30" font-size="16" direction="rtl">שלום עולם</text>
          </svg>
        ''';

        await tester.pumpWidget(
          AnimatedSvgPicture.string(svg, width: 200, height: 50),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('LTR text with explicit direction="ltr"', (tester) async {
        const svg = '''
          <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
            <text x="10" y="30" font-size="16" direction="ltr">Hello World</text>
          </svg>
        ''';

        await tester.pumpWidget(
          AnimatedSvgPicture.string(svg, width: 200, height: 50),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('Default direction (ltr when omitted)', (tester) async {
        const svg = '''
          <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
            <text x="10" y="30" font-size="16">Default LTR Text</text>
          </svg>
        ''';

        await tester.pumpWidget(
          AnimatedSvgPicture.string(svg, width: 200, height: 50),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });
    });

    group('Mixed LTR/RTL in tspan children', () {
      testWidgets('Mixed direction tspans', (tester) async {
        // English "Hello" followed by Hebrew "שלום" in separate tspans
        const svg = '''
          <svg viewBox="0 0 300 50" xmlns="http://www.w3.org/2000/svg">
            <text x="10" y="30" font-size="16">
              <tspan direction="ltr">Hello </tspan>
              <tspan direction="rtl">שלום</tspan>
              <tspan direction="ltr"> World</tspan>
            </text>
          </svg>
        ''';

        await tester.pumpWidget(
          AnimatedSvgPicture.string(svg, width: 300, height: 50),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('Nested RTL text in LTR parent', (tester) async {
        const svg = '''
          <svg viewBox="0 0 400 50" xmlns="http://www.w3.org/2000/svg">
            <text x="10" y="30" font-size="16" direction="ltr">
              Before <tspan direction="rtl">مرحبا</tspan> After
            </text>
          </svg>
        ''';

        await tester.pumpWidget(
          AnimatedSvgPicture.string(svg, width: 400, height: 50),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });
    });

    group('text-anchor with RTL direction', () {
      testWidgets('text-anchor="start" with RTL (right-aligned)', (
        tester,
      ) async {
        const svg = '''
          <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
            <text x="190" y="30" font-size="16" direction="rtl" text-anchor="start">שלום</text>
          </svg>
        ''';

        await tester.pumpWidget(
          AnimatedSvgPicture.string(svg, width: 200, height: 50),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('text-anchor="end" with RTL (left-aligned)', (tester) async {
        const svg = '''
          <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
            <text x="10" y="30" font-size="16" direction="rtl" text-anchor="end">שלום</text>
          </svg>
        ''';

        await tester.pumpWidget(
          AnimatedSvgPicture.string(svg, width: 200, height: 50),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('text-anchor="middle" with RTL (centered)', (tester) async {
        const svg = '''
          <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
            <text x="100" y="30" font-size="16" direction="rtl" text-anchor="middle">שלום</text>
          </svg>
        ''';

        await tester.pumpWidget(
          AnimatedSvgPicture.string(svg, width: 200, height: 50),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });
    });

    group('unicode-bidi attribute', () {
      testWidgets('unicode-bidi="bidi-override" forcing direction', (
        tester,
      ) async {
        // Force all characters to display as RTL
        const svg = '''
          <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
            <text x="190" y="30" font-size="16" direction="rtl" unicode-bidi="bidi-override">ABC123</text>
          </svg>
        ''';

        await tester.pumpWidget(
          AnimatedSvgPicture.string(svg, width: 200, height: 50),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('unicode-bidi="embed" with nested direction', (tester) async {
        const svg = '''
          <svg viewBox="0 0 300 50" xmlns="http://www.w3.org/2000/svg">
            <text x="10" y="30" font-size="16">
              <tspan unicode-bidi="embed" direction="rtl">שלום</tspan>
              <tspan> World</tspan>
            </text>
          </svg>
        ''';

        await tester.pumpWidget(
          AnimatedSvgPicture.string(svg, width: 300, height: 50),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('unicode-bidi="isolate" text isolation', (tester) async {
        const svg = '''
          <svg viewBox="0 0 300 50" xmlns="http://www.w3.org/2000/svg">
            <text x="10" y="30" font-size="16">
              Start <tspan unicode-bidi="isolate" direction="rtl">עברית</tspan> End
            </text>
          </svg>
        ''';

        await tester.pumpWidget(
          AnimatedSvgPicture.string(svg, width: 300, height: 50),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });
    });

    group('Per-character positioning with RTL', () {
      testWidgets('Per-character dx/dy with RTL text', (tester) async {
        const svg = '''
          <svg viewBox="0 0 300 100" xmlns="http://www.w3.org/2000/svg">
            <text x="200" y="50" font-size="16" direction="rtl" 
                  dx="0 5 10 15" dy="0 0 5 5">שלום</text>
          </svg>
        ''';

        await tester.pumpWidget(
          AnimatedSvgPicture.string(svg, width: 300, height: 100),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('Explicit x positions with RTL text', (tester) async {
        const svg = '''
          <svg viewBox="0 0 300 50" xmlns="http://www.w3.org/2000/svg">
            <text font-size="16" direction="rtl" x="200 180 160 140">מילה</text>
          </svg>
        ''';

        await tester.pumpWidget(
          AnimatedSvgPicture.string(svg, width: 300, height: 50),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });
    });

    group('Combining marks and Unicode normalization', () {
      testWidgets('Text with combining marks (é as e + combining accent)', (
        tester,
      ) async {
        // Using decomposed form: e + combining acute accent (U+0301)
        const svg = '''
          <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
            <text x="10" y="30" font-size="16">cafe\u0301</text>
          </svg>
        ''';

        await tester.pumpWidget(
          AnimatedSvgPicture.string(svg, width: 200, height: 50),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('Multiple combining marks', (tester) async {
        // Text with multiple diacritics
        const svg = '''
          <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
            <text x="10" y="30" font-size="16">e\u0301 a\u0300 n\u0303</text>
          </svg>
        ''';

        await tester.pumpWidget(
          AnimatedSvgPicture.string(svg, width: 200, height: 50),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });
    });

    group('Grapheme cluster awareness', () {
      testWidgets('Emoji with ZWJ sequence', (tester) async {
        // Family emoji: man + ZWJ + woman + ZWJ + girl
        const svg = '''
          <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
            <text x="10" y="35" font-size="24">👨‍👩‍👧</text>
          </svg>
        ''';

        await tester.pumpWidget(
          AnimatedSvgPicture.string(svg, width: 200, height: 50),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('Flag sequences (regional indicators)', (tester) async {
        // US flag: regional indicator U + regional indicator S
        const svg = '''
          <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
            <text x="10" y="35" font-size="24">🇺🇸 🇬🇧 🇫🇷</text>
          </svg>
        ''';

        await tester.pumpWidget(
          AnimatedSvgPicture.string(svg, width: 200, height: 50),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('Emoji with skin tone modifier', (tester) async {
        // Waving hand with medium skin tone
        const svg = '''
          <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
            <text x="10" y="35" font-size="24">👋🏽 ✌🏻 🤙🏿</text>
          </svg>
        ''';

        await tester.pumpWidget(
          AnimatedSvgPicture.string(svg, width: 200, height: 50),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });
    });

    group('Integration tests', () {
      testWidgets('SVG with RTL text renders without error', (tester) async {
        const svg = '''
          <svg viewBox="0 0 400 200" xmlns="http://www.w3.org/2000/svg">
            <rect width="400" height="200" fill="#f0f0f0"/>
            <text x="380" y="50" font-size="20" direction="rtl" text-anchor="start" fill="navy">
              مرحبا بالعالم
            </text>
            <text x="380" y="100" font-size="20" direction="rtl" text-anchor="start" fill="darkgreen">
              שלום לעולם
            </text>
            <text x="20" y="150" font-size="20" direction="ltr" fill="darkred">
              Hello World
            </text>
          </svg>
        ''';

        await tester.pumpWidget(
          AnimatedSvgPicture.string(svg, width: 400, height: 200),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('SVG with mixed direction tspans renders correctly', (
        tester,
      ) async {
        const svg = '''
          <svg viewBox="0 0 500 100" xmlns="http://www.w3.org/2000/svg">
            <text x="10" y="50" font-size="18">
              <tspan direction="ltr" fill="blue">English: </tspan>
              <tspan direction="rtl" unicode-bidi="embed" fill="green">עברית </tspan>
              <tspan direction="ltr" fill="blue">and </tspan>
              <tspan direction="rtl" unicode-bidi="embed" fill="red">عربي</tspan>
            </text>
          </svg>
        ''';

        await tester.pumpWidget(
          AnimatedSvgPicture.string(svg, width: 500, height: 100),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('Complex SVG with multiple BiDi features', (tester) async {
        const svg = '''
          <svg viewBox="0 0 600 300" xmlns="http://www.w3.org/2000/svg">
            <!-- Background -->
            <rect width="600" height="300" fill="#fafafa"/>
            
            <!-- RTL paragraph with text-anchor variations -->
            <g direction="rtl" font-size="16">
              <text x="580" y="40" text-anchor="start" fill="#333">
                כותרת - start anchor
              </text>
              <text x="300" y="70" text-anchor="middle" fill="#333">
                מרכז - middle anchor
              </text>
              <text x="20" y="100" text-anchor="end" fill="#333">
                סוף - end anchor
              </text>
            </g>
            
            <!-- Mixed content -->
            <text x="20" y="150" font-size="14" fill="#555">
              <tspan>Price: </tspan>
              <tspan direction="ltr">\$99.99</tspan>
              <tspan> - </tspan>
              <tspan direction="rtl" unicode-bidi="isolate">מחיר</tspan>
            </text>
            
            <!-- Combining marks and special characters -->
            <text x="20" y="200" font-size="14" fill="#555">
              Caf&#xe9; na&#xef;ve fa&#xe7;ade r&#xe9;sum&#xe9;
            </text>
            
            <!-- Per-character positioning with RTL -->
            <text x="500" y="250" font-size="14" direction="rtl" 
                  dx="0 3 6 9 12" dy="0 2 0 -2 0" fill="#666">
              מילים
            </text>
          </svg>
        ''';

        await tester.pumpWidget(
          AnimatedSvgPicture.string(svg, width: 600, height: 300),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });
    });
  });
}
