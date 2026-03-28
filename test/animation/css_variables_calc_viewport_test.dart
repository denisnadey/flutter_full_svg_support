import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_svg/src/animation/css_variables_calc.dart';
import 'package:flutter_svg/src/animation/svg_dom.dart';

void main() {
  group('Viewport Unit Resolution', () {
    const viewportSize = Size(1920.0, 1080.0);

    group('vw units', () {
      test('resolves vw with viewport size', () {
        final result = CssCalcEvaluator.evaluate(
          'calc(50vw)',
          viewportSize: viewportSize,
        );
        // 50% of 1920 = 960
        expect(result, equals(960.0));
      });

      test('resolves 100vw to full viewport width', () {
        final result = CssCalcEvaluator.evaluate(
          '100vw',
          viewportSize: viewportSize,
        );
        expect(result, equals(1920.0));
      });

      test('vw returns raw value without viewport', () {
        final result = CssCalcEvaluator.evaluate('50vw');
        // Without viewport, returns raw numeric value
        expect(result, equals(50.0));
      });

      test('vw arithmetic', () {
        final result = CssCalcEvaluator.evaluate(
          'calc(50vw + 100px)',
          viewportSize: viewportSize,
        );
        // 960 + 100 = 1060
        expect(result, equals(1060.0));
      });
    });

    group('vh units', () {
      test('resolves vh with viewport size', () {
        final result = CssCalcEvaluator.evaluate(
          'calc(50vh)',
          viewportSize: viewportSize,
        );
        // 50% of 1080 = 540
        expect(result, equals(540.0));
      });

      test('resolves 100vh to full viewport height', () {
        final result = CssCalcEvaluator.evaluate(
          '100vh',
          viewportSize: viewportSize,
        );
        expect(result, equals(1080.0));
      });

      test('vh returns raw value without viewport', () {
        final result = CssCalcEvaluator.evaluate('50vh');
        expect(result, equals(50.0));
      });

      test('vh arithmetic', () {
        final result = CssCalcEvaluator.evaluate(
          'calc(25vh - 40px)',
          viewportSize: viewportSize,
        );
        // 270 - 40 = 230
        expect(result, equals(230.0));
      });
    });

    group('vmin units', () {
      test('resolves vmin to smaller dimension (height in this case)', () {
        final result = CssCalcEvaluator.evaluate(
          'calc(100vmin)',
          viewportSize: viewportSize,
        );
        // min(1920, 1080) = 1080
        expect(result, equals(1080.0));
      });

      test('resolves 50vmin', () {
        final result = CssCalcEvaluator.evaluate(
          '50vmin',
          viewportSize: viewportSize,
        );
        // 50% of 1080 = 540
        expect(result, equals(540.0));
      });

      test('vmin with portrait viewport', () {
        const portraitViewport = Size(800.0, 1200.0);
        final result = CssCalcEvaluator.evaluate(
          '100vmin',
          viewportSize: portraitViewport,
        );
        // min(800, 1200) = 800
        expect(result, equals(800.0));
      });

      test('vmin returns raw value without viewport', () {
        final result = CssCalcEvaluator.evaluate('50vmin');
        expect(result, equals(50.0));
      });
    });

    group('vmax units', () {
      test('resolves vmax to larger dimension (width in this case)', () {
        final result = CssCalcEvaluator.evaluate(
          'calc(100vmax)',
          viewportSize: viewportSize,
        );
        // max(1920, 1080) = 1920
        expect(result, equals(1920.0));
      });

      test('resolves 50vmax', () {
        final result = CssCalcEvaluator.evaluate(
          '50vmax',
          viewportSize: viewportSize,
        );
        // 50% of 1920 = 960
        expect(result, equals(960.0));
      });

      test('vmax with portrait viewport', () {
        const portraitViewport = Size(800.0, 1200.0);
        final result = CssCalcEvaluator.evaluate(
          '100vmax',
          viewportSize: portraitViewport,
        );
        // max(800, 1200) = 1200
        expect(result, equals(1200.0));
      });

      test('vmax returns raw value without viewport', () {
        final result = CssCalcEvaluator.evaluate('50vmax');
        expect(result, equals(50.0));
      });
    });

    group('mixed viewport units', () {
      test('calc with vw and vh', () {
        final result = CssCalcEvaluator.evaluate(
          'calc(50vw + 50vh)',
          viewportSize: viewportSize,
        );
        // 960 + 540 = 1500
        expect(result, equals(1500.0));
      });

      test('min with vw and vh', () {
        final result = CssCalcEvaluator.evaluate(
          'min(50vw, 50vh)',
          viewportSize: viewportSize,
        );
        // min(960, 540) = 540
        expect(result, equals(540.0));
      });

      test('max with vw and vh', () {
        final result = CssCalcEvaluator.evaluate(
          'max(50vw, 50vh)',
          viewportSize: viewportSize,
        );
        // max(960, 540) = 960
        expect(result, equals(960.0));
      });

      test('clamp with viewport units', () {
        final result = CssCalcEvaluator.evaluate(
          'clamp(10vw, 500px, 50vw)',
          viewportSize: viewportSize,
        );
        // clamp(192, 500, 960) = 500
        expect(result, equals(500.0));
      });

      test('clamp where value exceeds max', () {
        final result = CssCalcEvaluator.evaluate(
          'clamp(10vw, 1000px, 50vw)',
          viewportSize: viewportSize,
        );
        // clamp(192, 1000, 960) = 960 (clamped to max)
        expect(result, equals(960.0));
      });
    });
  });

  group('Percentage Fallback to Viewport', () {
    const viewportSize = Size(1000.0, 800.0);

    test('percentage uses containerSize when available', () {
      final result = CssCalcEvaluator.evaluate(
        '50%',
        containerSize: 200.0,
        viewportSize: viewportSize,
      );
      // Uses containerSize: 50% of 200 = 100
      expect(result, equals(100.0));
    });

    test('percentage falls back to viewport width when containerSize is null', () {
      final result = CssCalcEvaluator.evaluate(
        '50%',
        viewportSize: viewportSize,
      );
      // Falls back to viewportSize.width: 50% of 1000 = 500
      expect(result, equals(500.0));
    });

    test('percentage returns raw value when both are null', () {
      final result = CssCalcEvaluator.evaluate('50%');
      // Neither containerSize nor viewportSize: returns raw 50
      expect(result, equals(50.0));
    });

    test('percentage in calc falls back to viewport', () {
      final result = CssCalcEvaluator.evaluate(
        'calc(50% + 100px)',
        viewportSize: viewportSize,
      );
      // 500 + 100 = 600
      expect(result, equals(600.0));
    });

    test('min with percentage fallback', () {
      final result = CssCalcEvaluator.evaluate(
        'min(50%, 300px)',
        viewportSize: viewportSize,
      );
      // min(500, 300) = 300
      expect(result, equals(300.0));
    });
  });

  group('Nested calc with var fallback', () {
    test('var fallback with calc is evaluated', () {
      final node = SvgNode(tagName: 'rect');
      // --undefined is not defined, so fallback calc(10 + 5) should be used
      final result = CssValueResolver.resolveToNumber(
        'var(--undefined, calc(10 + 5))',
        node,
      );
      expect(result, equals(15.0));
    });

    test('deeply nested var fallback with calc', () {
      final node = SvgNode(tagName: 'rect');
      // Both --a and --b are undefined, so final fallback calc(20 * 2) = 40
      final result = CssValueResolver.resolveToNumber(
        'var(--a, var(--b, calc(20 * 2)))',
        node,
      );
      expect(result, equals(40.0));
    });

    test('var fallback with nested calc', () {
      final node = SvgNode(tagName: 'rect');
      final result = CssValueResolver.resolveToNumber(
        'var(--missing, calc(calc(100 - 20) / 2))',
        node,
      );
      // (100 - 20) / 2 = 40
      expect(result, equals(40.0));
    });

    test('var fallback with calc using units', () {
      final node = SvgNode(tagName: 'rect');
      final result = CssValueResolver.resolveToNumber(
        'var(--missing, calc(2em + 16px))',
        node,
        fontSize: 16.0,
      );
      // 32 + 16 = 48
      expect(result, equals(48.0));
    });

    test('var fallback with calc and viewport units', () {
      final node = SvgNode(tagName: 'rect');
      const viewportSize = Size(1000.0, 800.0);
      final result = CssValueResolver.resolveToNumber(
        'var(--missing, calc(50vw + 100px))',
        node,
        viewportSize: viewportSize,
      );
      // 500 + 100 = 600
      expect(result, equals(600.0));
    });

    test('var with defined value does not use calc fallback', () {
      final node = SvgNode(tagName: 'rect');
      node.cssCustomProperties.set('--size', '200');
      final result = CssValueResolver.resolveToNumber(
        'var(--size, calc(10 + 5))',
        node,
      );
      // Uses defined value 200, not fallback
      expect(result, equals(200.0));
    });

    test('triple nested var with calc fallback', () {
      final node = SvgNode(tagName: 'rect');
      final result = CssValueResolver.resolveToNumber(
        'var(--a, var(--b, var(--c, calc(5 + 5 + 5))))',
        node,
      );
      expect(result, equals(15.0));
    });

    test('calc with min/max in var fallback', () {
      final node = SvgNode(tagName: 'rect');
      final result = CssValueResolver.resolveToNumber(
        'var(--missing, min(100, 50))',
        node,
      );
      expect(result, equals(50.0));
    });

    test('calc with clamp in var fallback', () {
      final node = SvgNode(tagName: 'rect');
      final result = CssValueResolver.resolveToNumber(
        'var(--missing, clamp(10, 50, 100))',
        node,
      );
      expect(result, equals(50.0));
    });
  });

  group('Edge cases', () {
    group('null viewport', () {
      test('vw without viewport returns raw value', () {
        final result = CssCalcEvaluator.evaluate('10vw');
        expect(result, equals(10.0));
      });

      test('vh without viewport returns raw value', () {
        final result = CssCalcEvaluator.evaluate('10vh');
        expect(result, equals(10.0));
      });

      test('vmin without viewport returns raw value', () {
        final result = CssCalcEvaluator.evaluate('10vmin');
        expect(result, equals(10.0));
      });

      test('vmax without viewport returns raw value', () {
        final result = CssCalcEvaluator.evaluate('10vmax');
        expect(result, equals(10.0));
      });

      test('percentage without container or viewport returns raw value', () {
        final result = CssCalcEvaluator.evaluate('10%');
        expect(result, equals(10.0));
      });
    });

    group('zero viewport', () {
      const zeroViewport = Size(0.0, 0.0);

      test('vw with zero viewport width', () {
        final result = CssCalcEvaluator.evaluate(
          '50vw',
          viewportSize: zeroViewport,
        );
        expect(result, equals(0.0));
      });

      test('vh with zero viewport height', () {
        final result = CssCalcEvaluator.evaluate(
          '50vh',
          viewportSize: zeroViewport,
        );
        expect(result, equals(0.0));
      });

      test('vmin with zero viewport', () {
        final result = CssCalcEvaluator.evaluate(
          '50vmin',
          viewportSize: zeroViewport,
        );
        expect(result, equals(0.0));
      });

      test('vmax with zero viewport', () {
        final result = CssCalcEvaluator.evaluate(
          '50vmax',
          viewportSize: zeroViewport,
        );
        expect(result, equals(0.0));
      });
    });

    group('very large values', () {
      const largeViewport = Size(100000.0, 100000.0);

      test('large viewport with vw', () {
        final result = CssCalcEvaluator.evaluate(
          '100vw',
          viewportSize: largeViewport,
        );
        expect(result, equals(100000.0));
      });

      test('large calc with viewport units', () {
        final result = CssCalcEvaluator.evaluate(
          'calc(50vw * 2 + 50vh * 2)',
          viewportSize: largeViewport,
        );
        // (50000 * 2) + (50000 * 2) = 200000
        expect(result, equals(200000.0));
      });

      test('very small viewport', () {
        const tinyViewport = Size(0.01, 0.01);
        final result = CssCalcEvaluator.evaluate(
          '100vw',
          viewportSize: tinyViewport,
        );
        expect(result, closeTo(0.01, 0.0001));
      });
    });

    group('square viewport', () {
      const squareViewport = Size(500.0, 500.0);

      test('vmin equals vmax for square viewport', () {
        final vminResult = CssCalcEvaluator.evaluate(
          '100vmin',
          viewportSize: squareViewport,
        );
        final vmaxResult = CssCalcEvaluator.evaluate(
          '100vmax',
          viewportSize: squareViewport,
        );
        expect(vminResult, equals(vmaxResult));
        expect(vminResult, equals(500.0));
      });
    });

    group('decimal viewport values', () {
      const decimalViewport = Size(1920.5, 1080.5);

      test('vw with decimal viewport width', () {
        final result = CssCalcEvaluator.evaluate(
          '100vw',
          viewportSize: decimalViewport,
        );
        expect(result, equals(1920.5));
      });

      test('vh with decimal viewport height', () {
        final result = CssCalcEvaluator.evaluate(
          '100vh',
          viewportSize: decimalViewport,
        );
        expect(result, equals(1080.5));
      });
    });
  });

  group('CssValueResolver with viewport', () {
    test('resolveToNumber with viewport units', () {
      final node = SvgNode(tagName: 'rect');
      const viewportSize = Size(1000.0, 800.0);

      final result = CssValueResolver.resolveToNumber(
        'calc(50vw + 50vh)',
        node,
        viewportSize: viewportSize,
      );
      // 500 + 400 = 900
      expect(result, equals(900.0));
    });

    test('resolveToNumber combines var() and viewport units', () {
      final node = SvgNode(tagName: 'rect');
      node.cssCustomProperties.set('--offset', '100');
      const viewportSize = Size(1000.0, 800.0);

      final result = CssValueResolver.resolveToNumber(
        'calc(50vw + var(--offset))',
        node,
        viewportSize: viewportSize,
      );
      // 500 + 100 = 600
      expect(result, equals(600.0));
    });

    test('resolve method preserves viewport units as string', () {
      final node = SvgNode(tagName: 'rect');

      final result = CssValueResolver.resolve(
        'calc(50vw + 100px)',
        node,
      );
      // resolve() returns string, doesn't evaluate calc()
      expect(result, equals('calc(50vw + 100px)'));
    });
  });

  group('ch and lh unit approximation', () {
    test('ch unit approximated as 0.5em', () {
      final result = CssCalcEvaluator.evaluate(
        '2ch',
        fontSize: 16.0,
      );
      // 2 * 0.5 * 16 = 16
      expect(result, equals(16.0));
    });

    test('lh unit approximated as 1.2em', () {
      final result = CssCalcEvaluator.evaluate(
        '2lh',
        fontSize: 16.0,
      );
      // 2 * 1.2 * 16 = 38.4
      expect(result, closeTo(38.4, 0.01));
    });

    test('ch in calc expression', () {
      final result = CssCalcEvaluator.evaluate(
        'calc(10ch + 10px)',
        fontSize: 20.0,
      );
      // 10 * 0.5 * 20 + 10 = 100 + 10 = 110
      expect(result, equals(110.0));
    });

    test('lh in calc expression', () {
      final result = CssCalcEvaluator.evaluate(
        'calc(2lh - 10px)',
        fontSize: 20.0,
      );
      // 2 * 1.2 * 20 - 10 = 48 - 10 = 38
      expect(result, equals(38.0));
    });

    test('ch with parentFontSize', () {
      final result = CssCalcEvaluator.evaluate(
        '4ch',
        fontSize: 16.0,
        parentFontSize: 24.0,
      );
      // Uses parentFontSize: 4 * 0.5 * 24 = 48
      expect(result, equals(48.0));
    });
  });
}
