import 'package:full_svg_flutter/src/animation/animated_svg_picture.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('text-underline-offset CSS property', () {
    testWidgets('text-underline-offset: auto (default)', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="16" text-decoration="underline" style="text-underline-offset: auto">Auto offset</text>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 200, height: 50),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('text-underline-offset: 3px', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="16" text-decoration="underline" style="text-underline-offset: 3px">3px offset</text>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 200, height: 50),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('text-underline-offset: 0.2em', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="16" text-decoration="underline" style="text-underline-offset: 0.2em">0.2em offset</text>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 200, height: 50),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('text-underline-offset: negative value', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="16" text-decoration="underline" style="text-underline-offset: -2px">Negative</text>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 200, height: 50),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('text-underline-offset inherited from group', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 80" xmlns="http://www.w3.org/2000/svg">
          <g text-decoration="underline" style="text-underline-offset: 5px">
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
