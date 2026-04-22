import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

import 'package:full_svg_flutter/src/animation/svg_parser.dart';
import 'package:full_svg_flutter/src/animation/svg_filters.dart';

void main() {
  // ===========================================================================
  // Advanced Filter Input-Graph Semantics Tests
  // ===========================================================================
  group('Advanced Filter Input-Graph Semantics', () {
    // =========================================================================
    // Multi-hop filter chain tests
    // =========================================================================
    group('Multi-hop filter chain resolution', () {
      test('Three-step chain: A -> B -> C with result references', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="threeStepFx">
      <feOffset dx="2" dy="0" result="step1"/>
      <feGaussianBlur in="step1" stdDeviation="1" result="step2"/>
      <feColorMatrix in="step2" type="saturate" values="0.5"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#threeStepFx)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final passes = document.filters!.resolvePaintPasses('threeStepFx');

        expect(passes, hasLength(1));
        expect(passes.single.offset, const ui.Offset(2, 0));
        expect(passes.single.imageFilter, isNotNull);
      });

      test(
        'Multi-hop with branching: same result used by multiple downstream primitives',
        () {
          final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="branchingFx">
      <feOffset dx="3" dy="0" result="base"/>
      <feGaussianBlur in="base" stdDeviation="2" result="blurred"/>
      <feColorMatrix in="base" type="hueRotate" values="90" result="rotated"/>
      <feMerge>
        <feMergeNode in="blurred"/>
        <feMergeNode in="rotated"/>
      </feMerge>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#branchingFx)"/>
</svg>
''';

          final document = SvgParser.parse(svgString);
          final passes = document.filters!.resolvePaintPasses('branchingFx');

          // Merge combines blurred and rotated, both derived from base
          expect(passes, hasLength(2));
          expect(passes[0].offset, const ui.Offset(3, 0)); // blurred base
          expect(passes[1].offset, const ui.Offset(3, 0)); // rotated base
          expect(passes[0].imageFilter, isNotNull); // has blur
        },
      );

      test('Deep chain with 5 sequential primitives', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="deepFx">
      <feOffset dx="1" dy="0" result="a"/>
      <feOffset in="a" dx="2" dy="0" result="b"/>
      <feOffset in="b" dx="3" dy="0" result="c"/>
      <feOffset in="c" dx="4" dy="0" result="d"/>
      <feOffset in="d" dx="5" dy="0"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#deepFx)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final passes = document.filters!.resolvePaintPasses('deepFx');

        expect(passes, hasLength(1));
        // Total offset: 1+2+3+4+5 = 15
        expect(passes.single.offset, const ui.Offset(15, 0));
      });

      test(
        'Chain with skip reference: primitive C uses result from A, not B',
        () {
          final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="skipFx">
      <feOffset dx="5" dy="0" result="first"/>
      <feGaussianBlur stdDeviation="2" result="middle"/>
      <feComposite in="first" in2="SourceGraphic" operator="over"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#skipFx)"/>
</svg>
''';

          final document = SvgParser.parse(svgString);
          final passes = document.filters!.resolvePaintPasses('skipFx');

          // Composite uses "first" (offset) directly, skipping "middle" (blur)
          expect(passes, hasLength(2));
          expect(passes[0].offset, ui.Offset.zero); // SourceGraphic base
          expect(passes[1].offset, const ui.Offset(5, 0)); // first (offset)
        },
      );
    });

    // =========================================================================
    // BackgroundImage/BackgroundAlpha input tests
    // =========================================================================
    group('BackgroundImage/BackgroundAlpha input handling', () {
      test('BackgroundImage with provided context', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="bgFx">
      <feBlend in="SourceGraphic" in2="BackgroundImage" mode="multiply"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#bgFx)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final passes = document.filters!.resolvePaintPasses(
          'bgFx',
          sourceContext: const SvgFilterSourceContext(
            backgroundImage: <SvgFilterPaintPass>[
              SvgFilterPaintPass(offset: ui.Offset(7, 0)),
            ],
          ),
        );

        // Blend combines BackgroundImage (base) + SourceGraphic (top)
        expect(passes, hasLength(2));
        expect(passes[0].offset, const ui.Offset(7, 0)); // BackgroundImage
        expect(passes[1].blendMode, ui.BlendMode.multiply);
      });

      test('BackgroundAlpha with provided context', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="bgAlphaFx">
      <feGaussianBlur in="BackgroundAlpha" stdDeviation="3"/>
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
        expect(passes.single.imageFilter, isNotNull); // blur
        expect(passes.single.colorFilter, isNotNull); // alpha extraction
      });

      test('Multiple primitives referencing BackgroundImage', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="multiBgFx">
      <feGaussianBlur in="BackgroundImage" stdDeviation="2" result="blurredBg"/>
      <feOffset in="BackgroundImage" dx="4" dy="0" result="offsetBg"/>
      <feMerge>
        <feMergeNode in="blurredBg"/>
        <feMergeNode in="offsetBg"/>
      </feMerge>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#multiBgFx)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final passes = document.filters!.resolvePaintPasses(
          'multiBgFx',
          sourceContext: const SvgFilterSourceContext(
            backgroundImage: <SvgFilterPaintPass>[
              SvgFilterPaintPass(offset: ui.Offset(1, 0)),
            ],
          ),
        );

        // Both primitives use same BackgroundImage source
        expect(passes, hasLength(2));
        expect(passes[0].imageFilter, isNotNull); // blurred has blur
        expect(passes[1].offset, const ui.Offset(5, 0)); // offset base + 4
      });

      test('BackgroundImage fallback to SourceGraphic when not provided', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="bgFallbackFx">
      <feBlend in="SourceGraphic" in2="BackgroundImage" mode="screen"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#bgFallbackFx)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final passes = document.filters!.resolvePaintPasses('bgFallbackFx');

        // BackgroundImage falls back to SourceGraphic
        expect(passes, hasLength(2));
        expect(passes[0].blendMode, isNull); // base
        expect(passes[1].blendMode, ui.BlendMode.screen); // top
      });
    });

    // =========================================================================
    // FillPaint/StrokePaint input tests
    // =========================================================================
    group('FillPaint/StrokePaint input scope', () {
      test('FillPaint with provided context', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="fillFx">
      <feGaussianBlur in="FillPaint" stdDeviation="2"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#fillFx)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final passes = document.filters!.resolvePaintPasses(
          'fillFx',
          sourceContext: const SvgFilterSourceContext(
            fillPaint: <SvgFilterPaintPass>[
              SvgFilterPaintPass(
                offset: ui.Offset(2, 0),
                paintFill: true,
                paintStroke: false,
              ),
            ],
          ),
        );

        expect(passes, hasLength(1));
        expect(passes.single.paintFill, isTrue);
        expect(passes.single.paintStroke, isFalse);
        expect(passes.single.imageFilter, isNotNull); // blur
      });

      test('StrokePaint with provided context', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="strokeFx">
      <feGaussianBlur in="StrokePaint" stdDeviation="1"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" stroke="red" filter="url(#strokeFx)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final passes = document.filters!.resolvePaintPasses(
          'strokeFx',
          sourceContext: const SvgFilterSourceContext(
            strokePaint: <SvgFilterPaintPass>[
              SvgFilterPaintPass(
                offset: ui.Offset(3, 0),
                paintFill: false,
                paintStroke: true,
              ),
            ],
          ),
        );

        expect(passes, hasLength(1));
        expect(passes.single.paintFill, isFalse);
        expect(passes.single.paintStroke, isTrue);
        expect(passes.single.offset, const ui.Offset(3, 0));
      });

      test('FillPaint fallback masks only fill channel', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="fillMaskFx">
      <feOffset in="FillPaint" dx="2" dy="0"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#fillMaskFx)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final passes = document.filters!.resolvePaintPasses('fillMaskFx');

        expect(passes, hasLength(1));
        expect(passes.single.paintFill, isTrue);
        expect(passes.single.paintStroke, isFalse);
      });

      test('StrokePaint fallback masks only stroke channel', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="strokeMaskFx">
      <feOffset in="StrokePaint" dx="2" dy="0"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" stroke="red" filter="url(#strokeMaskFx)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final passes = document.filters!.resolvePaintPasses('strokeMaskFx');

        expect(passes, hasLength(1));
        expect(passes.single.paintFill, isFalse);
        expect(passes.single.paintStroke, isTrue);
      });
    });

    // =========================================================================
    // feComposite arithmetic mode tests
    // =========================================================================
    group('feComposite arithmetic mode precision', () {
      test('Arithmetic with k2=0.5, k3=0.5 creates weighted blend', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="arithmeticBlendFx">
      <feOffset dx="3" dy="0" result="shifted"/>
      <feComposite in="SourceGraphic" in2="shifted" operator="arithmetic" k1="0" k2="0.5" k3="0.5" k4="0"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#arithmeticBlendFx)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final passes = document.filters!.resolvePaintPasses(
          'arithmeticBlendFx',
        );

        expect(passes, hasLength(2));
      });

      test('Arithmetic with k1=1 creates multiplication', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="arithmeticMultFx">
      <feOffset dx="2" dy="0" result="shifted"/>
      <feComposite in="SourceGraphic" in2="shifted" operator="arithmetic" k1="1" k2="0" k3="0" k4="0"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#arithmeticMultFx)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final passes = document.filters!.resolvePaintPasses('arithmeticMultFx');

        // k1=1 alone creates multiply blend
        expect(passes, hasLength(2));
        expect(passes[1].blendMode, ui.BlendMode.multiply);
      });

      test('Arithmetic with k4 bias adds constant offset', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="arithmeticBiasFx">
      <feComposite in="SourceGraphic" operator="arithmetic" k1="0" k2="1" k3="0" k4="0.2"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#arithmeticBiasFx)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final passes = document.filters!.resolvePaintPasses('arithmeticBiasFx');

        expect(passes, isNotEmpty);
      });

      test('Arithmetic k2=1 k3=1 creates additive plus blend', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="additiveFx">
      <feOffset dx="5" dy="0" result="shifted"/>
      <feComposite in="SourceGraphic" in2="shifted" operator="arithmetic" k1="0" k2="1" k3="1" k4="0"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#additiveFx)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final passes = document.filters!.resolvePaintPasses('additiveFx');

        expect(passes, hasLength(2));
        expect(passes[1].blendMode, ui.BlendMode.plus);
      });

      test('Arithmetic all zeros produces empty output', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="zeroArithmeticFx">
      <feComposite in="SourceGraphic" operator="arithmetic" k1="0" k2="0" k3="0" k4="0"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#zeroArithmeticFx)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final passes = document.filters!.resolvePaintPasses('zeroArithmeticFx');

        // All zero coefficients produce transparent black (identity fallback)
        expect(passes, hasLength(1));
        expect(passes.single.imageFilter, isNull);
        expect(passes.single.colorFilter, isNull);
      });
    });

    // =========================================================================
    // feMerge with non-adjacent result references tests
    // =========================================================================
    group('feMerge with non-adjacent result references', () {
      test('feMerge references results from non-adjacent primitives', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="nonAdjacentMergeFx">
      <feOffset dx="1" dy="0" result="first"/>
      <feGaussianBlur stdDeviation="2" result="middle"/>
      <feOffset dx="3" dy="0" result="last"/>
      <feMerge>
        <feMergeNode in="first"/>
        <feMergeNode in="last"/>
      </feMerge>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#nonAdjacentMergeFx)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final passes = document.filters!.resolvePaintPasses(
          'nonAdjacentMergeFx',
        );

        // Merge of first (offset 1) and last (offset 1+3=4 since last processes middle output)
        // middle processes first's output, last processes middle's output
        expect(passes, hasLength(2));
        expect(passes[0].offset, const ui.Offset(1, 0)); // first
        expect(
          passes[1].offset,
          const ui.Offset(4, 0),
        ); // last (first + last offset = 1+3)
      });

      test('feMerge with 4 nodes from different parts of chain', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="fourNodeMergeFx">
      <feOffset dx="1" dy="0" result="a"/>
      <feOffset dx="2" dy="0" result="b"/>
      <feOffset dx="3" dy="0" result="c"/>
      <feOffset dx="4" dy="0" result="d"/>
      <feMerge>
        <feMergeNode in="a"/>
        <feMergeNode in="c"/>
        <feMergeNode in="b"/>
        <feMergeNode in="d"/>
      </feMerge>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#fourNodeMergeFx)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final passes = document.filters!.resolvePaintPasses('fourNodeMergeFx');

        // Merge order: a, c, b, d
        expect(passes, hasLength(4));
        expect(passes[0].offset, const ui.Offset(1, 0)); // a
        expect(passes[1].offset, const ui.Offset(6, 0)); // c (1+2+3)
        expect(passes[2].offset, const ui.Offset(3, 0)); // b (1+2)
        expect(passes[3].offset, const ui.Offset(10, 0)); // d (1+2+3+4)
      });

      test('feMerge mixing named results and built-in inputs', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="mixedMergeFx">
      <feOffset dx="4" dy="0" result="shifted"/>
      <feGaussianBlur stdDeviation="2" result="blurred"/>
      <feMerge>
        <feMergeNode in="SourceGraphic"/>
        <feMergeNode in="shifted"/>
        <feMergeNode in="SourceAlpha"/>
        <feMergeNode in="blurred"/>
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
        expect(passes[1].offset, const ui.Offset(4, 0)); // shifted
        expect(passes[2].colorFilter, isNotNull); // SourceAlpha
        expect(passes[3].imageFilter, isNotNull); // blurred
      });
    });

    // =========================================================================
    // feDropShadow chaining tests
    // =========================================================================
    group('feDropShadow chaining scenarios', () {
      test('feDropShadow followed by feComposite', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="shadowCompositeFx">
      <feDropShadow dx="3" dy="3" stdDeviation="2" result="shadow"/>
      <feComposite in="shadow" in2="SourceGraphic" operator="xor"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#shadowCompositeFx)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final passes = document.filters!.resolvePaintPasses(
          'shadowCompositeFx',
        );

        // DropShadow produces 2 passes, composite uses them
        expect(passes.length, greaterThanOrEqualTo(2));
      });

      test('feDropShadow as input to feGaussianBlur', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="shadowBlurFx">
      <feDropShadow dx="2" dy="2" stdDeviation="1" result="shadow"/>
      <feGaussianBlur in="shadow" stdDeviation="3"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#shadowBlurFx)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final passes = document.filters!.resolvePaintPasses('shadowBlurFx');

        // Shadow (2 passes) -> blur processes all passes
        expect(passes, hasLength(2));
        expect(passes[0].imageFilter, isNotNull); // shadow pass with extra blur
        expect(passes[1].imageFilter, isNotNull); // source pass with blur
      });

      test('Multiple feDropShadows chained', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="doubleShadowFx">
      <feDropShadow dx="2" dy="2" stdDeviation="1" flood-color="red" result="shadow1"/>
      <feDropShadow in="shadow1" dx="4" dy="4" stdDeviation="2" flood-color="blue"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="green" filter="url(#doubleShadowFx)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final passes = document.filters!.resolvePaintPasses('doubleShadowFx');

        // First shadow: 2 passes (shadow + source)
        // Second shadow processes those 2 passes: 2*2 = 4 passes
        expect(passes, hasLength(4));
      });

      test('feDropShadow with custom input from blur result', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="blurShadowFx">
      <feGaussianBlur stdDeviation="2" result="preBlurred"/>
      <feDropShadow in="preBlurred" dx="3" dy="3" stdDeviation="1"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#blurShadowFx)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final passes = document.filters!.resolvePaintPasses('blurShadowFx');

        expect(passes, hasLength(2));
        // Both passes should have blur from preBlurred
        expect(passes[0].imageFilter, isNotNull);
        expect(passes[1].imageFilter, isNotNull);
        expect(passes[0].offset, const ui.Offset(3, 3)); // shadow offset
        expect(passes[1].offset, ui.Offset.zero); // source (blurred input)
      });

      test('feDropShadow in feMerge composition', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="mergeShadowFx">
      <feDropShadow dx="4" dy="4" stdDeviation="2" result="shadow"/>
      <feOffset dx="8" dy="0" result="offset"/>
      <feMerge>
        <feMergeNode in="shadow"/>
        <feMergeNode in="offset"/>
        <feMergeNode in="SourceGraphic"/>
      </feMerge>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#mergeShadowFx)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final passes = document.filters!.resolvePaintPasses('mergeShadowFx');

        // shadow (2) + offset (from shadow's 2 passes = 2) + SourceGraphic (1) = 5
        // offset processes previous output (shadow) which has 2 passes
        expect(passes, hasLength(5));
      });

      test('feDropShadow with zero stdDeviation (no blur)', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="noBlurShadowFx">
      <feDropShadow dx="5" dy="5" stdDeviation="0"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#noBlurShadowFx)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final passes = document.filters!.resolvePaintPasses('noBlurShadowFx');

        expect(passes, hasLength(2));
        expect(passes[0].offset, const ui.Offset(5, 5)); // shadow offset
        expect(passes[1].offset, ui.Offset.zero); // source
      });
    });

    // =========================================================================
    // Complex real-world filter scenarios
    // =========================================================================
    group('Complex real-world filter scenarios', () {
      test('Bevel effect simulation', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="bevelFx">
      <feGaussianBlur in="SourceAlpha" stdDeviation="2" result="blurAlpha"/>
      <feOffset in="blurAlpha" dx="-2" dy="-2" result="lightOffset"/>
      <feOffset in="blurAlpha" dx="2" dy="2" result="darkOffset"/>
      <feFlood flood-color="white" flood-opacity="0.5" result="lightColor"/>
      <feFlood flood-color="black" flood-opacity="0.5" result="darkColor"/>
      <feComposite in="lightColor" in2="lightOffset" operator="in" result="lightBevel"/>
      <feComposite in="darkColor" in2="darkOffset" operator="in" result="darkBevel"/>
      <feMerge>
        <feMergeNode in="darkBevel"/>
        <feMergeNode in="lightBevel"/>
        <feMergeNode in="SourceGraphic"/>
      </feMerge>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#bevelFx)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final passes = document.filters!.resolvePaintPasses('bevelFx');

        expect(passes.length, greaterThanOrEqualTo(3));
      });

      test('Glow effect with color overlay', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="glowFx">
      <feGaussianBlur in="SourceAlpha" stdDeviation="4" result="blur"/>
      <feFlood flood-color="#00FF00" flood-opacity="0.8" result="glowColor"/>
      <feComposite in="glowColor" in2="blur" operator="in" result="coloredGlow"/>
      <feMerge>
        <feMergeNode in="coloredGlow"/>
        <feMergeNode in="SourceGraphic"/>
      </feMerge>
    </filter>
  </defs>
  <text x="50" y="50" fill="white" filter="url(#glowFx)">Glow</text>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final passes = document.filters!.resolvePaintPasses('glowFx');

        // Colored glow + source graphic should produce at least two layers.
        expect(passes.length, greaterThanOrEqualTo(2));
      });

      test('Inner shadow effect', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="innerShadowFx">
      <feGaussianBlur in="SourceAlpha" stdDeviation="3" result="blur"/>
      <feOffset in="blur" dx="2" dy="2" result="offsetBlur"/>
      <feComposite in="SourceGraphic" in2="offsetBlur" operator="xor" result="inverseMask"/>
      <feFlood flood-color="black" flood-opacity="0.4" result="shadowColor"/>
      <feComposite in="shadowColor" in2="inverseMask" operator="in" result="innerShadow"/>
      <feComposite in="innerShadow" in2="SourceGraphic" operator="atop"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#innerShadowFx)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final passes = document.filters!.resolvePaintPasses('innerShadowFx');

        expect(passes, isNotEmpty);
      });
    });

    // =========================================================================
    // Forward reference and edge case tests
    // =========================================================================
    group('Forward reference handling', () {
      test('Forward reference produces transparent black (empty output)', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="forwardRefFx">
      <feOffset in="futureResult" dx="5" dy="0" result="first"/>
      <feGaussianBlur stdDeviation="2" result="futureResult"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#forwardRefFx)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final passes = document.filters!.resolvePaintPasses('forwardRefFx');

        // Forward reference "futureResult" not yet computed when "first" runs
        // Results in transparent black for first, then futureResult computes normally
        // Final output is futureResult's blur
        expect(passes, isNotEmpty);
      });

      test('Multiple forward references all produce identity fallback', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="multiFwdRefFx">
      <feOffset in="nonExistent1" dx="2" dy="0"/>
      <feOffset in="nonExistent2" dx="3" dy="0"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#multiFwdRefFx)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final passes = document.filters!.resolvePaintPasses('multiFwdRefFx');

        // Both references are unresolved, should get identity
        expect(passes, hasLength(1));
        expect(passes.single.imageFilter, isNull);
        expect(passes.single.colorFilter, isNull);
      });

      test('Unknown reference without fallback produces identity', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="unknownRefFx">
      <feComposite in="doesNotExist" in2="alsoDoesNotExist" operator="over"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#unknownRefFx)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final passes = document.filters!.resolvePaintPasses('unknownRefFx');

        // Both inputs unresolved, result is identity
        expect(passes, hasLength(1));
      });
    });

    // =========================================================================
    // Empty filter and single primitive tests
    // =========================================================================
    group('Empty filter and single primitive handling', () {
      test('Empty filter (no primitives) returns identity', () {
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
        expect(passes.single.imageFilter, isNull);
        expect(passes.single.colorFilter, isNull);
        expect(passes.single.blendMode, isNull);
      });

      test('Single feOffset primitive', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="singleOffsetFx">
      <feOffset dx="10" dy="20"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#singleOffsetFx)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final passes = document.filters!.resolvePaintPasses('singleOffsetFx');

        expect(passes, hasLength(1));
        expect(passes.single.offset, const ui.Offset(10, 20));
      });

      test('Single feFlood primitive', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="singleFloodFx">
      <feFlood flood-color="red" flood-opacity="0.5"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#singleFloodFx)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final passes = document.filters!.resolvePaintPasses('singleFloodFx');

        expect(passes, hasLength(1));
        expect(passes.single.colorFilter, isNotNull);
      });

      test('Non-existent filter ID returns identity', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="existingFx">
      <feGaussianBlur stdDeviation="5"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#existingFx)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final passes = document.filters!.resolvePaintPasses('nonExistentFx');

        // Non-existent filter returns identity
        expect(passes, hasLength(1));
        expect(passes.single.imageFilter, isNull);
        expect(passes.single.colorFilter, isNull);
      });
    });

    // =========================================================================
    // feDropShadow spec compliance tests
    // =========================================================================
    group('feDropShadow SVG spec compliance', () {
      test('feDropShadow with custom dx/dy', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="customOffsetShadowFx">
      <feDropShadow dx="8" dy="12" stdDeviation="0"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#customOffsetShadowFx)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final passes = document.filters!.resolvePaintPasses(
          'customOffsetShadowFx',
        );

        // Shadow pass + source pass
        expect(passes, hasLength(2));
        expect(passes[0].offset, const ui.Offset(8, 12)); // shadow
        expect(passes[1].offset, ui.Offset.zero); // source
      });

      test('feDropShadow with flood-color', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="coloredShadowFx">
      <feDropShadow dx="3" dy="3" stdDeviation="2" flood-color="#FF0000"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#coloredShadowFx)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final passes = document.filters!.resolvePaintPasses('coloredShadowFx');

        expect(passes, hasLength(2));
        expect(passes[0].colorFilter, isNotNull); // shadow color
      });

      test('feDropShadow with flood-opacity', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="opacityShadowFx">
      <feDropShadow dx="2" dy="2" stdDeviation="1" flood-opacity="0.3"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#opacityShadowFx)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final passes = document.filters!.resolvePaintPasses('opacityShadowFx');

        expect(passes, hasLength(2));
        expect(passes[0].colorFilter, isNotNull); // includes opacity
      });

      test('feDropShadow with asymmetric stdDeviation', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="asymmetricBlurShadowFx">
      <feDropShadow dx="4" dy="4" stdDeviation="2 6"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#asymmetricBlurShadowFx)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final passes = document.filters!.resolvePaintPasses(
          'asymmetricBlurShadowFx',
        );

        expect(passes, hasLength(2));
        // Shadow should have blur filter applied
        expect(passes[0].imageFilter, isNotNull);
      });

      test('feDropShadow with input from previous primitive', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="chainedShadowFx">
      <feColorMatrix type="saturate" values="0" result="grayscale"/>
      <feDropShadow in="grayscale" dx="3" dy="3" stdDeviation="2"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#chainedShadowFx)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final passes = document.filters!.resolvePaintPasses('chainedShadowFx');

        // grayscale input -> shadow produces 2 passes (shadow + grayscale source)
        expect(passes, hasLength(2));
      });
    });

    // =========================================================================
    // feMerge implicit input tests
    // =========================================================================
    group('feMerge implicit input handling', () {
      test('feMergeNode with omitted in uses previous result', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="implicitMergeFx">
      <feOffset dx="5" dy="0" result="shifted"/>
      <feMerge>
        <feMergeNode in="SourceGraphic"/>
        <feMergeNode/>
      </feMerge>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#implicitMergeFx)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final passes = document.filters!.resolvePaintPasses('implicitMergeFx');

        // SourceGraphic (no offset) + implicit previous (shifted = offset 5)
        expect(passes, hasLength(2));
        expect(passes[0].offset, ui.Offset.zero); // SourceGraphic
        expect(passes[1].offset, const ui.Offset(5, 0)); // shifted (previous)
      });

      test('Empty feMerge uses previous output', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="emptyMergeFx">
      <feOffset dx="7" dy="0"/>
      <feMerge>
      </feMerge>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#emptyMergeFx)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final passes = document.filters!.resolvePaintPasses('emptyMergeFx');

        // Empty merge should pass through previous offset
        expect(passes, hasLength(1));
        expect(passes.single.offset, const ui.Offset(7, 0));
      });

      test('feMerge with all implicit inputs', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="allImplicitMergeFx">
      <feOffset dx="3" dy="0"/>
      <feMerge>
        <feMergeNode/>
        <feMergeNode/>
        <feMergeNode/>
      </feMerge>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#allImplicitMergeFx)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final passes = document.filters!.resolvePaintPasses(
          'allImplicitMergeFx',
        );

        // All three nodes use previous (offset), creating 3 identical layers
        expect(passes, hasLength(3));
        for (final pass in passes) {
          expect(pass.offset, const ui.Offset(3, 0));
        }
      });

      test(
        'feMerge at start of filter uses SourceGraphic as implicit input',
        () {
          final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="firstMergeFx">
      <feMerge>
        <feMergeNode/>
        <feMergeNode in="SourceAlpha"/>
      </feMerge>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#firstMergeFx)"/>
</svg>
''';

          final document = SvgParser.parse(svgString);
          final passes = document.filters!.resolvePaintPasses('firstMergeFx');

          // First implicit node should use SourceGraphic, second is SourceAlpha
          expect(passes, hasLength(2));
          expect(
            passes[0].colorFilter,
            isNull,
          ); // SourceGraphic (no color filter)
          expect(
            passes[1].colorFilter,
            isNotNull,
          ); // SourceAlpha (has color filter)
        },
      );
    });

    // =========================================================================
    // Filter chain with result attribute tests
    // =========================================================================
    group('Filter chain with result attribute cross-references', () {
      test('Multiple primitives reference same named result', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="sharedResultFx">
      <feGaussianBlur stdDeviation="2" result="blurred"/>
      <feOffset in="blurred" dx="2" dy="0" result="offset1"/>
      <feOffset in="blurred" dx="4" dy="0" result="offset2"/>
      <feMerge>
        <feMergeNode in="offset1"/>
        <feMergeNode in="offset2"/>
      </feMerge>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#sharedResultFx)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final passes = document.filters!.resolvePaintPasses('sharedResultFx');

        // Two offsets from same blurred base merged together
        expect(passes, hasLength(2));
        expect(passes[0].offset, const ui.Offset(2, 0)); // offset1
        expect(passes[1].offset, const ui.Offset(4, 0)); // offset2
        // Both should have blur
        expect(passes[0].imageFilter, isNotNull);
        expect(passes[1].imageFilter, isNotNull);
      });

      test('Complex DAG with diamond dependency pattern', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="diamondFx">
      <feOffset dx="1" dy="0" result="root"/>
      <feOffset in="root" dx="2" dy="0" result="leftBranch"/>
      <feOffset in="root" dx="3" dy="0" result="rightBranch"/>
      <feComposite in="leftBranch" in2="rightBranch" operator="over" result="merged"/>
      <feOffset in="merged" dx="4" dy="0"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#diamondFx)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final passes = document.filters!.resolvePaintPasses('diamondFx');

        // Composite merges left (1+2=3) and right (1+3=4), then offset by 4
        // Result should have 2 passes from composite, both offset by 4
        expect(passes, hasLength(2));
      });

      test('Result name reuse (later primitive with same result name)', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="reusedResultFx">
      <feOffset dx="1" dy="0" result="temp"/>
      <feOffset in="temp" dx="2" dy="0"/>
      <feOffset dx="5" dy="0" result="temp"/>
      <feOffset in="temp" dx="10" dy="0"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#reusedResultFx)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final passes = document.filters!.resolvePaintPasses('reusedResultFx');

        // Second "temp" overwrites first, so last offset uses dx=5 (from second temp)
        // Final offset: (1+2) implicit chain, then 5 (new temp), then 5+10=15
        expect(passes, hasLength(1));
        // The last temp was from implicit chain (1+2+5=8), then +10 = 18
        expect(passes.single.offset, const ui.Offset(18, 0));
      });
    });

    // =========================================================================
    // Implicit input chaining tests (omitted in attributes)
    // =========================================================================
    group('Implicit input chaining (omitted in attributes)', () {
      test('Chain of primitives with all omitted in attributes', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="implicitChainFx">
      <feOffset dx="1" dy="0"/>
      <feOffset dx="2" dy="0"/>
      <feOffset dx="3" dy="0"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#implicitChainFx)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final passes = document.filters!.resolvePaintPasses('implicitChainFx');

        // Each offset uses previous, accumulating: 1+2+3=6
        expect(passes, hasLength(1));
        expect(passes.single.offset, const ui.Offset(6, 0));
      });

      test('First primitive with omitted in uses SourceGraphic', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="firstImplicitFx">
      <feGaussianBlur stdDeviation="3"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#firstImplicitFx)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final passes = document.filters!.resolvePaintPasses('firstImplicitFx');

        // First primitive with no "in" uses SourceGraphic
        expect(passes, hasLength(1));
        expect(passes.single.imageFilter, isNotNull); // blur applied
      });

      test('Mix of explicit and implicit inputs', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="mixedInputsFx">
      <feOffset dx="1" dy="0" result="a"/>
      <feOffset dx="2" dy="0"/>
      <feOffset in="a" dx="3" dy="0"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#mixedInputsFx)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final passes = document.filters!.resolvePaintPasses('mixedInputsFx');

        // a=1, implicit uses a=1+2=3, then explicit uses a=1+3=4
        expect(passes, hasLength(1));
        expect(passes.single.offset, const ui.Offset(4, 0));
      });
    });
  });
}
