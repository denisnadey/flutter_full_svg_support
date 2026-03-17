import 'package:flutter_svg/src/animation/animated_svg_picture.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('hyphens CSS property', () {
    testWidgets('hyphens: manual (default)', (tester) async {
      const svg = '''
        <svg viewBox="0 0 150 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="14" style="hyphens: manual">hyphen-ation</text>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 150, height: 50),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('hyphens: none', (tester) async {
      const svg = '''
        <svg viewBox="0 0 150 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="14" style="hyphens: none">no-hyphenation</text>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 150, height: 50),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('hyphens: auto', (tester) async {
      const svg = '''
        <svg viewBox="0 0 150 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="14" style="hyphens: auto">supercalifragilisticexpialidocious</text>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 150, height: 50),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('hyphens inherited from group', (tester) async {
      const svg = '''
        <svg viewBox="0 0 150 80" xmlns="http://www.w3.org/2000/svg">
          <g style="hyphens: auto">
            <text x="10" y="25" font-size="14">auto-hyphenation</text>
            <text x="10" y="50" font-size="14">another-word</text>
          </g>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 150, height: 80),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('hyphens with soft hyphen character', (tester) async {
      const svg = '''
        <svg viewBox="0 0 150 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="14" style="hyphens: manual">break&#173;here</text>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 150, height: 50),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });
}
