import 'package:flutter_test/flutter_test.dart';
import 'package:full_svg_flutter/src/animation/css_animations.dart';

void main() {
  group('CSS Shorthand Expansion', () {
    group('Font Shorthand', () {
      test('expands simple font shorthand', () {
        final result = CssParser.expandShorthand('font', '16px Arial');

        expect(result['font-size'], equals('16px'));
        expect(result['font-family'], equals('Arial'));
      });

      test('expands font with style and weight', () {
        final result = CssParser.expandShorthand(
          'font',
          'italic bold 16px Arial',
        );

        expect(result['font-style'], equals('italic'));
        expect(result['font-weight'], equals('bold'));
        expect(result['font-size'], equals('16px'));
        expect(result['font-family'], equals('Arial'));
      });

      test('expands font with line-height', () {
        final result = CssParser.expandShorthand('font', '16px/1.5 Arial');

        expect(result['font-size'], equals('16px'));
        expect(result['line-height'], equals('1.5'));
        expect(result['font-family'], equals('Arial'));
      });

      test('expands full font shorthand', () {
        final result = CssParser.expandShorthand(
          'font',
          'italic small-caps bold 16px/1.5 Arial, sans-serif',
        );

        expect(result['font-style'], equals('italic'));
        expect(result['font-variant'], equals('small-caps'));
        expect(result['font-weight'], equals('bold'));
        expect(result['font-size'], equals('16px'));
        expect(result['line-height'], equals('1.5'));
        expect(result['font-family'], isNotNull);
      });

      test('handles numeric font weight', () {
        final result = CssParser.expandShorthand('font', '700 14px Roboto');

        expect(result['font-weight'], equals('700'));
        expect(result['font-size'], equals('14px'));
        expect(result['font-family'], equals('Roboto'));
      });

      test('handles font keyword sizes', () {
        final result = CssParser.expandShorthand('font', 'large serif');

        expect(result['font-size'], equals('large'));
        expect(result['font-family'], equals('serif'));
      });

      test('handles relative font sizes', () {
        final result = CssParser.expandShorthand('font', 'larger monospace');

        expect(result['font-size'], equals('larger'));
        expect(result['font-family'], equals('monospace'));
      });

      test('handles system fonts', () {
        final result = CssParser.expandShorthand('font', 'caption');

        expect(result['font'], equals('caption'));
      });

      test('handles inherit keyword', () {
        final result = CssParser.expandShorthand('font', 'inherit');

        expect(result['font'], equals('inherit'));
      });
    });

    group('Animation Shorthand', () {
      test('expands simple animation shorthand', () {
        final result = CssParser.expandShorthand('animation', 'spin 1s');

        expect(result['animation-name'], equals('spin'));
        expect(result['animation-duration'], equals('1s'));
      });

      test('expands animation with timing function', () {
        final result = CssParser.expandShorthand(
          'animation',
          'fade 2s ease-in',
        );

        expect(result['animation-name'], equals('fade'));
        expect(result['animation-duration'], equals('2s'));
        expect(result['animation-timing-function'], equals('ease-in'));
      });

      test('expands animation with delay', () {
        final result = CssParser.expandShorthand('animation', 'slide 1s 500ms');

        expect(result['animation-name'], equals('slide'));
        expect(result['animation-duration'], equals('1s'));
        expect(result['animation-delay'], equals('500ms'));
      });

      test('expands animation with iteration count', () {
        final result = CssParser.expandShorthand(
          'animation',
          'pulse 1s infinite',
        );

        expect(result['animation-name'], equals('pulse'));
        expect(result['animation-duration'], equals('1s'));
        expect(result['animation-iteration-count'], equals('infinite'));
      });

      test('expands animation with direction', () {
        final result = CssParser.expandShorthand(
          'animation',
          'bounce 1s alternate',
        );

        expect(result['animation-name'], equals('bounce'));
        expect(result['animation-duration'], equals('1s'));
        expect(result['animation-direction'], equals('alternate'));
      });

      test('expands animation with fill mode', () {
        final result = CssParser.expandShorthand(
          'animation',
          'grow 1s forwards',
        );

        expect(result['animation-name'], equals('grow'));
        expect(result['animation-duration'], equals('1s'));
        expect(result['animation-fill-mode'], equals('forwards'));
      });

      test('expands full animation shorthand', () {
        final result = CssParser.expandShorthand(
          'animation',
          'spin 2s ease-in-out 500ms infinite alternate both',
        );

        expect(result['animation-name'], equals('spin'));
        expect(result['animation-duration'], equals('2s'));
        expect(result['animation-timing-function'], equals('ease-in-out'));
        expect(result['animation-delay'], equals('500ms'));
        expect(result['animation-iteration-count'], equals('infinite'));
        expect(result['animation-direction'], equals('alternate'));
        expect(result['animation-fill-mode'], equals('both'));
      });

      test('expands animation with cubic-bezier timing', () {
        final result = CssParser.expandShorthand(
          'animation',
          'move 1s cubic-bezier(0.4, 0, 0.2, 1)',
        );

        expect(result['animation-name'], equals('move'));
        expect(result['animation-duration'], equals('1s'));
        expect(
          result['animation-timing-function'],
          equals('cubic-bezier(0.4, 0, 0.2, 1)'),
        );
      });

      test('expands multiple animations', () {
        final result = CssParser.expandShorthand(
          'animation',
          'fadeIn 1s, slideUp 2s 0.5s',
        );

        expect(result['animation-name'], equals('fadeIn, slideUp'));
        expect(result['animation-duration'], equals('1s, 2s'));
        expect(result['animation-delay'], equals('0s, 0.5s'));
      });

      test('expands complex multiple animations', () {
        final result = CssParser.expandShorthand(
          'animation',
          'spin 1s linear infinite, fade 2s ease-in forwards',
        );

        expect(result['animation-name'], equals('spin, fade'));
        expect(result['animation-duration'], equals('1s, 2s'));
        expect(result['animation-timing-function'], equals('linear, ease-in'));
        expect(result['animation-iteration-count'], equals('infinite, 1'));
        expect(result['animation-fill-mode'], equals('none, forwards'));
      });
    });

    group('Transition Shorthand', () {
      test('expands simple transition shorthand', () {
        final result = CssParser.expandShorthand('transition', 'opacity 0.3s');

        expect(result['transition-property'], equals('opacity'));
        expect(result['transition-duration'], equals('0.3s'));
      });

      test('expands transition with timing function', () {
        final result = CssParser.expandShorthand(
          'transition',
          'all 0.5s ease-out',
        );

        expect(result['transition-property'], equals('all'));
        expect(result['transition-duration'], equals('0.5s'));
        expect(result['transition-timing-function'], equals('ease-out'));
      });

      test('expands transition with delay', () {
        final result = CssParser.expandShorthand(
          'transition',
          'transform 1s 200ms',
        );

        expect(result['transition-property'], equals('transform'));
        expect(result['transition-duration'], equals('1s'));
        expect(result['transition-delay'], equals('200ms'));
      });

      test('expands full transition shorthand', () {
        final result = CssParser.expandShorthand(
          'transition',
          'width 0.4s ease-in-out 100ms',
        );

        expect(result['transition-property'], equals('width'));
        expect(result['transition-duration'], equals('0.4s'));
        expect(result['transition-timing-function'], equals('ease-in-out'));
        expect(result['transition-delay'], equals('100ms'));
      });

      test('expands multiple transitions', () {
        final result = CssParser.expandShorthand(
          'transition',
          'opacity 0.3s ease, transform 0.5s ease-in-out',
        );

        expect(result['transition-property'], equals('opacity, transform'));
        expect(result['transition-duration'], equals('0.3s, 0.5s'));
        expect(
          result['transition-timing-function'],
          equals('ease, ease-in-out'),
        );
      });

      test('handles transition none', () {
        final result = CssParser.expandShorthand('transition', 'none');

        expect(result['transition-property'], equals('none'));
      });
    });

    group('Margin Shorthand', () {
      test('expands single value margin', () {
        final result = CssParser.expandShorthand('margin', '10px');

        expect(result['margin-top'], equals('10px'));
        expect(result['margin-right'], equals('10px'));
        expect(result['margin-bottom'], equals('10px'));
        expect(result['margin-left'], equals('10px'));
      });

      test('expands two value margin', () {
        final result = CssParser.expandShorthand('margin', '10px 20px');

        expect(result['margin-top'], equals('10px'));
        expect(result['margin-right'], equals('20px'));
        expect(result['margin-bottom'], equals('10px'));
        expect(result['margin-left'], equals('20px'));
      });

      test('expands three value margin', () {
        final result = CssParser.expandShorthand('margin', '10px 20px 30px');

        expect(result['margin-top'], equals('10px'));
        expect(result['margin-right'], equals('20px'));
        expect(result['margin-bottom'], equals('30px'));
        expect(result['margin-left'], equals('20px'));
      });

      test('expands four value margin', () {
        final result = CssParser.expandShorthand(
          'margin',
          '10px 20px 30px 40px',
        );

        expect(result['margin-top'], equals('10px'));
        expect(result['margin-right'], equals('20px'));
        expect(result['margin-bottom'], equals('30px'));
        expect(result['margin-left'], equals('40px'));
      });

      test('handles different units', () {
        final result = CssParser.expandShorthand('margin', '1em 2rem 3% 4px');

        expect(result['margin-top'], equals('1em'));
        expect(result['margin-right'], equals('2rem'));
        expect(result['margin-bottom'], equals('3%'));
        expect(result['margin-left'], equals('4px'));
      });

      test('handles auto keyword', () {
        final result = CssParser.expandShorthand('margin', '0 auto');

        expect(result['margin-top'], equals('0'));
        expect(result['margin-right'], equals('auto'));
        expect(result['margin-bottom'], equals('0'));
        expect(result['margin-left'], equals('auto'));
      });
    });

    group('Padding Shorthand', () {
      test('expands single value padding', () {
        final result = CssParser.expandShorthand('padding', '15px');

        expect(result['padding-top'], equals('15px'));
        expect(result['padding-right'], equals('15px'));
        expect(result['padding-bottom'], equals('15px'));
        expect(result['padding-left'], equals('15px'));
      });

      test('expands two value padding', () {
        final result = CssParser.expandShorthand('padding', '10px 25px');

        expect(result['padding-top'], equals('10px'));
        expect(result['padding-right'], equals('25px'));
        expect(result['padding-bottom'], equals('10px'));
        expect(result['padding-left'], equals('25px'));
      });

      test('expands three value padding', () {
        final result = CssParser.expandShorthand('padding', '5px 10px 15px');

        expect(result['padding-top'], equals('5px'));
        expect(result['padding-right'], equals('10px'));
        expect(result['padding-bottom'], equals('15px'));
        expect(result['padding-left'], equals('10px'));
      });

      test('expands four value padding', () {
        final result = CssParser.expandShorthand(
          'padding',
          '5px 10px 15px 20px',
        );

        expect(result['padding-top'], equals('5px'));
        expect(result['padding-right'], equals('10px'));
        expect(result['padding-bottom'], equals('15px'));
        expect(result['padding-left'], equals('20px'));
      });
    });

    group('Marker Shorthand (SVG)', () {
      test('expands marker shorthand to all marker properties', () {
        final result = CssParser.expandShorthand('marker', 'url(#arrowhead)');

        expect(result['marker-start'], equals('url(#arrowhead)'));
        expect(result['marker-mid'], equals('url(#arrowhead)'));
        expect(result['marker-end'], equals('url(#arrowhead)'));
      });

      test('expands marker none', () {
        final result = CssParser.expandShorthand('marker', 'none');

        expect(result['marker-start'], equals('none'));
        expect(result['marker-mid'], equals('none'));
        expect(result['marker-end'], equals('none'));
      });
    });

    group('Border Shorthand', () {
      test('expands border with all values', () {
        final result = CssParser.expandShorthand('border', '1px solid black');

        expect(result['border-top-width'], equals('1px'));
        expect(result['border-right-width'], equals('1px'));
        expect(result['border-bottom-width'], equals('1px'));
        expect(result['border-left-width'], equals('1px'));
        expect(result['border-top-style'], equals('solid'));
        expect(result['border-right-style'], equals('solid'));
        expect(result['border-bottom-style'], equals('solid'));
        expect(result['border-left-style'], equals('solid'));
        expect(result['border-top-color'], equals('black'));
        expect(result['border-right-color'], equals('black'));
        expect(result['border-bottom-color'], equals('black'));
        expect(result['border-left-color'], equals('black'));
      });

      test('expands border with width keyword', () {
        final result = CssParser.expandShorthand('border', 'thin dashed red');

        expect(result['border-top-width'], equals('thin'));
        expect(result['border-top-style'], equals('dashed'));
        expect(result['border-top-color'], equals('red'));
      });

      test('expands border-width shorthand', () {
        final result = CssParser.expandShorthand(
          'border-width',
          '1px 2px 3px 4px',
        );

        expect(result['border-top-width'], equals('1px'));
        expect(result['border-right-width'], equals('2px'));
        expect(result['border-bottom-width'], equals('3px'));
        expect(result['border-left-width'], equals('4px'));
      });

      test('expands border-style shorthand', () {
        final result = CssParser.expandShorthand(
          'border-style',
          'solid dashed',
        );

        expect(result['border-top-style'], equals('solid'));
        expect(result['border-right-style'], equals('dashed'));
        expect(result['border-bottom-style'], equals('solid'));
        expect(result['border-left-style'], equals('dashed'));
      });

      test('expands border-color shorthand', () {
        final result = CssParser.expandShorthand(
          'border-color',
          'red blue green',
        );

        expect(result['border-top-color'], equals('red'));
        expect(result['border-right-color'], equals('blue'));
        expect(result['border-bottom-color'], equals('green'));
        expect(result['border-left-color'], equals('blue'));
      });

      test('expands border-radius shorthand', () {
        final result = CssParser.expandShorthand('border-radius', '10px 20px');

        expect(result['border-top-left-radius'], equals('10px'));
        expect(result['border-top-right-radius'], equals('20px'));
        expect(result['border-bottom-right-radius'], equals('10px'));
        expect(result['border-bottom-left-radius'], equals('20px'));
      });

      test('expands border-radius with horizontal/vertical syntax', () {
        final result = CssParser.expandShorthand(
          'border-radius',
          '10px 20px / 5px 10px',
        );

        expect(result['border-top-left-radius'], equals('10px 5px'));
        expect(result['border-top-right-radius'], equals('20px 10px'));
        expect(result['border-bottom-right-radius'], equals('10px 5px'));
        expect(result['border-bottom-left-radius'], equals('20px 10px'));
      });
    });

    group('Background Shorthand', () {
      test('expands simple background color', () {
        final result = CssParser.expandShorthand('background', '#ff0000');

        expect(result['background-color'], equals('#ff0000'));
      });

      test('expands background with named color', () {
        final result = CssParser.expandShorthand('background', 'blue');

        expect(result['background-color'], equals('blue'));
      });

      test('handles background none', () {
        final result = CssParser.expandShorthand('background', 'none');

        expect(result['background-color'], equals('transparent'));
        expect(result['background-image'], equals('none'));
      });

      test('handles background inherit', () {
        final result = CssParser.expandShorthand('background', 'inherit');

        expect(result['background-color'], equals('transparent'));
        expect(result['background-image'], equals('inherit'));
      });

      test('handles background with url', () {
        final result = CssParser.expandShorthand(
          'background',
          'url(image.png)',
        );

        expect(result['background-image'], equals('url(image.png)'));
      });
    });

    group('Expand All Shorthands', () {
      test('expands multiple shorthands in a map', () {
        final properties = {
          'font': 'bold 16px Arial',
          'margin': '10px 20px',
          'fill': 'red',
        };

        final result = CssParser.expandAllShorthands(properties);

        // Font expanded
        expect(result['font-weight'], equals('bold'));
        expect(result['font-size'], equals('16px'));
        expect(result['font-family'], equals('Arial'));

        // Margin expanded
        expect(result['margin-top'], equals('10px'));
        expect(result['margin-right'], equals('20px'));
        expect(result['margin-bottom'], equals('10px'));
        expect(result['margin-left'], equals('20px'));

        // Non-shorthand preserved
        expect(result['fill'], equals('red'));
      });

      test('explicit longhands take precedence over expanded', () {
        final properties = {'margin': '10px', 'margin-top': '20px'};

        final result = CssParser.expandAllShorthands(properties);

        // Explicit longhand wins
        expect(result['margin-top'], equals('20px'));
        // Other sides from shorthand
        expect(result['margin-right'], equals('10px'));
        expect(result['margin-bottom'], equals('10px'));
        expect(result['margin-left'], equals('10px'));
      });
    });

    group('parsePropertiesExpanded', () {
      test('parses and expands CSS string', () {
        final result = CssParser.parsePropertiesExpanded(
          'margin: 10px 20px; font: bold 16px Arial',
        );

        expect(result['margin-top'], equals('10px'));
        expect(result['margin-right'], equals('20px'));
        expect(result['font-weight'], equals('bold'));
        expect(result['font-size'], equals('16px'));
        expect(result['font-family'], equals('Arial'));
      });

      test('handles mixed shorthand and longhand', () {
        final result = CssParser.parsePropertiesExpanded(
          'padding: 5px; padding-left: 10px; fill: blue',
        );

        expect(result['padding-top'], equals('5px'));
        expect(result['padding-right'], equals('5px'));
        expect(result['padding-bottom'], equals('5px'));
        expect(result['padding-left'], equals('10px'));
        expect(result['fill'], equals('blue'));
      });

      test('handles animation with multiple values', () {
        final result = CssParser.parsePropertiesExpanded(
          'animation: fadeIn 1s ease-in, slideUp 2s',
        );

        expect(result['animation-name'], equals('fadeIn, slideUp'));
        expect(result['animation-duration'], equals('1s, 2s'));
        expect(result['animation-timing-function'], equals('ease-in, ease'));
      });

      test('handles SVG marker shorthand', () {
        final result = CssParser.parsePropertiesExpanded(
          'marker: url(#arrow); stroke: black',
        );

        expect(result['marker-start'], equals('url(#arrow)'));
        expect(result['marker-mid'], equals('url(#arrow)'));
        expect(result['marker-end'], equals('url(#arrow)'));
        expect(result['stroke'], equals('black'));
      });
    });

    group('Edge Cases', () {
      test('handles empty value', () {
        final result = CssParser.expandShorthand('margin', '');

        expect(result, isNotEmpty);
      });

      test('handles whitespace-only value', () {
        final result = CssParser.expandShorthand('margin', '   ');

        expect(result, isNotEmpty);
      });

      test('handles unknown property', () {
        final result = CssParser.expandShorthand('custom-property', 'value');

        expect(result['custom-property'], equals('value'));
      });

      test('normalizes property names to lowercase', () {
        final result = CssParser.expandShorthand('MARGIN', '10px');

        expect(result['margin-top'], equals('10px'));
      });

      test('handles values with extra whitespace', () {
        final result = CssParser.expandShorthand('margin', '  10px   20px  ');

        expect(result['margin-top'], equals('10px'));
        expect(result['margin-right'], equals('20px'));
      });
    });

    group('isShorthandProperty', () {
      test('identifies font as shorthand', () {
        expect(CssShorthandExpander.isShorthandProperty('font'), isTrue);
      });

      test('identifies animation as shorthand', () {
        expect(CssShorthandExpander.isShorthandProperty('animation'), isTrue);
      });

      test('identifies transition as shorthand', () {
        expect(CssShorthandExpander.isShorthandProperty('transition'), isTrue);
      });

      test('identifies margin as shorthand', () {
        expect(CssShorthandExpander.isShorthandProperty('margin'), isTrue);
      });

      test('identifies padding as shorthand', () {
        expect(CssShorthandExpander.isShorthandProperty('padding'), isTrue);
      });

      test('identifies marker as shorthand', () {
        expect(CssShorthandExpander.isShorthandProperty('marker'), isTrue);
      });

      test('identifies border as shorthand', () {
        expect(CssShorthandExpander.isShorthandProperty('border'), isTrue);
      });

      test('identifies border side properties as shorthand', () {
        expect(CssShorthandExpander.isShorthandProperty('border-top'), isTrue);
        expect(
          CssShorthandExpander.isShorthandProperty('border-right'),
          isTrue,
        );
        expect(
          CssShorthandExpander.isShorthandProperty('border-bottom'),
          isTrue,
        );
        expect(CssShorthandExpander.isShorthandProperty('border-left'), isTrue);
      });

      test('identifies border sub-properties as shorthand', () {
        expect(
          CssShorthandExpander.isShorthandProperty('border-width'),
          isTrue,
        );
        expect(
          CssShorthandExpander.isShorthandProperty('border-style'),
          isTrue,
        );
        expect(
          CssShorthandExpander.isShorthandProperty('border-color'),
          isTrue,
        );
        expect(
          CssShorthandExpander.isShorthandProperty('border-radius'),
          isTrue,
        );
      });

      test('identifies background as shorthand', () {
        expect(CssShorthandExpander.isShorthandProperty('background'), isTrue);
      });

      test('identifies offset as shorthand', () {
        expect(CssShorthandExpander.isShorthandProperty('offset'), isTrue);
      });

      test('returns false for non-shorthand properties', () {
        // Colors
        expect(CssShorthandExpander.isShorthandProperty('color'), isFalse);
        expect(CssShorthandExpander.isShorthandProperty('fill'), isFalse);
        expect(CssShorthandExpander.isShorthandProperty('stroke'), isFalse);

        // Opacity
        expect(CssShorthandExpander.isShorthandProperty('opacity'), isFalse);
        expect(
          CssShorthandExpander.isShorthandProperty('fill-opacity'),
          isFalse,
        );

        // Transform
        expect(CssShorthandExpander.isShorthandProperty('transform'), isFalse);

        // Font longhand properties
        expect(
          CssShorthandExpander.isShorthandProperty('font-family'),
          isFalse,
        );
        expect(CssShorthandExpander.isShorthandProperty('font-size'), isFalse);
        expect(
          CssShorthandExpander.isShorthandProperty('font-weight'),
          isFalse,
        );
        expect(CssShorthandExpander.isShorthandProperty('font-style'), isFalse);

        // Margin/padding longhand properties
        expect(CssShorthandExpander.isShorthandProperty('margin-top'), isFalse);
        expect(
          CssShorthandExpander.isShorthandProperty('margin-left'),
          isFalse,
        );
        expect(
          CssShorthandExpander.isShorthandProperty('padding-top'),
          isFalse,
        );
        expect(
          CssShorthandExpander.isShorthandProperty('padding-bottom'),
          isFalse,
        );

        // Animation longhand properties
        expect(
          CssShorthandExpander.isShorthandProperty('animation-name'),
          isFalse,
        );
        expect(
          CssShorthandExpander.isShorthandProperty('animation-duration'),
          isFalse,
        );

        // Other SVG properties
        expect(
          CssShorthandExpander.isShorthandProperty('stroke-width'),
          isFalse,
        );
        expect(
          CssShorthandExpander.isShorthandProperty('stroke-dasharray'),
          isFalse,
        );
        expect(CssShorthandExpander.isShorthandProperty('visibility'), isFalse);
        expect(CssShorthandExpander.isShorthandProperty('display'), isFalse);
      });

      test('handles case insensitivity', () {
        expect(CssShorthandExpander.isShorthandProperty('MARGIN'), isTrue);
        expect(CssShorthandExpander.isShorthandProperty('Font'), isTrue);
        expect(CssShorthandExpander.isShorthandProperty('ANIMATION'), isTrue);
        expect(CssShorthandExpander.isShorthandProperty('Border'), isTrue);
      });

      test('handles whitespace', () {
        expect(CssShorthandExpander.isShorthandProperty('  margin  '), isTrue);
        expect(CssShorthandExpander.isShorthandProperty(' font '), isTrue);
        expect(CssShorthandExpander.isShorthandProperty('\tpadding\t'), isTrue);
      });
    });
  });
}
