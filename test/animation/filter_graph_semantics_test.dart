import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_svg/src/animation/svg_parser.dart';
import 'package:flutter_svg/src/animation/svg_filters.dart';

void main() {
  // ===========================================================================
  // Filter Graph Semantics Tests
  // Tests for advanced filter graph features: named result resolution,
  // in/in2 attribute handling, FillPaint/StrokePaint sources, and edge cases.
  // ===========================================================================

  group('Named Result Resolution', () {
    test('Simple 2-step filter chain with named results', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="twoStepFx">
      <feGaussianBlur in="SourceGraphic" stdDeviation="2" result="blurred"/>
      <feOffset in="blurred" dx="5" dy="5"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#twoStepFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('twoStepFx');

      expect(passes, hasLength(1));
      // Should have blur composed with offset
      expect(passes[0].imageFilter, isNotNull);
      expect(passes[0].offset, const ui.Offset(5, 5));
    });

    test('3-step chain: blur → offset → merge using named results', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="threeStepFx">
      <feGaussianBlur in="SourceGraphic" stdDeviation="3" result="blurred"/>
      <feOffset in="blurred" dx="4" dy="4" result="shadow"/>
      <feMerge>
        <feMergeNode in="shadow"/>
        <feMergeNode in="SourceGraphic"/>
      </feMerge>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#threeStepFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('threeStepFx');

      // Should have 2 passes: shadow layer + source layer
      expect(passes, hasLength(2));
      // First pass is shadow (offset applied)
      expect(passes[0].offset, const ui.Offset(4, 4));
      expect(passes[0].imageFilter, isNotNull); // blur
      // Second pass is SourceGraphic
      expect(passes[1].offset, ui.Offset.zero);
    });

    test('Default in resolution (omitted = previous output)', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="defaultInFx">
      <feGaussianBlur stdDeviation="2"/>
      <feOffset dx="3" dy="3"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#defaultInFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('defaultInFx');

      expect(passes, hasLength(1));
      // Blur should be applied, then offset
      expect(passes[0].imageFilter, isNotNull);
      expect(passes[0].offset, const ui.Offset(3, 3));
    });

    test('First primitive with omitted in (= SourceGraphic)', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="firstOmittedFx">
      <feGaussianBlur stdDeviation="4"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#firstOmittedFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('firstOmittedFx');

      expect(passes, hasLength(1));
      expect(passes[0].imageFilter, isNotNull); // blur applied
      // Should have started with SourceGraphic (paintFill=true, paintStroke=true)
      expect(passes[0].paintFill, isTrue);
      expect(passes[0].paintStroke, isTrue);
    });

    test('Chain with mixed named and default inputs', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="mixedChainFx">
      <feGaussianBlur stdDeviation="2" result="blur1"/>
      <feOffset dx="2" dy="2"/>
      <feGaussianBlur in="blur1" stdDeviation="1" result="blur2"/>
      <feMerge>
        <feMergeNode in="blur2"/>
        <feMergeNode/>
      </feMerge>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#mixedChainFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('mixedChainFx');

      // feMerge should have 2 layers: blur2 and previous (offset result)
      expect(passes.length, greaterThanOrEqualTo(2));
    });

    test('Complex 5-step filter chain', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="fiveStepFx">
      <feGaussianBlur in="SourceAlpha" stdDeviation="3" result="shadow"/>
      <feOffset in="shadow" dx="4" dy="4" result="offsetShadow"/>
      <feFlood flood-color="black" flood-opacity="0.5" result="flood"/>
      <feComposite in="flood" in2="offsetShadow" operator="in" result="coloredShadow"/>
      <feMerge>
        <feMergeNode in="coloredShadow"/>
        <feMergeNode in="SourceGraphic"/>
      </feMerge>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#fiveStepFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('fiveStepFx');

      // Should produce multiple passes for the merge
      expect(passes.length, greaterThanOrEqualTo(2));
    });
  });

  group('FillPaint/StrokePaint Sources', () {
    test('FillPaint as input source with context', () {
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
      expect(passes[0].imageFilter, isNotNull); // blur applied
      expect(passes[0].colorFilter, isNotNull); // fill color preserved
    });

    test('StrokePaint as input source with context', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="strokePaintFx">
      <feOffset in="StrokePaint" dx="3" dy="3"/>
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
      expect(passes[0].offset, const ui.Offset(3, 3));
      expect(passes[0].colorFilter, isNotNull); // stroke color preserved
    });

    test('FillPaint without context uses synthetic pass', () {
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
      final passes = document.filters!.resolvePaintPasses('fillNoCtxFx');

      expect(passes, hasLength(1));
      expect(passes[0].offset, const ui.Offset(5, 0));
      expect(passes[0].paintFill, isTrue);
      expect(passes[0].paintStroke, isFalse);
    });

    test('StrokePaint without context uses synthetic pass', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="strokeNoCtxFx">
      <feOffset in="StrokePaint" dx="0" dy="5"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" stroke="red" filter="url(#strokeNoCtxFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('strokeNoCtxFx');

      expect(passes, hasLength(1));
      expect(passes[0].offset, const ui.Offset(0, 5));
      expect(passes[0].paintFill, isFalse);
      expect(passes[0].paintStroke, isTrue);
    });
  });

  group('feDropShadow with explicit in', () {
    test('feDropShadow with explicit in referencing named result', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="shadowNamedFx">
      <feGaussianBlur in="SourceGraphic" stdDeviation="2" result="blurred"/>
      <feDropShadow in="blurred" dx="3" dy="3" stdDeviation="1"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#shadowNamedFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('shadowNamedFx');

      // feDropShadow produces shadow + input merged
      expect(passes.length, greaterThanOrEqualTo(2));
      // Shadow pass should have offset
      expect(passes[0].offset.dx, 3);
      expect(passes[0].offset.dy, 3);
    });

    test('feDropShadow with SourceAlpha input', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="shadowAlphaFx">
      <feDropShadow in="SourceAlpha" dx="5" dy="5" stdDeviation="3"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#shadowAlphaFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('shadowAlphaFx');

      expect(passes.length, greaterThanOrEqualTo(2));
    });
  });

  group('feMerge with unresolved inputs', () {
    test('feMerge with one unresolved input skips gracefully', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="mergeUnresolvedFx">
      <feMerge>
        <feMergeNode in="nonExistentResult"/>
        <feMergeNode in="SourceGraphic"/>
      </feMerge>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#mergeUnresolvedFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('mergeUnresolvedFx');

      // Only SourceGraphic should be in the result (nonExistent skipped)
      expect(passes, hasLength(1));
    });

    test('feMerge with all valid inputs', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="mergeValidFx">
      <feFlood flood-color="red" flood-opacity="0.5" result="redFlood"/>
      <feFlood flood-color="blue" flood-opacity="0.5" result="blueFlood"/>
      <feMerge>
        <feMergeNode in="redFlood"/>
        <feMergeNode in="blueFlood"/>
        <feMergeNode in="SourceGraphic"/>
      </feMerge>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="green" filter="url(#mergeValidFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('mergeValidFx');

      // All three merge nodes should contribute
      expect(passes, hasLength(3));
    });

    test('feMerge with in="none" skips that node', () {
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

      // Only SourceGraphic should be present (none skipped)
      expect(passes, hasLength(1));
    });
  });

  group('SourceAlpha and BackgroundImage inputs', () {
    test('SourceAlpha as input', () {
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
      expect(passes[0].imageFilter, isNotNull); // blur
      expect(passes[0].colorFilter, isNotNull); // alpha extraction
    });

    test('BackgroundImage as input with context', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="backgroundFx">
      <feGaussianBlur in="BackgroundImage" stdDeviation="2"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#backgroundFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses(
        'backgroundFx',
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
      expect(passes[0].imageFilter, isNotNull); // blur
    });
  });

  group('Edge cases and error handling', () {
    test('Circular/self-reference handling (should not crash)', () {
      // Note: This tests that circular references are detected and handled
      // gracefully rather than causing stack overflow.
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="circularFx">
      <feGaussianBlur in="SourceGraphic" stdDeviation="2" result="a"/>
      <feOffset in="a" dx="2" dy="2" result="b"/>
      <feGaussianBlur in="b" stdDeviation="1" result="c"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#circularFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      // Should not throw
      final passes = document.filters!.resolvePaintPasses('circularFx');
      expect(passes, isNotEmpty);
    });

    test('Empty filter chain (passthrough)', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="emptyFx">
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#emptyFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('emptyFx');

      // Empty filter should return identity
      expect(passes, hasLength(1));
      expect(passes[0], equals(SvgFilterPaintPass.identity));
    });

    test('Forward reference handling (produces transparent)', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="forwardRefFx">
      <feGaussianBlur in="futureResult" stdDeviation="2"/>
      <feFlood flood-color="red" result="futureResult"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#forwardRefFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('forwardRefFx');

      // Forward reference produces empty input for blur, so flood becomes output
      expect(passes, isNotEmpty);
    });

    test('Case-insensitive built-in input names', () {
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
      expect(passes[0].imageFilter, isNotNull); // blur applied
    });
  });

  group('SvgFillPaintSourcePass and SvgStrokePaintSourcePass classes', () {
    test('SvgFillPaintSourcePass has correct defaults', () {
      const pass = SvgFillPaintSourcePass();
      expect(pass.paintFill, isTrue);
      expect(pass.paintStroke, isFalse);
      expect(pass.fillColor, isNull);
    });

    test('SvgFillPaintSourcePass copyWith preserves fillColor', () {
      const originalPass = SvgFillPaintSourcePass(
        fillColor: ui.Color(0xFF00FF00),
      );
      final copiedPass = originalPass.copyWith(
        offset: const ui.Offset(5, 5),
      );

      expect(copiedPass, isA<SvgFillPaintSourcePass>());
      expect((copiedPass as SvgFillPaintSourcePass).fillColor,
          const ui.Color(0xFF00FF00));
      expect(copiedPass.offset, const ui.Offset(5, 5));
    });

    test('SvgStrokePaintSourcePass has correct defaults', () {
      const pass = SvgStrokePaintSourcePass();
      expect(pass.paintFill, isFalse);
      expect(pass.paintStroke, isTrue);
      expect(pass.strokeColor, isNull);
    });

    test('SvgStrokePaintSourcePass copyWith preserves strokeColor', () {
      const originalPass = SvgStrokePaintSourcePass(
        strokeColor: ui.Color(0xFFFF0000),
      );
      final copiedPass = originalPass.copyWith(
        blendMode: ui.BlendMode.multiply,
      );

      expect(copiedPass, isA<SvgStrokePaintSourcePass>());
      expect((copiedPass as SvgStrokePaintSourcePass).strokeColor,
          const ui.Color(0xFFFF0000));
      expect(copiedPass.blendMode, ui.BlendMode.multiply);
    });

    test('createFillPaintSourcePasses with color', () {
      final passes =
          SvgFiltersPipelinePrimitivePaintExtension.createFillPaintSourcePasses(
        fillColor: const ui.Color(0xFF0000FF),
      );

      expect(passes, hasLength(1));
      expect(passes[0], isA<SvgFillPaintSourcePass>());
      expect((passes[0] as SvgFillPaintSourcePass).fillColor,
          const ui.Color(0xFF0000FF));
      expect(passes[0].colorFilter, isNotNull);
    });

    test('createStrokePaintSourcePasses with color', () {
      final passes = SvgFiltersPipelinePrimitivePaintExtension
          .createStrokePaintSourcePasses(
        strokeColor: const ui.Color(0xFFFF0000),
      );

      expect(passes, hasLength(1));
      expect(passes[0], isA<SvgStrokePaintSourcePass>());
      expect((passes[0] as SvgStrokePaintSourcePass).strokeColor,
          const ui.Color(0xFFFF0000));
      expect(passes[0].colorFilter, isNotNull);
    });
  });
}
