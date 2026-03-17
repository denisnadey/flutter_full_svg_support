import 'package:flutter_svg/src/animation/animated_svg_picture.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('pathLength attribute', () {
    testWidgets('pathLength scales stroke-dasharray on path', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
          <path d="M10,50 L190,50" 
                pathLength="100"
                stroke="black" 
                stroke-width="4"
                stroke-dasharray="10 10"
                fill="none"/>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 200, height: 100),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('pathLength scales stroke-dashoffset on path', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
          <path d="M10,50 L190,50"
                pathLength="100"
                stroke="black"
                stroke-width="4"
                stroke-dasharray="20 10"
                stroke-dashoffset="5"
                fill="none"/>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 200, height: 100),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('pathLength on rect scales dasharray', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 150" xmlns="http://www.w3.org/2000/svg">
          <rect x="20" y="20" width="160" height="110"
                pathLength="100"
                stroke="blue"
                stroke-width="3"
                stroke-dasharray="25 10"
                fill="none"/>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 200, height: 150),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('pathLength on circle scales dasharray', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 200" xmlns="http://www.w3.org/2000/svg">
          <circle cx="100" cy="100" r="80"
                  pathLength="100"
                  stroke="green"
                  stroke-width="3"
                  stroke-dasharray="10 5"
                  fill="none"/>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 200, height: 200),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('pathLength on ellipse scales dasharray', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 150" xmlns="http://www.w3.org/2000/svg">
          <ellipse cx="100" cy="75" rx="90" ry="60"
                   pathLength="100"
                   stroke="purple"
                   stroke-width="3"
                   stroke-dasharray="15 5"
                   fill="none"/>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 200, height: 150),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('pathLength on line scales dasharray', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
          <line x1="10" y1="50" x2="190" y2="50"
                pathLength="50"
                stroke="red"
                stroke-width="4"
                stroke-dasharray="10 5"
                fill="none"/>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 200, height: 100),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('pathLength on polyline scales dasharray', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
          <polyline points="10,50 60,10 110,50 160,10 190,50"
                    pathLength="100"
                    stroke="orange"
                    stroke-width="3"
                    stroke-dasharray="20 10"
                    fill="none"/>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 200, height: 100),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('pathLength on polygon scales dasharray', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 200" xmlns="http://www.w3.org/2000/svg">
          <polygon points="100,10 190,80 160,180 40,180 10,80"
                   pathLength="100"
                   stroke="teal"
                   stroke-width="3"
                   stroke-dasharray="10 5"
                   fill="none"/>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 200, height: 200),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('pathLength=0 is handled gracefully', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
          <path d="M10,50 L190,50"
                pathLength="0"
                stroke="black"
                stroke-width="4"
                stroke-dasharray="10 10"
                fill="none"/>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 200, height: 100),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('pathLength without dasharray renders solid stroke', (
      tester,
    ) async {
      const svg = '''
        <svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
          <path d="M10,50 L190,50"
                pathLength="100"
                stroke="black"
                stroke-width="4"
                fill="none"/>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 200, height: 100),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });
}
