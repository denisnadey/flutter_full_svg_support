import 'package:full_svg_flutter/src/animation/animated_svg_picture.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('text-transform CSS property', () {
    testWidgets('text-transform: none (default)', (tester) async {
      const svg = '''
        <svg viewBox="0 0 150 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="14" style="text-transform: none">NoChange</text>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 150, height: 50),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('text-transform: uppercase', (tester) async {
      const svg = '''
        <svg viewBox="0 0 150 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="14" style="text-transform: uppercase">uppercase</text>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 150, height: 50),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('text-transform: lowercase', (tester) async {
      const svg = '''
        <svg viewBox="0 0 150 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="14" style="text-transform: lowercase">LOWERCASE</text>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 150, height: 50),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('text-transform: capitalize', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="14" style="text-transform: capitalize">hello world</text>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 200, height: 50),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('text-transform: full-width', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="14" style="text-transform: full-width">ABC</text>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 200, height: 50),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('text-transform inherited from group', (tester) async {
      const svg = '''
        <svg viewBox="0 0 150 80" xmlns="http://www.w3.org/2000/svg">
          <g style="text-transform: uppercase">
            <text x="10" y="25" font-size="14">text one</text>
            <text x="10" y="50" font-size="14">text two</text>
          </g>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 150, height: 80),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('text-transform with mixed case input', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="14" style="text-transform: lowercase">MiXeD CaSe</text>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 200, height: 50),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });
}
