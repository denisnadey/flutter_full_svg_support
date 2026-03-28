import 'package:flutter/material.dart';
import 'package:flutter_svg/src/animation/animated_svg_picture.dart';
import 'package:flutter_svg/src/animation/css_variables_calc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Nested calc() expressions', () {
    test('simple nested calc(calc(...))', () {
      final result = CssCalcEvaluator.evaluate('calc(calc(50 + 10) - 5)');
      expect(result, equals(55.0));
    });

    test('nested calc with units: calc(calc(50% + 10px) - 5px)', () {
      final result = CssCalcEvaluator.evaluate(
        'calc(calc(50% + 10px) - 5px)',
        containerSize: 100.0,
      );
      expect(result, equals(55.0)); // 50 + 10 - 5 = 55
    });

    test(
      'deeply nested (3+ levels): calc(calc(calc(100% - 10px) / 2) + 5px)',
      () {
        final result = CssCalcEvaluator.evaluate(
          'calc(calc(calc(100% - 10px) / 2) + 5px)',
          containerSize: 100.0,
        );
        expect(result, equals(50.0)); // ((100 - 10) / 2) + 5 = 45 + 5 = 50
      },
    );

    test('deeply nested (4 levels)', () {
      final result = CssCalcEvaluator.evaluate(
        'calc(calc(calc(calc(100 - 20) / 2) * 3) + 10)',
      );
      expect(result, equals(130.0)); // (((100 - 20) / 2) * 3) + 10 = 130
    });

    test('deeply nested (5 levels)', () {
      final result = CssCalcEvaluator.evaluate(
        'calc(calc(calc(calc(calc(200 - 100) / 2) * 4) - 50) + 25)',
      );
      expect(
        result,
        equals(175.0),
      ); // ((((200 - 100) / 2) * 4) - 50) + 25 = 175
    });
  });

  group('CSS min() function', () {
    test('min with 2 values in px', () {
      final result = CssCalcEvaluator.evaluate('min(100px, 50px)');
      expect(result, equals(50.0));
    });

    test('min with 3 values', () {
      final result = CssCalcEvaluator.evaluate('min(10px, 20px, 30px)');
      expect(result, equals(10.0));
    });

    test('min with 4 values', () {
      final result = CssCalcEvaluator.evaluate('min(40px, 10px, 30px, 20px)');
      expect(result, equals(10.0));
    });

    test('min with percentage and px (with containerSize)', () {
      final result = CssCalcEvaluator.evaluate(
        'min(100px, 50%)',
        containerSize: 300.0,
      );
      expect(result, equals(100.0)); // min(100, 150) = 100
    });

    test('min with percentage and px where % is smaller', () {
      final result = CssCalcEvaluator.evaluate(
        'min(100px, 50%)',
        containerSize: 100.0,
      );
      expect(result, equals(50.0)); // min(100, 50) = 50
    });

    test('min with calc inside', () {
      final result = CssCalcEvaluator.evaluate('min(calc(100 - 20), 50)');
      expect(result, equals(50.0)); // min(80, 50) = 50
    });

    test('nested min: min(min(10, 20), 15)', () {
      final result = CssCalcEvaluator.evaluate('min(min(10, 20), 15)');
      expect(result, equals(10.0));
    });
  });

  group('CSS max() function', () {
    test('max with 2 values in px', () {
      final result = CssCalcEvaluator.evaluate('max(100px, 50px)');
      expect(result, equals(100.0));
    });

    test('max with 3 values', () {
      final result = CssCalcEvaluator.evaluate('max(10px, 30px, 20px)');
      expect(result, equals(30.0));
    });

    test('max with percentage and px (with containerSize)', () {
      final result = CssCalcEvaluator.evaluate(
        'max(100px, 50%)',
        containerSize: 300.0,
      );
      expect(result, equals(150.0)); // max(100, 150) = 150
    });

    test('max with calc inside', () {
      final result = CssCalcEvaluator.evaluate('max(calc(100 - 80), 50)');
      expect(result, equals(50.0)); // max(20, 50) = 50
    });

    test('nested max: max(max(10, 20), 15)', () {
      final result = CssCalcEvaluator.evaluate('max(max(10, 20), 15)');
      expect(result, equals(20.0));
    });
  });

  group('CSS clamp() function', () {
    test('clamp(min, val, max) with value in range', () {
      final result = CssCalcEvaluator.evaluate('clamp(10px, 50px, 200px)');
      expect(result, equals(50.0));
    });

    test('clamp with value below min', () {
      final result = CssCalcEvaluator.evaluate('clamp(10px, 5px, 200px)');
      expect(result, equals(10.0)); // clamped to min
    });

    test('clamp with value above max', () {
      final result = CssCalcEvaluator.evaluate('clamp(10px, 300px, 200px)');
      expect(result, equals(200.0)); // clamped to max
    });

    test('clamp with percentage in val (with containerSize)', () {
      final result = CssCalcEvaluator.evaluate(
        'clamp(10px, 50%, 200px)',
        containerSize: 400.0,
      );
      expect(result, equals(200.0)); // 50% of 400 = 200, clamped to max 200
    });

    test('clamp with calc inside', () {
      final result = CssCalcEvaluator.evaluate(
        'clamp(10px, calc(100px + 50px), 200px)',
      );
      expect(result, equals(150.0));
    });

    test('nested clamp inside calc', () {
      final result = CssCalcEvaluator.evaluate('calc(clamp(10, 50, 100) + 10)');
      expect(result, equals(60.0)); // 50 + 10
    });
  });

  group('Mixed units in arithmetic', () {
    test('calc(100% - 50px) with containerSize', () {
      final result = CssCalcEvaluator.evaluate(
        'calc(100% - 50px)',
        containerSize: 200.0,
      );
      expect(result, equals(150.0)); // 200 - 50 = 150
    });

    test('calc(50% + 50%) with containerSize', () {
      final result = CssCalcEvaluator.evaluate(
        'calc(50% + 50%)',
        containerSize: 100.0,
      );
      expect(result, equals(100.0)); // 50 + 50 = 100
    });

    test('calc with em units', () {
      final result = CssCalcEvaluator.evaluate(
        'calc(2em + 16px)',
        fontSize: 16.0,
      );
      expect(result, equals(48.0)); // 32 + 16 = 48
    });

    test('calc with rem units', () {
      final result = CssCalcEvaluator.evaluate('calc(2rem + 8px)');
      expect(result, equals(40.0)); // 32 (2*16) + 8 = 40
    });

    test('calc with mixed em and percentage', () {
      final result = CssCalcEvaluator.evaluate(
        'calc(50% + 1em)',
        fontSize: 16.0,
        containerSize: 200.0,
      );
      expect(result, equals(116.0)); // 100 + 16 = 116
    });
  });

  group('Multiplication and division', () {
    test('calc(100px * 2)', () {
      final result = CssCalcEvaluator.evaluate('calc(100px * 2)');
      expect(result, equals(200.0));
    });

    test('calc(200px / 4)', () {
      final result = CssCalcEvaluator.evaluate('calc(200px / 4)');
      expect(result, equals(50.0));
    });

    test('calc with multiplication by decimal', () {
      final result = CssCalcEvaluator.evaluate('calc(100px * 0.5)');
      expect(result, equals(50.0));
    });

    test('calc with operator precedence (multiply before add)', () {
      final result = CssCalcEvaluator.evaluate('calc(10px + 5px * 2)');
      expect(result, equals(20.0)); // 10 + 10 = 20
    });

    test('calc with operator precedence (divide before subtract)', () {
      final result = CssCalcEvaluator.evaluate('calc(100px - 20px / 2)');
      expect(result, equals(90.0)); // 100 - 10 = 90
    });

    test('calc with multiple multiplications', () {
      final result = CssCalcEvaluator.evaluate('calc(2 * 3 * 4)');
      expect(result, equals(24.0));
    });

    test('calc with division by zero returns zero', () {
      final result = CssCalcEvaluator.evaluate('calc(100 / 0)');
      expect(result, equals(0.0));
    });
  });

  group('Percentage arithmetic', () {
    test('calc(50% + 25%) with containerSize', () {
      final result = CssCalcEvaluator.evaluate(
        'calc(50% + 25%)',
        containerSize: 200.0,
      );
      expect(result, equals(150.0)); // 100 + 50 = 150
    });

    test('calc(100% - 25%) with containerSize', () {
      final result = CssCalcEvaluator.evaluate(
        'calc(100% - 25%)',
        containerSize: 200.0,
      );
      expect(result, equals(150.0)); // 200 - 50 = 150
    });

    test('calc(50% * 2) with containerSize', () {
      final result = CssCalcEvaluator.evaluate(
        'calc(50% * 2)',
        containerSize: 200.0,
      );
      expect(result, equals(200.0)); // 100 * 2 = 200
    });

    test('calc(100% / 4) with containerSize', () {
      final result = CssCalcEvaluator.evaluate(
        'calc(100% / 4)',
        containerSize: 200.0,
      );
      expect(result, equals(50.0)); // 200 / 4 = 50
    });
  });

  group('Invalid expressions (graceful fallback)', () {
    test('empty calc() returns null', () {
      final result = CssCalcEvaluator.evaluate('calc()');
      expect(result, isNull);
    });

    test('calc with trailing operator returns null or empty expression', () {
      // Trailing operators may cause parsing issues - should return a result
      // based on the valid part, or null if completely invalid
      final result = CssCalcEvaluator.evaluate('calc(10px +)');
      // The parser sees "10px" and "+" separately, then fails on empty next token
      // This depends on implementation - we verify it doesn't crash
      expect(result == null || result == 10.0, isTrue);
    });

    test('calc with leading operator (except minus) handles gracefully', () {
      // Leading + may be parsed as part of the first number or as operator
      final result = CssCalcEvaluator.evaluate('calc(+ 10px)');
      // The parser should handle this gracefully, either returning 10 or null
      expect(result == null || result == 10.0, isTrue);
    });

    test('calc with invalid characters returns null', () {
      final result = CssCalcEvaluator.evaluate('calc(abc)');
      expect(result, isNull);
    });

    test('calc with unmatched parentheses returns null', () {
      final result = CssCalcEvaluator.evaluate('calc((10 + 5)');
      expect(result, isNull);
    });

    test('min with no arguments returns null', () {
      final result = CssCalcEvaluator.evaluate('min()');
      expect(result, isNull);
    });

    test('clamp with wrong number of arguments returns null', () {
      final result = CssCalcEvaluator.evaluate('clamp(10, 20)');
      expect(result, isNull);
    });

    test('deeply excessive nesting still evaluates (up to depth limit)', () {
      // Build a moderately nested expression
      var expr = '100';
      for (var i = 0; i < 15; i++) {
        expr = 'calc($expr + 1)';
      }
      // This should still evaluate successfully within depth limit
      final result = CssCalcEvaluator.evaluate(expr);
      // 100 + 15 = 115
      expect(result, equals(115.0));
    });
  });

  group('Whitespace handling', () {
    test('calc with extra whitespace', () {
      final result = CssCalcEvaluator.evaluate('calc(  100px   +   50px  )');
      expect(result, equals(150.0));
    });

    test('calc with newlines', () {
      final result = CssCalcEvaluator.evaluate('calc(100px\n+\n50px)');
      expect(result, equals(150.0));
    });

    test('calc with tabs', () {
      final result = CssCalcEvaluator.evaluate('calc(100px\t+\t50px)');
      expect(result, equals(150.0));
    });

    test('calc with no spaces around operators', () {
      // Per CSS spec, + and - need whitespace, but * and / don't
      final result = CssCalcEvaluator.evaluate('calc(100px*2)');
      expect(result, equals(200.0));
    });

    test('calc with spaces around multiplication', () {
      final result = CssCalcEvaluator.evaluate('calc(100px * 2)');
      expect(result, equals(200.0));
    });
  });

  group('Negative numbers', () {
    test('calc with negative result', () {
      final result = CssCalcEvaluator.evaluate('calc(10 - 20)');
      expect(result, equals(-10.0));
    });

    test('calc starting with negative number', () {
      final result = CssCalcEvaluator.evaluate('calc(-10 + 30)');
      expect(result, equals(20.0));
    });

    test('calc with negative multiplier', () {
      final result = CssCalcEvaluator.evaluate('calc(10 * -2)');
      expect(result, equals(-20.0));
    });

    test('calc with negative unit value', () {
      final result = CssCalcEvaluator.evaluate('calc(-50px + 100px)');
      expect(result, equals(50.0));
    });
  });

  group('Scientific notation', () {
    test('calc with scientific notation', () {
      final result = CssCalcEvaluator.evaluate('calc(1e2 + 50)');
      expect(result, equals(150.0));
    });

    test('calc with negative exponent', () {
      final result = CssCalcEvaluator.evaluate('calc(1e-1 + 0.9)');
      expect(result, closeTo(1.0, 0.1)); // 0.1 + 0.9 = 1.0
    });
  });

  group('Complex combinations', () {
    test('min inside calc', () {
      final result = CssCalcEvaluator.evaluate('calc(min(100, 50) + 25)');
      expect(result, equals(75.0)); // 50 + 25
    });

    test('max inside calc', () {
      final result = CssCalcEvaluator.evaluate('calc(max(100, 50) - 25)');
      expect(result, equals(75.0)); // 100 - 25
    });

    test('clamp inside calc', () {
      final result = CssCalcEvaluator.evaluate('calc(clamp(10, 50, 100) * 2)');
      expect(result, equals(100.0)); // 50 * 2
    });

    test('multiple math functions', () {
      final result = CssCalcEvaluator.evaluate(
        'calc(min(100, 200) + max(10, 20))',
      );
      expect(result, equals(120.0)); // 100 + 20
    });

    test('nested min and max', () {
      final result = CssCalcEvaluator.evaluate('max(min(100, 50), 75)');
      expect(result, equals(75.0)); // max(50, 75) = 75
    });
  });

  group('calc() in transform values rendering', () {
    testWidgets('translate with calc() renders correctly', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 200" xmlns="http://www.w3.org/2000/svg">
          <style>
            .calc-translate {
              transform: translate(calc(100px - 50px), calc(50px + 10px));
            }
          </style>
          <rect class="calc-translate" x="0" y="0" width="50" height="50" fill="red"/>
        </svg>
      ''';

      await tester.pumpWidget(
        MaterialApp(
          home: AnimatedSvgPicture.string(svg, width: 200, height: 200),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('scale with calc() renders correctly', (tester) async {
      const svg = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <style>
            .calc-scale {
              transform: scale(calc(0.5 + 0.5), calc(2 - 0.5));
            }
          </style>
          <rect class="calc-scale" x="25" y="25" width="50" height="50" fill="blue"/>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 100, height: 100),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('rotate with calc() renders correctly', (tester) async {
      const svg = '''
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <style>
            .calc-rotate {
              transform: rotate(calc(45deg + 45deg));
            }
          </style>
          <rect class="calc-rotate" x="25" y="25" width="50" height="50" fill="green"/>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 100, height: 100),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('complex transform with nested calc()', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 200" xmlns="http://www.w3.org/2000/svg">
          <style>
            .complex-calc {
              transform: translate(calc(calc(100px - 50px) + 10px), 20px) rotate(calc(30deg + 15deg));
            }
          </style>
          <rect class="complex-calc" x="0" y="0" width="50" height="50" fill="purple"/>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 200, height: 200),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('transform with min/max renders correctly', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 200" xmlns="http://www.w3.org/2000/svg">
          <style>
            .minmax-transform {
              transform: translate(min(100px, 50px), max(10px, 30px));
            }
          </style>
          <rect class="minmax-transform" x="0" y="0" width="50" height="50" fill="orange"/>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 200, height: 200),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('transform with clamp renders correctly', (tester) async {
      const svg = '''
        <svg viewBox="0 0 200 200" xmlns="http://www.w3.org/2000/svg">
          <style>
            .clamp-transform {
              transform: translateX(clamp(10px, 50px, 100px));
            }
          </style>
          <rect class="clamp-transform" x="0" y="50" width="50" height="50" fill="cyan"/>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 200, height: 200),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });

  group('Unit edge cases', () {
    test('calc with pt units', () {
      final result = CssCalcEvaluator.evaluate('calc(12pt + 12pt)');
      expect(result, closeTo(32.0, 0.1)); // 12pt ≈ 16px, so 16 + 16 = 32
    });

    test('calc with cm units', () {
      final result = CssCalcEvaluator.evaluate('calc(1cm + 1cm)');
      expect(result, closeTo(75.6, 0.1)); // 1cm ≈ 37.8px
    });

    test('calc with mm units', () {
      final result = CssCalcEvaluator.evaluate('calc(10mm + 10mm)');
      expect(result, closeTo(75.6, 0.1)); // 10mm ≈ 37.8px
    });

    test('calc with in units', () {
      final result = CssCalcEvaluator.evaluate('calc(0.5in + 0.5in)');
      expect(result, closeTo(96.0, 0.1)); // 1in = 96px
    });

    test('calc with vw units (no viewport, returns numeric value)', () {
      final result = CssCalcEvaluator.evaluate('calc(50vw + 50vw)');
      expect(result, equals(100.0)); // Without viewport, just numeric addition
    });

    test('calc with ex units', () {
      final result = CssCalcEvaluator.evaluate(
        'calc(2ex + 2ex)',
        fontSize: 16.0,
      );
      // ex ≈ 0.5 * fontSize, so 2ex = 2 * 8 = 16, total = 32
      expect(result, equals(32.0));
    });

    test('calc with ch units', () {
      final result = CssCalcEvaluator.evaluate(
        'calc(2ch + 2ch)',
        fontSize: 16.0,
      );
      // ch ≈ 0.5 * fontSize, so 2ch = 2 * 8 = 16, total = 32
      expect(result, equals(32.0));
    });
  });

  group('Case insensitivity', () {
    test('CALC() uppercase', () {
      final result = CssCalcEvaluator.evaluate('CALC(100 + 50)');
      expect(result, equals(150.0));
    });

    test('Calc() mixed case', () {
      final result = CssCalcEvaluator.evaluate('Calc(100 + 50)');
      expect(result, equals(150.0));
    });

    test('MIN() uppercase', () {
      final result = CssCalcEvaluator.evaluate('MIN(100, 50)');
      expect(result, equals(50.0));
    });

    test('MAX() uppercase', () {
      final result = CssCalcEvaluator.evaluate('MAX(100, 50)');
      expect(result, equals(100.0));
    });

    test('CLAMP() uppercase', () {
      final result = CssCalcEvaluator.evaluate('CLAMP(10, 50, 100)');
      expect(result, equals(50.0));
    });

    test('PX unit uppercase', () {
      final result = CssCalcEvaluator.evaluate('calc(100PX + 50PX)');
      expect(result, equals(150.0));
    });

    test('EM unit uppercase', () {
      final result = CssCalcEvaluator.evaluate('calc(2EM)', fontSize: 16.0);
      expect(result, equals(32.0));
    });
  });

  group('Decimal precision', () {
    test('calc with many decimal places', () {
      final result = CssCalcEvaluator.evaluate(
        'calc(1.123456789 + 2.987654321)',
      );
      expect(result, closeTo(4.11111111, 0.0001));
    });

    test('calc avoiding floating point errors', () {
      final result = CssCalcEvaluator.evaluate('calc(0.1 + 0.2)');
      expect(result, closeTo(0.3, 0.0001));
    });
  });

  group('containsCssMathFunction utility', () {
    test('detects calc()', () {
      expect(containsCssMathFunction('calc(10 + 5)'), isTrue);
    });

    test('detects min()', () {
      expect(containsCssMathFunction('min(10, 5)'), isTrue);
    });

    test('detects max()', () {
      expect(containsCssMathFunction('max(10, 5)'), isTrue);
    });

    test('detects clamp()', () {
      expect(containsCssMathFunction('clamp(10, 20, 30)'), isTrue);
    });

    test('returns false for plain values', () {
      expect(containsCssMathFunction('100px'), isFalse);
    });

    test('case insensitive', () {
      expect(containsCssMathFunction('CALC(10 + 5)'), isTrue);
      expect(containsCssMathFunction('Min(10, 5)'), isTrue);
    });
  });
}
