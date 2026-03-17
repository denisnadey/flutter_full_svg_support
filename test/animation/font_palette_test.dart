import 'package:flutter_svg/src/animation/animated_svg_picture.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('font-palette CSS property', () {
    testWidgets('font-palette: normal (default)', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="16">Normal palette</text>
        </svg>
      ''';
      await tester.pumpWidget(AnimatedSvgPicture.string(svg));
      await tester.pump();
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('font-palette: light', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="16" style="font-palette: light">Light</text>
        </svg>
      ''';
      await tester.pumpWidget(AnimatedSvgPicture.string(svg));
      await tester.pump();
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('font-palette: dark', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="16" style="font-palette: dark">Dark</text>
        </svg>
      ''';
      await tester.pumpWidget(AnimatedSvgPicture.string(svg));
      await tester.pump();
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('font-palette: custom name', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="16" style="font-palette: --my-palette">Custom</text>
        </svg>
      ''';
      await tester.pumpWidget(AnimatedSvgPicture.string(svg));
      await tester.pump();
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });
}
