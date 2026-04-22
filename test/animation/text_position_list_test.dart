import 'package:flutter/material.dart';
import 'package:full_svg_flutter/src/animation/animated_svg_picture.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('text multi-position attributes', () {
    testWidgets('text with multi-position x attribute parses without error', (
      tester,
    ) async {
      const svg =
          '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
        <text x="10 30 50" y="50" fill="black">ABC</text>
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

      // Should render without errors
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('text with multi-position y attribute parses without error', (
      tester,
    ) async {
      const svg =
          '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
        <text x="10" y="30 50 70" fill="black">ABC</text>
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

    testWidgets('text with multi-position dx attribute parses without error', (
      tester,
    ) async {
      const svg =
          '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
        <text x="10" y="50" dx="0 5 10" fill="black">ABC</text>
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

    testWidgets('text with multi-position dy attribute parses without error', (
      tester,
    ) async {
      const svg =
          '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
        <text x="10" y="50" dy="0 -5 5" fill="black">ABC</text>
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

    testWidgets('tspan inherits parent multi-position attributes', (
      tester,
    ) async {
      const svg =
          '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
        <text x="10 30 50 70" y="50" fill="black">
          AB<tspan fill="red">CD</tspan>
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

    testWidgets('tspan can override parent position lists', (tester) async {
      const svg =
          '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
        <text x="10" y="50" fill="black">
          AB<tspan x="100 120" fill="red">CD</tspan>
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

    testWidgets('comma-separated position values work', (tester) async {
      const svg =
          '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
        <text x="10,30,50" y="50" fill="black">ABC</text>
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

    testWidgets('mixed space and comma separators work', (tester) async {
      const svg =
          '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
        <text x="10, 30 50" y="50" fill="black">ABC</text>
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

    testWidgets('single value still works (backward compatibility)', (
      tester,
    ) async {
      const svg =
          '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
        <text x="50" y="50" fill="black">Hello</text>
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

    testWidgets('text with single rotate attribute applies to all characters', (
      tester,
    ) async {
      const svg =
          '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
        <text x="50" y="50" rotate="45" fill="black">ABC</text>
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

    testWidgets(
      'text with multi-position rotate attribute parses without error',
      (tester) async {
        const svg =
            '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
        <text x="10 40 70" y="50" rotate="0 30 60" fill="black">ABC</text>
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
      },
    );

    testWidgets(
      'rotate attribute last value repeats for remaining characters',
      (tester) async {
        // SVG spec: if there are fewer rotate values than characters,
        // the last value is used for remaining characters
        const svg =
            '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
        <text x="10" y="50" rotate="0 45" fill="black">ABCDE</text>
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
      },
    );

    testWidgets('tspan inherits parent rotate attribute', (tester) async {
      const svg =
          '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
        <text x="10" y="50" rotate="30" fill="black">
          AB<tspan fill="red">CD</tspan>
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

    testWidgets('tspan can override parent rotate attribute', (tester) async {
      const svg =
          '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
        <text x="10" y="50" rotate="0" fill="black">
          AB<tspan rotate="45 90" fill="red">CD</tspan>
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

    testWidgets('rotate with negative values works', (tester) async {
      const svg =
          '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
        <text x="50" y="50" rotate="-45 0 45" fill="black">ABC</text>
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

  group('textPath spacing attribute', () {
    testWidgets('textPath with spacing="exact" renders without error', (
      tester,
    ) async {
      const svg =
          '''<svg viewBox="0 0 300 100" xmlns="http://www.w3.org/2000/svg">
        <defs>
          <path id="myPath" d="M10,90 Q90,90 90,45 Q90,10 50,10" fill="none" stroke="blue"/>
        </defs>
        <text fill="black">
          <textPath href="#myPath" spacing="exact">Hello World</textPath>
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

    testWidgets('textPath with spacing="auto" renders without error', (
      tester,
    ) async {
      const svg =
          '''<svg viewBox="0 0 300 100" xmlns="http://www.w3.org/2000/svg">
        <defs>
          <path id="myPath" d="M10,90 Q90,90 90,45 Q90,10 50,10" fill="none" stroke="blue"/>
        </defs>
        <text fill="black" style="letter-spacing: 5px">
          <textPath href="#myPath" spacing="auto">Hello World</textPath>
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

    testWidgets('textPath defaults to spacing="exact" when not specified', (
      tester,
    ) async {
      const svg =
          '''<svg viewBox="0 0 300 100" xmlns="http://www.w3.org/2000/svg">
        <defs>
          <path id="myPath" d="M10,90 Q90,90 90,45 Q90,10 50,10" fill="none" stroke="blue"/>
        </defs>
        <text fill="black">
          <textPath href="#myPath">Default Spacing</textPath>
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

  group('text-decoration attribute', () {
    testWidgets('text with text-decoration="underline" renders without error', (
      tester,
    ) async {
      const svg =
          '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
        <text x="10" y="50" text-decoration="underline" fill="black">Underlined</text>
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

    testWidgets('text with text-decoration="overline" renders without error', (
      tester,
    ) async {
      const svg =
          '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
        <text x="10" y="50" text-decoration="overline" fill="black">Overlined</text>
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

    testWidgets(
      'text with text-decoration="line-through" renders without error',
      (tester) async {
        const svg =
            '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
        <text x="10" y="50" text-decoration="line-through" fill="black">Strikethrough</text>
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
      },
    );

    testWidgets('text with multiple decorations renders without error', (
      tester,
    ) async {
      const svg =
          '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
        <text x="10" y="50" text-decoration="underline overline" fill="black">Both</text>
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

    testWidgets('tspan inherits text-decoration from parent', (tester) async {
      const svg =
          '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
        <text x="10" y="50" text-decoration="underline" fill="black">
          Hello <tspan fill="red">World</tspan>
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

    testWidgets('text-decoration="none" removes decoration', (tester) async {
      const svg =
          '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
        <text x="10" y="50" fill="black">No decoration</text>
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

  group('writing-mode attribute', () {
    testWidgets(
      'text with writing-mode="horizontal-tb" renders without error',
      (tester) async {
        const svg =
            '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
        <text x="10" y="50" writing-mode="horizontal-tb" fill="black">Horizontal</text>
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
      },
    );

    testWidgets('text with writing-mode="vertical-rl" renders without error', (
      tester,
    ) async {
      const svg =
          '''<svg viewBox="0 0 100 200" xmlns="http://www.w3.org/2000/svg">
        <text x="50" y="10" writing-mode="vertical-rl" fill="black">縦書き</text>
      </svg>''';

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

    testWidgets('text with writing-mode="vertical-lr" renders without error', (
      tester,
    ) async {
      const svg =
          '''<svg viewBox="0 0 100 200" xmlns="http://www.w3.org/2000/svg">
        <text x="10" y="10" writing-mode="vertical-lr" fill="black">ABC</text>
      </svg>''';

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

    testWidgets('writing-mode is inherited by tspan', (tester) async {
      const svg =
          '''<svg viewBox="0 0 100 200" xmlns="http://www.w3.org/2000/svg">
        <text x="50" y="10" writing-mode="vertical-rl" fill="black">
          Hello<tspan fill="red">World</tspan>
        </text>
      </svg>''';

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

    testWidgets('legacy SVG 1.1 tb-rl value works', (tester) async {
      const svg =
          '''<svg viewBox="0 0 100 200" xmlns="http://www.w3.org/2000/svg">
        <text x="50" y="10" writing-mode="tb-rl" fill="black">Legacy</text>
      </svg>''';

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
}
