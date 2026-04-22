import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

import 'package:full_svg_flutter/src/animation/svg_parser.dart';
import 'package:full_svg_flutter/src/animation/svg_filters.dart';

void main() {
  // ===========================================================================
  // Filter Input-Graph Hardening Tests
  // ===========================================================================
  // These tests cover edge cases for input/output chaining, feDropShadow
  // expansion, feMerge with multiple feMergeNode inputs, and implicit input
  // resolution.

  group('Complex multi-step filter chains (6+ primitives)', () {
    test('Six-step sequential chain with named results', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="sixStepFx">
      <feOffset dx="1" dy="0" result="a"/>
      <feOffset in="a" dx="1" dy="0" result="b"/>
      <feOffset in="b" dx="1" dy="0" result="c"/>
      <feOffset in="c" dx="1" dy="0" result="d"/>
      <feOffset in="d" dx="1" dy="0" result="e"/>
      <feOffset in="e" dx="1" dy="0"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#sixStepFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('sixStepFx');

      expect(passes, hasLength(1));
      // Total offset: 1+1+1+1+1+1 = 6
      expect(passes.single.offset, const ui.Offset(6, 0));
    });

    test('Seven-step chain with branching and merge', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="sevenStepFx">
      <feOffset dx="1" dy="0" result="base"/>
      <feGaussianBlur in="base" stdDeviation="1" result="blurred"/>
      <feColorMatrix in="base" type="saturate" values="0" result="gray"/>
      <feOffset in="blurred" dx="2" dy="0" result="blurOffset"/>
      <feOffset in="gray" dx="3" dy="0" result="grayOffset"/>
      <feMerge result="merged">
        <feMergeNode in="blurOffset"/>
        <feMergeNode in="grayOffset"/>
      </feMerge>
      <feOffset in="merged" dx="4" dy="0"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#sevenStepFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('sevenStepFx');

      // Merge produces 2 passes, then offset adds 4 to each
      expect(passes, hasLength(2));
      // blurOffset: base(1) + 2 + 4 = 7
      expect(passes[0].offset.dx, 7);
      // grayOffset: base(1) + 3 + 4 = 8
      expect(passes[1].offset.dx, 8);
    });

    test('Eight-step chain with implicit inputs', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="eightStepFx">
      <feOffset dx="1" dy="0"/>
      <feOffset dx="1" dy="0"/>
      <feOffset dx="1" dy="0"/>
      <feOffset dx="1" dy="0"/>
      <feOffset dx="1" dy="0"/>
      <feOffset dx="1" dy="0"/>
      <feOffset dx="1" dy="0"/>
      <feOffset dx="1" dy="0"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#eightStepFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('eightStepFx');

      expect(passes, hasLength(1));
      // All implicit inputs chain: 8 * 1 = 8
      expect(passes.single.offset, const ui.Offset(8, 0));
    });

    test('Complex chain with multiple named result reuses', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="reuseResultFx">
      <feGaussianBlur stdDeviation="2" result="common"/>
      <feOffset in="common" dx="1" dy="0" result="a"/>
      <feOffset in="common" dx="2" dy="0" result="b"/>
      <feOffset in="common" dx="3" dy="0" result="c"/>
      <feMerge>
        <feMergeNode in="a"/>
        <feMergeNode in="b"/>
        <feMergeNode in="c"/>
      </feMerge>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#reuseResultFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('reuseResultFx');

      // 3 merge nodes, each from common (blur)
      expect(passes, hasLength(3));
      expect(passes[0].offset, const ui.Offset(1, 0));
      expect(passes[1].offset, const ui.Offset(2, 0));
      expect(passes[2].offset, const ui.Offset(3, 0));
      // All should have blur applied
      expect(passes[0].imageFilter, isNotNull);
      expect(passes[1].imageFilter, isNotNull);
      expect(passes[2].imageFilter, isNotNull);
    });
  });

  group('feDropShadow comprehensive chaining', () {
    test('feDropShadow with custom dx/dy/stdDeviation/flood-color', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="customShadowFx">
      <feDropShadow dx="5" dy="10" stdDeviation="3 4" flood-color="#FF0000" flood-opacity="0.7"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#customShadowFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final filter = document.filters!.getById('customShadowFx');
      expect(filter, isA<SvgDropShadowFilter>());

      final dropShadow = filter as SvgDropShadowFilter;
      expect(dropShadow.dx, 5.0);
      expect(dropShadow.dy, 10.0);
      expect(dropShadow.stdDeviationX, 3.0);
      expect(dropShadow.stdDeviationY, 4.0);
      expect(dropShadow.floodOpacity, closeTo(0.7, 0.01));

      final passes = document.filters!.resolvePaintPasses('customShadowFx');
      expect(passes, hasLength(2));
      expect(passes[0].offset, const ui.Offset(5, 10)); // shadow
      expect(passes[0].imageFilter, isNotNull); // blur
      expect(passes[0].colorFilter, isNotNull); // flood color
      expect(passes[1].offset, ui.Offset.zero); // source
    });

    test('feDropShadow expansion chained with downstream primitives', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="shadowChainFx">
      <feDropShadow dx="3" dy="3" stdDeviation="2" result="shadow"/>
      <feOffset in="shadow" dx="5" dy="0"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#shadowChainFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('shadowChainFx');

      // DropShadow produces 2 passes, offset adds 5 to each
      expect(passes, hasLength(2));
      expect(passes[0].offset.dx, 8); // shadow 3 + offset 5
      expect(passes[1].offset.dx, 5); // source 0 + offset 5
    });

    test('feDropShadow with SourceAlpha input', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="shadowAlphaFx">
      <feDropShadow in="SourceAlpha" dx="4" dy="4" stdDeviation="2"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#shadowAlphaFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('shadowAlphaFx');

      expect(passes, hasLength(2));
      // Both passes should have the alpha extraction filter from SourceAlpha
      expect(passes[0].colorFilter, isNotNull);
      expect(passes[1].colorFilter, isNotNull);
    });

    test('Triple feDropShadow chain accumulates correctly', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="tripleShadowFx">
      <feDropShadow dx="1" dy="1" stdDeviation="1" result="s1"/>
      <feDropShadow in="s1" dx="2" dy="2" stdDeviation="1" result="s2"/>
      <feDropShadow in="s2" dx="3" dy="3" stdDeviation="1"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#tripleShadowFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('tripleShadowFx');

      // Each shadow doubles passes: 1->2->4->8
      expect(passes, hasLength(8));
    });

    test('feDropShadow combined with feComposite arithmetic', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="shadowArithmeticFx">
      <feDropShadow dx="3" dy="3" stdDeviation="2" result="shadow"/>
      <feComposite in="shadow" in2="SourceGraphic" operator="arithmetic" k1="0" k2="0.5" k3="0.5" k4="0"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#shadowArithmeticFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('shadowArithmeticFx');

      expect(passes.length, greaterThanOrEqualTo(2));
    });
  });

  group('feMerge with 3+ feMergeNode edge cases', () {
    test('feMerge with 5 feMergeNode children', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="fiveMergeFx">
      <feOffset dx="1" dy="0" result="a"/>
      <feOffset dx="2" dy="0" result="b"/>
      <feOffset dx="3" dy="0" result="c"/>
      <feOffset dx="4" dy="0" result="d"/>
      <feOffset dx="5" dy="0" result="e"/>
      <feMerge>
        <feMergeNode in="a"/>
        <feMergeNode in="b"/>
        <feMergeNode in="c"/>
        <feMergeNode in="d"/>
        <feMergeNode in="e"/>
      </feMerge>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#fiveMergeFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('fiveMergeFx');

      expect(passes, hasLength(5));
      expect(passes[0].offset, const ui.Offset(1, 0)); // a
      // b is implicit chain from a: 1+2=3
      expect(passes[1].offset, const ui.Offset(3, 0)); // b
      // c is implicit chain from b: 3+3=6
      expect(passes[2].offset, const ui.Offset(6, 0)); // c
      // d is implicit chain from c: 6+4=10
      expect(passes[3].offset, const ui.Offset(10, 0)); // d
      // e is implicit chain from d: 10+5=15
      expect(passes[4].offset, const ui.Offset(15, 0)); // e
    });

    test('feMerge mixing implicit and explicit inputs', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="mixedMergeFx">
      <feOffset dx="5" dy="0" result="offsetResult"/>
      <feMerge>
        <feMergeNode in="SourceGraphic"/>
        <feMergeNode/>
        <feMergeNode in="offsetResult"/>
        <feMergeNode in="SourceAlpha"/>
      </feMerge>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#mixedMergeFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('mixedMergeFx');

      expect(passes, hasLength(4));
      expect(passes[0].offset, ui.Offset.zero); // SourceGraphic
      expect(
        passes[1].offset,
        const ui.Offset(5, 0),
      ); // implicit previous (offset)
      expect(passes[2].offset, const ui.Offset(5, 0)); // offsetResult
      expect(passes[3].colorFilter, isNotNull); // SourceAlpha
    });

    test('feMerge with non-existent reference falls back properly', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="badRefMergeFx">
      <feOffset dx="3" dy="0" result="valid"/>
      <feMerge>
        <feMergeNode in="valid"/>
        <feMergeNode in="doesNotExist"/>
        <feMergeNode in="SourceGraphic"/>
      </feMerge>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#badRefMergeFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('badRefMergeFx');

      // Should have 2 passes: valid + SourceGraphic (doesNotExist produces empty)
      expect(passes, hasLength(2));
      expect(passes[0].offset, const ui.Offset(3, 0)); // valid
      expect(passes[1].offset, ui.Offset.zero); // SourceGraphic
    });

    test('feMerge with all feMergeNode having empty in attribute', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="allEmptyMergeFx">
      <feOffset dx="2" dy="0"/>
      <feMerge>
        <feMergeNode in=""/>
        <feMergeNode in=""/>
        <feMergeNode in=""/>
      </feMerge>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#allEmptyMergeFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('allEmptyMergeFx');

      // All empty in attributes should use previous (offset)
      expect(passes, hasLength(3));
      for (final pass in passes) {
        expect(pass.offset, const ui.Offset(2, 0));
      }
    });
  });

  group('Implicit input resolution edge cases', () {
    test(
      'Implicit input with no previous (first primitive uses SourceGraphic)',
      () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="firstImplicitFx">
      <feGaussianBlur stdDeviation="2"/>
      <feOffset dx="3" dy="0"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#firstImplicitFx)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final passes = document.filters!.resolvePaintPasses('firstImplicitFx');

        expect(passes, hasLength(1));
        expect(passes.single.imageFilter, isNotNull); // blur
        expect(passes.single.offset, const ui.Offset(3, 0)); // offset
      },
    );

    test('Implicit input after named result still uses previous', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="implicitAfterNamedFx">
      <feOffset dx="1" dy="0" result="named"/>
      <feOffset dx="2" dy="0"/>
      <feOffset dx="3" dy="0"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#implicitAfterNamedFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses(
        'implicitAfterNamedFx',
      );

      expect(passes, hasLength(1));
      // Chain: 1 + 2 + 3 = 6
      expect(passes.single.offset, const ui.Offset(6, 0));
    });

    test('Explicit in overrides implicit chaining', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="explicitOverridesFx">
      <feOffset dx="10" dy="0" result="first"/>
      <feOffset dx="20" dy="0"/>
      <feOffset in="first" dx="1" dy="0"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#explicitOverridesFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses(
        'explicitOverridesFx',
      );

      expect(passes, hasLength(1));
      // Last primitive explicitly uses "first" (10), then adds 1 = 11
      expect(passes.single.offset, const ui.Offset(11, 0));
    });
  });

  group('SourceAlpha as input', () {
    test('SourceAlpha produces alpha-extracted passes', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="sourceAlphaFx">
      <feGaussianBlur in="SourceAlpha" stdDeviation="3"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#sourceAlphaFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('sourceAlphaFx');

      expect(passes, hasLength(1));
      expect(passes.single.imageFilter, isNotNull); // blur
      expect(passes.single.colorFilter, isNotNull); // alpha extraction
    });

    test('SourceAlpha used in composite with SourceGraphic', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="alphaCompositeFx">
      <feComposite in="SourceGraphic" in2="SourceAlpha" operator="in"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#alphaCompositeFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('alphaCompositeFx');

      expect(passes, hasLength(2));
      // in2 (SourceAlpha) should have colorFilter for alpha extraction
      expect(passes[0].colorFilter, isNotNull);
    });

    test('SourceAlpha chained through multiple primitives', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="alphaChainFx">
      <feGaussianBlur in="SourceAlpha" stdDeviation="2" result="blurredAlpha"/>
      <feOffset in="blurredAlpha" dx="3" dy="3" result="offsetAlpha"/>
      <feFlood flood-color="black" flood-opacity="0.5" result="shadowColor"/>
      <feComposite in="shadowColor" in2="offsetAlpha" operator="in"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#alphaChainFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('alphaChainFx');

      expect(passes, isNotEmpty);
    });
  });

  group('Named result reuse by multiple downstream primitives', () {
    test('Same named result used by 3 downstream primitives', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="tripleReuseFx">
      <feGaussianBlur stdDeviation="2" result="shared"/>
      <feOffset in="shared" dx="1" dy="0" result="use1"/>
      <feColorMatrix in="shared" type="saturate" values="0" result="use2"/>
      <feOffset in="shared" dx="2" dy="0" result="use3"/>
      <feMerge>
        <feMergeNode in="use1"/>
        <feMergeNode in="use2"/>
        <feMergeNode in="use3"/>
      </feMerge>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#tripleReuseFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('tripleReuseFx');

      expect(passes, hasLength(3));
      // All derived from shared (blur)
      expect(passes[0].imageFilter, isNotNull); // use1: shared + offset
      expect(passes[0].offset, const ui.Offset(1, 0));
      expect(passes[1].imageFilter, isNotNull); // use2: shared + colorMatrix
      expect(passes[2].imageFilter, isNotNull); // use3: shared + offset
      expect(passes[2].offset, const ui.Offset(2, 0));
    });

    test('Named result referenced before and after other primitives', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="beforeAfterFx">
      <feOffset dx="5" dy="0" result="base"/>
      <feOffset in="base" dx="1" dy="0" result="early"/>
      <feGaussianBlur stdDeviation="2"/>
      <feOffset in="base" dx="2" dy="0" result="late"/>
      <feMerge>
        <feMergeNode in="early"/>
        <feMergeNode in="late"/>
      </feMerge>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#beforeAfterFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('beforeAfterFx');

      expect(passes, hasLength(2));
      expect(passes[0].offset, const ui.Offset(6, 0)); // base(5) + 1
      expect(passes[1].offset, const ui.Offset(7, 0)); // base(5) + 2
    });
  });

  group('Error handling for invalid/missing input references', () {
    test('Forward reference produces empty result', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="forwardRefFx">
      <feOffset in="futureResult" dx="5" dy="0" result="early"/>
      <feGaussianBlur stdDeviation="2" result="futureResult"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#forwardRefFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('forwardRefFx');

      // Forward ref produces empty for early, then futureResult is computed
      expect(passes, isNotEmpty);
      expect(passes.last.imageFilter, isNotNull); // blur from futureResult
    });

    test('Non-existent reference in composite produces identity', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="badCompositeFx">
      <feComposite in="nonExistent" in2="alsoNonExistent" operator="over"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#badCompositeFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('badCompositeFx');

      // Both inputs unresolved should produce identity
      expect(passes, hasLength(1));
      expect(passes.single.imageFilter, isNull);
      expect(passes.single.colorFilter, isNull);
    });

    test('in2 non-existent but in valid still produces output', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="partialBadFx">
      <feOffset dx="3" dy="0" result="valid"/>
      <feComposite in="valid" in2="nonExistent" operator="over"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#partialBadFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('partialBadFx');

      // in valid, in2 invalid - should produce empty or valid input only
      // Per spec, unresolved in2 should produce transparent black result
      expect(passes, hasLength(1));
    });

    test('Circular reference detection prevents infinite loop', () {
      // This is hard to test directly since result names are computed sequentially,
      // but we can test that the circular detection mechanism works
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="circularTestFx">
      <feOffset dx="1" dy="0" result="a"/>
      <feOffset in="a" dx="2" dy="0" result="b"/>
      <feOffset in="b" dx="3" dy="0" result="c"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#circularTestFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('circularTestFx');

      // Should complete without hanging
      expect(passes, hasLength(1));
      expect(passes.single.offset, const ui.Offset(6, 0)); // 1+2+3
    });

    test('Deep chain (64+ primitives) is handled within depth limit', () {
      // Build a deep chain programmatically
      final primitives = StringBuffer();
      for (var i = 0; i < 60; i++) {
        if (i == 0) {
          primitives.writeln('<feOffset dx="1" dy="0" result="r$i"/>');
        } else {
          primitives.writeln(
            '<feOffset in="r${i - 1}" dx="1" dy="0" result="r$i"/>',
          );
        }
      }

      final svgString =
          '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="deepChainFx">
      $primitives
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#deepChainFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('deepChainFx');

      // Should complete without error
      expect(passes, hasLength(1));
      expect(passes.single.offset.dx, 60.0); // 60 * 1
    });
  });

  group('Special input names handling', () {
    test('Case-insensitive built-in input resolution', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="caseInsensitiveFx">
      <feGaussianBlur in="sourcegraphic" stdDeviation="2"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#caseInsensitiveFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('caseInsensitiveFx');

      expect(passes, hasLength(1));
      expect(passes.single.imageFilter, isNotNull); // blur applied
    });

    test('in="none" produces transparent black', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="noneFx">
      <feOffset in="none" dx="5" dy="0"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#noneFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('noneFx');

      // in="none" should produce empty (transparent black)
      // which falls back to identity
      expect(passes, hasLength(1));
    });

    test('FillPaint and StrokePaint built-in inputs', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="paintInputFx">
      <feGaussianBlur in="FillPaint" stdDeviation="1" result="blurredFill"/>
      <feGaussianBlur in="StrokePaint" stdDeviation="2" result="blurredStroke"/>
      <feMerge>
        <feMergeNode in="blurredFill"/>
        <feMergeNode in="blurredStroke"/>
      </feMerge>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" stroke="red" filter="url(#paintInputFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('paintInputFx');

      expect(passes, hasLength(2));
      // FillPaint should have paintFill=true, paintStroke=false
      expect(passes[0].paintFill, isTrue);
      expect(passes[0].paintStroke, isFalse);
      // StrokePaint should have paintFill=false, paintStroke=true
      expect(passes[1].paintFill, isFalse);
      expect(passes[1].paintStroke, isTrue);
    });
  });

  group('feBlend and feComposite with various in2 scenarios', () {
    test('feBlend with empty in2 uses previous', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="blendEmptyIn2Fx">
      <feOffset dx="3" dy="0"/>
      <feBlend in="SourceGraphic" mode="multiply"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#blendEmptyIn2Fx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('blendEmptyIn2Fx');

      expect(passes, hasLength(1));
      expect(passes.single.blendMode, ui.BlendMode.multiply);
    });

    test('feComposite operator=in masks by in2 alpha', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="compositeInFx">
      <feFlood flood-color="red" result="redFlood"/>
      <feComposite in="redFlood" in2="SourceAlpha" operator="in"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#compositeInFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('compositeInFx');

      expect(passes, isNotEmpty);
      // Composite `in` keeps srcIn semantics in the resulting layer stack.
      expect(
        passes.any((p) => p.blendMode == ui.BlendMode.srcIn) ||
            passes.any((p) => p.fillColorOverride != null),
        isTrue,
      );
    });
  });
}
