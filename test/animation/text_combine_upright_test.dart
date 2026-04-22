import 'package:full_svg_flutter/src/animation/animated_svg_picture.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('text-combine-upright CSS property', () {
    testWidgets('text-combine-upright: none (default)', (tester) async {
      const svg = '''
        <svg viewBox="0 0 100 150" xmlns="http://www.w3.org/2000/svg">
          <text x="50" y="20" writing-mode="vertical-rl" style="text-combine-upright: none">AB12</text>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 100, height: 150),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('text-combine-upright: all', (tester) async {
      const svg = '''
        <svg viewBox="0 0 100 150" xmlns="http://www.w3.org/2000/svg">
          <text x="50" y="20" writing-mode="vertical-rl" style="text-combine-upright: all">12</text>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 100, height: 150),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('text-combine-upright: digits', (tester) async {
      const svg = '''
        <svg viewBox="0 0 100 150" xmlns="http://www.w3.org/2000/svg">
          <text x="50" y="20" writing-mode="vertical-rl" style="text-combine-upright: digits">99</text>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 100, height: 150),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('text-combine-upright: digits 4', (tester) async {
      const svg = '''
        <svg viewBox="0 0 100 150" xmlns="http://www.w3.org/2000/svg">
          <text x="50" y="20" writing-mode="vertical-rl" style="text-combine-upright: digits 4">2024</text>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 100, height: 150),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('text-combine-upright inherited from group', (tester) async {
      const svg = '''
        <svg viewBox="0 0 100 150" xmlns="http://www.w3.org/2000/svg">
          <g writing-mode="vertical-rl" style="text-combine-upright: all">
            <text x="30" y="20">12</text>
            <text x="60" y="20">34</text>
          </g>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 100, height: 150),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });
}
