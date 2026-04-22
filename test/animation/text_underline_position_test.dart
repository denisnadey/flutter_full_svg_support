import 'package:full_svg_flutter/src/animation/animated_svg_picture.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('text-underline-position CSS property', () {
    testWidgets('text-underline-position: auto (default)', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="16" text-decoration="underline" style="text-underline-position: auto">Underlined</text>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 200, height: 50),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('text-underline-position: under', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="16" text-decoration="underline" style="text-underline-position: under">Under text</text>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 200, height: 50),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('text-underline-position: left', (tester) async {
      const svg = '''
        <svg viewBox="0 0 100 150" xmlns="http://www.w3.org/2000/svg">
          <text x="50" y="20" writing-mode="vertical-rl" text-decoration="underline" style="text-underline-position: left">縦書き</text>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 100, height: 150),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('text-underline-position: right', (tester) async {
      const svg = '''
        <svg viewBox="0 0 100 150" xmlns="http://www.w3.org/2000/svg">
          <text x="50" y="20" writing-mode="vertical-rl" text-decoration="underline" style="text-underline-position: right">縦書き</text>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 100, height: 150),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('text-underline-position: under left', (tester) async {
      const svg = '''
        <svg viewBox="0 0 100 150" xmlns="http://www.w3.org/2000/svg">
          <text x="50" y="20" writing-mode="vertical-rl" text-decoration="underline" style="text-underline-position: under left">組み合わせ</text>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 100, height: 150),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('text-underline-position inherited from group', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 80" xmlns="http://www.w3.org/2000/svg">
          <g text-decoration="underline" style="text-underline-position: under">
            <text x="10" y="25" font-size="16">Line 1</text>
            <text x="10" y="50" font-size="16">Line 2</text>
          </g>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 200, height: 80),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });
}
