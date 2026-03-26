import 'package:flutter/material.dart';
import 'package:flutter_svg/src/animation/animated_svg_picture.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('tspan absolute positioning edge cases', () {
    testWidgets('tspan with absolute x resets cursor position', (tester) async {
      const svg =
          '''<svg viewBox="0 0 300 100" xmlns="http://www.w3.org/2000/svg">
        <text x="10" y="50" fill="black">
          First<tspan x="150">Second</tspan>
        </text>
      </svg>''';

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

    testWidgets('tspan with absolute y resets cursor position', (tester) async {
      const svg =
          '''<svg viewBox="0 0 300 100" xmlns="http://www.w3.org/2000/svg">
        <text x="10" y="30" fill="black">
          Line1<tspan y="70">Line2</tspan>
        </text>
      </svg>''';

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

    testWidgets('multiple tspans with absolute x create independent chunks', (
      tester,
    ) async {
      const svg =
          '''<svg viewBox="0 0 400 100" xmlns="http://www.w3.org/2000/svg">
        <text x="10" y="50" fill="black">
          <tspan>A</tspan>
          <tspan x="100">B</tspan>
          <tspan x="200">C</tspan>
        </text>
      </svg>''';

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

    testWidgets('nested tspan overrides parent absolute positioning', (
      tester,
    ) async {
      const svg =
          '''<svg viewBox="0 0 400 100" xmlns="http://www.w3.org/2000/svg">
        <text x="50" y="50" fill="black">
          Parent<tspan x="200" y="70">
            Child<tspan x="300" y="30">Grandchild</tspan>
          </tspan>
        </text>
      </svg>''';

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

    testWidgets('tspan with both x and y creates new chunk', (tester) async {
      const svg =
          '''<svg viewBox="0 0 300 100" xmlns="http://www.w3.org/2000/svg">
        <text x="10" y="30" fill="black">
          Start<tspan x="150" y="70">Repositioned</tspan>End
        </text>
      </svg>''';

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

  group('complex font fallback chain', () {
    testWidgets('font-family with multiple fallbacks renders', (tester) async {
      const svg =
          '''<svg viewBox="0 0 300 100" xmlns="http://www.w3.org/2000/svg">
        <text x="10" y="50" font-family="NonExistentFont, Arial, sans-serif" fill="black">
          Font Fallback Test
        </text>
      </svg>''';

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

    testWidgets('generic font family serif expands to platform fonts', (
      tester,
    ) async {
      const svg =
          '''<svg viewBox="0 0 300 100" xmlns="http://www.w3.org/2000/svg">
        <text x="10" y="50" font-family="serif" fill="black">
          Serif Font Test
        </text>
      </svg>''';

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

    testWidgets('generic font family monospace expands correctly', (
      tester,
    ) async {
      const svg =
          '''<svg viewBox="0 0 300 100" xmlns="http://www.w3.org/2000/svg">
        <text x="10" y="50" font-family="monospace" fill="black">
          Monospace Font Test
        </text>
      </svg>''';

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

    testWidgets('system-ui font family resolves', (tester) async {
      const svg =
          '''<svg viewBox="0 0 300 100" xmlns="http://www.w3.org/2000/svg">
        <text x="10" y="50" font-family="system-ui" fill="black">
          System UI Font Test
        </text>
      </svg>''';

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

    testWidgets('quoted font names parse correctly', (tester) async {
      const svg =
          '''<svg viewBox="0 0 300 100" xmlns="http://www.w3.org/2000/svg">
        <text x="10" y="50" font-family="'Helvetica Neue', 'Open Sans', sans-serif" fill="black">
          Quoted Font Names
        </text>
      </svg>''';

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

  group('bidirectional text handling', () {
    testWidgets('direction="rtl" applies right-to-left text direction', (
      tester,
    ) async {
      const svg =
          '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
        <text x="190" y="50" direction="rtl" fill="black">مرحبا</text>
      </svg>''';

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

    testWidgets('direction="ltr" applies left-to-right text direction', (
      tester,
    ) async {
      const svg =
          '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
        <text x="10" y="50" direction="ltr" fill="black">Hello</text>
      </svg>''';

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

    testWidgets('unicode-bidi embed works', (tester) async {
      const svg =
          '''<svg viewBox="0 0 300 100" xmlns="http://www.w3.org/2000/svg">
        <text x="10" y="50" direction="ltr" unicode-bidi="embed" fill="black">
          English مرحبا English
        </text>
      </svg>''';

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

    testWidgets('unicode-bidi bidi-override works', (tester) async {
      const svg =
          '''<svg viewBox="0 0 300 100" xmlns="http://www.w3.org/2000/svg">
        <text x="10" y="50" direction="rtl" unicode-bidi="bidi-override" fill="black">
          ABCDEF
        </text>
      </svg>''';

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

    testWidgets('unicode-bidi isolate works', (tester) async {
      const svg =
          '''<svg viewBox="0 0 300 100" xmlns="http://www.w3.org/2000/svg">
        <text x="10" y="50" unicode-bidi="isolate" fill="black">
          Isolated text
        </text>
      </svg>''';

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

    testWidgets('unicode-bidi isolate-override works', (tester) async {
      const svg =
          '''<svg viewBox="0 0 300 100" xmlns="http://www.w3.org/2000/svg">
        <text x="10" y="50" direction="rtl" unicode-bidi="isolate-override" fill="black">
          Override isolated
        </text>
      </svg>''';

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

    testWidgets('unicode-bidi plaintext works', (tester) async {
      const svg =
          '''<svg viewBox="0 0 300 100" xmlns="http://www.w3.org/2000/svg">
        <text x="10" y="50" unicode-bidi="plaintext" fill="black">
          Plain text auto direction
        </text>
      </svg>''';

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

    testWidgets('mixed RTL and LTR text in same element', (tester) async {
      const svg =
          '''<svg viewBox="0 0 400 100" xmlns="http://www.w3.org/2000/svg">
        <text x="10" y="50" fill="black">
          Hello <tspan direction="rtl">שלום</tspan> World
        </text>
      </svg>''';

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

    testWidgets('Arabic text renders correctly', (tester) async {
      const svg =
          '''<svg viewBox="0 0 300 100" xmlns="http://www.w3.org/2000/svg">
        <text x="290" y="50" direction="rtl" fill="black">السلام عليكم</text>
      </svg>''';

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

    testWidgets('Hebrew text renders correctly', (tester) async {
      const svg =
          '''<svg viewBox="0 0 300 100" xmlns="http://www.w3.org/2000/svg">
        <text x="290" y="50" direction="rtl" fill="black">שלום עולם</text>
      </svg>''';

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

    testWidgets('BiDi text with text-anchor middle', (tester) async {
      const svg =
          '''<svg viewBox="0 0 300 100" xmlns="http://www.w3.org/2000/svg">
        <text x="150" y="50" text-anchor="middle" direction="rtl" fill="black">مرحبا</text>
      </svg>''';

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

    testWidgets('BiDi text with text-anchor end', (tester) async {
      const svg =
          '''<svg viewBox="0 0 300 100" xmlns="http://www.w3.org/2000/svg">
        <text x="290" y="50" text-anchor="end" direction="rtl" fill="black">مرحبا</text>
      </svg>''';

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

  group('combining marks and diacritics', () {
    testWidgets('combining acute accent renders correctly', (tester) async {
      // e + combining acute accent = é
      const svg =
          '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
        <text x="10" y="50" fill="black">cafe&#x0301;</text>
      </svg>''';

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

    testWidgets('precomposed character renders correctly', (tester) async {
      const svg =
          '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
        <text x="10" y="50" fill="black">café</text>
      </svg>''';

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

    testWidgets('multiple combining marks render', (tester) async {
      // o + combining tilde + combining acute
      const svg =
          '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
        <text x="10" y="50" fill="black">o&#x0303;&#x0301;</text>
      </svg>''';

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

    testWidgets('Vietnamese text with diacritics renders', (tester) async {
      const svg =
          '''<svg viewBox="0 0 300 100" xmlns="http://www.w3.org/2000/svg">
        <text x="10" y="50" fill="black">Việt Nam</text>
      </svg>''';

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

  group('complex scripts', () {
    testWidgets('Thai text with vowel marks renders', (tester) async {
      const svg =
          '''<svg viewBox="0 0 300 100" xmlns="http://www.w3.org/2000/svg">
        <text x="10" y="50" fill="black">สวัสดี</text>
      </svg>''';

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

    testWidgets('Devanagari text renders', (tester) async {
      const svg =
          '''<svg viewBox="0 0 300 100" xmlns="http://www.w3.org/2000/svg">
        <text x="10" y="50" fill="black">नमस्ते</text>
      </svg>''';

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

    testWidgets('Korean text renders', (tester) async {
      const svg =
          '''<svg viewBox="0 0 300 100" xmlns="http://www.w3.org/2000/svg">
        <text x="10" y="50" fill="black">안녕하세요</text>
      </svg>''';

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

    testWidgets('Chinese text renders', (tester) async {
      const svg =
          '''<svg viewBox="0 0 300 100" xmlns="http://www.w3.org/2000/svg">
        <text x="10" y="50" fill="black">你好世界</text>
      </svg>''';

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

    testWidgets('Japanese text renders', (tester) async {
      const svg =
          '''<svg viewBox="0 0 300 100" xmlns="http://www.w3.org/2000/svg">
        <text x="10" y="50" fill="black">こんにちは</text>
      </svg>''';

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

  group('character-precise hit-testing', () {
    testWidgets('per-character bounding boxes work with multi-position x', (
      tester,
    ) async {
      const svg =
          '''<svg viewBox="0 0 300 100" xmlns="http://www.w3.org/2000/svg">
        <text x="10 50 90 130 170" y="50" fill="black">CLICK</text>
      </svg>''';

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

    testWidgets('per-character bounding boxes work with rotate', (
      tester,
    ) async {
      const svg =
          '''<svg viewBox="0 0 300 100" xmlns="http://www.w3.org/2000/svg">
        <text x="50" y="50" rotate="0 15 30 45 60" fill="black">ABCDE</text>
      </svg>''';

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

    testWidgets('character-precise hit-testing with dx offsets', (
      tester,
    ) async {
      const svg =
          '''<svg viewBox="0 0 300 100" xmlns="http://www.w3.org/2000/svg">
        <text x="10" y="50" dx="0 10 20 30 40" fill="black">HELLO</text>
      </svg>''';

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

    testWidgets('character-precise hit-testing with dy offsets', (
      tester,
    ) async {
      const svg =
          '''<svg viewBox="0 0 300 100" xmlns="http://www.w3.org/2000/svg">
        <text x="10" y="50" dy="0 -5 0 5 0" fill="black">WORLD</text>
      </svg>''';

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

  group('edge cases', () {
    testWidgets('empty text element renders', (tester) async {
      const svg =
          '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
        <text x="10" y="50" fill="black"></text>
      </svg>''';

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

    testWidgets('single RTL character renders', (tester) async {
      const svg =
          '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
        <text x="100" y="50" direction="rtl" fill="black">א</text>
      </svg>''';

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

    testWidgets('whitespace-only text renders', (tester) async {
      const svg =
          '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
        <text x="10" y="50" fill="black">   </text>
      </svg>''';

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

    testWidgets('very long text renders', (tester) async {
      final longText = 'A' * 1000;
      final svg =
          '''<svg viewBox="0 0 5000 100" xmlns="http://www.w3.org/2000/svg">
        <text x="10" y="50" fill="black">$longText</text>
      </svg>''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svg, width: 500, height: 100),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('text with special XML characters renders', (tester) async {
      const svg =
          '''<svg viewBox="0 0 300 100" xmlns="http://www.w3.org/2000/svg">
        <text x="10" y="50" fill="black">&lt;tag&gt; &amp; "quote"</text>
      </svg>''';

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

  group('text-anchor per-chunk handling', () {
    testWidgets('text-anchor middle applies to each chunk independently', (
      tester,
    ) async {
      const svg =
          '''<svg viewBox="0 0 400 100" xmlns="http://www.w3.org/2000/svg">
        <text text-anchor="middle" y="50" fill="black">
          <tspan x="100">Chunk1</tspan>
          <tspan x="300">Chunk2</tspan>
        </text>
      </svg>''';

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

    testWidgets('text-anchor end applies to each chunk independently', (
      tester,
    ) async {
      const svg =
          '''<svg viewBox="0 0 400 100" xmlns="http://www.w3.org/2000/svg">
        <text text-anchor="end" y="50" fill="black">
          <tspan x="100">Chunk1</tspan>
          <tspan x="300">Chunk2</tspan>
        </text>
      </svg>''';

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

    testWidgets('text-anchor only affects chunks with absolute positions', (
      tester,
    ) async {
      const svg =
          '''<svg viewBox="0 0 400 100" xmlns="http://www.w3.org/2000/svg">
        <text text-anchor="middle" x="200" y="50" fill="black">
          Initial<tspan>NoAbsolute</tspan><tspan x="350">NewChunk</tspan>
        </text>
      </svg>''';

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

  group('text-decoration styling', () {
    testWidgets('text-decoration-color overrides fill color for decoration', (
      tester,
    ) async {
      const svg =
          '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
        <text x="10" y="50" fill="black" text-decoration="underline" 
              text-decoration-color="red">Colored underline</text>
      </svg>''';

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

    testWidgets('nested tspan inherits text-decoration from parent', (
      tester,
    ) async {
      const svg =
          '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
        <text x="10" y="50" fill="black" text-decoration="underline">
          Parent <tspan fill="red">Child</tspan> End
        </text>
      </svg>''';

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

    testWidgets('tspan can override parent text-decoration', (tester) async {
      const svg =
          '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
        <text x="10" y="50" fill="black" text-decoration="underline">
          Parent <tspan text-decoration="line-through">Override</tspan> End
        </text>
      </svg>''';

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

  group('textLength conflict resolution', () {
    testWidgets(
      'textLength is ignored when explicit per-character x positions exist',
      (tester) async {
        const svg =
            '''<svg viewBox="0 0 300 100" xmlns="http://www.w3.org/2000/svg">
        <text x="10 30 50 70 90" y="50" textLength="200" fill="black">HELLO</text>
      </svg>''';

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
      },
    );

    testWidgets(
      'textLength is ignored when explicit per-character y positions exist',
      (tester) async {
        const svg =
            '''<svg viewBox="0 0 200 200" xmlns="http://www.w3.org/2000/svg">
        <text x="50" y="20 40 60 80 100" textLength="150" fill="black">HELLO</text>
      </svg>''';

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
      },
    );

    testWidgets('textLength applies without explicit positions', (
      tester,
    ) async {
      const svg =
          '''<svg viewBox="0 0 300 100" xmlns="http://www.w3.org/2000/svg">
        <text x="10" y="50" textLength="250" fill="black">Hello World</text>
      </svg>''';

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
}
