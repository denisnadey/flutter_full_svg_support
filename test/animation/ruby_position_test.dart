import 'package:full_svg_flutter/src/animation/animated_svg_picture.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ruby-position CSS property', () {
    testWidgets('ruby-position: over (default)', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="16">漢字</text>
        </svg>
      ''';
      await tester.pumpWidget(AnimatedSvgPicture.string(svg));
      await tester.pump();
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('ruby-position: under', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="16" style="ruby-position: under">漢字</text>
        </svg>
      ''';
      await tester.pumpWidget(AnimatedSvgPicture.string(svg));
      await tester.pump();
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('ruby-position: inter-character', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="16" style="ruby-position: inter-character">漢字</text>
        </svg>
      ''';
      await tester.pumpWidget(AnimatedSvgPicture.string(svg));
      await tester.pump();
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });
}
