import 'package:flutter_svg/src/animation/animated_svg_picture.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('image-rendering attribute', () {
    testWidgets('image-rendering: auto (default medium quality)', (
      tester,
    ) async {
      const svg = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <image href="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="
                 x="10" y="10" width="80" height="80"
                 image-rendering="auto"/>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 100, height: 100),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('image-rendering: pixelated (no filtering)', (tester) async {
      const svg = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <image href="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="
                 x="10" y="10" width="80" height="80"
                 image-rendering="pixelated"/>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 100, height: 100),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('image-rendering: optimizeSpeed (no filtering)', (
      tester,
    ) async {
      const svg = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <image href="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="
                 x="10" y="10" width="80" height="80"
                 image-rendering="optimizeSpeed"/>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 100, height: 100),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('image-rendering: optimizeQuality (high quality)', (
      tester,
    ) async {
      const svg = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <image href="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="
                 x="10" y="10" width="80" height="80"
                 image-rendering="optimizeQuality"/>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 100, height: 100),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('image-rendering: smooth (high quality)', (tester) async {
      const svg = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <image href="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="
                 x="10" y="10" width="80" height="80"
                 image-rendering="smooth"/>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 100, height: 100),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });

  group('mix-blend-mode attribute', () {
    testWidgets('mix-blend-mode: normal (default)', (tester) async {
      const svg = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <rect x="10" y="10" width="50" height="50" fill="blue"/>
          <rect x="40" y="40" width="50" height="50" fill="red" 
                style="mix-blend-mode: normal"/>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 100, height: 100),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('mix-blend-mode: multiply', (tester) async {
      const svg = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <rect x="10" y="10" width="50" height="50" fill="blue"/>
          <rect x="40" y="40" width="50" height="50" fill="red"
                style="mix-blend-mode: multiply"/>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 100, height: 100),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('mix-blend-mode: screen', (tester) async {
      const svg = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <rect x="10" y="10" width="50" height="50" fill="blue"/>
          <rect x="40" y="40" width="50" height="50" fill="red"
                style="mix-blend-mode: screen"/>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 100, height: 100),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('mix-blend-mode: overlay', (tester) async {
      const svg = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <rect x="10" y="10" width="50" height="50" fill="blue"/>
          <rect x="40" y="40" width="50" height="50" fill="red"
                style="mix-blend-mode: overlay"/>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 100, height: 100),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('mix-blend-mode: darken', (tester) async {
      const svg = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <rect x="10" y="10" width="50" height="50" fill="blue"/>
          <rect x="40" y="40" width="50" height="50" fill="red"
                style="mix-blend-mode: darken"/>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 100, height: 100),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('mix-blend-mode: lighten', (tester) async {
      const svg = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <rect x="10" y="10" width="50" height="50" fill="blue"/>
          <rect x="40" y="40" width="50" height="50" fill="red"
                style="mix-blend-mode: lighten"/>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 100, height: 100),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('mix-blend-mode: color-dodge', (tester) async {
      const svg = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <rect x="10" y="10" width="50" height="50" fill="blue"/>
          <rect x="40" y="40" width="50" height="50" fill="red"
                style="mix-blend-mode: color-dodge"/>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 100, height: 100),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('mix-blend-mode: difference', (tester) async {
      const svg = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <rect x="10" y="10" width="50" height="50" fill="blue"/>
          <rect x="40" y="40" width="50" height="50" fill="red"
                style="mix-blend-mode: difference"/>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 100, height: 100),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('mix-blend-mode: exclusion', (tester) async {
      const svg = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <rect x="10" y="10" width="50" height="50" fill="blue"/>
          <rect x="40" y="40" width="50" height="50" fill="red"
                style="mix-blend-mode: exclusion"/>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 100, height: 100),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('mix-blend-mode: hue', (tester) async {
      const svg = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <rect x="10" y="10" width="50" height="50" fill="blue"/>
          <rect x="40" y="40" width="50" height="50" fill="red"
                style="mix-blend-mode: hue"/>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 100, height: 100),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('mix-blend-mode on strokes', (tester) async {
      const svg = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <rect x="10" y="10" width="80" height="80" fill="yellow"/>
          <line x1="10" y1="10" x2="90" y2="90" 
                stroke="blue" stroke-width="10"
                style="mix-blend-mode: multiply"/>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 100, height: 100),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('mix-blend-mode inherited from group', (tester) async {
      const svg = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <rect x="10" y="10" width="50" height="50" fill="blue"/>
          <g style="mix-blend-mode: screen">
            <rect x="40" y="40" width="50" height="50" fill="red"/>
          </g>
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
