import 'package:full_svg_flutter/src/animation/animated_svg_picture.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('text-orientation CSS property', () {
    testWidgets('text-orientation: mixed (default)', (tester) async {
      const svg = '''
        <svg viewBox="0 0 100 150" xmlns="http://www.w3.org/2000/svg">
          <text x="50" y="20" writing-mode="vertical-rl" style="text-orientation: mixed">ABあい</text>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 100, height: 150),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('text-orientation: upright', (tester) async {
      const svg = '''
        <svg viewBox="0 0 100 150" xmlns="http://www.w3.org/2000/svg">
          <text x="50" y="20" writing-mode="vertical-rl" style="text-orientation: upright">ABC</text>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 100, height: 150),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('text-orientation: sideways', (tester) async {
      const svg = '''
        <svg viewBox="0 0 100 150" xmlns="http://www.w3.org/2000/svg">
          <text x="50" y="20" writing-mode="vertical-rl" style="text-orientation: sideways">XYZ</text>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 100, height: 150),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('text-orientation: sideways-right (legacy)', (tester) async {
      const svg = '''
        <svg viewBox="0 0 100 150" xmlns="http://www.w3.org/2000/svg">
          <text x="50" y="20" writing-mode="vertical-rl" style="text-orientation: sideways-right">123</text>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 100, height: 150),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('text-orientation inherited from group', (tester) async {
      const svg = '''
        <svg viewBox="0 0 100 150" xmlns="http://www.w3.org/2000/svg">
          <g writing-mode="vertical-rl" style="text-orientation: upright">
            <text x="30" y="20">AB</text>
            <text x="60" y="20">CD</text>
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
