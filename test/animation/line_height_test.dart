import 'package:flutter_svg/src/animation/animated_svg_picture.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('line-height CSS property', () {
    testWidgets('line-height: normal (default)', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="16">Normal</text>
        </svg>
      ''';
      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg),
      );
      await tester.pump();
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('line-height: number (unitless)', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="16" style="line-height: 1.5">1.5x</text>
        </svg>
      ''';
      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg),
      );
      await tester.pump();
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('line-height: px value', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="16" style="line-height: 24px">24px</text>
        </svg>
      ''';
      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg),
      );
      await tester.pump();
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('line-height: em value', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="16" style="line-height: 1.5em">1.5em</text>
        </svg>
      ''';
      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg),
      );
      await tester.pump();
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('line-height: percentage', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="16" style="line-height: 150%">150%</text>
        </svg>
      ''';
      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg),
      );
      await tester.pump();
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('line-height: inheritance', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
          <g style="line-height: 2">
            <text x="10" y="30" font-size="16">Inherited</text>
          </g>
        </svg>
      ''';
      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg),
      );
      await tester.pump();
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });
}
