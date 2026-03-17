import 'package:flutter_svg/src/animation/animated_svg_picture.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('text-decoration-style CSS property', () {
    testWidgets('text-decoration-style: solid (default)', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="16" text-decoration="underline">Solid</text>
        </svg>
      ''';
      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg),
      );
      await tester.pump();
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('text-decoration-style: double', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="16" text-decoration="underline" style="text-decoration-style: double">Double</text>
        </svg>
      ''';
      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg),
      );
      await tester.pump();
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('text-decoration-style: dotted', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="16" text-decoration="underline" style="text-decoration-style: dotted">Dotted</text>
        </svg>
      ''';
      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg),
      );
      await tester.pump();
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('text-decoration-style: dashed', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="16" text-decoration="underline" style="text-decoration-style: dashed">Dashed</text>
        </svg>
      ''';
      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg),
      );
      await tester.pump();
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('text-decoration-style: wavy', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="16" text-decoration="underline" style="text-decoration-style: wavy">Wavy</text>
        </svg>
      ''';
      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg),
      );
      await tester.pump();
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('text-decoration-style inheritance', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
          <g style="text-decoration-style: dotted">
            <text x="10" y="30" font-size="16" text-decoration="underline">Inherited</text>
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
