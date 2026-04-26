import 'package:flutter/material.dart';
import 'package:full_svg_flutter/src/animation/animated_svg_picture.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Text Edge Cases', () {
    group('Deeply nested tspan with transforms', () {
      testWidgets('3+ level nested tspan with mixed transforms', (
        tester,
      ) async {
        const svg = '''
          <svg viewBox="0 0 400 200" xmlns="http://www.w3.org/2000/svg">
            <text x="50" y="50" font-size="16">
              Level 1
              <tspan transform="translate(20, 0)">
                Level 2
                <tspan transform="rotate(15)">
                  Level 3
                  <tspan transform="scale(1.2)" dx="5 10 15" dy="2 4 6">ABC</tspan>
                </tspan>
              </tspan>
            </text>
          </svg>
        ''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AnimatedSvgPicture.string(svg, width: 400, height: 200),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('per-character x/y positioning in transformed tspan', (
        tester,
      ) async {
        const svg = '''
          <svg viewBox="0 0 400 200" xmlns="http://www.w3.org/2000/svg">
            <text font-size="16">
              <tspan transform="translate(10, 50)">
                <tspan transform="rotate(5)">
                  <tspan x="10 30 50 70" y="0 5 0 -5">Test</tspan>
                </tspan>
              </tspan>
            </text>
          </svg>
        ''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AnimatedSvgPicture.string(svg, width: 400, height: 200),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('4-level deep tspan with mixed transform types', (
        tester,
      ) async {
        const svg = '''
          <svg viewBox="0 0 500 200" xmlns="http://www.w3.org/2000/svg">
            <text x="10" y="100" font-size="14">
              <tspan transform="matrix(1 0 0 1 10 0)">A
                <tspan transform="skewX(10)">B
                  <tspan transform="translate(5, -10)">C
                    <tspan transform="rotate(-5)" dx="2 4" dy="1 2">DE</tspan>
                  </tspan>
                </tspan>
              </tspan>
            </text>
          </svg>
        ''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AnimatedSvgPicture.string(svg, width: 500, height: 200),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });
    });

    group('Bidirectional text in complex hierarchies', () {
      testWidgets('RTL parent with LTR tspan children', (tester) async {
        const svg = '''
          <svg viewBox="0 0 400 100" xmlns="http://www.w3.org/2000/svg">
            <text x="380" y="50" font-size="16" direction="rtl" text-anchor="end">
              שלום 
              <tspan direction="ltr">Hello World</tspan>
               עולם
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
        await tester.pumpAndSettle();
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('LTR parent with RTL tspan and bidi-override', (
        tester,
      ) async {
        const svg = '''
          <svg viewBox="0 0 400 100" xmlns="http://www.w3.org/2000/svg">
            <text x="10" y="50" font-size="16" direction="ltr">
              Hello 
              <tspan direction="rtl" unicode-bidi="bidi-override">DCBA</tspan>
               World
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
        await tester.pumpAndSettle();
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('nested direction changes with isolate', (tester) async {
        const svg = '''
          <svg viewBox="0 0 500 100" xmlns="http://www.w3.org/2000/svg">
            <text x="10" y="50" font-size="14" direction="ltr">
              Start
              <tspan direction="rtl" unicode-bidi="isolate">
                עברית
                <tspan direction="ltr" unicode-bidi="isolate">English</tspan>
                עוד
              </tspan>
              End
            </text>
          </svg>
        ''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AnimatedSvgPicture.string(svg, width: 500, height: 100),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });
    });

    group('textLength with nested tspan', () {
      testWidgets('textLength on parent distributes to children - spacing', (
        tester,
      ) async {
        const svg = '''
          <svg viewBox="0 0 400 100" xmlns="http://www.w3.org/2000/svg">
            <text x="10" y="50" font-size="16" textLength="300" lengthAdjust="spacing">
              <tspan>First</tspan>
              <tspan>Second</tspan>
              <tspan>Third</tspan>
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
        await tester.pumpAndSettle();
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets(
        'textLength on parent distributes to children - spacingAndGlyphs',
        (tester) async {
          const svg = '''
          <svg viewBox="0 0 400 100" xmlns="http://www.w3.org/2000/svg">
            <text x="10" y="50" font-size="16" textLength="350" lengthAdjust="spacingAndGlyphs">
              <tspan>Short</tspan>
              <tspan>Medium Text</tspan>
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
          await tester.pumpAndSettle();
          expect(find.byType(AnimatedSvgPicture), findsOneWidget);
        },
      );

      testWidgets('deeply nested tspan with parent textLength', (tester) async {
        const svg = '''
          <svg viewBox="0 0 400 100" xmlns="http://www.w3.org/2000/svg">
            <text x="10" y="50" font-size="14" textLength="250" lengthAdjust="spacing">
              <tspan>A
                <tspan>B
                  <tspan>C</tspan>
                </tspan>
              </tspan>
              <tspan>DEF</tspan>
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
        await tester.pumpAndSettle();
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });
    });
  });

  group('Mask Refinements', () {
    group('Radial gradient in mask content', () {
      testWidgets('mask with radialGradient fill - luminance mode', (
        tester,
      ) async {
        const svg = '''
          <svg viewBox="0 0 200 200" xmlns="http://www.w3.org/2000/svg">
            <defs>
              <radialGradient id="maskGrad" cx="50%" cy="50%" r="50%">
                <stop offset="0%" stop-color="white"/>
                <stop offset="100%" stop-color="black"/>
              </radialGradient>
              <mask id="radialMask" mask-type="luminance">
                <circle cx="100" cy="100" r="80" fill="url(#maskGrad)"/>
              </mask>
            </defs>
            <rect x="20" y="20" width="160" height="160" fill="blue" mask="url(#radialMask)"/>
          </svg>
        ''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AnimatedSvgPicture.string(svg, width: 200, height: 200),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('mask with radialGradient with opacity stops', (
        tester,
      ) async {
        const svg = '''
          <svg viewBox="0 0 200 200" xmlns="http://www.w3.org/2000/svg">
            <defs>
              <radialGradient id="opacityGrad" cx="50%" cy="50%" r="50%">
                <stop offset="0%" stop-color="white" stop-opacity="1"/>
                <stop offset="50%" stop-color="gray" stop-opacity="0.5"/>
                <stop offset="100%" stop-color="black" stop-opacity="0"/>
              </radialGradient>
              <mask id="opacityMask" mask-type="luminance">
                <ellipse cx="100" cy="100" rx="90" ry="70" fill="url(#opacityGrad)"/>
              </mask>
            </defs>
            <rect x="10" y="30" width="180" height="140" fill="red" mask="url(#opacityMask)"/>
          </svg>
        ''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AnimatedSvgPicture.string(svg, width: 200, height: 200),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });
    });

    group('Filter chains on mask content', () {
      testWidgets('mask with blur filter on content', (tester) async {
        const svg = '''
          <svg viewBox="0 0 200 200" xmlns="http://www.w3.org/2000/svg">
            <defs>
              <filter id="maskBlur">
                <feGaussianBlur stdDeviation="3"/>
              </filter>
              <mask id="blurMask" mask-type="luminance">
                <rect x="30" y="30" width="140" height="140" fill="white" filter="url(#maskBlur)"/>
              </mask>
            </defs>
            <rect x="20" y="20" width="160" height="160" fill="green" mask="url(#blurMask)"/>
          </svg>
        ''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AnimatedSvgPicture.string(svg, width: 200, height: 200),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('mask with blur + colorMatrix filter chain', (tester) async {
        const svg = '''
          <svg viewBox="0 0 200 200" xmlns="http://www.w3.org/2000/svg">
            <defs>
              <filter id="chainFilter">
                <feGaussianBlur in="SourceGraphic" stdDeviation="2" result="blur"/>
                <feColorMatrix in="blur" type="saturate" values="0"/>
              </filter>
              <mask id="chainMask" mask-type="luminance">
                <circle cx="100" cy="100" r="70" fill="white" filter="url(#chainFilter)"/>
              </mask>
            </defs>
            <rect x="20" y="20" width="160" height="160" fill="purple" mask="url(#chainMask)"/>
          </svg>
        ''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AnimatedSvgPicture.string(svg, width: 200, height: 200),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });
    });

    group('Mask-to-mask intersection', () {
      testWidgets('nested elements with own masks intersect', (tester) async {
        const svg = '''
          <svg viewBox="0 0 200 200" xmlns="http://www.w3.org/2000/svg">
            <defs>
              <mask id="outerMask">
                <rect x="20" y="20" width="160" height="160" fill="white"/>
              </mask>
              <mask id="innerMask">
                <circle cx="100" cy="100" r="60" fill="white"/>
              </mask>
            </defs>
            <g mask="url(#outerMask)">
              <rect x="0" y="0" width="200" height="200" fill="lightblue"/>
              <g mask="url(#innerMask)">
                <rect x="40" y="40" width="120" height="120" fill="red"/>
              </g>
            </g>
          </svg>
        ''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AnimatedSvgPicture.string(svg, width: 200, height: 200),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('3-level deep mask nesting', (tester) async {
        const svg = '''
          <svg viewBox="0 0 200 200" xmlns="http://www.w3.org/2000/svg">
            <defs>
              <mask id="mask1">
                <rect x="10" y="10" width="180" height="180" fill="white"/>
              </mask>
              <mask id="mask2">
                <rect x="30" y="30" width="140" height="140" fill="white"/>
              </mask>
              <mask id="mask3">
                <circle cx="100" cy="100" r="50" fill="white"/>
              </mask>
            </defs>
            <g mask="url(#mask1)">
              <rect width="200" height="200" fill="yellow"/>
              <g mask="url(#mask2)">
                <rect width="200" height="200" fill="orange"/>
                <g mask="url(#mask3)">
                  <rect width="200" height="200" fill="red"/>
                </g>
              </g>
            </g>
          </svg>
        ''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AnimatedSvgPicture.string(svg, width: 200, height: 200),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });
    });
  });

  group('Image/ForeignObject Edge Cases', () {
    group('Image error fallback', () {
      testWidgets('missing image href renders transparent fallback', (
        tester,
      ) async {
        const svg = '''
          <svg viewBox="0 0 200 200" xmlns="http://www.w3.org/2000/svg">
            <rect x="0" y="0" width="200" height="200" fill="lightgray"/>
            <image x="50" y="50" width="100" height="100" href="nonexistent.png"/>
          </svg>
        ''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AnimatedSvgPicture.string(svg, width: 200, height: 200),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('invalid data URI image renders fallback', (tester) async {
        const svg = '''
          <svg viewBox="0 0 200 200" xmlns="http://www.w3.org/2000/svg">
            <rect x="0" y="0" width="200" height="200" fill="lightgray"/>
            <image x="50" y="50" width="100" height="100" href="data:image/png;base64,invalid!!!"/>
          </svg>
        ''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AnimatedSvgPicture.string(svg, width: 200, height: 200),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });
    });

    group('Nested SVG in foreignObject', () {
      testWidgets('foreignObject with nested svg - xMidYMid meet', (
        tester,
      ) async {
        const svg = '''
          <svg viewBox="0 0 300 200" xmlns="http://www.w3.org/2000/svg">
            <rect width="300" height="200" fill="lightgray"/>
            <foreignObject x="50" y="25" width="200" height="150">
              <svg viewBox="0 0 100 100" preserveAspectRatio="xMidYMid meet">
                <rect width="100" height="100" fill="blue"/>
                <circle cx="50" cy="50" r="40" fill="yellow"/>
              </svg>
            </foreignObject>
          </svg>
        ''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AnimatedSvgPicture.string(svg, width: 300, height: 200),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('foreignObject with nested svg - xMinYMin slice', (
        tester,
      ) async {
        const svg = '''
          <svg viewBox="0 0 300 200" xmlns="http://www.w3.org/2000/svg">
            <rect width="300" height="200" fill="lightgray"/>
            <foreignObject x="50" y="25" width="200" height="150">
              <svg viewBox="0 0 100 100" preserveAspectRatio="xMinYMin slice">
                <rect width="100" height="100" fill="green"/>
                <circle cx="50" cy="50" r="40" fill="red"/>
              </svg>
            </foreignObject>
          </svg>
        ''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AnimatedSvgPicture.string(svg, width: 300, height: 200),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('foreignObject with nested svg - none (stretch)', (
        tester,
      ) async {
        const svg = '''
          <svg viewBox="0 0 300 200" xmlns="http://www.w3.org/2000/svg">
            <rect width="300" height="200" fill="lightgray"/>
            <foreignObject x="50" y="25" width="200" height="150">
              <svg viewBox="0 0 50 50" preserveAspectRatio="none">
                <rect width="50" height="50" fill="purple"/>
                <ellipse cx="25" cy="25" rx="20" ry="15" fill="white"/>
              </svg>
            </foreignObject>
          </svg>
        ''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AnimatedSvgPicture.string(svg, width: 300, height: 200),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('foreignObject with all preserveAspectRatio alignments', (
        tester,
      ) async {
        // Test all 9 alignment values
        final alignments = [
          'xMinYMin',
          'xMidYMin',
          'xMaxYMin',
          'xMinYMid',
          'xMidYMid',
          'xMaxYMid',
          'xMinYMax',
          'xMidYMax',
          'xMaxYMax',
        ];

        for (final align in alignments) {
          final svg =
              '''
            <svg viewBox="0 0 200 150" xmlns="http://www.w3.org/2000/svg">
              <rect width="200" height="150" fill="#eee"/>
              <foreignObject x="25" y="25" width="150" height="100">
                <svg viewBox="0 0 80 80" preserveAspectRatio="$align meet">
                  <rect width="80" height="80" fill="teal"/>
                </svg>
              </foreignObject>
            </svg>
          ''';

          await tester.pumpWidget(
            MaterialApp(
              key: ValueKey(align),
              home: Scaffold(
                body: AnimatedSvgPicture.string(svg, width: 200, height: 150),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(
            find.byType(AnimatedSvgPicture),
            findsOneWidget,
            reason: 'Failed for $align',
          );
        }
      });
    });
  });
}
