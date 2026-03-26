import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_svg/src/animation/svg_parser.dart';
import 'package:flutter_svg/src/animation/svg_filters.dart';

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
}
