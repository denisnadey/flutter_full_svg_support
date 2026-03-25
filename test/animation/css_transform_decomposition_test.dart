import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_svg/src/animation/css_animations.dart';
import 'package:flutter_svg/src/animation/css_to_smil_converter.dart';
import 'package:flutter_svg/src/animation/smil/smil_animation.dart';
import 'package:flutter_svg/src/animation/svg_dom.dart';

void main() {
  group('CSS Compound Transform Decomposition', () {
    late SvgNode targetNode;
    late SvgDocument document;

    setUp(() {
      targetNode = SvgNode(tagName: 'rect', id: 'test-element');
      final rootNode = SvgNode(tagName: 'svg', children: [targetNode]);
      document = SvgDocument(root: rootNode);
    });

    group('SVGator-style translate + scale compound transforms', () {
      test('decomposes translate(px) + scale into separate animations', () {
        // SVGator-style animation from astronaut helmet:
        // translate(496.72781px,415.815353px) scale(1,1) → scale(0.89375,0.89375)
        final keyframes = CssKeyframes(
          name: 'ts__ts',
          keyframes: [
            CssKeyframe(
              offset: 0.0,
              properties: {
                'transform': 'translate(496.72781px,415.815353px) scale(1,1)',
              },
            ),
            CssKeyframe(
              offset: 0.5,
              properties: {
                'transform':
                    'translate(496.72781px,415.815353px) scale(0.89375,0.89375)',
              },
            ),
            CssKeyframe(
              offset: 1.0,
              properties: {
                'transform': 'translate(496.72781px,415.815353px) scale(1,1)',
              },
            ),
          ],
        );

        final animation = CssAnimation(
          name: 'ts__ts',
          duration: const Duration(milliseconds: 3000),
          timingFunction: 'linear',
          iterationCount: double.infinity,
        );

        final smilAnimations = CssToSmilConverter.convert(
          keyframes,
          animation,
          targetNode,
          document,
        );

        // Should have 2 separate animations: one for translate, one for scale
        expect(smilAnimations.length, equals(2));

        // Find translate animation
        final translateAnim = smilAnimations.firstWhere(
          (a) => a.transformType == 'translate',
          orElse: () => throw StateError('No translate animation found'),
        );
        expect(translateAnim.type, equals(SmilAnimationType.animateTransform));
        expect(translateAnim.attributeName, equals('transform'));
        expect(translateAnim.values!.length, equals(3));
        // Translate values should be constant
        expect(translateAnim.values![0], contains('496.7278'));
        expect(translateAnim.values![0], contains('415.8154'));

        // Find scale animation
        final scaleAnim = smilAnimations.firstWhere(
          (a) => a.transformType == 'scale',
          orElse: () => throw StateError('No scale animation found'),
        );
        expect(scaleAnim.type, equals(SmilAnimationType.animateTransform));
        expect(scaleAnim.attributeName, equals('transform'));
        expect(scaleAnim.values!.length, equals(3));
        // Scale changes: 1,1 → 0.89375,0.89375 → 1,1
        // Values are formatted with limited precision
        expect(scaleAnim.values![0], contains('1'));
        expect(scaleAnim.values![1], contains('0.8938'));
        expect(scaleAnim.values![2], contains('1'));
      });

      test('keyTimes match keyframe offsets', () {
        final keyframes = CssKeyframes(
          name: 'test',
          keyframes: [
            CssKeyframe(
              offset: 0.0,
              properties: {'transform': 'translate(100px,200px) scale(1,1)'},
            ),
            CssKeyframe(
              offset: 0.166667, // 16.666667%
              properties: {
                'transform': 'translate(100px,200px) scale(0.5,0.5)',
              },
            ),
            CssKeyframe(
              offset: 0.333333, // 33.333333%
              properties: {'transform': 'translate(100px,200px) scale(1,1)'},
            ),
            CssKeyframe(
              offset: 0.5,
              properties: {
                'transform': 'translate(100px,200px) scale(0.5,0.5)',
              },
            ),
            CssKeyframe(
              offset: 0.666667,
              properties: {'transform': 'translate(100px,200px) scale(1,1)'},
            ),
            CssKeyframe(
              offset: 0.833333,
              properties: {
                'transform': 'translate(100px,200px) scale(0.5,0.5)',
              },
            ),
            CssKeyframe(
              offset: 1.0,
              properties: {'transform': 'translate(100px,200px) scale(1,1)'},
            ),
          ],
        );

        final animation = CssAnimation(
          name: 'test',
          duration: const Duration(milliseconds: 3000),
          timingFunction: 'linear',
        );

        final smilAnimations = CssToSmilConverter.convert(
          keyframes,
          animation,
          targetNode,
          document,
        );

        for (final anim in smilAnimations) {
          expect(anim.keyTimes!.length, equals(7));
          expect(anim.keyTimes![0], closeTo(0.0, 0.0001));
          expect(anim.keyTimes![1], closeTo(0.166667, 0.0001));
          expect(anim.keyTimes![2], closeTo(0.333333, 0.0001));
          expect(anim.keyTimes![3], closeTo(0.5, 0.0001));
          expect(anim.keyTimes![4], closeTo(0.666667, 0.0001));
          expect(anim.keyTimes![5], closeTo(0.833333, 0.0001));
          expect(anim.keyTimes![6], closeTo(1.0, 0.0001));
        }
      });
    });

    group('SVGator-style rotate + scale with per-keyframe timing', () {
      test('decomposes rotate + scale and extracts cubic-bezier timing', () {
        // From astronaut helmet eQVNhIKm4qz63_ts__ts:
        // rotate(464.738819deg) scale(0.632549,0.632549) with cubic-bezier(0.77,0,0.175,1)
        final keyframes = CssKeyframes(
          name: 'ts__ts',
          keyframes: [
            CssKeyframe(
              offset: 0.0,
              properties: {
                'transform': 'rotate(464.738819deg) scale(0.632549,0.632549)',
              },
              timingFunction: 'cubic-bezier(0.77,0,0.175,1)',
            ),
            CssKeyframe(
              offset: 0.166667,
              properties: {'transform': 'rotate(464.738819deg) scale(0,0)'},
              timingFunction: 'cubic-bezier(0.77,0,0.175,1)',
            ),
            CssKeyframe(
              offset: 0.333333,
              properties: {
                'transform': 'rotate(464.738819deg) scale(0.632549,0.632549)',
              },
              timingFunction: 'cubic-bezier(0.77,0,0.175,1)',
            ),
            CssKeyframe(
              offset: 0.5,
              properties: {'transform': 'rotate(464.738819deg) scale(0,0)'},
              timingFunction: 'cubic-bezier(0.77,0,0.175,1)',
            ),
            CssKeyframe(
              offset: 0.666667,
              properties: {
                'transform': 'rotate(464.738819deg) scale(0.632549,0.632549)',
              },
              timingFunction: 'cubic-bezier(0.77,0,0.175,1)',
            ),
            CssKeyframe(
              offset: 0.833333,
              properties: {'transform': 'rotate(464.738819deg) scale(0,0)'},
              timingFunction: 'cubic-bezier(0.77,0,0.175,1)',
            ),
            CssKeyframe(
              offset: 1.0,
              properties: {
                'transform': 'rotate(464.738819deg) scale(0.632549,0.632549)',
              },
              // Last keyframe doesn't need timing function
            ),
          ],
        );

        final animation = CssAnimation(
          name: 'ts__ts',
          duration: const Duration(milliseconds: 3000),
          timingFunction: 'linear', // Global fallback
          iterationCount: double.infinity,
        );

        final smilAnimations = CssToSmilConverter.convert(
          keyframes,
          animation,
          targetNode,
          document,
        );

        expect(smilAnimations.length, equals(2));

        // Check that scale animation has per-keyframe cubic-bezier timing
        final scaleAnim = smilAnimations.firstWhere(
          (a) => a.transformType == 'scale',
          orElse: () => throw StateError('No scale animation found'),
        );

        expect(scaleAnim.calcMode, equals(SmilCalcMode.spline));
        expect(scaleAnim.keySplines, isNotNull);
        // Should have n-1 keySplines for n keyframes
        expect(scaleAnim.keySplines!.length, equals(6));

        // Verify the cubic-bezier values
        for (final spline in scaleAnim.keySplines!) {
          expect(spline.x1, closeTo(0.77, 0.01));
          expect(spline.y1, closeTo(0.0, 0.01));
          expect(spline.x2, closeTo(0.175, 0.01));
          expect(spline.y2, closeTo(1.0, 0.01));
        }
      });

      test('uses animation-level timing when no per-keyframe override', () {
        final keyframes = CssKeyframes(
          name: 'test',
          keyframes: [
            CssKeyframe(
              offset: 0.0,
              properties: {'transform': 'rotate(0deg) scale(1,1)'},
            ),
            CssKeyframe(
              offset: 1.0,
              properties: {'transform': 'rotate(360deg) scale(2,2)'},
            ),
          ],
        );

        final animation = CssAnimation(
          name: 'test',
          duration: const Duration(milliseconds: 1000),
          timingFunction: 'ease-in-out',
        );

        final smilAnimations = CssToSmilConverter.convert(
          keyframes,
          animation,
          targetNode,
          document,
        );

        for (final anim in smilAnimations) {
          expect(anim.calcMode, equals(SmilCalcMode.spline));
          expect(anim.keySplines, isNotNull);
          expect(anim.keySplines!.length, equals(1));
          // ease-in-out: cubic-bezier(0.42, 0, 0.58, 1)
          expect(anim.keySplines![0].x1, closeTo(0.42, 0.01));
          expect(anim.keySplines![0].y1, closeTo(0.0, 0.01));
          expect(anim.keySplines![0].x2, closeTo(0.58, 0.01));
          expect(anim.keySplines![0].y2, closeTo(1.0, 0.01));
        }
      });
    });

    group('translate + rotate compound transforms', () {
      test('decomposes translate + rotate correctly', () {
        // From astronaut helmet eQVNhIKm4qz66_tr__tr:
        // translate(198.465179px,277.487177px) rotate(11.95341deg)
        final keyframes = CssKeyframes(
          name: 'tr__tr',
          keyframes: [
            CssKeyframe(
              offset: 0.0,
              properties: {
                'transform':
                    'translate(198.465179px,277.487177px) rotate(11.95341deg)',
              },
            ),
            CssKeyframe(
              offset: 0.5,
              properties: {
                'transform':
                    'translate(198.465179px,277.487177px) rotate(-8.46827deg)',
              },
            ),
            CssKeyframe(
              offset: 1.0,
              properties: {
                'transform':
                    'translate(198.465179px,277.487177px) rotate(11.95341deg)',
              },
            ),
          ],
        );

        final animation = CssAnimation(
          name: 'tr__tr',
          duration: const Duration(milliseconds: 3000),
          timingFunction: 'linear',
          iterationCount: double.infinity,
        );

        final smilAnimations = CssToSmilConverter.convert(
          keyframes,
          animation,
          targetNode,
          document,
        );

        expect(smilAnimations.length, equals(2));

        // Translate should be constant
        final translateAnim = smilAnimations.firstWhere(
          (a) => a.transformType == 'translate',
          orElse: () => throw StateError('No translate animation found'),
        );
        expect(translateAnim.values!.length, equals(3));
        // All translate values should be the same
        expect(translateAnim.values![0], translateAnim.values![1]);
        expect(translateAnim.values![1], translateAnim.values![2]);

        // Rotate should change
        final rotateAnim = smilAnimations.firstWhere(
          (a) => a.transformType == 'rotate',
          orElse: () => throw StateError('No rotate animation found'),
        );
        expect(rotateAnim.values!.length, equals(3));
        // Rotate values: 11.95341 → -8.46827 → 11.95341
        expect(rotateAnim.values![0], contains('11.9534'));
        expect(rotateAnim.values![1], contains('-8.4683'));
        expect(rotateAnim.values![2], contains('11.9534'));
      });
    });

    group('translate only transforms', () {
      test('handles translate-only transform', () {
        // From astronaut helmet eQVNhIKm4qz63_to__to
        final keyframes = CssKeyframes(
          name: 'to__to',
          keyframes: [
            CssKeyframe(
              offset: 0.0,
              properties: {'transform': 'translate(290.213632px,429.238002px)'},
            ),
            CssKeyframe(
              offset: 0.166667,
              properties: {'transform': 'translate(322.023902px,414.777701px)'},
            ),
            CssKeyframe(
              offset: 0.333333,
              properties: {'transform': 'translate(290.213632px,429.238002px)'},
            ),
            CssKeyframe(
              offset: 0.5,
              properties: {'transform': 'translate(322.023902px,414.777701px)'},
            ),
            CssKeyframe(
              offset: 0.666667,
              properties: {'transform': 'translate(290.213632px,429.238002px)'},
            ),
            CssKeyframe(
              offset: 0.833333,
              properties: {'transform': 'translate(322.023902px,414.777701px)'},
            ),
            CssKeyframe(
              offset: 1.0,
              properties: {'transform': 'translate(290.213632px,429.238002px)'},
            ),
          ],
        );

        final animation = CssAnimation(
          name: 'to__to',
          duration: const Duration(milliseconds: 3000),
          timingFunction: 'linear',
        );

        final smilAnimations = CssToSmilConverter.convert(
          keyframes,
          animation,
          targetNode,
          document,
        );

        // Should have only 1 animation for translate
        expect(smilAnimations.length, equals(1));
        expect(smilAnimations[0].transformType, equals('translate'));
        expect(smilAnimations[0].values!.length, equals(7));
      });
    });

    group('px and deg unit stripping', () {
      test('strips px units from translate values', () {
        final keyframes = CssKeyframes(
          name: 'test',
          keyframes: [
            CssKeyframe(
              offset: 0.0,
              properties: {'transform': 'translate(100px, 200px)'},
            ),
            CssKeyframe(
              offset: 1.0,
              properties: {'transform': 'translate(300px, 400px)'},
            ),
          ],
        );

        final animation = CssAnimation(
          name: 'test',
          duration: const Duration(milliseconds: 1000),
        );

        final smilAnimations = CssToSmilConverter.convert(
          keyframes,
          animation,
          targetNode,
          document,
        );

        final translateAnim = smilAnimations.first;
        // Values should be numbers without 'px'
        expect(translateAnim.values![0].toString(), isNot(contains('px')));
        expect(translateAnim.values![0].toString(), contains('100'));
        expect(translateAnim.values![0].toString(), contains('200'));
      });

      test('strips deg units and converts to degrees', () {
        final keyframes = CssKeyframes(
          name: 'test',
          keyframes: [
            CssKeyframe(
              offset: 0.0,
              properties: {'transform': 'rotate(45deg)'},
            ),
            CssKeyframe(
              offset: 1.0,
              properties: {'transform': 'rotate(90deg)'},
            ),
          ],
        );

        final animation = CssAnimation(
          name: 'test',
          duration: const Duration(milliseconds: 1000),
        );

        final smilAnimations = CssToSmilConverter.convert(
          keyframes,
          animation,
          targetNode,
          document,
        );

        final rotateAnim = smilAnimations.first;
        expect(rotateAnim.values![0].toString(), isNot(contains('deg')));
        expect(rotateAnim.values![0].toString(), contains('45'));
        expect(rotateAnim.values![1].toString(), contains('90'));
      });
    });

    group('additive mode for compound transforms', () {
      test('decomposed transforms use additive sum mode', () {
        final keyframes = CssKeyframes(
          name: 'test',
          keyframes: [
            CssKeyframe(
              offset: 0.0,
              properties: {'transform': 'translate(100px,100px) scale(1,1)'},
            ),
            CssKeyframe(
              offset: 1.0,
              properties: {'transform': 'translate(200px,200px) scale(2,2)'},
            ),
          ],
        );

        final animation = CssAnimation(
          name: 'test',
          duration: const Duration(milliseconds: 1000),
        );

        final smilAnimations = CssToSmilConverter.convert(
          keyframes,
          animation,
          targetNode,
          document,
        );

        // Both animations should use additive='sum' to combine correctly
        for (final anim in smilAnimations) {
          expect(anim.additive, equals(SmilAdditiveMode.sum));
        }
      });
    });

    group('negative scale values', () {
      test('handles negative scale values correctly', () {
        // From astronaut helmet: scale(-0.000752,-0.000752)
        final keyframes = CssKeyframes(
          name: 'test',
          keyframes: [
            CssKeyframe(
              offset: 0.0,
              properties: {'transform': 'scale(0.632549,0.632549)'},
            ),
            CssKeyframe(
              offset: 0.5,
              properties: {'transform': 'scale(-0.000752,-0.000752)'},
            ),
            CssKeyframe(
              offset: 1.0,
              properties: {'transform': 'scale(0.632549,0.632549)'},
            ),
          ],
        );

        final animation = CssAnimation(
          name: 'test',
          duration: const Duration(milliseconds: 1000),
        );

        final smilAnimations = CssToSmilConverter.convert(
          keyframes,
          animation,
          targetNode,
          document,
        );

        expect(smilAnimations.length, equals(1));
        final scaleAnim = smilAnimations[0];
        // Value is formatted with limited precision: -0.000752 → -0.0008
        expect(scaleAnim.values![1].toString(), contains('-0.0008'));
      });
    });

    group('large rotation angles', () {
      test('handles angles greater than 360 degrees', () {
        // From astronaut helmet: rotate(464.738819deg)
        final keyframes = CssKeyframes(
          name: 'test',
          keyframes: [
            CssKeyframe(
              offset: 0.0,
              properties: {'transform': 'rotate(464.738819deg)'},
            ),
            CssKeyframe(
              offset: 1.0,
              properties: {'transform': 'rotate(830.871715deg)'},
            ),
          ],
        );

        final animation = CssAnimation(
          name: 'test',
          duration: const Duration(milliseconds: 1000),
        );

        final smilAnimations = CssToSmilConverter.convert(
          keyframes,
          animation,
          targetNode,
          document,
        );

        expect(smilAnimations.length, equals(1));
        final rotateAnim = smilAnimations[0];
        // Should preserve the actual angle value for correct interpolation
        expect(rotateAnim.values![0].toString(), contains('464.7388'));
        expect(rotateAnim.values![1].toString(), contains('830.8717'));
      });
    });
  });

  group('CSS Keyframe Parsing with Per-Keyframe Timing', () {
    test('extracts animation-timing-function from keyframe body', () {
      final cssText = '''
@keyframes ts__ts {
  0% {transform: rotate(0deg) scale(1,1);animation-timing-function: cubic-bezier(0.77,0,0.175,1)}
  50% {transform: rotate(180deg) scale(0,0);animation-timing-function: cubic-bezier(0.77,0,0.175,1)}
  100% {transform: rotate(360deg) scale(1,1)}
}
''';

      final keyframes = CssParser.parseKeyframes(cssText);
      expect(keyframes.length, equals(1));

      final kf = keyframes[0];
      expect(kf.keyframes.length, equals(3));

      // First keyframe should have timing function
      expect(kf.keyframes[0].timingFunction, isNotNull);
      expect(kf.keyframes[0].timingFunction, contains('cubic-bezier'));

      // Second keyframe should have timing function
      expect(kf.keyframes[1].timingFunction, isNotNull);
      expect(kf.keyframes[1].timingFunction, contains('cubic-bezier'));

      // Last keyframe should NOT have timing function
      expect(kf.keyframes[2].timingFunction, isNull);

      // Transform property should NOT contain animation-timing-function
      expect(
        kf.keyframes[0].properties['transform'],
        isNot(contains('animation-timing-function')),
      );
    });
  });
}
