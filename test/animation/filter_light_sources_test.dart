import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

import 'package:full_svg_flutter/src/animation/svg_parser.dart';
import 'package:full_svg_flutter/src/animation/svg_filters.dart';
import 'package:full_svg_flutter/src/animation/smil/smil_parser.dart';

/// Focused tests for filter light source elements (feDistantLight, fePointLight, feSpotLight).
/// These tests cover the specific requirements for light source parsing, computation, and animation.
void main() {
  group('feDistantLight with feDiffuseLighting', () {
    test('parses and computes correct light direction', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="distantDiffuse">
      <feDiffuseLighting surfaceScale="2" diffuseConstant="0.8" lighting-color="yellow">
        <feDistantLight azimuth="45" elevation="60"/>
      </feDiffuseLighting>
    </filter>
  </defs>
  <rect x="10" y="10" width="80" height="80" filter="url(#distantDiffuse)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final filter =
          document.filters!.getById('distantDiffuse')
              as SvgDiffuseLightingFilter;

      expect(filter.lightSource, isA<SvgDistantLightSource>());
      final light = filter.lightSource as SvgDistantLightSource;
      expect(light.azimuth, 45);
      expect(light.elevation, 60);

      // Verify colorFilter is computed
      expect(filter.colorFilter(), isNotNull);
    });

    test('zero elevation produces light from horizon', () {
      final filter = SvgDiffuseLightingFilter(
        id: 'horizonLight',
        surfaceScale: 1.0,
        diffuseConstant: 1.0,
        lightingColor: const ui.Color(0xFFFFFFFF),
        lightSource: const SvgDistantLightSource(azimuth: 0, elevation: 0),
      );

      // Light from horizon should produce valid but dim lighting on flat surface
      expect(filter.colorFilter(), isNotNull);
    });
  });

  group('feDistantLight with feSpecularLighting', () {
    test('parses and computes specular highlights', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="distantSpecular">
      <feSpecularLighting surfaceScale="5" specularConstant="1.5" specularExponent="30" lighting-color="white">
        <feDistantLight azimuth="135" elevation="45"/>
      </feSpecularLighting>
    </filter>
  </defs>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final filter =
          document.filters!.getById('distantSpecular')
              as SvgSpecularLightingFilter;

      expect(filter.lightSource, isA<SvgDistantLightSource>());
      expect(filter.specularConstant, 1.5);
      expect(filter.specularExponent, 30);
      expect(filter.colorFilter(), isNotNull);
    });
  });

  group('fePointLight with feDiffuseLighting', () {
    test('parses point light position', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="pointDiffuse">
      <feDiffuseLighting surfaceScale="3" diffuseConstant="1" lighting-color="blue">
        <fePointLight x="50" y="50" z="200"/>
      </feDiffuseLighting>
    </filter>
  </defs>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final filter =
          document.filters!.getById('pointDiffuse') as SvgDiffuseLightingFilter;

      expect(filter.lightSource, isA<SvgPointLightSource>());
      final light = filter.lightSource as SvgPointLightSource;
      expect(light.x, 50);
      expect(light.y, 50);
      expect(light.z, 200);
    });

    test('negative z value is supported', () {
      final filter = SvgDiffuseLightingFilter(
        id: 'negativeZ',
        surfaceScale: 1.0,
        diffuseConstant: 1.0,
        lightingColor: const ui.Color(0xFFFFFFFF),
        lightSource: const SvgPointLightSource(x: 50, y: 50, z: -10),
      );

      // Light behind surface should still produce a filter
      expect(filter.colorFilter(), isNotNull);
    });
  });

  group('fePointLight with feSpecularLighting', () {
    test('produces position-dependent specular highlights', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="pointSpecular">
      <feSpecularLighting surfaceScale="2" specularConstant="1" specularExponent="20" lighting-color="cyan">
        <fePointLight x="30" y="30" z="100"/>
      </feSpecularLighting>
    </filter>
  </defs>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final filter =
          document.filters!.getById('pointSpecular')
              as SvgSpecularLightingFilter;

      expect(filter.lightSource, isA<SvgPointLightSource>());
      expect(filter.colorFilter(), isNotNull);
    });
  });

  group('feSpotLight with feDiffuseLighting', () {
    test('parses spotlight with all attributes', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="spotDiffuse">
      <feDiffuseLighting surfaceScale="4" diffuseConstant="0.9" lighting-color="red">
        <feSpotLight x="50" y="0" z="100" pointsAtX="50" pointsAtY="50" pointsAtZ="0" 
                     specularExponent="15" limitingConeAngle="30"/>
      </feDiffuseLighting>
    </filter>
  </defs>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final filter =
          document.filters!.getById('spotDiffuse') as SvgDiffuseLightingFilter;

      expect(filter.lightSource, isA<SvgSpotLightSource>());
      final spot = filter.lightSource as SvgSpotLightSource;
      expect(spot.x, 50);
      expect(spot.y, 0);
      expect(spot.z, 100);
      expect(spot.pointsAtX, 50);
      expect(spot.pointsAtY, 50);
      expect(spot.pointsAtZ, 0);
      expect(spot.specularExponent, 15);
      expect(spot.limitingConeAngle, 30);
    });
  });

  group('feSpotLight with feSpecularLighting', () {
    test('produces cone-shaped specular highlights', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="spotSpecular">
      <feSpecularLighting surfaceScale="3" specularConstant="2" specularExponent="40" lighting-color="white">
        <feSpotLight x="50" y="50" z="150" pointsAtX="50" pointsAtY="50" pointsAtZ="0" 
                     specularExponent="20" limitingConeAngle="25"/>
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

  group('Default values when attributes omitted', () {
    test('feDistantLight uses default azimuth=0 elevation=0', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="distantDefaults">
      <feDiffuseLighting surfaceScale="1" diffuseConstant="1">
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

      final light = filter.lightSource as SvgDistantLightSource;
      expect(light.azimuth, 0);
      expect(light.elevation, 0);
    });

    test('fePointLight uses default x=0 y=0 z=0', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="pointDefaults">
      <feDiffuseLighting surfaceScale="1" diffuseConstant="1">
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

      final light = filter.lightSource as SvgPointLightSource;
      expect(light.x, 0);
      expect(light.y, 0);
      expect(light.z, 0);
    });

    test(
      'feSpotLight uses default specularExponent=1 and limitingConeAngle=0',
      () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="spotDefaults">
      <feDiffuseLighting surfaceScale="1" diffuseConstant="1">
        <feSpotLight x="50" y="50" z="100" pointsAtX="50" pointsAtY="50" pointsAtZ="0"/>
      </feDiffuseLighting>
    </filter>
  </defs>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final filter =
            document.filters!.getById('spotDefaults')
                as SvgDiffuseLightingFilter;

        final spot = filter.lightSource as SvgSpotLightSource;
        expect(spot.specularExponent, 1);
        expect(spot.limitingConeAngle, 0);
      },
    );

    test('lighting-color defaults to white', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="colorDefault">
      <feDiffuseLighting surfaceScale="1" diffuseConstant="1">
        <feDistantLight azimuth="45" elevation="45"/>
      </feDiffuseLighting>
    </filter>
  </defs>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final filter =
          document.filters!.getById('colorDefault') as SvgDiffuseLightingFilter;

      expect(filter.lightingColor, const ui.Color(0xFFFFFFFF));
    });
  });

  group('Light source animation', () {
    test('feDistantLight azimuth and elevation are animatable', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="animatedDistant">
      <feDiffuseLighting surfaceScale="1" diffuseConstant="1" lighting-color="white">
        <feDistantLight azimuth="0" elevation="45">
          <animate attributeName="azimuth" from="0" to="360" dur="4s" repeatCount="indefinite"/>
          <animate attributeName="elevation" from="0" to="90" dur="2s" fill="freeze"/>
        </feDistantLight>
      </feDiffuseLighting>
    </filter>
  </defs>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);

      final azimuthAnim = animations
          .where((a) => a.attributeName == 'azimuth')
          .toList();
      final elevAnim = animations
          .where((a) => a.attributeName == 'elevation')
          .toList();

      expect(azimuthAnim, isNotEmpty);
      expect(elevAnim, isNotEmpty);
      expect(azimuthAnim.first.from, 0.0);
      expect(azimuthAnim.first.to, 360.0);
    });

    test('fePointLight x, y, z are animatable', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="animatedPoint">
      <feDiffuseLighting surfaceScale="1" diffuseConstant="1">
        <fePointLight x="0" y="50" z="100">
          <animate attributeName="x" from="0" to="100" dur="3s"/>
          <animate attributeName="y" from="0" to="100" dur="3s"/>
          <animate attributeName="z" from="50" to="200" dur="3s"/>
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

    test('feSpotLight pointsAt and cone attributes are animatable', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="animatedSpot">
      <feDiffuseLighting surfaceScale="1" diffuseConstant="1">
        <feSpotLight x="50" y="50" z="100" pointsAtX="50" pointsAtY="50" pointsAtZ="0" 
                     specularExponent="10" limitingConeAngle="30">
          <animate attributeName="pointsAtX" from="0" to="100" dur="2s"/>
          <animate attributeName="pointsAtY" from="0" to="100" dur="2s"/>
          <animate attributeName="specularExponent" from="1" to="50" dur="2s"/>
          <animate attributeName="limitingConeAngle" from="10" to="60" dur="2s"/>
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
      expect(
        animations.where((a) => a.attributeName == 'specularExponent'),
        isNotEmpty,
      );
      expect(
        animations.where((a) => a.attributeName == 'limitingConeAngle'),
        isNotEmpty,
      );
    });
  });

  group('Multiple light types in same filter', () {
    test('only first light source is used when multiple present', () {
      // SVG spec says only the first light source child is used
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="multipleLight">
      <feDiffuseLighting surfaceScale="1" diffuseConstant="1">
        <feDistantLight azimuth="45" elevation="60"/>
        <fePointLight x="50" y="50" z="100"/>
        <feSpotLight x="0" y="0" z="50" pointsAtX="50" pointsAtY="50" pointsAtZ="0"/>
      </feDiffuseLighting>
    </filter>
  </defs>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final filter =
          document.filters!.getById('multipleLight')
              as SvgDiffuseLightingFilter;

      // Should use the first light source (feDistantLight)
      expect(filter.lightSource, isA<SvgDistantLightSource>());
      final light = filter.lightSource as SvgDistantLightSource;
      expect(light.azimuth, 45);
      expect(light.elevation, 60);
    });

    test('different light types in separate filters work independently', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="filter1">
      <feDiffuseLighting surfaceScale="1" diffuseConstant="1">
        <feDistantLight azimuth="90" elevation="45"/>
      </feDiffuseLighting>
    </filter>
    <filter id="filter2">
      <feDiffuseLighting surfaceScale="1" diffuseConstant="1">
        <fePointLight x="100" y="100" z="50"/>
      </feDiffuseLighting>
    </filter>
    <filter id="filter3">
      <feSpecularLighting surfaceScale="1" specularConstant="1" specularExponent="10">
        <feSpotLight x="50" y="50" z="100" pointsAtX="50" pointsAtY="50" pointsAtZ="0"/>
      </feSpecularLighting>
    </filter>
  </defs>
</svg>
''';

      final document = SvgParser.parse(svgString);

      final f1 =
          document.filters!.getById('filter1') as SvgDiffuseLightingFilter;
      final f2 =
          document.filters!.getById('filter2') as SvgDiffuseLightingFilter;
      final f3 =
          document.filters!.getById('filter3') as SvgSpecularLightingFilter;

      expect(f1.lightSource, isA<SvgDistantLightSource>());
      expect(f2.lightSource, isA<SvgPointLightSource>());
      expect(f3.lightSource, isA<SvgSpotLightSource>());
    });
  });

  group('Edge cases', () {
    test('zero elevation creates horizontal light', () {
      final light = const SvgDistantLightSource(azimuth: 0, elevation: 0);
      final (dir, _) = light.getDirectionAndIntensityAt(0, 0, 0);

      // Light from horizon has z ≈ 0
      expect(dir.z, closeTo(0, 0.01));
    });

    test('90 degree elevation creates light from directly above', () {
      final light = const SvgDistantLightSource(azimuth: 0, elevation: 90);
      final (dir, _) = light.getDirectionAndIntensityAt(0, 0, 0);

      // Light from above has z ≈ 1
      expect(dir.z, closeTo(1.0, 0.01));
    });

    test('negative z for point light (light below surface)', () {
      final light = const SvgPointLightSource(x: 0, y: 0, z: -50);
      final (dir, intensity) = light.getDirectionAndIntensityAt(0, 0, 0);

      // Light below surface points downward (negative z in direction)
      expect(dir.z, lessThan(0));
      expect(intensity, greaterThan(0));
    });

    test('spotlight with very narrow cone angle', () {
      final filter = SvgDiffuseLightingFilter(
        id: 'narrowSpot',
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
          limitingConeAngle: 5, // Very narrow 5-degree cone
        ),
      );

      expect(filter.colorFilter(), isNotNull);
    });

    test('spotlight specularExponent clamped to 1-128 range', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="clampedExp">
      <feDiffuseLighting surfaceScale="1" diffuseConstant="1">
        <feSpotLight x="50" y="50" z="100" pointsAtX="50" pointsAtY="50" pointsAtZ="0" 
                     specularExponent="500"/>
      </feDiffuseLighting>
    </filter>
  </defs>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final filter =
          document.filters!.getById('clampedExp') as SvgDiffuseLightingFilter;

      final spot = filter.lightSource as SvgSpotLightSource;
      expect(spot.specularExponent, 128); // Clamped to max
    });

    test('point light at same position as surface point', () {
      final light = const SvgPointLightSource(x: 50, y: 50, z: 0);
      final (dir, _) = light.getDirectionAndIntensityAt(50, 50, 0);

      // When light is at surface, direction should default to up
      expect(dir.z, equals(1.0));
    });

    test('no light source produces null colorFilter', () {
      final diffuse = SvgDiffuseLightingFilter(
        id: 'noLight1',
        surfaceScale: 1.0,
        diffuseConstant: 1.0,
        lightingColor: const ui.Color(0xFFFFFFFF),
        lightSource: null,
      );

      final specular = SvgSpecularLightingFilter(
        id: 'noLight2',
        surfaceScale: 1.0,
        specularConstant: 1.0,
        specularExponent: 20,
        lightingColor: const ui.Color(0xFFFFFFFF),
        lightSource: null,
      );

      expect(diffuse.colorFilter(), isNull);
      expect(specular.colorFilter(), isNull);
    });
  });
}
