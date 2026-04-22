/// Tests for CSS shorthand property expansion edge cases.
///
/// These tests verify that CSS shorthand properties are correctly expanded
/// into their longhand equivalents, following CSS cascade rules where
/// later declarations override earlier ones at the same specificity level.
import 'package:flutter_test/flutter_test.dart';
import 'package:full_svg_flutter/src/animation/css_animations.dart';

void main() {
  group('CssShorthandExpander', () {
    group('Font shorthand', () {
      test('expands full font shorthand with all properties', () {
        final result = CssShorthandExpander.expandProperty(
          'font',
          'italic small-caps bold 16px/1.2 Arial, sans-serif',
        );

        expect(result['font-style'], equals('italic'));
        expect(result['font-variant'], equals('small-caps'));
        expect(result['font-weight'], equals('bold'));
        expect(result['font-size'], equals('16px'));
        expect(result['line-height'], equals('1.2'));
        expect(result['font-family'], equals('Arial, sans-serif'));
      });

      test(
        'expands font shorthand with missing optional values - resets to initial',
        () {
          final result = CssShorthandExpander.expandProperty(
            'font',
            'bold 14px monospace',
          );

          // Specified values
          expect(result['font-weight'], equals('bold'));
          expect(result['font-size'], equals('14px'));
          expect(result['font-family'], equals('monospace'));

          // Missing values reset to initial
          expect(result['font-style'], equals('normal'));
          expect(result['font-variant'], equals('normal'));
          expect(result['line-height'], equals('normal'));
        },
      );

      test('recognizes system font keywords', () {
        const systemFonts = [
          'caption',
          'icon',
          'menu',
          'message-box',
          'small-caption',
          'status-bar',
        ];

        for (final systemFont in systemFonts) {
          final result = CssShorthandExpander.expandProperty(
            'font',
            systemFont,
          );
          expect(
            result['font'],
            equals(systemFont),
            reason: 'System font "$systemFont" should be recognized',
          );
          expect(
            result['_font-system'],
            equals(systemFont),
            reason: 'System font marker should be set',
          );
        }
      });

      test('individual font-* property overrides font shorthand', () {
        final result = CssShorthandExpander.expandAllOrdered([
          ('font', 'italic bold 16px Arial'),
          ('font-style', 'normal'),
        ]);

        // font-style should be overridden to normal
        expect(result['font-style'], equals('normal'));
        // Other properties from shorthand should remain
        expect(result['font-weight'], equals('bold'));
        expect(result['font-size'], equals('16px'));
      });

      test('handles numeric font weights', () {
        final result = CssShorthandExpander.expandProperty(
          'font',
          '500 12px Helvetica',
        );

        expect(result['font-weight'], equals('500'));
        expect(result['font-size'], equals('12px'));
        expect(result['font-family'], equals('Helvetica'));
      });

      test('handles font-stretch in shorthand', () {
        final result = CssShorthandExpander.expandProperty(
          'font',
          'italic condensed bold 16px Arial',
        );

        expect(result['font-style'], equals('italic'));
        expect(result['font-stretch'], equals('condensed'));
        expect(result['font-weight'], equals('bold'));
        expect(result['font-size'], equals('16px'));
      });

      test('handles quoted font family names', () {
        final result = CssShorthandExpander.expandProperty(
          'font',
          '14px "Times New Roman", serif',
        );

        expect(result['font-size'], equals('14px'));
        expect(result['font-family'], equals('"Times New Roman", serif'));
      });
    });

    group('Margin/Padding shorthand', () {
      test('expands single value to all sides', () {
        final result = CssShorthandExpander.expandProperty('margin', '10px');

        expect(result['margin-top'], equals('10px'));
        expect(result['margin-right'], equals('10px'));
        expect(result['margin-bottom'], equals('10px'));
        expect(result['margin-left'], equals('10px'));
      });

      test('expands two values (vertical | horizontal)', () {
        final result = CssShorthandExpander.expandProperty(
          'margin',
          '10px 20px',
        );

        expect(result['margin-top'], equals('10px'));
        expect(result['margin-right'], equals('20px'));
        expect(result['margin-bottom'], equals('10px'));
        expect(result['margin-left'], equals('20px'));
      });

      test('expands three values (top | horizontal | bottom)', () {
        final result = CssShorthandExpander.expandProperty(
          'margin',
          '10px 20px 30px',
        );

        expect(result['margin-top'], equals('10px'));
        expect(result['margin-right'], equals('20px'));
        expect(result['margin-bottom'], equals('30px'));
        expect(result['margin-left'], equals('20px')); // Same as right
      });

      test('expands four values (top | right | bottom | left)', () {
        final result = CssShorthandExpander.expandProperty(
          'margin',
          '10px 20px 30px 40px',
        );

        expect(result['margin-top'], equals('10px'));
        expect(result['margin-right'], equals('20px'));
        expect(result['margin-bottom'], equals('30px'));
        expect(result['margin-left'], equals('40px'));
      });

      test('individual margin-* overrides shorthand', () {
        final result = CssShorthandExpander.expandAllOrdered([
          ('margin', '10px 20px'),
          ('margin-left', '5px'),
        ]);

        expect(result['margin-top'], equals('10px'));
        expect(result['margin-right'], equals('20px'));
        expect(result['margin-bottom'], equals('10px'));
        expect(result['margin-left'], equals('5px')); // Overridden
      });

      test('later shorthand overrides earlier shorthand', () {
        final result = CssShorthandExpander.expandAllOrdered([
          ('margin', '10px'),
          ('margin', '20px 30px'),
        ]);

        expect(result['margin-top'], equals('20px'));
        expect(result['margin-right'], equals('30px'));
        expect(result['margin-bottom'], equals('20px'));
        expect(result['margin-left'], equals('30px'));
      });

      test('padding shorthand works identically', () {
        final result = CssShorthandExpander.expandProperty(
          'padding',
          '5px 10px 15px',
        );

        expect(result['padding-top'], equals('5px'));
        expect(result['padding-right'], equals('10px'));
        expect(result['padding-bottom'], equals('15px'));
        expect(result['padding-left'], equals('10px'));
      });
    });

    group('Animation shorthand', () {
      test('expands basic animation shorthand', () {
        final result = CssShorthandExpander.expandProperty(
          'animation',
          'slide 1s ease-in',
        );

        expect(result['animation-name'], equals('slide'));
        expect(result['animation-duration'], equals('1s'));
        expect(result['animation-timing-function'], equals('ease-in'));
      });

      test('expands animation with delay', () {
        final result = CssShorthandExpander.expandProperty(
          'animation',
          'slide 1s ease-in 0.5s',
        );

        expect(result['animation-name'], equals('slide'));
        expect(result['animation-duration'], equals('1s'));
        expect(result['animation-timing-function'], equals('ease-in'));
        expect(result['animation-delay'], equals('0.5s'));
      });

      test('individual animation-delay overrides shorthand', () {
        final result = CssShorthandExpander.expandAllOrdered([
          ('animation', 'slide 1s ease-in'),
          ('animation-delay', '0.5s'),
        ]);

        expect(result['animation-name'], equals('slide'));
        expect(result['animation-duration'], equals('1s'));
        expect(result['animation-delay'], equals('0.5s')); // Overridden
      });

      test('multiple animations with comma separation', () {
        final result = CssShorthandExpander.expandProperty(
          'animation',
          'slide 1s, fade 2s',
        );

        // For multiple animations, names are comma-separated
        expect(result['animation-name'], equals('slide, fade'));
        expect(result['animation-duration'], equals('1s, 2s'));
      });

      test('animation-duration override applies to all animations', () {
        final result = CssShorthandExpander.expandAllOrdered([
          ('animation', 'slide 1s, fade 2s'),
          ('animation-duration', '3s'),
        ]);

        expect(result['animation-name'], equals('slide, fade'));
        expect(
          result['animation-duration'],
          equals('3s'),
        ); // Overridden for all
      });

      test('handles cubic-bezier timing function', () {
        final result = CssShorthandExpander.expandProperty(
          'animation',
          'bounce 1.5s cubic-bezier(0.68, -0.55, 0.265, 1.55)',
        );

        expect(result['animation-name'], equals('bounce'));
        expect(
          result['animation-timing-function'],
          equals('cubic-bezier(0.68, -0.55, 0.265, 1.55)'),
        );
      });

      test('handles infinite iteration count', () {
        final result = CssShorthandExpander.expandProperty(
          'animation',
          'spin 2s linear infinite',
        );

        expect(result['animation-name'], equals('spin'));
        expect(result['animation-iteration-count'], equals('infinite'));
      });

      test('handles all animation properties', () {
        final result = CssShorthandExpander.expandProperty(
          'animation',
          'pulse 1s ease-in-out 0.5s infinite alternate both paused',
        );

        expect(result['animation-name'], equals('pulse'));
        expect(result['animation-duration'], equals('1s'));
        expect(result['animation-timing-function'], equals('ease-in-out'));
        expect(result['animation-delay'], equals('0.5s'));
        expect(result['animation-iteration-count'], equals('infinite'));
        expect(result['animation-direction'], equals('alternate'));
        expect(result['animation-fill-mode'], equals('both'));
        expect(result['animation-play-state'], equals('paused'));
      });
    });

    group('Border shorthand', () {
      test('expands basic border shorthand', () {
        final result = CssShorthandExpander.expandProperty(
          'border',
          '1px solid black',
        );

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

      test('border-left-color overrides border shorthand', () {
        final result = CssShorthandExpander.expandAllOrdered([
          ('border', '1px solid black'),
          ('border-left-color', 'red'),
        ]);

        // Other borders remain black
        expect(result['border-top-color'], equals('black'));
        expect(result['border-right-color'], equals('black'));
        expect(result['border-bottom-color'], equals('black'));

        // Left border is red
        expect(result['border-left-color'], equals('red'));
      });

      test('border-left shorthand', () {
        final result = CssShorthandExpander.expandProperty(
          'border-left',
          '2px dashed blue',
        );

        expect(result['border-left-width'], equals('2px'));
        expect(result['border-left-style'], equals('dashed'));
        expect(result['border-left-color'], equals('blue'));

        // Other sides should not be set
        expect(result.containsKey('border-top-width'), isFalse);
        expect(result.containsKey('border-right-width'), isFalse);
      });

      test('border-top overrides border shorthand for top side only', () {
        final result = CssShorthandExpander.expandAllOrdered([
          ('border', '1px solid black'),
          ('border-top', '3px dotted green'),
        ]);

        // Top border is overridden
        expect(result['border-top-width'], equals('3px'));
        expect(result['border-top-style'], equals('dotted'));
        expect(result['border-top-color'], equals('green'));

        // Other borders unchanged
        expect(result['border-right-width'], equals('1px'));
        expect(result['border-bottom-style'], equals('solid'));
        expect(result['border-left-color'], equals('black'));
      });

      test('border-width shorthand with 3 values', () {
        final result = CssShorthandExpander.expandProperty(
          'border-width',
          '1px 2px 3px',
        );

        expect(result['border-top-width'], equals('1px'));
        expect(result['border-right-width'], equals('2px'));
        expect(result['border-bottom-width'], equals('3px'));
        expect(result['border-left-width'], equals('2px')); // Same as right
      });

      test('border-color shorthand with 4 values', () {
        final result = CssShorthandExpander.expandProperty(
          'border-color',
          'red green blue yellow',
        );

        expect(result['border-top-color'], equals('red'));
        expect(result['border-right-color'], equals('green'));
        expect(result['border-bottom-color'], equals('blue'));
        expect(result['border-left-color'], equals('yellow'));
      });
    });

    group('Cascade and specificity interactions', () {
      test('last declaration wins at same specificity', () {
        final result = CssShorthandExpander.expandAllOrdered([
          ('margin', '10px'),
          ('margin', '20px'),
        ]);

        expect(result['margin-top'], equals('20px'));
      });

      test('longhand after shorthand wins', () {
        final result = CssShorthandExpander.expandAllOrdered([
          ('font', 'bold 16px Arial'),
          ('font-weight', 'normal'),
        ]);

        expect(result['font-weight'], equals('normal'));
        expect(result['font-size'], equals('16px'));
      });

      test('shorthand after longhand resets all values', () {
        final result = CssShorthandExpander.expandAllOrdered([
          ('font-weight', '900'),
          ('font', '14px monospace'),
        ]);

        // font shorthand should reset font-weight to normal
        expect(result['font-weight'], equals('normal'));
        expect(result['font-size'], equals('14px'));
      });

      test('complex cascade with multiple shorthand/longhand', () {
        final result = CssShorthandExpander.expandAllOrdered([
          ('margin', '10px'),
          ('margin-left', '5px'),
          ('margin', '15px 20px'),
          ('margin-top', '25px'),
        ]);

        expect(result['margin-top'], equals('25px')); // Last override
        expect(result['margin-right'], equals('20px')); // From second margin
        expect(result['margin-bottom'], equals('15px')); // From second margin
        expect(
          result['margin-left'],
          equals('20px'),
        ); // From second margin (overrides 5px)
      });
    });

    group('Border radius shorthand', () {
      test('single value applies to all corners', () {
        final result = CssShorthandExpander.expandProperty(
          'border-radius',
          '10px',
        );

        expect(result['border-top-left-radius'], equals('10px'));
        expect(result['border-top-right-radius'], equals('10px'));
        expect(result['border-bottom-right-radius'], equals('10px'));
        expect(result['border-bottom-left-radius'], equals('10px'));
      });

      test('horizontal/vertical syntax', () {
        final result = CssShorthandExpander.expandProperty(
          'border-radius',
          '10px 20px / 5px 15px',
        );

        expect(result['border-top-left-radius'], equals('10px 5px'));
        expect(result['border-top-right-radius'], equals('20px 15px'));
        expect(result['border-bottom-right-radius'], equals('10px 5px'));
        expect(result['border-bottom-left-radius'], equals('20px 15px'));
      });
    });

    group('Background shorthand', () {
      test('simple color background', () {
        final result = CssShorthandExpander.expandProperty('background', 'red');

        expect(result['background-color'], equals('red'));
      });

      test('background with image and position', () {
        final result = CssShorthandExpander.expandProperty(
          'background',
          'url(image.png) no-repeat center',
        );

        expect(result['background-image'], equals('url(image.png)'));
        expect(result['background-repeat'], equals('no-repeat'));
        expect(result['background-position'], contains('center'));
      });
    });
  });
}
