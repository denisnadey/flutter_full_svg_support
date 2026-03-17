import 'package:flutter_svg/src/animation/animated_svg_picture.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('shape-rendering attribute', () {
    testWidgets('shape-rendering: auto (default, anti-aliased)', (
      tester,
    ) async {
      const svg = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <rect x="10" y="10" width="80" height="80" fill="blue"
                shape-rendering="auto"/>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 100, height: 100),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('shape-rendering: geometricPrecision (anti-aliased)', (
      tester,
    ) async {
      const svg = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <circle cx="50" cy="50" r="40" fill="red"
                  shape-rendering="geometricPrecision"/>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 100, height: 100),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('shape-rendering: optimizeSpeed (no anti-alias)', (
      tester,
    ) async {
      const svg = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <rect x="10" y="10" width="80" height="80" fill="green"
                shape-rendering="optimizeSpeed"/>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 100, height: 100),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('shape-rendering: crispEdges (no anti-alias)', (tester) async {
      const svg = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <path d="M10,10 L90,10 L90,90 L10,90 Z" fill="purple"
                shape-rendering="crispEdges"/>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 100, height: 100),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('shape-rendering applies to strokes', (tester) async {
      const svg = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <line x1="10" y1="50" x2="90" y2="50" 
                stroke="orange" stroke-width="4"
                shape-rendering="crispEdges"/>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 100, height: 100),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('shape-rendering inherited from parent', (tester) async {
      const svg = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <g shape-rendering="crispEdges">
            <rect x="10" y="10" width="30" height="30" fill="blue"/>
            <rect x="60" y="60" width="30" height="30" fill="red"/>
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

  group('overflow attribute', () {
    testWidgets('overflow: hidden clips content (default)', (tester) async {
      const svg = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <foreignObject x="20" y="20" width="60" height="60" overflow="hidden">
            <rect x="-10" y="-10" width="100" height="100" fill="blue"/>
          </foreignObject>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 100, height: 100),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('overflow: visible allows content to overflow', (tester) async {
      const svg = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <foreignObject x="20" y="20" width="60" height="60" overflow="visible">
            <rect x="-10" y="-10" width="100" height="100" fill="red"/>
          </foreignObject>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 100, height: 100),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('overflow: auto clips content', (tester) async {
      const svg = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <foreignObject x="20" y="20" width="60" height="60" overflow="auto">
            <rect x="0" y="0" width="100" height="100" fill="green"/>
          </foreignObject>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 100, height: 100),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('overflow: scroll clips content', (tester) async {
      const svg = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <foreignObject x="20" y="20" width="60" height="60" overflow="scroll">
            <rect x="0" y="0" width="100" height="100" fill="purple"/>
          </foreignObject>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 100, height: 100),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('overflow inherited from parent', (tester) async {
      const svg = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <g overflow="visible">
            <foreignObject x="20" y="20" width="60" height="60">
              <rect x="-10" y="-10" width="100" height="100" fill="teal"/>
            </foreignObject>
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

  group('combined rendering attributes', () {
    testWidgets('shape-rendering + overflow combined', (tester) async {
      const svg = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg"
             shape-rendering="crispEdges">
          <foreignObject x="10" y="10" width="80" height="80" overflow="hidden">
            <rect x="0" y="0" width="100" height="100" fill="navy"/>
          </foreignObject>
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
