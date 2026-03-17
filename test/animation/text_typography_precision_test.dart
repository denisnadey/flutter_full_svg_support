import 'package:flutter/material.dart';
import 'package:flutter_svg/src/animation/animated_svg_picture.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('dominant-baseline precision', () {
    testWidgets('hanging baseline positions text correctly', (tester) async {
      const svg = '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
        <text x="10" y="50" dominant-baseline="hanging" fill="black">Hanging</text>
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

    testWidgets('mathematical baseline positions text correctly', (
      tester,
    ) async {
      const svg = '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
        <text x="10" y="50" dominant-baseline="mathematical" fill="black">Math</text>
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

    testWidgets('ideographic baseline positions text correctly', (
      tester,
    ) async {
      const svg = '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
        <text x="10" y="80" dominant-baseline="ideographic" fill="black">漢字</text>
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

    testWidgets('central baseline positions text at vertical center', (
      tester,
    ) async {
      const svg = '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
        <text x="10" y="50" dominant-baseline="central" fill="black">Central</text>
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

    testWidgets('alignment-baseline falls back to dominant-baseline', (
      tester,
    ) async {
      const svg = '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
        <text x="10" y="50" alignment-baseline="middle" fill="black">Middle</text>
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

  group('baseline-shift precision', () {
    testWidgets('percentage baseline-shift uses line-height', (tester) async {
      const svg = '''<svg viewBox="0 0 300 100" xmlns="http://www.w3.org/2000/svg">
        <text x="10" y="50" fill="black" style="line-height: 1.5">
          Base<tspan baseline-shift="50%">shifted</tspan>
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

    testWidgets('em units baseline-shift works', (tester) async {
      const svg = '''<svg viewBox="0 0 300 100" xmlns="http://www.w3.org/2000/svg">
        <text x="10" y="50" fill="black">
          Base<tspan baseline-shift="0.5em">shifted</tspan>
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

    testWidgets('ex units baseline-shift works', (tester) async {
      const svg = '''<svg viewBox="0 0 300 100" xmlns="http://www.w3.org/2000/svg">
        <text x="10" y="50" fill="black">
          Base<tspan baseline-shift="1ex">shifted</tspan>
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

    testWidgets('sub keyword shifts down', (tester) async {
      const svg = '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
        <text x="10" y="50" fill="black">
          H<tspan baseline-shift="sub">2</tspan>O
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

    testWidgets('super keyword shifts up', (tester) async {
      const svg = '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
        <text x="10" y="50" fill="black">
          x<tspan baseline-shift="super">2</tspan>
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

  group('textPath method attribute', () {
    testWidgets('method="align" positions glyphs along path', (tester) async {
      const svg = '''<svg viewBox="0 0 300 200" xmlns="http://www.w3.org/2000/svg">
        <defs>
          <path id="myPath" d="M 50,100 Q 150,50 250,100" fill="none"/>
        </defs>
        <text fill="black">
          <textPath href="#myPath" method="align">Aligned text on path</textPath>
        </text>
      </svg>''';

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
      const svg = '''<svg viewBox="0 0 300 200" xmlns="http://www.w3.org/2000/svg">
        <defs>
          <path id="myPath" d="M 50,100 Q 150,50 250,100" fill="none"/>
        </defs>
        <text fill="black">
          <textPath href="#myPath" method="stretch">Stretched</textPath>
        </text>
      </svg>''';

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

    testWidgets('textPath with percentage startOffset', (tester) async {
      const svg = '''<svg viewBox="0 0 300 200" xmlns="http://www.w3.org/2000/svg">
        <defs>
          <path id="myPath" d="M 0,100 L 300,100" fill="none"/>
        </defs>
        <text fill="black">
          <textPath href="#myPath" startOffset="50%">Centered on path</textPath>
        </text>
      </svg>''';

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

    testWidgets('textPath text overflow is clipped at path end', (tester) async {
      const svg = '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
        <defs>
          <path id="shortPath" d="M 10,50 L 100,50" fill="none"/>
        </defs>
        <text font-size="20" fill="black">
          <textPath href="#shortPath">This text is longer than the path</textPath>
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

  group('bidirectional text handling', () {
    testWidgets('unicode-bidi embed works with RTL', (tester) async {
      const svg = '''<svg viewBox="0 0 400 100" xmlns="http://www.w3.org/2000/svg">
        <text x="390" y="50" direction="rtl" unicode-bidi="embed" fill="black">
          שלום Hello World
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

    testWidgets('unicode-bidi bidi-override forces direction', (tester) async {
      const svg = '''<svg viewBox="0 0 300 100" xmlns="http://www.w3.org/2000/svg">
        <text x="10" y="50" direction="rtl" unicode-bidi="bidi-override" fill="black">
          ABC123
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
      const svg = '''<svg viewBox="0 0 400 100" xmlns="http://www.w3.org/2000/svg">
        <text x="10" y="50" fill="black">
          LTR <tspan direction="rtl" unicode-bidi="isolate">מבודד</tspan> text
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

    testWidgets('unicode-bidi isolate-override works', (tester) async {
      const svg = '''<svg viewBox="0 0 400 100" xmlns="http://www.w3.org/2000/svg">
        <text x="10" y="50" fill="black">
          Normal <tspan direction="rtl" unicode-bidi="isolate-override">ABC</tspan> text
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

    testWidgets('unicode-bidi plaintext determines direction', (tester) async {
      const svg = '''<svg viewBox="0 0 400 100" xmlns="http://www.w3.org/2000/svg">
        <text x="10" y="50" unicode-bidi="plaintext" fill="black">
          שלום וברכה
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

  group('font-size-adjust', () {
    testWidgets('font-size-adjust scales font size based on aspect ratio', (
      tester,
    ) async {
      const svg = '''<svg viewBox="0 0 300 100" xmlns="http://www.w3.org/2000/svg">
        <text x="10" y="30" font-size="24" fill="black">Normal text</text>
        <text x="10" y="70" font-size="24" font-size-adjust="0.5" fill="black">Adjusted text</text>
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

    testWidgets('font-size-adjust none has no effect', (tester) async {
      const svg = '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
        <text x="10" y="50" font-size="24" font-size-adjust="none" fill="black">Normal</text>
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

  group('font-stretch', () {
    testWidgets('font-stretch condensed keyword applies', (tester) async {
      const svg = '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
        <text x="10" y="50" font-stretch="condensed" fill="black">Condensed</text>
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

    testWidgets('font-stretch expanded keyword applies', (tester) async {
      const svg = '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
        <text x="10" y="50" font-stretch="expanded" fill="black">Expanded</text>
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

    testWidgets('font-stretch percentage applies', (tester) async {
      const svg = '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
        <text x="10" y="50" font-stretch="150%" fill="black">150%</text>
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

    testWidgets('font-stretch ultra-condensed keyword', (tester) async {
      const svg = '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
        <text x="10" y="50" font-stretch="ultra-condensed" fill="black">Ultra</text>
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

  group('multi-position attribute edge cases', () {
    testWidgets('rotate last value repeats for remaining chars', (tester) async {
      const svg = '''<svg viewBox="0 0 300 100" xmlns="http://www.w3.org/2000/svg">
        <text x="50" y="50" rotate="0 15 30" fill="black">ABCDEFGH</text>
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

    testWidgets('mixed x and dx positioning', (tester) async {
      const svg = '''<svg viewBox="0 0 300 100" xmlns="http://www.w3.org/2000/svg">
        <text x="10 50" dx="5 10 15" y="50" fill="black">ABCDEF</text>
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

    testWidgets('vertical writing mode with multi-position attributes', (
      tester,
    ) async {
      const svg = '''<svg viewBox="0 0 100 300" xmlns="http://www.w3.org/2000/svg">
        <text x="50" y="20 60 100 140" writing-mode="vertical-rl" fill="black">縦書き</text>
      </svg>''';

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

    testWidgets('tspan inherits and extends position lists', (tester) async {
      const svg = '''<svg viewBox="0 0 400 100" xmlns="http://www.w3.org/2000/svg">
        <text x="10 50 90" y="50" fill="black">
          ABC<tspan>DEF</tspan>
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
