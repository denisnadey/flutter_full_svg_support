import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_svg/src/animation/svg_parser.dart';
import 'package:flutter_svg/src/animation/svg_filters.dart';
import 'package:flutter_svg/src/animation/smil/smil_parser.dart';

/// Comprehensive tests for feComponentTransfer with feFuncR/G/B/A elements.
/// Tests all 5 transfer function types (identity, table, discrete, linear, gamma)
/// plus animation support and edge cases.
void main() {
  group('Component transfer function types', () {
    group('identity', () {
      test('no-op passes through all values unchanged', () {
        const func = SvgComponentTransferFunction(
          type: SvgComponentTransferType.identity,
        );

        // Test full range
        for (var i = 0; i <= 10; i++) {
          final v = i / 10.0;
          expect(func.apply(v), closeTo(v, 0.0001));
        }
      });

      test('identity function handles boundary values', () {
        const func = SvgComponentTransferFunction(
          type: SvgComponentTransferType.identity,
        );
        expect(func.apply(0.0), 0.0);
        expect(func.apply(1.0), 1.0);
        expect(func.apply(0.001), closeTo(0.001, 0.0001));
        expect(func.apply(0.999), closeTo(0.999, 0.0001));
      });
    });

    group('table', () {
      test('table with 4 values creates 3 intervals', () {
        const func = SvgComponentTransferFunction(
          type: SvgComponentTransferType.table,
          tableValues: [0.0, 0.25, 0.75, 1.0],
        );
        // 4 values = 3 intervals: [0, 1/3], [1/3, 2/3], [2/3, 1]
        expect(func.apply(0.0), closeTo(0.0, 0.0001));
        expect(func.apply(1.0 / 3.0), closeTo(0.25, 0.0001));
        expect(func.apply(2.0 / 3.0), closeTo(0.75, 0.0001));
        expect(func.apply(1.0), closeTo(1.0, 0.0001));
      });

      test('table with posterization effect (staircase)', () {
        // Creates a posterization effect with distinct levels
        const func = SvgComponentTransferFunction(
          type: SvgComponentTransferType.table,
          tableValues: [0.0, 0.0, 0.5, 0.5, 1.0, 1.0],
        );
        // Input < 0.2 maps to 0
        expect(func.apply(0.1), closeTo(0.0, 0.01));
        // Input around 0.4 maps to ~0.5
        expect(func.apply(0.5), closeTo(0.5, 0.01));
        // Input > 0.8 maps to 1.0
        expect(func.apply(0.9), closeTo(1.0, 0.01));
      });

      test('table inverts with [1, 0]', () {
        const func = SvgComponentTransferFunction(
          type: SvgComponentTransferType.table,
          tableValues: [1.0, 0.0],
        );
        expect(func.apply(0.0), closeTo(1.0, 0.0001));
        expect(func.apply(0.5), closeTo(0.5, 0.0001));
        expect(func.apply(1.0), closeTo(0.0, 0.0001));
        expect(func.apply(0.25), closeTo(0.75, 0.0001));
      });

      test('table with large number of values interpolates correctly', () {
        // 11 values: 0.0, 0.1, 0.2, ..., 1.0 (identity-like)
        const func = SvgComponentTransferFunction(
          type: SvgComponentTransferType.table,
          tableValues: [0.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0],
        );
        expect(func.apply(0.0), closeTo(0.0, 0.0001));
        expect(func.apply(0.5), closeTo(0.5, 0.0001));
        expect(func.apply(1.0), closeTo(1.0, 0.0001));
      });
    });

    group('discrete', () {
      test('discrete with 4 values creates 4 step levels', () {
        const func = SvgComponentTransferFunction(
          type: SvgComponentTransferType.discrete,
          tableValues: [0.0, 0.33, 0.66, 1.0],
        );
        // 4 values = 4 intervals: [0, 0.25), [0.25, 0.5), [0.5, 0.75), [0.75, 1]
        expect(func.apply(0.1), 0.0);
        expect(func.apply(0.3), 0.33);
        expect(func.apply(0.6), 0.66);
        expect(func.apply(0.8), 1.0);
      });

      test('discrete with 5 values for quantization', () {
        const func = SvgComponentTransferFunction(
          type: SvgComponentTransferType.discrete,
          tableValues: [0.0, 0.25, 0.5, 0.75, 1.0],
        );
        // 5 values = 5 intervals at 0.2 each
        expect(func.apply(0.0), 0.0);
        expect(func.apply(0.15), 0.0); // < 0.2
        expect(func.apply(0.25), 0.25); // >= 0.2, < 0.4
        expect(func.apply(0.45), 0.5); // >= 0.4, < 0.6
        expect(func.apply(0.65), 0.75); // >= 0.6, < 0.8
        expect(func.apply(0.85), 1.0); // >= 0.8
      });

      test('discrete thresholding with 2 values (binary)', () {
        const func = SvgComponentTransferFunction(
          type: SvgComponentTransferType.discrete,
          tableValues: [0.0, 1.0],
        );
        // Binary threshold at 0.5
        expect(func.apply(0.0), 0.0);
        expect(func.apply(0.49), 0.0);
        expect(func.apply(0.5), 1.0);
        expect(func.apply(1.0), 1.0);
      });
    });

    group('linear', () {
      test('linear contrast increase (slope > 1)', () {
        const func = SvgComponentTransferFunction(
          type: SvgComponentTransferType.linear,
          slope: 2.0,
          intercept: -0.5,
        );
        // C' = 2.0 * C - 0.5
        expect(func.apply(0.25), closeTo(0.0, 0.0001)); // 2*0.25 - 0.5 = 0
        expect(func.apply(0.5), closeTo(0.5, 0.0001)); // 2*0.5 - 0.5 = 0.5
        expect(func.apply(0.75), closeTo(1.0, 0.0001)); // 2*0.75 - 0.5 = 1.0
      });

      test('linear contrast decrease (slope < 1)', () {
        const func = SvgComponentTransferFunction(
          type: SvgComponentTransferType.linear,
          slope: 0.5,
          intercept: 0.25,
        );
        // C' = 0.5 * C + 0.25
        expect(func.apply(0.0), closeTo(0.25, 0.0001));
        expect(func.apply(0.5), closeTo(0.5, 0.0001));
        expect(func.apply(1.0), closeTo(0.75, 0.0001));
      });

      test('linear with negative slope inverts', () {
        const func = SvgComponentTransferFunction(
          type: SvgComponentTransferType.linear,
          slope: -1.0,
          intercept: 1.0,
        );
        // C' = -1 * C + 1 = 1 - C (inversion)
        expect(func.apply(0.0), closeTo(1.0, 0.0001));
        expect(func.apply(0.5), closeTo(0.5, 0.0001));
        expect(func.apply(1.0), closeTo(0.0, 0.0001));
      });

      test('linear brightness adjustment (intercept only)', () {
        const func = SvgComponentTransferFunction(
          type: SvgComponentTransferType.linear,
          slope: 1.0,
          intercept: 0.2,
        );
        // C' = C + 0.2 (brightness boost)
        expect(func.apply(0.0), closeTo(0.2, 0.0001));
        expect(func.apply(0.5), closeTo(0.7, 0.0001));
        expect(func.apply(0.8), closeTo(1.0, 0.0001)); // clamped
      });
    });

    group('gamma', () {
      test('gamma correction for sRGB (exponent 2.2)', () {
        const func = SvgComponentTransferFunction(
          type: SvgComponentTransferType.gamma,
          amplitude: 1.0,
          exponent: 2.2,
          offset: 0.0,
        );
        // Gamma 2.2 darkens mid-tones
        expect(func.apply(0.0), closeTo(0.0, 0.0001));
        expect(func.apply(0.5), closeTo(0.2176, 0.01)); // 0.5^2.2
        expect(func.apply(1.0), closeTo(1.0, 0.0001));
      });

      test('inverse gamma (exponent < 1) brightens mid-tones', () {
        const func = SvgComponentTransferFunction(
          type: SvgComponentTransferType.gamma,
          amplitude: 1.0,
          exponent: 0.45, // ~ 1/2.2
          offset: 0.0,
        );
        expect(func.apply(0.0), closeTo(0.0, 0.0001));
        expect(func.apply(0.5), closeTo(0.7297, 0.01)); // 0.5^0.45
        expect(func.apply(1.0), closeTo(1.0, 0.0001));
      });

      test('gamma with amplitude adjustment', () {
        const func = SvgComponentTransferFunction(
          type: SvgComponentTransferType.gamma,
          amplitude: 0.8,
          exponent: 1.0,
          offset: 0.1,
        );
        // C' = 0.8 * C^1 + 0.1
        expect(func.apply(0.0), closeTo(0.1, 0.0001));
        expect(func.apply(0.5), closeTo(0.5, 0.0001)); // 0.8*0.5 + 0.1
        expect(func.apply(1.0), closeTo(0.9, 0.0001)); // 0.8*1 + 0.1
      });

      test('gamma with offset shifts entire range', () {
        const func = SvgComponentTransferFunction(
          type: SvgComponentTransferType.gamma,
          amplitude: 1.0,
          exponent: 1.0,
          offset: 0.25,
        );
        // C' = C + 0.25
        expect(func.apply(0.0), closeTo(0.25, 0.0001));
        expect(func.apply(0.5), closeTo(0.75, 0.0001));
        expect(func.apply(0.75), closeTo(1.0, 0.0001)); // clamped
      });

      test('gamma square function (exponent = 2)', () {
        const func = SvgComponentTransferFunction(
          type: SvgComponentTransferType.gamma,
          amplitude: 1.0,
          exponent: 2.0,
          offset: 0.0,
        );
        expect(func.apply(0.0), closeTo(0.0, 0.0001));
        expect(func.apply(0.5), closeTo(0.25, 0.0001)); // 0.5^2
        expect(func.apply(0.7071), closeTo(0.5, 0.01)); // sqrt(0.5)^2 ≈ 0.5
        expect(func.apply(1.0), closeTo(1.0, 0.0001));
      });
    });
  });

  group('Mixed channel types', () {
    test('R=linear, G=gamma, B=table, A=identity', () {
      final filter = SvgComponentTransferFilter(
        id: 'mixed',
        funcR: const SvgComponentTransferFunction(
          type: SvgComponentTransferType.linear,
          slope: 0.5,
          intercept: 0.25,
        ),
        funcG: const SvgComponentTransferFunction(
          type: SvgComponentTransferType.gamma,
          amplitude: 1.0,
          exponent: 2.0,
          offset: 0.0,
        ),
        funcB: const SvgComponentTransferFunction(
          type: SvgComponentTransferType.table,
          tableValues: [0.0, 1.0, 0.0],
        ),
        funcA: const SvgComponentTransferFunction(
          type: SvgComponentTransferType.identity,
        ),
      );

      final input = ui.Color.from(alpha: 0.8, red: 0.6, green: 0.5, blue: 0.5);
      final output = filter.transformPixel(input);

      // R: 0.5 * 0.6 + 0.25 = 0.55
      expect(output.r, closeTo(0.55, 0.01));
      // G: 0.5^2 = 0.25
      expect(output.g, closeTo(0.25, 0.01));
      // B: table interpolation at 0.5 (peak of triangle)
      expect(output.b, closeTo(1.0, 0.01));
      // A: unchanged
      expect(output.a, closeTo(0.8, 0.01));
    });

    test('R=discrete, G=discrete, B=discrete, A=linear', () {
      final filter = SvgComponentTransferFilter(
        id: 'posterize',
        funcR: const SvgComponentTransferFunction(
          type: SvgComponentTransferType.discrete,
          tableValues: [0.0, 0.5, 1.0],
        ),
        funcG: const SvgComponentTransferFunction(
          type: SvgComponentTransferType.discrete,
          tableValues: [0.0, 0.5, 1.0],
        ),
        funcB: const SvgComponentTransferFunction(
          type: SvgComponentTransferType.discrete,
          tableValues: [0.0, 0.5, 1.0],
        ),
        funcA: const SvgComponentTransferFunction(
          type: SvgComponentTransferType.linear,
          slope: 1.0,
          intercept: 0.0,
        ),
      );

      final input = ui.Color.from(alpha: 0.9, red: 0.3, green: 0.6, blue: 0.8);
      final output = filter.transformPixel(input);

      // RGB posterized to 3 levels
      expect(output.r, 0.0); // 0.3 < 0.33
      expect(output.g, 0.5); // 0.6 >= 0.33 && < 0.66
      expect(output.b, 1.0); // 0.8 >= 0.66
      expect(output.a, closeTo(0.9, 0.01));
    });
  });

  group('Missing func elements', () {
    test('all channels default to identity when no func elements', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="emptyTransfer">
      <feComponentTransfer in="SourceGraphic"/>
    </filter>
  </defs>
</svg>
''';
      final document = SvgParser.parse(svgString);
      final filter = document.filters!.getById('emptyTransfer')
          as SvgComponentTransferFilter;

      expect(filter.funcR, isNull);
      expect(filter.funcG, isNull);
      expect(filter.funcB, isNull);
      expect(filter.funcA, isNull);
      expect(filter.isIdentity, isTrue);

      // Transform should pass through unchanged
      final input = ui.Color.from(alpha: 0.7, red: 0.3, green: 0.5, blue: 0.9);
      final output = filter.transformPixel(input);
      expect(output.r, closeTo(0.3, 0.01));
      expect(output.g, closeTo(0.5, 0.01));
      expect(output.b, closeTo(0.9, 0.01));
      expect(output.a, closeTo(0.7, 0.01));
    });

    test('partial func elements - others default to identity', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="partialTransfer">
      <feComponentTransfer>
        <feFuncR type="linear" slope="2"/>
      </feComponentTransfer>
    </filter>
  </defs>
</svg>
''';
      final document = SvgParser.parse(svgString);
      final filter = document.filters!.getById('partialTransfer')
          as SvgComponentTransferFilter;

      expect(filter.funcR, isNotNull);
      expect(filter.funcG, isNull);
      expect(filter.funcB, isNull);
      expect(filter.funcA, isNull);

      expect(filter.effectiveFuncR.type, SvgComponentTransferType.linear);
      expect(filter.effectiveFuncG.type, SvgComponentTransferType.identity);
      expect(filter.effectiveFuncB.type, SvgComponentTransferType.identity);
      expect(filter.effectiveFuncA.type, SvgComponentTransferType.identity);
    });
  });

  group('Edge cases', () {
    test('empty tableValues behaves as identity', () {
      const funcTable = SvgComponentTransferFunction(
        type: SvgComponentTransferType.table,
        tableValues: [],
      );
      expect(funcTable.apply(0.3), 0.3);
      expect(funcTable.apply(0.7), 0.7);

      const funcDiscrete = SvgComponentTransferFunction(
        type: SvgComponentTransferType.discrete,
        tableValues: [],
      );
      expect(funcDiscrete.apply(0.3), 0.3);
      expect(funcDiscrete.apply(0.7), 0.7);
    });

    test('extreme slope values clamp properly', () {
      const funcHigh = SvgComponentTransferFunction(
        type: SvgComponentTransferType.linear,
        slope: 100.0,
        intercept: 0.0,
      );
      expect(funcHigh.apply(0.01), closeTo(1.0, 0.0001)); // clamped to 1
      expect(funcHigh.apply(0.0), closeTo(0.0, 0.0001));

      const funcNeg = SvgComponentTransferFunction(
        type: SvgComponentTransferType.linear,
        slope: -100.0,
        intercept: 0.0,
      );
      expect(funcNeg.apply(0.01), closeTo(0.0, 0.0001)); // clamped to 0
    });

    test('extreme exponent values in gamma', () {
      const funcHighExp = SvgComponentTransferFunction(
        type: SvgComponentTransferType.gamma,
        amplitude: 1.0,
        exponent: 10.0,
        offset: 0.0,
      );
      expect(funcHighExp.apply(0.5), closeTo(0.0009765625, 0.0001)); // 0.5^10
      expect(funcHighExp.apply(0.9), closeTo(0.3486784401, 0.01)); // 0.9^10

      const funcLowExp = SvgComponentTransferFunction(
        type: SvgComponentTransferType.gamma,
        amplitude: 1.0,
        exponent: 0.1,
        offset: 0.0,
      );
      expect(funcLowExp.apply(0.1), closeTo(0.7943, 0.01)); // 0.1^0.1
      expect(funcLowExp.apply(0.5), closeTo(0.9330, 0.01)); // 0.5^0.1
    });

    test('tableValues outside [0,1] clamp output', () {
      const func = SvgComponentTransferFunction(
        type: SvgComponentTransferType.table,
        tableValues: [-0.5, 1.5],
      );
      expect(func.apply(0.0), 0.0); // -0.5 clamped to 0
      expect(func.apply(1.0), 1.0); // 1.5 clamped to 1
      expect(func.apply(0.5), closeTo(0.5, 0.0001)); // midpoint
    });

    test('type attribute case insensitivity in parsing', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="caseTest">
      <feComponentTransfer>
        <feFuncR type="LINEAR" slope="0.5"/>
        <feFuncG type="GAMMA" exponent="2"/>
        <feFuncB type="TABLE" tableValues="0 1"/>
        <feFuncA type="DISCRETE" tableValues="0 1"/>
      </feComponentTransfer>
    </filter>
  </defs>
</svg>
''';
      final document = SvgParser.parse(svgString);
      final filter =
          document.filters!.getById('caseTest') as SvgComponentTransferFilter;

      expect(filter.funcR!.type, SvgComponentTransferType.linear);
      expect(filter.funcG!.type, SvgComponentTransferType.gamma);
      expect(filter.funcB!.type, SvgComponentTransferType.table);
      expect(filter.funcA!.type, SvgComponentTransferType.discrete);
    });

    test('tableValues with comma and space separators', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="separatorTest">
      <feComponentTransfer>
        <feFuncR type="table" tableValues="0 0.25 0.5 0.75 1"/>
        <feFuncG type="table" tableValues="0,0.25,0.5,0.75,1"/>
        <feFuncB type="table" tableValues="0, 0.25, 0.5, 0.75, 1"/>
      </feComponentTransfer>
    </filter>
  </defs>
</svg>
''';
      final document = SvgParser.parse(svgString);
      final filter = document.filters!.getById('separatorTest')
          as SvgComponentTransferFilter;

      expect(filter.funcR!.tableValues, [0.0, 0.25, 0.5, 0.75, 1.0]);
      expect(filter.funcG!.tableValues, [0.0, 0.25, 0.5, 0.75, 1.0]);
      expect(filter.funcB!.tableValues, [0.0, 0.25, 0.5, 0.75, 1.0]);
    });
  });

  group('Animation support', () {
    test('parses animate on feFuncR slope attribute', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="animatedSlope">
      <feComponentTransfer in="SourceGraphic">
        <feFuncR type="linear" slope="1">
          <animate attributeName="slope" from="1" to="2" dur="2s"/>
        </feFuncR>
      </feComponentTransfer>
    </filter>
  </defs>
</svg>
''';
      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);

      final slopeAnims =
          animations.where((a) => a.attributeName == 'slope').toList();
      expect(slopeAnims, isNotEmpty);
      // Animation values may be stored as strings or doubles depending on parser
      expect(slopeAnims.first.from.toString(), '1');
      expect(slopeAnims.first.to.toString(), '2');
    });

    test('parses animate on feFuncG amplitude attribute', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="animatedAmplitude">
      <feComponentTransfer>
        <feFuncG type="gamma" amplitude="1">
          <animate attributeName="amplitude" from="0.5" to="1.5" dur="1s"/>
        </feFuncG>
      </feComponentTransfer>
    </filter>
  </defs>
</svg>
''';
      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);

      final ampAnims =
          animations.where((a) => a.attributeName == 'amplitude').toList();
      expect(ampAnims, isNotEmpty);
      expect(ampAnims.first.from.toString(), '0.5');
      expect(ampAnims.first.to.toString(), '1.5');
    });

    test('parses animate on feFuncB exponent attribute', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="animatedExponent">
      <feComponentTransfer>
        <feFuncB type="gamma" exponent="1">
          <animate attributeName="exponent" values="1;2.2;1" dur="3s"/>
        </feFuncB>
      </feComponentTransfer>
    </filter>
  </defs>
</svg>
''';
      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);

      final expAnims =
          animations.where((a) => a.attributeName == 'exponent').toList();
      expect(expAnims, isNotEmpty);
      expect(expAnims.first.values!.length, 3);
      // Values are parsed as doubles for number attributes
      final values = expAnims.first.values!;
      // First value may be parsed as string '1' or double 1.0
      expect(double.parse(values[0].toString()), equals(1.0));
      expect(double.parse(values[1].toString()), equals(2.2));
      expect(double.parse(values[2].toString()), equals(1.0));
    });

    test('parses animate on feFuncA intercept attribute', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="animatedIntercept">
      <feComponentTransfer>
        <feFuncA type="linear" slope="1" intercept="0">
          <animate attributeName="intercept" from="0" to="0.5" dur="1s"/>
        </feFuncA>
      </feComponentTransfer>
    </filter>
  </defs>
</svg>
''';
      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);

      final intAnims =
          animations.where((a) => a.attributeName == 'intercept').toList();
      expect(intAnims, isNotEmpty);
      expect(intAnims.first.from.toString(), '0');
      expect(intAnims.first.to.toString(), '0.5');
    });

    test('parses animate on offset attribute', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="animatedOffset">
      <feComponentTransfer>
        <feFuncR type="gamma" offset="0">
          <animate attributeName="offset" from="0" to="0.3" dur="2s"/>
        </feFuncR>
      </feComponentTransfer>
    </filter>
  </defs>
</svg>
''';
      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);

      final offsetAnims =
          animations.where((a) => a.attributeName == 'offset').toList();
      expect(offsetAnims, isNotEmpty);
      // Offset is recognized as number attribute, so values are doubles
      expect(double.parse(offsetAnims.first.from.toString()), equals(0.0));
      expect(double.parse(offsetAnims.first.to.toString()), equals(0.3));
    });

    test('parses multiple animations on different func attributes', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="multiAnim">
      <feComponentTransfer>
        <feFuncR type="linear" slope="1" intercept="0">
          <animate attributeName="slope" from="0.5" to="1.5" dur="2s"/>
          <animate attributeName="intercept" from="0" to="0.2" dur="2s"/>
        </feFuncR>
        <feFuncG type="gamma" amplitude="1" exponent="1" offset="0">
          <animate attributeName="amplitude" from="0.8" to="1.2" dur="2s"/>
          <animate attributeName="exponent" from="1" to="2.2" dur="2s"/>
          <animate attributeName="offset" from="0" to="0.1" dur="2s"/>
        </feFuncG>
      </feComponentTransfer>
    </filter>
  </defs>
</svg>
''';
      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);

      expect(animations.where((a) => a.attributeName == 'slope'), isNotEmpty);
      expect(
        animations.where((a) => a.attributeName == 'intercept'),
        isNotEmpty,
      );
      expect(
        animations.where((a) => a.attributeName == 'amplitude'),
        isNotEmpty,
      );
      expect(
        animations.where((a) => a.attributeName == 'exponent'),
        isNotEmpty,
      );
      expect(animations.where((a) => a.attributeName == 'offset'), isNotEmpty);
    });
  });

  group('Pipeline integration', () {
    test('component transfer with feGaussianBlur chain', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="chainedFilter">
      <feGaussianBlur in="SourceGraphic" stdDeviation="2" result="blurred"/>
      <feComponentTransfer in="blurred">
        <feFuncR type="linear" slope="1.5" intercept="-0.25"/>
        <feFuncG type="linear" slope="1.5" intercept="-0.25"/>
        <feFuncB type="linear" slope="1.5" intercept="-0.25"/>
      </feComponentTransfer>
    </filter>
  </defs>
</svg>
''';
      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('chainedFilter');

      expect(passes, isNotEmpty);
      // Should have blur + linear color filter
      expect(passes.first.imageFilter, isNotNull); // Blur
      expect(passes.first.colorFilter, isNotNull); // Linear transfer
    });

    test('component transfer produces specialized pass for gamma', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="gammaOnly">
      <feComponentTransfer>
        <feFuncR type="gamma" amplitude="1" exponent="2.2" offset="0"/>
      </feComponentTransfer>
    </filter>
  </defs>
</svg>
''';
      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('gammaOnly');

      expect(passes, isNotEmpty);
      expect(passes.first, isA<SvgComponentTransferPaintPass>());
      final pass = passes.first as SvgComponentTransferPaintPass;
      expect(pass.transferFilter.funcR!.type, SvgComponentTransferType.gamma);
    });
  });
}
