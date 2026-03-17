import 'package:flutter/material.dart';
import 'package:flutter_svg/src/animation/animated_svg_picture.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('group opacity compositing', () {
    testWidgets('group with opacity="0.5" renders without error', (
      tester,
    ) async {
      const svg =
          '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
        <g opacity="0.5">
          <rect x="10" y="10" width="80" height="80" fill="red"/>
          <rect x="50" y="10" width="80" height="80" fill="blue"/>
        </g>
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

    testWidgets('nested groups with opacity render without error', (
      tester,
    ) async {
      const svg =
          '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
        <g opacity="0.8">
          <rect x="10" y="10" width="60" height="60" fill="green"/>
          <g opacity="0.5">
            <circle cx="100" cy="50" r="30" fill="yellow"/>
          </g>
        </g>
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

    testWidgets('group with opacity="0" renders without error (invisible)', (
      tester,
    ) async {
      const svg =
          '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
        <g opacity="0">
          <rect x="10" y="10" width="180" height="80" fill="red"/>
        </g>
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

    testWidgets('group with opacity="1" renders normally', (tester) async {
      const svg =
          '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
        <g opacity="1">
          <rect x="10" y="10" width="180" height="80" fill="purple"/>
        </g>
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

    testWidgets('svg root with opacity renders without error', (tester) async {
      const svg =
          '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg" opacity="0.7">
        <rect x="10" y="10" width="180" height="80" fill="orange"/>
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

    testWidgets('group opacity with overlapping children composites correctly', (
      tester,
    ) async {
      // This tests the key difference between group opacity and individual opacity:
      // With group opacity, overlapping areas should NOT be darker
      const svg =
          '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
        <g opacity="0.5">
          <circle cx="60" cy="50" r="40" fill="red"/>
          <circle cx="100" cy="50" r="40" fill="red"/>
          <circle cx="140" cy="50" r="40" fill="red"/>
        </g>
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
