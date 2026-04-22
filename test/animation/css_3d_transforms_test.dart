import 'dart:math' as math;

import 'package:full_svg_flutter/src/animation/svg_transform.dart';
import 'package:full_svg_flutter/src/animation/transform_3d.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Matrix4x4', () {
    test('identity matrix', () {
      final matrix = Matrix4x4.identity();

      expect(matrix.get(0, 0), 1.0);
      expect(matrix.get(1, 1), 1.0);
      expect(matrix.get(2, 2), 1.0);
      expect(matrix.get(3, 3), 1.0);
      expect(matrix.get(0, 1), 0.0);
      expect(matrix.get(1, 0), 0.0);
    });

    test('translation matrix', () {
      final matrix = Matrix4x4.translation(10, 20, 30);

      // Translation values should be in the last column
      expect(matrix.get(0, 3), 10.0);
      expect(matrix.get(1, 3), 20.0);
      expect(matrix.get(2, 3), 30.0);
    });

    test('scale matrix', () {
      final matrix = Matrix4x4.scale(2, 3, 4);

      expect(matrix.get(0, 0), 2.0);
      expect(matrix.get(1, 1), 3.0);
      expect(matrix.get(2, 2), 4.0);
    });

    test('rotation around Z axis', () {
      final matrix = Matrix4x4.rotationZ(math.pi / 2); // 90 degrees

      // Rotation of 90 degrees around Z axis:
      // cos(90) = 0, sin(90) = 1
      expect(matrix.get(0, 0), closeTo(0, 1e-10));
      expect(matrix.get(0, 1), closeTo(-1, 1e-10));
      expect(matrix.get(1, 0), closeTo(1, 1e-10));
      expect(matrix.get(1, 1), closeTo(0, 1e-10));
    });

    test('rotation around X axis', () {
      final matrix = Matrix4x4.rotationX(math.pi / 2); // 90 degrees

      expect(matrix.get(1, 1), closeTo(0, 1e-10));
      expect(matrix.get(1, 2), closeTo(-1, 1e-10));
      expect(matrix.get(2, 1), closeTo(1, 1e-10));
      expect(matrix.get(2, 2), closeTo(0, 1e-10));
    });

    test('rotation around Y axis', () {
      final matrix = Matrix4x4.rotationY(math.pi / 2); // 90 degrees

      expect(matrix.get(0, 0), closeTo(0, 1e-10));
      expect(matrix.get(0, 2), closeTo(1, 1e-10));
      expect(matrix.get(2, 0), closeTo(-1, 1e-10));
      expect(matrix.get(2, 2), closeTo(0, 1e-10));
    });

    test('matrix multiplication', () {
      final translate = Matrix4x4.translation(10, 0, 0);
      final scale = Matrix4x4.scale(2, 2, 2);

      final result = translate * scale;

      // Translation then scale: translate values scaled by 2
      expect(result.get(0, 0), 2.0);
      expect(result.get(0, 3), 10.0); // Translation preserved
    });

    test('perspective matrix', () {
      final matrix = Matrix4x4.perspective(1000);

      expect(matrix.get(3, 2), closeTo(-0.001, 1e-6));
    });

    test('extract 2D matrix from identity', () {
      final matrix = Matrix4x4.identity();
      final result = matrix.extract2DMatrix();

      expect(result[0], 1.0); // a
      expect(result[1], 0.0); // b
      expect(result[2], 0.0); // c
      expect(result[3], 1.0); // d
      expect(result[4], 0.0); // e
      expect(result[5], 0.0); // f
    });

    test('extract 2D matrix from translation', () {
      final matrix = Matrix4x4.translation(50, 100, 0);
      final result = matrix.extract2DMatrix();

      expect(result[4], 50.0); // e = tx
      expect(result[5], 100.0); // f = ty
    });

    test('extract 2D matrix from Z rotation', () {
      final matrix = Matrix4x4.rotationZ(math.pi / 4); // 45 degrees
      final result = matrix.extract2DMatrix();

      // cos(45) ≈ 0.707, sin(45) ≈ 0.707
      expect(result[0], closeTo(math.cos(math.pi / 4), 1e-10)); // a
      expect(result[1], closeTo(math.sin(math.pi / 4), 1e-10)); // b
      expect(result[2], closeTo(-math.sin(math.pi / 4), 1e-10)); // c
      expect(result[3], closeTo(math.cos(math.pi / 4), 1e-10)); // d
    });

    test('isBackfacing detects backface', () {
      // Identity matrix - facing forward
      final front = Matrix4x4.identity();
      expect(front.isBackfacing(), false);

      // Rotated 180 degrees around Y axis - facing backward
      final back = Matrix4x4.rotationY(math.pi);
      expect(back.isBackfacing(), true);

      // Rotated 90 degrees - edge case
      final edge = Matrix4x4.rotationY(math.pi / 2);
      expect(edge.isBackfacing(), false); // cos(90) = 0, not negative
    });

    test('fromMatrix3d creates correct matrix', () {
      // Identity matrix3d
      final values = [
        1.0,
        0.0,
        0.0,
        0.0,
        0.0,
        1.0,
        0.0,
        0.0,
        0.0,
        0.0,
        1.0,
        0.0,
        0.0,
        0.0,
        0.0,
        1.0,
      ];
      final matrix = Matrix4x4.fromMatrix3d(values);

      expect(matrix.get(0, 0), 1.0);
      expect(matrix.get(1, 1), 1.0);
      expect(matrix.get(2, 2), 1.0);
      expect(matrix.get(3, 3), 1.0);
    });

    test('from2dMatrix creates correct 4x4 matrix', () {
      // 2D translate matrix(1, 0, 0, 1, 10, 20)
      final values = [1.0, 0.0, 0.0, 1.0, 10.0, 20.0];
      final matrix = Matrix4x4.from2dMatrix(values);

      expect(matrix.get(0, 0), 1.0);
      expect(matrix.get(1, 1), 1.0);
      expect(matrix.get(2, 2), 1.0);
      expect(matrix.get(3, 3), 1.0);
      expect(matrix.get(0, 3), 10.0); // tx
      expect(matrix.get(1, 3), 20.0); // ty
    });

    test('transform2D projects point correctly', () {
      // Translation matrix
      final translate = Matrix4x4.translation(10, 20, 0);
      final point = translate.transform2D(5, 5, 0);

      expect(point.dx, 15.0);
      expect(point.dy, 25.0);
    });

    test('transform2D with perspective', () {
      final perspective = Matrix4x4.perspective(1000);
      final translate = Matrix4x4.translation(
        0,
        0,
        500,
      ); // Move halfway to perspective

      final combined = perspective * translate;
      final point = combined.transform2D(100, 100, 0);

      // With z=500 and perspective=1000, w = 1 - 500/1000 = 0.5
      // So x' = 100/0.5 = 200, y' = 100/0.5 = 200
      expect(point.dx, closeTo(200, 1));
      expect(point.dy, closeTo(200, 1));
    });
  });

  group('SvgTransform 3D parsing', () {
    test('parses translate3d', () {
      final transforms = SvgTransform.parse('translate3d(10, 20, 30)');

      expect(transforms.length, 1);
      expect(transforms[0].type, SvgTransformType.translate3d);
      expect(transforms[0].values, [10.0, 20.0, 30.0]);
    });

    test('parses translateZ', () {
      final transforms = SvgTransform.parse('translateZ(50)');

      expect(transforms.length, 1);
      expect(transforms[0].type, SvgTransformType.translateZ);
      expect(transforms[0].values, [50.0]);
    });

    test('parses rotateX', () {
      final transforms = SvgTransform.parse('rotateX(45deg)');

      expect(transforms.length, 1);
      expect(transforms[0].type, SvgTransformType.rotateX);
      expect(transforms[0].values, [45.0]);
    });

    test('parses rotateY', () {
      final transforms = SvgTransform.parse('rotateY(90deg)');

      expect(transforms.length, 1);
      expect(transforms[0].type, SvgTransformType.rotateY);
      expect(transforms[0].values, [90.0]);
    });

    test('parses rotateZ', () {
      final transforms = SvgTransform.parse('rotateZ(180deg)');

      expect(transforms.length, 1);
      expect(transforms[0].type, SvgTransformType.rotateZ);
      expect(transforms[0].values, [180.0]);
    });

    test('parses rotate3d', () {
      final transforms = SvgTransform.parse('rotate3d(1, 0, 0, 45deg)');

      expect(transforms.length, 1);
      expect(transforms[0].type, SvgTransformType.rotate3d);
      expect(transforms[0].values, [1.0, 0.0, 0.0, 45.0]);
    });

    test('parses scale3d', () {
      final transforms = SvgTransform.parse('scale3d(2, 3, 4)');

      expect(transforms.length, 1);
      expect(transforms[0].type, SvgTransformType.scale3d);
      expect(transforms[0].values, [2.0, 3.0, 4.0]);
    });

    test('parses scaleZ', () {
      final transforms = SvgTransform.parse('scaleZ(2)');

      expect(transforms.length, 1);
      expect(transforms[0].type, SvgTransformType.scaleZ);
      expect(transforms[0].values, [2.0]);
    });

    test('parses perspective', () {
      final transforms = SvgTransform.parse('perspective(1000px)');

      expect(transforms.length, 1);
      expect(transforms[0].type, SvgTransformType.perspective);
      expect(transforms[0].values, [1000.0]);
    });

    test('parses matrix3d', () {
      final transforms = SvgTransform.parse(
        'matrix3d(1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 10, 20, 30, 1)',
      );

      expect(transforms.length, 1);
      expect(transforms[0].type, SvgTransformType.matrix3d);
      expect(transforms[0].values.length, 16);
      expect(transforms[0].values[0], 1.0);
      expect(transforms[0].values[12], 10.0);
      expect(transforms[0].values[13], 20.0);
      expect(transforms[0].values[14], 30.0);
    });

    test('parses combined 2D and 3D transforms', () {
      final transforms = SvgTransform.parse(
        'translate(10, 20) rotateX(45deg) scale(2)',
      );

      expect(transforms.length, 3);
      expect(transforms[0].type, SvgTransformType.translate);
      expect(transforms[1].type, SvgTransformType.rotateX);
      expect(transforms[2].type, SvgTransformType.scale);
    });

    test('parses angle with rad unit', () {
      final transforms = SvgTransform.parse('rotateX(${math.pi / 2}rad)');

      expect(transforms.length, 1);
      expect(transforms[0].type, SvgTransformType.rotateX);
      expect(transforms[0].values[0], closeTo(90, 0.01)); // pi/2 rad = 90 deg
    });

    test('parses angle with turn unit', () {
      final transforms = SvgTransform.parse('rotateY(0.25turn)');

      expect(transforms.length, 1);
      expect(transforms[0].type, SvgTransformType.rotateY);
      expect(transforms[0].values[0], closeTo(90, 0.01)); // 0.25 turn = 90 deg
    });

    test('handles case insensitivity', () {
      final transforms = SvgTransform.parse('ROTATEX(45) TRANSLATEZ(100)');

      expect(transforms.length, 2);
      expect(transforms[0].type, SvgTransformType.rotateX);
      expect(transforms[1].type, SvgTransformType.translateZ);
    });
  });

  group('TransformDecomposition 3D', () {
    test('decomposes translate3d', () {
      final transforms = SvgTransform.parse('translate3d(10, 20, 30)');
      final decomp = TransformDecomposition.fromTransforms(transforms);

      // X and Y should be extracted, Z ignored for 2D
      expect(decomp.translateX, 10.0);
      expect(decomp.translateY, 20.0);
    });

    test('decomposes rotateX projection', () {
      final transforms = SvgTransform.parse('rotateX(45)');
      final decomp = TransformDecomposition.fromTransforms(transforms);

      // rotateX affects Y scale in 2D projection
      // cos(45) ≈ 0.707
      expect(decomp.scaleY, closeTo(math.cos(45 * math.pi / 180), 0.01));
    });

    test('decomposes rotateY projection', () {
      final transforms = SvgTransform.parse('rotateY(45)');
      final decomp = TransformDecomposition.fromTransforms(transforms);

      // rotateY affects X scale in 2D projection
      expect(decomp.scaleX, closeTo(math.cos(45 * math.pi / 180), 0.01));
    });

    test('decomposes rotateZ as regular rotate', () {
      final transforms = SvgTransform.parse('rotateZ(90)');
      final decomp = TransformDecomposition.fromTransforms(transforms);

      expect(decomp.rotation, closeTo(math.pi / 2, 0.01));
    });

    test('decomposes scale3d', () {
      final transforms = SvgTransform.parse('scale3d(2, 3, 4)');
      final decomp = TransformDecomposition.fromTransforms(transforms);

      expect(decomp.scaleX, 2.0);
      expect(decomp.scaleY, 3.0);
      // Z scale is ignored in 2D
    });

    test('decomposes matrix3d identity', () {
      final transforms = SvgTransform.parse(
        'matrix3d(1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)',
      );
      final decomp = TransformDecomposition.fromTransforms(transforms);

      expect(decomp.translateX, 0.0);
      expect(decomp.translateY, 0.0);
      expect(decomp.rotation, closeTo(0, 0.01));
      expect(decomp.scaleX, closeTo(1.0, 0.01));
      expect(decomp.scaleY, closeTo(1.0, 0.01));
    });

    test('decomposes matrix3d with translation', () {
      final transforms = SvgTransform.parse(
        'matrix3d(1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 100, 200, 0, 1)',
      );
      final decomp = TransformDecomposition.fromTransforms(transforms);

      expect(decomp.translateX, closeTo(100.0, 0.01));
      expect(decomp.translateY, closeTo(200.0, 0.01));
    });
  });

  group('Transform3DContext', () {
    test('creates perspective matrix', () {
      final context = Transform3DContext(
        perspective: 1000,
        perspectiveOriginX: 0.5,
        perspectiveOriginY: 0.5,
      );

      final matrix = context.createPerspectiveMatrix(200, 200);
      expect(matrix, isNotNull);
    });

    test('returns null for no perspective', () {
      final context = Transform3DContext();
      final matrix = context.createPerspectiveMatrix(200, 200);
      expect(matrix, isNull);
    });

    test('returns null for invalid perspective', () {
      final context = Transform3DContext(perspective: 0);
      final matrix = context.createPerspectiveMatrix(200, 200);
      expect(matrix, isNull);

      final context2 = Transform3DContext(perspective: -100);
      final matrix2 = context2.createPerspectiveMatrix(200, 200);
      expect(matrix2, isNull);
    });
  });

  group('BackfaceVisibility', () {
    test('visible is default', () {
      expect(BackfaceVisibility.visible, BackfaceVisibility.visible);
    });

    test('hidden value exists', () {
      expect(BackfaceVisibility.hidden, BackfaceVisibility.hidden);
    });
  });

  group('Transform3DStyle', () {
    test('flat is default', () {
      expect(Transform3DStyle.flat, Transform3DStyle.flat);
    });

    test('preserve3d value exists', () {
      expect(Transform3DStyle.preserve3d, Transform3DStyle.preserve3d);
    });
  });

  group('Utility functions', () {
    test('degreesToRadians converts correctly', () {
      expect(degreesToRadians(0), 0);
      expect(degreesToRadians(90), closeTo(math.pi / 2, 1e-10));
      expect(degreesToRadians(180), closeTo(math.pi, 1e-10));
      expect(degreesToRadians(360), closeTo(2 * math.pi, 1e-10));
    });

    test('radiansToDegrees converts correctly', () {
      expect(radiansToDegrees(0), 0);
      expect(radiansToDegrees(math.pi / 2), closeTo(90, 1e-10));
      expect(radiansToDegrees(math.pi), closeTo(180, 1e-10));
      expect(radiansToDegrees(2 * math.pi), closeTo(360, 1e-10));
    });
  });
}
