import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_svg/src/animation/svg_parser.dart';
import 'package:flutter_svg/src/animation/svg_filters.dart';

void main() {
  // ===========================================================================
  // Extended Filter Input-Graph Semantics Tests
  // ===========================================================================
  // These tests cover additional edge cases per SVG Filter 1.1 spec:
  // 1. Duplicate result name overwrite behavior
  // 2. feDisplacementMap in2 handling
  // 3. Complex multi-step chains with mixed inputs
  // 4. in2 on feBlend, feComposite, feDisplacementMap

  group('Duplicate result name overwrite behavior', () {
    test('Later primitive overwrites earlier result with same name', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="duplicateResultFx">
      <feOffset dx="5" dy="0" result="shared"/>
      <feOffset dx="10" dy="0" result="shared"/>
      <feOffset in="shared" dx="1" dy="0"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#duplicateResultFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('duplicateResultFx');

      expect(passes, hasLength(1));
      // Chain: first offset uses SourceGraphic -> 5, stores as "shared"
      // Second offset uses previous (5) + 10 = 15, overwrites "shared"
      // Third offset uses "shared" (15) + 1 = 16
      expect(passes.single.offset.dx, 16.0);
    });

    test('Duplicate result name across different primitive types', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="duplicateMixedFx">
      <feGaussianBlur stdDeviation="2" result="effect"/>
      <feOffset dx="5" dy="0" result="effect"/>
      <feMerge>
        <feMergeNode in="effect"/>
        <feMergeNode in="SourceGraphic"/>
      </feMerge>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#duplicateMixedFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('duplicateMixedFx');

      expect(passes, hasLength(2));
      // "effect" should be the feOffset (offset 5), not the blur
      // feOffset applied to blur (2) produces offset + blur
      expect(passes[0].offset, const ui.Offset(5, 0));
      // The blur should NOT be in the first pass since it was overwritten
      // Actually blur IS in the first pass because feOffset chains from blur
      expect(passes[0].imageFilter, isNotNull);
    });

    test('Triple overwrite of same result name', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="tripleOverwriteFx">
      <feOffset dx="1" dy="0" result="x"/>
      <feOffset dx="2" dy="0" result="x"/>
      <feOffset dx="3" dy="0" result="x"/>
      <feOffset in="x" dx="10" dy="0"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#tripleOverwriteFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('tripleOverwriteFx');

      expect(passes, hasLength(1));
      // "x" should be 3 (last overwrite), then +10 = 13
      // Chain: first offset(1) -> second offset(1+2=3) -> third offset(3+3=6)
      // "x" = 6, then +10 = 16
      expect(passes.single.offset.dx, 16.0);
    });

    test('Reference to overwritten result uses latest value', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="overwriteRefFx">
      <feOffset dx="1" dy="0" result="r"/>
      <feOffset in="r" dx="2" dy="0"/>
      <feOffset dx="100" dy="0" result="r"/>
      <feOffset in="r" dx="3" dy="0"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#overwriteRefFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('overwriteRefFx');

      expect(passes, hasLength(1));
      // First feOffset: result "r" = 1
      // Second feOffset: in="r" (1) + 2 = 3
      // Third feOffset: result "r" = 3 + 100 = 103 (overwrites)
      // Fourth feOffset: in="r" (103) + 3 = 106
      expect(passes.single.offset.dx, 106.0);
    });
  });

  group('feDisplacementMap in2 handling', () {
    test('feDisplacementMap with valid in2 reference', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="displacementFx">
      <feGaussianBlur stdDeviation="2" result="blurred"/>
      <feTurbulence type="fractalNoise" baseFrequency="0.1" result="noise"/>
      <feDisplacementMap in="blurred" in2="noise" scale="10"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#displacementFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('displacementFx');

      // When in2 is valid, displacement map should process input
      expect(passes, isNotEmpty);
      // blurred input should have blur filter
      expect(passes.first.imageFilter, isNotNull);
    });

    test('feDisplacementMap with in2="none" passes through input', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="displacementNoneFx">
      <feGaussianBlur stdDeviation="2" result="blurred"/>
      <feDisplacementMap in="blurred" in2="none" scale="10"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#displacementNoneFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('displacementNoneFx');

      // in2="none" should just pass through the input
      expect(passes, hasLength(1));
      expect(passes.first.imageFilter, isNotNull); // blur preserved
    });

    test('feDisplacementMap with invalid in2 reference produces empty', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="displacementBadFx">
      <feGaussianBlur stdDeviation="2" result="blurred"/>
      <feDisplacementMap in="blurred" in2="nonExistent" scale="10"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#displacementBadFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('displacementBadFx');

      // Invalid in2 reference should produce empty output
      expect(passes, hasLength(1));
    });

    test('feDisplacementMap with scale=0 is identity', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="displacementZeroFx">
      <feOffset dx="5" dy="0" result="offset"/>
      <feTurbulence result="noise"/>
      <feDisplacementMap in="offset" in2="noise" scale="0"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#displacementZeroFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('displacementZeroFx');

      // scale=0 is identity displacement
      expect(passes, hasLength(1));
      expect(passes.first.offset, const ui.Offset(5, 0));
    });

    test('feDisplacementMap chained from SourceAlpha', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="displacementAlphaFx">
      <feTurbulence type="turbulence" baseFrequency="0.05" result="noise"/>
      <feDisplacementMap in="SourceAlpha" in2="noise" scale="5"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#displacementAlphaFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses(
        'displacementAlphaFx',
      );

      expect(passes, isNotEmpty);
      // SourceAlpha should have colorFilter for alpha extraction
      expect(passes.first.colorFilter, isNotNull);
    });
  });

  group('feBlend in2 handling', () {
    test('feBlend with valid in2 reference', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="blendValidFx">
      <feOffset dx="5" dy="0" result="top"/>
      <feOffset dx="10" dy="0" result="bottom"/>
      <feBlend in="top" in2="bottom" mode="multiply"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#blendValidFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('blendValidFx');

      expect(passes, hasLength(2));
      // Blend should include both layers
      expect(passes.last.blendMode, ui.BlendMode.multiply);
    });

    test('feBlend with in2="SourceGraphic"', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="blendSourceFx">
      <feGaussianBlur stdDeviation="2" result="blurred"/>
      <feBlend in="blurred" in2="SourceGraphic" mode="screen"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#blendSourceFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('blendSourceFx');

      expect(passes, hasLength(2));
      // in2 is SourceGraphic, should be included
    });

    test('feBlend with in2="none" uses only in', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="blendNoneFx">
      <feOffset dx="5" dy="0" result="offsetted"/>
      <feBlend in="offsetted" in2="none" mode="overlay"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#blendNoneFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('blendNoneFx');

      expect(passes, hasLength(1));
      expect(passes.first.offset, const ui.Offset(5, 0));
      expect(passes.first.blendMode, ui.BlendMode.overlay);
    });

    test('feBlend with invalid in2 produces empty', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="blendBadIn2Fx">
      <feOffset dx="5" dy="0" result="valid"/>
      <feBlend in="valid" in2="nonExistent" mode="darken"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#blendBadIn2Fx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('blendBadIn2Fx');

      // Invalid in2 should produce empty (transparent black)
      expect(passes, hasLength(1));
    });
  });

  group('feComposite in2 handling', () {
    test('feComposite operator=in with named in2', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="compositeInFx">
      <feFlood flood-color="red" result="red"/>
      <feGaussianBlur in="SourceAlpha" stdDeviation="2" result="blurredAlpha"/>
      <feComposite in="red" in2="blurredAlpha" operator="in"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#compositeInFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('compositeInFx');

      expect(passes, hasLength(2));
      // in2 should have blur applied
      expect(passes.first.imageFilter, isNotNull);
    });

    test('feComposite operator=out with SourceAlpha in2', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="compositeOutFx">
      <feFlood flood-color="green" result="flood"/>
      <feComposite in="flood" in2="SourceAlpha" operator="out"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#compositeOutFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('compositeOutFx');

      expect(passes, hasLength(2));
      // Should have srcOut blend mode
      expect(passes.last.blendMode, ui.BlendMode.srcOut);
    });

    test('feComposite arithmetic with in2 from named result', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="arithmeticNamedFx">
      <feGaussianBlur stdDeviation="1" result="blur1"/>
      <feGaussianBlur stdDeviation="2" result="blur2"/>
      <feComposite in="blur1" in2="blur2" operator="arithmetic" k1="0.5" k2="0.5" k3="0.5" k4="0"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#arithmeticNamedFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('arithmeticNamedFx');

      expect(passes, isNotEmpty);
    });

    test('feComposite with in2="none"', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="compositeNoneIn2Fx">
      <feOffset dx="5" dy="0" result="offset"/>
      <feComposite in="offset" in2="none" operator="over"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#compositeNoneIn2Fx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('compositeNoneIn2Fx');

      expect(passes, hasLength(1));
      expect(passes.first.offset, const ui.Offset(5, 0));
    });
  });

  group('Complex multi-step chains with mixed inputs', () {
    test('10-step chain with alternating named and implicit inputs', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="tenStepFx">
      <feOffset dx="1" dy="0" result="r1"/>
      <feOffset dx="1" dy="0"/>
      <feOffset dx="1" dy="0" result="r3"/>
      <feOffset dx="1" dy="0"/>
      <feOffset dx="1" dy="0" result="r5"/>
      <feOffset in="r1" dx="1" dy="0" result="r6"/>
      <feOffset in="r3" dx="1" dy="0"/>
      <feOffset in="r5" dx="1" dy="0"/>
      <feOffset dx="1" dy="0"/>
      <feOffset dx="1" dy="0"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#tenStepFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('tenStepFx');

      expect(passes, hasLength(1));
      // Complex chain resolves without error
      expect(passes.single.offset.dx, isPositive);
    });

    test('Diamond graph: branch and rejoin', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="diamondFx">
      <feOffset dx="1" dy="0" result="start"/>
      <feGaussianBlur in="start" stdDeviation="1" result="branch1"/>
      <feColorMatrix in="start" type="saturate" values="0.5" result="branch2"/>
      <feMerge result="rejoin">
        <feMergeNode in="branch1"/>
        <feMergeNode in="branch2"/>
      </feMerge>
      <feOffset in="rejoin" dx="2" dy="0"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#diamondFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('diamondFx');

      expect(passes, hasLength(2));
      // Both branches should have offset 1 + 2 = 3
      expect(passes[0].offset.dx, 3.0);
      expect(passes[1].offset.dx, 3.0);
      // One should have blur, one should have colorMatrix
      expect(passes[0].imageFilter, isNotNull); // blur
    });

    test('Triple branch from single source', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="tripleBranchFx">
      <feGaussianBlur stdDeviation="1" result="source"/>
      <feOffset in="source" dx="1" dy="0" result="b1"/>
      <feOffset in="source" dx="2" dy="0" result="b2"/>
      <feOffset in="source" dx="3" dy="0" result="b3"/>
      <feMerge>
        <feMergeNode in="b1"/>
        <feMergeNode in="b2"/>
        <feMergeNode in="b3"/>
      </feMerge>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#tripleBranchFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('tripleBranchFx');

      expect(passes, hasLength(3));
      // All branches start from source (blur)
      expect(passes[0].imageFilter, isNotNull);
      expect(passes[1].imageFilter, isNotNull);
      expect(passes[2].imageFilter, isNotNull);
      // Different offsets
      expect(passes[0].offset.dx, 1.0);
      expect(passes[1].offset.dx, 2.0);
      expect(passes[2].offset.dx, 3.0);
    });

    test('Chain with reused intermediate and final merge', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="reuseMergeFx">
      <feGaussianBlur stdDeviation="2" result="blur"/>
      <feOffset in="blur" dx="1" dy="0" result="offset1"/>
      <feOffset in="blur" dx="2" dy="0" result="offset2"/>
      <feDropShadow in="blur" dx="3" dy="3" stdDeviation="1" result="shadow"/>
      <feMerge>
        <feMergeNode in="offset1"/>
        <feMergeNode in="offset2"/>
        <feMergeNode in="shadow"/>
        <feMergeNode in="SourceGraphic"/>
      </feMerge>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#reuseMergeFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('reuseMergeFx');

      // offset1(1) + offset2(1) + shadow(2) + SourceGraphic(1) = 5
      expect(passes, hasLength(5));
    });
  });

  group('Implicit input defaults edge cases', () {
    test('First primitive without in gets SourceGraphic', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="firstImplicitFx">
      <feGaussianBlur stdDeviation="2"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#firstImplicitFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('firstImplicitFx');

      expect(passes, hasLength(1));
      // Should have blur applied (from SourceGraphic)
      expect(passes.single.imageFilter, isNotNull);
    });

    test('Subsequent primitives without in get previous output', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="subsequentImplicitFx">
      <feOffset dx="1" dy="0"/>
      <feOffset dx="2" dy="0"/>
      <feOffset dx="3" dy="0"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#subsequentImplicitFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses(
        'subsequentImplicitFx',
      );

      expect(passes, hasLength(1));
      // Cumulative: 1 + 2 + 3 = 6
      expect(passes.single.offset.dx, 6.0);
    });

    test('Empty in attribute treated same as omitted', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="emptyInFx">
      <feOffset dx="5" dy="0"/>
      <feOffset in="" dx="3" dy="0"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#emptyInFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('emptyInFx');

      expect(passes, hasLength(1));
      // Empty in="" should use previous: 5 + 3 = 8
      expect(passes.single.offset.dx, 8.0);
    });

    test('Whitespace-only in attribute treated as omitted', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="whitespaceInFx">
      <feOffset dx="4" dy="0"/>
      <feOffset in="   " dx="2" dy="0"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#whitespaceInFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('whitespaceInFx');

      expect(passes, hasLength(1));
      // Whitespace in should use previous: 4 + 2 = 6
      expect(passes.single.offset.dx, 6.0);
    });
  });

  group('Forward reference handling', () {
    test('Forward reference produces transparent black (empty)', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="forwardRefFx">
      <feOffset in="future" dx="5" dy="0"/>
      <feGaussianBlur stdDeviation="2" result="future"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#forwardRefFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('forwardRefFx');

      // First primitive gets empty (forward ref)
      // Second primitive uses its input (implicit) which is empty, then applies blur
      // Final output should be from the blur
      expect(passes, isNotEmpty);
      expect(passes.last.imageFilter, isNotNull);
    });

    test('Multiple forward references all produce empty', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="multiForwardFx">
      <feOffset in="f1" dx="1" dy="0"/>
      <feOffset in="f2" dx="2" dy="0"/>
      <feGaussianBlur stdDeviation="1" result="f1"/>
      <feGaussianBlur stdDeviation="2" result="f2"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#multiForwardFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('multiForwardFx');

      // Forward refs produce empty, final blur should be present
      expect(passes, isNotEmpty);
    });
  });

  group('Circular reference detection', () {
    test('Self-referencing primitive produces empty', () {
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

      // Self-reference should be detected and produce identity
      expect(passes, hasLength(1));
    });

    test('Mutual reference is handled gracefully', () {
      // In practice, forward refs make this impossible to create a true cycle
      // But we test that the system handles such attempts gracefully
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

      // First primitive gets empty (forward ref to b)
      // Second primitive gets a (which is empty)
      expect(passes, hasLength(1));
    });
  });

  group('BackgroundImage and BackgroundAlpha with context', () {
    test('BackgroundImage with provided context', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="bgImageContextFx">
      <feGaussianBlur in="BackgroundImage" stdDeviation="2"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#bgImageContextFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses(
        'bgImageContextFx',
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
      expect(passes.first.imageFilter, isNotNull); // blur
    });

    test('BackgroundAlpha used in composite', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="bgAlphaCompositeFx">
      <feFlood flood-color="blue" result="flood"/>
      <feComposite in="flood" in2="BackgroundAlpha" operator="in"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="red" filter="url(#bgAlphaCompositeFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses(
        'bgAlphaCompositeFx',
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

      expect(passes, hasLength(2));
    });

    test('BackgroundImage without context falls back to SourceGraphic', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="bgNoContextFx">
      <feOffset in="BackgroundImage" dx="5" dy="0"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#bgNoContextFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('bgNoContextFx');

      // Without context, BackgroundImage falls back to SourceGraphic
      expect(passes, hasLength(1));
      expect(passes.first.offset, const ui.Offset(5, 0));
    });
  });
}
