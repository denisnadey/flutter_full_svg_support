import 'package:full_svg_flutter/src/animation/animated_svg_picture.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('color-rendering attribute', () {
    testWidgets('color-rendering: auto (default)', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
          <defs>
            <linearGradient id="grad1">
              <stop offset="0%" stop-color="red"/>
              <stop offset="100%" stop-color="blue"/>
            </linearGradient>
          </defs>
          <rect x="10" y="10" width="180" height="80" 
                fill="url(#grad1)" 
                color-rendering="auto"/>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 200, height: 100),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('color-rendering: optimizeSpeed', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
          <defs>
            <linearGradient id="grad2">
              <stop offset="0%" stop-color="yellow"/>
              <stop offset="100%" stop-color="green"/>
            </linearGradient>
          </defs>
          <rect x="10" y="10" width="180" height="80" 
                fill="url(#grad2)"
                color-rendering="optimizeSpeed"/>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 200, height: 100),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('color-rendering: optimizeQuality', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
          <defs>
            <radialGradient id="grad3">
              <stop offset="0%" stop-color="white"/>
              <stop offset="100%" stop-color="purple"/>
            </radialGradient>
          </defs>
          <circle cx="100" cy="50" r="40" 
                  fill="url(#grad3)"
                  color-rendering="optimizeQuality"/>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 200, height: 100),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('color-rendering via style attribute', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
          <defs>
            <linearGradient id="grad4">
              <stop offset="0%" stop-color="cyan"/>
              <stop offset="100%" stop-color="magenta"/>
            </linearGradient>
          </defs>
          <rect x="10" y="10" width="180" height="80" 
                fill="url(#grad4)"
                style="color-rendering: optimizeQuality"/>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 200, height: 100),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('color-rendering inherited from group', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 150" xmlns="http://www.w3.org/2000/svg">
          <defs>
            <linearGradient id="grad5">
              <stop offset="0%" stop-color="orange"/>
              <stop offset="100%" stop-color="red"/>
            </linearGradient>
          </defs>
          <g color-rendering="optimizeSpeed">
            <rect x="10" y="10" width="80" height="60" fill="url(#grad5)"/>
            <rect x="110" y="10" width="80" height="60" fill="url(#grad5)"/>
          </g>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 200, height: 150),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('color-rendering on solid color shapes', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
          <rect x="10" y="10" width="80" height="80" 
                fill="#ff5500" 
                color-rendering="optimizeSpeed"/>
          <rect x="110" y="10" width="80" height="80" 
                fill="#00ff55" 
                color-rendering="optimizeQuality"/>
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
