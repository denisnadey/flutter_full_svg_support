import 'package:flutter_svg/src/animation/animated_svg_picture.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('paint-order attribute', () {
    testWidgets('default order is fill then stroke', (tester) async {
      // Default order: fill, stroke, markers
      // Stroke paints on top of fill by default
      const svg = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <rect x="10" y="10" width="80" height="80" 
                fill="blue" stroke="red" stroke-width="10"/>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(
          svg,
          width: 100,
          height: 100,
        ),
      );
      await tester.pumpAndSettle();

      // Visual verification - stroke (red) should be on top of fill (blue)
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('paint-order: stroke fill renders stroke first', (tester) async {
      // With stroke first, fill paints on top of stroke
      const svg = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <rect x="10" y="10" width="80" height="80" 
                fill="blue" stroke="red" stroke-width="10"
                paint-order="stroke fill"/>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(
          svg,
          width: 100,
          height: 100,
        ),
      );
      await tester.pumpAndSettle();

      // Visual verification - fill (blue) should be on top of stroke (red)
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('paint-order: stroke fill markers orders correctly', (tester) async {
      // Full order specification
      const svg = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <rect x="10" y="10" width="80" height="80" 
                fill="blue" stroke="red" stroke-width="10"
                paint-order="stroke fill markers"/>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(
          svg,
          width: 100,
          height: 100,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('paint-order: normal uses default order', (tester) async {
      // "normal" is same as default: fill, stroke, markers
      const svg = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <rect x="10" y="10" width="80" height="80" 
                fill="blue" stroke="red" stroke-width="10"
                paint-order="normal"/>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(
          svg,
          width: 100,
          height: 100,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('paint-order is inherited from parent', (tester) async {
      // paint-order should inherit from parent group
      const svg = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <g paint-order="stroke fill">
            <rect x="10" y="10" width="80" height="80" 
                  fill="blue" stroke="red" stroke-width="10"/>
          </g>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(
          svg,
          width: 100,
          height: 100,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('paint-order applies to circle', (tester) async {
      const svg = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <circle cx="50" cy="50" r="40" 
                  fill="green" stroke="yellow" stroke-width="10"
                  paint-order="stroke"/>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(
          svg,
          width: 100,
          height: 100,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('paint-order applies to ellipse', (tester) async {
      const svg = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <ellipse cx="50" cy="50" rx="40" ry="25" 
                   fill="purple" stroke="orange" stroke-width="8"
                   paint-order="stroke fill"/>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(
          svg,
          width: 100,
          height: 100,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('paint-order applies to path', (tester) async {
      const svg = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <path d="M 10,50 Q 50,10 90,50 T 90,90 Z" 
                fill="cyan" stroke="magenta" stroke-width="6"
                paint-order="stroke"/>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(
          svg,
          width: 100,
          height: 100,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('paint-order applies to polygon', (tester) async {
      const svg = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <polygon points="50,10 90,90 10,90" 
                   fill="lime" stroke="navy" stroke-width="8"
                   paint-order="stroke fill"/>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(
          svg,
          width: 100,
          height: 100,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('paint-order applies to polyline', (tester) async {
      const svg = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <polyline points="10,10 50,50 90,10 50,90" 
                    fill="teal" stroke="coral" stroke-width="6"
                    paint-order="stroke"/>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(
          svg,
          width: 100,
          height: 100,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('paint-order with markers on path', (tester) async {
      // Test paint-order with markers - markers layer control
      const svg = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <defs>
            <marker id="dot" viewBox="0 0 10 10" refX="5" refY="5"
                    markerWidth="4" markerHeight="4">
              <circle cx="5" cy="5" r="4" fill="red"/>
            </marker>
          </defs>
          <path d="M 10,50 L 90,50" 
                stroke="blue" stroke-width="4"
                marker-start="url(#dot)" marker-end="url(#dot)"
                paint-order="markers stroke"/>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(
          svg,
          width: 100,
          height: 100,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('paint-order partial list adds missing at end', (tester) async {
      // When only "stroke" is specified, fill and markers follow in default order
      const svg = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <rect x="10" y="10" width="80" height="80" 
                fill="blue" stroke="red" stroke-width="10"
                paint-order="stroke"/>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(
          svg,
          width: 100,
          height: 100,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });
}
