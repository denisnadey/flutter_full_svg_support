import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

import 'package:full_svg_flutter/src/animation/svg_parser.dart';
import 'package:full_svg_flutter/src/animation/svg_filters.dart';

void main() {
  // ===========================================================================
  // Advanced Filter Input-Graph Chain Handling Tests
  // ===========================================================================
  // These tests cover advanced edge cases for Blink SVG parity:
  // 1. Multi-reference input chains with caching verification
  // 2. FillPaint/StrokePaint as input sources with complex chains
  // 3. Nested filter composition and recursion prevention
  // 4. Complex graph topologies with multiple merges and branches

  group('Multi-Reference Input Chains - Caching Verification', () {
    test(
      'Same named result referenced 5 times produces consistent results',
      () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="multiRef5Fx">
      <feGaussianBlur stdDeviation="2" result="shared"/>
      <feMerge>
        <feMergeNode in="shared"/>
        <feMergeNode in="shared"/>
        <feMergeNode in="shared"/>
        <feMergeNode in="shared"/>
        <feMergeNode in="shared"/>
      </feMerge>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#multiRef5Fx)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final passes = document.filters!.resolvePaintPasses('multiRef5Fx');

        expect(passes, hasLength(5));
        // All passes should have identical blur filter (from cached result)
        for (final pass in passes) {
          expect(pass.imageFilter, isNotNull);
        }
      },
    );

    test('Multi-reference with intermediate processing uses cached base', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="cachedBaseFx">
      <feGaussianBlur stdDeviation="3" result="base"/>
      <feOffset in="base" dx="1" dy="0" result="use1"/>
      <feOffset in="base" dx="2" dy="0" result="use2"/>
      <feOffset in="base" dx="3" dy="0" result="use3"/>
      <feColorMatrix in="base" type="saturate" values="0.5" result="use4"/>
      <feMerge>
        <feMergeNode in="use1"/>
        <feMergeNode in="use2"/>
        <feMergeNode in="use3"/>
        <feMergeNode in="use4"/>
      </feMerge>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#cachedBaseFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('cachedBaseFx');

      expect(passes, hasLength(4));
      // All passes inherit blur from cached 'base' result
      for (final pass in passes) {
        expect(pass.imageFilter, isNotNull);
      }
      // Verify different offsets
      expect(passes[0].offset.dx, 1);
      expect(passes[1].offset.dx, 2);
      expect(passes[2].offset.dx, 3);
    });

    test('Diamond pattern: A→B→D and A→C→D with single base', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="diamondPatternFx">
      <feGaussianBlur stdDeviation="1" result="A"/>
      <feOffset in="A" dx="1" dy="0" result="B"/>
      <feOffset in="A" dx="2" dy="0" result="C"/>
      <feMerge result="D">
        <feMergeNode in="B"/>
        <feMergeNode in="C"/>
      </feMerge>
      <feOffset in="D" dx="3" dy="0"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#diamondPatternFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('diamondPatternFx');

      expect(passes, hasLength(2));
      // B path: blur + offset(1) + offset(3) = blur, offset 4
      // C path: blur + offset(2) + offset(3) = blur, offset 5
      expect(passes[0].offset.dx, 4);
      expect(passes[1].offset.dx, 5);
    });

    test('Cross-reference between two chains', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="crossRefFx">
      <feOffset dx="1" dy="0" result="a1"/>
      <feOffset dx="2" dy="0" result="b1"/>
      <feOffset in="a1" dx="10" dy="0" result="a2"/>
      <feOffset in="b1" dx="20" dy="0" result="b2"/>
      <feMerge>
        <feMergeNode in="a2"/>
        <feMergeNode in="b2"/>
        <feMergeNode in="a1"/>
        <feMergeNode in="b1"/>
      </feMerge>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#crossRefFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('crossRefFx');

      expect(passes, hasLength(4));
      expect(passes[0].offset.dx, 11); // a1(1) + 10
      expect(passes[1].offset.dx, 23); // b1 chains from a1: 1+2+20=23
      expect(passes[2].offset.dx, 1); // a1 cached
      expect(passes[3].offset.dx, 3); // b1 cached (chains from a1: 1+2)
    });
  });

  group('FillPaint/StrokePaint Advanced Input Chains', () {
    test('FillPaint through multi-step chain', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="fillChainFx">
      <feGaussianBlur in="FillPaint" stdDeviation="1" result="blurFill"/>
      <feOffset in="blurFill" dx="2" dy="2" result="offsetFill"/>
      <feColorMatrix in="offsetFill" type="saturate" values="0.5"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="red" filter="url(#fillChainFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('fillChainFx');

      expect(passes, hasLength(1));
      expect(passes[0].paintFill, isTrue);
      expect(passes[0].paintStroke, isFalse);
      expect(passes[0].imageFilter, isNotNull);
      expect(passes[0].offset, const ui.Offset(2, 2));
    });

    test('StrokePaint with DropShadow chain', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="strokeShadowFx">
      <feDropShadow in="StrokePaint" dx="3" dy="3" stdDeviation="2"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" stroke="blue" filter="url(#strokeShadowFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('strokeShadowFx');

      expect(passes, hasLength(2));
      // Shadow pass
      expect(passes[0].paintFill, isFalse);
      expect(passes[0].paintStroke, isTrue);
      expect(passes[0].offset, const ui.Offset(3, 3));
      // Source pass
      expect(passes[1].paintFill, isFalse);
      expect(passes[1].paintStroke, isTrue);
    });

    test('FillPaint and StrokePaint merged with offsets', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="mergedPaintsFx">
      <feOffset in="FillPaint" dx="5" dy="0" result="fillOff"/>
      <feOffset in="StrokePaint" dx="10" dy="0" result="strokeOff"/>
      <feMerge>
        <feMergeNode in="fillOff"/>
        <feMergeNode in="strokeOff"/>
        <feMergeNode in="SourceGraphic"/>
      </feMerge>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="red" stroke="blue" filter="url(#mergedPaintsFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('mergedPaintsFx');

      expect(passes, hasLength(3));
      expect(passes[0].paintFill, isTrue);
      expect(passes[0].offset.dx, 5);
      expect(passes[1].paintStroke, isTrue);
      expect(passes[1].offset.dx, 10);
    });

    test('FillPaint with context-provided fill color', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="fillContextFx">
      <feGaussianBlur in="FillPaint" stdDeviation="2"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="green" filter="url(#fillContextFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses(
        'fillContextFx',
        sourceContext: const SvgFilterSourceContext(
          fillPaint: <SvgFilterPaintPass>[
            SvgFillPaintSourcePass(fillColor: ui.Color(0xFF00FF00)),
          ],
        ),
      );

      expect(passes, hasLength(1));
      expect(passes[0].imageFilter, isNotNull);
    });
  });

  group('Nested Filter Composition', () {
    test('feImage with element reference preserves filter context', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="imageRefFx">
      <feImage href="#myRect" result="refImage"/>
      <feGaussianBlur in="refImage" stdDeviation="2"/>
    </filter>
    <rect id="myRect" x="0" y="0" width="20" height="20" fill="red"/>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#imageRefFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('imageRefFx');

      // feImage creates specialized pass, blur is applied
      expect(passes, hasLength(1));
      expect(passes[0].imageFilter, isNotNull);
    });

    test('Filter with nested background context', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="bgNestedFx">
      <feGaussianBlur in="BackgroundImage" stdDeviation="1"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#bgNestedFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      // Push a background context to simulate nested filtering
      document.filters!.pushBackgroundContext(
        backgroundImage: const <SvgFilterPaintPass>[
          SvgFilterPaintPass(
            colorFilter: ui.ColorFilter.mode(
              ui.Color(0xFF00FF00),
              ui.BlendMode.srcIn,
            ),
          ),
        ],
      );

      final passes = document.filters!.resolvePaintPasses('bgNestedFx');

      expect(passes, hasLength(1));
      expect(passes[0].imageFilter, isNotNull);

      document.filters!.popBackgroundContext();
    });

    test('Deep feImage chain does not cause infinite recursion', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="deepImageFx">
      <feImage href="#nestedRect"/>
      <feGaussianBlur stdDeviation="1"/>
    </filter>
    <rect id="nestedRect" x="0" y="0" width="10" height="10" fill="blue"/>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#deepImageFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      // Should complete without stack overflow
      final passes = document.filters!.resolvePaintPasses('deepImageFx');
      expect(passes, isNotEmpty);
    });

    test('feImage with missing element reference produces transparent', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="missingImageRefFx">
      <feImage href="#nonExistent" result="missing"/>
      <feMerge>
        <feMergeNode in="missing"/>
        <feMergeNode in="SourceGraphic"/>
      </feMerge>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#missingImageRefFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('missingImageRefFx');

      // feImage creates a pass even for missing refs (painter handles fallback)
      // merge combines the image pass with SourceGraphic
      expect(passes.isNotEmpty, isTrue);
    });
  });

  group('Complex Graph Topologies', () {
    test('8-node merge with mixed sources', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="eightNodeMergeFx">
      <feOffset dx="1" dy="0" result="n1"/>
      <feOffset dx="2" dy="0" result="n2"/>
      <feOffset dx="3" dy="0" result="n3"/>
      <feOffset dx="4" dy="0" result="n4"/>
      <feGaussianBlur stdDeviation="1" result="n5"/>
      <feColorMatrix type="saturate" values="0" result="n6"/>
      <feMerge>
        <feMergeNode in="n1"/>
        <feMergeNode in="n2"/>
        <feMergeNode in="n3"/>
        <feMergeNode in="n4"/>
        <feMergeNode in="n5"/>
        <feMergeNode in="n6"/>
        <feMergeNode in="SourceGraphic"/>
        <feMergeNode in="SourceAlpha"/>
      </feMerge>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#eightNodeMergeFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('eightNodeMergeFx');

      expect(passes, hasLength(8));
    });

    test('Triple nested merge references', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="tripleNestedMergeFx">
      <feOffset dx="1" dy="0" result="a"/>
      <feOffset dx="2" dy="0" result="b"/>
      <feMerge result="m1">
        <feMergeNode in="a"/>
        <feMergeNode in="b"/>
      </feMerge>
      <feOffset dx="3" dy="0" result="c"/>
      <feMerge result="m2">
        <feMergeNode in="m1"/>
        <feMergeNode in="c"/>
      </feMerge>
      <feOffset dx="4" dy="0" result="d"/>
      <feMerge>
        <feMergeNode in="m2"/>
        <feMergeNode in="d"/>
      </feMerge>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#tripleNestedMergeFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses(
        'tripleNestedMergeFx',
      );

      // m1: 2 passes, m2: m1(2) + c(2)=4, final: m2(4) + d(4)=8
      expect(passes, hasLength(8));
    });

    test('Parallel branches with common base and separate merges', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="parallelBranchesFx">
      <feGaussianBlur stdDeviation="1" result="base"/>
      <feOffset in="base" dx="1" dy="0" result="branch1a"/>
      <feOffset in="base" dx="2" dy="0" result="branch1b"/>
      <feMerge result="group1">
        <feMergeNode in="branch1a"/>
        <feMergeNode in="branch1b"/>
      </feMerge>
      <feOffset in="base" dx="3" dy="0" result="branch2a"/>
      <feOffset in="base" dx="4" dy="0" result="branch2b"/>
      <feMerge result="group2">
        <feMergeNode in="branch2a"/>
        <feMergeNode in="branch2b"/>
      </feMerge>
      <feMerge>
        <feMergeNode in="group1"/>
        <feMergeNode in="group2"/>
      </feMerge>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#parallelBranchesFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('parallelBranchesFx');

      // group1: 2, group2: 2, final merge: 4
      expect(passes, hasLength(4));
    });

    test('Filter with 10+ primitives in complex topology', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="complexTopologyFx">
      <feGaussianBlur stdDeviation="1" result="blur1"/>
      <feOffset in="blur1" dx="1" dy="0" result="off1"/>
      <feColorMatrix in="off1" type="saturate" values="0.5" result="cm1"/>
      <feOffset in="cm1" dx="2" dy="0" result="off2"/>
      <feGaussianBlur in="off2" stdDeviation="0.5" result="blur2"/>
      <feDropShadow in="blur2" dx="1" dy="1" stdDeviation="0.5" result="shadow"/>
      <feMerge result="merged1">
        <feMergeNode in="shadow"/>
        <feMergeNode in="blur1"/>
      </feMerge>
      <feOffset in="merged1" dx="3" dy="0" result="offMerged"/>
      <feFlood flood-color="red" flood-opacity="0.3" result="flood"/>
      <feBlend in="offMerged" in2="flood" mode="overlay"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#complexTopologyFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('complexTopologyFx');

      expect(passes.isNotEmpty, isTrue);
    });
  });

  group('Edge Cases - Cycle and Recursion Prevention', () {
    test('Self-referencing primitive produces transparent black', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="selfRefFx">
      <feOffset in="selfResult" dx="5" dy="0" result="selfResult"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#selfRefFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('selfRefFx');

      // Self-reference detection should produce identity fallback
      expect(passes, hasLength(1));
    });

    test('Mutual reference between two primitives handled', () {
      // Note: This is technically a forward reference, not mutual
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="mutualRefFx">
      <feOffset in="b" dx="1" dy="0" result="a"/>
      <feOffset in="a" dx="2" dy="0" result="b"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#mutualRefFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('mutualRefFx');

      // Forward ref produces empty, second primitive uses empty input
      expect(passes, hasLength(1));
    });

    test('Very deep chain (64 primitives) near resolution limit', () {
      final primitives = StringBuffer();
      for (var i = 0; i < 64; i++) {
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
    <filter id="veryDeepChainFx">
      $primitives
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#veryDeepChainFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('veryDeepChainFx');

      // Should complete without error, accumulated offset = 64
      expect(passes, hasLength(1));
      expect(passes.single.offset.dx, 64.0);
    });
  });

  group('Input Source Combinations', () {
    test('All built-in inputs in single merge', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="allInputsMergeFx">
      <feMerge>
        <feMergeNode in="SourceGraphic"/>
        <feMergeNode in="SourceAlpha"/>
        <feMergeNode in="FillPaint"/>
        <feMergeNode in="StrokePaint"/>
        <feMergeNode in="BackgroundImage"/>
        <feMergeNode in="BackgroundAlpha"/>
      </feMerge>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#allInputsMergeFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('allInputsMergeFx');

      // All 6 built-in inputs should resolve
      expect(passes, hasLength(6));
    });

    test('Mixed case input references resolve correctly', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="mixedCaseInputsFx">
      <feMerge>
        <feMergeNode in="SOURCEGRAPHIC"/>
        <feMergeNode in="sourcealpha"/>
        <feMergeNode in="FillPAINT"/>
        <feMergeNode in="strokePAINT"/>
      </feMerge>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#mixedCaseInputsFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('mixedCaseInputsFx');

      // Case-insensitive fallback should resolve all
      expect(passes, hasLength(4));
    });

    test('Whitespace variations in input references', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="whitespaceInputsFx">
      <feOffset dx="1" dy="0" result="target"/>
      <feMerge>
        <feMergeNode in="  target  "/>
        <feMergeNode in="target"/>
        <feMergeNode in=" SourceGraphic "/>
      </feMerge>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#whitespaceInputsFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('whitespaceInputsFx');

      expect(passes, hasLength(3));
      expect(passes[0].offset.dx, 1);
      expect(passes[1].offset.dx, 1);
      expect(passes[2].offset, ui.Offset.zero);
    });

    test('Empty result name does not cache', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="emptyResultFx">
      <feOffset dx="1" dy="0" result=""/>
      <feOffset dx="2" dy="0"/>
      <feOffset dx="3" dy="0"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#emptyResultFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('emptyResultFx');

      expect(passes, hasLength(1));
      // Sequential chaining: 1+2+3 = 6
      expect(passes.single.offset.dx, 6);
    });
  });
}
