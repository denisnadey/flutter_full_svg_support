import 'package:flutter_svg/src/animation/animated_svg_picture.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('line-break CSS property', () {
    testWidgets('line-break: auto (default)', (tester) async {
      const svg = '''
        <svg viewBox="0 0 150 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="14" style="line-break: auto">AutoBreak</text>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 150, height: 50),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('line-break: loose', (tester) async {
      const svg = '''
        <svg viewBox="0 0 150 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="14" style="line-break: loose">LooseBreak</text>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 150, height: 50),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('line-break: normal', (tester) async {
      const svg = '''
        <svg viewBox="0 0 150 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="14" style="line-break: normal">NormalBreak</text>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 150, height: 50),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('line-break: strict', (tester) async {
      const svg = '''
        <svg viewBox="0 0 150 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="14" style="line-break: strict">StrictBreak</text>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 150, height: 50),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('line-break: anywhere', (tester) async {
      const svg = '''
        <svg viewBox="0 0 150 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="14" style="line-break: anywhere">AnywhereBreak</text>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 150, height: 50),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('line-break inherited from group', (tester) async {
      const svg = '''
        <svg viewBox="0 0 150 80" xmlns="http://www.w3.org/2000/svg">
          <g style="line-break: strict">
            <text x="10" y="25" font-size="14">Text1</text>
            <text x="10" y="50" font-size="14">Text2</text>
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
