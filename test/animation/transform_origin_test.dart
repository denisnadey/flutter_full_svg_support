import 'package:flutter_svg/src/animation/animated_svg_picture.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('transform-origin attribute', () {
    testWidgets('transform-origin: center (default behavior)', (tester) async {
      const svg = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <rect x="25" y="25" width="50" height="50" fill="blue"
                transform="rotate(45)"
                style="transform-origin: center"/>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 100, height: 100),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('transform-origin: 0 0 (top-left)', (tester) async {
      const svg = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <rect x="25" y="25" width="50" height="50" fill="red"
                transform="rotate(45)"
                style="transform-origin: 0 0"/>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 100, height: 100),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('transform-origin: 50% 50% (center percentage)', (
      tester,
    ) async {
      const svg = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <rect x="25" y="25" width="50" height="50" fill="green"
                transform="scale(0.8)"
                style="transform-origin: 50% 50%"/>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 100, height: 100),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('transform-origin: left top', (tester) async {
      const svg = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <rect x="25" y="25" width="50" height="50" fill="purple"
                transform="rotate(30)"
                style="transform-origin: left top"/>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 100, height: 100),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('transform-origin: right bottom', (tester) async {
      const svg = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <rect x="25" y="25" width="50" height="50" fill="orange"
                transform="rotate(-30)"
                style="transform-origin: right bottom"/>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 100, height: 100),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('transform-origin: 25px 25px (absolute values)', (
      tester,
    ) async {
      const svg = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <rect x="0" y="0" width="50" height="50" fill="teal"
                transform="rotate(45)"
                style="transform-origin: 25px 25px"/>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 100, height: 100),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('transform-origin with scale transform', (tester) async {
      const svg = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <rect x="25" y="25" width="50" height="50" fill="crimson"
                transform="scale(1.5)"
                style="transform-origin: center"/>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 100, height: 100),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('transform-origin with skewX', (tester) async {
      const svg = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <rect x="25" y="25" width="50" height="50" fill="navy"
                transform="skewX(15)"
                style="transform-origin: center center"/>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 100, height: 100),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('transform-origin on circle', (tester) async {
      const svg = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <circle cx="50" cy="50" r="25" fill="gold"
                  transform="scale(0.8)"
                  style="transform-origin: center"/>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 100, height: 100),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('transform-origin on ellipse', (tester) async {
      const svg = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <ellipse cx="50" cy="50" rx="40" ry="20" fill="coral"
                   transform="rotate(30)"
                   style="transform-origin: 50% 50%"/>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 100, height: 100),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('transform-origin on group', (tester) async {
      const svg = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <g transform="rotate(45)" style="transform-origin: 50 50">
            <rect x="30" y="30" width="40" height="40" fill="indigo"/>
          </g>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 100, height: 100),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('transform-origin: single value (applied to both axes)', (
      tester,
    ) async {
      const svg = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <rect x="25" y="25" width="50" height="50" fill="magenta"
                transform="rotate(45)"
                style="transform-origin: center"/>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 100, height: 100),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('transform-origin with combined transforms', (tester) async {
      const svg = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <rect x="25" y="25" width="50" height="50" fill="lime"
                transform="translate(10, 10) rotate(45) scale(0.8)"
                style="transform-origin: center"/>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 100, height: 100),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('transform-origin as attribute', (tester) async {
      const svg = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <rect x="25" y="25" width="50" height="50" fill="cyan"
                transform="rotate(30)"
                transform-origin="center center"/>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 100, height: 100),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });
}
