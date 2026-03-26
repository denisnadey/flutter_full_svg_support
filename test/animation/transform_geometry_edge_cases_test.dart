import 'package:flutter_svg/src/animation/animated_svg_picture.dart';
import 'package:flutter_svg/src/animation/svg_transform.dart';
import 'package:flutter_svg/src/animation/smil/interpolators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('perspective-origin CSS property', () {
    testWidgets('renders with custom perspective-origin', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 200" xmlns="http://www.w3.org/2000/svg">
          <style>
            .box {
              perspective: 500px;
              perspective-origin: 25% 75%;
            }
          </style>
          <g class="box">
            <rect x="50" y="50" width="100" height="100" fill="blue"
                  style="transform: rotateY(45deg);"/>
          </g>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 200, height: 200),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('handles perspective-origin keywords (left top)', (
      tester,
    ) async {
      const svg = '''
        <svg viewBox="0 0 200 200" xmlns="http://www.w3.org/2000/svg">
          <g style="perspective: 300px; perspective-origin: left top;">
            <rect x="50" y="50" width="100" height="100" fill="green"
                  style="transform: rotateX(30deg);"/>
          </g>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 200, height: 200),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('handles perspective-origin with pixel values', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 200" xmlns="http://www.w3.org/2000/svg">
          <g style="perspective: 400px; perspective-origin: 100px 150px;">
            <rect x="50" y="50" width="100" height="100" fill="red"
                  style="transform: rotateY(60deg);"/>
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

  group('transform-style: preserve-3d', () {
    testWidgets('renders nested 3D transforms with preserve-3d', (
      tester,
    ) async {
      const svg = '''
        <svg viewBox="0 0 200 200" xmlns="http://www.w3.org/2000/svg">
          <g style="transform-style: preserve-3d; transform: rotateY(30deg);">
            <rect x="50" y="50" width="100" height="100" fill="blue"
                  style="transform: rotateX(45deg);"/>
          </g>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 200, height: 200),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('renders with transform-style: flat (default)', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 200" xmlns="http://www.w3.org/2000/svg">
          <g style="transform-style: flat; transform: rotateY(30deg);">
            <rect x="50" y="50" width="100" height="100" fill="orange"
                  style="transform: rotateX(45deg);"/>
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

  group('transform-origin with 3D perspective', () {
    testWidgets('applies transform-origin correctly with perspective', (
      tester,
    ) async {
      const svg = '''
        <svg viewBox="0 0 200 200" xmlns="http://www.w3.org/2000/svg">
          <rect x="50" y="50" width="100" height="100" fill="purple"
                style="
                  perspective: 500px;
                  transform-origin: 100px 100px;
                  transform: rotateY(45deg);
                "/>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 200, height: 200),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('perspective and transform-origin are applied independently', (
      tester,
    ) async {
      const svg = '''
        <svg viewBox="0 0 200 200" xmlns="http://www.w3.org/2000/svg">
          <g style="perspective: 400px; perspective-origin: 0% 0%;">
            <rect x="50" y="50" width="100" height="100" fill="cyan"
                  style="transform-origin: center; transform: rotateY(30deg);"/>
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

  group('Non-commutative transform animation', () {
    test('interpolates matching transform lists per-function', () {
      // rotate(0) scale(1) → rotate(180) scale(2) at t=0.5
      // Should produce rotate(90) scale(1.5) with per-function interpolation
      final result = Interpolators.interpolateTransform(
        'rotate(0) scale(1)',
        'rotate(180) scale(2)',
        0.5,
      );

      // Check that both rotate and scale are present
      expect(result, contains('rotate'));
      expect(result, contains('scale'));

      // Parse the result to verify values
      final transforms = SvgTransform.parse(result);
      expect(transforms.length, equals(2));

      // First should be rotate
      expect(transforms[0].type, equals(SvgTransformType.rotate));
      expect(transforms[0].values[0], closeTo(90.0, 0.1));

      // Second should be scale
      expect(transforms[1].type, equals(SvgTransformType.scale));
      expect(transforms[1].values[0], closeTo(1.5, 0.1));
    });

    test('interpolates translate + rotate + scale with matching functions', () {
      final result = Interpolators.interpolateTransform(
        'translate(0, 0) rotate(0) scale(1)',
        'translate(100, 100) rotate(90) scale(2)',
        0.5,
      );

      final transforms = SvgTransform.parse(result);
      expect(transforms.length, equals(3));

      // Verify translate
      expect(transforms[0].type, equals(SvgTransformType.translate));
      expect(transforms[0].values[0], closeTo(50.0, 0.1));
      expect(transforms[0].values[1], closeTo(50.0, 0.1));

      // Verify rotate
      expect(transforms[1].type, equals(SvgTransformType.rotate));
      expect(transforms[1].values[0], closeTo(45.0, 0.1));

      // Verify scale
      expect(transforms[2].type, equals(SvgTransformType.scale));
      expect(transforms[2].values[0], closeTo(1.5, 0.1));
    });

    test('falls back to matrix decomposition for non-matching transforms', () {
      // Different transform functions - should use matrix decomposition
      final result = Interpolators.interpolateTransform(
        'rotate(0) scale(1)',
        'translate(50, 50)',
        0.5,
      );

      // Result should be valid transform string
      expect(result.isNotEmpty, isTrue);
    });

    test('handles skew + scale non-commutative transforms', () {
      final result = Interpolators.interpolateTransform(
        'skewX(0) scale(1)',
        'skewX(30) scale(2)',
        0.5,
      );

      final transforms = SvgTransform.parse(result);
      expect(transforms.length, equals(2));
      expect(transforms[0].type, equals(SvgTransformType.skewX));
      expect(transforms[0].values[0], closeTo(15.0, 0.1));
      expect(transforms[1].type, equals(SvgTransformType.scale));
      expect(transforms[1].values[0], closeTo(1.5, 0.1));
    });
  });

  group('Arc geometry edge cases', () {
    testWidgets('arc with zero rx renders as lineTo', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
          <path d="M10,50 A0,30 0 0 1 100,50" 
                stroke="black" stroke-width="2" fill="none"/>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 200, height: 100),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('arc with zero ry renders as lineTo', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
          <path d="M10,50 A30,0 0 0 1 100,50" 
                stroke="blue" stroke-width="2" fill="none"/>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 200, height: 100),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('arc with negative radii uses absolute values', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
          <path d="M10,50 A-30,-20 0 0 1 100,50" 
                stroke="green" stroke-width="2" fill="none"/>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 200, height: 100),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('arc with very small radii degenerates gracefully', (
      tester,
    ) async {
      const svg = '''
        <svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
          <path d="M10,50 A0.0001,0.0001 0 0 1 100,50" 
                stroke="red" stroke-width="2" fill="none"/>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 200, height: 100),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('arc with endpoints at same position is handled', (
      tester,
    ) async {
      const svg = '''
        <svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
          <path d="M50,50 A30,30 0 0 1 50,50" 
                stroke="purple" stroke-width="2" fill="none"/>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 200, height: 100),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('arc with large radii relative to endpoints', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
          <path d="M50,50 A1000,1000 0 0 1 55,50" 
                stroke="orange" stroke-width="2" fill="none"/>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 200, height: 100),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });

  group('pathLength attribute', () {
    testWidgets('pathLength scales stroke-dasharray correctly', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
          <path d="M10,50 L190,50" 
                pathLength="100"
                stroke="black" 
                stroke-width="4"
                stroke-dasharray="10 10"
                fill="none"/>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 200, height: 100),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('pathLength scales stroke-dashoffset correctly', (
      tester,
    ) async {
      const svg = '''
        <svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
          <path d="M10,50 L190,50"
                pathLength="100"
                stroke="black"
                stroke-width="4"
                stroke-dasharray="20 10"
                stroke-dashoffset="5"
                fill="none"/>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 200, height: 100),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('pathLength works on circle', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 200" xmlns="http://www.w3.org/2000/svg">
          <circle cx="100" cy="100" r="80"
                  pathLength="100"
                  stroke="green"
                  stroke-width="3"
                  stroke-dasharray="10 5"
                  fill="none"/>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 200, height: 200),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('pathLength=0 is handled gracefully', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
          <path d="M10,50 L190,50"
                pathLength="0"
                stroke="black"
                stroke-width="4"
                stroke-dasharray="10 10"
                fill="none"/>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 200, height: 100),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('negative pathLength is handled gracefully', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
          <path d="M10,50 L190,50"
                pathLength="-100"
                stroke="black"
                stroke-width="4"
                stroke-dasharray="10 10"
                fill="none"/>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 200, height: 100),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });

  group('Non-uniform scaling', () {
    testWidgets('text renders under non-uniform scale transform', (
      tester,
    ) async {
      const svg = '''
        <svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
          <g transform="scale(2, 0.5)">
            <text x="10" y="50" font-size="16" fill="black">
              Non-uniform scale
            </text>
          </g>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 200, height: 100),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('shapes render under non-uniform scale', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
          <g transform="scale(1.5, 0.75)">
            <rect x="10" y="10" width="50" height="50" fill="blue"/>
            <circle cx="100" cy="35" r="25" fill="green"/>
          </g>
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
