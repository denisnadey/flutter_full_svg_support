import 'package:flutter_svg/src/animation/animated_svg_picture.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('hanging-punctuation CSS property', () {
    testWidgets('hanging-punctuation: none (default)', (tester) async {
      const svg = '''
        <svg viewBox="0 0 150 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="14" style="hanging-punctuation: none">"Quote"</text>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 150, height: 50),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('hanging-punctuation: first', (tester) async {
      const svg = '''
        <svg viewBox="0 0 150 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="14" style="hanging-punctuation: first">"Leading quote"</text>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 150, height: 50),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('hanging-punctuation: last', (tester) async {
      const svg = '''
        <svg viewBox="0 0 150 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="14" style="hanging-punctuation: last">Trailing quote"</text>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 150, height: 50),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('hanging-punctuation: first last', (tester) async {
      const svg = '''
        <svg viewBox="0 0 150 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="14" style="hanging-punctuation: first last">"Both ends"</text>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 150, height: 50),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('hanging-punctuation: force-end', (tester) async {
      const svg = '''
        <svg viewBox="0 0 150 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="14" style="hanging-punctuation: force-end">Text.</text>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 150, height: 50),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('hanging-punctuation: allow-end', (tester) async {
      const svg = '''
        <svg viewBox="0 0 150 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="14" style="hanging-punctuation: allow-end">Allow,</text>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 150, height: 50),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('hanging-punctuation inherited from group', (tester) async {
      const svg = '''
        <svg viewBox="0 0 150 80" xmlns="http://www.w3.org/2000/svg">
          <g style="hanging-punctuation: first">
            <text x="10" y="25" font-size="14">"Quote1"</text>
            <text x="10" y="50" font-size="14">"Quote2"</text>
          </g>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 150, height: 80),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });
}
