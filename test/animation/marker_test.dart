import 'package:flutter/material.dart';
import 'package:flutter_svg/src/animation/animated_svg_picture.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('marker element rendering', () {
    testWidgets('path with marker-end renders without error', (tester) async {
      const svg =
          '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
        <defs>
          <marker id="arrow" viewBox="0 0 10 10" refX="5" refY="5"
              markerWidth="6" markerHeight="6" orient="auto">
            <path d="M 0 0 L 10 5 L 0 10 z" fill="black"/>
          </marker>
        </defs>
        <line x1="10" y1="50" x2="180" y2="50" stroke="black" marker-end="url(#arrow)"/>
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

    testWidgets('path with marker-start renders without error', (tester) async {
      const svg =
          '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
        <defs>
          <marker id="circle" viewBox="0 0 10 10" refX="5" refY="5"
              markerWidth="5" markerHeight="5">
            <circle cx="5" cy="5" r="4" fill="red"/>
          </marker>
        </defs>
        <path d="M 20 50 L 180 50" stroke="black" marker-start="url(#circle)"/>
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

    testWidgets('polyline with marker-mid renders without error', (
      tester,
    ) async {
      const svg =
          '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
        <defs>
          <marker id="dot" viewBox="0 0 10 10" refX="5" refY="5"
              markerWidth="4" markerHeight="4">
            <circle cx="5" cy="5" r="4" fill="blue"/>
          </marker>
        </defs>
        <polyline points="10,50 100,10 190,50" stroke="black" fill="none"
            marker-mid="url(#dot)"/>
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

    testWidgets('marker shorthand applies to all positions', (tester) async {
      const svg =
          '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
        <defs>
          <marker id="square" viewBox="0 0 10 10" refX="5" refY="5"
              markerWidth="5" markerHeight="5">
            <rect x="0" y="0" width="10" height="10" fill="green"/>
          </marker>
        </defs>
        <path d="M 20 50 L 100 20 L 180 50" stroke="black" fill="none"
            marker="url(#square)"/>
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
      'marker with orient="auto-start-reverse" renders without error',
      (tester) async {
        const svg =
            '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
        <defs>
          <marker id="arrowRev" viewBox="0 0 10 10" refX="5" refY="5"
              markerWidth="6" markerHeight="6" orient="auto-start-reverse">
            <path d="M 0 0 L 10 5 L 0 10 z" fill="purple"/>
          </marker>
        </defs>
        <line x1="20" y1="50" x2="180" y2="50" stroke="black"
            marker-start="url(#arrowRev)" marker-end="url(#arrowRev)"/>
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

    testWidgets('marker with fixed angle orientation renders without error', (
      tester,
    ) async {
      const svg =
          '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
        <defs>
          <marker id="fixedArrow" viewBox="0 0 10 10" refX="5" refY="5"
              markerWidth="6" markerHeight="6" orient="45deg">
            <path d="M 0 0 L 10 5 L 0 10 z" fill="orange"/>
          </marker>
        </defs>
        <path d="M 20 50 L 180 50" stroke="black" marker-end="url(#fixedArrow)"/>
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
      'marker with markerUnits="userSpaceOnUse" renders without error',
      (tester) async {
        const svg =
            '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
        <defs>
          <marker id="userSpace" viewBox="0 0 10 10" refX="5" refY="5"
              markerWidth="10" markerHeight="10" markerUnits="userSpaceOnUse">
            <circle cx="5" cy="5" r="5" fill="cyan"/>
          </marker>
        </defs>
        <line x1="20" y1="50" x2="180" y2="50" stroke="black" stroke-width="3"
            marker-end="url(#userSpace)"/>
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

    testWidgets('polygon with markers renders without error', (tester) async {
      const svg =
          '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
        <defs>
          <marker id="tri" viewBox="0 0 10 10" refX="5" refY="5"
              markerWidth="4" markerHeight="4" orient="auto">
            <polygon points="0,0 10,5 0,10" fill="magenta"/>
          </marker>
        </defs>
        <polygon points="50,80 100,20 150,80" stroke="black" fill="none"
            marker-start="url(#tri)" marker-mid="url(#tri)" marker-end="url(#tri)"/>
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
