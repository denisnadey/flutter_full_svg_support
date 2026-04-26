import 'package:flutter_test/flutter_test.dart';
import 'package:full_svg_flutter/src/animation/css_animations.dart';

void main() {
  group('Background Shorthand Expansion', () {
    test('expands simple background color', () {
      final result = CssParser.expandShorthand('background', 'red');

      expect(result['background-color'], equals('red'));
    });

    test('expands background with hex color', () {
      final result = CssParser.expandShorthand('background', '#ff0000');

      expect(result['background-color'], equals('#ff0000'));
    });

    test('expands background with rgb color', () {
      final result = CssParser.expandShorthand('background', 'rgb(255, 0, 0)');

      expect(result['background-color'], equals('rgb(255, 0, 0)'));
    });

    test('expands background with url image', () {
      final result = CssParser.expandShorthand('background', 'url(img.png)');

      expect(result['background-image'], equals('url(img.png)'));
    });

    test('expands background with url and no-repeat', () {
      final result = CssParser.expandShorthand(
        'background',
        'url(img.png) no-repeat',
      );

      expect(result['background-image'], equals('url(img.png)'));
      expect(result['background-repeat'], equals('no-repeat'));
    });

    test('expands background with url no-repeat center', () {
      final result = CssParser.expandShorthand(
        'background',
        'url(img.png) no-repeat center',
      );

      expect(result['background-image'], equals('url(img.png)'));
      expect(result['background-repeat'], equals('no-repeat'));
      expect(result['background-position'], equals('center'));
    });

    test('expands background with linear-gradient', () {
      final result = CssParser.expandShorthand(
        'background',
        'linear-gradient(to right, red, blue)',
      );

      expect(
        result['background-image'],
        equals('linear-gradient(to right, red, blue)'),
      );
    });

    test('expands background with linear-gradient and no-repeat', () {
      final result = CssParser.expandShorthand(
        'background',
        'linear-gradient(to right, red, blue) no-repeat',
      );

      expect(
        result['background-image'],
        equals('linear-gradient(to right, red, blue)'),
      );
      expect(result['background-repeat'], equals('no-repeat'));
    });

    test('expands background none', () {
      final result = CssParser.expandShorthand('background', 'none');

      expect(result['background-color'], equals('transparent'));
      expect(result['background-image'], equals('none'));
    });

    test('expands background inherit', () {
      final result = CssParser.expandShorthand('background', 'inherit');

      expect(result['background-color'], equals('transparent'));
      expect(result['background-image'], equals('inherit'));
    });

    test('provides defaults for unspecified properties', () {
      final result = CssParser.expandShorthand('background', 'url(img.png)');

      expect(result['background-image'], equals('url(img.png)'));
      expect(result['background-color'], equals('transparent'));
      expect(result['background-position'], equals('0% 0%'));
      expect(result['background-size'], equals('auto'));
      expect(result['background-repeat'], equals('repeat'));
    });
  });

  group('Animation Timing Defaults', () {
    test('defaults timing-function to ease for single animation', () {
      final result = CssParser.expandShorthand('animation', 'fadeIn 1s');

      expect(result['animation-name'], equals('fadeIn'));
      expect(result['animation-duration'], equals('1s'));
      expect(result['animation-timing-function'], equals('ease'));
    });

    test('defaults timing-function to ease for multiple animations', () {
      final result = CssParser.expandShorthand(
        'animation',
        'fadeIn 1s, slideUp 2s',
      );

      expect(result['animation-name'], equals('fadeIn, slideUp'));
      expect(result['animation-timing-function'], equals('ease, ease'));
    });

    test('preserves explicit timing function', () {
      final result = CssParser.expandShorthand('animation', 'fadeIn 1s linear');

      expect(result['animation-timing-function'], equals('linear'));
    });

    test('defaults all animation properties', () {
      final result = CssParser.expandShorthand('animation', 'myAnim');

      expect(result['animation-name'], equals('myAnim'));
      expect(result['animation-duration'], equals('0s'));
      expect(result['animation-timing-function'], equals('ease'));
      expect(result['animation-delay'], equals('0s'));
      expect(result['animation-iteration-count'], equals('1'));
      expect(result['animation-direction'], equals('normal'));
      expect(result['animation-fill-mode'], equals('none'));
      expect(result['animation-play-state'], equals('running'));
    });
  });

  group('Step Timing Function Jump Variants', () {
    group('Shorthand recognition', () {
      test('recognizes step-start', () {
        final result = CssParser.expandShorthand(
          'animation',
          'fadeIn 1s step-start',
        );

        expect(result['animation-timing-function'], equals('step-start'));
      });

      test('recognizes step-end', () {
        final result = CssParser.expandShorthand(
          'animation',
          'fadeIn 1s step-end',
        );

        expect(result['animation-timing-function'], equals('step-end'));
      });

      test('recognizes steps(n) default to end', () {
        final result = CssParser.expandShorthand(
          'animation',
          'fadeIn 1s steps(5)',
        );

        expect(result['animation-timing-function'], equals('steps(5)'));
      });

      test('recognizes steps(n, start)', () {
        final result = CssParser.expandShorthand(
          'animation',
          'fadeIn 1s steps(5, start)',
        );

        expect(result['animation-timing-function'], equals('steps(5, start)'));
      });

      test('recognizes steps(n, jump-start)', () {
        final result = CssParser.expandShorthand(
          'animation',
          'fadeIn 1s steps(5, jump-start)',
        );

        expect(
          result['animation-timing-function'],
          equals('steps(5, jump-start)'),
        );
      });

      test('recognizes steps(n, jump-end)', () {
        final result = CssParser.expandShorthand(
          'animation',
          'fadeIn 1s steps(5, jump-end)',
        );

        expect(
          result['animation-timing-function'],
          equals('steps(5, jump-end)'),
        );
      });

      test('recognizes steps(n, jump-none)', () {
        final result = CssParser.expandShorthand(
          'animation',
          'fadeIn 1s steps(5, jump-none)',
        );

        expect(
          result['animation-timing-function'],
          equals('steps(5, jump-none)'),
        );
      });

      test('recognizes steps(n, jump-both)', () {
        final result = CssParser.expandShorthand(
          'animation',
          'fadeIn 1s steps(5, jump-both)',
        );

        expect(
          result['animation-timing-function'],
          equals('steps(5, jump-both)'),
        );
      });
    });

    group('SMIL timing function recognition', () {
      // The step timing functions are tested through CSS shorthand recognition
      // The actual SMIL conversion is tested in css_transform_decomposition_test.dart

      test('steps function is recognized as timing function', () {
        // Verify that steps() timing functions are properly recognized
        // in animation shorthand
        final result = CssParser.expandShorthand(
          'animation',
          'fadeIn 1s steps(5)',
        );
        expect(result['animation-timing-function'], equals('steps(5)'));
      });

      test('steps with jump-start is recognized', () {
        final result = CssParser.expandShorthand(
          'animation',
          'fadeIn 1s steps(5, jump-start)',
        );
        expect(
          result['animation-timing-function'],
          equals('steps(5, jump-start)'),
        );
      });

      test('steps with jump-end is recognized', () {
        final result = CssParser.expandShorthand(
          'animation',
          'fadeIn 1s steps(5, jump-end)',
        );
        expect(
          result['animation-timing-function'],
          equals('steps(5, jump-end)'),
        );
      });

      test('steps with jump-none is recognized', () {
        final result = CssParser.expandShorthand(
          'animation',
          'fadeIn 1s steps(5, jump-none)',
        );
        expect(
          result['animation-timing-function'],
          equals('steps(5, jump-none)'),
        );
      });

      test('steps with jump-both is recognized', () {
        final result = CssParser.expandShorthand(
          'animation',
          'fadeIn 1s steps(5, jump-both)',
        );
        expect(
          result['animation-timing-function'],
          equals('steps(5, jump-both)'),
        );
      });
    });
  });

  group('Offset Property Recognition', () {
    test('recognizes offset-path property', () {
      final result = CssParser.expandShorthand(
        'offset-path',
        'path("M 10 10 L 100 100")',
      );

      expect(result['offset-path'], equals('path("M 10 10 L 100 100")'));
    });

    test('recognizes offset-distance property', () {
      final result = CssParser.expandShorthand('offset-distance', '50%');

      expect(result['offset-distance'], equals('50%'));
    });

    test('recognizes offset-rotate property', () {
      final result = CssParser.expandShorthand('offset-rotate', 'auto');

      expect(result['offset-rotate'], equals('auto'));
    });

    test('recognizes offset-position property', () {
      final result = CssParser.expandShorthand('offset-position', 'auto');

      expect(result['offset-position'], equals('auto'));
    });

    test('recognizes offset-anchor property', () {
      final result = CssParser.expandShorthand('offset-anchor', 'center');

      expect(result['offset-anchor'], equals('center'));
    });

    test('expands offset shorthand with path', () {
      final result = CssParser.expandShorthand(
        'offset',
        'path("M 0 0 L 100 100")',
      );

      expect(result['offset-path'], equals('path("M 0 0 L 100 100")'));
    });

    test('expands offset shorthand with path and distance', () {
      final result = CssParser.expandShorthand(
        'offset',
        'path("M 0 0 L 100 100") 50%',
      );

      expect(result['offset-path'], equals('path("M 0 0 L 100 100")'));
      expect(result['offset-distance'], equals('50%'));
    });

    test('expands offset shorthand with path distance and rotate', () {
      final result = CssParser.expandShorthand(
        'offset',
        'path("M 0 0 L 100 100") 50% auto',
      );

      expect(result['offset-path'], equals('path("M 0 0 L 100 100")'));
      expect(result['offset-distance'], equals('50%'));
      expect(result['offset-rotate'], equals('auto'));
    });

    test('expands offset none', () {
      final result = CssParser.expandShorthand('offset', 'none');

      expect(result['offset-path'], equals('none'));
      expect(result['offset-distance'], equals('0'));
      expect(result['offset-rotate'], equals('auto'));
    });

    test('expands offset with url reference', () {
      final result = CssParser.expandShorthand(
        'offset',
        'url(#myPath) 25% reverse',
      );

      expect(result['offset-path'], equals('url(#myPath)'));
      expect(result['offset-distance'], equals('25%'));
      expect(result['offset-rotate'], equals('reverse'));
    });

    test('isMotionProperty returns true for offset properties', () {
      expect(CssShorthandExpander.isMotionProperty('offset'), isTrue);
      expect(CssShorthandExpander.isMotionProperty('offset-path'), isTrue);
      expect(CssShorthandExpander.isMotionProperty('offset-distance'), isTrue);
      expect(CssShorthandExpander.isMotionProperty('offset-rotate'), isTrue);
      expect(CssShorthandExpander.isMotionProperty('offset-position'), isTrue);
      expect(CssShorthandExpander.isMotionProperty('offset-anchor'), isTrue);
    });

    test('isMotionProperty returns true for legacy motion properties', () {
      expect(CssShorthandExpander.isMotionProperty('motion-path'), isTrue);
      expect(CssShorthandExpander.isMotionProperty('motion-offset'), isTrue);
      expect(CssShorthandExpander.isMotionProperty('motion-rotation'), isTrue);
    });

    test('isMotionProperty returns false for non-motion properties', () {
      expect(CssShorthandExpander.isMotionProperty('opacity'), isFalse);
      expect(CssShorthandExpander.isMotionProperty('transform'), isFalse);
      expect(CssShorthandExpander.isMotionProperty('fill'), isFalse);
    });
  });

  group('Edge Cases', () {
    test('background with complex gradient', () {
      final result = CssParser.expandShorthand(
        'background',
        'radial-gradient(circle at center, red 0%, blue 100%) no-repeat',
      );

      expect(
        result['background-image'],
        contains('radial-gradient(circle at center, red 0%, blue 100%)'),
      );
      expect(result['background-repeat'], equals('no-repeat'));
    });

    test('animation with steps timing in complex shorthand', () {
      final result = CssParser.expandShorthand(
        'animation',
        'bounce 2s steps(4, jump-both) 500ms infinite alternate both',
      );

      expect(result['animation-name'], equals('bounce'));
      expect(result['animation-duration'], equals('2s'));
      expect(
        result['animation-timing-function'],
        equals('steps(4, jump-both)'),
      );
      expect(result['animation-delay'], equals('500ms'));
      expect(result['animation-iteration-count'], equals('infinite'));
      expect(result['animation-direction'], equals('alternate'));
      expect(result['animation-fill-mode'], equals('both'));
    });

    test('offset with ray() function', () {
      final result = CssParser.expandShorthand(
        'offset',
        'ray(45deg closest-side)',
      );

      expect(result['offset-path'], equals('ray(45deg closest-side)'));
    });

    test('offset with polygon() function', () {
      final result = CssParser.expandShorthand(
        'offset',
        'polygon(0 0, 100% 0, 100% 100%)',
      );

      expect(result['offset-path'], equals('polygon(0 0, 100% 0, 100% 100%)'));
    });
  });
}
