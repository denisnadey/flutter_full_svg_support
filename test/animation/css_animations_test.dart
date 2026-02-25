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

  group('CSS Selector Rules Parsing', () {
    test('Parse #id and .class selectors', () {
      final cssText = '''
@keyframes spin {
  from { transform: rotate(0deg); }
}
#myId {
  animation: spin 1s infinite;
  fill: red;
}
.myClass {
  animation-name: fade;
  animation-duration: 2s;
}
circle, rect {
  opacity: 0.5;
}
''';

      final rules = CssParser.parseSelectorRules(cssText);

      // Should have 4 rules: #myId, .myClass, circle, rect
      expect(rules, hasLength(4));

      final idRule = rules.firstWhere((r) => r.isIdSelector);
      expect(idRule.targetId, equals('myId'));
      expect(idRule.hasAnimation, isTrue);
      expect(idRule.declarations['fill'], equals('red'));

      final classRule = rules.firstWhere((r) => r.isClassSelector);
      expect(classRule.targetClass, equals('myClass'));
      expect(classRule.hasAnimation, isTrue);

      final elements = rules
          .where((r) => !r.isIdSelector && !r.isClassSelector)
          .toList();
      expect(elements, hasLength(2));
      expect(elements[0].selector, equals('circle'));
      expect(elements[1].selector, equals('rect'));
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
        expect(transformAnim.transformType, equals('rotate'));
        expect(transformAnim.values, isNotNull);
        expect(transformAnim.values![0], equals('0'));
        expect(transformAnim.values![1], equals('360'));
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
    test('CSS selectors (#id, .class) trigger animations on matching nodes', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <style>
    @keyframes spin {
      from { transform: rotate(0); }
      to { transform: rotate(360); }
    }
    @keyframes fade {
      from { opacity: 0; }
      to { opacity: 1; }
    }
    #myRect {
      animation: spin 2s linear infinite;
    }
    .fadeMe {
      animation: fade 1s ease both;
    }
  </style>
  <rect id="myRect" width="10" height="10" />
  <circle class="fadeMe" cx="50" cy="50" r="10" />
  <ellipse class="fadeMe otherClass" cx="20" cy="20" rx="5" ry="5" />
  <path d="M0 0 H10" />
</svg>
''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);

      // Should have 1 spin animation (from #myRect) and 2 fade animations (from .fadeMe)
      expect(animations, hasLength(3));

      final rectAnims = animations
          .where((a) => a.targetNode.tagName == 'rect')
          .toList();
      expect(rectAnims, hasLength(1));
      expect(rectAnims.first.attributeName, equals('transform'));
      expect(rectAnims.first.targetNode.id, equals('myRect'));

      final circleAnims = animations
          .where((a) => a.targetNode.tagName == 'circle')
          .toList();
      expect(circleAnims, hasLength(1));
      expect(circleAnims.first.attributeName, equals('opacity'));
      expect(circleAnims.first.targetNode.className, equals('fadeMe'));

      final ellipseAnims = animations
          .where((a) => a.targetNode.tagName == 'ellipse')
          .toList();
      expect(ellipseAnims, hasLength(1));
      expect(ellipseAnims.first.attributeName, equals('opacity'));
      expect(
        ellipseAnims.first.targetNode.className,
        equals('fadeMe otherClass'),
      );

      // The <path> has no animations
      final pathAnims = animations
          .where((a) => a.targetNode.tagName == 'path')
          .toList();
      expect(pathAnims, isEmpty);
    });
    test('CSS steps() timing function is converted to StepTiming', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <style>
    @keyframes jump {
      from { x: 0; }
      to { x: 100; }
    }
  </style>
  <rect
    id="rect"
    x="0"
    style="
      animation-name: jump;
      animation-duration: 1s;
      animation-timing-function: steps(2, end);
    "
  />
</svg>
''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);
      final xAnim = animations.firstWhere((a) => a.attributeName == 'x');

      // The keySteps should be attached
      expect(xAnim.keySteps, isNotNull);
      expect(xAnim.keySteps, hasLength(1));

      final stepTiming = xAnim.keySteps!.first;
      expect(stepTiming.steps, equals(2));
      expect(stepTiming.stepAtStart, isFalse);

      // Verify the StepTiming output
      expect(stepTiming.transform(0.0), closeTo(0.0, 0.001));
      expect(stepTiming.transform(0.49), closeTo(0.0, 0.001));
      expect(stepTiming.transform(0.50), closeTo(0.5, 0.001));
      expect(stepTiming.transform(0.99), closeTo(0.5, 0.001));
      expect(stepTiming.transform(1.00), closeTo(1.0, 0.001));

      // Values update verify
      xAnim.updateForTime(
        const Duration(milliseconds: 250),
      ); // 25% -> step 0 -> 0x
      expect(
        xAnim.targetNode.getAttributeValue('x') as double,
        closeTo(0.0, 0.01),
      );

      xAnim.updateForTime(
        const Duration(milliseconds: 750),
      ); // 75% -> step 1 -> 50x
      expect(
        xAnim.targetNode.getAttributeValue('x') as double,
        closeTo(50.0, 0.01),
      );
    });
  });
}
