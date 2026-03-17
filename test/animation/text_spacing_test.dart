import 'package:flutter_svg/src/animation/animated_svg_picture.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('text-spacing CSS property', () {
    testWidgets('text-spacing: normal (default)', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="16">漢字「日本語」</text>
        </svg>
      ''';
      await tester.pumpWidget(AnimatedSvgPicture.string(svg));
      await tester.pump();
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('text-spacing: none', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="16" style="text-spacing: none">漢字「日本語」</text>
        </svg>
      ''';
      await tester.pumpWidget(AnimatedSvgPicture.string(svg));
      await tester.pump();
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('text-spacing: auto', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="16" style="text-spacing: auto">漢字「日本語」</text>
        </svg>
      ''';
      await tester.pumpWidget(AnimatedSvgPicture.string(svg));
      await tester.pump();
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });
}
