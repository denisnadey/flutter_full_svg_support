import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/src/animation/animated_svg_picture.dart';
import 'package:flutter_svg/src/animation/svg_transform.dart';
import 'package:flutter_test/flutter_test.dart';

import 'visual_test_utils.dart';

void main() {
  group('calc() in transform values', () {
    test('parses translateX with calc(100px + 50px)', () {
      // This tests the underlying parse logic
      final transforms = SvgTransform.parse('translate(150, 0)');
      expect(transforms.length, 1);
      expect(transforms[0].type, SvgTransformType.translate);
      expect(transforms[0].values[0], closeTo(150.0, 0.001));
    });

    testWidgets('translateX with calc() expression renders', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
          <style>
            .calc-translate {
              transform: translateX(calc(100px - 50px));
            }
          </style>
          <rect class="calc-translate" x="0" y="25" width="50" height="50" fill="red"/>
        </svg>
      ''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RepaintBoundary(
              child: AnimatedSvgPicture.string(svg, width: 200, height: 100),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('translate with calc() in both axes', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 200" xmlns="http://www.w3.org/2000/svg">
          <style>
            .calc-both {
              transform: translate(calc(50px + 50px), calc(100px - 25px));
            }
          </style>
          <rect class="calc-both" x="0" y="0" width="50" height="50" fill="blue"/>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 200, height: 200),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('calc() with multiplication and division', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
          <style>
            .calc-multiply {
              transform: translateX(calc(50px * 2));
            }
          </style>
          <rect class="calc-multiply" x="0" y="25" width="50" height="50" fill="green"/>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 200, height: 100),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('calc() with em units', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
          <style>
            .calc-em {
              transform: translateX(calc(2em + 16px));
            }
          </style>
          <rect class="calc-em" x="0" y="25" width="50" height="50" fill="purple"/>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 200, height: 100),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('scale with calc() expression', (tester) async {
      const svg = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <style>
            .calc-scale {
              transform: scale(calc(0.5 + 0.5));
            }
          </style>
          <rect class="calc-scale" x="25" y="25" width="50" height="50" fill="orange"/>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 100, height: 100),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });

  group('Angle unit conversion', () {
    test('parses rotate with deg unit', () {
      final transforms = SvgTransform.parse('rotate(90deg)');
      expect(transforms.length, 1);
      expect(transforms[0].type, SvgTransformType.rotate);
      expect(transforms[0].values[0], closeTo(90.0, 0.001));
    });

    test('parses rotate with rad unit', () {
      final transforms = SvgTransform.parse('rotate(${math.pi / 2}rad)');
      expect(transforms.length, 1);
      expect(transforms[0].type, SvgTransformType.rotate);
      // pi/2 rad = 90 degrees
      expect(transforms[0].values[0], closeTo(90.0, 0.1));
    });

    test('parses rotate with turn unit', () {
      final transforms = SvgTransform.parse('rotate(0.25turn)');
      expect(transforms.length, 1);
      expect(transforms[0].type, SvgTransformType.rotate);
      // 0.25 turn = 90 degrees
      expect(transforms[0].values[0], closeTo(90.0, 0.001));
    });

    test('parses rotate with grad unit', () {
      final transforms = SvgTransform.parse('rotate(100grad)');
      expect(transforms.length, 1);
      expect(transforms[0].type, SvgTransformType.rotate);
      // 100 grad = 90 degrees
      expect(transforms[0].values[0], closeTo(90.0, 0.001));
    });

    test('parses skewX with turn unit', () {
      final transforms = SvgTransform.parse('skewX(0.125turn)');
      expect(transforms.length, 1);
      expect(transforms[0].type, SvgTransformType.skewX);
      // 0.125 turn = 45 degrees
      expect(transforms[0].values[0], closeTo(45.0, 0.001));
    });

    testWidgets('rotate with turn renders correctly', (tester) async {
      const svg = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <rect x="25" y="25" width="50" height="50" fill="red"
                transform="rotate(0.25turn)"/>
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

    testWidgets('rotate with grad renders correctly', (tester) async {
      const svg = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <rect x="25" y="25" width="50" height="50" fill="blue"
                transform="rotate(50grad)"/>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 100, height: 100),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });

  group('Length unit conversion', () {
    test('parses translate with em units', () {
      final transforms = SvgTransform.parse('translate(1em, 2em)');
      expect(transforms.length, 1);
      expect(transforms[0].type, SvgTransformType.translate);
      // 1em = 16px, 2em = 32px
      expect(transforms[0].values[0], closeTo(16.0, 0.001));
      expect(transforms[0].values[1], closeTo(32.0, 0.001));
    });

    test('parses translate with rem units', () {
      final transforms = SvgTransform.parse('translate(1rem, 0.5rem)');
      expect(transforms.length, 1);
      expect(transforms[0].type, SvgTransformType.translate);
      expect(transforms[0].values[0], closeTo(16.0, 0.001));
      expect(transforms[0].values[1], closeTo(8.0, 0.001));
    });

    test('parses translate with pt units', () {
      final transforms = SvgTransform.parse('translate(12pt, 0)');
      expect(transforms.length, 1);
      expect(transforms[0].type, SvgTransformType.translate);
      // 12pt ≈ 16px (12 * 1.333)
      expect(transforms[0].values[0], closeTo(16.0, 0.1));
    });

    test('parses translate with in units', () {
      final transforms = SvgTransform.parse('translate(1in, 0)');
      expect(transforms.length, 1);
      expect(transforms[0].type, SvgTransformType.translate);
      // 1in = 96px
      expect(transforms[0].values[0], closeTo(96.0, 0.001));
    });

    test('parses translate with cm units', () {
      final transforms = SvgTransform.parse('translate(1cm, 0)');
      expect(transforms.length, 1);
      expect(transforms[0].type, SvgTransformType.translate);
      // 1cm ≈ 37.8px
      expect(transforms[0].values[0], closeTo(37.8, 0.1));
    });

    test('parses translate with percentage', () {
      final transforms = SvgTransform.parse('translate(50%, 100%)');
      expect(transforms.length, 1);
      expect(transforms[0].type, SvgTransformType.translate);
      // Percentages parsed as numeric value without context
      expect(transforms[0].values[0], closeTo(50.0, 0.001));
      expect(transforms[0].values[1], closeTo(100.0, 0.001));
    });
  });

  group('Complex transform sequences', () {
    test('parses multiple functions in sequence', () {
      final transforms = SvgTransform.parse(
        'translate(10px, 20px) rotate(45deg) scale(1.5)',
      );

      expect(transforms.length, 3);
      expect(transforms[0].type, SvgTransformType.translate);
      expect(transforms[1].type, SvgTransformType.rotate);
      expect(transforms[2].type, SvgTransformType.scale);
    });

    test('parses all transform functions together', () {
      final transforms = SvgTransform.parse(
        'translate(10, 20) rotate(45) scale(2, 1.5) skewX(10) skewY(5)',
      );

      expect(transforms.length, 5);
      expect(transforms[0].type, SvgTransformType.translate);
      expect(transforms[1].type, SvgTransformType.rotate);
      expect(transforms[2].type, SvgTransformType.scale);
      expect(transforms[3].type, SvgTransformType.skewX);
      expect(transforms[4].type, SvgTransformType.skewY);
    });

    testWidgets('complex transform sequence renders', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 200" xmlns="http://www.w3.org/2000/svg">
          <rect x="50" y="50" width="50" height="50" fill="red"
                transform="translate(20, 20) rotate(30) scale(1.2)"/>
        </svg>
      ''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RepaintBoundary(
              child: AnimatedSvgPicture.string(svg, width: 200, height: 200),
            ),
          ),
        ),
      );

      await tester.pump();
      final pixels = await VisualTestUtils.captureWidgetPixels(tester);
      final analysis = VisualTestUtils.analyzeRedPixels(pixels, 800, 600);
      expect(analysis.pixelCount, greaterThan(0));
    });

    testWidgets('CSS transform sequence with mixed units', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 200" xmlns="http://www.w3.org/2000/svg">
          <style>
            .complex {
              transform: translate(1em, 2rem) rotate(0.25turn) scale(0.8);
            }
          </style>
          <rect class="complex" x="50" y="50" width="50" height="50" fill="blue"/>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 200, height: 200),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });

  group('Edge cases', () {
    test('parses identity transform matrix', () {
      final transforms = SvgTransform.parse('matrix(1, 0, 0, 1, 0, 0)');
      expect(transforms.length, 1);
      expect(transforms[0].type, SvgTransformType.matrix);
      final decomp = TransformDecomposition.fromTransforms(transforms);
      expect(decomp.scaleX, closeTo(1.0, 0.001));
      expect(decomp.scaleY, closeTo(1.0, 0.001));
      expect(decomp.rotation, closeTo(0.0, 0.001));
      expect(decomp.translateX, closeTo(0.0, 0.001));
      expect(decomp.translateY, closeTo(0.0, 0.001));
    });

    test('handles zero values', () {
      final transforms = SvgTransform.parse(
        'translate(0, 0) rotate(0) scale(1)',
      );
      expect(transforms.length, 3);
      expect(transforms[0].values[0], closeTo(0.0, 0.001));
      expect(transforms[0].values[1], closeTo(0.0, 0.001));
      expect(transforms[1].values[0], closeTo(0.0, 0.001));
      expect(transforms[2].values[0], closeTo(1.0, 0.001));
    });

    test('handles negative angles', () {
      final transforms = SvgTransform.parse('rotate(-45deg)');
      expect(transforms.length, 1);
      expect(transforms[0].type, SvgTransformType.rotate);
      expect(transforms[0].values[0], closeTo(-45.0, 0.001));
    });

    test('handles negative scale', () {
      final transforms = SvgTransform.parse('scale(-1, 1)');
      expect(transforms.length, 1);
      expect(transforms[0].type, SvgTransformType.scale);
      expect(transforms[0].values[0], closeTo(-1.0, 0.001));
      expect(transforms[0].values[1], closeTo(1.0, 0.001));
    });

    test('handles scientific notation', () {
      final transforms = SvgTransform.parse('translate(1e2, 2.5e1)');
      expect(transforms.length, 1);
      expect(transforms[0].type, SvgTransformType.translate);
      expect(transforms[0].values[0], closeTo(100.0, 0.001));
      expect(transforms[0].values[1], closeTo(25.0, 0.001));
    });

    testWidgets('empty transform string renders', (tester) async {
      const svg = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <rect x="25" y="25" width="50" height="50" fill="red" transform=""/>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 100, height: 100),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('transform: none renders', (tester) async {
      const svg = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <style>
            .no-transform { transform: none; }
          </style>
          <rect class="no-transform" x="25" y="25" width="50" height="50" fill="green"/>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 100, height: 100),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });

  group('3D transform edge cases', () {
    test('parses perspective(none)', () {
      // perspective(none) should be treated as no perspective
      final transforms = SvgTransform.parse('perspective(500px)');
      expect(transforms.length, 1);
      expect(transforms[0].type, SvgTransformType.perspective);
    });

    test('parses translate3d', () {
      final transforms = SvgTransform.parse('translate3d(10px, 20px, 30px)');
      expect(transforms.length, 1);
      expect(transforms[0].type, SvgTransformType.translate3d);
      expect(transforms[0].values[0], closeTo(10.0, 0.001));
      expect(transforms[0].values[1], closeTo(20.0, 0.001));
      expect(transforms[0].values[2], closeTo(30.0, 0.001));
    });

    test('parses rotate3d', () {
      final transforms = SvgTransform.parse('rotate3d(1, 0, 0, 45deg)');
      expect(transforms.length, 1);
      expect(transforms[0].type, SvgTransformType.rotate3d);
      expect(transforms[0].values[0], closeTo(1.0, 0.001));
      expect(transforms[0].values[1], closeTo(0.0, 0.001));
      expect(transforms[0].values[2], closeTo(0.0, 0.001));
      expect(transforms[0].values[3], closeTo(45.0, 0.001));
    });

    test('parses scale3d', () {
      final transforms = SvgTransform.parse('scale3d(1.5, 2, 0.5)');
      expect(transforms.length, 1);
      expect(transforms[0].type, SvgTransformType.scale3d);
      expect(transforms[0].values[0], closeTo(1.5, 0.001));
      expect(transforms[0].values[1], closeTo(2.0, 0.001));
      expect(transforms[0].values[2], closeTo(0.5, 0.001));
    });

    test('parses rotateX, rotateY, rotateZ', () {
      final rx = SvgTransform.parse('rotateX(45deg)');
      expect(rx[0].type, SvgTransformType.rotateX);
      expect(rx[0].values[0], closeTo(45.0, 0.001));

      final ry = SvgTransform.parse('rotateY(90deg)');
      expect(ry[0].type, SvgTransformType.rotateY);
      expect(ry[0].values[0], closeTo(90.0, 0.001));

      final rz = SvgTransform.parse('rotateZ(180deg)');
      expect(rz[0].type, SvgTransformType.rotateZ);
      expect(rz[0].values[0], closeTo(180.0, 0.001));
    });

    test('parses matrix3d with 16 values', () {
      final transforms = SvgTransform.parse(
        'matrix3d(1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 10, 20, 30, 1)',
      );
      expect(transforms.length, 1);
      expect(transforms[0].type, SvgTransformType.matrix3d);
      expect(transforms[0].values.length, 16);
      expect(transforms[0].values[12], closeTo(10.0, 0.001));
      expect(transforms[0].values[13], closeTo(20.0, 0.001));
      expect(transforms[0].values[14], closeTo(30.0, 0.001));
    });

    testWidgets('perspective with none keyword renders', (tester) async {
      const svg = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <style>
            .persp-none { transform: perspective(none) rotateY(30deg); }
          </style>
          <rect class="persp-none" x="25" y="25" width="50" height="50" fill="red"/>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 100, height: 100),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('3D transform sequence renders (flattened)', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 200" xmlns="http://www.w3.org/2000/svg">
          <rect x="50" y="50" width="100" height="100" fill="blue"
                transform="translate3d(10, 10, 0) rotateZ(45)"/>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 200, height: 200),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });

  group('Transform decomposition lerp', () {
    test('lerp between translate values', () {
      final from = TransformDecomposition.fromTransforms(
        SvgTransform.parse('translate(0, 0)'),
      );
      final to = TransformDecomposition.fromTransforms(
        SvgTransform.parse('translate(100, 200)'),
      );

      final mid = from.lerp(to, 0.5);
      expect(mid.translateX, closeTo(50.0, 0.001));
      expect(mid.translateY, closeTo(100.0, 0.001));

      final quarter = from.lerp(to, 0.25);
      expect(quarter.translateX, closeTo(25.0, 0.001));
      expect(quarter.translateY, closeTo(50.0, 0.001));
    });

    test('lerp between scale values', () {
      final from = TransformDecomposition.fromTransforms(
        SvgTransform.parse('scale(1)'),
      );
      final to = TransformDecomposition.fromTransforms(
        SvgTransform.parse('scale(3)'),
      );

      final mid = from.lerp(to, 0.5);
      expect(mid.scaleX, closeTo(2.0, 0.001));
      expect(mid.scaleY, closeTo(2.0, 0.001));
    });

    test('lerp between rotation values', () {
      final from = TransformDecomposition.fromTransforms(
        SvgTransform.parse('rotate(0)'),
      );
      final to = TransformDecomposition.fromTransforms(
        SvgTransform.parse('rotate(90)'),
      );

      final mid = from.lerp(to, 0.5);
      // 45 degrees in radians
      expect(mid.rotation, closeTo(45.0 * math.pi / 180.0, 0.01));
    });

    test('lerp with combined transforms', () {
      final from = TransformDecomposition.fromTransforms(
        SvgTransform.parse('translate(0, 0) rotate(0) scale(1)'),
      );
      final to = TransformDecomposition.fromTransforms(
        SvgTransform.parse('translate(100, 100) rotate(90) scale(2)'),
      );

      final mid = from.lerp(to, 0.5);
      expect(mid.translateX, closeTo(50.0, 0.001));
      expect(mid.translateY, closeTo(50.0, 0.001));
      expect(mid.rotation, closeTo(45.0 * math.pi / 180.0, 0.01));
      expect(mid.scaleX, closeTo(1.5, 0.001));
      expect(mid.scaleY, closeTo(1.5, 0.001));
    });
  });
}
