import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_svg/src/animation/svg_parser.dart';
import 'package:flutter_svg/src/animation/svg_filters.dart';

void main() {
  // ===========================================================================
  // Advanced Filter Input-Graph Semantics Tests
  // ===========================================================================
  // These tests cover edge cases for:
  // 1. FillPaint/StrokePaint source distinction edge cases
  // 2. Recursive filter composition edge cases (deep chains A→B→C→D)
  // 3. Advanced feDropShadow with non-source input chains
  // 4. Advanced feMerge with explicit unresolved inputs

  group('FillPaint/StrokePaint source distinction edge cases', () {
    test('FillPaint with gradient fill resolves correctly', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <linearGradient id="grad1">
      <stop offset="0%" style="stop-color:red"/>
      <stop offset="100%" style="stop-color:blue"/>
    </linearGradient>
    <filter id="fillPaintGradientFx">
      <feGaussianBlur in="FillPaint" stdDeviation="2" result="blurredFill"/>
      <feMerge>
        <feMergeNode in="blurredFill"/>
        <feMergeNode in="SourceGraphic"/>
      </feMerge>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="url(#grad1)" filter="url(#fillPaintGradientFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses(
        'fillPaintGradientFx',
      );

      expect(passes, hasLength(2));
      // FillPaint should have paintFill=true, paintStroke=false
      expect(passes[0].paintFill, isTrue);
      expect(passes[0].paintStroke, isFalse);
      expect(passes[0].imageFilter, isNotNull); // blur applied
    });

    test('StrokePaint with pattern resolves correctly', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <pattern id="pat1" width="10" height="10" patternUnits="userSpaceOnUse">
      <circle cx="5" cy="5" r="3" fill="red"/>
    </pattern>
    <filter id="strokePaintPatternFx">
      <feGaussianBlur in="StrokePaint" stdDeviation="1"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" stroke="url(#pat1)" filter="url(#strokePaintPatternFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses(
        'strokePaintPatternFx',
      );

      expect(passes, hasLength(1));
      // StrokePaint should have paintFill=false, paintStroke=true
      expect(passes[0].paintFill, isFalse);
      expect(passes[0].paintStroke, isTrue);
    });

    test('FillPaint in nested filter context', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="nestedFillFx">
      <feOffset in="FillPaint" dx="2" dy="2" result="offsetFill"/>
      <feGaussianBlur in="offsetFill" stdDeviation="1"/>
    </filter>
  </defs>
  <rect fill="green" filter="url(#nestedFillFx)" x="10" y="10" width="50" height="50"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('nestedFillFx');

      expect(passes, hasLength(1));
      expect(passes[0].paintFill, isTrue);
      expect(passes[0].offset.dx, 2);
      expect(passes[0].imageFilter, isNotNull);
    });

    test('StrokePaint and FillPaint combined in same filter', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="bothPaintsFx">
      <feGaussianBlur in="FillPaint" stdDeviation="2" result="blurredFill"/>
      <feGaussianBlur in="StrokePaint" stdDeviation="1" result="blurredStroke"/>
      <feMerge>
        <feMergeNode in="blurredFill"/>
        <feMergeNode in="blurredStroke"/>
      </feMerge>
    </filter>
  </defs>
  <rect fill="blue" stroke="red" filter="url(#bothPaintsFx)" x="10" y="10" width="50" height="50"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('bothPaintsFx');

      expect(passes, hasLength(2));
      expect(passes[0].paintFill, isTrue);
      expect(passes[0].paintStroke, isFalse);
      expect(passes[1].paintFill, isFalse);
      expect(passes[1].paintStroke, isTrue);
    });

    test('FillPaint case-insensitive resolution', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="fillPaintCaseFx">
      <feGaussianBlur in="fillpaint" stdDeviation="2"/>
    </filter>
  </defs>
  <rect fill="blue" filter="url(#fillPaintCaseFx)" x="10" y="10" width="50" height="50"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('fillPaintCaseFx');

      expect(passes, hasLength(1));
      expect(passes[0].paintFill, isTrue);
    });
  });

  group('Recursive filter composition edge cases', () {
    test('Deep chain A→B→C→D with 4 primitives', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="deepChainFx">
      <feOffset dx="1" dy="0" result="A"/>
      <feOffset in="A" dx="2" dy="0" result="B"/>
      <feOffset in="B" dx="3" dy="0" result="C"/>
      <feOffset in="C" dx="4" dy="0" result="D"/>
      <feOffset in="D" dx="5" dy="0"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#deepChainFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('deepChainFx');

      expect(passes, hasLength(1));
      // Total offset: 1+2+3+4+5 = 15
      expect(passes.single.offset, const ui.Offset(15, 0));
    });

    test('Deep chain with branch and rejoin', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="branchRejoinFx">
      <feOffset dx="1" dy="0" result="base"/>
      <feOffset in="base" dx="2" dy="0" result="branch1"/>
      <feOffset in="base" dx="3" dy="0" result="branch2"/>
      <feMerge result="merged">
        <feMergeNode in="branch1"/>
        <feMergeNode in="branch2"/>
      </feMerge>
      <feOffset in="merged" dx="4" dy="0"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#branchRejoinFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('branchRejoinFx');

      expect(passes, hasLength(2));
      // branch1: base(1) + 2 + 4 = 7
      expect(passes[0].offset.dx, 7);
      // branch2: base(1) + 3 + 4 = 8
      expect(passes[1].offset.dx, 8);
    });

    test('Maximum depth chain (60 primitives) completes without error', () {
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
    <filter id="maxDepthFx">
      $primitives
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#maxDepthFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('maxDepthFx');

      // Should complete without error
      expect(passes, hasLength(1));
      expect(passes.single.offset.dx, 60.0);
    });

    test('Missing named result falls back gracefully', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="missingResultFx">
      <feOffset dx="5" dy="0" result="existing"/>
      <feOffset in="nonExistent" dx="10" dy="0"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#missingResultFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('missingResultFx');

      // Should complete without error - missing ref produces empty
      expect(passes, hasLength(1));
    });

    test('Forward reference produces transparent black', () {
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

      expect(passes, isNotEmpty);
      // The blur from futureResult should be in the final output
      expect(passes.last.imageFilter, isNotNull);
    });

    test('Same named result referenced multiple times', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="multiRefFx">
      <feGaussianBlur stdDeviation="2" result="shared"/>
      <feOffset in="shared" dx="1" dy="0" result="use1"/>
      <feOffset in="shared" dx="2" dy="0" result="use2"/>
      <feOffset in="shared" dx="3" dy="0" result="use3"/>
      <feMerge>
        <feMergeNode in="use1"/>
        <feMergeNode in="use2"/>
        <feMergeNode in="use3"/>
      </feMerge>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#multiRefFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('multiRefFx');

      expect(passes, hasLength(3));
      // All should have blur applied
      expect(passes[0].imageFilter, isNotNull);
      expect(passes[1].imageFilter, isNotNull);
      expect(passes[2].imageFilter, isNotNull);
      // Different offsets
      expect(passes[0].offset.dx, 1);
      expect(passes[1].offset.dx, 2);
      expect(passes[2].offset.dx, 3);
    });
  });

  group('Advanced feDropShadow with non-source input chains', () {
    test('feDropShadow with named result input', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="shadowNamedInputFx">
      <feGaussianBlur stdDeviation="1" result="blurred"/>
      <feDropShadow in="blurred" dx="3" dy="3" stdDeviation="2"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#shadowNamedInputFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('shadowNamedInputFx');

      // DropShadow produces 2 passes (shadow + source)
      expect(passes, hasLength(2));
      // Shadow pass should have offset
      expect(passes[0].offset, const ui.Offset(3, 3));
      // Both should have blur from the input
      expect(passes[0].imageFilter, isNotNull);
      expect(passes[1].imageFilter, isNotNull);
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
      // Both should have color filter from SourceAlpha
      expect(passes[0].colorFilter, isNotNull);
      expect(passes[1].colorFilter, isNotNull);
    });

    test('feDropShadow with FillPaint input', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="shadowFillPaintFx">
      <feDropShadow in="FillPaint" dx="5" dy="5" stdDeviation="3"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="red" filter="url(#shadowFillPaintFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('shadowFillPaintFx');

      expect(passes, hasLength(2));
      // Should maintain FillPaint context
      expect(passes[0].paintFill, isTrue);
      expect(passes[1].paintFill, isTrue);
    });

    test('Triple feDropShadow chain with custom inputs', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="tripleShadowChainFx">
      <feDropShadow dx="1" dy="1" stdDeviation="1" result="s1"/>
      <feDropShadow in="s1" dx="2" dy="2" stdDeviation="1" result="s2"/>
      <feDropShadow in="s2" dx="3" dy="3" stdDeviation="1"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#tripleShadowChainFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses(
        'tripleShadowChainFx',
      );

      // Each shadow doubles passes: 1->2->4->8
      expect(passes, hasLength(8));
    });

    test('feDropShadow with in="none" produces empty', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="shadowNoneFx">
      <feDropShadow in="none" dx="5" dy="5" stdDeviation="2"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#shadowNoneFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('shadowNoneFx');

      // Should return identity since in="none" produces empty
      expect(passes, hasLength(1));
    });

    test('feDropShadow chained after feColorMatrix', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="colorMatrixShadowFx">
      <feColorMatrix type="saturate" values="0" result="grayscale"/>
      <feDropShadow in="grayscale" dx="4" dy="4" stdDeviation="3"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#colorMatrixShadowFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses(
        'colorMatrixShadowFx',
      );

      expect(passes, hasLength(2));
      expect(passes[0].offset, const ui.Offset(4, 4)); // shadow
    });
  });

  group('Advanced feMerge with explicit unresolved inputs', () {
    test(
      'feMerge with unresolvable in produces transparent black for that node',
      () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="unresolvedMergeFx">
      <feOffset dx="5" dy="0" result="valid"/>
      <feMerge>
        <feMergeNode in="valid"/>
        <feMergeNode in="doesNotExist"/>
        <feMergeNode in="SourceGraphic"/>
      </feMerge>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#unresolvedMergeFx)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final passes = document.filters!.resolvePaintPasses(
          'unresolvedMergeFx',
        );

        // Per SVG spec: unresolved reference produces transparent black (empty)
        // Should have 2 passes: valid + SourceGraphic (doesNotExist produces empty)
        expect(passes, hasLength(2));
        expect(passes[0].offset, const ui.Offset(5, 0)); // valid
        expect(passes[1].offset, ui.Offset.zero); // SourceGraphic
      },
    );

    test('Empty feMerge (no children) uses previous gracefully', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="emptyMergeFx">
      <feOffset dx="3" dy="3"/>
      <feMerge/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#emptyMergeFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('emptyMergeFx');

      expect(passes, hasLength(1));
      // Should use previous offset result
      expect(passes[0].offset, const ui.Offset(3, 3));
    });

    test('feMerge with all in="none" returns identity', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="allNoneMergeFx">
      <feMerge>
        <feMergeNode in="none"/>
        <feMergeNode in="none"/>
        <feMergeNode in="none"/>
      </feMerge>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#allNoneMergeFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('allNoneMergeFx');

      // All in="none" should return identity
      expect(passes, hasLength(1));
      expect(passes[0], equals(const SvgFilterPaintPass()));
    });

    test('feMerge with mixed valid and invalid inputs', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="mixedMergeFx">
      <feGaussianBlur stdDeviation="2" result="blurred"/>
      <feOffset dx="5" dy="0" result="offset"/>
      <feMerge>
        <feMergeNode in="blurred"/>
        <feMergeNode in="invalid1"/>
        <feMergeNode in="offset"/>
        <feMergeNode in="invalid2"/>
        <feMergeNode in="SourceAlpha"/>
      </feMerge>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#mixedMergeFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('mixedMergeFx');

      // Per SVG spec: invalid references produce empty (transparent black)
      // blurred + offset + SourceAlpha = 3 passes (invalid1/2 produce empty)
      expect(passes, hasLength(3));
    });

    test('feMerge with 6+ feMergeNode children', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="sixNodeMergeFx">
      <feOffset dx="1" dy="0" result="a"/>
      <feOffset dx="2" dy="0" result="b"/>
      <feOffset dx="3" dy="0" result="c"/>
      <feOffset dx="4" dy="0" result="d"/>
      <feOffset dx="5" dy="0" result="e"/>
      <feOffset dx="6" dy="0" result="f"/>
      <feMerge>
        <feMergeNode in="a"/>
        <feMergeNode in="b"/>
        <feMergeNode in="c"/>
        <feMergeNode in="d"/>
        <feMergeNode in="e"/>
        <feMergeNode in="f"/>
      </feMerge>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#sixNodeMergeFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('sixNodeMergeFx');

      expect(passes, hasLength(6));
    });

    test('Chained feMerge references another feMerge result', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="chainedMergeFx">
      <feOffset dx="1" dy="0" result="a"/>
      <feOffset dx="2" dy="0" result="b"/>
      <feMerge result="merge1">
        <feMergeNode in="a"/>
        <feMergeNode in="b"/>
      </feMerge>
      <feOffset dx="3" dy="0" result="c"/>
      <feMerge>
        <feMergeNode in="merge1"/>
        <feMergeNode in="c"/>
      </feMerge>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#chainedMergeFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('chainedMergeFx');

      // merge1 has 2 passes, c chains from merge1 (2 passes) + offset(3) = 2 passes
      // final merge: merge1 (2) + c (2) = 4 passes
      expect(passes, hasLength(4));
    });
  });

  group('Edge cases for circular reference detection', () {
    test('No circular reference in linear chain', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="linearChainFx">
      <feOffset dx="1" dy="0" result="a"/>
      <feOffset in="a" dx="2" dy="0" result="b"/>
      <feOffset in="b" dx="3" dy="0" result="c"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#linearChainFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('linearChainFx');

      expect(passes, hasLength(1));
      expect(passes.single.offset, const ui.Offset(6, 0));
    });

    test('Resolution depth limit prevents stack overflow', () {
      // Build chain near depth limit
      final primitives = StringBuffer();
      for (var i = 0; i < 63; i++) {
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
    <filter id="depthLimitFx">
      $primitives
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#depthLimitFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('depthLimitFx');

      expect(passes, hasLength(1));
      expect(passes.single.offset.dx, 63.0);
    });
  });

  group('Whitespace handling in input references', () {
    test('Leading/trailing whitespace in input reference', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="whitespaceFx">
      <feOffset dx="5" dy="0" result="target"/>
      <feOffset in="  target  " dx="3" dy="0"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#whitespaceFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('whitespaceFx');

      expect(passes, hasLength(1));
      // Should trim whitespace and resolve correctly
      expect(passes.single.offset, const ui.Offset(8, 0));
    });

    test('in attribute with only whitespace uses previous', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="emptyWhitespaceFx">
      <feOffset dx="5" dy="0"/>
      <feOffset in="   " dx="3" dy="0"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#emptyWhitespaceFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('emptyWhitespaceFx');

      expect(passes, hasLength(1));
      expect(passes.single.offset, const ui.Offset(8, 0));
    });
  });
}
