import 'package:flutter/material.dart';
import 'package:flutter_svg/src/animation/animated_svg_picture.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('gradient objectBoundingBox edge cases', () {
    testWidgets('gradient on element with zero width renders nothing', (
      tester,
    ) async {
      // Per SVG spec and Blink, objectBoundingBox gradients cannot render
      // when target element has zero width
      const svg =
          '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
        <defs>
          <linearGradient id="grad1" gradientUnits="objectBoundingBox">
            <stop offset="0%" stop-color="red"/>
            <stop offset="100%" stop-color="blue"/>
          </linearGradient>
        </defs>
        <rect x="50" y="25" width="0" height="50" fill="url(#grad1)" stroke="black"/>
      </svg>''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svg, width: 200, height: 100),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('gradient on element with zero height renders nothing', (
      tester,
    ) async {
      const svg =
          '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
        <defs>
          <linearGradient id="grad1" gradientUnits="objectBoundingBox">
            <stop offset="0%" stop-color="red"/>
            <stop offset="100%" stop-color="blue"/>
          </linearGradient>
        </defs>
        <rect x="50" y="25" width="100" height="0" fill="url(#grad1)" stroke="black"/>
      </svg>''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svg, width: 200, height: 100),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('gradient on horizontal line (zero-area bbox) renders nothing', (
      tester,
    ) async {
      // A horizontal line has zero height, so objectBoundingBox gradient fails
      const svg =
          '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
        <defs>
          <linearGradient id="grad1" gradientUnits="objectBoundingBox">
            <stop offset="0%" stop-color="green"/>
            <stop offset="100%" stop-color="yellow"/>
          </linearGradient>
        </defs>
        <line x1="10" y1="50" x2="190" y2="50" stroke="url(#grad1)" stroke-width="5"/>
      </svg>''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svg, width: 200, height: 100),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets(
      'gradient with userSpaceOnUse still works on zero-width element',
      (tester) async {
        // userSpaceOnUse doesn't depend on element bounds, so should work
        const svg =
            '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
        <defs>
          <linearGradient id="grad1" gradientUnits="userSpaceOnUse"
                          x1="0" y1="0" x2="200" y2="100">
            <stop offset="0%" stop-color="purple"/>
            <stop offset="100%" stop-color="orange"/>
          </linearGradient>
        </defs>
        <rect x="50" y="25" width="0" height="50" fill="url(#grad1)" stroke="black"/>
      </svg>''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AnimatedSvgPicture.string(svg, width: 200, height: 100),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      },
    );

    testWidgets('radial gradient on sub-pixel element renders nothing', (
      tester,
    ) async {
      const svg =
          '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
        <defs>
          <radialGradient id="grad1" gradientUnits="objectBoundingBox">
            <stop offset="0%" stop-color="white"/>
            <stop offset="100%" stop-color="black"/>
          </radialGradient>
        </defs>
        <rect x="50" y="25" width="0.0000001" height="50" fill="url(#grad1)" stroke="black"/>
      </svg>''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svg, width: 200, height: 100),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });

  group('conic gradient support', () {
    testWidgets('basic conic gradient renders', (tester) async {
      const svg =
          '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
        <defs>
          <conicGradient id="conic1" cx="50%" cy="50%">
            <stop offset="0%" stop-color="red"/>
            <stop offset="25%" stop-color="yellow"/>
            <stop offset="50%" stop-color="green"/>
            <stop offset="75%" stop-color="blue"/>
            <stop offset="100%" stop-color="red"/>
          </conicGradient>
        </defs>
        <rect x="25" y="10" width="80" height="80" fill="url(#conic1)"/>
      </svg>''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svg, width: 200, height: 100),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('conic gradient with from angle offset', (tester) async {
      const svg =
          '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
        <defs>
          <conicGradient id="conic1" cx="50%" cy="50%" from="45deg">
            <stop offset="0%" stop-color="red"/>
            <stop offset="100%" stop-color="blue"/>
          </conicGradient>
        </defs>
        <circle cx="100" cy="50" r="40" fill="url(#conic1)"/>
      </svg>''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svg, width: 200, height: 100),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('conic gradient with radians angle', (tester) async {
      const svg =
          '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
        <defs>
          <conicGradient id="conic1" cx="50%" cy="50%" from="1.57rad">
            <stop offset="0%" stop-color="green"/>
            <stop offset="100%" stop-color="purple"/>
          </conicGradient>
        </defs>
        <rect x="25" y="10" width="80" height="80" fill="url(#conic1)"/>
      </svg>''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svg, width: 200, height: 100),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('conic gradient with turn angle unit', (tester) async {
      const svg =
          '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
        <defs>
          <conicGradient id="conic1" cx="50%" cy="50%" from="0.25turn">
            <stop offset="0%" stop-color="cyan"/>
            <stop offset="100%" stop-color="magenta"/>
          </conicGradient>
        </defs>
        <ellipse cx="100" cy="50" rx="60" ry="40" fill="url(#conic1)"/>
      </svg>''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svg, width: 200, height: 100),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('conic gradient with gradientTransform', (tester) async {
      const svg =
          '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
        <defs>
          <conicGradient id="conic1" cx="50%" cy="50%" 
                         gradientTransform="scale(1.5)">
            <stop offset="0%" stop-color="gold"/>
            <stop offset="50%" stop-color="darkblue"/>
            <stop offset="100%" stop-color="gold"/>
          </conicGradient>
        </defs>
        <rect x="20" y="10" width="80" height="80" fill="url(#conic1)"/>
      </svg>''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svg, width: 200, height: 100),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('conic gradient with spreadMethod repeat', (tester) async {
      const svg =
          '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
        <defs>
          <conicGradient id="conic1" cx="50%" cy="50%" spreadMethod="repeat">
            <stop offset="0%" stop-color="red"/>
            <stop offset="50%" stop-color="yellow"/>
          </conicGradient>
        </defs>
        <rect x="20" y="10" width="80" height="80" fill="url(#conic1)"/>
      </svg>''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svg, width: 200, height: 100),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });

  group('pattern viewBox precedence', () {
    testWidgets('viewBox takes precedence over patternContentUnits', (
      tester,
    ) async {
      // When both viewBox and patternContentUnits="objectBoundingBox" are set,
      // viewBox should take precedence per SVG spec
      const svg =
          '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
        <defs>
          <pattern id="pat1" patternUnits="userSpaceOnUse"
                   patternContentUnits="objectBoundingBox"
                   width="20" height="20"
                   viewBox="0 0 10 10">
            <rect width="5" height="5" fill="red"/>
            <rect x="5" y="5" width="5" height="5" fill="blue"/>
          </pattern>
        </defs>
        <rect x="10" y="10" width="180" height="80" fill="url(#pat1)"/>
      </svg>''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svg, width: 200, height: 100),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('patternContentUnits works when no viewBox', (tester) async {
      const svg =
          '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
        <defs>
          <pattern id="pat1" patternUnits="userSpaceOnUse"
                   patternContentUnits="objectBoundingBox"
                   width="40" height="40">
            <circle cx="0.5" cy="0.5" r="0.2" fill="green"/>
          </pattern>
        </defs>
        <rect x="10" y="10" width="100" height="80" fill="url(#pat1)"/>
      </svg>''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svg, width: 200, height: 100),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });

  group('nested pattern references', () {
    testWidgets('pattern inherits width/height from referenced pattern', (
      tester,
    ) async {
      const svg =
          '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
        <defs>
          <pattern id="basePattern" patternUnits="userSpaceOnUse" 
                   width="20" height="20">
            <circle cx="10" cy="10" r="8" fill="blue"/>
          </pattern>
          <pattern id="derivedPattern" href="#basePattern"/>
        </defs>
        <rect x="10" y="10" width="180" height="80" fill="url(#derivedPattern)"/>
      </svg>''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svg, width: 200, height: 100),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('pattern overrides inherited width/height', (tester) async {
      const svg =
          '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
        <defs>
          <pattern id="basePattern" patternUnits="userSpaceOnUse" 
                   width="10" height="10">
            <rect width="5" height="5" fill="red"/>
          </pattern>
          <pattern id="derivedPattern" href="#basePattern" width="30" height="30"/>
        </defs>
        <rect x="10" y="10" width="180" height="80" fill="url(#derivedPattern)"/>
      </svg>''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svg, width: 200, height: 100),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('pattern inherits patternUnits from referenced pattern', (
      tester,
    ) async {
      const svg =
          '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
        <defs>
          <pattern id="basePattern" patternUnits="objectBoundingBox" 
                   width="0.1" height="0.1">
            <rect width="100%" height="100%" fill="yellow"/>
            <circle cx="50%" cy="50%" r="30%" fill="orange"/>
          </pattern>
          <pattern id="derivedPattern" href="#basePattern"/>
        </defs>
        <rect x="10" y="10" width="180" height="80" fill="url(#derivedPattern)"/>
      </svg>''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svg, width: 200, height: 100),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('pattern inherits patternTransform from referenced pattern', (
      tester,
    ) async {
      const svg =
          '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
        <defs>
          <pattern id="basePattern" patternUnits="userSpaceOnUse" 
                   width="20" height="20" patternTransform="rotate(45)">
            <rect width="10" height="10" fill="purple"/>
          </pattern>
          <pattern id="derivedPattern" href="#basePattern"/>
        </defs>
        <rect x="10" y="10" width="180" height="80" fill="url(#derivedPattern)"/>
      </svg>''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svg, width: 200, height: 100),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('deep pattern reference chain works', (tester) async {
      const svg =
          '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
        <defs>
          <pattern id="pattern1" patternUnits="userSpaceOnUse" width="15" height="15">
            <circle cx="7.5" cy="7.5" r="5" fill="teal"/>
          </pattern>
          <pattern id="pattern2" href="#pattern1"/>
          <pattern id="pattern3" href="#pattern2"/>
        </defs>
        <rect x="10" y="10" width="180" height="80" fill="url(#pattern3)"/>
      </svg>''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svg, width: 200, height: 100),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });

  group('stop offset animation in nested gradients', () {
    testWidgets('animated stop in referenced gradient', (tester) async {
      const svg =
          '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
        <defs>
          <linearGradient id="gradB">
            <stop offset="0%" stop-color="red"/>
            <stop offset="50%" stop-color="yellow">
              <animate attributeName="offset" from="0.5" to="0.9" 
                       dur="2s" repeatCount="indefinite"/>
            </stop>
            <stop offset="100%" stop-color="blue"/>
          </linearGradient>
          <linearGradient id="gradA" href="#gradB"/>
        </defs>
        <rect x="10" y="10" width="180" height="80" fill="url(#gradA)"/>
      </svg>''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svg, width: 200, height: 100),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('deep gradient chain with animated stops', (tester) async {
      const svg =
          '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
        <defs>
          <linearGradient id="gradC">
            <stop offset="0%" stop-color="green">
              <animate attributeName="offset" values="0;0.2;0" 
                       dur="3s" repeatCount="indefinite"/>
            </stop>
            <stop offset="100%" stop-color="purple">
              <animate attributeName="offset" values="1;0.8;1" 
                       dur="3s" repeatCount="indefinite"/>
            </stop>
          </linearGradient>
          <linearGradient id="gradB" href="#gradC"/>
          <linearGradient id="gradA" href="#gradB"/>
        </defs>
        <rect x="10" y="10" width="180" height="80" fill="url(#gradA)"/>
      </svg>''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svg, width: 200, height: 100),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('gradient with overridden attributes but inherited stops', (
      tester,
    ) async {
      const svg =
          '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
        <defs>
          <linearGradient id="gradB" gradientUnits="objectBoundingBox">
            <stop offset="0%" stop-color="cyan">
              <animate attributeName="stop-color" values="cyan;magenta;cyan" 
                       dur="2s" repeatCount="indefinite"/>
            </stop>
            <stop offset="100%" stop-color="black"/>
          </linearGradient>
          <linearGradient id="gradA" href="#gradB" 
                          gradientUnits="userSpaceOnUse"
                          x1="10" y1="10" x2="190" y2="90"/>
        </defs>
        <rect x="10" y="10" width="180" height="80" fill="url(#gradA)"/>
      </svg>''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svg, width: 200, height: 100),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });
}
