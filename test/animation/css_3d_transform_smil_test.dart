import 'dart:math' as math;

import 'package:flutter_svg/src/animation/css_animations.dart';
import 'package:flutter_svg/src/animation/css_to_smil_converter.dart';
import 'package:flutter_svg/src/animation/smil/smil_animation.dart';
import 'package:flutter_svg/src/animation/svg_dom.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Css3DDecompositionResult', () {
    test('toSmilString generates correct translate string', () {
      const result = Css3DDecompositionResult(
        smilType: 'translate',
        values: [10.0, 20.0],
      );

      expect(result.toSmilString(), 'translate(10, 20)');
    });

    test('toSmilString generates correct rotate string', () {
      const result = Css3DDecompositionResult(
        smilType: 'rotate',
        values: [45.0],
      );

      expect(result.toSmilString(), 'rotate(45)');
    });

    test('toSmilString generates rotate with center point', () {
      const result = Css3DDecompositionResult(
        smilType: 'rotate',
        values: [45.0, 50.0, 50.0],
      );

      expect(result.toSmilString(), 'rotate(45, 50, 50)');
    });

    test('toSmilString generates correct scale string', () {
      const result = Css3DDecompositionResult(
        smilType: 'scale',
        values: [2.0, 3.0],
      );

      expect(result.toSmilString(), 'scale(2, 3)');
    });

    test('toSmilString generates correct skewX string', () {
      const result = Css3DDecompositionResult(
        smilType: 'skewX',
        values: [30.0],
      );

      expect(result.toSmilString(), 'skewX(30)');
    });

    test('toSmilString generates correct skewY string', () {
      const result = Css3DDecompositionResult(
        smilType: 'skewY',
        values: [15.0],
      );

      expect(result.toSmilString(), 'skewY(15)');
    });

    test('toSmilString generates correct matrix string', () {
      const result = Css3DDecompositionResult(
        smilType: 'matrix',
        values: [1.0, 0.0, 0.0, 1.0, 10.0, 20.0],
      );

      expect(result.toSmilString(), 'matrix(1, 0, 0, 1, 10, 20)');
    });

    test('toSmilString returns empty for empty values', () {
      const result = Css3DDecompositionResult(
        smilType: 'translate',
        values: [],
      );

      expect(result.toSmilString(), '');
    });
  });

  group('Css3DTransformDecomposer - translate3d', () {
    test('decomposes translate3d extracting x and y', () {
      final result = Css3DTransformDecomposer.decomposeTranslate3d(10, 20, 30);

      expect(result.smilType, 'translate');
      expect(result.values, [10.0, 20.0]);
      expect(result.zTranslation, 30.0);
      expect(result.is3D, true);
    });

    test('decomposes translate3d with zero values', () {
      final result = Css3DTransformDecomposer.decomposeTranslate3d(0, 0, 0);

      expect(result.smilType, 'translate');
      expect(result.values, [0.0, 0.0]);
      expect(result.is3D, true);
    });

    test('decomposes translate3d with negative values', () {
      final result = Css3DTransformDecomposer.decomposeTranslate3d(
        -50,
        -100,
        -200,
      );

      expect(result.smilType, 'translate');
      expect(result.values, [-50.0, -100.0]);
      expect(result.zTranslation, -200.0);
    });
  });

  group('Css3DTransformDecomposer - rotateX', () {
    test('decomposes rotateX to scale for small angles', () {
      final result = Css3DTransformDecomposer.decomposeRotateX(30);

      // cos(30deg) ≈ 0.866
      expect(result.smilType, 'scale');
      expect(result.values[0], closeTo(1.0, 0.001));
      expect(result.values[1], closeTo(math.cos(30 * math.pi / 180), 0.001));
      expect(result.is3D, true);
    });

    test('decomposes rotateX to matrix for large angles', () {
      final result = Css3DTransformDecomposer.decomposeRotateX(60);

      expect(result.smilType, 'matrix');
      expect(result.values.length, 6);
      expect(result.values[0], 1.0); // a = 1
      expect(result.values[3], closeTo(math.cos(60 * math.pi / 180), 0.001));
    });

    test('rotateX(0) produces identity-like transform', () {
      final result = Css3DTransformDecomposer.decomposeRotateX(0);

      expect(result.values[0], closeTo(1.0, 0.001));
      expect(result.values[1], closeTo(1.0, 0.001));
    });

    test('rotateX(90) produces zero Y scale', () {
      final result = Css3DTransformDecomposer.decomposeRotateX(90);

      // cos(90deg) = 0
      expect(result.smilType, 'matrix');
      expect(result.values[3], closeTo(0.0, 0.001));
    });
  });

  group('Css3DTransformDecomposer - rotateY', () {
    test('decomposes rotateY to scale for small angles', () {
      final result = Css3DTransformDecomposer.decomposeRotateY(30);

      expect(result.smilType, 'scale');
      expect(result.values[0], closeTo(math.cos(30 * math.pi / 180), 0.001));
      expect(result.values[1], closeTo(1.0, 0.001));
      expect(result.is3D, true);
    });

    test('decomposes rotateY to matrix for large angles', () {
      final result = Css3DTransformDecomposer.decomposeRotateY(60);

      expect(result.smilType, 'matrix');
      expect(result.values[0], closeTo(math.cos(60 * math.pi / 180), 0.001));
      expect(result.values[3], 1.0); // d = 1
    });

    test('rotateY(90) produces zero X scale', () {
      final result = Css3DTransformDecomposer.decomposeRotateY(90);

      expect(result.smilType, 'matrix');
      expect(result.values[0], closeTo(0.0, 0.001));
    });
  });

  group('Css3DTransformDecomposer - rotateZ', () {
    test('decomposes rotateZ directly to rotate', () {
      final result = Css3DTransformDecomposer.decomposeRotateZ(45);

      expect(result.smilType, 'rotate');
      expect(result.values, [45.0]);
      expect(result.is3D, false); // rotateZ is effectively 2D
    });

    test('decomposes rotateZ with negative angle', () {
      final result = Css3DTransformDecomposer.decomposeRotateZ(-90);

      expect(result.smilType, 'rotate');
      expect(result.values, [-90.0]);
    });

    test('decomposes rotateZ(0) to zero rotation', () {
      final result = Css3DTransformDecomposer.decomposeRotateZ(0);

      expect(result.smilType, 'rotate');
      expect(result.values, [0.0]);
    });
  });

  group('Css3DTransformDecomposer - rotate3d', () {
    test('rotate3d around Z axis maps to rotateZ', () {
      final result = Css3DTransformDecomposer.decomposeRotate3d(0, 0, 1, 45);

      expect(result.smilType, 'rotate');
      expect(result.values[0], closeTo(45.0, 0.001));
    });

    test('rotate3d around X axis maps to rotateX-like', () {
      final result = Css3DTransformDecomposer.decomposeRotate3d(1, 0, 0, 30);

      // Should decompose to scale or matrix with similar effect to rotateX
      expect(result.is3D, true);
    });

    test('rotate3d around Y axis maps to rotateY-like', () {
      final result = Css3DTransformDecomposer.decomposeRotate3d(0, 1, 0, 30);

      expect(result.is3D, true);
    });

    test('rotate3d with zero-length axis returns identity', () {
      final result = Css3DTransformDecomposer.decomposeRotate3d(0, 0, 0, 45);

      expect(result.smilType, 'rotate');
      expect(result.values[0], 0.0);
    });

    test('rotate3d with arbitrary axis uses matrix', () {
      final result = Css3DTransformDecomposer.decomposeRotate3d(1, 1, 1, 45);

      expect(result.smilType, 'matrix');
      expect(result.values.length, 6);
      expect(result.is3D, true);
    });
  });

  group('Css3DTransformDecomposer - scale3d', () {
    test('decomposes scale3d extracting x and y', () {
      final result = Css3DTransformDecomposer.decomposeScale3d(2, 3, 4);

      expect(result.smilType, 'scale');
      expect(result.values, [2.0, 3.0]);
      expect(result.zScale, 4.0);
      expect(result.is3D, true);
    });

    test('decomposes scale3d identity', () {
      final result = Css3DTransformDecomposer.decomposeScale3d(1, 1, 1);

      expect(result.values, [1.0, 1.0]);
    });

    test('decomposes scale3d with negative values', () {
      final result = Css3DTransformDecomposer.decomposeScale3d(-1, 2, 0.5);

      expect(result.values, [-1.0, 2.0]);
      expect(result.zScale, 0.5);
    });
  });

  group('Css3DTransformDecomposer - perspective', () {
    test('decomposes perspective to identity with metadata', () {
      final result = Css3DTransformDecomposer.decomposePerspective(1000);

      expect(result.smilType, 'matrix');
      expect(result.values, [1.0, 0.0, 0.0, 1.0, 0.0, 0.0]);
      expect(result.perspectiveDistance, 1000.0);
      expect(result.is3D, true);
    });

    test('decomposes perspective with zero distance', () {
      final result = Css3DTransformDecomposer.decomposePerspective(0);

      expect(result.perspectiveDistance, 0.0);
    });
  });

  group('Css3DTransformDecomposer - matrix3d', () {
    test('decomposes matrix3d identity', () {
      final result = Css3DTransformDecomposer.decomposeMatrix3d([
        1,
        0,
        0,
        0,
        0,
        1,
        0,
        0,
        0,
        0,
        1,
        0,
        0,
        0,
        0,
        1,
      ]);

      expect(result.smilType, 'matrix');
      expect(result.values[0], closeTo(1.0, 0.001));
      expect(result.values[3], closeTo(1.0, 0.001));
      expect(result.values[4], closeTo(0.0, 0.001));
      expect(result.values[5], closeTo(0.0, 0.001));
    });

    test('decomposes matrix3d with translation', () {
      final result = Css3DTransformDecomposer.decomposeMatrix3d([
        1,
        0,
        0,
        0,
        0,
        1,
        0,
        0,
        0,
        0,
        1,
        0,
        100,
        200,
        0,
        1,
      ]);

      expect(result.values[4], closeTo(100.0, 0.001)); // tx
      expect(result.values[5], closeTo(200.0, 0.001)); // ty
    });

    test('decomposes invalid matrix3d to identity', () {
      final result = Css3DTransformDecomposer.decomposeMatrix3d([1, 0, 0]);

      expect(result.values, [1.0, 0.0, 0.0, 1.0, 0.0, 0.0]);
    });
  });

  group('Css3DTransformDecomposer - decomposeTransformString', () {
    test('parses and decomposes translate3d string', () {
      final results = Css3DTransformDecomposer.decomposeTransformString(
        'translate3d(10, 20, 30)',
      );

      expect(results.length, 1);
      expect(results[0].smilType, 'translate');
      expect(results[0].values, [10.0, 20.0]);
    });

    test('parses and decomposes multiple transforms', () {
      final results = Css3DTransformDecomposer.decomposeTransformString(
        'translate(10, 20) rotateZ(45) scale(2)',
      );

      expect(results.length, 3);
      expect(results[0].smilType, 'translate');
      expect(results[1].smilType, 'rotate');
      expect(results[2].smilType, 'scale');
    });

    test('parses combined 2D and 3D transforms', () {
      final results = Css3DTransformDecomposer.decomposeTransformString(
        'translate(10, 20) rotateX(45) scale3d(2, 2, 2)',
      );

      expect(results.length, 3);
      expect(results[0].is3D, false);
      expect(results[1].is3D, true);
      expect(results[2].is3D, true);
    });

    test('handles empty string', () {
      final results = Css3DTransformDecomposer.decomposeTransformString('');

      expect(results.isEmpty, true);
    });
  });

  group('Css3DTransformDecomposer - combineResults', () {
    test('combines translate and scale', () {
      final results = [
        const Css3DDecompositionResult(
          smilType: 'translate',
          values: [10.0, 20.0],
        ),
        const Css3DDecompositionResult(smilType: 'scale', values: [2.0, 2.0]),
      ];

      final combined = Css3DTransformDecomposer.combineResults(results);

      expect(combined.smilType, 'matrix');
      expect(combined.values.length, 6);
    });

    test('combines single result returns original', () {
      const single = Css3DDecompositionResult(
        smilType: 'rotate',
        values: [45.0],
      );

      final combined = Css3DTransformDecomposer.combineResults([single]);

      expect(combined.smilType, 'rotate');
      expect(combined.values, [45.0]);
    });

    test('combines empty list returns identity', () {
      final combined = Css3DTransformDecomposer.combineResults([]);

      expect(combined.smilType, 'matrix');
      expect(combined.values, [1.0, 0.0, 0.0, 1.0, 0.0, 0.0]);
    });

    test('preserves perspective metadata', () {
      final results = [
        const Css3DDecompositionResult(
          smilType: 'matrix',
          values: [1.0, 0.0, 0.0, 1.0, 0.0, 0.0],
          perspectiveDistance: 1000.0,
        ),
        const Css3DDecompositionResult(
          smilType: 'translate',
          values: [10.0, 20.0],
        ),
      ];

      final combined = Css3DTransformDecomposer.combineResults(results);

      expect(combined.perspectiveDistance, 1000.0);
    });

    test('tracks 3D flag in combined result', () {
      final results = [
        const Css3DDecompositionResult(
          smilType: 'translate',
          values: [10.0, 20.0],
          is3D: false,
        ),
        const Css3DDecompositionResult(
          smilType: 'scale',
          values: [2.0, 3.0],
          is3D: true,
        ),
      ];

      final combined = Css3DTransformDecomposer.combineResults(results);

      expect(combined.is3D, true);
    });
  });

  group('_inferTransformType', () {
    // We need to test the fixed behavior through the converter
    // Create minimal structures to verify the fix

    test('returns matrix for unrecognized transform types', () {
      // Test by creating a keyframe animation with an unrecognized transform
      // The _inferTransformType function should return 'matrix' for unknown types
      final keyframes = CssKeyframes(
        name: 'test',
        keyframes: [
          CssKeyframe(offset: 0.0, properties: {'transform': 'custom(1, 2)'}),
          CssKeyframe(offset: 1.0, properties: {'transform': 'custom(3, 4)'}),
        ],
      );

      final animation = CssAnimation(
        name: 'test',
        duration: const Duration(seconds: 1),
        timingFunction: 'linear',
        delay: Duration.zero,
        iterationCount: 1.0,
        direction: 'normal',
        fillMode: 'forwards',
      );

      final targetNode = SvgNode(
        tagName: 'rect',
        id: 'test',
        children: [],
        attributes: {},
      );

      final document = SvgDocument(
        root: targetNode,
        width: 100,
        height: 100,
        viewBox: null,
      );

      final smilAnimations = CssToSmilConverter.convert(
        keyframes,
        animation,
        targetNode,
        document,
      );

      // Verify the animation was created
      expect(smilAnimations.isNotEmpty, true);
      final transformAnim = smilAnimations.firstWhere(
        (a) => a.attributeName == 'transform',
      );
      // The transform type should be 'matrix' for unrecognized transforms
      expect(transformAnim.transformType, 'matrix');
    });

    test('returns rotate for rotate transforms', () {
      final keyframes = CssKeyframes(
        name: 'test',
        keyframes: [
          CssKeyframe(offset: 0.0, properties: {'transform': 'rotate(0deg)'}),
          CssKeyframe(offset: 1.0, properties: {'transform': 'rotate(90deg)'}),
        ],
      );

      final animation = CssAnimation(
        name: 'test',
        duration: const Duration(seconds: 1),
        timingFunction: 'linear',
        delay: Duration.zero,
        iterationCount: 1.0,
        direction: 'normal',
        fillMode: 'forwards',
      );

      final targetNode = SvgNode(
        tagName: 'rect',
        id: 'test',
        children: [],
        attributes: {},
      );

      final document = SvgDocument(
        root: targetNode,
        width: 100,
        height: 100,
        viewBox: null,
      );

      final smilAnimations = CssToSmilConverter.convert(
        keyframes,
        animation,
        targetNode,
        document,
      );

      expect(smilAnimations.isNotEmpty, true);
      final transformAnim = smilAnimations.firstWhere(
        (a) => a.attributeName == 'transform',
      );
      expect(transformAnim.transformType, 'rotate');
    });
  });

  group('Round-trip: CSS 3D keyframe to SMIL', () {
    test('translate3d keyframe converts to SMIL values', () {
      final keyframes = CssKeyframes(
        name: 'slide',
        keyframes: [
          CssKeyframe(
            offset: 0.0,
            properties: {'transform': 'translate3d(0, 0, 0)'},
          ),
          CssKeyframe(
            offset: 1.0,
            properties: {'transform': 'translate3d(100, 200, 50)'},
          ),
        ],
      );

      final animation = CssAnimation(
        name: 'slide',
        duration: const Duration(seconds: 1),
        timingFunction: 'linear',
        delay: Duration.zero,
        iterationCount: 1.0,
        direction: 'normal',
        fillMode: 'forwards',
      );

      final targetNode = SvgNode(
        tagName: 'rect',
        id: 'test',
        children: [],
        attributes: {},
      );

      final document = SvgDocument(
        root: targetNode,
        width: 100,
        height: 100,
        viewBox: null,
      );

      final smilAnimations = CssToSmilConverter.convert(
        keyframes,
        animation,
        targetNode,
        document,
      );

      expect(smilAnimations.length, 1);
      expect(smilAnimations[0].type, SmilAnimationType.animateTransform);
      expect(smilAnimations[0].values!.length, 2);
    });

    test('rotateX keyframe converts to SMIL values', () {
      final keyframes = CssKeyframes(
        name: 'flip',
        keyframes: [
          CssKeyframe(offset: 0.0, properties: {'transform': 'rotateX(0deg)'}),
          CssKeyframe(
            offset: 1.0,
            properties: {'transform': 'rotateX(180deg)'},
          ),
        ],
      );

      final animation = CssAnimation(
        name: 'flip',
        duration: const Duration(seconds: 1),
        timingFunction: 'linear',
        delay: Duration.zero,
        iterationCount: 1.0,
        direction: 'normal',
        fillMode: 'forwards',
      );

      final targetNode = SvgNode(
        tagName: 'rect',
        id: 'test',
        children: [],
        attributes: {},
      );

      final document = SvgDocument(
        root: targetNode,
        width: 100,
        height: 100,
        viewBox: null,
      );

      final smilAnimations = CssToSmilConverter.convert(
        keyframes,
        animation,
        targetNode,
        document,
      );

      expect(smilAnimations.length, 1);
      expect(smilAnimations[0].type, SmilAnimationType.animateTransform);
    });

    test('combined 2D+3D transform keyframes convert correctly', () {
      final keyframes = CssKeyframes(
        name: 'complex',
        keyframes: [
          CssKeyframe(
            offset: 0.0,
            properties: {'transform': 'translate(0, 0) rotateZ(0deg)'},
          ),
          CssKeyframe(
            offset: 0.5,
            properties: {'transform': 'translate3d(50, 50, 0) rotateZ(45deg)'},
          ),
          CssKeyframe(
            offset: 1.0,
            properties: {'transform': 'translate(100, 100) rotateZ(90deg)'},
          ),
        ],
      );

      final animation = CssAnimation(
        name: 'complex',
        duration: const Duration(seconds: 2),
        timingFunction: 'linear',
        delay: Duration.zero,
        iterationCount: 1.0,
        direction: 'normal',
        fillMode: 'forwards',
      );

      final targetNode = SvgNode(
        tagName: 'rect',
        id: 'test',
        children: [],
        attributes: {},
      );

      final document = SvgDocument(
        root: targetNode,
        width: 100,
        height: 100,
        viewBox: null,
      );

      final smilAnimations = CssToSmilConverter.convert(
        keyframes,
        animation,
        targetNode,
        document,
      );

      expect(smilAnimations.length, 1);
      expect(smilAnimations[0].values!.length, 3);
      expect(smilAnimations[0].keyTimes, [0.0, 0.5, 1.0]);
    });
  });

  group('Edge cases', () {
    test('handles zero values in 3D transforms', () {
      final result = Css3DTransformDecomposer.decomposeTranslate3d(0, 0, 0);
      expect(result.values, [0.0, 0.0]);

      final scaleResult = Css3DTransformDecomposer.decomposeScale3d(0, 0, 0);
      expect(scaleResult.values, [0.0, 0.0]);
    });

    test('handles identity transforms', () {
      // Identity translate3d
      var results = Css3DTransformDecomposer.decomposeTransformString(
        'translate3d(0, 0, 0)',
      );
      expect(results[0].values, [0.0, 0.0]);

      // Identity scale3d
      results = Css3DTransformDecomposer.decomposeTransformString(
        'scale3d(1, 1, 1)',
      );
      expect(results[0].values, [1.0, 1.0]);

      // Identity matrix3d
      results = Css3DTransformDecomposer.decomposeTransformString(
        'matrix3d(1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)',
      );
      expect(results[0].values[0], closeTo(1.0, 0.001));
      expect(results[0].values[3], closeTo(1.0, 0.001));
    });

    test('handles very large values', () {
      final result = Css3DTransformDecomposer.decomposeTranslate3d(
        1e10,
        1e10,
        1e10,
      );
      expect(result.values[0], 1e10);
      expect(result.values[1], 1e10);
    });

    test('handles very small values', () {
      final result = Css3DTransformDecomposer.decomposeTranslate3d(
        1e-10,
        1e-10,
        1e-10,
      );
      expect(result.values[0], closeTo(1e-10, 1e-15));
      expect(result.values[1], closeTo(1e-10, 1e-15));
    });

    test('handles 360 degree rotation', () {
      final result = Css3DTransformDecomposer.decomposeRotateZ(360);
      expect(result.values[0], 360.0);
    });

    test('handles negative angles', () {
      final result = Css3DTransformDecomposer.decomposeRotateZ(-45);
      expect(result.values[0], -45.0);
    });

    test('translateZ produces translate with zero x,y', () {
      final results = Css3DTransformDecomposer.decomposeTransformString(
        'translateZ(100)',
      );

      expect(results.length, 1);
      expect(results[0].smilType, 'translate');
      expect(results[0].values, [0.0, 0.0]);
      expect(results[0].zTranslation, 100.0);
    });

    test('scaleZ produces scale with 1,1 for x,y', () {
      final results = Css3DTransformDecomposer.decomposeTransformString(
        'scaleZ(2)',
      );

      expect(results.length, 1);
      expect(results[0].smilType, 'scale');
      expect(results[0].values, [1.0, 1.0]);
      expect(results[0].zScale, 2.0);
    });
  });
}
