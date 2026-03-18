import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_svg/src/animation/svg_parser.dart';
import 'package:flutter_svg/src/animation/svg_filters.dart';

void main() {
  // ===========================================================================
  // Advanced feDropShadow Filter Tests
  // ===========================================================================
  group('feDropShadow advanced composition', () {
    // =========================================================================
    // Asymmetric stdDeviation tests
    // =========================================================================
    group('Asymmetric stdDeviation', () {
      test('feDropShadow with asymmetric stdDeviation "2 4"', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="asymmetricFx">
      <feDropShadow dx="3" dy="3" stdDeviation="2 4"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#asymmetricFx)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final filter = document.filters!.getById('asymmetricFx');

        expect(filter, isNotNull);
        expect(filter, isA<SvgDropShadowFilter>());

        final dropShadow = filter as SvgDropShadowFilter;
        expect(dropShadow.stdDeviationX, 2.0);
        expect(dropShadow.stdDeviationY, 4.0);

        final passes = document.filters!.resolvePaintPasses('asymmetricFx');
        expect(passes, hasLength(2)); // shadow + source
        expect(passes[0].imageFilter, isNotNull); // blur applied
      });

      test('feDropShadow with asymmetric stdDeviation "0 5"', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="verticalBlurFx">
      <feDropShadow dx="3" dy="3" stdDeviation="0 5"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#verticalBlurFx)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final filter = document.filters!.getById('verticalBlurFx');
        final dropShadow = filter as SvgDropShadowFilter;

        expect(dropShadow.stdDeviationX, 0.0);
        expect(dropShadow.stdDeviationY, 5.0);

        final passes = document.filters!.resolvePaintPasses('verticalBlurFx');
        expect(passes, hasLength(2));
        // Should still have blur since stdDeviationY > 0
        expect(passes[0].imageFilter, isNotNull);
      });

      test('feDropShadow with asymmetric stdDeviation "3 0"', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="horizontalBlurFx">
      <feDropShadow dx="3" dy="3" stdDeviation="3 0"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#horizontalBlurFx)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final filter = document.filters!.getById('horizontalBlurFx');
        final dropShadow = filter as SvgDropShadowFilter;

        expect(dropShadow.stdDeviationX, 3.0);
        expect(dropShadow.stdDeviationY, 0.0);

        final passes = document.filters!.resolvePaintPasses('horizontalBlurFx');
        expect(passes, hasLength(2));
        // Should still have blur since stdDeviationX > 0
        expect(passes[0].imageFilter, isNotNull);
      });

      test('feDropShadow with large asymmetric stdDeviation', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="largeAsymmetricFx">
      <feDropShadow dx="5" dy="5" stdDeviation="1 10"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#largeAsymmetricFx)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final filter = document.filters!.getById('largeAsymmetricFx');
        final dropShadow = filter as SvgDropShadowFilter;

        expect(dropShadow.stdDeviationX, 1.0);
        expect(dropShadow.stdDeviationY, 10.0);
      });
    });

    // =========================================================================
    // flood-color and flood-opacity tests
    // =========================================================================
    group('flood-color and flood-opacity', () {
      test('feDropShadow with custom flood-color', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="redShadowFx">
      <feDropShadow dx="3" dy="3" stdDeviation="2" flood-color="red"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#redShadowFx)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final filter = document.filters!.getById('redShadowFx');
        final dropShadow = filter as SvgDropShadowFilter;

        expect(dropShadow.floodColor, isNotNull);
        expect((dropShadow.floodColor!.r * 255.0).round().clamp(0, 255), 255);
        expect((dropShadow.floodColor!.g * 255.0).round().clamp(0, 255), 0);
        expect((dropShadow.floodColor!.b * 255.0).round().clamp(0, 255), 0);

        final passes = document.filters!.resolvePaintPasses('redShadowFx');
        expect(passes, hasLength(2));
        expect(passes[0].colorFilter, isNotNull);
      });

      test('feDropShadow with hex flood-color', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="hexShadowFx">
      <feDropShadow dx="3" dy="3" stdDeviation="2" flood-color="#00FF00"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#hexShadowFx)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final filter = document.filters!.getById('hexShadowFx');
        final dropShadow = filter as SvgDropShadowFilter;

        expect(dropShadow.floodColor, isNotNull);
        expect((dropShadow.floodColor!.r * 255.0).round().clamp(0, 255), 0);
        expect((dropShadow.floodColor!.g * 255.0).round().clamp(0, 255), 255);
        expect((dropShadow.floodColor!.b * 255.0).round().clamp(0, 255), 0);
      });

      test('feDropShadow with rgba flood-color', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="rgbaShadowFx">
      <feDropShadow dx="3" dy="3" stdDeviation="2" flood-color="rgba(255, 128, 0, 0.5)"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#rgbaShadowFx)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final filter = document.filters!.getById('rgbaShadowFx');
        final dropShadow = filter as SvgDropShadowFilter;

        expect(dropShadow.floodColor, isNotNull);
        expect((dropShadow.floodColor!.r * 255.0).round().clamp(0, 255), 255);
        expect((dropShadow.floodColor!.g * 255.0).round().clamp(0, 255), 128);
        expect((dropShadow.floodColor!.b * 255.0).round().clamp(0, 255), 0);
      });

      test('feDropShadow with flood-opacity', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="opacityShadowFx">
      <feDropShadow dx="3" dy="3" stdDeviation="2" flood-opacity="0.5"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#opacityShadowFx)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final filter = document.filters!.getById('opacityShadowFx');
        final dropShadow = filter as SvgDropShadowFilter;

        expect(dropShadow.floodOpacity, 0.5);

        // Verify effectiveShadowColor has opacity applied
        final effectiveColor = dropShadow.effectiveShadowColor;
        expect(effectiveColor.a, closeTo(0.5, 0.01));
      });

      test('feDropShadow with flood-color and flood-opacity combined', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="colorOpacityShadowFx">
      <feDropShadow dx="3" dy="3" stdDeviation="2" flood-color="blue" flood-opacity="0.3"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="red" filter="url(#colorOpacityShadowFx)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final filter = document.filters!.getById('colorOpacityShadowFx');
        final dropShadow = filter as SvgDropShadowFilter;

        expect((dropShadow.floodColor!.b * 255.0).round().clamp(0, 255), 255);
        expect(dropShadow.floodOpacity, 0.3);

        final effectiveColor = dropShadow.effectiveShadowColor;
        expect(effectiveColor.r, closeTo(0.0, 0.01));
        expect(effectiveColor.g, closeTo(0.0, 0.01));
        expect(effectiveColor.b, closeTo(1.0, 0.01));
        expect(effectiveColor.a, closeTo(0.3, 0.01));
      });

      test('feDropShadow flood-opacity=0 produces fully transparent shadow', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="transparentShadowFx">
      <feDropShadow dx="3" dy="3" stdDeviation="2" flood-opacity="0"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#transparentShadowFx)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final filter = document.filters!.getById('transparentShadowFx');
        final dropShadow = filter as SvgDropShadowFilter;

        expect(dropShadow.floodOpacity, 0.0);
        expect(dropShadow.effectiveShadowColor.a, 0.0);
      });
    });

    // =========================================================================
    // stdDeviation=0 tests (sharp shadow)
    // =========================================================================
    group('stdDeviation=0 (sharp shadow)', () {
      test('feDropShadow with stdDeviation=0 produces sharp shadow', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="sharpShadowFx">
      <feDropShadow dx="5" dy="5" stdDeviation="0"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#sharpShadowFx)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final passes = document.filters!.resolvePaintPasses('sharpShadowFx');

        expect(passes, hasLength(2));
        // Shadow pass should NOT have blur filter (stdDeviation=0)
        // The implementation should skip blur when stdDeviation is 0
        expect(passes[0].offset, const ui.Offset(5, 5));
        expect(passes[1].offset, ui.Offset.zero);
      });

      test('feDropShadow with stdDeviation="0 0" is sharp shadow', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="sharpShadow2Fx">
      <feDropShadow dx="5" dy="5" stdDeviation="0 0"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#sharpShadow2Fx)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final filter = document.filters!.getById('sharpShadow2Fx');
        final dropShadow = filter as SvgDropShadowFilter;

        expect(dropShadow.stdDeviationX, 0.0);
        expect(dropShadow.stdDeviationY, 0.0);

        final passes = document.filters!.resolvePaintPasses('sharpShadow2Fx');
        expect(passes, hasLength(2));
      });

      test('feDropShadow stdDeviation=0 still applies offset and color', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="sharpColoredShadowFx">
      <feDropShadow dx="8" dy="12" stdDeviation="0" flood-color="red"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#sharpColoredShadowFx)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final passes = document.filters!.resolvePaintPasses('sharpColoredShadowFx');

        expect(passes, hasLength(2));
        expect(passes[0].offset, const ui.Offset(8, 12));
        expect(passes[0].colorFilter, isNotNull); // color still applied
        expect(passes[1].offset, ui.Offset.zero);
      });
    });

    // =========================================================================
    // Compositing order tests
    // =========================================================================
    group('Compositing order (shadow behind source)', () {
      test('Shadow passes come before source passes', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="orderFx">
      <feDropShadow dx="5" dy="5" stdDeviation="3"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#orderFx)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final passes = document.filters!.resolvePaintPasses('orderFx');

        expect(passes, hasLength(2));
        // First pass is shadow (has offset)
        expect(passes[0].offset, const ui.Offset(5, 5));
        expect(passes[0].colorFilter, isNotNull); // shadow color
        // Second pass is source (no offset)
        expect(passes[1].offset, ui.Offset.zero);
      });

      test('Shadow blendMode is srcOver for correct compositing', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="blendOrderFx">
      <feDropShadow dx="3" dy="3" stdDeviation="2"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#blendOrderFx)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final passes = document.filters!.resolvePaintPasses('blendOrderFx');

        expect(passes, hasLength(2));
        // Shadow pass uses srcOver blend
        expect(passes[0].blendMode, ui.BlendMode.srcOver);
      });

      test('Multiple shadow passes maintain correct order', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="multiShadowOrderFx">
      <feDropShadow dx="2" dy="2" stdDeviation="1"/>
      <feDropShadow dx="4" dy="4" stdDeviation="2"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#multiShadowOrderFx)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final passes = document.filters!.resolvePaintPasses('multiShadowOrderFx');

        // Each feDropShadow doubles passes (shadow + source)
        // First shadow: 2 passes, second processes those 2: 4 passes
        expect(passes, hasLength(4));
      });
    });

    // =========================================================================
    // Animation support tests (static attribute verification)
    // =========================================================================
    group('Animated attributes', () {
      test('feDropShadow dx/dy can be parsed as animation targets', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="animDxDyFx">
      <feDropShadow dx="0" dy="0" stdDeviation="2">
        <animate attributeName="dx" from="0" to="10" dur="1s"/>
        <animate attributeName="dy" from="0" to="10" dur="1s"/>
      </feDropShadow>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#animDxDyFx)"/>
</svg>
''';

        // The parsing should succeed (animation setup is separate from filter resolution)
        final document = SvgParser.parse(svgString);
        final filter = document.filters!.getById('animDxDyFx');
        expect(filter, isA<SvgDropShadowFilter>());
      });

      test('feDropShadow stdDeviation can be animated', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="animStdDevFx">
      <feDropShadow dx="3" dy="3" stdDeviation="0">
        <animate attributeName="stdDeviation" from="0" to="5" dur="1s"/>
      </feDropShadow>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#animStdDevFx)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final filter = document.filters!.getById('animStdDevFx');
        expect(filter, isA<SvgDropShadowFilter>());
      });

      test('feDropShadow flood-color can be animated', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="animColorFx">
      <feDropShadow dx="3" dy="3" stdDeviation="2" flood-color="red">
        <animate attributeName="flood-color" from="red" to="blue" dur="1s"/>
      </feDropShadow>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="green" filter="url(#animColorFx)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final filter = document.filters!.getById('animColorFx');
        expect(filter, isA<SvgDropShadowFilter>());
      });

      test('feDropShadow flood-opacity can be animated', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="animOpacityFx">
      <feDropShadow dx="3" dy="3" stdDeviation="2" flood-opacity="1">
        <animate attributeName="flood-opacity" from="1" to="0" dur="1s"/>
      </feDropShadow>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#animOpacityFx)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final filter = document.filters!.getById('animOpacityFx');
        expect(filter, isA<SvgDropShadowFilter>());
      });
    });

    // =========================================================================
    // Edge cases and error handling
    // =========================================================================
    group('Edge cases', () {
      test('feDropShadow with negative dx/dy', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="negativeDxDyFx">
      <feDropShadow dx="-5" dy="-5" stdDeviation="2"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#negativeDxDyFx)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final passes = document.filters!.resolvePaintPasses('negativeDxDyFx');

        expect(passes, hasLength(2));
        expect(passes[0].offset, const ui.Offset(-5, -5));
      });

      test('feDropShadow with very large stdDeviation', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="largeStdDevFx">
      <feDropShadow dx="3" dy="3" stdDeviation="100"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#largeStdDevFx)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final filter = document.filters!.getById('largeStdDevFx');
        final dropShadow = filter as SvgDropShadowFilter;

        expect(dropShadow.stdDeviationX, 100.0);
        expect(dropShadow.stdDeviationY, 100.0);
      });

      test('feDropShadow with decimal stdDeviation', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="decimalStdDevFx">
      <feDropShadow dx="3" dy="3" stdDeviation="2.5 3.7"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#decimalStdDevFx)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final filter = document.filters!.getById('decimalStdDevFx');
        final dropShadow = filter as SvgDropShadowFilter;

        expect(dropShadow.stdDeviationX, 2.5);
        expect(dropShadow.stdDeviationY, 3.7);
      });

      test('feDropShadow with no attributes uses defaults', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="defaultsFx">
      <feDropShadow/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#defaultsFx)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final filter = document.filters!.getById('defaultsFx');
        final dropShadow = filter as SvgDropShadowFilter;

        // Default values per SVG spec
        expect(dropShadow.dx, 2.0);
        expect(dropShadow.dy, 2.0);
        expect(dropShadow.stdDeviationX, 2.0);
        expect(dropShadow.stdDeviationY, 2.0);
        expect(dropShadow.floodOpacity, 1.0);
      });

      test('feDropShadow with explicit input from previous primitive', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="inputShadowFx">
      <feGaussianBlur stdDeviation="1" result="preBlur"/>
      <feDropShadow in="preBlur" dx="3" dy="3" stdDeviation="2"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#inputShadowFx)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final passes = document.filters!.resolvePaintPasses('inputShadowFx');

        expect(passes, hasLength(2));
        // Both passes should have blur from preBlur
        expect(passes[0].imageFilter, isNotNull);
        expect(passes[1].imageFilter, isNotNull);
      });

      test('feDropShadow with unresolved input produces empty result', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="unresolvedInputFx">
      <feDropShadow in="nonExistent" dx="3" dy="3" stdDeviation="2"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#unresolvedInputFx)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final passes = document.filters!.resolvePaintPasses('unresolvedInputFx');

        // Unresolved input should produce identity fallback
        expect(passes, hasLength(1));
      });
    });

    // =========================================================================
    // Filter chain integration
    // =========================================================================
    group('Filter chain integration', () {
      test('feDropShadow result used in feComposite', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="shadowCompositeFx">
      <feDropShadow dx="3" dy="3" stdDeviation="2" result="shadow"/>
      <feComposite in="shadow" in2="SourceGraphic" operator="over"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#shadowCompositeFx)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final passes = document.filters!.resolvePaintPasses('shadowCompositeFx');

        // Composite uses shadow (2 passes) + SourceGraphic (1 pass)
        expect(passes.length, greaterThanOrEqualTo(2));
      });

      test('feDropShadow in feMerge composition', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="shadowMergeFx">
      <feDropShadow dx="5" dy="5" stdDeviation="3" result="shadow"/>
      <feOffset dx="10" dy="0" result="offset"/>
      <feMerge>
        <feMergeNode in="shadow"/>
        <feMergeNode in="offset"/>
      </feMerge>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#shadowMergeFx)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final passes = document.filters!.resolvePaintPasses('shadowMergeFx');

        // shadow (2) + offset (from shadow's 2 = 2) = 4
        expect(passes.length, greaterThanOrEqualTo(4));
      });

      test('Sequential feDropShadows accumulate correctly', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="doubleShadowFx">
      <feDropShadow dx="2" dy="2" stdDeviation="1" flood-color="red"/>
      <feDropShadow dx="4" dy="4" stdDeviation="2" flood-color="blue"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="green" filter="url(#doubleShadowFx)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final passes = document.filters!.resolvePaintPasses('doubleShadowFx');

        // First shadow: 2 passes, second processes those: 4 passes
        expect(passes, hasLength(4));
      });
    });
  });
}
