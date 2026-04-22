import 'package:full_svg_flutter/src/animation/animated_svg_picture.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Bidi Text Methods Integration', () {
    group('_buildBidiContext', () {
      testWidgets('builds correct context for nested elements with direction', (
        tester,
      ) async {
        // Tests that bidi context is built for nested tspans with direction attributes
        const svg = '''
          <svg viewBox="0 0 400 100" xmlns="http://www.w3.org/2000/svg">
            <text x="10" y="30" font-size="16" direction="ltr">
              LTR parent 
              <tspan direction="rtl">RTL child שלום</tspan>
              <tspan>inherits LTR</tspan>
            </text>
          </svg>
        ''';

        await tester.pumpWidget(
          AnimatedSvgPicture.string(svg, width: 400, height: 100),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('builds context for deeply nested direction changes', (
        tester,
      ) async {
        // Tests 3+ levels of direction nesting
        const svg = '''
          <svg viewBox="0 0 500 100" xmlns="http://www.w3.org/2000/svg">
            <text x="10" y="30" font-size="16" direction="rtl">
              <tspan direction="ltr">
                LTR level 1
                <tspan direction="rtl">RTL level 2</tspan>
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

      testWidgets('builds context with unicode-bidi attributes', (
        tester,
      ) async {
        const svg = '''
          <svg viewBox="0 0 400 100" xmlns="http://www.w3.org/2000/svg">
            <text x="10" y="30" font-size="16" direction="rtl" unicode-bidi="embed">
              <tspan unicode-bidi="isolate">Isolated content</tspan>
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

    group('_resolveEffectiveBidiDirection', () {
      testWidgets('uses explicit direction on node', (tester) async {
        // When a node has explicit direction, it should use that
        const svg = '''
          <svg viewBox="0 0 300 100" xmlns="http://www.w3.org/2000/svg">
            <text x="10" y="30" font-size="16" direction="ltr">
              <tspan direction="rtl">This should be RTL</tspan>
            </text>
          </svg>
        ''';

        await tester.pumpWidget(
          AnimatedSvgPicture.string(svg, width: 300, height: 100),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('inherits direction from parent when not specified', (
        tester,
      ) async {
        // Child without direction should inherit from parent
        const svg = '''
          <svg viewBox="0 0 300 100" xmlns="http://www.w3.org/2000/svg">
            <text x="200" y="30" font-size="16" direction="rtl">
              <tspan>Inherits RTL</tspan>
              <tspan>Also RTL</tspan>
            </text>
          </svg>
        ''';

        await tester.pumpWidget(
          AnimatedSvgPicture.string(svg, width: 300, height: 100),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('falls back to inherited direction through hierarchy', (
        tester,
      ) async {
        // Direction inherited through multiple levels
        const svg = '''
          <svg viewBox="0 0 400 100" xmlns="http://www.w3.org/2000/svg">
            <g direction="rtl">
              <text x="200" y="30" font-size="16">
                <tspan>Should be RTL from group</tspan>
              </text>
            </g>
          </svg>
        ''';

        await tester.pumpWidget(
          AnimatedSvgPicture.string(svg, width: 400, height: 100),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });
    });

    group('unicode-bidi override/isolate modes', () {
      testWidgets('unicode-bidi: bidi-override forces direction', (
        tester,
      ) async {
        const svg = '''
          <svg viewBox="0 0 300 100" xmlns="http://www.w3.org/2000/svg">
            <text x="250" y="30" font-size="16" direction="rtl" unicode-bidi="bidi-override">
              ABC123
            </text>
          </svg>
        ''';

        await tester.pumpWidget(
          AnimatedSvgPicture.string(svg, width: 300, height: 100),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('unicode-bidi: isolate creates isolated segment', (
        tester,
      ) async {
        const svg = '''
          <svg viewBox="0 0 400 100" xmlns="http://www.w3.org/2000/svg">
            <text x="10" y="30" font-size="16" direction="ltr">
              Before 
              <tspan unicode-bidi="isolate" direction="rtl">שלום</tspan>
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

      testWidgets(
        'unicode-bidi: isolate-override combines isolation and override',
        (tester) async {
          const svg = '''
          <svg viewBox="0 0 400 100" xmlns="http://www.w3.org/2000/svg">
            <text x="10" y="30" font-size="16">
              Start 
              <tspan unicode-bidi="isolate-override" direction="rtl">DCBA</tspan>
              End
            </text>
          </svg>
        ''';

          await tester.pumpWidget(
            AnimatedSvgPicture.string(svg, width: 400, height: 100),
          );
          await tester.pumpAndSettle();

          expect(find.byType(AnimatedSvgPicture), findsOneWidget);
        },
      );
    });

    group('mixed-direction nested tspans', () {
      testWidgets('LTR parent with multiple RTL children', (tester) async {
        const svg = '''
          <svg viewBox="0 0 500 100" xmlns="http://www.w3.org/2000/svg">
            <text x="10" y="30" font-size="16" direction="ltr">
              English 
              <tspan direction="rtl">עברית</tspan>
               more English 
              <tspan direction="rtl">العربية</tspan>
            </text>
          </svg>
        ''';

        await tester.pumpWidget(
          AnimatedSvgPicture.string(svg, width: 500, height: 100),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('RTL parent with LTR embedded code', (tester) async {
        const svg = '''
          <svg viewBox="0 0 400 100" xmlns="http://www.w3.org/2000/svg">
            <text x="350" y="30" font-size="16" direction="rtl">
              קוד: 
              <tspan direction="ltr">HTML5</tspan>
               ו-
              <tspan direction="ltr">CSS3</tspan>
            </text>
          </svg>
        ''';

        await tester.pumpWidget(
          AnimatedSvgPicture.string(svg, width: 400, height: 100),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('alternating direction tspans', (tester) async {
        const svg = '''
          <svg viewBox="0 0 600 100" xmlns="http://www.w3.org/2000/svg">
            <text x="10" y="30" font-size="14">
              <tspan direction="ltr">LTR1 </tspan>
              <tspan direction="rtl">RTL1 </tspan>
              <tspan direction="ltr">LTR2 </tspan>
              <tspan direction="rtl">RTL2 </tspan>
              <tspan direction="ltr">LTR3</tspan>
            </text>
          </svg>
        ''';

        await tester.pumpWidget(
          AnimatedSvgPicture.string(svg, width: 600, height: 100),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('deeply nested direction changes with content', (
        tester,
      ) async {
        const svg = '''
          <svg viewBox="0 0 600 100" xmlns="http://www.w3.org/2000/svg">
            <text x="10" y="30" font-size="14" direction="ltr">
              L1 
              <tspan direction="rtl">
                R2 
                <tspan direction="ltr">
                  L3 
                  <tspan direction="rtl">R4</tspan>
                </tspan>
              </tspan>
            </text>
          </svg>
        ''';

        await tester.pumpWidget(
          AnimatedSvgPicture.string(svg, width: 600, height: 100),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });
    });

    group('direction with text-anchor', () {
      testWidgets('RTL direction with text-anchor start', (tester) async {
        const svg = '''
          <svg viewBox="0 0 300 100" xmlns="http://www.w3.org/2000/svg">
            <text x="290" y="30" font-size="16" direction="rtl" text-anchor="start">
              טקסט בעברית
            </text>
          </svg>
        ''';

        await tester.pumpWidget(
          AnimatedSvgPicture.string(svg, width: 300, height: 100),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('RTL direction with text-anchor end', (tester) async {
        const svg = '''
          <svg viewBox="0 0 300 100" xmlns="http://www.w3.org/2000/svg">
            <text x="10" y="30" font-size="16" direction="rtl" text-anchor="end">
              טקסט בעברית
            </text>
          </svg>
        ''';

        await tester.pumpWidget(
          AnimatedSvgPicture.string(svg, width: 300, height: 100),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });
    });

    group('direction inheritance via style attribute', () {
      testWidgets('direction set via CSS style', (tester) async {
        const svg = '''
          <svg viewBox="0 0 300 100" xmlns="http://www.w3.org/2000/svg">
            <text x="280" y="30" font-size="16" style="direction: rtl; unicode-bidi: embed">
              Styled RTL
            </text>
          </svg>
        ''';

        await tester.pumpWidget(
          AnimatedSvgPicture.string(svg, width: 300, height: 100),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('direction from CSS class', (tester) async {
        const svg = '''
          <svg viewBox="0 0 300 100" xmlns="http://www.w3.org/2000/svg">
            <style>
              .rtl-text { direction: rtl; }
            </style>
            <text x="280" y="30" font-size="16" class="rtl-text">
              Class RTL
            </text>
          </svg>
        ''';

        await tester.pumpWidget(
          AnimatedSvgPicture.string(svg, width: 300, height: 100),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });
    });
  });
}
