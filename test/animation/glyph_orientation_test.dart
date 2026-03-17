import 'package:flutter_svg/src/animation/animated_svg_picture.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('glyph-orientation-vertical attribute', () {
    testWidgets('glyph-orientation-vertical: auto (default)', (tester) async {
      const svg = '''
        <svg viewBox="0 0 100 200" xmlns="http://www.w3.org/2000/svg">
          <text x="50" y="20" font-size="20" writing-mode="vertical-rl"
                glyph-orientation-vertical="auto">
            Vertical
          </text>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 100, height: 200),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('glyph-orientation-vertical: 0deg (upright)', (tester) async {
      const svg = '''
        <svg viewBox="0 0 100 200" xmlns="http://www.w3.org/2000/svg">
          <text x="50" y="20" font-size="20" writing-mode="vertical-rl"
                glyph-orientation-vertical="0deg">
            Upright
          </text>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 100, height: 200),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('glyph-orientation-vertical: 90deg (rotated)', (tester) async {
      const svg = '''
        <svg viewBox="0 0 100 200" xmlns="http://www.w3.org/2000/svg">
          <text x="50" y="20" font-size="20" writing-mode="vertical-rl"
                glyph-orientation-vertical="90deg">
            Rotated
          </text>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 100, height: 200),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('glyph-orientation-vertical: 0 without deg suffix',
        (tester) async {
      const svg = '''
        <svg viewBox="0 0 100 200" xmlns="http://www.w3.org/2000/svg">
          <text x="50" y="20" font-size="20" writing-mode="vertical-rl"
                glyph-orientation-vertical="0">
            Upright
          </text>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 100, height: 200),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('glyph-orientation-vertical via style attribute',
        (tester) async {
      const svg = '''
        <svg viewBox="0 0 100 200" xmlns="http://www.w3.org/2000/svg">
          <text x="50" y="20" font-size="20" 
                style="writing-mode: vertical-rl; glyph-orientation-vertical: 0">
            Styled
          </text>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 100, height: 200),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('glyph-orientation-vertical inherited from group',
        (tester) async {
      const svg = '''
        <svg viewBox="0 0 150 200" xmlns="http://www.w3.org/2000/svg">
          <g writing-mode="vertical-rl" glyph-orientation-vertical="0">
            <text x="30" y="20" font-size="16">First</text>
            <text x="80" y="20" font-size="16">Second</text>
          </g>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 150, height: 200),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('glyph-orientation-vertical on horizontal text (ignored)',
        (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="50" font-size="20" glyph-orientation-vertical="90">
            Horizontal Text
          </text>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 200, height: 100),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });
}
