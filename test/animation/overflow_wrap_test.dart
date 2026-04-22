import 'package:full_svg_flutter/src/animation/animated_svg_picture.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('overflow-wrap CSS property', () {
    testWidgets('overflow-wrap: normal (default)', (tester) async {
      const svg = '''
        <svg viewBox="0 0 100 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="14" style="overflow-wrap: normal">NormalWrap</text>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 100, height: 50),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('overflow-wrap: break-word', (tester) async {
      const svg = '''
        <svg viewBox="0 0 100 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="14" style="overflow-wrap: break-word">LongUnbreakableWord</text>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 100, height: 50),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('overflow-wrap: anywhere', (tester) async {
      const svg = '''
        <svg viewBox="0 0 100 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="14" style="overflow-wrap: anywhere">Anywhere</text>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 100, height: 50),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('word-wrap legacy property (fallback)', (tester) async {
      const svg = '''
        <svg viewBox="0 0 100 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="14" style="word-wrap: break-word">LegacyWordWrap</text>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 100, height: 50),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('overflow-wrap inherited from group', (tester) async {
      const svg = '''
        <svg viewBox="0 0 100 80" xmlns="http://www.w3.org/2000/svg">
          <g style="overflow-wrap: break-word">
            <text x="10" y="25" font-size="14">Text1</text>
            <text x="10" y="50" font-size="14">Text2</text>
          </g>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 100, height: 80),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('overflow-wrap with word-break combination', (tester) async {
      const svg = '''
        <svg viewBox="0 0 100 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="14" style="word-break: normal; overflow-wrap: break-word">Combined</text>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 100, height: 50),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });
}
