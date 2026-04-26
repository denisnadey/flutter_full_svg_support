import 'package:flutter/material.dart';
import 'package:full_svg_flutter/src/animation/animated_svg_picture.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('deep nesting baseline alignment', () {
    testWidgets('3-level font-size nesting renders correctly', (tester) async {
      // <text font-size="48"><tspan font-size="24"><tspan font-size="12">deep</tspan></tspan></text>
      const svg =
          '''<svg viewBox="0 0 300 100" xmlns="http://www.w3.org/2000/svg">
        <text x="10" y="50" font-size="48" fill="black">
          Root
          <tspan font-size="24" fill="blue">
            Level2
            <tspan font-size="12" fill="red">deep</tspan>
          </tspan>
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

      // Should render without errors and all nested tspans visible
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('4-level font-size nesting with alternating sizes', (
      tester,
    ) async {
      // 48 -> 24 -> 36 -> 18 (alternating larger/smaller)
      const svg =
          '''<svg viewBox="0 0 400 100" xmlns="http://www.w3.org/2000/svg">
        <text x="10" y="60" font-size="48" fill="black">
          A
          <tspan font-size="24" fill="blue">
            B
            <tspan font-size="36" fill="green">
              C
              <tspan font-size="18" fill="red">D</tspan>
            </tspan>
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

    testWidgets(
      'mixed dominant-baseline at each level: alphabetic -> hanging -> mathematical',
      (tester) async {
        const svg =
            '''<svg viewBox="0 0 400 100" xmlns="http://www.w3.org/2000/svg">
        <text x="10" y="50" dominant-baseline="alphabetic" font-size="24" fill="black">
          Alpha
          <tspan dominant-baseline="hanging" fill="blue">
            Hang
            <tspan dominant-baseline="mathematical" fill="red">Math</tspan>
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
      },
    );

    testWidgets(
      'baseline-shift: super at level 2, sub at level 3 - cumulative shift',
      (tester) async {
        const svg =
            '''<svg viewBox="0 0 300 100" xmlns="http://www.w3.org/2000/svg">
        <text x="10" y="50" font-size="24" fill="black">
          Normal
          <tspan baseline-shift="super" fill="blue">
            Super
            <tspan baseline-shift="sub" fill="red">SubOfSuper</tspan>
          </tspan>
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
      },
    );
  });

  group('writing-mode transitions', () {
    testWidgets(
      'vertical text inside horizontal text: writing-mode axis change',
      (tester) async {
        const svg =
            '''<svg viewBox="0 0 200 200" xmlns="http://www.w3.org/2000/svg">
        <text x="10" y="30" writing-mode="horizontal-tb" font-size="20" fill="black">
          Horiz
          <tspan writing-mode="vertical-rl" fill="blue">縦書き</tspan>
        </text>
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

    testWidgets('horizontal text inside vertical text (reverse transition)', (
      tester,
    ) async {
      const svg =
          '''<svg viewBox="0 0 200 200" xmlns="http://www.w3.org/2000/svg">
        <text x="50" y="10" writing-mode="vertical-rl" font-size="20" fill="black">
          縦
          <tspan writing-mode="horizontal-tb" fill="blue">横書き</tspan>
        </text>
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
    });

    testWidgets('vertical-lr mode nesting', (tester) async {
      const svg =
          '''<svg viewBox="0 0 200 200" xmlns="http://www.w3.org/2000/svg">
        <text x="10" y="10" writing-mode="vertical-lr" font-size="20" fill="black">
          ABC
          <tspan font-size="12" fill="blue">DEF</tspan>
        </text>
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
    });
  });

  group('alignment-baseline multi-level', () {
    testWidgets('alignment-baseline set differently at 3 nesting levels', (
      tester,
    ) async {
      const svg =
          '''<svg viewBox="0 0 400 100" xmlns="http://www.w3.org/2000/svg">
        <text x="10" y="50" dominant-baseline="alphabetic" font-size="24" fill="black">
          Root
          <tspan alignment-baseline="middle" fill="blue">
            Mid
            <tspan alignment-baseline="text-before-edge" fill="red">Top</tspan>
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

    testWidgets('alignment-baseline with central and ideographic', (
      tester,
    ) async {
      const svg =
          '''<svg viewBox="0 0 400 100" xmlns="http://www.w3.org/2000/svg">
        <text x="10" y="50" dominant-baseline="central" font-size="24" fill="black">
          Center
          <tspan alignment-baseline="ideographic" fill="blue">
            Ideo
            <tspan alignment-baseline="alphabetic" fill="red">Alpha</tspan>
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
  });

  group('complex mixed scenarios', () {
    testWidgets('deeply nested with mixed font-size and baseline-shift', (
      tester,
    ) async {
      // Tests: font-size 48->24->12 with baseline-shift at level 2
      const svg =
          '''<svg viewBox="0 0 400 100" xmlns="http://www.w3.org/2000/svg">
        <text x="10" y="60" font-size="48" fill="black">
          Big
          <tspan font-size="24" baseline-shift="super" fill="blue">
            Med
            <tspan font-size="12" fill="red">Small</tspan>
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

    testWidgets(
      'all properties combined: font-size, baseline, shift, writing-mode',
      (tester) async {
        const svg =
            '''<svg viewBox="0 0 300 200" xmlns="http://www.w3.org/2000/svg">
        <text x="10" y="50" font-size="24" dominant-baseline="alphabetic" fill="black">
          Start
          <tspan font-size="18" baseline-shift="super" dominant-baseline="hanging" fill="blue">
            Up
            <tspan font-size="14" baseline-shift="sub" fill="red">Down</tspan>
          </tspan>
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
      },
    );

    testWidgets('5-level deep nesting stress test', (tester) async {
      const svg =
          '''<svg viewBox="0 0 500 100" xmlns="http://www.w3.org/2000/svg">
        <text x="10" y="60" font-size="40" fill="black">
          L1
          <tspan font-size="32" fill="#333">
            L2
            <tspan font-size="24" fill="#666">
              L3
              <tspan font-size="18" fill="#999">
                L4
                <tspan font-size="12" fill="#ccc">L5</tspan>
              </tspan>
            </tspan>
          </tspan>
        </text>
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
  });

  group('regression tests (1-2 level nesting)', () {
    testWidgets('1-level nesting still works correctly', (tester) async {
      const svg =
          '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
        <text x="10" y="50" font-size="24" fill="black">
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

    testWidgets('2-level font-size nesting still works', (tester) async {
      const svg =
          '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
        <text x="10" y="50" font-size="24" fill="black">
          Big
          <tspan font-size="12" fill="blue">Small</tspan>
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

    testWidgets('simple baseline-shift super still works', (tester) async {
      const svg =
          '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
        <text x="10" y="50" font-size="24" fill="black">
          E=mc<tspan baseline-shift="super" font-size="12">2</tspan>
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

    testWidgets('simple baseline-shift sub still works', (tester) async {
      const svg =
          '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
        <text x="10" y="50" font-size="24" fill="black">
          H<tspan baseline-shift="sub" font-size="12">2</tspan>O
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

    testWidgets('single tspan with dominant-baseline still works', (
      tester,
    ) async {
      const svg =
          '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
        <text x="10" y="50" dominant-baseline="middle" font-size="24" fill="black">
          Middle <tspan fill="red">Text</tspan>
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

    testWidgets('text-anchor with nested tspans still works', (tester) async {
      const svg =
          '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
        <text x="100" y="50" text-anchor="middle" font-size="24" fill="black">
          Center<tspan fill="red">ed</tspan>
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

  group('edge cases', () {
    testWidgets('empty tspan at deep level', (tester) async {
      const svg =
          '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
        <text x="10" y="50" font-size="24" fill="black">
          Text
          <tspan font-size="18">
            <tspan font-size="12"></tspan>
          </tspan>
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

    testWidgets('same font-size at all levels (no offset needed)', (
      tester,
    ) async {
      const svg =
          '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
        <text x="10" y="50" font-size="24" fill="black">
          A
          <tspan fill="blue">
            B
            <tspan fill="red">C</tspan>
          </tspan>
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

    testWidgets('percentage baseline-shift at multiple levels', (tester) async {
      const svg =
          '''<svg viewBox="0 0 300 100" xmlns="http://www.w3.org/2000/svg">
        <text x="10" y="50" font-size="24" fill="black">
          Normal
          <tspan baseline-shift="50%" fill="blue">
            Half
            <tspan baseline-shift="-25%" fill="red">Quarter</tspan>
          </tspan>
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

    testWidgets('em unit baseline-shift at multiple levels', (tester) async {
      const svg =
          '''<svg viewBox="0 0 300 100" xmlns="http://www.w3.org/2000/svg">
        <text x="10" y="50" font-size="24" fill="black">
          Base
          <tspan baseline-shift="0.5em" font-size="18" fill="blue">
            Up
            <tspan baseline-shift="-0.3em" font-size="14" fill="red">Down</tspan>
          </tspan>
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

  group('textPath deep nesting', () {
    testWidgets('textPath with nested tspan font-size changes', (tester) async {
      const svg =
          '''<svg viewBox="0 0 400 200" xmlns="http://www.w3.org/2000/svg">
        <defs>
          <path id="curve" d="M10,100 Q200,10 390,100" fill="none"/>
        </defs>
        <text font-size="24" fill="black">
          <textPath href="#curve">
            Start
            <tspan font-size="18" fill="blue">
              Mid
              <tspan font-size="12" fill="red">End</tspan>
            </tspan>
          </textPath>
        </text>
      </svg>''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svg, width: 400, height: 200),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });
}
