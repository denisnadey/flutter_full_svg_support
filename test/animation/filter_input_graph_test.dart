import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

import 'package:full_svg_flutter/src/animation/svg_parser.dart';
import 'package:full_svg_flutter/src/animation/svg_filters.dart';

void main() {
  // ===========================================================================
  // Filter Input-Graph Semantics Tests
  // Tests for advanced input-graph features: FillPaint/StrokePaint sources,
  // in="none" handling, advanced feMerge chains, and feDropShadow composition.
  // ===========================================================================

  group('FillPaint/StrokePaint source inputs', () {
    test('FillPaint as filter input with provided fill context', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="fillPaintFx">
      <feGaussianBlur in="FillPaint" stdDeviation="2"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#fillPaintFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses(
        'fillPaintFx',
        sourceContext: const SvgFilterSourceContext(
          fillPaint: <SvgFilterPaintPass>[
            SvgFilterPaintPass(
              colorFilter: ui.ColorFilter.mode(
                ui.Color(0xFF0000FF),
                ui.BlendMode.srcIn,
              ),
            ),
          ],
        ),
      );

      expect(passes, hasLength(1));
      expect(passes[0].colorFilter, isNotNull);
      expect(passes[0].imageFilter, isNotNull); // blur applied
    });

    test('StrokePaint as filter input with provided stroke context', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="strokePaintFx">
      <feColorMatrix in="StrokePaint" type="saturate" values="0"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" stroke="red" filter="url(#strokePaintFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses(
        'strokePaintFx',
        sourceContext: const SvgFilterSourceContext(
          strokePaint: <SvgFilterPaintPass>[
            SvgFilterPaintPass(
              colorFilter: ui.ColorFilter.mode(
                ui.Color(0xFFFF0000),
                ui.BlendMode.srcIn,
              ),
            ),
          ],
        ),
      );

      expect(passes, hasLength(1));
      expect(passes[0].colorFilter, isNotNull);
    });

    test('FillPaint without context falls back to synthetic paint pass', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="fillNoCtxFx">
      <feOffset in="FillPaint" dx="5" dy="0"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#fillNoCtxFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      // No source context provided - should use synthetic fill paint
      final passes = document.filters!.resolvePaintPasses('fillNoCtxFx');

      expect(passes, hasLength(1));
      expect(passes[0].offset, const ui.Offset(5, 0));
      expect(passes[0].paintFill, isTrue);
      expect(passes[0].paintStroke, isFalse);
    });

    test('Case-insensitive FillPaint/StrokePaint references', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="caseInsensitiveFx">
      <feMerge>
        <feMergeNode in="fillpaint"/>
        <feMergeNode in="strokepaint"/>
      </feMerge>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#caseInsensitiveFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('caseInsensitiveFx');

      // Both fillpaint and strokepaint should resolve
      expect(passes, hasLength(2));
    });
  });

  group('in="none" handling', () {
    test('in="none" produces transparent output for feGaussianBlur', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="noneBlurFx">
      <feGaussianBlur in="none" stdDeviation="2"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#noneBlurFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('noneBlurFx');

      // in="none" produces empty passes
      expect(passes, hasLength(1));
      expect(passes[0], equals(SvgFilterPaintPass.identity));
    });

    test('in="none" produces empty output for feDropShadow', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="noneShadowFx">
      <feDropShadow in="none" dx="3" dy="3" stdDeviation="2"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#noneShadowFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('noneShadowFx');

      // in="none" for feDropShadow produces identity (no shadow, no source)
      expect(passes, hasLength(1));
      expect(passes[0], equals(SvgFilterPaintPass.identity));
    });

    test('feMergeNode with in="none" produces empty layer', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="mergeNoneFx">
      <feMerge>
        <feMergeNode in="none"/>
        <feMergeNode in="SourceGraphic"/>
      </feMerge>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#mergeNoneFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('mergeNoneFx');

      // Only SourceGraphic contributes (in="none" produces empty)
      expect(passes, hasLength(1));
    });

    test('All feMergeNode with in="none" produces identity', () {
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

      // All none -> identity fallback
      expect(passes, hasLength(1));
      expect(passes[0], equals(SvgFilterPaintPass.identity));
    });

    test('feComposite with in2="none" uses only in', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="compositeNoneFx">
      <feOffset dx="5" dy="0" result="offsetted"/>
      <feComposite in="offsetted" in2="none" operator="over"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#compositeNoneFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('compositeNoneFx');

      expect(passes, hasLength(1));
      expect(passes[0].offset, const ui.Offset(5, 0));
    });
  });

  group('feDropShadow with custom in attribute', () {
    test('feDropShadow with in="SourceAlpha"', () {
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

      // Shadow + source (from SourceAlpha)
      expect(passes, hasLength(2));
      expect(passes[0], isA<SvgDropShadowPaintPass>());
    });

    test('feDropShadow with custom named result input', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="shadowNamedFx">
      <feGaussianBlur stdDeviation="1" result="blurred"/>
      <feDropShadow in="blurred" dx="3" dy="3" stdDeviation="2"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#shadowNamedFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('shadowNamedFx');

      // Shadow pass + blurred input pass
      expect(passes, hasLength(2));
      // Shadow should have blur composed from both blur and shadow
      expect(passes[0].imageFilter, isNotNull);
    });
  });

  group('Multiple sequential feDropShadow', () {
    test('Two sequential feDropShadow with implicit inputs', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="doubleShadowFx">
      <feDropShadow dx="2" dy="2" stdDeviation="1" flood-color="black"/>
      <feDropShadow dx="4" dy="4" stdDeviation="2" flood-color="blue"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#doubleShadowFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('doubleShadowFx');

      // First shadow: [shadow1, source]
      // Second shadow applied to [shadow1, source]: [shadow2_of_shadow1, shadow2_of_source, shadow1, source]
      expect(passes, hasLength(4));
    });

    test('Three sequential feDropShadow', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="tripleShadowFx">
      <feDropShadow dx="1" dy="1" stdDeviation="0.5"/>
      <feDropShadow dx="2" dy="2" stdDeviation="1"/>
      <feDropShadow dx="3" dy="3" stdDeviation="1.5"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#tripleShadowFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('tripleShadowFx');

      // Passes grow exponentially: 2 -> 4 -> 8
      expect(passes, hasLength(8));
    });
  });

  group('feMergeNode with named inputs', () {
    test('feMerge with multiple named result references', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="mergeNamedFx">
      <feOffset in="SourceGraphic" dx="2" dy="0" result="offset1"/>
      <feOffset in="SourceGraphic" dx="4" dy="0" result="offset2"/>
      <feOffset in="SourceGraphic" dx="6" dy="0" result="offset3"/>
      <feMerge>
        <feMergeNode in="offset1"/>
        <feMergeNode in="offset2"/>
        <feMergeNode in="offset3"/>
      </feMerge>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#mergeNamedFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('mergeNamedFx');

      expect(passes, hasLength(3));
      // Each offset is applied from SourceGraphic independently
      expect(passes[0].offset, const ui.Offset(2, 0));
      expect(passes[1].offset, const ui.Offset(4, 0));
      expect(passes[2].offset, const ui.Offset(6, 0));
    });

    test('feMerge reusing same named result multiple times', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="mergeReuseFx">
      <feGaussianBlur stdDeviation="2" result="blurred"/>
      <feMerge>
        <feMergeNode in="blurred"/>
        <feMergeNode in="blurred"/>
        <feMergeNode in="SourceGraphic"/>
      </feMerge>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#mergeReuseFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('mergeReuseFx');

      // blurred + blurred + SourceGraphic
      expect(passes, hasLength(3));
      expect(passes[0].imageFilter, isNotNull);
      expect(passes[1].imageFilter, isNotNull);
      expect(passes[2].imageFilter, isNull);
    });
  });

  group('feMerge chaining intermediate results', () {
    test('Chained feMerge referencing another merge result', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="chainedMergeFx">
      <feOffset in="SourceGraphic" dx="1" dy="0" result="a"/>
      <feOffset in="SourceGraphic" dx="2" dy="0" result="b"/>
      <feMerge result="merge1">
        <feMergeNode in="a"/>
        <feMergeNode in="b"/>
      </feMerge>
      <feOffset in="merge1" dx="3" dy="0"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#chainedMergeFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('chainedMergeFx');

      // merge1 has 2 passes (a=1, b=2), offset adds 3 to each
      expect(passes, hasLength(2));
      expect(passes[0].offset, const ui.Offset(4, 0)); // a(1) + 3
      expect(passes[1].offset, const ui.Offset(5, 0)); // b(2) + 3
    });

    test('Two sequential feMerge with cross-references', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="doubleMergeFx">
      <feOffset dx="1" dy="0" result="a"/>
      <feOffset dx="2" dy="0" result="b"/>
      <feMerge result="merge1">
        <feMergeNode in="a"/>
        <feMergeNode in="SourceGraphic"/>
      </feMerge>
      <feMerge>
        <feMergeNode in="merge1"/>
        <feMergeNode in="b"/>
      </feMerge>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#doubleMergeFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('doubleMergeFx');

      // merge1: [a, SourceGraphic] = 2 passes
      // final merge: [merge1(2), b(1)] = 3 passes
      expect(passes, hasLength(3));
    });
  });

  group('Complex multi-node filter graph', () {
    test('Five-node feMerge with different sources', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="fiveNodeMergeFx">
      <feOffset dx="1" dy="0" result="a"/>
      <feGaussianBlur stdDeviation="1" result="b"/>
      <feColorMatrix type="saturate" values="0" result="c"/>
      <feOffset dx="2" dy="0" result="d"/>
      <feMerge>
        <feMergeNode in="a"/>
        <feMergeNode in="b"/>
        <feMergeNode in="c"/>
        <feMergeNode in="d"/>
        <feMergeNode in="SourceGraphic"/>
      </feMerge>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#fiveNodeMergeFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('fiveNodeMergeFx');

      expect(passes, hasLength(5));
    });

    test('Complex graph with branching and merging', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="complexGraphFx">
      <feGaussianBlur stdDeviation="2" result="base"/>
      <feOffset in="base" dx="1" dy="0" result="branch1"/>
      <feColorMatrix in="base" type="saturate" values="0.5" result="branch2"/>
      <feDropShadow in="branch1" dx="2" dy="2" stdDeviation="1" result="shadow"/>
      <feMerge>
        <feMergeNode in="shadow"/>
        <feMergeNode in="branch2"/>
        <feMergeNode in="SourceGraphic"/>
      </feMerge>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#complexGraphFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('complexGraphFx');

      // shadow(2 passes from branch1) + branch2(1) + SourceGraphic(1) = 4
      expect(passes, hasLength(4));
    });
  });

  group('Edge cases', () {
    test('Invalid input name produces empty (transparent black)', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="invalidInputFx">
      <feOffset in="nonExistentResult" dx="5" dy="0"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#invalidInputFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('invalidInputFx');

      // Invalid reference produces identity (fallback)
      expect(passes, hasLength(1));
    });

    test('Forward reference produces empty', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="forwardRefFx">
      <feOffset in="futureResult" dx="5" dy="0"/>
      <feGaussianBlur stdDeviation="2" result="futureResult"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#forwardRefFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('forwardRefFx');

      // Forward reference in first primitive produces empty
      // Final result is from feGaussianBlur
      expect(passes, hasLength(1));
      expect(passes[0].imageFilter, isNotNull);
    });

    test('Circular reference detection produces empty', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="circularFx">
      <feOffset in="self" dx="5" dy="0" result="self"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#circularFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('circularFx');

      // Circular reference detected - should produce identity
      expect(passes, hasLength(1));
    });

    test('Empty feMerge uses previous output', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="emptyMergeFx">
      <feOffset dx="3" dy="0"/>
      <feMerge/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#emptyMergeFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('emptyMergeFx');

      // Empty feMerge falls back to previous (feOffset)
      expect(passes, hasLength(1));
      expect(passes[0].offset, const ui.Offset(3, 0));
    });

    test('Whitespace in input reference is trimmed', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="whitespaceFx">
      <feOffset dx="2" dy="0" result="padded"/>
      <feOffset in="  padded  " dx="3" dy="0"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#whitespaceFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('whitespaceFx');

      expect(passes, hasLength(1));
      expect(passes[0].offset, const ui.Offset(5, 0)); // 2 + 3
    });
  });

  // ===========================================================================
  // Advanced Filter Input-Graph Semantics Tests (Extended Coverage)
  // Additional tests for complex chains, cycle detection, and edge cases.
  // ===========================================================================

  group('Multi-hop chain resolution', () {
    test('Three-hop chain: A -> B -> C references', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="threeHopFx">
      <feOffset dx="1" dy="0" result="a"/>
      <feOffset in="a" dx="2" dy="0" result="b"/>
      <feOffset in="b" dx="3" dy="0" result="c"/>
      <feOffset in="c" dx="4" dy="0"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#threeHopFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('threeHopFx');

      expect(passes, hasLength(1));
      // Cumulative offset: 1 + 2 + 3 + 4 = 10
      expect(passes[0].offset, const ui.Offset(10, 0));
    });

    test('Four-hop chain with branching at hop 2', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="fourHopBranchFx">
      <feOffset dx="1" dy="0" result="base"/>
      <feOffset in="base" dx="2" dy="0" result="branch1"/>
      <feOffset in="base" dx="3" dy="0" result="branch2"/>
      <feMerge>
        <feMergeNode in="branch1"/>
        <feMergeNode in="branch2"/>
      </feMerge>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#fourHopBranchFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('fourHopBranchFx');

      expect(passes, hasLength(2));
      expect(passes[0].offset, const ui.Offset(3, 0)); // base(1) + branch1(2)
      expect(passes[1].offset, const ui.Offset(4, 0)); // base(1) + branch2(3)
    });

    test('Multi-hop with same named result referenced multiple times', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="reuseHopFx">
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
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#reuseHopFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('reuseHopFx');

      expect(passes, hasLength(3));
      // Each use references the same shared blur result
      for (final pass in passes) {
        expect(pass.imageFilter, isNotNull);
      }
    });
  });

  group('Advanced cycle detection', () {
    test('Self-reference in result name produces empty', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="selfRefFx">
      <feOffset in="self" dx="5" dy="0" result="self"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#selfRefFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('selfRefFx');

      // Self-reference detected - produces identity
      expect(passes, hasLength(1));
    });

    test('Forward reference to later primitive produces empty', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="forwardFx">
      <feOffset in="later" dx="1" dy="0" result="early"/>
      <feOffset dx="2" dy="0" result="later"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#forwardFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('forwardFx');

      // Forward reference produces empty for first primitive
      // Second primitive uses implicit previous (which is empty from forward ref)
      // Final result is the second feOffset applied to SourceGraphic (fallback)
      expect(passes, hasLength(1));
      // The offset is applied but forward ref causes empty intermediate
      expect(passes[0].offset, const ui.Offset(2, 0));
    });

    test('Deep chain does not cause stack overflow', () {
      // Build a filter with 50+ primitives in a chain
      final buffer = StringBuffer();
      buffer.writeln('<svg viewBox="0 0 100 100">');
      buffer.writeln('  <defs>');
      buffer.writeln('    <filter id="deepChainFx">');
      buffer.writeln('      <feOffset dx="1" dy="0" result="r0"/>');
      for (int i = 1; i < 50; i++) {
        buffer.writeln(
          '      <feOffset in="r${i - 1}" dx="1" dy="0" result="r$i"/>',
        );
      }
      buffer.writeln('    </filter>');
      buffer.writeln('  </defs>');
      buffer.writeln(
        '  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#deepChainFx)"/>',
      );
      buffer.writeln('</svg>');

      final document = SvgParser.parse(buffer.toString());
      final passes = document.filters!.resolvePaintPasses('deepChainFx');

      expect(passes, hasLength(1));
      expect(passes[0].offset, const ui.Offset(50, 0)); // 50 x 1 offset
    });
  });

  group('FillPaint/StrokePaint advanced scenarios', () {
    test('FillPaint with gradient fill context (simulated)', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="fillGradientFx">
      <feGaussianBlur in="FillPaint" stdDeviation="3" result="blurredFill"/>
      <feMerge>
        <feMergeNode in="blurredFill"/>
        <feMergeNode in="SourceGraphic"/>
      </feMerge>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="url(#grad)" filter="url(#fillGradientFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      // Simulating a gradient fill context
      final passes = document.filters!.resolvePaintPasses(
        'fillGradientFx',
        sourceContext: const SvgFilterSourceContext(
          fillPaint: <SvgFilterPaintPass>[SvgFillPaintSourcePass()],
        ),
      );

      expect(passes, hasLength(2));
      expect(passes[0].imageFilter, isNotNull); // blur applied
    });

    test('StrokePaint combined with offset and blur', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="strokeBlurOffsetFx">
      <feOffset in="StrokePaint" dx="5" dy="5" result="offsetStroke"/>
      <feGaussianBlur in="offsetStroke" stdDeviation="2"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" stroke="red" filter="url(#strokeBlurOffsetFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses(
        'strokeBlurOffsetFx',
        sourceContext: const SvgFilterSourceContext(
          strokePaint: <SvgFilterPaintPass>[
            SvgStrokePaintSourcePass(strokeColor: ui.Color(0xFFFF0000)),
          ],
        ),
      );

      expect(passes, hasLength(1));
      expect(passes[0].offset, const ui.Offset(5, 5));
      expect(passes[0].imageFilter, isNotNull); // blur applied
    });

    test('FillPaint and StrokePaint in same filter with merge', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="fillStrokeMergeFx">
      <feGaussianBlur in="FillPaint" stdDeviation="1" result="blurredFill"/>
      <feOffset in="StrokePaint" dx="2" dy="2" result="offsetStroke"/>
      <feMerge>
        <feMergeNode in="blurredFill"/>
        <feMergeNode in="offsetStroke"/>
        <feMergeNode in="SourceGraphic"/>
      </feMerge>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" stroke="red" filter="url(#fillStrokeMergeFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses(
        'fillStrokeMergeFx',
        sourceContext: const SvgFilterSourceContext(
          fillPaint: <SvgFilterPaintPass>[
            SvgFillPaintSourcePass(fillColor: ui.Color(0xFF0000FF)),
          ],
          strokePaint: <SvgFilterPaintPass>[
            SvgStrokePaintSourcePass(strokeColor: ui.Color(0xFFFF0000)),
          ],
        ),
      );

      // blurredFill + offsetStroke + SourceGraphic = 3 passes
      expect(passes, hasLength(3));
    });
  });

  group('feMerge advanced scenarios', () {
    test('feMerge with 6 nodes from different sources', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="sixNodeMergeFx">
      <feOffset dx="1" dy="0" result="a"/>
      <feOffset dx="2" dy="0" result="b"/>
      <feGaussianBlur stdDeviation="1" result="c"/>
      <feColorMatrix type="saturate" values="0" result="d"/>
      <feOffset dx="3" dy="0" result="e"/>
      <feMerge>
        <feMergeNode in="a"/>
        <feMergeNode in="b"/>
        <feMergeNode in="c"/>
        <feMergeNode in="d"/>
        <feMergeNode in="e"/>
        <feMergeNode in="SourceGraphic"/>
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

    test('feMerge with mix of valid, invalid, and none inputs', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="mixedMergeFx">
      <feOffset dx="1" dy="0" result="valid"/>
      <feMerge>
        <feMergeNode in="valid"/>
        <feMergeNode in="nonExistent"/>
        <feMergeNode in="none"/>
        <feMergeNode in="SourceGraphic"/>
      </feMerge>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#mixedMergeFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('mixedMergeFx');

      // valid + SourceGraphic = 2 (nonExistent and none produce empty)
      expect(passes, hasLength(2));
    });

    test('Nested feMerge references another merge result', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="nestedMergeFx">
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
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#nestedMergeFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('nestedMergeFx');

      // merge1 has 2 passes (a, b)
      // c uses previous (which is merge1 with 2 passes), so c becomes 2 passes with offset 3
      // final merge: merge1(2) + c(2) = 4 passes total
      expect(passes, hasLength(4));
    });

    test('feMerge with implicit previous as input (no in attr)', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="implicitMergeFx">
      <feOffset dx="5" dy="0"/>
      <feMerge>
        <feMergeNode/>
        <feMergeNode in="SourceGraphic"/>
      </feMerge>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#implicitMergeFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('implicitMergeFx');

      // First node uses previous (feOffset), second uses SourceGraphic
      expect(passes, hasLength(2));
      expect(passes[0].offset, const ui.Offset(5, 0));
    });
  });

  group('feDropShadow asymmetric blur', () {
    test('feDropShadow with stdDeviation X different from Y', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="asymBlurShadowFx">
      <feDropShadow dx="4" dy="4" stdDeviation="2 4"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#asymBlurShadowFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('asymBlurShadowFx');

      // Shadow + source = 2 passes
      expect(passes, hasLength(2));
      expect(passes[0], isA<SvgDropShadowPaintPass>());
    });

    test('feDropShadow with zero stdDeviation still applies offset', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="noBlurShadowFx">
      <feDropShadow dx="3" dy="3" stdDeviation="0"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#noBlurShadowFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('noBlurShadowFx');

      expect(passes, hasLength(2));
      expect(passes[0].offset, const ui.Offset(3, 3));
    });

    test('feDropShadow with flood-color and flood-opacity', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="coloredShadowFx">
      <feDropShadow dx="2" dy="2" stdDeviation="1" flood-color="red" flood-opacity="0.5"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#coloredShadowFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('coloredShadowFx');

      expect(passes, hasLength(2));
      final shadowPass = passes[0] as SvgDropShadowPaintPass;
      expect(shadowPass.colorFilter, isNotNull);
    });

    test('feDropShadow with custom input to named result', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="shadowOnFilteredFx">
      <feGaussianBlur stdDeviation="1" result="preBlurred"/>
      <feDropShadow in="preBlurred" dx="5" dy="5" stdDeviation="2"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#shadowOnFilteredFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('shadowOnFilteredFx');

      // Shadow applied to pre-blurred input + pre-blurred input
      expect(passes, hasLength(2));
    });
  });

  group('BackgroundImage/BackgroundAlpha inputs', () {
    test('BackgroundImage as filter input', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="bgImageFx">
      <feGaussianBlur in="BackgroundImage" stdDeviation="2"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#bgImageFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses(
        'bgImageFx',
        sourceContext: const SvgFilterSourceContext(
          backgroundImage: <SvgFilterPaintPass>[
            SvgFilterPaintPass(
              colorFilter: ui.ColorFilter.mode(
                ui.Color(0xFF00FF00),
                ui.BlendMode.srcIn,
              ),
            ),
          ],
        ),
      );

      expect(passes, hasLength(1));
      expect(passes[0].imageFilter, isNotNull);
    });

    test('BackgroundAlpha as filter input', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="bgAlphaFx">
      <feOffset in="BackgroundAlpha" dx="3" dy="3"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#bgAlphaFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses(
        'bgAlphaFx',
        sourceContext: const SvgFilterSourceContext(
          backgroundAlpha: <SvgFilterPaintPass>[
            SvgFilterPaintPass(
              colorFilter: ui.ColorFilter.mode(
                ui.Color(0xFFFFFFFF),
                ui.BlendMode.srcIn,
              ),
            ),
          ],
        ),
      );

      expect(passes, hasLength(1));
      expect(passes[0].offset, const ui.Offset(3, 3));
    });

    test('Case-insensitive background input references', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="bgCaseFx">
      <feMerge>
        <feMergeNode in="backgroundimage"/>
        <feMergeNode in="backgroundalpha"/>
      </feMerge>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#bgCaseFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('bgCaseFx');

      // Both should resolve (to SourceGraphic fallback without context)
      expect(passes, hasLength(2));
    });
  });

  group('feComposite advanced', () {
    test('feComposite arithmetic with k1=1 (multiply)', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="arithmeticMultFx">
      <feOffset dx="2" dy="0" result="a"/>
      <feOffset dx="3" dy="0" result="b"/>
      <feComposite in="a" in2="b" operator="arithmetic" k1="1" k2="0" k3="0" k4="0"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#arithmeticMultFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('arithmeticMultFx');

      expect(passes.isNotEmpty, isTrue);
    });

    test('feComposite arithmetic with all zeros produces empty', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="arithmeticZeroFx">
      <feComposite operator="arithmetic" k1="0" k2="0" k3="0" k4="0"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#arithmeticZeroFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('arithmeticZeroFx');

      // All-zero coefficients should produce identity fallback
      expect(passes, hasLength(1));
    });
  });

  group('Complex real-world filter scenarios', () {
    test('Glow effect: blur + merge with source', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="glowFx">
      <feGaussianBlur in="SourceAlpha" stdDeviation="3" result="blur"/>
      <feFlood flood-color="yellow" flood-opacity="0.8" result="color"/>
      <feComposite in="color" in2="blur" operator="in" result="glow"/>
      <feMerge>
        <feMergeNode in="glow"/>
        <feMergeNode in="SourceGraphic"/>
      </feMerge>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#glowFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('glowFx');

      // glow is composite result, SourceGraphic is 1, merged together
      // The actual number depends on composite result structure
      expect(passes.isNotEmpty, isTrue);
    });

    test('Emboss effect: multiple offsets and blend', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="embossFx">
      <feOffset in="SourceAlpha" dx="-1" dy="-1" result="light"/>
      <feOffset in="SourceAlpha" dx="1" dy="1" result="dark"/>
      <feFlood flood-color="white" flood-opacity="0.5" result="lightColor"/>
      <feFlood flood-color="black" flood-opacity="0.5" result="darkColor"/>
      <feComposite in="lightColor" in2="light" operator="in" result="lightEmboss"/>
      <feComposite in="darkColor" in2="dark" operator="in" result="darkEmboss"/>
      <feMerge>
        <feMergeNode in="lightEmboss"/>
        <feMergeNode in="darkEmboss"/>
        <feMergeNode in="SourceGraphic"/>
      </feMerge>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#embossFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('embossFx');

      // Each composite merges flood + offset, resulting in layered passes
      // The actual count depends on implementation details
      expect(passes.isNotEmpty, isTrue);
    });

    test('Complex shadow with blur and color transformation', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="complexShadowFx">
      <feDropShadow dx="3" dy="3" stdDeviation="2" flood-color="#333" result="shadow1"/>
      <feColorMatrix in="shadow1" type="saturate" values="0" result="grayShadow"/>
      <feMerge>
        <feMergeNode in="grayShadow"/>
        <feMergeNode in="SourceGraphic"/>
      </feMerge>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#complexShadowFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('complexShadowFx');

      // shadow1 is 2 passes, colorMatrix applies to each, merge selects grayShadow(2) + Source(1)
      expect(passes.isNotEmpty, isTrue);
    });
  });
}
