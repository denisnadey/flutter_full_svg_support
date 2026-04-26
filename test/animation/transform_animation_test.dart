import 'package:full_svg_flutter/src/animation/svg_dom.dart';
import 'package:full_svg_flutter/src/animation/svg_parser.dart';
import 'package:full_svg_flutter/src/animation/svg_transform.dart';
import 'package:full_svg_flutter/src/animation/smil/interpolators.dart';
import 'package:full_svg_flutter/src/animation/smil/smil_animation.dart';
import 'package:full_svg_flutter/src/animation/smil/smil_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SvgTransform', () {
    test('parses translate transform', () {
      final transforms = SvgTransform.parse('translate(10, 20)');

      expect(transforms.length, 1);
      expect(transforms[0].type, SvgTransformType.translate);
      expect(transforms[0].values, [10.0, 20.0]);
    });

    test('parses translate with single value', () {
      final transforms = SvgTransform.parse('translate(15)');

      expect(transforms.length, 1);
      expect(transforms[0].type, SvgTransformType.translate);
      expect(transforms[0].values, [15.0]);
    });

    test('parses rotate transform', () {
      final transforms = SvgTransform.parse('rotate(45)');

      expect(transforms.length, 1);
      expect(transforms[0].type, SvgTransformType.rotate);
      expect(transforms[0].values, [45.0]);
    });

    test('parses rotate with center point', () {
      final transforms = SvgTransform.parse('rotate(45, 50, 50)');

      expect(transforms.length, 1);
      expect(transforms[0].type, SvgTransformType.rotate);
      expect(transforms[0].values, [45.0, 50.0, 50.0]);
    });

    test('parses scale transform', () {
      final transforms = SvgTransform.parse('scale(2)');

      expect(transforms.length, 1);
      expect(transforms[0].type, SvgTransformType.scale);
      expect(transforms[0].values, [2.0]);
    });

    test('parses scale with two values', () {
      final transforms = SvgTransform.parse('scale(2, 3)');

      expect(transforms.length, 1);
      expect(transforms[0].type, SvgTransformType.scale);
      expect(transforms[0].values, [2.0, 3.0]);
    });

    test('parses matrix transform', () {
      final transforms = SvgTransform.parse('matrix(1, 0, 0, 1, 10, 20)');

      expect(transforms.length, 1);
      expect(transforms[0].type, SvgTransformType.matrix);
      expect(transforms[0].values, [1.0, 0.0, 0.0, 1.0, 10.0, 20.0]);
    });

    test('parses multiple transforms', () {
      final transforms = SvgTransform.parse(
        'translate(10, 20) rotate(45) scale(2)',
      );

      expect(transforms.length, 3);
      expect(transforms[0].type, SvgTransformType.translate);
      expect(transforms[1].type, SvgTransformType.rotate);
      expect(transforms[2].type, SvgTransformType.scale);
    });
  });

  group('TransformDecomposition', () {
    test('creates decomposition from translate', () {
      final transforms = SvgTransform.parse('translate(10, 20)');
      final decomp = TransformDecomposition.fromTransforms(transforms);

      expect(decomp.translateX, 10.0);
      expect(decomp.translateY, 20.0);
      expect(decomp.rotation, 0.0);
      expect(decomp.scaleX, 1.0);
      expect(decomp.scaleY, 1.0);
    });

    test('creates decomposition from rotate', () {
      final transforms = SvgTransform.parse('rotate(90)');
      final decomp = TransformDecomposition.fromTransforms(transforms);

      expect(decomp.translateX, 0.0);
      expect(decomp.translateY, 0.0);
      expect(decomp.rotation, closeTo(1.5708, 0.001)); // 90° in radians
      expect(decomp.scaleX, 1.0);
      expect(decomp.scaleY, 1.0);
    });

    test('creates decomposition from scale', () {
      final transforms = SvgTransform.parse('scale(2, 3)');
      final decomp = TransformDecomposition.fromTransforms(transforms);

      expect(decomp.translateX, 0.0);
      expect(decomp.translateY, 0.0);
      expect(decomp.rotation, 0.0);
      expect(decomp.scaleX, 2.0);
      expect(decomp.scaleY, 3.0);
    });

    test('creates decomposition from matrix translate', () {
      final transforms = SvgTransform.parse('matrix(1, 0, 0, 1, 10, 20)');
      final decomp = TransformDecomposition.fromTransforms(transforms);

      expect(decomp.translateX, closeTo(10.0, 0.001));
      expect(decomp.translateY, closeTo(20.0, 0.001));
      expect(decomp.rotation, closeTo(0.0, 0.001));
      expect(decomp.scaleX, closeTo(1.0, 0.001));
      expect(decomp.scaleY, closeTo(1.0, 0.001));
      expect(decomp.skewX, closeTo(0.0, 0.001));
    });

    test('creates decomposition from matrix rotate', () {
      final transforms = SvgTransform.parse('matrix(0, 1, -1, 0, 0, 0)');
      final decomp = TransformDecomposition.fromTransforms(transforms);

      expect(decomp.translateX, closeTo(0.0, 0.001));
      expect(decomp.translateY, closeTo(0.0, 0.001));
      expect(decomp.rotation, closeTo(1.5708, 0.001)); // pi / 2
      expect(decomp.scaleX, closeTo(1.0, 0.001));
      expect(decomp.scaleY, closeTo(1.0, 0.001));
      expect(decomp.skewX, closeTo(0.0, 0.001));
    });

    test('creates decomposition from matrix skewX', () {
      final transforms = SvgTransform.parse('matrix(1, 0, 1, 1, 0, 0)');
      final decomp = TransformDecomposition.fromTransforms(transforms);

      expect(decomp.translateX, closeTo(0.0, 0.001));
      expect(decomp.translateY, closeTo(0.0, 0.001));
      expect(decomp.rotation, closeTo(0.0, 0.001));
      expect(decomp.scaleX, closeTo(1.0, 0.001));
      expect(decomp.scaleY, closeTo(1.0, 0.001));
      expect(decomp.skewX, closeTo(0.7854, 0.001)); // 45deg
    });

    test('interpolates between two decompositions', () {
      final from = TransformDecomposition.fromTransforms(
        SvgTransform.parse('translate(0, 0) scale(1)'),
      );
      final to = TransformDecomposition.fromTransforms(
        SvgTransform.parse('translate(100, 100) scale(2)'),
      );

      final mid = from.lerp(to, 0.5);

      expect(mid.translateX, 50.0);
      expect(mid.translateY, 50.0);
      expect(mid.scaleX, 1.5);
      expect(mid.scaleY, 1.5);
    });
  });

  group('Transform Animation', () {
    test('parses animateTransform element', () {
      const svgXml = '''
        <svg>
          <rect x="10" y="10" width="50" height="50">
            <animateTransform
              attributeName="transform"
              type="translate"
              from="0 0"
              to="50 50"
              dur="1s"/>
          </rect>
        </svg>
      ''';

      final doc = SvgParser.parse(svgXml);
      final animations = SmilParser.parseAnimations(doc);

      expect(animations.length, equals(1));
      expect(animations[0].attributeName, equals('transform'));
      expect(animations[0].attributeType, equals(SvgAttributeType.transform));
    });

    test('interpolates translate at t=0.5', () {
      final result = Interpolators.interpolateTransform(
        'translate(0, 0)',
        'translate(100, 100)',
        0.5,
      );

      expect(result, contains('translate'));
      expect(result, contains('50'));
    });

    test('interpolates rotate at t=0.5', () {
      final result = Interpolators.interpolateTransform(
        'rotate(0)',
        'rotate(90)',
        0.5,
      );

      expect(result, contains('rotate'));
      expect(result, contains('45'));
    });

    test('interpolates scale at t=0.25', () {
      final result = Interpolators.interpolateTransform(
        'scale(1)',
        'scale(3)',
        0.25,
      );

      expect(result, contains('scale'));
      expect(result, contains('1.5')); // 1 + (3-1)*0.25 = 1.5
    });

    test('applies animated transform to node', () {
      final node = SvgNode(tagName: 'rect');
      node.setAttribute(
        'transform',
        'translate(0, 0)',
        type: SvgAttributeType.transform,
      );

      final anim = SmilAnimation(
        type: SmilAnimationType.animateTransform,
        targetNode: node,
        attributeName: 'transform',
        attributeType: SvgAttributeType.transform,
        from: 'translate(0, 0)',
        to: 'translate(100, 100)',
        dur: const Duration(seconds: 1),
      );

      // Apply animation at midpoint
      final value = anim.computeValue(0.5);

      expect(value, isA<String>());
      final transformStr = value as String;
      expect(transformStr, contains('translate'));
      expect(transformStr, contains('50'));
    });

    test('animates rotation with from/to', () {
      final node = SvgNode(tagName: 'rect');
      node.setAttribute(
        'transform',
        'rotate(0)',
        type: SvgAttributeType.transform,
      );

      final anim = SmilAnimation(
        type: SmilAnimationType.animateTransform,
        targetNode: node,
        attributeName: 'transform',
        attributeType: SvgAttributeType.transform,
        from: 'rotate(0)',
        to: 'rotate(360)',
        dur: const Duration(seconds: 2),
        repeatCount: double.infinity,
      );

      // t=0.5 (50%): rotate(180)
      var value = anim.computeValue(0.5);
      expect(value.toString(), contains('180'));

      // t=1.0 (100%): rotate(360)
      value = anim.computeValue(1.0);
      expect(value.toString(), contains('360'));
    });

    test('animates combined transform', () {
      final result = Interpolators.interpolateTransform(
        'translate(0, 0) rotate(0) scale(1)',
        'translate(100, 100) rotate(90) scale(2)',
        0.5,
      );

      // Should contain all three transforms at midpoint
      expect(result, contains('translate'));
      expect(result, contains('50')); // translate midpoint
      expect(result, contains('rotate'));
      expect(result, contains('45')); // rotate midpoint
      expect(result, contains('scale'));
      expect(result, contains('1.5')); // scale midpoint
    });

    test('interpolates matrix to translate via decomposition', () {
      final result = Interpolators.interpolateTransform(
        'matrix(1, 0, 0, 1, 10, 20)',
        'translate(30, 40)',
        0.5,
      );

      final transforms = SvgTransform.parse(result);
      final translate = transforms.firstWhere(
        (transform) => transform.type == SvgTransformType.translate,
      );

      expect(translate.values[0], closeTo(20.0, 0.001));
      expect(translate.values[1], closeTo(30.0, 0.001));
    });
  });
}
