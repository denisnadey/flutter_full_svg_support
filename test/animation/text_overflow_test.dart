import 'package:flutter_svg/src/animation/animated_svg_picture.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('text-overflow CSS property', () {
    testWidgets('text-overflow: clip (default)', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="16">Clip text</text>
        </svg>
      ''';
      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg),
      );
      await tester.pump();
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('text-overflow: ellipsis', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="16" style="text-overflow: ellipsis">Ellipsis text</text>
        </svg>
      ''';
      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg),
      );
      await tester.pump();
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('text-overflow: clip explicit', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="16" style="text-overflow: clip">Clip</text>
        </svg>
      ''';
      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg),
      );
      await tester.pump();
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('text-overflow: custom string', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="16" style="text-overflow: '...'">Custom</text>
        </svg>
      ''';
      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg),
      );
      await tester.pump();
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('text-overflow inheritance', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
          <g style="text-overflow: ellipsis">
            <text x="10" y="30" font-size="16">Inherited</text>
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
