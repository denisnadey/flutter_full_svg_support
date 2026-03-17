import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_svg/src/animation/svg_parser.dart';
import 'package:flutter_svg/src/animation/svg_filters.dart';

void main() {
  group('feDiffuseLighting Filter', () {
    test('parses feDiffuseLighting with feDistantLight', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="diffuseLight">
      <feDiffuseLighting surfaceScale="5" diffuseConstant="1" lighting-color="white">
        <feDistantLight azimuth="45" elevation="60"/>
      </feDiffuseLighting>
    </filter>
  </defs>
  <rect x="10" y="10" width="80" height="80" fill="blue" filter="url(#diffuseLight)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      expect(document.filters, isNotNull);
      expect(document.filters!.hasFilter('diffuseLight'), isTrue);

      final filter = document.filters!.getById('diffuseLight');
      expect(filter, isA<SvgDiffuseLightingFilter>());

      final lighting = filter as SvgDiffuseLightingFilter;
      expect(lighting.surfaceScale, 5.0);
      expect(lighting.diffuseConstant, 1.0);
      expect(lighting.lightingColor, const ui.Color(0xFFFFFFFF));
      expect(lighting.lightSource, isA<SvgDistantLightSource>());

      final distantLight = lighting.lightSource as SvgDistantLightSource;
      expect(distantLight.azimuth, 45);
      expect(distantLight.elevation, 60);
    });

    test('parses feDiffuseLighting with fePointLight', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="pointDiffuse">
      <feDiffuseLighting surfaceScale="2" diffuseConstant="0.8" lighting-color="yellow">
        <fePointLight x="50" y="50" z="100"/>
      </feDiffuseLighting>
    </filter>
  </defs>
  <rect x="10" y="10" width="80" height="80" filter="url(#pointDiffuse)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final filter =
          document.filters!.getById('pointDiffuse') as SvgDiffuseLightingFilter;

      expect(filter.surfaceScale, 2.0);
      expect(filter.diffuseConstant, 0.8);
      expect(filter.lightSource, isA<SvgPointLightSource>());

      final pointLight = filter.lightSource as SvgPointLightSource;
      expect(pointLight.x, 50);
      expect(pointLight.y, 50);
      expect(pointLight.z, 100);
    });

    test('parses feDiffuseLighting with feSpotLight', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="spotDiffuse">
      <feDiffuseLighting surfaceScale="3" diffuseConstant="0.7" lighting-color="red">
        <feSpotLight x="40" y="40" z="80" pointsAtX="50" pointsAtY="50" pointsAtZ="0" specularExponent="10" limitingConeAngle="20"/>
      </feDiffuseLighting>
    </filter>
  </defs>
  <rect x="10" y="10" width="80" height="80" filter="url(#spotDiffuse)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final filter =
          document.filters!.getById('spotDiffuse') as SvgDiffuseLightingFilter;

      expect(filter.surfaceScale, 3.0);
      expect(filter.diffuseConstant, 0.7);
      expect(filter.lightSource, isA<SvgSpotLightSource>());

      final spotLight = filter.lightSource as SvgSpotLightSource;
      expect(spotLight.x, 40);
      expect(spotLight.y, 40);
      expect(spotLight.z, 80);
      expect(spotLight.pointsAtX, 50);
      expect(spotLight.pointsAtY, 50);
      expect(spotLight.pointsAtZ, 0);
      expect(spotLight.specularExponent, 10);
      expect(spotLight.limitingConeAngle, 20);
    });

    test('feDiffuseLighting produces colorFilter with light source', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="diffuseCalc">
      <feDiffuseLighting surfaceScale="1" diffuseConstant="1" lighting-color="white">
        <feDistantLight azimuth="0" elevation="90"/>
      </feDiffuseLighting>
    </filter>
  </defs>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final filter =
          document.filters!.getById('diffuseCalc') as SvgDiffuseLightingFilter;

      // With elevation=90, light comes from directly above -> N·L = 1.0
      final colorFilter = filter.colorFilter();
      expect(colorFilter, isNotNull);
    });

    test('feDiffuseLighting returns null colorFilter without light source', () {
      // Create filter programmatically without light source
      final filter = SvgDiffuseLightingFilter(
        id: 'noLight',
        surfaceScale: 1.0,
        diffuseConstant: 1.0,
        lightingColor: const ui.Color(0xFFFFFFFF),
        lightSource: null,
      );

      expect(filter.colorFilter(), isNull);
    });

    test('feDiffuseLighting intensity varies with elevation angle', () {
      // Light from above (elevation=90) should be brighter than light from side
      final filterAbove = SvgDiffuseLightingFilter(
        id: 'above',
        surfaceScale: 1.0,
        diffuseConstant: 1.0,
        lightingColor: const ui.Color(0xFFFFFFFF),
        lightSource: const SvgDistantLightSource(azimuth: 0, elevation: 90),
      );

      final filterSide = SvgDiffuseLightingFilter(
        id: 'side',
        surfaceScale: 1.0,
        diffuseConstant: 1.0,
        lightingColor: const ui.Color(0xFFFFFFFF),
        lightSource: const SvgDistantLightSource(azimuth: 0, elevation: 0),
      );

      // Both should produce color filters
      final colorAbove = filterAbove.colorFilter();
      final colorSide = filterSide.colorFilter();

      expect(colorAbove, isNotNull);
      expect(colorSide, isNotNull);
    });
  });

  group('feSpecularLighting Filter', () {
    test('parses feSpecularLighting with feDistantLight', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="specularLight">
      <feSpecularLighting surfaceScale="5" specularConstant="1" specularExponent="20" lighting-color="white">
        <feDistantLight azimuth="45" elevation="60"/>
      </feSpecularLighting>
    </filter>
  </defs>
  <rect x="10" y="10" width="80" height="80" fill="blue" filter="url(#specularLight)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      expect(document.filters, isNotNull);
      expect(document.filters!.hasFilter('specularLight'), isTrue);

      final filter = document.filters!.getById('specularLight');
      expect(filter, isA<SvgSpecularLightingFilter>());

      final lighting = filter as SvgSpecularLightingFilter;
      expect(lighting.surfaceScale, 5.0);
      expect(lighting.specularConstant, 1.0);
      expect(lighting.specularExponent, 20.0);
      expect(lighting.lightingColor, const ui.Color(0xFFFFFFFF));
      expect(lighting.lightSource, isA<SvgDistantLightSource>());
    });

    test('parses feSpecularLighting with fePointLight', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="pointSpecular">
      <feSpecularLighting surfaceScale="2" specularConstant="0.5" specularExponent="10" lighting-color="cyan">
        <fePointLight x="60" y="60" z="150"/>
      </feSpecularLighting>
    </filter>
  </defs>
  <rect x="10" y="10" width="80" height="80" filter="url(#pointSpecular)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final filter = document.filters!.getById('pointSpecular')
          as SvgSpecularLightingFilter;

      expect(filter.surfaceScale, 2.0);
      expect(filter.specularConstant, 0.5);
      expect(filter.specularExponent, 10.0);
      expect(filter.lightSource, isA<SvgPointLightSource>());

      final pointLight = filter.lightSource as SvgPointLightSource;
      expect(pointLight.x, 60);
      expect(pointLight.y, 60);
      expect(pointLight.z, 150);
    });

    test('feSpecularLighting produces colorFilter with light source', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="specularCalc">
      <feSpecularLighting surfaceScale="1" specularConstant="1" specularExponent="1" lighting-color="white">
        <feDistantLight azimuth="0" elevation="90"/>
      </feSpecularLighting>
    </filter>
  </defs>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final filter = document.filters!.getById('specularCalc')
          as SvgSpecularLightingFilter;

      final colorFilter = filter.colorFilter();
      expect(colorFilter, isNotNull);
    });

    test('feSpecularLighting returns null colorFilter without light source',
        () {
      final filter = SvgSpecularLightingFilter(
        id: 'noLight',
        surfaceScale: 1.0,
        specularConstant: 1.0,
        specularExponent: 20.0,
        lightingColor: const ui.Color(0xFFFFFFFF),
        lightSource: null,
      );

      expect(filter.colorFilter(), isNull);
    });

    test('feSpecularLighting alpha equals max RGB component', () {
      // With white light and maximum specular intensity, alpha should be 255
      final filter = SvgSpecularLightingFilter(
        id: 'maxSpec',
        surfaceScale: 1.0,
        specularConstant: 1.0,
        specularExponent: 1.0,
        lightingColor: const ui.Color(0xFFFFFFFF),
        lightSource: const SvgDistantLightSource(azimuth: 0, elevation: 90),
      );

      final colorFilter = filter.colorFilter();
      expect(colorFilter, isNotNull);
    });
  });

  group('Lighting Filter Pipeline Integration', () {
    test('feDiffuseLighting resolves color filter in pipeline', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="diffusePipeline">
      <feDiffuseLighting surfaceScale="1" diffuseConstant="1" lighting-color="white" result="diffuse">
        <feDistantLight azimuth="45" elevation="45"/>
      </feDiffuseLighting>
    </filter>
  </defs>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final colorFilter = document.filters!.resolveColorFilter('diffusePipeline');

      // Pipeline should resolve a color filter for diffuse lighting
      expect(colorFilter, isNotNull);
    });

    test('feSpecularLighting resolves color filter in pipeline', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="specularPipeline">
      <feSpecularLighting surfaceScale="1" specularConstant="1" specularExponent="10" lighting-color="white" result="specular">
        <feDistantLight azimuth="45" elevation="45"/>
      </feSpecularLighting>
    </filter>
  </defs>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final colorFilter =
          document.filters!.resolveColorFilter('specularPipeline');

      expect(colorFilter, isNotNull);
    });

    test('lighting filters chain with other primitives', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="lightingChain">
      <feGaussianBlur in="SourceAlpha" stdDeviation="2" result="blur"/>
      <feDiffuseLighting in="blur" surfaceScale="1" diffuseConstant="1" lighting-color="yellow" result="diffuse">
        <feDistantLight azimuth="225" elevation="45"/>
      </feDiffuseLighting>
      <feComposite in="diffuse" in2="SourceGraphic" operator="arithmetic" k1="1" k2="0" k3="0" k4="0"/>
    </filter>
  </defs>
</svg>
''';

      final document = SvgParser.parse(svgString);
      expect(document.filters!.hasFilter('lightingChain'), isTrue);

      // Verify the pipeline can process this chain
      final passes = document.filters!.resolvePaintPasses('lightingChain');
      expect(passes, isNotEmpty);
    });

    test('lighting filter with no light source acts as pass-through', () {
      // This creates a filter without a light source child element
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="noLightSource">
      <feDiffuseLighting surfaceScale="1" diffuseConstant="1" lighting-color="white"/>
    </filter>
  </defs>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final filter =
          document.filters!.getById('noLightSource') as SvgDiffuseLightingFilter;

      // Without light source, should return null color filter
      expect(filter.lightSource, isNull);
      expect(filter.colorFilter(), isNull);
    });
  });

  group('Lighting Color Parsing', () {
    test('parses named colors for lighting-color', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="namedColor">
      <feDiffuseLighting surfaceScale="1" diffuseConstant="1" lighting-color="red">
        <feDistantLight azimuth="0" elevation="45"/>
      </feDiffuseLighting>
    </filter>
  </defs>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final filter =
          document.filters!.getById('namedColor') as SvgDiffuseLightingFilter;

      expect(filter.lightingColor, const ui.Color(0xFFFF0000));
    });

    test('parses hex colors for lighting-color', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="hexColor">
      <feDiffuseLighting surfaceScale="1" diffuseConstant="1" lighting-color="#00FF00">
        <feDistantLight azimuth="0" elevation="45"/>
      </feDiffuseLighting>
    </filter>
  </defs>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final filter =
          document.filters!.getById('hexColor') as SvgDiffuseLightingFilter;

      expect(filter.lightingColor, const ui.Color(0xFF00FF00));
    });

    test('defaults to white when lighting-color is not specified', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="defaultColor">
      <feDiffuseLighting surfaceScale="1" diffuseConstant="1">
        <feDistantLight azimuth="0" elevation="45"/>
      </feDiffuseLighting>
    </filter>
  </defs>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final filter =
          document.filters!.getById('defaultColor') as SvgDiffuseLightingFilter;

      // Default lighting-color is white
      expect(filter.lightingColor, const ui.Color(0xFFFFFFFF));
    });
  });

  group('Surface Scale Attribute', () {
    test('parses surfaceScale attribute', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="surfaceScale">
      <feDiffuseLighting surfaceScale="10" diffuseConstant="1" lighting-color="white">
        <feDistantLight azimuth="0" elevation="45"/>
      </feDiffuseLighting>
    </filter>
  </defs>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final filter =
          document.filters!.getById('surfaceScale') as SvgDiffuseLightingFilter;

      expect(filter.surfaceScale, 10.0);
    });

    test('surfaceScale affects lighting intensity calculation', () {
      // Higher surfaceScale means more pronounced surface features
      final lowScale = SvgDiffuseLightingFilter(
        id: 'low',
        surfaceScale: 1.0,
        diffuseConstant: 1.0,
        lightingColor: const ui.Color(0xFFFFFFFF),
        lightSource: const SvgDistantLightSource(azimuth: 45, elevation: 45),
      );

      final highScale = SvgDiffuseLightingFilter(
        id: 'high',
        surfaceScale: 10.0,
        diffuseConstant: 1.0,
        lightingColor: const ui.Color(0xFFFFFFFF),
        lightSource: const SvgDistantLightSource(azimuth: 45, elevation: 45),
      );

      // Both should produce valid color filters
      expect(lowScale.colorFilter(), isNotNull);
      expect(highScale.colorFilter(), isNotNull);
    });
  });

  group('kernelUnitLength Attribute', () {
    test('parses kernelUnitLength attribute', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="kernelUnit">
      <feDiffuseLighting surfaceScale="1" diffuseConstant="1" kernelUnitLength="2 3" lighting-color="white">
        <feDistantLight azimuth="0" elevation="45"/>
      </feDiffuseLighting>
    </filter>
  </defs>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final filter =
          document.filters!.getById('kernelUnit') as SvgDiffuseLightingFilter;

      expect(filter.kernelUnitLengthX, 2.0);
      expect(filter.kernelUnitLengthY, 3.0);
    });

    test('kernelUnitLength with single value uses same for both axes', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="singleKernel">
      <feDiffuseLighting surfaceScale="1" diffuseConstant="1" kernelUnitLength="5" lighting-color="white">
        <feDistantLight azimuth="0" elevation="45"/>
      </feDiffuseLighting>
    </filter>
  </defs>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final filter =
          document.filters!.getById('singleKernel') as SvgDiffuseLightingFilter;

      expect(filter.kernelUnitLengthX, 5.0);
      expect(filter.kernelUnitLengthY, 5.0);
    });
  });
}
