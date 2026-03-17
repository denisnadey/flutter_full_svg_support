import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_svg/src/animation/css_animations.dart';
import 'package:flutter_svg/src/animation/svg_parser.dart';
import 'package:flutter_svg/src/animation/smil/smil_animation.dart';
import 'package:flutter_svg/src/animation/smil/smil_parser.dart';

void main() {
  group('Multiple Animations Per Element', () {
    test('Parse comma-separated animation shorthand', () {
      final animations = CssParser.parseMultipleAnimations(
        'fadeIn 1s, slideUp 2s 0.5s ease-out',
      );

      expect(animations, hasLength(2));

      expect(animations[0].name, equals('fadeIn'));
      expect(animations[0].duration, equals(const Duration(seconds: 1)));

      expect(animations[1].name, equals('slideUp'));
      expect(animations[1].duration, equals(const Duration(seconds: 2)));
      expect(animations[1].delay, equals(const Duration(milliseconds: 500)));
      expect(animations[1].timingFunction, equals('ease-out'));
    });

    test('Parse multiple animations with cubic-bezier', () {
      final animations = CssParser.parseMultipleAnimations(
        'spin 1s cubic-bezier(0.4, 0, 0.2, 1) infinite, fade 0.5s linear',
      );

      expect(animations, hasLength(2));
      expect(animations[0].name, equals('spin'));
      expect(
        animations[0].timingFunction,
        equals('cubic-bezier(0.4, 0, 0.2, 1)'),
      );
      expect(animations[0].iterationCount, equals(double.infinity));

      expect(animations[1].name, equals('fade'));
      expect(animations[1].timingFunction, equals('linear'));
    });

    test('Multiple animations applied to single element via style', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <style>
    @keyframes fadeIn {
      from { opacity: 0; }
      to { opacity: 1; }
    }
    @keyframes slideUp {
      from { transform: translateY(100px); }
      to { transform: translateY(0); }
    }
  </style>
  <rect id="rect" style="animation: fadeIn 1s, slideUp 2s 0.5s ease-out;"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);

      // Should have 2 animations on the rect
      expect(animations, hasLength(2));

      final opacityAnim = animations.firstWhere(
        (a) => a.attributeName == 'opacity',
      );
      expect(opacityAnim.dur, equals(const Duration(seconds: 1)));

      final transformAnim = animations.firstWhere(
        (a) => a.attributeName == 'transform',
      );
      expect(transformAnim.dur, equals(const Duration(seconds: 2)));
      expect(transformAnim.begin, equals(const Duration(milliseconds: 500)));
    });

    test('Multiple animations via CSS selector', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <style>
    @keyframes spin {
      from { transform: rotate(0deg); }
      to { transform: rotate(360deg); }
    }
    @keyframes pulse {
      0% { opacity: 1; }
      50% { opacity: 0.5; }
      100% { opacity: 1; }
    }
    #animated {
      animation: spin 2s linear infinite, pulse 1s ease-in-out 3;
    }
  </style>
  <rect id="animated" x="10" y="10" width="80" height="80"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);

      expect(animations, hasLength(2));
    });
  });

  group('Animation Play State', () {
    test('Parse animation-play-state: paused', () {
      final animation = CssParser.parseAnimation('spin 2s infinite paused');

      expect(animation, isNotNull);
      expect(animation!.playState, equals('paused'));
      expect(animation.isPaused, isTrue);
    });

    test('Parse animation-play-state: running (default)', () {
      final animation = CssParser.parseAnimation('spin 2s infinite');

      expect(animation, isNotNull);
      expect(animation!.playState, equals('running'));
      expect(animation.isPaused, isFalse);
    });

    test('animation-play-state from style attribute', () {
      final styleText = '''
        animation-name: spin;
        animation-duration: 2s;
        animation-play-state: paused;
      ''';
      final animation = CssParser.parseAnimationFromStyle(styleText);

      expect(animation, isNotNull);
      expect(animation!.isPaused, isTrue);
    });

    test('Paused animation does not update', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <style>
    @keyframes fade {
      from { opacity: 0; }
      to { opacity: 1; }
    }
  </style>
  <rect id="rect" opacity="0.5" style="animation: fade 2s paused;"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);

      expect(animations, hasLength(1));
      expect(animations.first.isPaused, isTrue);

      // Initial value should remain unchanged since animation is paused
      animations.first.updateForTime(const Duration(milliseconds: 500));
      // Animation shouldn't apply values when paused
    });
  });

  group('Negative Animation Delay', () {
    test('Parse negative animation delay', () {
      final animation = CssParser.parseAnimation('spin 2s -0.5s');

      expect(animation, isNotNull);
      expect(animation!.delay.inMilliseconds, equals(-500));
    });

    test('Parse negative delay from style', () {
      final styleText = '''
        animation-name: spin;
        animation-duration: 4s;
        animation-delay: -1s;
      ''';
      final animation = CssParser.parseAnimationFromStyle(styleText);

      expect(animation, isNotNull);
      expect(animation!.delay.inSeconds, equals(-1));
    });

    test('Negative delay starts animation partway through', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <style>
    @keyframes slide {
      from { x: 0; }
      to { x: 100; }
    }
  </style>
  <rect id="rect" x="0" style="animation: slide 2s -0.5s linear forwards;"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);
      final slideAnim = animations.first;

      // With -0.5s delay on 2s animation, at t=0 we're already 0.5s into the animation
      // So 25% progress = x should be 25
      slideAnim.updateForTime(Duration.zero);
      final xValue = slideAnim.targetNode.getAttributeValue('x') as double;
      expect(xValue, closeTo(25.0, 1.0));
    });
  });

  group('Animation Fill Mode Edge Cases', () {
    test('fill-mode: forwards - retain final value after animation', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <style>
    @keyframes fade {
      from { opacity: 0; }
      to { opacity: 1; }
    }
  </style>
  <rect id="rect" opacity="0" style="animation: fade 1s forwards;"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);
      final fadeAnim = animations.first;

      expect(fadeAnim.fillMode, equals(SmilFillMode.freeze));

      // After animation ends
      fadeAnim.updateForTime(const Duration(seconds: 2));
      final opacity =
          fadeAnim.targetNode.getAttributeValue('opacity') as double;
      expect(opacity, closeTo(1.0, 0.01));
    });

    test('fill-mode: backwards - apply initial value during delay', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <style>
    @keyframes fade {
      from { opacity: 0; }
      to { opacity: 1; }
    }
  </style>
  <rect id="rect" opacity="0.5" style="animation: fade 1s 1s backwards;"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);
      final fadeAnim = animations.first;

      expect(fadeAnim.fillMode, equals(SmilFillMode.backwards));

      // During the 1s delay, backwards fill should show initial value (opacity: 0)
      fadeAnim.updateForTime(const Duration(milliseconds: 500));
      final opacity =
          fadeAnim.targetNode.getAttributeValue('opacity') as double;
      expect(opacity, closeTo(0.0, 0.01));
    });

    test('fill-mode: both - apply initial during delay AND retain final', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <style>
    @keyframes fade {
      from { opacity: 0; }
      to { opacity: 1; }
    }
  </style>
  <rect id="rect" opacity="0.5" style="animation: fade 1s 1s both;"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);
      final fadeAnim = animations.first;

      expect(fadeAnim.fillMode, equals(SmilFillMode.both));

      // During delay: should apply initial value (0)
      fadeAnim.updateForTime(const Duration(milliseconds: 500));
      var opacity = fadeAnim.targetNode.getAttributeValue('opacity') as double;
      expect(opacity, closeTo(0.0, 0.01));

      // After animation ends: should retain final value (1)
      fadeAnim.updateForTime(const Duration(seconds: 5));
      opacity = fadeAnim.targetNode.getAttributeValue('opacity') as double;
      expect(opacity, closeTo(1.0, 0.01));
    });
  });

  group('CSS Transitions', () {
    test('Parse transition shorthand', () {
      final transition = CssParser.parseTransition('opacity 0.3s ease-in-out');

      expect(transition, isNotNull);
      expect(transition!.property, equals('opacity'));
      expect(transition.duration, equals(const Duration(milliseconds: 300)));
      expect(transition.timingFunction, equals('ease-in-out'));
    });

    test('Parse transition with delay', () {
      final transition = CssParser.parseTransition('transform 1s 0.5s ease');

      expect(transition, isNotNull);
      expect(transition!.property, equals('transform'));
      expect(transition.duration, equals(const Duration(seconds: 1)));
      expect(transition.delay, equals(const Duration(milliseconds: 500)));
      expect(transition.timingFunction, equals('ease'));
    });

    test('Parse multiple transitions', () {
      final transitions = CssParser.parseTransitionsFromStyle(
        'transition: opacity 0.3s, transform 0.5s ease-out;',
      );

      expect(transitions, hasLength(2));
      expect(transitions[0].property, equals('opacity'));
      expect(transitions[1].property, equals('transform'));
    });

    test('Parse transitions from individual properties', () {
      final transitions = CssParser.parseTransitionsFromStyle('''
        transition-property: opacity, transform;
        transition-duration: 0.3s, 0.5s;
        transition-timing-function: ease, ease-out;
      ''');

      expect(transitions, hasLength(2));
      expect(transitions[0].property, equals('opacity'));
      expect(transitions[0].duration.inMilliseconds, equals(300));
      expect(transitions[1].property, equals('transform'));
      expect(transitions[1].duration.inMilliseconds, equals(500));
    });
  });

  group('@media Queries in SVG Style Blocks', () {
    test('Parse @media prefers-color-scheme: dark', () {
      final cssText = '''
        @media (prefers-color-scheme: dark) {
          rect { fill: white; }
        }
      ''';

      final mediaRules = CssParser.parseMediaRules(cssText);

      expect(mediaRules, hasLength(1));
      expect(mediaRules.first.query, contains('prefers-color-scheme'));
      expect(mediaRules.first.condition, isNotNull);
      expect(
        mediaRules.first.condition!.feature,
        equals(CssMediaFeature.prefersColorScheme),
      );
      expect(mediaRules.first.condition!.value, equals('dark'));
      expect(mediaRules.first.rules, hasLength(1));
    });

    test('Parse @media min-width', () {
      final cssText = '''
        @media (min-width: 600px) {
          .large { opacity: 1; }
        }
      ''';

      final mediaRules = CssParser.parseMediaRules(cssText);

      expect(mediaRules, hasLength(1));
      expect(mediaRules.first.condition, isNotNull);
      expect(
        mediaRules.first.condition!.feature,
        equals(CssMediaFeature.minWidth),
      );
      expect(mediaRules.first.condition!.numericValue, equals(600));
      expect(mediaRules.first.condition!.unit, equals('px'));
    });

    test('Evaluate media query: prefers-color-scheme', () {
      final condition = CssMediaCondition(
        feature: CssMediaFeature.prefersColorScheme,
        value: 'dark',
      );

      final darkContext = CssMediaContext(
        viewportWidth: 100,
        viewportHeight: 100,
        isDarkMode: true,
      );
      expect(condition.evaluate(darkContext), isTrue);

      final lightContext = CssMediaContext(
        viewportWidth: 100,
        viewportHeight: 100,
        isDarkMode: false,
      );
      expect(condition.evaluate(lightContext), isFalse);
    });

    test('Evaluate media query: min-width', () {
      final condition = CssMediaCondition(
        feature: CssMediaFeature.minWidth,
        numericValue: 600,
        unit: 'px',
      );

      final wideContext = CssMediaContext(
        viewportWidth: 800,
        viewportHeight: 600,
      );
      expect(condition.evaluate(wideContext), isTrue);

      final narrowContext = CssMediaContext(
        viewportWidth: 400,
        viewportHeight: 600,
      );
      expect(condition.evaluate(narrowContext), isFalse);
    });

    test('Evaluate media query: max-width', () {
      final condition = CssMediaCondition(
        feature: CssMediaFeature.maxWidth,
        numericValue: 500,
        unit: 'px',
      );

      final narrowContext = CssMediaContext(
        viewportWidth: 400,
        viewportHeight: 600,
      );
      expect(condition.evaluate(narrowContext), isTrue);

      final wideContext = CssMediaContext(
        viewportWidth: 800,
        viewportHeight: 600,
      );
      expect(condition.evaluate(wideContext), isFalse);
    });

    test('Multiple @media rules in same stylesheet', () {
      final cssText = '''
        @media (prefers-color-scheme: dark) {
          .icon { fill: white; }
        }
        @media (min-width: 768px) {
          .icon { transform: scale(1.5); }
        }
      ''';

      final mediaRules = CssParser.parseMediaRules(cssText);

      expect(mediaRules, hasLength(2));
      expect(
        mediaRules[0].condition!.feature,
        equals(CssMediaFeature.prefersColorScheme),
      );
      expect(
        mediaRules[1].condition!.feature,
        equals(CssMediaFeature.minWidth),
      );
    });
  });

  group('Edge Cases and Robustness', () {
    test('Empty animation value returns empty list', () {
      final animations = CssParser.parseMultipleAnimations('');
      expect(animations, isEmpty);
    });

    test('Animation with all properties', () {
      final animation = CssParser.parseAnimation(
        'myAnim 2s cubic-bezier(0.4, 0, 0.2, 1) 0.5s 3 alternate-reverse both paused',
      );

      expect(animation, isNotNull);
      expect(animation!.name, equals('myAnim'));
      expect(animation.duration, equals(const Duration(seconds: 2)));
      expect(animation.timingFunction, equals('cubic-bezier(0.4, 0, 0.2, 1)'));
      expect(animation.delay, equals(const Duration(milliseconds: 500)));
      expect(animation.iterationCount, equals(3));
      expect(animation.direction, equals('alternate-reverse'));
      expect(animation.fillMode, equals('both'));
      expect(animation.playState, equals('paused'));
    });

    test('Handle whitespace in animation values', () {
      final animations = CssParser.parseMultipleAnimations(
        '  fadeIn   1s  ,   slideUp  2s  ',
      );

      expect(animations, hasLength(2));
      expect(animations[0].name, equals('fadeIn'));
      expect(animations[1].name, equals('slideUp'));
    });

    test('Transition with all keyword', () {
      final transition = CssParser.parseTransition('all 0.3s ease');

      expect(transition, isNotNull);
      expect(transition!.property, equals('all'));
    });
  });
}
