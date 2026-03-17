import 'package:flutter_svg/src/animation/animated_svg_picture.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('vector-effect attribute', () {
    testWidgets('non-scaling-stroke keeps stroke width constant under scale', (
      tester,
    ) async {
      // Without non-scaling-stroke, the stroke appears 2x as thick when scaled 2x
      // With non-scaling-stroke, stroke width stays constant
      const svg = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <g transform="scale(2)">
            <rect x="5" y="5" width="40" height="40" 
                  fill="none" stroke="blue" stroke-width="2"
                  vector-effect="non-scaling-stroke"/>
          </g>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 100, height: 100),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('non-scaling-stroke works with nested transforms', (
      tester,
    ) async {
      const svg = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <g transform="scale(2)">
            <g transform="scale(1.5)">
              <circle cx="20" cy="20" r="15" 
                      fill="none" stroke="red" stroke-width="1"
                      vector-effect="non-scaling-stroke"/>
            </g>
          </g>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 100, height: 100),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('non-scaling-stroke works on path elements', (tester) async {
      const svg = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <g transform="scale(3)">
            <path d="M5,5 L30,5 L30,30 Z" 
                  fill="none" stroke="green" stroke-width="1"
                  vector-effect="non-scaling-stroke"/>
          </g>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 100, height: 100),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('non-scaling-stroke works on ellipse', (tester) async {
      const svg = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <g transform="scale(2, 3)">
            <ellipse cx="25" cy="15" rx="20" ry="10" 
                     fill="none" stroke="purple" stroke-width="2"
                     vector-effect="non-scaling-stroke"/>
          </g>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 100, height: 100),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('non-scaling-stroke works on polygon', (tester) async {
      const svg = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <g transform="scale(2)">
            <polygon points="25,5 45,45 5,45" 
                     fill="none" stroke="orange" stroke-width="1"
                     vector-effect="non-scaling-stroke"/>
          </g>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 100, height: 100),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('non-scaling-stroke works on polyline', (tester) async {
      const svg = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <g transform="scale(2)">
            <polyline points="5,5 25,25 45,5" 
                      fill="none" stroke="cyan" stroke-width="1"
                      vector-effect="non-scaling-stroke"/>
          </g>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 100, height: 100),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('non-scaling-stroke works on line', (tester) async {
      const svg = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <g transform="scale(2)">
            <line x1="5" y1="5" x2="45" y2="45" 
                  stroke="magenta" stroke-width="2"
                  vector-effect="non-scaling-stroke"/>
          </g>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 100, height: 100),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('non-scaling-stroke is inherited from parent', (tester) async {
      const svg = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <g transform="scale(2)" vector-effect="non-scaling-stroke">
            <rect x="5" y="5" width="40" height="40" 
                  fill="none" stroke="blue" stroke-width="1"/>
          </g>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 100, height: 100),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('non-scaling-stroke works with rotation transform', (
      tester,
    ) async {
      const svg = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <g transform="rotate(45, 50, 50) scale(2)">
            <rect x="25" y="25" width="50" height="50" 
                  fill="none" stroke="teal" stroke-width="2"
                  vector-effect="non-scaling-stroke"/>
          </g>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 100, height: 100),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('default (no vector-effect) scales stroke normally', (
      tester,
    ) async {
      // Without vector-effect, stroke scales with transform
      const svg = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <g transform="scale(2)">
            <rect x="5" y="5" width="40" height="40" 
                  fill="none" stroke="navy" stroke-width="2"/>
          </g>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 100, height: 100),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('non-scaling-stroke with fill and stroke', (tester) async {
      const svg = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <g transform="scale(2)">
            <rect x="5" y="5" width="40" height="40" 
                  fill="yellow" stroke="black" stroke-width="2"
                  vector-effect="non-scaling-stroke"/>
          </g>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 100, height: 100),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });
}
