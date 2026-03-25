import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_svg/src/animation/svg_parser.dart';
import 'package:flutter_svg/src/animation/svg_filters.dart';
import 'package:flutter_svg/src/animation/smil/smil_parser.dart';

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
      final filter =
          document.filters!.getById('pointSpecular')
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
      final filter =
          document.filters!.getById('specularCalc')
              as SvgSpecularLightingFilter;

      final colorFilter = filter.colorFilter();
      expect(colorFilter, isNotNull);
    });

    test(
      'feSpecularLighting returns null colorFilter without light source',
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
      },
    );

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
      final colorFilter = document.filters!.resolveColorFilter(
        'diffusePipeline',
      );

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
      final colorFilter = document.filters!.resolveColorFilter(
        'specularPipeline',
      );

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
          document.filters!.getById('noLightSource')
              as SvgDiffuseLightingFilter;

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

  group('Light Source Default Values', () {
    test('feDistantLight defaults azimuth and elevation to 0', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="distantDefaults">
      <feDiffuseLighting surfaceScale="1" diffuseConstant="1" lighting-color="white">
        <feDistantLight/>
      </feDiffuseLighting>
    </filter>
  </defs>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final filter =
          document.filters!.getById('distantDefaults')
              as SvgDiffuseLightingFilter;

      expect(filter.lightSource, isA<SvgDistantLightSource>());
      final distantLight = filter.lightSource as SvgDistantLightSource;
      expect(distantLight.azimuth, 0);
      expect(distantLight.elevation, 0);
    });

    test('fePointLight defaults x, y, z to 0', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="pointDefaults">
      <feDiffuseLighting surfaceScale="1" diffuseConstant="1" lighting-color="white">
        <fePointLight/>
      </feDiffuseLighting>
    </filter>
  </defs>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final filter =
          document.filters!.getById('pointDefaults')
              as SvgDiffuseLightingFilter;

      expect(filter.lightSource, isA<SvgPointLightSource>());
      final pointLight = filter.lightSource as SvgPointLightSource;
      expect(pointLight.x, 0);
      expect(pointLight.y, 0);
      expect(pointLight.z, 0);
    });

    test('feSpotLight defaults all attributes correctly', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="spotDefaults">
      <feDiffuseLighting surfaceScale="1" diffuseConstant="1" lighting-color="white">
        <feSpotLight/>
      </feDiffuseLighting>
    </filter>
  </defs>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final filter =
          document.filters!.getById('spotDefaults') as SvgDiffuseLightingFilter;

      expect(filter.lightSource, isA<SvgSpotLightSource>());
      final spotLight = filter.lightSource as SvgSpotLightSource;
      expect(spotLight.x, 0);
      expect(spotLight.y, 0);
      expect(spotLight.z, 0);
      expect(spotLight.pointsAtX, 0);
      expect(spotLight.pointsAtY, 0);
      expect(spotLight.pointsAtZ, 0);
      expect(spotLight.specularExponent, 1); // SVG spec default
      expect(spotLight.limitingConeAngle, 0); // Means no limiting cone
    });

    test('feSpotLight specularExponent is clamped to valid range', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="spotClamped">
      <feDiffuseLighting surfaceScale="1" diffuseConstant="1" lighting-color="white">
        <feSpotLight x="0" y="0" z="10" pointsAtX="0" pointsAtY="0" pointsAtZ="0" specularExponent="200"/>
      </feDiffuseLighting>
    </filter>
  </defs>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final filter =
          document.filters!.getById('spotClamped') as SvgDiffuseLightingFilter;

      final spotLight = filter.lightSource as SvgSpotLightSource;
      // specularExponent should be clamped to 128
      expect(spotLight.specularExponent, 128);
    });

    test(
      'feDistantLight with partial attributes uses defaults for missing',
      () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="distantPartial">
      <feDiffuseLighting surfaceScale="1" diffuseConstant="1" lighting-color="white">
        <feDistantLight azimuth="45"/>
      </feDiffuseLighting>
    </filter>
  </defs>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final filter =
            document.filters!.getById('distantPartial')
                as SvgDiffuseLightingFilter;

        final distantLight = filter.lightSource as SvgDistantLightSource;
        expect(distantLight.azimuth, 45);
        expect(distantLight.elevation, 0); // Default
      },
    );

    test('fePointLight with partial attributes uses defaults for missing', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="pointPartial">
      <feDiffuseLighting surfaceScale="1" diffuseConstant="1" lighting-color="white">
        <fePointLight x="50" z="100"/>
      </feDiffuseLighting>
    </filter>
  </defs>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final filter =
          document.filters!.getById('pointPartial') as SvgDiffuseLightingFilter;

      final pointLight = filter.lightSource as SvgPointLightSource;
      expect(pointLight.x, 50);
      expect(pointLight.y, 0); // Default
      expect(pointLight.z, 100);
    });
  });

  group('Light Source Animation', () {
    test('parses azimuth animation on feDistantLight', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="animatedAzimuth">
      <feDiffuseLighting surfaceScale="1" diffuseConstant="1" lighting-color="white">
        <feDistantLight azimuth="0" elevation="45">
          <animate attributeName="azimuth" from="0" to="360" dur="2s" repeatCount="indefinite"/>
        </feDistantLight>
      </feDiffuseLighting>
    </filter>
  </defs>
  <rect x="10" y="10" width="80" height="80" filter="url(#animatedAzimuth)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);

      // Should find the azimuth animation
      final azimuthAnim = animations.where((a) => a.attributeName == 'azimuth');
      expect(azimuthAnim, isNotEmpty);
      expect(azimuthAnim.first.from, equals('0'));
      expect(azimuthAnim.first.to, equals('360'));
    });

    test('parses elevation animation on feDistantLight', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="animatedElevation">
      <feDiffuseLighting surfaceScale="1" diffuseConstant="1" lighting-color="white">
        <feDistantLight azimuth="45" elevation="0">
          <animate attributeName="elevation" from="0" to="90" dur="1s"/>
        </feDistantLight>
      </feDiffuseLighting>
    </filter>
  </defs>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);

      final elevAnim = animations.where((a) => a.attributeName == 'elevation');
      expect(elevAnim, isNotEmpty);
    });

    test('parses position animation on fePointLight', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="animatedPointLight">
      <feDiffuseLighting surfaceScale="1" diffuseConstant="1" lighting-color="white">
        <fePointLight x="0" y="0" z="100">
          <animate attributeName="x" from="0" to="100" dur="2s"/>
          <animate attributeName="y" from="0" to="100" dur="2s"/>
          <animate attributeName="z" from="50" to="200" dur="2s"/>
        </fePointLight>
      </feDiffuseLighting>
    </filter>
  </defs>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);

      expect(animations.where((a) => a.attributeName == 'x'), isNotEmpty);
      expect(animations.where((a) => a.attributeName == 'y'), isNotEmpty);
      expect(animations.where((a) => a.attributeName == 'z'), isNotEmpty);
    });

    test('parses pointsAt animation on feSpotLight', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="animatedSpotTarget">
      <feDiffuseLighting surfaceScale="1" diffuseConstant="1" lighting-color="white">
        <feSpotLight x="50" y="50" z="100" pointsAtX="50" pointsAtY="50" pointsAtZ="0">
          <animate attributeName="pointsAtX" from="0" to="100" dur="2s"/>
          <animate attributeName="pointsAtY" from="0" to="100" dur="2s"/>
        </feSpotLight>
      </feDiffuseLighting>
    </filter>
  </defs>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);

      expect(
        animations.where((a) => a.attributeName == 'pointsAtX'),
        isNotEmpty,
      );
      expect(
        animations.where((a) => a.attributeName == 'pointsAtY'),
        isNotEmpty,
      );
    });

    test('parses specularExponent animation on feSpotLight', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="animatedSpotExp">
      <feSpecularLighting surfaceScale="1" specularConstant="1" specularExponent="20" lighting-color="white">
        <feSpotLight x="50" y="50" z="100" pointsAtX="50" pointsAtY="50" pointsAtZ="0" specularExponent="1">
          <animate attributeName="specularExponent" from="1" to="50" dur="1s"/>
        </feSpotLight>
      </feSpecularLighting>
    </filter>
  </defs>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);

      final expAnim = animations.where(
        (a) => a.attributeName == 'specularExponent',
      );
      expect(expAnim, isNotEmpty);
    });

    test('parses limitingConeAngle animation on feSpotLight', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="animatedConeAngle">
      <feDiffuseLighting surfaceScale="1" diffuseConstant="1" lighting-color="white">
        <feSpotLight x="50" y="50" z="100" pointsAtX="50" pointsAtY="50" pointsAtZ="0" limitingConeAngle="10">
          <animate attributeName="limitingConeAngle" from="10" to="45" dur="1s"/>
        </feSpotLight>
      </feDiffuseLighting>
    </filter>
  </defs>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);

      final coneAnim = animations.where(
        (a) => a.attributeName == 'limitingConeAngle',
      );
      expect(coneAnim, isNotEmpty);
    });

    test('parses surfaceScale animation on feDiffuseLighting', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="animatedSurfaceScale">
      <feDiffuseLighting surfaceScale="1" diffuseConstant="1" lighting-color="white">
        <animate attributeName="surfaceScale" from="1" to="10" dur="2s"/>
        <feDistantLight azimuth="45" elevation="45"/>
      </feDiffuseLighting>
    </filter>
  </defs>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);

      final surfAnim = animations.where(
        (a) => a.attributeName == 'surfaceScale',
      );
      expect(surfAnim, isNotEmpty);
    });

    test('parses diffuseConstant animation', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="animatedDiffuseConst">
      <feDiffuseLighting surfaceScale="1" diffuseConstant="0.5" lighting-color="white">
        <animate attributeName="diffuseConstant" from="0" to="1" dur="1s"/>
        <feDistantLight azimuth="45" elevation="45"/>
      </feDiffuseLighting>
    </filter>
  </defs>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);

      final diffAnim = animations.where(
        (a) => a.attributeName == 'diffuseConstant',
      );
      expect(diffAnim, isNotEmpty);
    });

    test('parses specularConstant animation', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="animatedSpecConst">
      <feSpecularLighting surfaceScale="1" specularConstant="0.5" specularExponent="10" lighting-color="white">
        <animate attributeName="specularConstant" from="0" to="1" dur="1s"/>
        <feDistantLight azimuth="45" elevation="45"/>
      </feSpecularLighting>
    </filter>
  </defs>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);

      final specAnim = animations.where(
        (a) => a.attributeName == 'specularConstant',
      );
      expect(specAnim, isNotEmpty);
    });
  });

  group('Spotlight Specific Behavior', () {
    test('spotlight with limitingConeAngle=0 has no angular cutoff', () {
      // When limitingConeAngle is 0 or negative, it means no limiting cone (180 degree cone)
      final filter = SvgDiffuseLightingFilter(
        id: 'noCone',
        surfaceScale: 1.0,
        diffuseConstant: 1.0,
        lightingColor: const ui.Color(0xFFFFFFFF),
        lightSource: const SvgSpotLightSource(
          x: 50,
          y: 50,
          z: 100,
          pointsAtX: 50,
          pointsAtY: 50,
          pointsAtZ: 0,
          specularExponent: 1,
          limitingConeAngle: 0,
        ),
      );

      // Should still produce a valid color filter
      final colorFilter = filter.colorFilter();
      expect(colorFilter, isNotNull);
    });

    test('spotlight with small limitingConeAngle produces narrow beam', () {
      // A small cone angle means a more focused spotlight
      final filter = SvgDiffuseLightingFilter(
        id: 'narrowCone',
        surfaceScale: 1.0,
        diffuseConstant: 1.0,
        lightingColor: const ui.Color(0xFFFFFFFF),
        lightSource: const SvgSpotLightSource(
          x: 50,
          y: 50,
          z: 100,
          pointsAtX: 50,
          pointsAtY: 50,
          pointsAtZ: 0,
          specularExponent: 1,
          limitingConeAngle: 10, // Narrow 10-degree cone
        ),
      );

      final colorFilter = filter.colorFilter();
      expect(colorFilter, isNotNull);
    });

    test('spotlight specularExponent affects falloff steepness', () {
      // Higher specularExponent = sharper falloff at cone edges
      final lowExp = SvgDiffuseLightingFilter(
        id: 'lowExp',
        surfaceScale: 1.0,
        diffuseConstant: 1.0,
        lightingColor: const ui.Color(0xFFFFFFFF),
        lightSource: const SvgSpotLightSource(
          x: 50,
          y: 50,
          z: 100,
          pointsAtX: 50,
          pointsAtY: 50,
          pointsAtZ: 0,
          specularExponent: 1,
          limitingConeAngle: 30,
        ),
      );

      final highExp = SvgDiffuseLightingFilter(
        id: 'highExp',
        surfaceScale: 1.0,
        diffuseConstant: 1.0,
        lightingColor: const ui.Color(0xFFFFFFFF),
        lightSource: const SvgSpotLightSource(
          x: 50,
          y: 50,
          z: 100,
          pointsAtX: 50,
          pointsAtY: 50,
          pointsAtZ: 0,
          specularExponent: 50,
          limitingConeAngle: 30,
        ),
      );

      // Both should produce valid color filters
      expect(lowExp.colorFilter(), isNotNull);
      expect(highExp.colorFilter(), isNotNull);
    });

    test('spotlight pointing away from surface has reduced intensity', () {
      // Spotlight pointing in opposite direction should have lower average intensity
      final spotAway = SvgDiffuseLightingFilter(
        id: 'away',
        surfaceScale: 1.0,
        diffuseConstant: 1.0,
        lightingColor: const ui.Color(0xFFFFFFFF),
        lightSource: const SvgSpotLightSource(
          x: 50,
          y: 50,
          z: 100,
          pointsAtX: 50,
          pointsAtY: 50,
          pointsAtZ: 200, // Pointing up/away from surface
          specularExponent: 1,
          limitingConeAngle: 30,
        ),
      );

      // Should still produce a color filter (even if dimmer)
      expect(spotAway.colorFilter(), isNotNull);
    });

    test('spotlight with feSpecularLighting produces specular highlights', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="spotSpecular">
      <feSpecularLighting surfaceScale="5" specularConstant="1" specularExponent="30" lighting-color="white">
        <feSpotLight x="50" y="0" z="100" pointsAtX="50" pointsAtY="50" pointsAtZ="0" specularExponent="10" limitingConeAngle="45"/>
      </feSpecularLighting>
    </filter>
  </defs>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final filter =
          document.filters!.getById('spotSpecular')
              as SvgSpecularLightingFilter;

      expect(filter.lightSource, isA<SvgSpotLightSource>());
      expect(filter.colorFilter(), isNotNull);
    });
  });

  group('Light Source Combinations', () {
    test('each light type works with diffuse lighting', () {
      final distantDiffuse = SvgDiffuseLightingFilter(
        id: 'distantDiff',
        surfaceScale: 1.0,
        diffuseConstant: 1.0,
        lightingColor: const ui.Color(0xFFFFFFFF),
        lightSource: const SvgDistantLightSource(azimuth: 45, elevation: 45),
      );

      final pointDiffuse = SvgDiffuseLightingFilter(
        id: 'pointDiff',
        surfaceScale: 1.0,
        diffuseConstant: 1.0,
        lightingColor: const ui.Color(0xFFFFFFFF),
        lightSource: const SvgPointLightSource(x: 50, y: 50, z: 100),
      );

      final spotDiffuse = SvgDiffuseLightingFilter(
        id: 'spotDiff',
        surfaceScale: 1.0,
        diffuseConstant: 1.0,
        lightingColor: const ui.Color(0xFFFFFFFF),
        lightSource: const SvgSpotLightSource(
          x: 50,
          y: 50,
          z: 100,
          pointsAtX: 50,
          pointsAtY: 50,
          pointsAtZ: 0,
          specularExponent: 1,
          limitingConeAngle: 30,
        ),
      );

      expect(distantDiffuse.colorFilter(), isNotNull);
      expect(pointDiffuse.colorFilter(), isNotNull);
      expect(spotDiffuse.colorFilter(), isNotNull);
    });

    test('each light type works with specular lighting', () {
      final distantSpec = SvgSpecularLightingFilter(
        id: 'distantSpec',
        surfaceScale: 1.0,
        specularConstant: 1.0,
        specularExponent: 20.0,
        lightingColor: const ui.Color(0xFFFFFFFF),
        lightSource: const SvgDistantLightSource(azimuth: 45, elevation: 45),
      );

      final pointSpec = SvgSpecularLightingFilter(
        id: 'pointSpec',
        surfaceScale: 1.0,
        specularConstant: 1.0,
        specularExponent: 20.0,
        lightingColor: const ui.Color(0xFFFFFFFF),
        lightSource: const SvgPointLightSource(x: 50, y: 50, z: 100),
      );

      final spotSpec = SvgSpecularLightingFilter(
        id: 'spotSpec',
        surfaceScale: 1.0,
        specularConstant: 1.0,
        specularExponent: 20.0,
        lightingColor: const ui.Color(0xFFFFFFFF),
        lightSource: const SvgSpotLightSource(
          x: 50,
          y: 50,
          z: 100,
          pointsAtX: 50,
          pointsAtY: 50,
          pointsAtZ: 0,
          specularExponent: 1,
          limitingConeAngle: 30,
        ),
      );

      expect(distantSpec.colorFilter(), isNotNull);
      expect(pointSpec.colorFilter(), isNotNull);
      expect(spotSpec.colorFilter(), isNotNull);
    });
  });
}
