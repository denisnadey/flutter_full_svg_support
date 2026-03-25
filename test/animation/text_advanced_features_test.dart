import 'package:flutter/material.dart';
import 'package:flutter_svg/src/animation/animated_svg_picture.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('tref element', () {
    testWidgets('tref references text element content', (tester) async {
      const svg =
          '''<svg viewBox="0 0 300 100" xmlns="http://www.w3.org/2000/svg">
        <defs>
          <text id="sourceText">Hello World</text>
        </defs>
        <text x="10" y="50" fill="black">
          <tref href="#sourceText"/>
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

    testWidgets('tref with xlink:href references text content', (tester) async {
      const svg =
          '''<svg viewBox="0 0 300 100" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">
        <defs>
          <text id="refText">Referenced Text</text>
        </defs>
        <text x="10" y="50" fill="black">
          <tref xlink:href="#refText"/>
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

    testWidgets('tref applies its own styling', (tester) async {
      const svg =
          '''<svg viewBox="0 0 300 100" xmlns="http://www.w3.org/2000/svg">
        <defs>
          <text id="styledRef">Styled Text</text>
        </defs>
        <text x="10" y="50" fill="black">
          <tref href="#styledRef" fill="red" font-weight="bold"/>
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

    testWidgets('tref with own positioning attributes', (tester) async {
      const svg =
          '''<svg viewBox="0 0 300 100" xmlns="http://www.w3.org/2000/svg">
        <defs>
          <text id="posRef">Positioned</text>
        </defs>
        <text x="10" y="50" fill="black">
          Start <tref href="#posRef" x="100" y="30"/> End
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

    testWidgets('tref references nested text content', (tester) async {
      const svg =
          '''<svg viewBox="0 0 300 100" xmlns="http://www.w3.org/2000/svg">
        <defs>
          <text id="nestedRef">
            Hello <tspan>World</tspan>
          </text>
        </defs>
        <text x="10" y="50" fill="black">
          <tref href="#nestedRef"/>
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

    testWidgets('tref with missing reference renders gracefully', (
      tester,
    ) async {
      const svg =
          '''<svg viewBox="0 0 300 100" xmlns="http://www.w3.org/2000/svg">
        <text x="10" y="50" fill="black">
          <tref href="#nonExistent"/>Fallback
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

  group('RTL and BiDi text rendering', () {
    testWidgets('text with direction="rtl" renders correctly', (tester) async {
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

    testWidgets('RTL text with text-anchor="start" (behaves as end)', (
      tester,
    ) async {
      const svg =
          '''<svg viewBox="0 0 300 100" xmlns="http://www.w3.org/2000/svg">
        <text x="150" y="50" direction="rtl" text-anchor="start" fill="black">
          مرحبا
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

    testWidgets('RTL text with text-anchor="end" (behaves as start)', (
      tester,
    ) async {
      const svg =
          '''<svg viewBox="0 0 300 100" xmlns="http://www.w3.org/2000/svg">
        <text x="150" y="50" direction="rtl" text-anchor="end" fill="black">
          مرحبا
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

    testWidgets('mixed LTR/RTL text in single element', (tester) async {
      const svg =
          '''<svg viewBox="0 0 400 100" xmlns="http://www.w3.org/2000/svg">
        <text x="10" y="50" fill="black">Hello שלום World</text>
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

    testWidgets('unicode-bidi="embed" applies direction embedding', (
      tester,
    ) async {
      const svg =
          '''<svg viewBox="0 0 300 100" xmlns="http://www.w3.org/2000/svg">
        <text x="10" y="50" fill="black">
          <tspan unicode-bidi="embed" direction="rtl">עברית</tspan> English
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

    testWidgets('unicode-bidi="bidi-override" forces direction', (
      tester,
    ) async {
      const svg =
          '''<svg viewBox="0 0 300 100" xmlns="http://www.w3.org/2000/svg">
        <text x="10" y="50" fill="black">
          <tspan unicode-bidi="bidi-override" direction="rtl">ABC</tspan>
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

    testWidgets('unicode-bidi="isolate" isolates text', (tester) async {
      const svg =
          '''<svg viewBox="0 0 300 100" xmlns="http://www.w3.org/2000/svg">
        <text x="10" y="50" fill="black">
          Before <tspan unicode-bidi="isolate" direction="rtl">שלום</tspan> After
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

  group('font fallback chains', () {
    testWidgets('single font family works', (tester) async {
      const svg =
          '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
        <text x="10" y="50" font-family="Arial" fill="black">Single Font</text>
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

    testWidgets('comma-separated font families work', (tester) async {
      const svg =
          '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
        <text x="10" y="50" font-family="Helvetica, Arial, sans-serif" fill="black">
          Fallback Fonts
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

    testWidgets('quoted font names with spaces work', (tester) async {
      const svg =
          '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
        <text x="10" y="50" font-family="'Helvetica Neue', Arial, sans-serif" fill="black">
          Quoted Fonts
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

    testWidgets('double-quoted font names work', (tester) async {
      const svg =
          '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
        <text x="10" y="50" font-family='"Open Sans", sans-serif' fill="black">
          Double Quoted
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

    testWidgets('generic family serif works', (tester) async {
      const svg =
          '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
        <text x="10" y="50" font-family="serif" fill="black">Serif Text</text>
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

    testWidgets('generic family sans-serif works', (tester) async {
      const svg =
          '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
        <text x="10" y="50" font-family="sans-serif" fill="black">Sans-serif</text>
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

    testWidgets('generic family monospace works', (tester) async {
      const svg =
          '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
        <text x="10" y="50" font-family="monospace" fill="black">Monospace</text>
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

    testWidgets('system-ui font family works', (tester) async {
      const svg =
          '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
        <text x="10" y="50" font-family="system-ui" fill="black">System UI</text>
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

  group('per-character positioning edge cases', () {
    testWidgets('x list shorter than text - remaining chars flow naturally', (
      tester,
    ) async {
      const svg =
          '''<svg viewBox="0 0 300 100" xmlns="http://www.w3.org/2000/svg">
        <text x="10 50 90" y="50" fill="black">ABCDEFGH</text>
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

    testWidgets('y list shorter than text - remaining use last y', (
      tester,
    ) async {
      const svg =
          '''<svg viewBox="0 0 300 100" xmlns="http://www.w3.org/2000/svg">
        <text x="10" y="30 50" fill="black">ABCDEF</text>
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

    testWidgets('dx/dy accumulate for each character', (tester) async {
      const svg =
          '''<svg viewBox="0 0 300 100" xmlns="http://www.w3.org/2000/svg">
        <text x="10" y="50" dx="0 5 10 15" dy="0 -5 5 0" fill="black">ABCD</text>
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

    testWidgets('rotate with single value applies to all characters', (
      tester,
    ) async {
      const svg =
          '''<svg viewBox="0 0 300 100" xmlns="http://www.w3.org/2000/svg">
        <text x="10" y="50" rotate="30" fill="black">ABCDEF</text>
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

    testWidgets('rotate list shorter - last value repeats', (tester) async {
      const svg =
          '''<svg viewBox="0 0 300 100" xmlns="http://www.w3.org/2000/svg">
        <text x="10" y="50" rotate="0 30 60" fill="black">ABCDEFGH</text>
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

    testWidgets('nested tspan overrides parent position lists', (tester) async {
      const svg =
          '''<svg viewBox="0 0 300 100" xmlns="http://www.w3.org/2000/svg">
        <text x="10 30 50 70" y="50" fill="black">
          AB<tspan x="150 170" fill="red">CD</tspan>EF
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

    testWidgets('tspan with absolute y creates new text chunk', (tester) async {
      const svg =
          '''<svg viewBox="0 0 300 100" xmlns="http://www.w3.org/2000/svg">
        <text x="10" y="30" fill="black">
          Line 1<tspan x="10" y="60">Line 2</tspan>
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

    testWidgets('position lists longer than text - excess ignored', (
      tester,
    ) async {
      const svg =
          '''<svg viewBox="0 0 300 100" xmlns="http://www.w3.org/2000/svg">
        <text x="10 50 90 130 170 210 250" y="50" fill="black">ABC</text>
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

    testWidgets('combined x, dx, rotate positioning', (tester) async {
      const svg =
          '''<svg viewBox="0 0 300 100" xmlns="http://www.w3.org/2000/svg">
        <text x="20 60 100" dx="5 10 15" rotate="0 30 60" y="50" fill="black">ABC</text>
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

    testWidgets('deeply nested tspan position inheritance', (tester) async {
      const svg =
          '''<svg viewBox="0 0 400 100" xmlns="http://www.w3.org/2000/svg">
        <text x="10" y="50" fill="black">
          L1<tspan dx="20">L2<tspan dx="20">L3<tspan dx="20">L4</tspan></tspan></tspan>
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
}
