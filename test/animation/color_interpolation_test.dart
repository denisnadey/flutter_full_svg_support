import 'package:full_svg_flutter/src/animation/animated_svg_picture.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('color-interpolation attribute', () {
    testWidgets('color-interpolation: sRGB (default)', (tester) async {
      const svg = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <defs>
            <linearGradient id="grad1" color-interpolation="sRGB">
              <stop offset="0%" stop-color="red"/>
              <stop offset="100%" stop-color="blue"/>
            </linearGradient>
          </defs>
          <rect x="10" y="10" width="80" height="80" fill="url(#grad1)"/>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 100, height: 100),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('color-interpolation: linearRGB', (tester) async {
      const svg = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <defs>
            <linearGradient id="grad2" color-interpolation="linearRGB">
              <stop offset="0%" stop-color="red"/>
              <stop offset="100%" stop-color="blue"/>
            </linearGradient>
          </defs>
          <rect x="10" y="10" width="80" height="80" fill="url(#grad2)"/>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 100, height: 100),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('linearRGB gradient with radial gradient', (tester) async {
      const svg = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <defs>
            <radialGradient id="grad3" color-interpolation="linearRGB">
              <stop offset="0%" stop-color="yellow"/>
              <stop offset="100%" stop-color="green"/>
            </radialGradient>
          </defs>
          <circle cx="50" cy="50" r="40" fill="url(#grad3)"/>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 100, height: 100),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('linearRGB gradient with multiple stops', (tester) async {
      const svg = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <defs>
            <linearGradient id="grad4" color-interpolation="linearRGB">
              <stop offset="0%" stop-color="#FF0000"/>
              <stop offset="50%" stop-color="#00FF00"/>
              <stop offset="100%" stop-color="#0000FF"/>
            </linearGradient>
          </defs>
          <rect x="10" y="10" width="80" height="80" fill="url(#grad4)"/>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 100, height: 100),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('linearRGB with opacity stops', (tester) async {
      const svg = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <defs>
            <linearGradient id="grad5" color-interpolation="linearRGB">
              <stop offset="0%" stop-color="black" stop-opacity="1"/>
              <stop offset="100%" stop-color="white" stop-opacity="0.5"/>
            </linearGradient>
          </defs>
          <rect x="10" y="10" width="80" height="80" fill="url(#grad5)"/>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 100, height: 100),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('color-interpolation default (no attribute)', (tester) async {
      const svg = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <defs>
            <linearGradient id="grad6">
              <stop offset="0%" stop-color="purple"/>
              <stop offset="100%" stop-color="orange"/>
            </linearGradient>
          </defs>
          <rect x="10" y="10" width="80" height="80" fill="url(#grad6)"/>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 100, height: 100),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('side-by-side sRGB vs linearRGB comparison', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
          <defs>
            <linearGradient id="srgb" color-interpolation="sRGB">
              <stop offset="0%" stop-color="red"/>
              <stop offset="100%" stop-color="lime"/>
            </linearGradient>
            <linearGradient id="linear" color-interpolation="linearRGB">
              <stop offset="0%" stop-color="red"/>
              <stop offset="100%" stop-color="lime"/>
            </linearGradient>
          </defs>
          <rect x="5" y="10" width="90" height="80" fill="url(#srgb)"/>
          <rect x="105" y="10" width="90" height="80" fill="url(#linear)"/>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 200, height: 100),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('linearRGB with gradientTransform', (tester) async {
      const svg = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <defs>
            <linearGradient id="grad7" color-interpolation="linearRGB"
                            gradientTransform="rotate(45)">
              <stop offset="0%" stop-color="cyan"/>
              <stop offset="100%" stop-color="magenta"/>
            </linearGradient>
          </defs>
          <rect x="10" y="10" width="80" height="80" fill="url(#grad7)"/>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 100, height: 100),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('linearRGB with spreadMethod', (tester) async {
      const svg = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <defs>
            <linearGradient id="grad8" x1="30%" x2="70%" 
                            color-interpolation="linearRGB" spreadMethod="reflect">
              <stop offset="0%" stop-color="navy"/>
              <stop offset="100%" stop-color="gold"/>
            </linearGradient>
          </defs>
          <rect x="10" y="10" width="80" height="80" fill="url(#grad8)"/>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 100, height: 100),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('linearRGB with focal radial gradient', (tester) async {
      const svg = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <defs>
            <radialGradient id="grad9" fx="30%" fy="30%"
                            color-interpolation="linearRGB">
              <stop offset="0%" stop-color="white"/>
              <stop offset="100%" stop-color="darkblue"/>
            </radialGradient>
          </defs>
          <circle cx="50" cy="50" r="40" fill="url(#grad9)"/>
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
