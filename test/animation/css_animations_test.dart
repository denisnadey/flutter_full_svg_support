import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_svg/src/animation/css_animations.dart';
import 'package:flutter_svg/src/animation/svg_parser.dart';
import 'package:flutter_svg/src/animation/smil/smil_animation.dart';
import 'package:flutter_svg/src/animation/smil/smil_parser.dart';

void main() {
  group('CSS @keyframes Parsing', () {
    test('Parse simple @keyframes', () {
      final cssText = '''
@keyframes spin {
  from { transform: rotate(0deg); }
  to { transform: rotate(360deg); }
}
''';

      final keyframes = CssParser.parseKeyframes(cssText);
      expect(keyframes, hasLength(1));
      expect(keyframes.first.name, equals('spin'));
      expect(keyframes.first.keyframes, hasLength(2));
      expect(keyframes.first.keyframes[0].offset, equals(0.0));
      expect(keyframes.first.keyframes[1].offset, equals(1.0));
    });

    test('Parse @keyframes with percentage keyframes', () {
      final cssText = '''
@keyframes fade {
  0% { opacity: 0; }
  50% { opacity: 0.5; }
  100% { opacity: 1; }
}
''';

      final keyframes = CssParser.parseKeyframes(cssText);
      expect(keyframes, hasLength(1));
      expect(keyframes.first.name, equals('fade'));
      expect(keyframes.first.keyframes, hasLength(3));
      expect(keyframes.first.keyframes[0].offset, equals(0.0));
      expect(keyframes.first.keyframes[1].offset, equals(0.5));
      expect(keyframes.first.keyframes[2].offset, equals(1.0));
    });

    test('Parse multiple @keyframes', () {
      final cssText = '''
@keyframes spin {
  from { transform: rotate(0deg); }
  to { transform: rotate(360deg); }
}
@keyframes fade {
  0% { opacity: 0; }
  100% { opacity: 1; }
}
''';

      final keyframes = CssParser.parseKeyframes(cssText);
      expect(keyframes, hasLength(2));
      expect(keyframes.any((kf) => kf.name == 'spin'), isTrue);
      expect(keyframes.any((kf) => kf.name == 'fade'), isTrue);
    });
  });

  group('CSS animation Property Parsing', () {
    test('Parse animation shorthand', () {
      final animationValue = 'spin 2s infinite linear';
      final animation = CssParser.parseAnimation(animationValue);

      expect(animation, isNotNull);
      expect(animation!.name, equals('spin'));
      expect(animation.duration, equals(const Duration(seconds: 2)));
      expect(animation.iterationCount, equals(double.infinity));
      expect(animation.timingFunction, equals('linear'));
    });

    test('Parse animation with delay', () {
      final animationValue = 'fade 1s 0.5s ease-in-out';
      final animation = CssParser.parseAnimation(animationValue);

      expect(animation, isNotNull);
      expect(animation!.name, equals('fade'));
      expect(animation.delay, equals(const Duration(milliseconds: 500)));
    });

    test('Parse animation shorthand with cubic-bezier and direction', () {
      final animationValue =
          'spin 2s cubic-bezier(0.42, 0, 0.58, 1) 120ms 3 alternate-reverse both';
      final animation = CssParser.parseAnimation(animationValue);

      expect(animation, isNotNull);
      expect(animation!.name, equals('spin'));
      expect(animation.duration, equals(const Duration(seconds: 2)));
      expect(
        animation.timingFunction,
        equals('cubic-bezier(0.42, 0, 0.58, 1)'),
      );
      expect(animation.delay, equals(const Duration(milliseconds: 120)));
      expect(animation.iterationCount, equals(3));
      expect(animation.direction, equals('alternate-reverse'));
      expect(animation.fillMode, equals('both'));
    });

    test('Parse animation from style attribute', () {
      final styleText = 'animation: spin 2s infinite; fill: blue;';
      final animation = CssParser.parseAnimationFromStyle(styleText);

      expect(animation, isNotNull);
      expect(animation!.name, equals('spin'));
      expect(animation.duration, equals(const Duration(seconds: 2)));
      expect(animation.iterationCount, equals(double.infinity));
    });

    test('Parse separate animation-* properties', () {
      final styleText = '''
        animation-name: spin;
        animation-duration: 2s;
        animation-iteration-count: infinite;
        animation-timing-function: linear;
      ''';
      final animation = CssParser.parseAnimationFromStyle(styleText);

      expect(animation, isNotNull);
      expect(animation!.name, equals('spin'));
      expect(animation.duration, equals(const Duration(seconds: 2)));
      expect(animation.iterationCount, equals(double.infinity));
      expect(animation.timingFunction, equals('linear'));
    });
  });

  group('CSS Animations in SVG', () {
    test('Parse CSS animations from SVG with style element', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <style>
    @keyframes spin {
      from { transform: rotate(0deg); }
      to { transform: rotate(360deg); }
    }
  </style>
  <circle id="circle" cx="50" cy="50" r="20" fill="blue" style="animation: spin 2s infinite;"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      expect(document.cssKeyframes, isNotNull);
      expect(document.cssKeyframes!.length, greaterThan(0));
      expect(document.cssKeyframes!.any((kf) => kf.name == 'spin'), isTrue);
    });

    test('CSS animations converted to SMIL', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <style>
    @keyframes spin {
      from { transform: rotate(0deg); }
      to { transform: rotate(360deg); }
    }
  </style>
  <circle id="circle" cx="50" cy="50" r="20" fill="blue" style="animation: spin 2s infinite;"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);

      // CSS анимация должна быть сконвертирована в SMIL
      expect(animations, isNotEmpty);

      // Проверяем что есть анимация transform
      final transformAnims = animations
          .where((anim) => anim.attributeName == 'transform')
          .toList();
      expect(transformAnims, isNotEmpty);
    });

    test(
      'CSS converter maps cubic-bezier to keySplines and normalizes transform values',
      () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <style>
    @keyframes spin {
      from { transform: rotate(0deg); }
      to { transform: rotate(1turn); }
    }
  </style>
  <circle
    id="circle"
    cx="50"
    cy="50"
    r="20"
    fill="blue"
    style="
      animation-name: spin;
      animation-duration: 2s;
      animation-iteration-count: 1;
      animation-timing-function: cubic-bezier(0.42, 0, 0.58, 1);
      animation-fill-mode: both;
    "
  />
</svg>
''';

        final document = SvgParser.parse(svgString);
        final animations = SmilParser.parseAnimations(document);
        final transformAnim = animations.firstWhere(
          (anim) => anim.attributeName == 'transform',
        );

        expect(transformAnim.calcMode, equals(SmilCalcMode.spline));
        expect(transformAnim.keySplines, isNotNull);
        expect(transformAnim.keySplines, hasLength(1));
        expect(transformAnim.values, isNotNull);
        expect(transformAnim.values![0], equals('rotate(0)'));
        expect(transformAnim.values![1], equals('rotate(360)'));
      },
    );

    test(
      'alternate direction affects runtime progress in converted CSS animation',
      () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <style>
    @keyframes fade {
      from { opacity: 0; }
      to { opacity: 1; }
    }
  </style>
  <rect
    id="rect"
    x="0"
    y="0"
    width="10"
    height="10"
    opacity="0"
    style="
      animation-name: fade;
      animation-duration: 2s;
      animation-iteration-count: 2;
      animation-direction: alternate;
      animation-timing-function: linear;
    "
  />
</svg>
''';

        final document = SvgParser.parse(svgString);
        final animations = SmilParser.parseAnimations(document);
        final opacityAnim = animations.firstWhere(
          (anim) => anim.attributeName == 'opacity',
        );

        expect(
          opacityAnim.playbackDirection,
          equals(SmilPlaybackDirection.alternate),
        );

        opacityAnim.updateForTime(const Duration(milliseconds: 500));
        final valueAt500ms =
            opacityAnim.targetNode.getAttributeValue('opacity') as double;
        expect(valueAt500ms, closeTo(0.25, 0.01));

        opacityAnim.updateForTime(const Duration(milliseconds: 2500));
        final valueAt2500ms =
            opacityAnim.targetNode.getAttributeValue('opacity') as double;
        expect(valueAt2500ms, closeTo(0.75, 0.01));
      },
    );
  });
}
