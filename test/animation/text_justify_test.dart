import 'package:flutter_svg/src/animation/animated_svg_picture.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('text-justify CSS property', () {
    testWidgets('text-justify: auto (default)', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="16">Auto justify</text>
        </svg>
      ''';
      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg),
      );
      await tester.pump();
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('text-justify: none', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="16" style="text-justify: none">No justify</text>
        </svg>
      ''';
      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg),
      );
      await tester.pump();
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('text-justify: inter-word', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="16" style="text-justify: inter-word">Inter word</text>
        </svg>
      ''';
      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg),
      );
      await tester.pump();
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('text-justify: inter-character', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="16" style="text-justify: inter-character">Inter char</text>
        </svg>
      ''';
      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg),
      );
      await tester.pump();
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('text-justify inheritance', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
          <g style="text-justify: inter-word">
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
