import 'package:flutter_svg/src/animation/animated_svg_picture.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('white-space CSS property', () {
    testWidgets('white-space: normal (default, collapses whitespace)', (
      tester,
    ) async {
      const svg = '''
        <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="16" style="white-space: normal">Hello    World</text>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 200, height: 50),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('white-space: pre (preserves whitespace)', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="16" style="white-space: pre">Hello    World</text>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 200, height: 50),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('white-space: pre-wrap (preserves with wrapping)', (
      tester,
    ) async {
      const svg = '''
        <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="16" style="white-space: pre-wrap">Hello    World</text>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 200, height: 50),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('white-space: nowrap (collapses, no wrapping)', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="16" style="white-space: nowrap">Hello    World</text>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 200, height: 50),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('white-space: pre-line (preserves newlines only)', (
      tester,
    ) async {
      const svg = '''
        <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="16" style="white-space: pre-line">Hello    World</text>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 200, height: 50),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('white-space: break-spaces (like pre-wrap)', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="16" style="white-space: break-spaces">Hello    World</text>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 200, height: 50),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('white-space inherited from group', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
          <g style="white-space: pre">
            <text x="10" y="30" font-size="16">Hello    World</text>
            <text x="10" y="60" font-size="16">Foo    Bar</text>
          </g>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 200, height: 100),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('white-space overrides xml:space', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="16" xml:space="preserve" style="white-space: normal">Hello    World</text>
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
