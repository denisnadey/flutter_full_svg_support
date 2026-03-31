import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/src/animation/svg_filters.dart';

void main() {
  group('SvgComponentTransferFunction edge cases', () {
    group('discrete function', () {
      test('empty tableValues should return input unchanged (identity)', () {
        const func = SvgComponentTransferFunction(
          type: SvgComponentTransferType.discrete,
          tableValues: <double>[],
        );

        expect(func.apply(0.0), equals(0.0));
        expect(func.apply(0.5), equals(0.5));
        expect(func.apply(1.0), equals(1.0));
      });

      test('single value should return that value for all inputs', () {
        const func = SvgComponentTransferFunction(
          type: SvgComponentTransferType.discrete,
          tableValues: <double>[0.7],
        );

        expect(func.apply(0.0), closeTo(0.7, 0.001));
        expect(func.apply(0.25), closeTo(0.7, 0.001));
        expect(func.apply(0.5), closeTo(0.7, 0.001));
        expect(func.apply(0.75), closeTo(0.7, 0.001));
        expect(func.apply(1.0), closeTo(0.7, 0.001));
      });

      test('two values should split input range in half', () {
        const func = SvgComponentTransferFunction(
          type: SvgComponentTransferType.discrete,
          tableValues: <double>[0.0, 1.0],
        );

        // [0, 0.5) -> 0.0, [0.5, 1.0] -> 1.0
        expect(func.apply(0.0), equals(0.0));
        expect(func.apply(0.25), equals(0.0));
        expect(func.apply(0.49), equals(0.0));
        expect(func.apply(0.5), equals(1.0));
        expect(func.apply(0.75), equals(1.0));
        expect(func.apply(1.0), equals(1.0));
      });

      test('edge case: input = 1.0 should return last table value', () {
        const func = SvgComponentTransferFunction(
          type: SvgComponentTransferType.discrete,
          tableValues: <double>[0.1, 0.3, 0.5, 0.9],
        );

        // With 4 values, input 1.0 should map to index 3 (clamped from 4)
        expect(func.apply(1.0), closeTo(0.9, 0.001));
      });

      test('many table values should produce step function', () {
        const func = SvgComponentTransferFunction(
          type: SvgComponentTransferType.discrete,
          tableValues: <double>[0.0, 0.25, 0.5, 0.75, 1.0],
        );

        // 5 values create 5 intervals: [0, 0.2), [0.2, 0.4), etc.
        expect(func.apply(0.0), equals(0.0));
        expect(func.apply(0.19), equals(0.0));
        expect(func.apply(0.2), closeTo(0.25, 0.001));
        expect(func.apply(0.39), closeTo(0.25, 0.001));
        expect(func.apply(0.4), closeTo(0.5, 0.001));
      });
    });

    group('table function', () {
      test('empty tableValues should return input unchanged', () {
        const func = SvgComponentTransferFunction(
          type: SvgComponentTransferType.table,
          tableValues: <double>[],
        );

        expect(func.apply(0.0), equals(0.0));
        expect(func.apply(0.5), equals(0.5));
        expect(func.apply(1.0), equals(1.0));
      });

      test('single value should return that value clamped', () {
        const func = SvgComponentTransferFunction(
          type: SvgComponentTransferType.table,
          tableValues: <double>[0.5],
        );

        expect(func.apply(0.0), closeTo(0.5, 0.001));
        expect(func.apply(0.5), closeTo(0.5, 0.001));
        expect(func.apply(1.0), closeTo(0.5, 0.001));
      });

      test('two values should interpolate linearly', () {
        const func = SvgComponentTransferFunction(
          type: SvgComponentTransferType.table,
          tableValues: <double>[0.0, 1.0],
        );

        expect(func.apply(0.0), closeTo(0.0, 0.001));
        expect(func.apply(0.25), closeTo(0.25, 0.001));
        expect(func.apply(0.5), closeTo(0.5, 0.001));
        expect(func.apply(0.75), closeTo(0.75, 0.001));
        expect(func.apply(1.0), closeTo(1.0, 0.001));
      });

      test('reverse table should invert', () {
        const func = SvgComponentTransferFunction(
          type: SvgComponentTransferType.table,
          tableValues: <double>[1.0, 0.0],
        );

        expect(func.apply(0.0), closeTo(1.0, 0.001));
        expect(func.apply(0.5), closeTo(0.5, 0.001));
        expect(func.apply(1.0), closeTo(0.0, 0.001));
      });

      test('table with values outside [0,1] should still work', () {
        const func = SvgComponentTransferFunction(
          type: SvgComponentTransferType.table,
          tableValues: <double>[-0.5, 1.5],
        );

        // Interpolated value may be outside [0,1] but apply() clamps output
        expect(func.apply(0.0), closeTo(0.0, 0.001)); // -0.5 clamped to 0
        expect(func.apply(1.0), closeTo(1.0, 0.001)); // 1.5 clamped to 1
      });
    });

    group('gamma function precision', () {
      test('gamma with c = 0 should return offset', () {
        const func = SvgComponentTransferFunction(
          type: SvgComponentTransferType.gamma,
          amplitude: 1.0,
          exponent: 2.0,
          offset: 0.1,
        );

        expect(func.apply(0.0), closeTo(0.1, 0.001));
      });

      test('gamma with exponent = 1 should be linear', () {
        const func = SvgComponentTransferFunction(
          type: SvgComponentTransferType.gamma,
          amplitude: 1.0,
          exponent: 1.0,
          offset: 0.0,
        );

        expect(func.apply(0.0), closeTo(0.0, 0.001));
        expect(func.apply(0.5), closeTo(0.5, 0.001));
        expect(func.apply(1.0), closeTo(1.0, 0.001));
      });

      test('gamma with very large exponent should not overflow', () {
        const func = SvgComponentTransferFunction(
          type: SvgComponentTransferType.gamma,
          amplitude: 1.0,
          exponent: 1000.0, // Very large
          offset: 0.0,
        );

        // Should not throw or produce NaN/Infinity
        final result = func.apply(0.5);
        expect(result.isFinite, isTrue);
        expect(result, inInclusiveRange(0.0, 1.0));
      });

      test('gamma with very small exponent should not overflow', () {
        const func = SvgComponentTransferFunction(
          type: SvgComponentTransferType.gamma,
          amplitude: 1.0,
          exponent: 0.001, // Very small
          offset: 0.0,
        );

        final result = func.apply(0.5);
        expect(result.isFinite, isTrue);
        expect(result, inInclusiveRange(0.0, 1.0));
      });

      test('gamma with negative exponent should be handled', () {
        const func = SvgComponentTransferFunction(
          type: SvgComponentTransferType.gamma,
          amplitude: 1.0,
          exponent: -2.0,
          offset: 0.0,
        );

        // pow(0.5, -2) = 4, which gets clamped
        final result = func.apply(0.5);
        expect(result.isFinite, isTrue);
        expect(result, inInclusiveRange(0.0, 1.0));
      });

      test('gamma with very large amplitude should be clamped', () {
        const func = SvgComponentTransferFunction(
          type: SvgComponentTransferType.gamma,
          amplitude: 1e10, // Very large
          exponent: 1.0,
          offset: 0.0,
        );

        final result = func.apply(0.5);
        expect(result.isFinite, isTrue);
        expect(result, inInclusiveRange(0.0, 1.0));
      });

      test('gamma with negative amplitude', () {
        const func = SvgComponentTransferFunction(
          type: SvgComponentTransferType.gamma,
          amplitude: -1.0,
          exponent: 1.0,
          offset: 0.5,
        );

        // -1 * 0.5 + 0.5 = 0
        expect(func.apply(0.5), closeTo(0.0, 0.001));
      });

      test('gamma classic sRGB-like curve', () {
        // Approximate gamma 2.2 correction
        const func = SvgComponentTransferFunction(
          type: SvgComponentTransferType.gamma,
          amplitude: 1.0,
          exponent: 2.2,
          offset: 0.0,
        );

        // Mid-gray should be darker than linear
        final result = func.apply(0.5);
        expect(result, lessThan(0.5));
        expect(result, greaterThan(0.0));
      });
    });

    group('linear function', () {
      test('identity linear (slope=1, intercept=0)', () {
        const func = SvgComponentTransferFunction(
          type: SvgComponentTransferType.linear,
          slope: 1.0,
          intercept: 0.0,
        );

        expect(func.apply(0.0), closeTo(0.0, 0.001));
        expect(func.apply(0.5), closeTo(0.5, 0.001));
        expect(func.apply(1.0), closeTo(1.0, 0.001));
        expect(func.isIdentity, isTrue);
      });

      test('contrast increase (slope > 1)', () {
        const func = SvgComponentTransferFunction(
          type: SvgComponentTransferType.linear,
          slope: 2.0,
          intercept: -0.5,
        );

        expect(func.apply(0.25), closeTo(0.0, 0.001)); // 2*0.25 - 0.5 = 0
        expect(func.apply(0.5), closeTo(0.5, 0.001)); // 2*0.5 - 0.5 = 0.5
        expect(func.apply(0.75), closeTo(1.0, 0.001)); // 2*0.75 - 0.5 = 1
      });

      test('brightness increase (positive intercept)', () {
        const func = SvgComponentTransferFunction(
          type: SvgComponentTransferType.linear,
          slope: 1.0,
          intercept: 0.2,
        );

        expect(func.apply(0.0), closeTo(0.2, 0.001));
        expect(func.apply(0.5), closeTo(0.7, 0.001));
        expect(func.apply(1.0), closeTo(1.0, 0.001)); // Clamped
      });

      test('inversion (negative slope)', () {
        const func = SvgComponentTransferFunction(
          type: SvgComponentTransferType.linear,
          slope: -1.0,
          intercept: 1.0,
        );

        expect(func.apply(0.0), closeTo(1.0, 0.001));
        expect(func.apply(0.5), closeTo(0.5, 0.001));
        expect(func.apply(1.0), closeTo(0.0, 0.001));
      });
    });

    group('output clamping', () {
      test('values above 1 should be clamped', () {
        const func = SvgComponentTransferFunction(
          type: SvgComponentTransferType.linear,
          slope: 2.0,
          intercept: 0.5,
        );

        // 2 * 1.0 + 0.5 = 2.5, should clamp to 1.0
        expect(func.apply(1.0), equals(1.0));
      });

      test('values below 0 should be clamped', () {
        const func = SvgComponentTransferFunction(
          type: SvgComponentTransferType.linear,
          slope: 2.0,
          intercept: -1.0,
        );

        // 2 * 0 - 1 = -1, should clamp to 0
        expect(func.apply(0.0), equals(0.0));
      });

      test(
        'input values outside [0,1] should be clamped before processing',
        () {
          const func = SvgComponentTransferFunction(
            type: SvgComponentTransferType.identity,
          );

          expect(func.apply(-0.5), equals(0.0));
          expect(func.apply(1.5), equals(1.0));
        },
      );
    });

    group('lookup table generation', () {
      test('identity function should produce identity table', () {
        const func = SvgComponentTransferFunction(
          type: SvgComponentTransferType.identity,
        );

        final table = func.buildLookupTable();

        expect(table.length, equals(256));
        for (var i = 0; i < 256; i++) {
          expect(table[i], equals(i));
        }
      });

      test('linear inversion should produce reversed table', () {
        const func = SvgComponentTransferFunction(
          type: SvgComponentTransferType.linear,
          slope: -1.0,
          intercept: 1.0,
        );

        final table = func.buildLookupTable();

        expect(table.length, equals(256));
        expect(table[0], equals(255));
        expect(table[255], equals(0));
        expect(table[127], closeTo(128, 1));
      });

      test('discrete function lookup table should have steps', () {
        const func = SvgComponentTransferFunction(
          type: SvgComponentTransferType.discrete,
          tableValues: <double>[0.0, 0.5, 1.0],
        );

        final table = func.buildLookupTable();

        // First third should be 0
        expect(table[0], equals(0));
        expect(table[84], equals(0));
        // Second third should be ~128
        expect(table[85], closeTo(128, 2));
        expect(table[169], closeTo(128, 2));
        // Last third should be 255
        expect(table[170], equals(255));
        expect(table[255], equals(255));
      });

      test('table lookup should be consistent with apply', () {
        const func = SvgComponentTransferFunction(
          type: SvgComponentTransferType.gamma,
          amplitude: 1.2,
          exponent: 0.8,
          offset: -0.1,
        );

        final table = func.buildLookupTable();

        // Verify several values match
        for (var i = 0; i < 256; i += 17) {
          final input = i / 255.0;
          final fromApply = (func.apply(input) * 255.0).round().clamp(0, 255);
          expect(
            table[i],
            equals(fromApply),
            reason: 'Lookup table should match apply() for index $i',
          );
        }
      });
    });

    group('isIdentity detection', () {
      test('identity type should be detected', () {
        const func = SvgComponentTransferFunction(
          type: SvgComponentTransferType.identity,
        );
        expect(func.isIdentity, isTrue);
      });

      test('linear with slope=1 intercept=0 should be identity', () {
        const func = SvgComponentTransferFunction(
          type: SvgComponentTransferType.linear,
          slope: 1.0,
          intercept: 0.0,
        );
        expect(func.isIdentity, isTrue);
      });

      test('linear with different slope should not be identity', () {
        const func = SvgComponentTransferFunction(
          type: SvgComponentTransferType.linear,
          slope: 1.5,
          intercept: 0.0,
        );
        expect(func.isIdentity, isFalse);
      });

      test('gamma with amp=1 exp=1 offset=0 should be identity', () {
        const func = SvgComponentTransferFunction(
          type: SvgComponentTransferType.gamma,
          amplitude: 1.0,
          exponent: 1.0,
          offset: 0.0,
        );
        expect(func.isIdentity, isTrue);
      });
    });
  });

  group('SvgComponentTransferFilter edge cases', () {
    test('null functions should default to identity', () {
      final filter = SvgComponentTransferFilter(id: 'test');

      expect(filter.effectiveFuncR.isIdentity, isTrue);
      expect(filter.effectiveFuncG.isIdentity, isTrue);
      expect(filter.effectiveFuncB.isIdentity, isTrue);
      expect(filter.effectiveFuncA.isIdentity, isTrue);
      expect(filter.isIdentity, isTrue);
    });

    test('transformPixel should apply all channel functions', () {
      final filter = SvgComponentTransferFilter(
        id: 'test',
        funcR: const SvgComponentTransferFunction(
          type: SvgComponentTransferType.linear,
          slope: 0.0,
          intercept: 0.5, // All red becomes 0.5
        ),
        funcG: const SvgComponentTransferFunction(
          type: SvgComponentTransferType.linear,
          slope: 2.0,
          intercept: 0.0, // Double green
        ),
      );

      final result = filter.transformPixel(
        ui.Color.from(alpha: 1.0, red: 0.8, green: 0.3, blue: 0.6),
      );

      expect(result.r, closeTo(0.5, 0.01));
      expect(result.g, closeTo(0.6, 0.01)); // 0.3 * 2 = 0.6
      expect(result.b, closeTo(0.6, 0.01)); // Unchanged (identity)
      expect(result.a, closeTo(1.0, 0.01)); // Unchanged (identity)
    });

    test('transformPixelFast should use lookup tables', () {
      final filter = SvgComponentTransferFilter(
        id: 'test',
        funcR: const SvgComponentTransferFunction(
          type: SvgComponentTransferType.discrete,
          tableValues: <double>[0.0, 1.0],
        ),
      );

      // Access lookup tables to trigger lazy initialization
      final tableR = filter.lookupTableR;
      expect(tableR.length, equals(256));

      // Fast transform
      final result = filter.transformPixelFast(64, 128, 192, 255);

      expect(result.length, equals(4));
      // R: 64/255 < 0.5, so discrete gives 0
      expect(result[0], equals(0));
      // G, B, A should be identity
      expect(result[1], equals(128));
      expect(result[2], equals(192));
      expect(result[3], equals(255));
    });

    test('linearColorFilter should return null for non-linear functions', () {
      final filter = SvgComponentTransferFilter(
        id: 'test',
        funcR: const SvgComponentTransferFunction(
          type: SvgComponentTransferType.gamma,
          amplitude: 1.0,
          exponent: 2.2,
          offset: 0.0,
        ),
      );

      expect(filter.linearColorFilter(), isNull);
    });

    test('linearColorFilter should work for linear functions', () {
      final filter = SvgComponentTransferFilter(
        id: 'test',
        funcR: const SvgComponentTransferFunction(
          type: SvgComponentTransferType.linear,
          slope: 1.2,
          intercept: 0.1,
        ),
      );

      final colorFilter = filter.linearColorFilter();
      expect(colorFilter, isNotNull);
    });

    test('lookup tables should be lazily cached', () {
      final filter = SvgComponentTransferFilter(
        id: 'test',
        funcR: const SvgComponentTransferFunction(
          type: SvgComponentTransferType.gamma,
          amplitude: 1.0,
          exponent: 2.2,
          offset: 0.0,
        ),
      );

      // First access builds the table
      final table1 = filter.lookupTableR;
      // Second access should return same instance (cached)
      final table2 = filter.lookupTableR;

      expect(identical(table1, table2), isTrue);
    });
  });
}
