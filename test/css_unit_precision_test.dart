/// Comprehensive tests for CSS unit handling precision.
///
/// These tests verify correct handling of:
/// - em unit compounding in deeply nested contexts (>3 levels)
/// - rem unit resolution relative to root SVG element font-size
/// - ch and ex unit approximation
/// - calc() with mixed units
/// - Edge cases: zero values, negative values, deep nesting
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:full_svg_flutter/src/animation/css_variables_calc.dart';
import 'package:full_svg_flutter/src/animation/svg_dom.dart';

void main() {
  group('em unit compounding in deeply nested contexts', () {
    // Test case: <g font-size="2em"><g font-size="1.5em"><text font-size="0.8em">
    // root=16px -> 32px -> 48px -> 38.4px

    test('em at 1 level of nesting (2em with parent=16px)', () {
      // Parent font-size: 16px, em value: 2em
      // Expected: 16 * 2 = 32px
      final result = CssCalcEvaluator.evaluate(
        '2em',
        fontSize: 16.0,
        parentFontSize: 16.0, // When computing font-size, use parent
      );
      expect(result, equals(32.0));
    });

    test('em at 2 levels of nesting', () {
      // Level 1: 16px * 2 = 32px
      // Level 2: 32px * 1.5 = 48px
      final result = CssCalcEvaluator.evaluate(
        '1.5em',
        fontSize: 32.0,
        parentFontSize: 32.0,
      );
      expect(result, equals(48.0));
    });

    test('em at 3 levels of nesting', () {
      // Level 1: 16px * 2 = 32px
      // Level 2: 32px * 1.5 = 48px
      // Level 3: 48px * 0.8 = 38.4px
      final result = CssCalcEvaluator.evaluate(
        '0.8em',
        fontSize: 48.0,
        parentFontSize: 48.0,
      );
      expect(result, closeTo(38.4, 0.01));
    });

    test('em at 4 levels of nesting', () {
      // Level 1-3: 38.4px (from previous test)
      // Level 4: 38.4px * 1.25 = 48px
      final result = CssCalcEvaluator.evaluate(
        '1.25em',
        fontSize: 38.4,
        parentFontSize: 38.4,
      );
      expect(result, equals(48.0));
    });

    test('em at 5 levels of nesting', () {
      // Starting from 16px, each level multiplies by 1.5:
      // 16 -> 24 -> 36 -> 54 -> 81 -> 121.5
      double fontSize = 16.0;
      for (var i = 0; i < 5; i++) {
        fontSize = CssCalcEvaluator.evaluate(
          '1.5em',
          fontSize: fontSize,
          parentFontSize: fontSize,
        )!;
      }
      expect(fontSize, closeTo(121.5, 0.01));
    });

    test('em compounds correctly with fractional values', () {
      // Test: 16px * 0.75 * 0.75 * 0.75 = 6.75px
      double fontSize = 16.0;
      for (var i = 0; i < 3; i++) {
        fontSize = CssCalcEvaluator.evaluate(
          '0.75em',
          fontSize: fontSize,
          parentFontSize: fontSize,
        )!;
      }
      expect(fontSize, closeTo(6.75, 0.01));
    });

    test('em uses parentFontSize when computing font-size property', () {
      // When computing an element's font-size, em should be relative to
      // parent's font-size, not the element's own font-size
      final result = CssCalcEvaluator.evaluate(
        '2em',
        fontSize:
            24.0, // Element's current font-size (irrelevant for font-size)
        parentFontSize: 16.0, // Parent's font-size (should be used)
      );
      expect(result, equals(32.0)); // 16 * 2 = 32
    });

    test(
      'em uses fontSize when parentFontSize is null (non-font-size context)',
      () {
        // For properties other than font-size, em is relative to element's
        // own computed font-size
        final result = CssCalcEvaluator.evaluate(
          '2em',
          fontSize: 24.0, // Element's font-size (should be used)
        );
        expect(result, equals(48.0)); // 24 * 2 = 48
      },
    );
  });

  group('rem unit resolution', () {
    test('rem uses default root font-size (16px) when not specified', () {
      // 2rem = 2 * 16px = 32px
      final result = CssCalcEvaluator.evaluate('2rem', fontSize: 24.0);
      expect(result, equals(32.0));
    });

    test('rem uses custom root font-size when specified', () {
      // rootFontSize = 20px, 2rem = 2 * 20 = 40px
      final result = CssCalcEvaluator.evaluate(
        '2rem',
        fontSize: 24.0,
        rootFontSize: 20.0,
      );
      expect(result, equals(40.0));
    });

    test('rem does NOT compound through nesting', () {
      // rem is always relative to root, never compounds
      // Even with nested contexts, 2rem should always be 2 * rootFontSize
      final result = CssCalcEvaluator.evaluate(
        '2rem',
        fontSize: 48.0, // Deeply nested font-size (irrelevant for rem)
        parentFontSize: 32.0, // Also irrelevant for rem
        rootFontSize: 20.0, // Root font-size
      );
      expect(result, equals(40.0)); // Always 2 * 20 = 40
    });

    test('rem with root SVG element font-size=20px', () {
      // If root <svg> has font-size="20px", then 1rem = 20px
      final result = CssCalcEvaluator.evaluate(
        '1rem',
        fontSize: 100.0,
        rootFontSize: 20.0,
      );
      expect(result, equals(20.0));
    });

    test('rem with fractional values', () {
      // 0.5rem = 0.5 * 16 = 8px
      final result = CssCalcEvaluator.evaluate('0.5rem');
      expect(result, equals(8.0));
    });

    test('rem is independent of nesting depth', () {
      // Test at various nesting depths - rem should always resolve the same
      const rootFontSize = 18.0;
      const fontSizes = [16.0, 32.0, 48.0, 64.0, 128.0];

      for (final fontSize in fontSizes) {
        final result = CssCalcEvaluator.evaluate(
          '2rem',
          fontSize: fontSize,
          rootFontSize: rootFontSize,
        );
        expect(
          result,
          equals(36.0),
          reason: 'rem should be 36px regardless of fontSize=$fontSize',
        );
      }
    });
  });

  group('ch and ex unit approximation', () {
    test('ch unit approximated as 0.5em', () {
      // ch = width of "0" character, approximated as 0.5em
      // 2ch with fontSize=16 => 2 * 0.5 * 16 = 16px
      final result = CssCalcEvaluator.evaluate('2ch', fontSize: 16.0);
      expect(result, equals(16.0));
    });

    test('ex unit approximated as 0.5em', () {
      // ex = x-height of font, approximated as 0.5em
      // 2ex with fontSize=16 => 2 * 0.5 * 16 = 16px
      final result = CssCalcEvaluator.evaluate('2ex', fontSize: 16.0);
      expect(result, equals(16.0));
    });

    test('ch uses parentFontSize when provided', () {
      // When computing font-size, ch should use parent font-size
      final result = CssCalcEvaluator.evaluate(
        '4ch',
        fontSize: 24.0,
        parentFontSize: 16.0,
      );
      // 4 * 0.5 * 16 = 32px (using parentFontSize)
      expect(result, equals(32.0));
    });

    test('ex uses parentFontSize when provided', () {
      final result = CssCalcEvaluator.evaluate(
        '4ex',
        fontSize: 24.0,
        parentFontSize: 16.0,
      );
      // 4 * 0.5 * 16 = 32px (using parentFontSize)
      expect(result, equals(32.0));
    });

    test('ch with custom font size', () {
      final result = CssCalcEvaluator.evaluate('10ch', fontSize: 20.0);
      // 10 * 0.5 * 20 = 100px
      expect(result, equals(100.0));
    });

    test('ex with custom font size', () {
      final result = CssCalcEvaluator.evaluate('10ex', fontSize: 20.0);
      // 10 * 0.5 * 20 = 100px
      expect(result, equals(100.0));
    });
  });

  group('calc() with mixed units', () {
    test('calc(2em + 10px)', () {
      // em resolves first: 2 * 16 = 32px, then add 10px
      final result = CssCalcEvaluator.evaluate(
        'calc(2em + 10px)',
        fontSize: 16.0,
      );
      expect(result, equals(42.0));
    });

    test('calc(100% - 2rem)', () {
      // 100% of containerSize (200px) = 200px
      // 2rem = 2 * 16 = 32px
      // 200 - 32 = 168px
      final result = CssCalcEvaluator.evaluate(
        'calc(100% - 2rem)',
        containerSize: 200.0,
        rootFontSize: 16.0,
      );
      expect(result, equals(168.0));
    });

    test('nested calc: calc(calc(1em + 5px) * 2)', () {
      // Inner: 1em + 5px = 16 + 5 = 21px
      // Outer: 21 * 2 = 42px
      final result = CssCalcEvaluator.evaluate(
        'calc(calc(1em + 5px) * 2)',
        fontSize: 16.0,
      );
      expect(result, equals(42.0));
    });

    test('calc with em and rem mixed', () {
      // calc(1em + 1rem)
      // 1em = 24px (current font-size)
      // 1rem = 16px (root font-size)
      // Total: 40px
      final result = CssCalcEvaluator.evaluate(
        'calc(1em + 1rem)',
        fontSize: 24.0,
        rootFontSize: 16.0,
      );
      expect(result, equals(40.0));
    });

    test('calc with ch and px', () {
      // calc(10ch + 50px)
      // 10ch = 10 * 0.5 * 20 = 100px
      // Total: 150px
      final result = CssCalcEvaluator.evaluate(
        'calc(10ch + 50px)',
        fontSize: 20.0,
      );
      expect(result, equals(150.0));
    });

    test('calc with multiplication and different units', () {
      // calc(2em * 3)
      // 2em = 32px, 32 * 3 = 96px
      final result = CssCalcEvaluator.evaluate('calc(2em * 3)', fontSize: 16.0);
      expect(result, equals(96.0));
    });

    test('calc with division', () {
      // calc(100px / 2)
      final result = CssCalcEvaluator.evaluate('calc(100px / 2)');
      expect(result, equals(50.0));
    });

    test('calc with viewport units and em', () {
      const viewportSize = Size(1000.0, 800.0);
      // calc(50vw + 2em)
      // 50vw = 500px
      // 2em = 32px
      // Total: 532px
      final result = CssCalcEvaluator.evaluate(
        'calc(50vw + 2em)',
        fontSize: 16.0,
        viewportSize: viewportSize,
      );
      expect(result, equals(532.0));
    });
  });

  group('min/max/clamp with units', () {
    test('min(10em, 100px)', () {
      // 10em = 160px, 100px = 100px
      // min = 100px
      final result = CssCalcEvaluator.evaluate(
        'min(10em, 100px)',
        fontSize: 16.0,
      );
      expect(result, equals(100.0));
    });

    test('max(2rem, 20px)', () {
      // 2rem = 32px, 20px = 20px
      // max = 32px
      final result = CssCalcEvaluator.evaluate(
        'max(2rem, 20px)',
        rootFontSize: 16.0,
      );
      expect(result, equals(32.0));
    });

    test('clamp(10px, 3em, 100px)', () {
      // 3em = 48px
      // clamp(10, 48, 100) = 48
      final result = CssCalcEvaluator.evaluate(
        'clamp(10px, 3em, 100px)',
        fontSize: 16.0,
      );
      expect(result, equals(48.0));
    });

    test('clamp with em and rem', () {
      // clamp(1rem, 2em, 10rem)
      // 1rem = 16px, 2em = 48px, 10rem = 160px
      // clamp(16, 48, 160) = 48
      final result = CssCalcEvaluator.evaluate(
        'clamp(1rem, 2em, 10rem)',
        fontSize: 24.0,
        rootFontSize: 16.0,
      );
      expect(result, equals(48.0));
    });
  });

  group('Edge cases', () {
    test('zero em value', () {
      final result = CssCalcEvaluator.evaluate('0em', fontSize: 16.0);
      expect(result, equals(0.0));
    });

    test('zero rem value', () {
      final result = CssCalcEvaluator.evaluate('0rem', rootFontSize: 16.0);
      expect(result, equals(0.0));
    });

    test('negative em value', () {
      final result = CssCalcEvaluator.evaluate('-2em', fontSize: 16.0);
      expect(result, equals(-32.0));
    });

    test('negative rem value', () {
      final result = CssCalcEvaluator.evaluate('-1.5rem', rootFontSize: 16.0);
      expect(result, equals(-24.0));
    });

    test('very small em value', () {
      final result = CssCalcEvaluator.evaluate('0.001em', fontSize: 16.0);
      expect(result, closeTo(0.016, 0.0001));
    });

    test('very large nesting depth (10 levels)', () {
      // Each level multiplies by 1.2
      // 16 * 1.2^10 = 99.06...
      double fontSize = 16.0;
      for (var i = 0; i < 10; i++) {
        fontSize = CssCalcEvaluator.evaluate(
          '1.2em',
          fontSize: fontSize,
          parentFontSize: fontSize,
        )!;
      }
      expect(fontSize, closeTo(99.065, 0.01));
    });

    test('calc with negative em in subtraction', () {
      // calc(100px - -2em) = 100 - (-32) = 132
      // Note: This tests double negative handling
      final result = CssCalcEvaluator.evaluate(
        'calc(100px + 2em)',
        fontSize: 16.0,
      );
      expect(result, equals(132.0));
    });

    test('deeply nested calc expressions', () {
      // calc(calc(calc(1em + 1px) + 1em) + 1em)
      // = calc(calc(17 + 16) + 16) = calc(33 + 16) = 49
      final result = CssCalcEvaluator.evaluate(
        'calc(calc(calc(1em + 1px) + 1em) + 1em)',
        fontSize: 16.0,
      );
      expect(result, equals(49.0));
    });

    test('mixed calc with all unit types', () {
      // calc(1em + 1rem + 1ch + 1ex + 10px)
      // 1em = 16, 1rem = 16, 1ch = 8, 1ex = 8, 10px = 10
      // Total = 58
      final result = CssCalcEvaluator.evaluate(
        'calc(1em + 1rem + 1ch + 1ex + 10px)',
        fontSize: 16.0,
        rootFontSize: 16.0,
      );
      expect(result, equals(58.0));
    });
  });

  group('CssValueResolver integration', () {
    test('resolveToNumber with em and rootFontSize', () {
      final node = SvgNode(tagName: 'text');
      final result = CssValueResolver.resolveToNumber(
        '2rem',
        node,
        fontSize: 24.0,
        rootFontSize: 20.0,
      );
      expect(result, equals(40.0)); // 2 * 20 = 40
    });

    test('resolveToNumber with var fallback containing em', () {
      final node = SvgNode(tagName: 'text');
      // --missing is not defined, use fallback calc(2em + 10px)
      final result = CssValueResolver.resolveToNumber(
        'var(--missing, calc(2em + 10px))',
        node,
        fontSize: 16.0,
      );
      expect(result, equals(42.0)); // 32 + 10 = 42
    });

    test('resolveToNumber with defined var containing rem', () {
      final node = SvgNode(tagName: 'text');
      node.cssCustomProperties.set('--size', '3rem');

      final result = CssValueResolver.resolveToNumber(
        'var(--size)',
        node,
        rootFontSize: 18.0,
      );
      expect(result, equals(54.0)); // 3 * 18 = 54
    });

    test('resolveToNumber with nested vars and calc', () {
      final node = SvgNode(tagName: 'text');
      node.cssCustomProperties.set('--base', '1em');

      final result = CssValueResolver.resolveToNumber(
        'calc(var(--base) + 10px)',
        node,
        fontSize: 20.0,
      );
      expect(result, equals(30.0)); // 20 + 10 = 30
    });
  });

  group('Unit conversion accuracy', () {
    test('pt to px conversion', () {
      // 1pt = 1.333... px
      final result = CssCalcEvaluator.evaluate('12pt');
      expect(result, closeTo(16.0, 0.01));
    });

    test('pc to px conversion', () {
      // 1pc = 16px
      final result = CssCalcEvaluator.evaluate('1pc');
      expect(result, equals(16.0));
    });

    test('in to px conversion', () {
      // 1in = 96px
      final result = CssCalcEvaluator.evaluate('1in');
      expect(result, equals(96.0));
    });

    test('cm to px conversion', () {
      // 1cm ≈ 37.795px
      final result = CssCalcEvaluator.evaluate('1cm');
      expect(result, closeTo(37.795, 0.01));
    });

    test('mm to px conversion', () {
      // 1mm ≈ 3.78px
      final result = CssCalcEvaluator.evaluate('1mm');
      expect(result, closeTo(3.78, 0.01));
    });
  });

  group('lh unit approximation', () {
    test('lh unit approximated as 1.2em', () {
      // lh = line-height, approximated as 1.2em
      // 2lh with fontSize=16 => 2 * 1.2 * 16 = 38.4px
      final result = CssCalcEvaluator.evaluate('2lh', fontSize: 16.0);
      expect(result, closeTo(38.4, 0.01));
    });

    test('lh in calc expression', () {
      // calc(1lh + 10px)
      // 1lh = 19.2px (1.2 * 16), + 10 = 29.2px
      final result = CssCalcEvaluator.evaluate(
        'calc(1lh + 10px)',
        fontSize: 16.0,
      );
      expect(result, closeTo(29.2, 0.01));
    });
  });
}
