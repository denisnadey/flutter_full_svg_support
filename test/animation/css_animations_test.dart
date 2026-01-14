import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_svg/src/animation/css_animations.dart';
import 'package:flutter_svg/src/animation/svg_parser.dart';
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
      final transformAnims = animations.where(
        (anim) => anim.attributeName == 'transform',
      ).toList();
      expect(transformAnims, isNotEmpty);
    });
  });
}
