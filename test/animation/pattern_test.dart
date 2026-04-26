import 'package:flutter/material.dart';
import 'package:full_svg_flutter/src/animation/animated_svg_picture.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('pattern element rendering', () {
    testWidgets('rect with pattern fill renders without error', (tester) async {
      const svg =
          '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
        <defs>
          <pattern id="dots" patternUnits="userSpaceOnUse" width="10" height="10">
            <circle cx="5" cy="5" r="3" fill="blue"/>
          </pattern>
        </defs>
        <rect x="10" y="10" width="180" height="80" fill="url(#dots)"/>
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

    testWidgets('path with pattern stroke renders without error', (
      tester,
    ) async {
      const svg =
          '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
        <defs>
          <pattern id="stripes" patternUnits="userSpaceOnUse" width="8" height="8">
            <line x1="0" y1="0" x2="8" y2="8" stroke="red" stroke-width="2"/>
          </pattern>
        </defs>
        <path d="M10,50 L190,50" stroke="url(#stripes)" stroke-width="20" fill="none"/>
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

    testWidgets('pattern with objectBoundingBox units renders without error', (
      tester,
    ) async {
      const svg =
          '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
        <defs>
          <pattern id="grid" patternUnits="objectBoundingBox" width="0.1" height="0.2">
            <rect x="0" y="0" width="100%" height="100%" fill="none" stroke="gray"/>
          </pattern>
        </defs>
        <rect x="10" y="10" width="100" height="50" fill="url(#grid)" stroke="black"/>
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

    testWidgets('pattern with viewBox renders without error', (tester) async {
      const svg =
          '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
        <defs>
          <pattern id="star" viewBox="0 0 10 10" width="20" height="20" patternUnits="userSpaceOnUse">
            <polygon points="5,0 6.5,4 10,4 7.5,6 8.5,10 5,8 1.5,10 2.5,6 0,4 3.5,4" fill="gold"/>
          </pattern>
        </defs>
        <circle cx="100" cy="50" r="40" fill="url(#star)"/>
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

    testWidgets('pattern with patternTransform renders without error', (
      tester,
    ) async {
      const svg =
          '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
        <defs>
          <pattern id="rotated" patternUnits="userSpaceOnUse" width="20" height="20"
              patternTransform="rotate(45)">
            <rect x="0" y="0" width="10" height="10" fill="purple"/>
          </pattern>
        </defs>
        <rect x="10" y="10" width="180" height="80" fill="url(#rotated)"/>
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

    testWidgets('pattern with href inheritance renders without error', (
      tester,
    ) async {
      const svg =
          '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
        <defs>
          <pattern id="basePattern" patternUnits="userSpaceOnUse" width="15" height="15">
            <circle cx="7.5" cy="7.5" r="5" fill="green"/>
          </pattern>
          <pattern id="derivedPattern" href="#basePattern" width="20" height="20"/>
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

    testWidgets('ellipse with pattern fill renders without error', (
      tester,
    ) async {
      const svg =
          '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
        <defs>
          <pattern id="checker" patternUnits="userSpaceOnUse" width="20" height="20">
            <rect x="0" y="0" width="10" height="10" fill="black"/>
            <rect x="10" y="10" width="10" height="10" fill="black"/>
          </pattern>
        </defs>
        <ellipse cx="100" cy="50" rx="80" ry="40" fill="url(#checker)"/>
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
}
