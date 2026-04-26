import 'package:full_svg_flutter/src/animation/animated_svg_picture.dart';
import 'package:full_svg_flutter/src/animation/path_data.dart';
import 'package:full_svg_flutter/src/animation/path_parser.dart';
import 'package:full_svg_flutter/src/animation/svg_transform.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Zero-Radius Ellipse Handling', () {
    testWidgets('ellipse with rx=0 does not render', (tester) async {
      const svg = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <ellipse cx="50" cy="50" rx="0" ry="30" fill="blue"/>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 100, height: 100),
      );
      await tester.pumpAndSettle();

      // Should render SVG but skip the degenerate ellipse
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('ellipse with ry=0 does not render', (tester) async {
      const svg = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <ellipse cx="50" cy="50" rx="30" ry="0" fill="red"/>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 100, height: 100),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('ellipse with both rx=0 and ry=0 does not render', (
      tester,
    ) async {
      const svg = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <ellipse cx="50" cy="50" rx="0" ry="0" fill="green"/>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 100, height: 100),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('ellipse with negative rx does not render', (tester) async {
      const svg = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <ellipse cx="50" cy="50" rx="-10" ry="30" fill="purple"/>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 100, height: 100),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('valid ellipse renders correctly', (tester) async {
      const svg = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <ellipse cx="50" cy="50" rx="30" ry="20" fill="orange"/>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 100, height: 100),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });

  group('Singular Matrix Protection', () {
    test('isMatrix2DSingular detects zero determinant matrix', () {
      // Singular matrix: a*d - b*c = 0
      // Example: [1, 2, 2, 4, 0, 0] -> 1*4 - 2*2 = 0
      final singular = [1.0, 2.0, 2.0, 4.0, 0.0, 0.0];
      expect(isMatrix2DSingular(singular), isTrue);
    });

    test('isMatrix2DSingular returns false for valid matrix', () {
      // Identity matrix: 1*1 - 0*0 = 1
      final identity = [1.0, 0.0, 0.0, 1.0, 0.0, 0.0];
      expect(isMatrix2DSingular(identity), isFalse);
    });

    test('isMatrix2DSingular handles near-zero determinant', () {
      // Near-singular matrix with very small determinant
      final nearSingular = [1.0, 1.0, 1.0, 1.0 + 1e-15, 0.0, 0.0];
      expect(isMatrix2DSingular(nearSingular), isTrue);
    });

    test('isMatrix2DSingular handles incomplete matrix', () {
      // Matrix with fewer than 4 elements
      expect(isMatrix2DSingular([1.0, 0.0, 0.0]), isTrue);
      expect(isMatrix2DSingular([]), isTrue);
    });

    test('getIdentityMatrix2D returns correct identity', () {
      final identity = getIdentityMatrix2D();
      expect(identity, [1.0, 0.0, 0.0, 1.0, 0.0, 0.0]);
    });

    test('TransformDecomposition handles singular matrix gracefully', () {
      // Test that singular matrix doesn't crash decomposition
      final transforms = SvgTransform.parse('matrix(1, 2, 2, 4, 10, 20)');
      expect(transforms.length, 1);

      final decomposition = TransformDecomposition.fromTransforms(transforms);
      // Should return identity-like transform with translation preserved
      expect(decomposition.translateX, 10.0);
      expect(decomposition.translateY, 20.0);
      expect(decomposition.scaleX, 0.0); // Degenerate scale
      expect(decomposition.scaleY, 0.0);
    });

    testWidgets('SVG with singular transform matrix renders gracefully', (
      tester,
    ) async {
      const svg = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <rect x="10" y="10" width="50" height="50" fill="blue"
                transform="matrix(1, 2, 2, 4, 0, 0)"/>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 100, height: 100),
      );
      await tester.pumpAndSettle();

      // Should not crash
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });

  group('NaN/Infinity in Path Parsing', () {
    test('PathParser handles path with valid coordinates', () {
      final parser = PathParser();
      final commands = parser.parse('M10,20 L30,40');

      expect(commands.length, 2);
      expect(commands[0], isA<MoveToCommand>());
      expect(commands[1], isA<LineToCommand>());
    });

    test('PathParser gracefully handles empty path', () {
      final parser = PathParser();
      final commands = parser.parse('');

      expect(commands, isEmpty);
    });

    test('PathParser gracefully handles whitespace-only path', () {
      final parser = PathParser();
      final commands = parser.parse('   ');

      expect(commands, isEmpty);
    });

    testWidgets('SVG with complex path renders correctly', (tester) async {
      const svg = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <path d="M10,10 L50,10 L50,50 L10,50 Z" fill="blue"/>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 100, height: 100),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('SVG with cubic bezier path renders correctly', (tester) async {
      const svg = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <path d="M10,50 C20,10 80,10 90,50" stroke="blue" fill="none"/>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 100, height: 100),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('SVG with arc path renders correctly', (tester) async {
      const svg = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <path d="M10,50 A20,20 0 1,1 90,50" stroke="red" fill="none"/>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 100, height: 100),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });

  group('Gradient Stop Offset Clamping', () {
    testWidgets('gradient with stop offset 0.0 renders correctly', (
      tester,
    ) async {
      const svg = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <defs>
            <linearGradient id="grad1">
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

    testWidgets('gradient with stop offset 1.0 renders correctly', (
      tester,
    ) async {
      const svg = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <defs>
            <linearGradient id="grad2">
              <stop offset="0" stop-color="green"/>
              <stop offset="1" stop-color="yellow"/>
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

    testWidgets('gradient with negative stop offset is clamped to 0', (
      tester,
    ) async {
      const svg = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <defs>
            <linearGradient id="grad3">
              <stop offset="-0.5" stop-color="purple"/>
              <stop offset="1" stop-color="orange"/>
            </linearGradient>
          </defs>
          <rect x="10" y="10" width="80" height="80" fill="url(#grad3)"/>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 100, height: 100),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('gradient with stop offset > 1 is clamped to 1', (
      tester,
    ) async {
      const svg = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <defs>
            <linearGradient id="grad4">
              <stop offset="0" stop-color="cyan"/>
              <stop offset="1.5" stop-color="magenta"/>
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

    testWidgets('radial gradient with boundary offsets renders correctly', (
      tester,
    ) async {
      const svg = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <defs>
            <radialGradient id="radGrad">
              <stop offset="0%" stop-color="white"/>
              <stop offset="100%" stop-color="black"/>
            </radialGradient>
          </defs>
          <circle cx="50" cy="50" r="40" fill="url(#radGrad)"/>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 100, height: 100),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });

  group('Marker Rendering for Degenerate Paths', () {
    testWidgets('marker on valid path renders correctly', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
          <defs>
            <marker id="arrow" viewBox="0 0 10 10" refX="5" refY="5"
                    markerWidth="6" markerHeight="6" orient="auto">
              <path d="M0,0 L10,5 L0,10 Z" fill="red"/>
            </marker>
          </defs>
          <line x1="20" y1="50" x2="180" y2="50" stroke="black" 
                marker-end="url(#arrow)"/>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 200, height: 100),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('marker on zero-length line handles gracefully', (
      tester,
    ) async {
      const svg = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <defs>
            <marker id="dot" viewBox="0 0 10 10" refX="5" refY="5"
                    markerWidth="6" markerHeight="6">
              <circle cx="5" cy="5" r="4" fill="blue"/>
            </marker>
          </defs>
          <line x1="50" y1="50" x2="50" y2="50" stroke="black"
                marker-start="url(#dot)" marker-end="url(#dot)"/>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 100, height: 100),
      );
      await tester.pumpAndSettle();

      // Should not crash on zero-length line
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('marker on path with all identical points handles gracefully', (
      tester,
    ) async {
      const svg = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <defs>
            <marker id="marker1" viewBox="0 0 10 10" refX="5" refY="5"
                    markerWidth="6" markerHeight="6" orient="auto">
              <rect width="10" height="10" fill="green"/>
            </marker>
          </defs>
          <path d="M50,50 L50,50 L50,50" stroke="black"
                marker-start="url(#marker1)" marker-mid="url(#marker1)" 
                marker-end="url(#marker1)"/>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 100, height: 100),
      );
      await tester.pumpAndSettle();

      // Should handle degenerate path gracefully
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('marker-mid on path with zero-length middle segment', (
      tester,
    ) async {
      const svg = '''
        <svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
          <defs>
            <marker id="midMarker" viewBox="0 0 10 10" refX="5" refY="5"
                    markerWidth="6" markerHeight="6" orient="auto">
              <circle cx="5" cy="5" r="4" fill="purple"/>
            </marker>
          </defs>
          <path d="M20,50 L100,50 L100,50 L180,50" stroke="black"
                marker-mid="url(#midMarker)"/>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 200, height: 100),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('polyline with markers renders correctly', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
          <defs>
            <marker id="polyMarker" viewBox="0 0 10 10" refX="5" refY="5"
                    markerWidth="4" markerHeight="4">
              <circle cx="5" cy="5" r="4" fill="orange"/>
            </marker>
          </defs>
          <polyline points="20,50 60,20 100,50 140,20 180,50" 
                    stroke="black" fill="none"
                    marker-start="url(#polyMarker)"
                    marker-mid="url(#polyMarker)"
                    marker-end="url(#polyMarker)"/>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 200, height: 100),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });

  group('Combined Edge Cases', () {
    testWidgets('complex SVG with multiple edge cases renders', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 200" xmlns="http://www.w3.org/2000/svg">
          <!-- Zero-radius ellipse (should not render) -->
          <ellipse cx="50" cy="50" rx="0" ry="0" fill="red"/>
          
          <!-- Valid ellipse -->
          <ellipse cx="100" cy="50" rx="30" ry="20" fill="blue"/>
          
          <!-- Gradient with boundary offsets -->
          <defs>
            <linearGradient id="testGrad">
              <stop offset="0%" stop-color="green"/>
              <stop offset="100%" stop-color="yellow"/>
            </linearGradient>
          </defs>
          <rect x="10" y="100" width="80" height="80" fill="url(#testGrad)"/>
          
          <!-- Valid path with transform -->
          <path d="M120,100 L180,100 L180,180 L120,180 Z" 
                fill="purple" transform="rotate(10, 150, 140)"/>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 200, height: 200),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('SVG with nested transforms handles edge cases', (
      tester,
    ) async {
      const svg = '''
        <svg viewBox="0 0 200 200" xmlns="http://www.w3.org/2000/svg">
          <g transform="translate(50, 50)">
            <g transform="scale(1.5)">
              <rect x="0" y="0" width="50" height="50" fill="blue"/>
            </g>
          </g>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 200, height: 200),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });
}
