import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_svg/src/animation/svg_filters.dart';
import 'package:flutter_svg/src/animation/svg_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('feDistantLight parsing', () {
    test('parses default azimuth and elevation (0, 0)', () {
      const svg = '''
        <svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">
          <defs>
            <filter id="f1">
              <feDiffuseLighting surfaceScale="1" diffuseConstant="1">
                <feDistantLight/>
              </feDiffuseLighting>
            </filter>
          </defs>
          <rect width="100" height="100" filter="url(#f1)"/>
        </svg>
      ''';

      final svgDoc = SvgParser.parse(svg);
      expect(svgDoc.filters, isNotNull);
      final primitives = svgDoc.filters!.getAllById('f1');
      expect(primitives, hasLength(1));
      final lighting = primitives.first as SvgDiffuseLightingFilter;
      final light = lighting.lightSource;
      expect(light, isA<SvgDistantLightSource>());
      final distant = light as SvgDistantLightSource;
      expect(distant.azimuth, equals(0.0));
      expect(distant.elevation, equals(0.0));
    });

    test('parses azimuth 45 and elevation 30', () {
      const svg = '''
        <svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">
          <defs>
            <filter id="f1">
              <feDiffuseLighting surfaceScale="1" diffuseConstant="1">
                <feDistantLight azimuth="45" elevation="30"/>
              </feDiffuseLighting>
            </filter>
          </defs>
          <rect width="100" height="100" filter="url(#f1)"/>
        </svg>
      ''';

      final svgDoc = SvgParser.parse(svg);
      final lighting =
          svgDoc.filters!.getAllById('f1').first as SvgDiffuseLightingFilter;
      final distant = lighting.lightSource as SvgDistantLightSource;
      expect(distant.azimuth, equals(45.0));
      expect(distant.elevation, equals(30.0));
    });

    test('parses negative azimuth and elevation', () {
      const svg = '''
        <svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">
          <defs>
            <filter id="f1">
              <feDiffuseLighting surfaceScale="1" diffuseConstant="1">
                <feDistantLight azimuth="-90" elevation="-45"/>
              </feDiffuseLighting>
            </filter>
          </defs>
          <rect width="100" height="100" filter="url(#f1)"/>
        </svg>
      ''';

      final svgDoc = SvgParser.parse(svg);
      final lighting =
          svgDoc.filters!.getAllById('f1').first as SvgDiffuseLightingFilter;
      final distant = lighting.lightSource as SvgDistantLightSource;
      expect(distant.azimuth, equals(-90.0));
      expect(distant.elevation, equals(-45.0));
    });
  });

  group('fePointLight parsing', () {
    test('parses default x, y, z (0, 0, 0)', () {
      const svg = '''
        <svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">
          <defs>
            <filter id="f1">
              <feDiffuseLighting surfaceScale="1" diffuseConstant="1">
                <fePointLight/>
              </feDiffuseLighting>
            </filter>
          </defs>
          <rect width="100" height="100" filter="url(#f1)"/>
        </svg>
      ''';

      final svgDoc = SvgParser.parse(svg);
      final lighting =
          svgDoc.filters!.getAllById('f1').first as SvgDiffuseLightingFilter;
      final light = lighting.lightSource;
      expect(light, isA<SvgPointLightSource>());
      final point = light as SvgPointLightSource;
      expect(point.x, equals(0.0));
      expect(point.y, equals(0.0));
      expect(point.z, equals(0.0));
    });

    test('parses x, y, z coordinates', () {
      const svg = '''
        <svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">
          <defs>
            <filter id="f1">
              <feDiffuseLighting surfaceScale="1" diffuseConstant="1">
                <fePointLight x="50" y="50" z="100"/>
              </feDiffuseLighting>
            </filter>
          </defs>
          <rect width="100" height="100" filter="url(#f1)"/>
        </svg>
      ''';

      final svgDoc = SvgParser.parse(svg);
      final lighting =
          svgDoc.filters!.getAllById('f1').first as SvgDiffuseLightingFilter;
      final point = lighting.lightSource as SvgPointLightSource;
      expect(point.x, equals(50.0));
      expect(point.y, equals(50.0));
      expect(point.z, equals(100.0));
    });

    test('parses negative coordinates', () {
      const svg = '''
        <svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">
          <defs>
            <filter id="f1">
              <feDiffuseLighting surfaceScale="1" diffuseConstant="1">
                <fePointLight x="-25.5" y="-10" z="200"/>
              </feDiffuseLighting>
            </filter>
          </defs>
          <rect width="100" height="100" filter="url(#f1)"/>
        </svg>
      ''';

      final svgDoc = SvgParser.parse(svg);
      final lighting =
          svgDoc.filters!.getAllById('f1').first as SvgDiffuseLightingFilter;
      final point = lighting.lightSource as SvgPointLightSource;
      expect(point.x, equals(-25.5));
      expect(point.y, equals(-10.0));
      expect(point.z, equals(200.0));
    });
  });

  group('feSpotLight parsing', () {
    test('parses all attributes including limitingConeAngle', () {
      const svg = '''
        <svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">
          <defs>
            <filter id="f1">
              <feSpecularLighting surfaceScale="1" specularConstant="1" specularExponent="10">
                <feSpotLight x="50" y="50" z="100" pointsAtX="25" pointsAtY="25" pointsAtZ="0" specularExponent="2" limitingConeAngle="30"/>
              </feSpecularLighting>
            </filter>
          </defs>
          <rect width="100" height="100" filter="url(#f1)"/>
        </svg>
      ''';

      final svgDoc = SvgParser.parse(svg);
      final lighting =
          svgDoc.filters!.getAllById('f1').first as SvgSpecularLightingFilter;
      final light = lighting.lightSource;
      expect(light, isA<SvgSpotLightSource>());
      final spot = light as SvgSpotLightSource;
      expect(spot.x, equals(50.0));
      expect(spot.y, equals(50.0));
      expect(spot.z, equals(100.0));
      expect(spot.pointsAtX, equals(25.0));
      expect(spot.pointsAtY, equals(25.0));
      expect(spot.pointsAtZ, equals(0.0));
      expect(spot.specularExponent, equals(2.0));
      expect(spot.limitingConeAngle, equals(30.0));
    });

    test('parses default specularExponent (1) and no limitingConeAngle', () {
      const svg = '''
        <svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">
          <defs>
            <filter id="f1">
              <feDiffuseLighting surfaceScale="1" diffuseConstant="1">
                <feSpotLight x="0" y="0" z="50" pointsAtX="50" pointsAtY="50" pointsAtZ="0"/>
              </feDiffuseLighting>
            </filter>
          </defs>
          <rect width="100" height="100" filter="url(#f1)"/>
        </svg>
      ''';

      final svgDoc = SvgParser.parse(svg);
      final lighting =
          svgDoc.filters!.getAllById('f1').first as SvgDiffuseLightingFilter;
      final spot = lighting.lightSource as SvgSpotLightSource;
      expect(spot.specularExponent, equals(1.0));
      expect(spot.limitingConeAngle, equals(0.0));
    });

    test('clamps specularExponent to [1, 128]', () {
      const svg = '''
        <svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">
          <defs>
            <filter id="f1">
              <feDiffuseLighting surfaceScale="1" diffuseConstant="1">
                <feSpotLight x="0" y="0" z="50" pointsAtX="50" pointsAtY="50" pointsAtZ="0" specularExponent="200"/>
              </feDiffuseLighting>
            </filter>
          </defs>
          <rect width="100" height="100" filter="url(#f1)"/>
        </svg>
      ''';

      final svgDoc = SvgParser.parse(svg);
      final lighting =
          svgDoc.filters!.getAllById('f1').first as SvgDiffuseLightingFilter;
      final spot = lighting.lightSource as SvgSpotLightSource;
      expect(spot.specularExponent, equals(128.0));
    });
  });

  group('Distant light vector computation', () {
    test('azimuth=0, elevation=0 points in +X direction', () {
      final (lx, ly, lz) = computeDistantLightVector(0, 0);
      expect(lx, closeTo(1.0, 0.0001));
      expect(ly, closeTo(0.0, 0.0001));
      expect(lz, closeTo(0.0, 0.0001));
    });

    test('azimuth=90, elevation=0 points in +Y direction', () {
      final (lx, ly, lz) = computeDistantLightVector(90, 0);
      expect(lx, closeTo(0.0, 0.0001));
      expect(ly, closeTo(1.0, 0.0001));
      expect(lz, closeTo(0.0, 0.0001));
    });

    test(
      'azimuth=0, elevation=90 points in +Z direction (light from above)',
      () {
        final (lx, ly, lz) = computeDistantLightVector(0, 90);
        expect(lx, closeTo(0.0, 0.0001));
        expect(ly, closeTo(0.0, 0.0001));
        expect(lz, closeTo(1.0, 0.0001));
      },
    );

    test('azimuth=45, elevation=45 has correct components', () {
      final (lx, ly, lz) = computeDistantLightVector(45, 45);
      final expectedLx =
          math.cos(45 * math.pi / 180) * math.cos(45 * math.pi / 180);
      final expectedLy =
          math.sin(45 * math.pi / 180) * math.cos(45 * math.pi / 180);
      final expectedLz = math.sin(45 * math.pi / 180);
      final len = math.sqrt(
        expectedLx * expectedLx +
            expectedLy * expectedLy +
            expectedLz * expectedLz,
      );
      expect(lx, closeTo(expectedLx / len, 0.0001));
      expect(ly, closeTo(expectedLy / len, 0.0001));
      expect(lz, closeTo(expectedLz / len, 0.0001));
    });

    test('result is normalized (length = 1)', () {
      final (lx, ly, lz) = computeDistantLightVector(37, 23);
      final length = math.sqrt(lx * lx + ly * ly + lz * lz);
      expect(length, closeTo(1.0, 0.0001));
    });
  });

  group('Point light vector computation', () {
    test('light directly above surface point', () {
      final (lx, ly, lz) = computePointLightVector(50, 50, 100, 50, 50, 0);
      expect(lx, closeTo(0.0, 0.0001));
      expect(ly, closeTo(0.0, 0.0001));
      expect(lz, closeTo(1.0, 0.0001));
    });

    test('light to the right of surface point', () {
      final (lx, ly, lz) = computePointLightVector(100, 0, 0, 0, 0, 0);
      expect(lx, closeTo(1.0, 0.0001));
      expect(ly, closeTo(0.0, 0.0001));
      expect(lz, closeTo(0.0, 0.0001));
    });

    test('light at diagonal position', () {
      final (lx, ly, lz) = computePointLightVector(10, 10, 10, 0, 0, 0);
      final len = math.sqrt(10 * 10 * 3);
      expect(lx, closeTo(10 / len, 0.0001));
      expect(ly, closeTo(10 / len, 0.0001));
      expect(lz, closeTo(10 / len, 0.0001));
    });

    test('result is normalized', () {
      final (lx, ly, lz) = computePointLightVector(123, 456, 789, 10, 20, 30);
      final length = math.sqrt(lx * lx + ly * ly + lz * lz);
      expect(length, closeTo(1.0, 0.0001));
    });

    test('coincident points return default direction', () {
      final (lx, ly, lz) = computePointLightVector(50, 50, 50, 50, 50, 50);
      expect(lx, closeTo(0.0, 0.0001));
      expect(ly, closeTo(0.0, 0.0001));
      expect(lz, closeTo(1.0, 0.0001));
    });
  });

  group('Spot light cone attenuation', () {
    test('surface point inside cone has positive intensity', () {
      final ((lx, ly, lz), intensity) = computeSpotLightVector(
        0,
        0,
        100,
        0,
        0,
        0,
        0,
        0,
        0,
        specularExponent: 1.0,
        limitingConeAngleDegrees: 45.0,
      );
      expect(intensity, greaterThan(0.0));
      expect(lz, closeTo(1.0, 0.0001));
    });

    test('surface point outside cone has zero intensity', () {
      final (_, intensity) = computeSpotLightVector(
        0,
        0,
        100,
        0,
        0,
        0,
        1000,
        0,
        0,
        specularExponent: 1.0,
        limitingConeAngleDegrees: 10.0,
      );
      expect(intensity, equals(0.0));
    });

    test('surface at edge of cone has reduced intensity', () {
      final surfaceX = math.sin(45 * math.pi / 180) * 100;
      final surfaceZ = math.cos(45 * math.pi / 180) * 100;

      final (_, intensityInside) = computeSpotLightVector(
        0,
        0,
        0,
        0,
        0,
        100,
        surfaceX * 0.99,
        0,
        surfaceZ,
        specularExponent: 1.0,
        limitingConeAngleDegrees: 45.0,
      );
      expect(intensityInside, greaterThan(0.0));
    });

    test('specularExponent affects falloff', () {
      final (_, intensity1) = computeSpotLightVector(
        0,
        0,
        100,
        0,
        0,
        0,
        20,
        20,
        0,
        specularExponent: 1.0,
        limitingConeAngleDegrees: 90.0,
      );
      final (_, intensity2) = computeSpotLightVector(
        0,
        0,
        100,
        0,
        0,
        0,
        20,
        20,
        0,
        specularExponent: 4.0,
        limitingConeAngleDegrees: 90.0,
      );
      expect(intensity2, lessThan(intensity1));
    });

    test('no cone cutoff when limitingConeAngle is 0', () {
      final (_, intensity) = computeSpotLightVector(
        0,
        0,
        100,
        0,
        0,
        0,
        500,
        500,
        0,
        specularExponent: 1.0,
        limitingConeAngleDegrees: 0.0,
      );
      expect(intensity, greaterThan(0.0));
    });
  });

  group('Integration: feDiffuseLighting with light sources', () {
    testWidgets('renders with feDistantLight without error', (tester) async {
      const svg = '''
        <svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">
          <defs>
            <filter id="f1">
              <feDiffuseLighting in="SourceGraphic" surfaceScale="5" diffuseConstant="1" lighting-color="white">
                <feDistantLight azimuth="45" elevation="45"/>
              </feDiffuseLighting>
            </filter>
          </defs>
          <rect x="10" y="10" width="80" height="80" fill="blue" filter="url(#f1)"/>
        </svg>
      ''';

      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: SvgPicture.string(svg))),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('renders with fePointLight without error', (tester) async {
      const svg = '''
        <svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">
          <defs>
            <filter id="f1">
              <feDiffuseLighting in="SourceGraphic" surfaceScale="5" diffuseConstant="1" lighting-color="yellow">
                <fePointLight x="50" y="50" z="100"/>
              </feDiffuseLighting>
            </filter>
          </defs>
          <circle cx="50" cy="50" r="40" fill="red" filter="url(#f1)"/>
        </svg>
      ''';

      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: SvgPicture.string(svg))),
      );

      expect(tester.takeException(), isNull);
    });
  });

  group('Integration: feSpecularLighting with light sources', () {
    testWidgets('renders with fePointLight without error', (tester) async {
      const svg = '''
        <svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">
          <defs>
            <filter id="f1">
              <feSpecularLighting in="SourceGraphic" surfaceScale="5" specularConstant="1" specularExponent="20" lighting-color="white">
                <fePointLight x="50" y="0" z="50"/>
              </feSpecularLighting>
            </filter>
          </defs>
          <rect x="10" y="10" width="80" height="80" fill="green" filter="url(#f1)"/>
        </svg>
      ''';

      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: SvgPicture.string(svg))),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('renders with feSpotLight without error', (tester) async {
      const svg = '''
        <svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">
          <defs>
            <filter id="f1">
              <feSpecularLighting in="SourceGraphic" surfaceScale="5" specularConstant="1" specularExponent="20" lighting-color="white">
                <feSpotLight x="50" y="50" z="100" pointsAtX="50" pointsAtY="50" pointsAtZ="0" specularExponent="3" limitingConeAngle="30"/>
              </feSpecularLighting>
            </filter>
          </defs>
          <ellipse cx="50" cy="50" rx="40" ry="30" fill="purple" filter="url(#f1)"/>
        </svg>
      ''';

      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: SvgPicture.string(svg))),
      );

      expect(tester.takeException(), isNull);
    });
  });

  group('Default values when attributes omitted', () {
    test('feDistantLight defaults azimuth and elevation to 0', () {
      const svg = '''
        <svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">
          <defs>
            <filter id="f1">
              <feDiffuseLighting surfaceScale="1" diffuseConstant="1">
                <feDistantLight/>
              </feDiffuseLighting>
            </filter>
          </defs>
          <rect width="100" height="100" filter="url(#f1)"/>
        </svg>
      ''';

      final svgDoc = SvgParser.parse(svg);
      final lighting =
          svgDoc.filters!.getAllById('f1').first as SvgDiffuseLightingFilter;
      final distant = lighting.lightSource as SvgDistantLightSource;
      expect(distant.azimuth, equals(0.0));
      expect(distant.elevation, equals(0.0));
    });

    test('fePointLight defaults x, y, z to 0', () {
      const svg = '''
        <svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">
          <defs>
            <filter id="f1">
              <feDiffuseLighting surfaceScale="1" diffuseConstant="1">
                <fePointLight/>
              </feDiffuseLighting>
            </filter>
          </defs>
          <rect width="100" height="100" filter="url(#f1)"/>
        </svg>
      ''';

      final svgDoc = SvgParser.parse(svg);
      final lighting =
          svgDoc.filters!.getAllById('f1').first as SvgDiffuseLightingFilter;
      final point = lighting.lightSource as SvgPointLightSource;
      expect(point.x, equals(0.0));
      expect(point.y, equals(0.0));
      expect(point.z, equals(0.0));
    });

    test('feSpotLight defaults pointsAt to 0 and specularExponent to 1', () {
      const svg = '''
        <svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">
          <defs>
            <filter id="f1">
              <feDiffuseLighting surfaceScale="1" diffuseConstant="1">
                <feSpotLight x="50" y="50" z="100"/>
              </feDiffuseLighting>
            </filter>
          </defs>
          <rect width="100" height="100" filter="url(#f1)"/>
        </svg>
      ''';

      final svgDoc = SvgParser.parse(svg);
      final lighting =
          svgDoc.filters!.getAllById('f1').first as SvgDiffuseLightingFilter;
      final spot = lighting.lightSource as SvgSpotLightSource;
      expect(spot.pointsAtX, equals(0.0));
      expect(spot.pointsAtY, equals(0.0));
      expect(spot.pointsAtZ, equals(0.0));
      expect(spot.specularExponent, equals(1.0));
      expect(spot.limitingConeAngle, equals(0.0));
    });
  });

  group('Multiple light sources', () {
    test('only first light source is used (per SVG spec)', () {
      const svg = '''
        <svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">
          <defs>
            <filter id="f1">
              <feDiffuseLighting surfaceScale="1" diffuseConstant="1">
                <feDistantLight azimuth="10" elevation="20"/>
                <fePointLight x="100" y="100" z="100"/>
                <feSpotLight x="50" y="50" z="50" pointsAtX="25" pointsAtY="25" pointsAtZ="0"/>
              </feDiffuseLighting>
            </filter>
          </defs>
          <rect width="100" height="100" filter="url(#f1)"/>
        </svg>
      ''';

      final svgDoc = SvgParser.parse(svg);
      final lighting =
          svgDoc.filters!.getAllById('f1').first as SvgDiffuseLightingFilter;
      // Parser returns first light source found (per SVG spec)
      expect(lighting.lightSource, isA<SvgDistantLightSource>());
    });
  });
}
