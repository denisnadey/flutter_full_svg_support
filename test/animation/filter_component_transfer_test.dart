import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_svg/src/animation/svg_parser.dart';
import 'package:flutter_svg/src/animation/svg_filters.dart';

void main() {
  group('SvgComponentTransferFunction', () {
    group('identity type', () {
      test('returns input unchanged', () {
        const func = SvgComponentTransferFunction(
          type: SvgComponentTransferType.identity,
        );
        expect(func.apply(0.0), 0.0);
        expect(func.apply(0.5), 0.5);
        expect(func.apply(1.0), 1.0);
      });

      test('clamps input to [0,1]', () {
        const func = SvgComponentTransferFunction(
          type: SvgComponentTransferType.identity,
        );
        expect(func.apply(-0.5), 0.0);
        expect(func.apply(1.5), 1.0);
      });

      test('isIdentity returns true', () {
        const func = SvgComponentTransferFunction(
          type: SvgComponentTransferType.identity,
        );
        expect(func.isIdentity, isTrue);
      });
    });

    group('linear type', () {
      test('applies slope and intercept', () {
        const func = SvgComponentTransferFunction(
          type: SvgComponentTransferType.linear,
          slope: 0.5,
          intercept: 0.25,
        );
        // C' = 0.5 * C + 0.25
        expect(func.apply(0.0), closeTo(0.25, 0.0001));
        expect(func.apply(0.5), closeTo(0.5, 0.0001)); // 0.5*0.5 + 0.25 = 0.5
        expect(func.apply(1.0), closeTo(0.75, 0.0001)); // 0.5*1.0 + 0.25 = 0.75
      });

      test('clamps result to [0,1]', () {
        const func = SvgComponentTransferFunction(
          type: SvgComponentTransferType.linear,
          slope: 2.0,
          intercept: 0.5,
        );
        // C' = 2.0 * 1.0 + 0.5 = 2.5 -> clamped to 1.0
        expect(func.apply(1.0), 1.0);
        
        const funcNeg = SvgComponentTransferFunction(
          type: SvgComponentTransferType.linear,
          slope: 1.0,
          intercept: -0.5,
        );
        // C' = 1.0 * 0.0 - 0.5 = -0.5 -> clamped to 0.0
        expect(funcNeg.apply(0.0), 0.0);
      });

      test('isIdentity returns true for slope=1 intercept=0', () {
        const func = SvgComponentTransferFunction(
          type: SvgComponentTransferType.linear,
          slope: 1.0,
          intercept: 0.0,
        );
        expect(func.isIdentity, isTrue);
      });

      test('isIdentity returns false for non-identity linear', () {
        const func = SvgComponentTransferFunction(
          type: SvgComponentTransferType.linear,
          slope: 0.5,
          intercept: 0.0,
        );
        expect(func.isIdentity, isFalse);
      });
    });

    group('gamma type', () {
      test('applies amplitude, exponent, and offset', () {
        const func = SvgComponentTransferFunction(
          type: SvgComponentTransferType.gamma,
          amplitude: 1.0,
          exponent: 2.0,
          offset: 0.0,
        );
        // C' = 1.0 * C^2.0 + 0.0
        expect(func.apply(0.0), closeTo(0.0, 0.0001));
        expect(func.apply(0.5), closeTo(0.25, 0.0001)); // 0.5^2 = 0.25
        expect(func.apply(1.0), closeTo(1.0, 0.0001));
      });

      test('handles offset', () {
        const func = SvgComponentTransferFunction(
          type: SvgComponentTransferType.gamma,
          amplitude: 1.0,
          exponent: 1.0,
          offset: 0.1,
        );
        // C' = 1.0 * C^1.0 + 0.1
        expect(func.apply(0.0), closeTo(0.1, 0.0001));
        expect(func.apply(0.5), closeTo(0.6, 0.0001));
      });

      test('handles amplitude', () {
        const func = SvgComponentTransferFunction(
          type: SvgComponentTransferType.gamma,
          amplitude: 0.5,
          exponent: 1.0,
          offset: 0.0,
        );
        // C' = 0.5 * C^1.0 + 0.0
        expect(func.apply(1.0), closeTo(0.5, 0.0001));
      });

      test('clamps result to [0,1]', () {
        const func = SvgComponentTransferFunction(
          type: SvgComponentTransferType.gamma,
          amplitude: 2.0,
          exponent: 1.0,
          offset: 0.5,
        );
        // C' = 2.0 * 1.0^1.0 + 0.5 = 2.5 -> clamped to 1.0
        expect(func.apply(1.0), 1.0);
      });

      test('isIdentity returns true for amplitude=1 exponent=1 offset=0', () {
        const func = SvgComponentTransferFunction(
          type: SvgComponentTransferType.gamma,
          amplitude: 1.0,
          exponent: 1.0,
          offset: 0.0,
        );
        expect(func.isIdentity, isTrue);
      });
    });

    group('table type', () {
      test('interpolates between table values', () {
        const func = SvgComponentTransferFunction(
          type: SvgComponentTransferType.table,
          tableValues: [0.0, 1.0],
        );
        // For 2 values, 1 interval: maps [0,1] to [0.0, 1.0]
        expect(func.apply(0.0), closeTo(0.0, 0.0001));
        expect(func.apply(0.5), closeTo(0.5, 0.0001));
        expect(func.apply(1.0), closeTo(1.0, 0.0001));
      });

      test('interpolates with 3 values', () {
        const func = SvgComponentTransferFunction(
          type: SvgComponentTransferType.table,
          tableValues: [0.0, 1.0, 0.0],
        );
        // 3 values = 2 intervals
        // [0, 0.5] maps to [0.0, 1.0]
        // [0.5, 1.0] maps to [1.0, 0.0]
        expect(func.apply(0.0), closeTo(0.0, 0.0001));
        expect(func.apply(0.25), closeTo(0.5, 0.0001));
        expect(func.apply(0.5), closeTo(1.0, 0.0001));
        expect(func.apply(0.75), closeTo(0.5, 0.0001));
        expect(func.apply(1.0), closeTo(0.0, 0.0001));
      });

      test('handles inverted table', () {
        const func = SvgComponentTransferFunction(
          type: SvgComponentTransferType.table,
          tableValues: [1.0, 0.0],
        );
        // Inverts the input
        expect(func.apply(0.0), closeTo(1.0, 0.0001));
        expect(func.apply(0.5), closeTo(0.5, 0.0001));
        expect(func.apply(1.0), closeTo(0.0, 0.0001));
      });

      test('returns input for empty tableValues', () {
        const func = SvgComponentTransferFunction(
          type: SvgComponentTransferType.table,
          tableValues: [],
        );
        expect(func.apply(0.5), 0.5);
      });

      test('returns constant for single tableValue', () {
        const func = SvgComponentTransferFunction(
          type: SvgComponentTransferType.table,
          tableValues: [0.7],
        );
        expect(func.apply(0.0), 0.7);
        expect(func.apply(0.5), 0.7);
        expect(func.apply(1.0), 0.7);
      });
    });

    group('discrete type', () {
      test('returns discrete values', () {
        const func = SvgComponentTransferFunction(
          type: SvgComponentTransferType.discrete,
          tableValues: [0.0, 0.5, 1.0],
        );
        // 3 values = 3 intervals: [0, 1/3), [1/3, 2/3), [2/3, 1]
        expect(func.apply(0.0), 0.0);
        expect(func.apply(0.2), 0.0); // < 1/3
        expect(func.apply(0.4), 0.5); // >= 1/3, < 2/3
        expect(func.apply(0.7), 1.0); // >= 2/3
        expect(func.apply(1.0), 1.0); // edge case - clamped to last value
      });

      test('handles 2 discrete values', () {
        const func = SvgComponentTransferFunction(
          type: SvgComponentTransferType.discrete,
          tableValues: [0.0, 1.0],
        );
        // 2 values = 2 intervals: [0, 0.5), [0.5, 1]
        expect(func.apply(0.0), 0.0);
        expect(func.apply(0.4), 0.0);
        expect(func.apply(0.5), 1.0);
        expect(func.apply(1.0), 1.0);
      });

      test('returns input for empty tableValues', () {
        const func = SvgComponentTransferFunction(
          type: SvgComponentTransferType.discrete,
          tableValues: [],
        );
        expect(func.apply(0.5), 0.5);
      });
    });
  });

  group('SvgComponentTransferFilter', () {
    test('defaults to identity for missing functions', () {
      final filter = SvgComponentTransferFilter(id: 'test');
      expect(filter.effectiveFuncR.type, SvgComponentTransferType.identity);
      expect(filter.effectiveFuncG.type, SvgComponentTransferType.identity);
      expect(filter.effectiveFuncB.type, SvgComponentTransferType.identity);
      expect(filter.effectiveFuncA.type, SvgComponentTransferType.identity);
      expect(filter.isIdentity, isTrue);
    });

    test('isIdentity is false when any channel has non-identity function', () {
      final filter = SvgComponentTransferFilter(
        id: 'test',
        funcR: const SvgComponentTransferFunction(
          type: SvgComponentTransferType.linear,
          slope: 0.5,
        ),
      );
      expect(filter.isIdentity, isFalse);
    });

    test('transformPixel applies functions to each channel', () {
      final filter = SvgComponentTransferFilter(
        id: 'test',
        funcR: const SvgComponentTransferFunction(
          type: SvgComponentTransferType.linear,
          slope: 0.5,
          intercept: 0.0,
        ),
        funcG: const SvgComponentTransferFunction(
          type: SvgComponentTransferType.linear,
          slope: 2.0,
          intercept: 0.0,
        ),
        funcB: const SvgComponentTransferFunction(
          type: SvgComponentTransferType.identity,
        ),
        funcA: const SvgComponentTransferFunction(
          type: SvgComponentTransferType.identity,
        ),
      );
      
      final input = ui.Color.from(alpha: 1.0, red: 0.8, green: 0.4, blue: 0.5);
      final output = filter.transformPixel(input);
      
      expect(output.r, closeTo(0.4, 0.001)); // 0.8 * 0.5 = 0.4
      expect(output.g, closeTo(0.8, 0.001)); // 0.4 * 2.0 = 0.8
      expect(output.b, closeTo(0.5, 0.001)); // unchanged
      expect(output.a, closeTo(1.0, 0.001)); // unchanged
    });

    test('linearColorFilter returns ColorFilter for linear-only transforms', () {
      final filter = SvgComponentTransferFilter(
        id: 'test',
        funcR: const SvgComponentTransferFunction(
          type: SvgComponentTransferType.linear,
          slope: 0.5,
          intercept: 0.1,
        ),
      );
      final colorFilter = filter.linearColorFilter();
      expect(colorFilter, isNotNull);
    });

    test('linearColorFilter returns null for non-linear transforms', () {
      final filter = SvgComponentTransferFilter(
        id: 'test',
        funcR: const SvgComponentTransferFunction(
          type: SvgComponentTransferType.gamma,
          amplitude: 1.0,
          exponent: 2.0,
          offset: 0.0,
        ),
      );
      final colorFilter = filter.linearColorFilter();
      expect(colorFilter, isNull);
    });
  });

  group('feComponentTransfer parsing', () {
    test('parses feComponentTransfer with feFuncR linear', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="transfer">
      <feComponentTransfer in="SourceGraphic" result="out">
        <feFuncR type="linear" slope="0.5" intercept="0.25"/>
      </feComponentTransfer>
    </filter>
  </defs>
</svg>
''';
      final document = SvgParser.parse(svgString);
      expect(document.filters, isNotNull);
      expect(document.filters!.hasFilter('transfer'), isTrue);

      final filter = document.filters!.getById('transfer');
      expect(filter, isA<SvgComponentTransferFilter>());
      final transfer = filter as SvgComponentTransferFilter;
      
      expect(transfer.funcR, isNotNull);
      expect(transfer.funcR!.type, SvgComponentTransferType.linear);
      expect(transfer.funcR!.slope, 0.5);
      expect(transfer.funcR!.intercept, 0.25);
      expect(transfer.input, 'SourceGraphic');
      expect(transfer.resultName, 'out');
    });

    test('parses feFuncG with gamma', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="gammaFx">
      <feComponentTransfer>
        <feFuncG type="gamma" amplitude="1.5" exponent="0.5" offset="0.1"/>
      </feComponentTransfer>
    </filter>
  </defs>
</svg>
''';
      final document = SvgParser.parse(svgString);
      final filter = document.filters!.getById('gammaFx') as SvgComponentTransferFilter;
      
      expect(filter.funcG, isNotNull);
      expect(filter.funcG!.type, SvgComponentTransferType.gamma);
      expect(filter.funcG!.amplitude, 1.5);
      expect(filter.funcG!.exponent, 0.5);
      expect(filter.funcG!.offset, 0.1);
    });

    test('parses feFuncB with table', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="tableFx">
      <feComponentTransfer>
        <feFuncB type="table" tableValues="0 0.5 1"/>
      </feComponentTransfer>
    </filter>
  </defs>
</svg>
''';
      final document = SvgParser.parse(svgString);
      final filter = document.filters!.getById('tableFx') as SvgComponentTransferFilter;
      
      expect(filter.funcB, isNotNull);
      expect(filter.funcB!.type, SvgComponentTransferType.table);
      expect(filter.funcB!.tableValues, [0.0, 0.5, 1.0]);
    });

    test('parses feFuncA with discrete', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="discreteFx">
      <feComponentTransfer>
        <feFuncA type="discrete" tableValues="0,0.3,0.6,1"/>
      </feComponentTransfer>
    </filter>
  </defs>
</svg>
''';
      final document = SvgParser.parse(svgString);
      final filter = document.filters!.getById('discreteFx') as SvgComponentTransferFilter;
      
      expect(filter.funcA, isNotNull);
      expect(filter.funcA!.type, SvgComponentTransferType.discrete);
      expect(filter.funcA!.tableValues, [0.0, 0.3, 0.6, 1.0]);
    });

    test('parses feComponentTransfer with identity', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="identityFx">
      <feComponentTransfer>
        <feFuncR type="identity"/>
      </feComponentTransfer>
    </filter>
  </defs>
</svg>
''';
      final document = SvgParser.parse(svgString);
      final filter = document.filters!.getById('identityFx') as SvgComponentTransferFilter;
      
      expect(filter.funcR, isNotNull);
      expect(filter.funcR!.type, SvgComponentTransferType.identity);
    });

    test('parses mixed transfer functions', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="mixedFx">
      <feComponentTransfer>
        <feFuncR type="linear" slope="1.2"/>
        <feFuncG type="table" tableValues="0 1"/>
        <feFuncB type="gamma" exponent="2.0"/>
        <feFuncA type="identity"/>
      </feComponentTransfer>
    </filter>
  </defs>
</svg>
''';
      final document = SvgParser.parse(svgString);
      final filter = document.filters!.getById('mixedFx') as SvgComponentTransferFilter;
      
      expect(filter.funcR!.type, SvgComponentTransferType.linear);
      expect(filter.funcG!.type, SvgComponentTransferType.table);
      expect(filter.funcB!.type, SvgComponentTransferType.gamma);
      expect(filter.funcA!.type, SvgComponentTransferType.identity);
    });

    test('uses default values when attributes are omitted', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="defaultsFx">
      <feComponentTransfer>
        <feFuncR type="linear"/>
        <feFuncG type="gamma"/>
      </feComponentTransfer>
    </filter>
  </defs>
</svg>
''';
      final document = SvgParser.parse(svgString);
      final filter = document.filters!.getById('defaultsFx') as SvgComponentTransferFilter;
      
      // Linear defaults: slope=1, intercept=0
      expect(filter.funcR!.slope, 1.0);
      expect(filter.funcR!.intercept, 0.0);
      
      // Gamma defaults: amplitude=1, exponent=1, offset=0
      expect(filter.funcG!.amplitude, 1.0);
      expect(filter.funcG!.exponent, 1.0);
      expect(filter.funcG!.offset, 0.0);
    });
  });

  group('feComponentTransfer pipeline', () {
    test('identity filter produces identity pass', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="idFx">
      <feComponentTransfer>
        <feFuncR type="identity"/>
        <feFuncG type="identity"/>
        <feFuncB type="identity"/>
        <feFuncA type="identity"/>
      </feComponentTransfer>
    </filter>
  </defs>
</svg>
''';
      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('idFx');
      
      // Identity filter should pass through without modification
      expect(passes, isNotEmpty);
      // Should not create SvgComponentTransferPaintPass for identity
      expect(passes.first, isNot(isA<SvgComponentTransferPaintPass>()));
    });

    test('linear-only filter produces ColorFilter', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="linearFx">
      <feComponentTransfer>
        <feFuncR type="linear" slope="0.5"/>
        <feFuncG type="linear" slope="0.8"/>
      </feComponentTransfer>
    </filter>
  </defs>
</svg>
''';
      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('linearFx');
      
      expect(passes, isNotEmpty);
      // Linear transforms use ColorFilter, not SvgComponentTransferPaintPass
      expect(passes.first.colorFilter, isNotNull);
      expect(passes.first, isNot(isA<SvgComponentTransferPaintPass>()));
    });

    test('gamma filter produces SvgComponentTransferPaintPass', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="gammaFx">
      <feComponentTransfer>
        <feFuncR type="gamma" exponent="2.2"/>
      </feComponentTransfer>
    </filter>
  </defs>
</svg>
''';
      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('gammaFx');
      
      expect(passes, isNotEmpty);
      expect(passes.first, isA<SvgComponentTransferPaintPass>());
    });

    test('table filter produces SvgComponentTransferPaintPass', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="tableFx">
      <feComponentTransfer>
        <feFuncR type="table" tableValues="0 1 0"/>
      </feComponentTransfer>
    </filter>
  </defs>
</svg>
''';
      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('tableFx');
      
      expect(passes, isNotEmpty);
      expect(passes.first, isA<SvgComponentTransferPaintPass>());
    });

    test('discrete filter produces SvgComponentTransferPaintPass', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="discreteFx">
      <feComponentTransfer>
        <feFuncR type="discrete" tableValues="0 0.5 1"/>
      </feComponentTransfer>
    </filter>
  </defs>
</svg>
''';
      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('discreteFx');
      
      expect(passes, isNotEmpty);
      expect(passes.first, isA<SvgComponentTransferPaintPass>());
    });
  });

  group('edge cases', () {
    test('table with values > 1 clamps output', () {
      const func = SvgComponentTransferFunction(
        type: SvgComponentTransferType.table,
        tableValues: [0.0, 2.0],
      );
      expect(func.apply(1.0), 1.0); // 2.0 clamped to 1.0
    });

    test('table with negative values clamps output', () {
      const func = SvgComponentTransferFunction(
        type: SvgComponentTransferType.table,
        tableValues: [-0.5, 0.5],
      );
      expect(func.apply(0.0), 0.0); // -0.5 clamped to 0.0
    });

    test('linear with negative result clamps to 0', () {
      const func = SvgComponentTransferFunction(
        type: SvgComponentTransferType.linear,
        slope: 1.0,
        intercept: -0.5,
      );
      expect(func.apply(0.0), 0.0);
    });

    test('gamma with zero input returns offset', () {
      const func = SvgComponentTransferFunction(
        type: SvgComponentTransferType.gamma,
        amplitude: 1.0,
        exponent: 0.5,
        offset: 0.1,
      );
      expect(func.apply(0.0), closeTo(0.1, 0.0001));
    });

    test('discrete with single value returns that value', () {
      const func = SvgComponentTransferFunction(
        type: SvgComponentTransferType.discrete,
        tableValues: [0.7],
      );
      expect(func.apply(0.0), 0.7);
      expect(func.apply(0.5), 0.7);
      expect(func.apply(0.99), 0.7);
    });
  });
}
