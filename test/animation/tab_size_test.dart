import 'package:full_svg_flutter/src/animation/animated_svg_picture.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('tab-size CSS property', () {
    testWidgets('tab-size: 8 (default)', (tester) async {
      const svg = '''
        <svg viewBox="0 0 300 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="16" style="tab-size: 8">Col1&#x9;Col2</text>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 300, height: 50),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('tab-size: 4', (tester) async {
      const svg = '''
        <svg viewBox="0 0 300 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="16" style="tab-size: 4">Col1&#x9;Col2</text>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 300, height: 50),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('tab-size: 2', (tester) async {
      const svg = '''
        <svg viewBox="0 0 300 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="16" style="tab-size: 2">A&#x9;B</text>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 300, height: 50),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('tab-size: 1 (minimum)', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="16" style="tab-size: 1">X&#x9;Y</text>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 200, height: 50),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('tab-size inherited from group', (tester) async {
      const svg = '''
        <svg viewBox="0 0 300 100" xmlns="http://www.w3.org/2000/svg">
          <g style="tab-size: 4">
            <text x="10" y="30" font-size="16">A&#x9;B</text>
            <text x="10" y="60" font-size="16">C&#x9;D</text>
          </g>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 300, height: 100),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('tab-size with white-space: pre', (tester) async {
      const svg = '''
        <svg viewBox="0 0 300 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="16" style="white-space: pre; tab-size: 4">A&#x9;B</text>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 300, height: 50),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });
}
