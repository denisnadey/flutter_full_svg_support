import 'package:full_svg_flutter/src/animation/animated_svg_picture.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('font-variant-east-asian CSS property', () {
    testWidgets('font-variant-east-asian: normal (default)', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="16">漢字</text>
        </svg>
      ''';
      await tester.pumpWidget(AnimatedSvgPicture.string(svg));
      await tester.pump();
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('font-variant-east-asian: jis78', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="16" style="font-variant-east-asian: jis78">漢字</text>
        </svg>
      ''';
      await tester.pumpWidget(AnimatedSvgPicture.string(svg));
      await tester.pump();
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('font-variant-east-asian: full-width', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="16" style="font-variant-east-asian: full-width">ABC123</text>
        </svg>
      ''';
      await tester.pumpWidget(AnimatedSvgPicture.string(svg));
      await tester.pump();
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('font-variant-east-asian: ruby simplified', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="16" style="font-variant-east-asian: ruby simplified">漢字</text>
        </svg>
      ''';
      await tester.pumpWidget(AnimatedSvgPicture.string(svg));
      await tester.pump();
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });
}
