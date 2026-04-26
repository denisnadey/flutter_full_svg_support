import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:full_svg_flutter/src/animation/animated_svg_picture.dart';
import 'package:full_svg_flutter/src/animation/smil/interpolators.dart';
import 'package:full_svg_flutter/src/animation/svg_transform.dart';
import 'package:flutter_test/flutter_test.dart';

import 'visual_test_utils.dart';

void main() {
  group('Transform-origin edge cases', () {
    testWidgets('transform-origin: top left keywords', (tester) async {
      const svg = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <rect x="25" y="25" width="50" height="50" fill="blue"
                transform="rotate(45)"
                style="transform-origin: top left"/>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 100, height: 100),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('transform-origin: bottom right keywords', (tester) async {
      const svg = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <rect x="25" y="25" width="50" height="50" fill="red"
                transform="scale(0.5)"
                style="transform-origin: bottom right"/>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 100, height: 100),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('transform-origin: 25% 75%', (tester) async {
      const svg = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <rect x="10" y="10" width="80" height="80" fill="green"
                transform="rotate(30)"
                style="transform-origin: 25% 75%"/>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 100, height: 100),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('transform-origin: three values (x y z)', (tester) async {
      const svg = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <rect x="25" y="25" width="50" height="50" fill="purple"
                transform="rotate(45)"
                style="transform-origin: 50% 50% 10px"/>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 100, height: 100),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('transform-origin with em units', (tester) async {
      const svg = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <rect x="0" y="0" width="50" height="50" fill="orange"
                transform="rotate(45)"
                style="transform-origin: 2em 1em"/>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 100, height: 100),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('transform-box: view-box', (tester) async {
      const svg = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <rect x="25" y="25" width="50" height="50" fill="cyan"
                transform="rotate(45)"
                style="transform-origin: 50% 50%; transform-box: view-box"/>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 100, height: 100),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('transform-box: fill-box', (tester) async {
      const svg = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <rect x="25" y="25" width="50" height="50" fill="magenta"
                transform="rotate(45)"
                style="transform-origin: 50% 50%; transform-box: fill-box"/>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 100, height: 100),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });

  group('Matrix decomposition', () {
    test('decomposes identity matrix correctly', () {
      final transforms = SvgTransform.parse('matrix(1, 0, 0, 1, 0, 0)');
      final decomp = TransformDecomposition.fromTransforms(transforms);

      expect(decomp.translateX, closeTo(0.0, 0.001));
      expect(decomp.translateY, closeTo(0.0, 0.001));
      expect(decomp.rotation, closeTo(0.0, 0.001));
      expect(decomp.scaleX, closeTo(1.0, 0.001));
      expect(decomp.scaleY, closeTo(1.0, 0.001));
      expect(decomp.skewX, closeTo(0.0, 0.001));
    });

    test('decomposes scale matrix correctly', () {
      final transforms = SvgTransform.parse('matrix(2, 0, 0, 3, 0, 0)');
      final decomp = TransformDecomposition.fromTransforms(transforms);

      expect(decomp.scaleX, closeTo(2.0, 0.001));
      expect(decomp.scaleY, closeTo(3.0, 0.001));
      expect(decomp.rotation, closeTo(0.0, 0.001));
    });

    test('decomposes 90 degree rotation matrix', () {
      // matrix(0, 1, -1, 0, 0, 0) = rotate(90deg)
      final transforms = SvgTransform.parse('matrix(0, 1, -1, 0, 0, 0)');
      final decomp = TransformDecomposition.fromTransforms(transforms);

      expect(decomp.rotation, closeTo(math.pi / 2, 0.001));
      expect(decomp.scaleX, closeTo(1.0, 0.001));
      expect(decomp.scaleY, closeTo(1.0, 0.001));
    });

    test('decomposes skewX matrix correctly', () {
      // matrix(1, 0, tan(45deg), 1, 0, 0)
      final transforms = SvgTransform.parse('matrix(1, 0, 1, 1, 0, 0)');
      final decomp = TransformDecomposition.fromTransforms(transforms);

      expect(decomp.skewX, closeTo(math.pi / 4, 0.01)); // 45 degrees
      expect(decomp.scaleX, closeTo(1.0, 0.001));
      expect(decomp.scaleY, closeTo(1.0, 0.001));
    });

    test('handles degenerate (zero determinant) matrix', () {
      // Zero determinant matrix (all zeros except translation)
      final transforms = SvgTransform.parse('matrix(0, 0, 0, 0, 10, 20)');
      final decomp = TransformDecomposition.fromTransforms(transforms);

      expect(decomp.translateX, closeTo(10.0, 0.001));
      expect(decomp.translateY, closeTo(20.0, 0.001));
      // Should not throw, should return graceful defaults
      expect(decomp.scaleX, closeTo(0.0, 0.001));
      expect(decomp.scaleY, closeTo(0.0, 0.001));
    });

    test('includes skewY in decomposition', () {
      final transforms = SvgTransform.parse('skewY(30)');
      final decomp = TransformDecomposition.fromTransforms(transforms);

      expect(decomp.skewY, closeTo(30 * math.pi / 180, 0.001));
    });

    test('lerp interpolates smoothly', () {
      final from = TransformDecomposition.fromTransforms(
        SvgTransform.parse('translate(0, 0) scale(1)'),
      );
      final to = TransformDecomposition.fromTransforms(
        SvgTransform.parse('translate(100, 100) scale(2)'),
      );

      // Test multiple interpolation points
      for (var t = 0.0; t <= 1.0; t += 0.1) {
        final lerped = from.lerp(to, t);
        expect(lerped.translateX, closeTo(100 * t, 0.01));
        expect(lerped.translateY, closeTo(100 * t, 0.01));
        expect(lerped.scaleX, closeTo(1 + t, 0.01));
        expect(lerped.scaleY, closeTo(1 + t, 0.01));
      }
    });

    test('lerp handles rotation shortest path', () {
      // Test that rotation interpolates via shortest path
      final from = TransformDecomposition.fromTransforms(
        SvgTransform.parse('rotate(10)'),
      );
      final to = TransformDecomposition.fromTransforms(
        SvgTransform.parse('rotate(350)'), // -10 degrees equivalent
      );

      final mid = from.lerp(to, 0.5);
      // Should go through 0/360 degrees, not through 180
      // (10 + 350) / 2 = 180 the wrong way, but shortest path: 0 or 360
      // Actually the shortest path from 10 to 350 is 10 -> 0 -> 350
      // At t=0.5, should be around 0 or 360
      final midDegrees = mid.rotation * 180 / math.pi;
      // Normalize to 0-360 range
      final normalized = ((midDegrees % 360) + 360) % 360;
      // Should be closer to 0/360 than to 180
      expect(normalized < 20 || normalized > 340, isTrue);
    });
  });

  group('Complex shorthand parsing', () {
    test('parses multiple transform functions', () {
      final transforms = SvgTransform.parse(
        'translate(10px, 20px) rotate(45deg) scale(1.5)',
      );

      expect(transforms.length, 3);
      expect(transforms[0].type, SvgTransformType.translate);
      expect(transforms[0].values[0], closeTo(10.0, 0.001));
      expect(transforms[0].values[1], closeTo(20.0, 0.001));
      expect(transforms[1].type, SvgTransformType.rotate);
      expect(transforms[1].values[0], closeTo(45.0, 0.001));
      expect(transforms[2].type, SvgTransformType.scale);
      expect(transforms[2].values[0], closeTo(1.5, 0.001));
    });

    test('parses angle units correctly', () {
      // bare number works (already tested elsewhere)
      final bare = SvgTransform.parse('rotate(45)');
      expect(bare.length, 1);
      expect(bare[0].type, SvgTransformType.rotate);
      expect(bare[0].values[0], closeTo(45.0, 0.01));

      // 90deg should convert to 90 degrees
      final deg = SvgTransform.parse('rotate(90deg)');
      expect(deg.length, 1);
      expect(deg[0].type, SvgTransformType.rotate);
      expect(deg[0].values.isNotEmpty, isTrue);
      // Note: The current implementation parses 90deg as 90 (value already in degrees)
      expect(deg[0].values[0], closeTo(90.0, 0.01));
    });

    test('parses length units correctly', () {
      final transforms = SvgTransform.parse('translate(1em, 2rem)');
      expect(transforms[0].values[0], closeTo(16.0, 0.001)); // 1em = 16px
      expect(transforms[0].values[1], closeTo(32.0, 0.001)); // 2rem = 32px
    });

    test('parses percentage values', () {
      final transforms = SvgTransform.parse('translate(50%, 100%)');
      // Percentages are parsed as the numeric value
      expect(transforms[0].values[0], closeTo(50.0, 0.001));
      expect(transforms[0].values[1], closeTo(100.0, 0.001));
    });
  });

  group('Transform animation edge cases', () {
    test('interpolates from none to transform', () {
      final result = Interpolators.interpolateTransform(
        'none',
        'translate(100, 100)',
        0.5,
      );

      final transforms = SvgTransform.parse(result);
      expect(transforms.isNotEmpty, isTrue);
      // At t=0.5, should be halfway
      final translate = transforms.firstWhere(
        (t) => t.type == SvgTransformType.translate,
        orElse: () =>
            SvgTransform(type: SvgTransformType.translate, values: [0, 0]),
      );
      expect(translate.values[0], closeTo(50.0, 1.0));
      expect(translate.values[1], closeTo(50.0, 1.0));
    });

    test('interpolates from transform to none', () {
      final result = Interpolators.interpolateTransform(
        'scale(2)',
        'none',
        0.5,
      );

      final transforms = SvgTransform.parse(result);
      expect(transforms.isNotEmpty, isTrue);
    });

    test('interpolates between none and none', () {
      final result = Interpolators.interpolateTransform('none', 'none', 0.5);

      // Should return identity transform
      expect(result.contains('translate') || result.isEmpty, isTrue);
    });

    test('interpolates empty string as none', () {
      final result = Interpolators.interpolateTransform('', 'rotate(90)', 0.5);

      final transforms = SvgTransform.parse(result);
      expect(transforms.isNotEmpty, isTrue);
    });
  });

  group('CSS transform property vs SVG attribute', () {
    testWidgets('CSS transform property is applied', (tester) async {
      const svg = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <style>
            .rotated { transform: rotate(45deg); }
          </style>
          <rect class="rotated" x="25" y="25" width="50" height="50" fill="red"/>
        </svg>
      ''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RepaintBoundary(
              child: AnimatedSvgPicture.string(svg, width: 100, height: 100),
            ),
          ),
        ),
      );

      await tester.pump();

      final pixels = await VisualTestUtils.captureWidgetPixels(tester);
      final analysis = VisualTestUtils.analyzeRedPixels(pixels, 800, 600);

      expect(analysis.pixelCount, greaterThan(0));
    });

    testWidgets('transform: none is handled', (tester) async {
      const svg = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <rect x="25" y="25" width="50" height="50" fill="blue"
                style="transform: none"/>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 100, height: 100),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });

  group('Nested transform contexts', () {
    testWidgets('nested groups with transforms compose correctly', (
      tester,
    ) async {
      const svg = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <g transform="translate(10, 10)">
            <g transform="rotate(45 50 50)">
              <g transform="scale(0.8)">
                <rect x="25" y="25" width="50" height="50" fill="red"/>
              </g>
            </g>
          </g>
        </svg>
      ''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RepaintBoundary(
              child: AnimatedSvgPicture.string(svg, width: 100, height: 100),
            ),
          ),
        ),
      );

      await tester.pump();

      final pixels = await VisualTestUtils.captureWidgetPixels(tester);
      final analysis = VisualTestUtils.analyzeRedPixels(pixels, 800, 600);

      expect(analysis.pixelCount, greaterThan(0));
    });

    testWidgets('viewBox with nested transform', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 200" xmlns="http://www.w3.org/2000/svg" width="100" height="100">
          <g transform="translate(50, 50)">
            <rect x="0" y="0" width="100" height="100" fill="red"/>
          </g>
        </svg>
      ''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RepaintBoundary(
              child: AnimatedSvgPicture.string(svg, width: 100, height: 100),
            ),
          ),
        ),
      );

      await tester.pump();

      final pixels = await VisualTestUtils.captureWidgetPixels(tester);
      final analysis = VisualTestUtils.analyzeRedPixels(pixels, 800, 600);

      expect(analysis.pixelCount, greaterThan(0));
    });
  });

  group('3D transform handling', () {
    testWidgets('rotateX renders (flattened to 2D)', (tester) async {
      const svg = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <rect x="25" y="25" width="50" height="50" fill="red"
                transform="rotateX(30)"/>
        </svg>
      ''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RepaintBoundary(
              child: AnimatedSvgPicture.string(svg, width: 100, height: 100),
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('rotateY renders (flattened to 2D)', (tester) async {
      const svg = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <rect x="25" y="25" width="50" height="50" fill="red"
                transform="rotateY(30)"/>
        </svg>
      ''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RepaintBoundary(
              child: AnimatedSvgPicture.string(svg, width: 100, height: 100),
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('perspective transform', (tester) async {
      const svg = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <rect x="25" y="25" width="50" height="50" fill="blue"
                style="perspective: 500px"
                transform="rotateY(30)"/>
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
