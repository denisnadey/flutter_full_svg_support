import 'package:full_svg_flutter/src/animation/animated_svg_picture.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('word-break CSS property', () {
    testWidgets('word-break: normal (default)', (tester) async {
      const svg = '''
        <svg viewBox="0 0 100 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="14" style="word-break: normal">LongWord</text>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 100, height: 50),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('word-break: break-all', (tester) async {
      const svg = '''
        <svg viewBox="0 0 100 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="14" style="word-break: break-all">BreakAnywhere</text>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 100, height: 50),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('word-break: keep-all', (tester) async {
      const svg = '''
        <svg viewBox="0 0 100 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="14" style="word-break: keep-all">KeepIt</text>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 100, height: 50),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('word-break: break-word', (tester) async {
      const svg = '''
        <svg viewBox="0 0 100 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="14" style="word-break: break-word">OverflowWord</text>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 100, height: 50),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('word-break inherited from group', (tester) async {
      const svg = '''
        <svg viewBox="0 0 100 80" xmlns="http://www.w3.org/2000/svg">
          <g style="word-break: break-all">
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

    testWidgets('word-break with CJK text', (tester) async {
      const svg = '''
        <svg viewBox="0 0 100 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="14" style="word-break: keep-all">中文文字</text>
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
