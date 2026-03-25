import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_svg/src/animation/svg_parser.dart';
import 'package:flutter_svg/src/animation/svg_filters.dart';

void main() {
  group('SVG Filters Parsing', () {
    test('Parse feGaussianBlur filter', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="blur">
      <feGaussianBlur stdDeviation="5"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#blur)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      expect(document.filters, isNotNull);
      expect(document.filters!.hasFilter('blur'), isTrue);

      final filter = document.filters!.getById('blur');
      expect(filter, isNotNull);
      expect(filter!.type.toString(), contains('gaussianBlur'));
    });

    test('Parse feMorphology filter', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="morphFx">
      <feMorphology operator="dilate" radius="2 3" in="SourceGraphic" result="morphOut"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#morphFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      expect(document.filters, isNotNull);
      expect(document.filters!.hasFilter('morphFx'), isTrue);

      final filter = document.filters!.getById('morphFx');
      expect(filter, isNotNull);
      expect(filter, isA<SvgMorphologyFilter>());
      expect(filter!.type, SvgFilterType.morphology);
      final morphology = filter as SvgMorphologyFilter;
      expect(morphology.operatorType, SvgMorphologyOperator.dilate);
      expect(morphology.radiusX, 2);
      expect(morphology.radiusY, 3);
      expect(morphology.input, 'SourceGraphic');
      expect(morphology.resultName, 'morphOut');
    });

    test('Parse feDisplacementMap filter', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="dispFx">
      <feDisplacementMap
        in="SourceGraphic"
        in2="noiseMap"
        scale="12"
        xChannelSelector="R"
        yChannelSelector="B"
        result="dispOut"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#dispFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      expect(document.filters, isNotNull);
      expect(document.filters!.hasFilter('dispFx'), isTrue);

      final filter = document.filters!.getById('dispFx');
      expect(filter, isNotNull);
      expect(filter, isA<SvgDisplacementMapFilter>());
      expect(filter!.type, SvgFilterType.displacementMap);
      final displacement = filter as SvgDisplacementMapFilter;
      expect(displacement.scale, 12.0);
      expect(displacement.xChannelSelector, SvgChannelSelector.r);
      expect(displacement.yChannelSelector, SvgChannelSelector.b);
      expect(displacement.input, 'SourceGraphic');
      expect(displacement.input2, 'noiseMap');
      expect(displacement.resultName, 'dispOut');
    });

    test('Parse feImage filter', () {
      final svgString = '''
<svg viewBox="0 0 100 100" xmlns:xlink="http://www.w3.org/1999/xlink">
  <defs>
    <filter id="imgFx">
      <feImage
        xlink:href="data:image/png;base64,AAAA"
        x="4"
        y="5"
        width="16"
        height="18"
        preserveAspectRatio="none"
        result="imgOut"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#imgFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      expect(document.filters, isNotNull);
      expect(document.filters!.hasFilter('imgFx'), isTrue);

      final filter = document.filters!.getById('imgFx');
      expect(filter, isNotNull);
      expect(filter, isA<SvgFeImageFilter>());
      expect(filter!.type, SvgFilterType.image);
      final image = filter as SvgFeImageFilter;
      expect(image.href, 'data:image/png;base64,AAAA');
      expect(image.x, 4.0);
      expect(image.y, 5.0);
      expect(image.width, 16.0);
      expect(image.height, 18.0);
      expect(image.preserveAspectRatio, 'none');
      expect(image.resultName, 'imgOut');
    });

    test('Parse feConvolveMatrix filter', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="convFx">
      <feConvolveMatrix
        in="SourceGraphic"
        order="3 5"
        kernelMatrix="1 0 -1 2 0 -2 1 0 -1 2 0 -2 1 0 -1"
        divisor="2"
        bias="0.5"
        targetX="1"
        targetY="2"
        edgeMode="wrap"
        kernelUnitLength="2 3"
        preserveAlpha="true"
        result="convOut"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#convFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      expect(document.filters, isNotNull);
      expect(document.filters!.hasFilter('convFx'), isTrue);

      final filter = document.filters!.getById('convFx');
      expect(filter, isNotNull);
      expect(filter, isA<SvgConvolveMatrixFilter>());
      expect(filter!.type, SvgFilterType.convolveMatrix);
      final convolve = filter as SvgConvolveMatrixFilter;
      expect(convolve.orderX, 3);
      expect(convolve.orderY, 5);
      expect(convolve.kernelMatrix.length, 15);
      expect(convolve.divisor, 2.0);
      expect(convolve.bias, 0.5);
      expect(convolve.targetX, 1);
      expect(convolve.targetY, 2);
      expect(convolve.edgeMode, SvgConvolveEdgeMode.wrap);
      expect(convolve.kernelUnitLengthX, 2.0);
      expect(convolve.kernelUnitLengthY, 3.0);
      expect(convolve.preserveAlpha, isTrue);
      expect(convolve.input, 'SourceGraphic');
      expect(convolve.resultName, 'convOut');
    });

    test('Parse feTurbulence filter', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="noiseFx">
      <feTurbulence
        type="fractalNoise"
        baseFrequency="0.025 0.05"
        numOctaves="4"
        seed="7"
        stitchTiles="stitch"
        result="noiseOut"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#noiseFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      expect(document.filters, isNotNull);
      expect(document.filters!.hasFilter('noiseFx'), isTrue);

      final filter = document.filters!.getById('noiseFx');
      expect(filter, isNotNull);
      expect(filter, isA<SvgTurbulenceFilter>());
      expect(filter!.type, SvgFilterType.turbulence);
      final turbulence = filter as SvgTurbulenceFilter;
      expect(turbulence.baseFrequencyX, closeTo(0.025, 0.000001));
      expect(turbulence.baseFrequencyY, closeTo(0.05, 0.000001));
      expect(turbulence.numOctaves, 4);
      expect(turbulence.seed, 7.0);
      expect(turbulence.stitchTiles, SvgTurbulenceStitchTiles.stitch);
      expect(turbulence.noiseType, SvgTurbulenceType.fractalNoise);
      expect(turbulence.resultName, 'noiseOut');
    });

    test('Parse feComponentTransfer filter', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="compTransferFx">
      <feComponentTransfer in="SourceGraphic" result="compOut">
        <feFuncR type="linear" slope="1.2" intercept="0.1"/>
        <feFuncG type="gamma" amplitude="0.8" exponent="2.2" offset="0.05"/>
        <feFuncB type="table" tableValues="0 0.5 1"/>
        <feFuncA type="discrete" tableValues="0 1"/>
      </feComponentTransfer>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#compTransferFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      expect(document.filters, isNotNull);
      expect(document.filters!.hasFilter('compTransferFx'), isTrue);

      final filter = document.filters!.getById('compTransferFx');
      expect(filter, isNotNull);
      expect(filter, isA<SvgComponentTransferFilter>());
      expect(filter!.type, SvgFilterType.componentTransfer);

      final componentTransfer = filter as SvgComponentTransferFilter;
      expect(componentTransfer.input, 'SourceGraphic');
      expect(componentTransfer.resultName, 'compOut');
      expect(componentTransfer.funcR?.type, SvgComponentTransferType.linear);
      expect(componentTransfer.funcR?.slope, closeTo(1.2, 0.000001));
      expect(componentTransfer.funcR?.intercept, closeTo(0.1, 0.000001));
      expect(componentTransfer.funcG?.type, SvgComponentTransferType.gamma);
      expect(componentTransfer.funcG?.amplitude, closeTo(0.8, 0.000001));
      expect(componentTransfer.funcG?.exponent, closeTo(2.2, 0.000001));
      expect(componentTransfer.funcG?.offset, closeTo(0.05, 0.000001));
      expect(componentTransfer.funcB?.type, SvgComponentTransferType.table);
      expect(componentTransfer.funcB?.tableValues, <double>[0, 0.5, 1]);
      expect(componentTransfer.funcA?.type, SvgComponentTransferType.discrete);
      expect(componentTransfer.funcA?.tableValues, <double>[0, 1]);
    });

    test('Parse feDiffuseLighting filter', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="lightFx">
      <feDiffuseLighting
        in="SourceAlpha"
        x="4"
        y="5"
        width="60"
        height="70"
        surfaceScale="2"
        diffuseConstant="1.5"
        kernelUnitLength="2 3"
        lighting-color="#336699"
        result="litOut">
        <fePointLight x="1" y="2" z="3"/>
      </feDiffuseLighting>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#lightFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      expect(document.filters, isNotNull);
      expect(document.filters!.hasFilter('lightFx'), isTrue);

      final filter = document.filters!.getById('lightFx');
      expect(filter, isNotNull);
      expect(filter, isA<SvgDiffuseLightingFilter>());
      expect(filter!.type, SvgFilterType.diffuseLighting);

      final diffuse = filter as SvgDiffuseLightingFilter;
      expect(diffuse.input, 'SourceAlpha');
      expect(diffuse.resultName, 'litOut');
      expect(diffuse.x, 4.0);
      expect(diffuse.y, 5.0);
      expect(diffuse.width, 60.0);
      expect(diffuse.height, 70.0);
      expect(diffuse.surfaceScale, 2.0);
      expect(diffuse.diffuseConstant, 1.5);
      expect(diffuse.kernelUnitLengthX, 2.0);
      expect(diffuse.kernelUnitLengthY, 3.0);
      expect(diffuse.lightingColor, const ui.Color(0xFF336699));
      expect(diffuse.lightSource, isA<SvgPointLightSource>());
      final pointLight = diffuse.lightSource as SvgPointLightSource;
      expect(pointLight.x, 1.0);
      expect(pointLight.y, 2.0);
      expect(pointLight.z, 3.0);
    });

    test('Parse feSpecularLighting filter', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="specFx">
      <feSpecularLighting
        in="SourceAlpha"
        x="6"
        y="7"
        width="50"
        height="55"
        surfaceScale="3"
        specularConstant="2"
        specularExponent="80"
        kernelUnitLength="1.5 2.5"
        lighting-color="rgb(255, 200, 128)"
        result="specOut">
        <feSpotLight
          x="1"
          y="2"
          z="3"
          pointsAtX="4"
          pointsAtY="5"
          pointsAtZ="6"
          specularExponent="12"
          limitingConeAngle="25"/>
      </feSpecularLighting>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#specFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      expect(document.filters, isNotNull);
      expect(document.filters!.hasFilter('specFx'), isTrue);

      final filter = document.filters!.getById('specFx');
      expect(filter, isNotNull);
      expect(filter, isA<SvgSpecularLightingFilter>());
      expect(filter!.type, SvgFilterType.specularLighting);

      final specular = filter as SvgSpecularLightingFilter;
      expect(specular.input, 'SourceAlpha');
      expect(specular.resultName, 'specOut');
      expect(specular.x, 6.0);
      expect(specular.y, 7.0);
      expect(specular.width, 50.0);
      expect(specular.height, 55.0);
      expect(specular.surfaceScale, 3.0);
      expect(specular.specularConstant, 2.0);
      expect(specular.specularExponent, 80.0);
      expect(specular.kernelUnitLengthX, 1.5);
      expect(specular.kernelUnitLengthY, 2.5);
      expect(specular.lightingColor, const ui.Color(0xFFFFC880));
      expect(specular.lightSource, isA<SvgSpotLightSource>());
      final spot = specular.lightSource as SvgSpotLightSource;
      expect(spot.x, 1.0);
      expect(spot.y, 2.0);
      expect(spot.z, 3.0);
      expect(spot.pointsAtX, 4.0);
      expect(spot.pointsAtY, 5.0);
      expect(spot.pointsAtZ, 6.0);
      expect(spot.specularExponent, 12.0);
      expect(spot.limitingConeAngle, 25.0);
    });

    test('Parse feDropShadow filter', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="shadow">
      <feDropShadow
        dx="2"
        dy="2"
        stdDeviation="3 5"
        flood-color="black"
        flood-opacity="0.25"
        in="SourceGraphic"
        result="shadowOut"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#shadow)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      expect(document.filters, isNotNull);
      expect(document.filters!.hasFilter('shadow'), isTrue);

      final filter = document.filters!.getById('shadow');
      expect(filter, isNotNull);
      expect(filter!.type.toString(), contains('dropShadow'));
      expect(filter, isA<SvgDropShadowFilter>());
      final shadow = filter as SvgDropShadowFilter;
      expect(shadow.stdDeviationX, 3);
      expect(shadow.stdDeviationY, 5);
      expect(shadow.floodOpacity, closeTo(0.25, 0.0001));
      expect(shadow.input, 'SourceGraphic');
      expect(shadow.resultName, 'shadowOut');
    });

    test('Parse feDropShadow style fallback overrides attributes', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="shadowStyle">
      <feDropShadow
        dx="1"
        dy="1"
        stdDeviation="1"
        flood-color="#ff0000"
        flood-opacity="1"
        style="dx: 4; dy: 6; stdDeviation: 7 9; flood-color: #00ff00 !important; flood-opacity: 0.4 !important"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#shadowStyle)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final filter = document.filters!.getById('shadowStyle');

      expect(filter, isNotNull);
      expect(filter, isA<SvgDropShadowFilter>());
      final shadow = filter as SvgDropShadowFilter;
      expect(shadow.dx, 4);
      expect(shadow.dy, 6);
      expect(shadow.stdDeviationX, 7);
      expect(shadow.stdDeviationY, 9);
      expect(shadow.floodColor, const ui.Color(0xFF00FF00));
      expect(shadow.floodOpacity, closeTo(0.4, 0.0001));
    });

    test('Parse feDropShadow style fallback supports std-deviation name', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="shadowStyleHyphen">
      <feDropShadow
        style="dx: 5; dy: 3; std-deviation: 8 2; flood-color: #123456; flood-opacity: 0.75"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#shadowStyleHyphen)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final filter = document.filters!.getById('shadowStyleHyphen');

      expect(filter, isNotNull);
      expect(filter, isA<SvgDropShadowFilter>());
      final shadow = filter as SvgDropShadowFilter;
      expect(shadow.dx, 5);
      expect(shadow.dy, 3);
      expect(shadow.stdDeviationX, 8);
      expect(shadow.stdDeviationY, 2);
      expect(shadow.floodColor, const ui.Color(0xFF123456));
      expect(shadow.floodOpacity, closeTo(0.75, 0.0001));
    });

    test('Parse feOffset filter', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="offsetFilter">
      <feOffset dx="4" dy="6"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#offsetFilter)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      expect(document.filters, isNotNull);
      expect(document.filters!.hasFilter('offsetFilter'), isTrue);

      final filter = document.filters!.getById('offsetFilter');
      expect(filter, isNotNull);
      expect(filter!.type.toString(), contains('offset'));
    });

    test('Parse feColorMatrix filter with saturate', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="grayscale">
      <feColorMatrix type="saturate" values="0"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#grayscale)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      expect(document.filters, isNotNull);
      expect(document.filters!.hasFilter('grayscale'), isTrue);

      final filter = document.filters!.getById('grayscale');
      expect(filter, isNotNull);
      expect(filter!.type.toString(), contains('colorMatrix'));
    });

    test('Parse feColorMatrix filter with hueRotate', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="hueRotateFx">
      <feColorMatrix type="hueRotate" values="90"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#hueRotateFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      expect(document.filters, isNotNull);
      expect(document.filters!.hasFilter('hueRotateFx'), isTrue);

      final filter = document.filters!.getById('hueRotateFx');
      expect(filter, isNotNull);
      expect(filter, isA<SvgColorMatrixFilter>());
      final colorMatrix = filter as SvgColorMatrixFilter;
      expect(colorMatrix.matrixType, SvgColorMatrixType.hueRotate);
      expect(colorMatrix.values, <double>[90.0]);
    });

    test('Parse feColorMatrix filter with luminanceToAlpha', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="luminanceToAlphaFx">
      <feColorMatrix type="luminanceToAlpha"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#luminanceToAlphaFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      expect(document.filters, isNotNull);
      expect(document.filters!.hasFilter('luminanceToAlphaFx'), isTrue);

      final filter = document.filters!.getById('luminanceToAlphaFx');
      expect(filter, isNotNull);
      expect(filter, isA<SvgColorMatrixFilter>());
      final colorMatrix = filter as SvgColorMatrixFilter;
      expect(colorMatrix.matrixType, SvgColorMatrixType.luminanceToAlpha);
    });

    test('Parse feColorMatrix filter with custom matrix', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="customMatrixFx">
      <feColorMatrix type="matrix" values="1 0 0 0 0  0 1 0 0 0  0 0 1 0 0  0 0 0 1 0"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#customMatrixFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      expect(document.filters, isNotNull);
      expect(document.filters!.hasFilter('customMatrixFx'), isTrue);

      final filter = document.filters!.getById('customMatrixFx');
      expect(filter, isNotNull);
      expect(filter, isA<SvgColorMatrixFilter>());
      final colorMatrix = filter as SvgColorMatrixFilter;
      expect(colorMatrix.matrixType, SvgColorMatrixType.matrix);
      expect(colorMatrix.values, hasLength(20));
    });

    test('Parse feFlood filter', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="floodFx">
      <feFlood flood-color="#00ff00" flood-opacity="0.5"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#floodFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      expect(document.filters, isNotNull);
      expect(document.filters!.hasFilter('floodFx'), isTrue);

      final filter = document.filters!.getById('floodFx');
      expect(filter, isNotNull);
      expect(filter, isA<SvgFloodFilter>());
      expect(filter!.type, SvgFilterType.flood);
      final flood = filter as SvgFloodFilter;
      expect(flood.floodColor, const ui.Color(0xFF00FF00));
      expect(flood.floodOpacity, closeTo(0.5, 0.0001));
    });

    test('Parse feFlood style fallback overrides attributes', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="floodStyleFx">
      <feFlood
        flood-color="#ff0000"
        flood-opacity="1"
        style="flood-color: #123456 !important; flood-opacity: 0.25 !important"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#floodStyleFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final filter = document.filters!.getById('floodStyleFx');

      expect(filter, isNotNull);
      expect(filter, isA<SvgFloodFilter>());
      final flood = filter as SvgFloodFilter;
      expect(flood.floodColor, const ui.Color(0xFF123456));
      expect(flood.floodOpacity, closeTo(0.25, 0.0001));
    });

    test('Parse feBlend filter', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="blendFx">
      <feBlend mode="multiply"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#blendFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      expect(document.filters, isNotNull);
      expect(document.filters!.hasFilter('blendFx'), isTrue);

      final filter = document.filters!.getById('blendFx');
      expect(filter, isNotNull);
      expect(filter, isA<SvgBlendFilter>());
      expect(filter!.type, SvgFilterType.blend);
      expect((filter as SvgBlendFilter).mode, ui.BlendMode.multiply);
    });

    test('Parse feBlend SVG2 mode variants', () {
      const expectedModes = <String, ui.BlendMode>{
        'overlay': ui.BlendMode.overlay,
        'color-dodge': ui.BlendMode.colorDodge,
        'color-burn': ui.BlendMode.colorBurn,
        'hard-light': ui.BlendMode.hardLight,
        'soft-light': ui.BlendMode.softLight,
        'difference': ui.BlendMode.difference,
        'exclusion': ui.BlendMode.exclusion,
        'hue': ui.BlendMode.hue,
        'saturation': ui.BlendMode.saturation,
        'color': ui.BlendMode.color,
        'luminosity': ui.BlendMode.luminosity,
      };

      expectedModes.forEach((modeName, blendMode) {
        expect(parseSvgBlendMode(modeName), blendMode, reason: modeName);
      });

      // Case-insensitive mode parsing remains supported.
      expect(parseSvgBlendMode('COLOR-DODGE'), ui.BlendMode.colorDodge);
    });

    test('Parse feComposite filter', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="compFx">
      <feComposite operator="xor"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#compFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      expect(document.filters, isNotNull);
      expect(document.filters!.hasFilter('compFx'), isTrue);

      final filter = document.filters!.getById('compFx');
      expect(filter, isNotNull);
      expect(filter, isA<SvgCompositeFilter>());
      expect(filter!.type, SvgFilterType.composite);
      final composite = filter as SvgCompositeFilter;
      expect(composite.operatorType, 'xor');
      expect(composite.mode, ui.BlendMode.xor);
    });

    test('Parse feComposite filter with operator="out"', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="compOutFx">
      <feComposite in="SourceGraphic" in2="SourceAlpha" operator="out"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#compOutFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      expect(document.filters, isNotNull);
      expect(document.filters!.hasFilter('compOutFx'), isTrue);

      final filter = document.filters!.getById('compOutFx');
      expect(filter, isNotNull);
      expect(filter, isA<SvgCompositeFilter>());
      final composite = filter as SvgCompositeFilter;
      expect(composite.operatorType, 'out');
      expect(composite.mode, ui.BlendMode.srcOut);
      expect(composite.input, 'SourceGraphic');
      expect(composite.input2, 'SourceAlpha');
    });

    test('Parse feComposite filter with operator="lighter"', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="compLighterFx">
      <feComposite in="SourceGraphic" in2="SourceAlpha" operator="lighter"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#compLighterFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      expect(document.filters, isNotNull);
      expect(document.filters!.hasFilter('compLighterFx'), isTrue);

      final filter = document.filters!.getById('compLighterFx');
      expect(filter, isNotNull);
      expect(filter, isA<SvgCompositeFilter>());
      final composite = filter as SvgCompositeFilter;
      expect(composite.operatorType, 'lighter');
      expect(composite.mode, ui.BlendMode.plus);
    });

    test('Parse feComposite arithmetic filter coefficients', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="compArithmeticFx">
      <feComposite
        in="SourceGraphic"
        in2="BackgroundImage"
        operator="arithmetic"
        k1="0"
        k2="1"
        k3="1"
        k4="0.2"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#compArithmeticFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      expect(document.filters, isNotNull);
      expect(document.filters!.hasFilter('compArithmeticFx'), isTrue);

      final filter = document.filters!.getById('compArithmeticFx');
      expect(filter, isNotNull);
      expect(filter, isA<SvgCompositeFilter>());
      final composite = filter as SvgCompositeFilter;
      expect(composite.operatorType, 'arithmetic');
      expect(composite.mode, isNull);
      expect(composite.k1, 0.0);
      expect(composite.k2, 1.0);
      expect(composite.k3, 1.0);
      expect(composite.k4, 0.2);
      expect(composite.input, 'SourceGraphic');
      expect(composite.input2, 'BackgroundImage');
    });

    test('Parse feMerge filter with feMergeNode inputs', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="mergeFx">
      <feMerge>
        <feMergeNode in="SourceGraphic"/>
        <feMergeNode in="BackgroundImage"/>
      </feMerge>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#mergeFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      expect(document.filters, isNotNull);
      expect(document.filters!.hasFilter('mergeFx'), isTrue);

      final filter = document.filters!.getById('mergeFx');
      expect(filter, isNotNull);
      expect(filter, isA<SvgMergeFilter>());
      expect(filter!.type, SvgFilterType.merge);
      final merge = filter as SvgMergeFilter;
      expect(merge.nodeCount, 2);
      expect(merge.nodeInputs, <String?>['SourceGraphic', 'BackgroundImage']);
    });

    test('Parse feTile filter', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="tileFx">
      <feTile in="SourceGraphic"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#tileFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      expect(document.filters, isNotNull);
      expect(document.filters!.hasFilter('tileFx'), isTrue);

      final filter = document.filters!.getById('tileFx');
      expect(filter, isNotNull);
      expect(filter, isA<SvgTileFilter>());
      expect(filter!.type, SvgFilterType.tile);
      expect((filter as SvgTileFilter).input, 'SourceGraphic');
    });

    test('Composes multi-primitive filter chain in declaration order', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="chainFx">
      <feGaussianBlur stdDeviation="1"/>
      <feOffset dx="2" dy="3"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#chainFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      expect(document.filters, isNotNull);
      expect(document.filters!.hasFilter('chainFx'), isTrue);

      final items = document.filters!.getAllById('chainFx');
      expect(items, hasLength(2));
      expect(items.first, isA<SvgGaussianBlurFilter>());
      expect(items.last, isA<SvgOffsetFilter>());
      expect(document.filters!.resolveImageFilter('chainFx'), isNotNull);
    });

    test('Resolve feMorphology as image filter pass', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="morphFx">
      <feMorphology operator="erode" radius="1"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#morphFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('morphFx');

      expect(passes, hasLength(1));
      expect(passes.single.imageFilter, isNotNull);
    });

    test('Resolve feDisplacementMap as pass-through of in input', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="dispFx">
      <feOffset dx="6" dy="0" result="shifted"/>
      <feDisplacementMap in="shifted" in2="SourceGraphic" scale="20"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#dispFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('dispFx');

      expect(passes, hasLength(1));
      expect(passes.single.offset, const ui.Offset(6, 0));
    });

    test('Resolve feDisplacementMap skips unresolved explicit in2', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="dispFxMissingIn2">
      <feOffset dx="6" dy="0" result="shifted"/>
      <feDisplacementMap in="shifted" in2="missingMap" scale="20"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#dispFxMissingIn2)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('dispFxMissingIn2');

      expect(passes, hasLength(1));
      expect(passes.single.offset, ui.Offset.zero);
      expect(passes.single.imageFilter, isNull);
      expect(passes.single.colorFilter, isNull);
    });

    test('Resolve feDisplacementMap accepts explicit none in2 input', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="dispFxNoneIn2">
      <feOffset dx="6" dy="0" result="shifted"/>
      <feDisplacementMap in="shifted" in2="none" scale="20"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#dispFxNoneIn2)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('dispFxNoneIn2');

      expect(passes, hasLength(1));
      expect(passes.single.offset, const ui.Offset(6, 0));
      expect(passes.single.imageFilter, isNull);
    });

    test(
      'Resolve feDisplacementMap accepts mixed-case explicit none in2 input',
      () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="dispFxMixedNoneIn2">
      <feOffset dx="7" dy="0" result="shifted"/>
      <feDisplacementMap in="shifted" in2="NoNe" scale="20"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#dispFxMixedNoneIn2)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final passes = document.filters!.resolvePaintPasses(
          'dispFxMixedNoneIn2',
        );

        expect(passes, hasLength(1));
        expect(passes.single.offset, const ui.Offset(7, 0));
        expect(passes.single.imageFilter, isNull);
      },
    );

    test(
      'Resolve feDisplacementMap with scale=0 ignores unresolved explicit in2',
      () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="dispFxZeroScale">
      <feOffset dx="6" dy="0" result="shifted"/>
      <feDisplacementMap in="shifted" in2="missingMap" scale="0"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#dispFxZeroScale)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final passes = document.filters!.resolvePaintPasses('dispFxZeroScale');

        expect(passes, hasLength(1));
        expect(passes.single.offset, const ui.Offset(6, 0));
        expect(passes.single.imageFilter, isNull);
      },
    );

    test(
      'Resolve feDisplacementMap accepts BackgroundAlpha as explicit in2',
      () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="dispFxBackgroundAlpha">
      <feOffset dx="8" dy="0" result="shifted"/>
      <feDisplacementMap in="shifted" in2="BackgroundAlpha" scale="10"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#dispFxBackgroundAlpha)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final passes = document.filters!.resolvePaintPasses(
          'dispFxBackgroundAlpha',
        );

        expect(passes, hasLength(1));
        expect(passes.single.offset, const ui.Offset(8, 0));
      },
    );

    test(
      'Resolve feDisplacementMap accepts lowercase backgroundalpha as explicit in2',
      () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="dispFxBackgroundAlphaLower">
      <feOffset dx="10" dy="0" result="shifted"/>
      <feDisplacementMap in="shifted" in2="backgroundalpha" scale="10"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#dispFxBackgroundAlphaLower)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final passes = document.filters!.resolvePaintPasses(
          'dispFxBackgroundAlphaLower',
        );

        expect(passes, hasLength(1));
        expect(passes.single.offset, const ui.Offset(10, 0));
      },
    );

    test(
      'Resolve feImage without in resets chain to source placeholder output',
      () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="imgFx">
      <feOffset dx="5" dy="0" result="shifted"/>
      <feImage href="data:image/png;base64,AAAA"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#imgFx)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final passes = document.filters!.resolvePaintPasses('imgFx');

        expect(passes, hasLength(1));
        expect(passes.single.offset, ui.Offset.zero);
        expect(passes.single.imageFilter, isNull);
      },
    );

    test('Resolve feImage with explicit in uses referenced prior output', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="imgFx">
      <feOffset dx="5" dy="0" result="shifted"/>
      <feImage in="shifted" href="data:image/png;base64,AAAA"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#imgFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('imgFx');

      expect(passes, hasLength(1));
      expect(passes.single.offset, const ui.Offset(5, 0));
      expect(passes.single.imageFilter, isNull);
    });

    test('Resolve feImage skips unresolved explicit in input', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="imgUnknownFx">
      <feOffset dx="5" dy="0" result="shifted"/>
      <feImage in="missingResult" href="data:image/png;base64,AAAA"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#imgUnknownFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('imgUnknownFx');

      expect(passes, hasLength(1));
      expect(passes.single.offset, ui.Offset.zero);
      expect(passes.single.imageFilter, isNull);
    });

    test('Resolve feConvolveMatrix as pass-through of in input', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="convFx">
      <feOffset dx="7" dy="0" result="shifted"/>
      <feConvolveMatrix
        in="shifted"
        order="3"
        kernelMatrix="0 -1 0 -1 5 -1 0 -1 0"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#convFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('convFx');

      expect(passes, hasLength(1));
      expect(passes.single.offset, const ui.Offset(7, 0));
      expect(passes.single.imageFilter, isNull);
    });

    test('Resolve feTurbulence as pass-through of in input', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="noiseFx">
      <feOffset dx="3" dy="0" result="shifted"/>
      <feTurbulence in="shifted" baseFrequency="0.05"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#noiseFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('noiseFx');

      expect(passes, hasLength(1));
      expect(passes.single.offset, const ui.Offset(3, 0));
      expect(passes.single.imageFilter, isNull);
    });

    test('Resolve feComponentTransfer as pass-through of in input', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="compTransferFx">
      <feOffset dx="9" dy="0" result="shifted"/>
      <feComponentTransfer in="shifted">
        <feFuncR type="identity"/>
      </feComponentTransfer>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#compTransferFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('compTransferFx');

      expect(passes, hasLength(1));
      expect(passes.single.offset, const ui.Offset(9, 0));
      expect(passes.single.imageFilter, isNull);
    });

    test('Resolve feDiffuseLighting as pass-through of in input', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="lightFx">
      <feOffset dx="11" dy="0" result="shifted"/>
      <feDiffuseLighting in="shifted">
        <feDistantLight azimuth="45" elevation="60"/>
      </feDiffuseLighting>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#lightFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('lightFx');

      expect(passes, hasLength(1));
      expect(passes.single.offset, const ui.Offset(11, 0));
      expect(passes.single.imageFilter, isNull);
    });

    test('Resolve feSpecularLighting as pass-through of in input', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="specFx">
      <feOffset dx="13" dy="0" result="shifted"/>
      <feSpecularLighting in="shifted">
        <fePointLight x="1" y="2" z="3"/>
      </feSpecularLighting>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#specFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('specFx');

      expect(passes, hasLength(1));
      expect(passes.single.offset, const ui.Offset(13, 0));
      expect(passes.single.imageFilter, isNull);
    });

    test('Resolve drop shadow to multi-pass rendering sequence', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="shadowFx">
      <feDropShadow dx="4" dy="6" stdDeviation="2" flood-color="#000000" flood-opacity="0.5"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#shadowFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('shadowFx');

      expect(passes, hasLength(2));
      expect(passes.first.offset, const ui.Offset(4, 6));
      expect(passes.first.imageFilter, isNotNull);
      expect(passes.first.colorFilter, isNotNull);
      expect(passes.last.offset, ui.Offset.zero);
      expect(passes.last.colorFilter, isNull);
    });

    test('Resolve drop shadow preserves FillPaint channel scope', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="shadowFillFx">
      <feDropShadow in="FillPaint" dx="2" dy="3" stdDeviation="1"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#shadowFillFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses(
        'shadowFillFx',
        sourceContext: const SvgFilterSourceContext(
          fillPaint: <SvgFilterPaintPass>[
            SvgFilterPaintPass(
              offset: ui.Offset(4, 0),
              paintFill: true,
              paintStroke: false,
            ),
          ],
        ),
      );

      expect(passes, hasLength(2));
      expect(passes[0].paintFill, isTrue);
      expect(passes[0].paintStroke, isFalse);
      expect(passes[1].paintFill, isTrue);
      expect(passes[1].paintStroke, isFalse);
    });

    test('Resolve drop shadow preserves StrokePaint channel scope', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="shadowStrokeFx">
      <feDropShadow in="StrokePaint" dx="2" dy="3" stdDeviation="1"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#shadowStrokeFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses(
        'shadowStrokeFx',
        sourceContext: const SvgFilterSourceContext(
          strokePaint: <SvgFilterPaintPass>[
            SvgFilterPaintPass(
              offset: ui.Offset(6, 0),
              paintFill: false,
              paintStroke: true,
            ),
          ],
        ),
      );

      expect(passes, hasLength(2));
      expect(passes[0].paintFill, isFalse);
      expect(passes[0].paintStroke, isTrue);
      expect(passes[1].paintFill, isFalse);
      expect(passes[1].paintStroke, isTrue);
    });

    test('Resolve feMerge using named primitive results', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="mergeFx">
      <feGaussianBlur stdDeviation="2" result="blurred"/>
      <feMerge>
        <feMergeNode in="blurred"/>
        <feMergeNode in="SourceGraphic"/>
      </feMerge>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#mergeFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('mergeFx');

      expect(passes, hasLength(2));
      expect(passes.first.imageFilter, isNotNull);
      expect(passes.last.imageFilter, isNull);
    });

    test(
      'Resolve feMerge unresolved explicit node input does not fallback',
      () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="mergeUnknownFx">
      <feOffset dx="4" dy="0" result="known"/>
      <feMerge>
        <feMergeNode in="missingResult"/>
        <feMergeNode in="known"/>
      </feMerge>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#mergeUnknownFx)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final passes = document.filters!.resolvePaintPasses('mergeUnknownFx');

        expect(passes, hasLength(1));
        expect(passes.single.offset, const ui.Offset(4, 0));
      },
    );

    test(
      'Resolve feMerge single unresolved explicit node input collapses to identity output',
      () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="mergeOnlyUnknownFx">
      <feOffset dx="4" dy="0" result="known"/>
      <feMerge>
        <feMergeNode in="missingResult"/>
      </feMerge>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#mergeOnlyUnknownFx)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final passes = document.filters!.resolvePaintPasses(
          'mergeOnlyUnknownFx',
        );

        expect(passes, hasLength(1));
        expect(passes.single.offset, ui.Offset.zero);
        expect(passes.single.imageFilter, isNull);
        expect(passes.single.colorFilter, isNull);
        expect(passes.single.blendMode, isNull);
      },
    );

    test('Resolve feMerge explicit none node input does not fallback', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="mergeNoneFx">
      <feOffset dx="4" dy="0" result="known"/>
      <feMerge>
        <feMergeNode in="none"/>
        <feMergeNode in="known"/>
      </feMerge>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#mergeNoneFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('mergeNoneFx');

      expect(passes, hasLength(1));
      expect(passes.single.offset, const ui.Offset(4, 0));
    });

    test(
      'Resolve feMerge explicit mixed-case none node input does not fallback',
      () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="mergeNoneCaseFx">
      <feOffset dx="7" dy="0" result="known"/>
      <feMerge>
        <feMergeNode in="NoNe"/>
        <feMergeNode in="known"/>
      </feMerge>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#mergeNoneCaseFx)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final passes = document.filters!.resolvePaintPasses('mergeNoneCaseFx');

        expect(passes, hasLength(1));
        expect(passes.single.offset, const ui.Offset(7, 0));
      },
    );

    test('Resolve feMerge forward reference does not fallback to previous', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="mergeForwardFx">
      <feOffset dx="3" dy="0" result="known"/>
      <feMerge>
        <feMergeNode in="futureResult"/>
      </feMerge>
      <feOffset dx="5" dy="0" result="futureResult"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#mergeForwardFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('mergeForwardFx');

      // Forward merge input resolves as explicit unresolved and does not
      // contribute previous-output fallback.
      expect(passes, hasLength(1));
      expect(passes.single.offset, const ui.Offset(5, 0));
    });

    test(
      'Resolve feMerge mixed forward and known node inputs skip forward fallback',
      () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="mergeForwardKnownFx">
      <feOffset dx="3" dy="0" result="known"/>
      <feMerge>
        <feMergeNode in="futureResult"/>
        <feMergeNode in="known"/>
      </feMerge>
      <feOffset dx="5" dy="0" result="futureResult"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#mergeForwardKnownFx)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final passes = document.filters!.resolvePaintPasses(
          'mergeForwardKnownFx',
        );

        // Only known node contributes into merge output.
        expect(passes, hasLength(1));
        expect(passes.single.offset, const ui.Offset(8, 0));
      },
    );

    test('Resolve feMerge node without in uses implicit previous input', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="mergeImplicitInFx">
      <feOffset dx="4" dy="0" result="known"/>
      <feMerge>
        <feMergeNode/>
        <feMergeNode in="known"/>
      </feMerge>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#mergeImplicitInFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('mergeImplicitInFx');

      expect(passes, hasLength(2));
      expect(passes[0].offset, const ui.Offset(4, 0));
      expect(passes[1].offset, const ui.Offset(4, 0));
    });

    test('Resolve feMerge node with empty in uses implicit previous input', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="mergeEmptyInFx">
      <feOffset dx="6" dy="0" result="known"/>
      <feMerge>
        <feMergeNode in=""/>
        <feMergeNode in="known"/>
      </feMerge>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#mergeEmptyInFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('mergeEmptyInFx');

      expect(passes, hasLength(2));
      expect(passes[0].offset, const ui.Offset(6, 0));
      expect(passes[1].offset, const ui.Offset(6, 0));
    });

    test('Resolve feMerge composes named feImage non-source result', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="mergeImageFx">
      <feOffset dx="6" dy="0" result="shifted"/>
      <feImage href="data:image/png;base64,AAAA" result="imgOut"/>
      <feMerge>
        <feMergeNode in="shifted"/>
        <feMergeNode in="imgOut"/>
      </feMerge>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#mergeImageFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('mergeImageFx');

      expect(passes, hasLength(2));
      expect(passes[0].offset, const ui.Offset(6, 0));
      expect(passes[1].offset, ui.Offset.zero);
      expect(passes[0].imageFilter, isNull);
      expect(passes[1].imageFilter, isNull);
    });

    test(
      'Resolve feMerge accepts lowercase backgroundimage merge-node input',
      () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="mergeLowerBgFx">
      <feOffset dx="6" dy="0" result="shifted"/>
      <feMerge>
        <feMergeNode in="shifted"/>
        <feMergeNode in="backgroundimage"/>
      </feMerge>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#mergeLowerBgFx)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final passes = document.filters!.resolvePaintPasses('mergeLowerBgFx');

        expect(passes, hasLength(2));
        expect(passes[0].offset, const ui.Offset(6, 0));
        expect(passes[1].offset, ui.Offset.zero);
      },
    );

    test('Resolve feTile as pass-through of selected input', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="tileFx">
      <feOffset dx="4" dy="0" result="shifted"/>
      <feTile in="shifted"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#tileFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('tileFx');

      expect(passes, hasLength(1));
      expect(passes.single.offset, const ui.Offset(4, 0));
    });

    test('Resolve feTile skips unresolved explicit in input', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="tileUnknownFx">
      <feOffset dx="4" dy="0" result="shifted"/>
      <feTile in="missingResult"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#tileUnknownFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('tileUnknownFx');

      expect(passes, hasLength(1));
      expect(passes.single.offset, ui.Offset.zero);
      expect(passes.single.imageFilter, isNull);
    });

    test('Resolve feBlend layers in2 base with blended in pass', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="blendFx">
      <feOffset dx="2" dy="0" result="base"/>
      <feOffset dx="7" dy="0" result="top"/>
      <feBlend in="top" in2="base" mode="screen"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#blendFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('blendFx');

      expect(passes, hasLength(2));
      expect(passes[0].offset, const ui.Offset(2, 0));
      expect(passes[0].blendMode, isNull);
      expect(passes[1].offset, const ui.Offset(9, 0));
      expect(passes[1].blendMode, ui.BlendMode.screen);
    });

    test('Resolve feBlend supports extended SVG2 blend modes', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="blendExtendedFx">
      <feOffset dx="2" dy="0" result="base"/>
      <feOffset dx="7" dy="0" result="top"/>
      <feBlend in="top" in2="base" mode="color-dodge"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#blendExtendedFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('blendExtendedFx');

      expect(passes, hasLength(2));
      expect(passes[0].offset, const ui.Offset(2, 0));
      expect(passes[0].blendMode, isNull);
      expect(passes[1].offset, const ui.Offset(9, 0));
      expect(passes[1].blendMode, ui.BlendMode.colorDodge);
    });

    test('Resolve feBlend skips unresolved explicit in2', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="blendUnknownFx">
      <feOffset dx="2" dy="0" result="base"/>
      <feOffset dx="7" dy="0" result="top"/>
      <feBlend in="top" in2="missingResult" mode="screen"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#blendUnknownFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('blendUnknownFx');

      expect(passes, hasLength(1));
      expect(passes.single.offset, ui.Offset.zero);
      expect(passes.single.blendMode, isNull);
      expect(passes.single.imageFilter, isNull);
      expect(passes.single.colorFilter, isNull);
    });

    test('Resolve feBlend skips unresolved explicit in', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="blendUnknownInFx">
      <feOffset dx="2" dy="0" result="base"/>
      <feBlend in="missingTop" in2="base" mode="screen"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#blendUnknownInFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('blendUnknownInFx');

      expect(passes, hasLength(1));
      expect(passes.single.offset, ui.Offset.zero);
      expect(passes.single.blendMode, isNull);
      expect(passes.single.imageFilter, isNull);
      expect(passes.single.colorFilter, isNull);
    });

    test('Resolve feBlend explicit none in2 keeps top input output', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="blendNoneIn2Fx">
      <feOffset dx="7" dy="0" result="top"/>
      <feBlend in="top" in2="none" mode="screen"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#blendNoneIn2Fx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('blendNoneIn2Fx');

      expect(passes, hasLength(1));
      expect(passes.single.offset, const ui.Offset(7, 0));
      expect(passes.single.blendMode, ui.BlendMode.screen);
    });

    test(
      'Resolve feBlend explicit mixed-case none in2 keeps top input output',
      () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="blendMixedNoneIn2Fx">
      <feOffset dx="8" dy="0" result="top"/>
      <feBlend in="top" in2="NoNe" mode="screen"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#blendMixedNoneIn2Fx)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final passes = document.filters!.resolvePaintPasses(
          'blendMixedNoneIn2Fx',
        );

        expect(passes, hasLength(1));
        expect(passes.single.offset, const ui.Offset(8, 0));
        expect(passes.single.blendMode, ui.BlendMode.screen);
      },
    );

    test('Resolve feComposite layers in2 base with composited in pass', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="compFx">
      <feOffset dx="3" dy="0" result="base"/>
      <feOffset dx="9" dy="0" result="top"/>
      <feComposite in="top" in2="base" operator="xor"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#compFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('compFx');

      expect(passes, hasLength(2));
      expect(passes[0].offset, const ui.Offset(3, 0));
      expect(passes[0].blendMode, isNull);
      expect(passes[1].offset, const ui.Offset(12, 0));
      expect(passes[1].blendMode, ui.BlendMode.xor);
    });

    test('Resolve feComposite skips unresolved explicit in2', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="compUnknownFx">
      <feOffset dx="3" dy="0" result="base"/>
      <feOffset dx="9" dy="0" result="top"/>
      <feComposite in="top" in2="missingResult" operator="xor"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#compUnknownFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('compUnknownFx');

      expect(passes, hasLength(1));
      expect(passes.single.offset, ui.Offset.zero);
      expect(passes.single.blendMode, isNull);
      expect(passes.single.imageFilter, isNull);
      expect(passes.single.colorFilter, isNull);
    });

    test('Resolve feComposite skips unresolved explicit in', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="compUnknownInFx">
      <feOffset dx="3" dy="0" result="base"/>
      <feComposite in="missingTop" in2="base" operator="xor"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#compUnknownInFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('compUnknownInFx');

      expect(passes, hasLength(1));
      expect(passes.single.offset, ui.Offset.zero);
      expect(passes.single.blendMode, isNull);
      expect(passes.single.imageFilter, isNull);
      expect(passes.single.colorFilter, isNull);
    });

    test('Resolve feComposite explicit none in2 keeps top input output', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="compNoneIn2Fx">
      <feOffset dx="9" dy="0" result="top"/>
      <feComposite in="top" in2="none" operator="xor"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#compNoneIn2Fx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('compNoneIn2Fx');

      expect(passes, hasLength(1));
      expect(passes.single.offset, const ui.Offset(9, 0));
      expect(passes.single.blendMode, ui.BlendMode.xor);
    });

    test('Resolve feComposite arithmetic k3-only selects in2 output', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="compArithmeticIn2Fx">
      <feOffset dx="3" dy="0" result="base"/>
      <feOffset dx="9" dy="0" result="top"/>
      <feComposite
        in="top"
        in2="base"
        operator="arithmetic"
        k1="0"
        k2="0"
        k3="1"
        k4="0"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#compArithmeticIn2Fx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses(
        'compArithmeticIn2Fx',
      );

      expect(passes, hasLength(1));
      expect(passes.single.offset, const ui.Offset(3, 0));
      expect(passes.single.blendMode, isNull);
    });

    test(
      'Resolve feComposite arithmetic k2+k3 approximates additive layering',
      () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="compArithmeticAddFx">
      <feOffset dx="3" dy="0" result="base"/>
      <feOffset dx="9" dy="0" result="top"/>
      <feComposite
        in="top"
        in2="base"
        operator="arithmetic"
        k1="0"
        k2="1"
        k3="1"
        k4="0"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#compArithmeticAddFx)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final passes = document.filters!.resolvePaintPasses(
          'compArithmeticAddFx',
        );

        expect(passes, hasLength(2));
        expect(passes[0].offset, const ui.Offset(3, 0));
        expect(passes[0].blendMode, isNull);
        expect(passes[1].offset, const ui.Offset(12, 0));
        expect(passes[1].blendMode, ui.BlendMode.plus);
      },
    );

    test(
      'Resolve feComposite arithmetic k2+k3 with explicit none in2 keeps additive top output',
      () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="compArithmeticNoneIn2Fx">
      <feOffset dx="9" dy="0" result="top"/>
      <feComposite
        in="top"
        in2="none"
        operator="arithmetic"
        k1="0"
        k2="1"
        k3="1"
        k4="0"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#compArithmeticNoneIn2Fx)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final passes = document.filters!.resolvePaintPasses(
          'compArithmeticNoneIn2Fx',
        );

        expect(passes, hasLength(1));
        expect(passes.single.offset, const ui.Offset(9, 0));
        expect(passes.single.blendMode, ui.BlendMode.plus);
      },
    );

    test(
      'Resolve feComposite arithmetic all-zero coefficients skip output',
      () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="compArithmeticZeroFx">
      <feOffset dx="3" dy="0" result="base"/>
      <feOffset dx="9" dy="0" result="top"/>
      <feComposite
        in="top"
        in2="base"
        operator="arithmetic"
        k1="0"
        k2="0"
        k3="0"
        k4="0"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#compArithmeticZeroFx)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final passes = document.filters!.resolvePaintPasses(
          'compArithmeticZeroFx',
        );

        expect(passes, hasLength(1));
        expect(passes.single.offset, ui.Offset.zero);
        expect(passes.single.imageFilter, isNull);
        expect(passes.single.colorFilter, isNull);
        expect(passes.single.blendMode, isNull);
      },
    );

    test(
      'Resolve feComposite arithmetic in2-dependent coefficients skip unresolved explicit in2',
      () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="compArithmeticMissingIn2Fx">
      <feOffset dx="3" dy="0" result="top"/>
      <feComposite
        in="top"
        in2="missingBase"
        operator="arithmetic"
        k1="0"
        k2="0"
        k3="1"
        k4="0"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#compArithmeticMissingIn2Fx)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final passes = document.filters!.resolvePaintPasses(
          'compArithmeticMissingIn2Fx',
        );

        expect(passes, hasLength(1));
        expect(passes.single.offset, ui.Offset.zero);
        expect(passes.single.blendMode, isNull);
        expect(passes.single.imageFilter, isNull);
        expect(passes.single.colorFilter, isNull);
      },
    );

    test(
      'Resolve BackgroundImage input maps to source graphic placeholder',
      () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="bgImgFx">
      <feTile in="BackgroundImage"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#bgImgFx)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final passes = document.filters!.resolvePaintPasses('bgImgFx');

        expect(passes, hasLength(1));
        expect(passes.single.colorFilter, isNull);
      },
    );

    test('Resolve BackgroundAlpha input maps to source alpha placeholder', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="bgAlphaFx">
      <feTile in="BackgroundAlpha"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#bgAlphaFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('bgAlphaFx');

      expect(passes, hasLength(1));
      expect(passes.single.colorFilter, isNotNull);
    });

    test('Resolve BackgroundImage input uses provided source context pass', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="bgImgContextFx">
      <feTile in="BackgroundImage"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#bgImgContextFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses(
        'bgImgContextFx',
        sourceContext: const SvgFilterSourceContext(
          backgroundImage: <SvgFilterPaintPass>[
            SvgFilterPaintPass(
              blendMode: ui.BlendMode.screen,
              offset: ui.Offset(11, 2),
            ),
          ],
        ),
      );

      expect(passes, hasLength(1));
      expect(passes.single.offset, const ui.Offset(11, 2));
      expect(passes.single.blendMode, ui.BlendMode.screen);
    });

    test('Resolve BackgroundAlpha input uses provided source context pass', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="bgAlphaContextFx">
      <feTile in="BackgroundAlpha"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#bgAlphaContextFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses(
        'bgAlphaContextFx',
        sourceContext: SvgFilterSourceContext(
          backgroundAlpha: <SvgFilterPaintPass>[
            const SvgFilterPaintPass(
              colorFilter: ui.ColorFilter.mode(
                ui.Color(0xFFABCDEF),
                ui.BlendMode.srcIn,
              ),
              offset: ui.Offset(3, 9),
            ),
          ],
        ),
      );

      expect(passes, hasLength(1));
      expect(passes.single.offset, const ui.Offset(3, 9));
      expect(passes.single.colorFilter, isNotNull);
    });

    test(
      'Resolve FillPaint input without source context uses fill-only source pass',
      () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="fillPaintFallbackFx">
      <feTile in="FillPaint"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#fillPaintFallbackFx)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final passes = document.filters!.resolvePaintPasses(
          'fillPaintFallbackFx',
        );

        expect(passes, hasLength(1));
        expect(passes.single.paintFill, isTrue);
        expect(passes.single.paintStroke, isFalse);
      },
    );

    test(
      'Resolve StrokePaint input without source context uses stroke-only source pass',
      () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="strokePaintFallbackFx">
      <feTile in="StrokePaint"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#strokePaintFallbackFx)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final passes = document.filters!.resolvePaintPasses(
          'strokePaintFallbackFx',
        );

        expect(passes, hasLength(1));
        expect(passes.single.paintFill, isFalse);
        expect(passes.single.paintStroke, isTrue);
      },
    );

    test('Resolve FillPaint input uses provided source context pass', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="fillPaintFx">
      <feTile in="FillPaint"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#fillPaintFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses(
        'fillPaintFx',
        sourceContext: SvgFilterSourceContext(
          fillPaint: <SvgFilterPaintPass>[
            const SvgFilterPaintPass(
              colorFilter: ui.ColorFilter.mode(
                ui.Color(0xFF00FF00),
                ui.BlendMode.srcIn,
              ),
            ),
          ],
        ),
      );

      expect(passes, hasLength(1));
      expect(passes.single.colorFilter, isNotNull);
    });

    test('Resolve StrokePaint input uses provided source context pass', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="strokePaintFx">
      <feTile in="StrokePaint"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#strokePaintFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses(
        'strokePaintFx',
        sourceContext: SvgFilterSourceContext(
          strokePaint: <SvgFilterPaintPass>[
            const SvgFilterPaintPass(
              colorFilter: ui.ColorFilter.mode(
                ui.Color(0xFF0000FF),
                ui.BlendMode.srcIn,
              ),
            ),
          ],
        ),
      );

      expect(passes, hasLength(1));
      expect(passes.single.colorFilter, isNotNull);
    });

    test('Filter applied via filter attribute', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="blur">
      <feGaussianBlur stdDeviation="5"/>
    </filter>
  </defs>
  <rect id="rect1" x="10" y="10" width="50" height="50" fill="blue" filter="url(#blur)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final rect = document.getElementById('rect1');
      expect(rect, isNotNull);

      final filterAttr = rect!.getAttributeValue('filter');
      expect(filterAttr, isNotNull);
      expect(filterAttr.toString(), contains('blur'));
    });
  });

  // =========================================================================
  // Advanced Filter Chain Tests - Blink Parity
  // =========================================================================
  group('Advanced Filter Chain Semantics', () {
    test('Non-source input chain: blur result referenced by composite', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="blurCompositeFx">
      <feGaussianBlur stdDeviation="3" result="blur"/>
      <feComposite in="blur" in2="SourceGraphic" operator="xor"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#blurCompositeFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('blurCompositeFx');

      // composite layers SourceGraphic (base) with blur result (top with xor blend)
      expect(passes, hasLength(2));
      expect(passes[0].blendMode, isNull); // SourceGraphic base
      expect(passes[1].blendMode, ui.BlendMode.xor); // blurred input with xor
      expect(passes[1].imageFilter, isNotNull); // contains blur filter
    });

    test('Filter result caching: multiple references to same result', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="multiRefFx">
      <feOffset dx="5" dy="0" result="shifted"/>
      <feMerge>
        <feMergeNode in="shifted"/>
        <feMergeNode in="shifted"/>
        <feMergeNode in="SourceGraphic"/>
      </feMerge>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#multiRefFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('multiRefFx');

      // Merge combines: shifted (x2) + SourceGraphic
      expect(passes, hasLength(3));
      expect(
        passes[0].offset,
        const ui.Offset(5, 0),
      ); // first shifted reference
      expect(
        passes[1].offset,
        const ui.Offset(5, 0),
      ); // second shifted reference
      expect(passes[2].offset, ui.Offset.zero); // SourceGraphic
    });

    test('feDropShadow with non-source input from blur chain', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="shadowBlurFx">
      <feGaussianBlur stdDeviation="2" result="blurred"/>
      <feDropShadow in="blurred" dx="4" dy="4" stdDeviation="1"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#shadowBlurFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('shadowBlurFx');

      // DropShadow creates shadow pass + original input
      expect(passes, hasLength(2));
      expect(passes[0].offset, const ui.Offset(4, 4)); // shadow with offset
      expect(passes[0].imageFilter, isNotNull); // combined blur filters
      expect(passes[0].colorFilter, isNotNull); // shadow color
      expect(
        passes[1].offset,
        ui.Offset.zero,
      ); // original blurred input (no offset)
    });

    test('feDropShadow with unresolved input produces no output', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="shadowMissingFx">
      <feDropShadow in="missingResult" dx="4" dy="4" stdDeviation="1"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#shadowMissingFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('shadowMissingFx');

      // Unresolved input produces identity fallback
      expect(passes, hasLength(1));
      expect(passes.single.imageFilter, isNull);
      expect(passes.single.colorFilter, isNull);
    });

    test('Complex multi-primitive chain with default input resolution', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="chainFx">
      <feGaussianBlur stdDeviation="2"/>
      <feOffset dx="3" dy="0"/>
      <feColorMatrix type="saturate" values="0.5"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#chainFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('chainFx');

      // Each primitive uses previous output as input (no explicit in attr)
      // feColorMatrix applies to the blurred+offset input
      expect(passes, hasLength(1));
      expect(passes.single.offset, const ui.Offset(3, 0));
      expect(passes.single.imageFilter, isNotNull); // blur applied
      // Note: feColorMatrix type="saturate" creates a ColorFilter.matrix,
      // which is wrapped in ImageFilter, not direct ColorFilter
    });

    test('feBlend with named result inputs from parallel chains', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="blendChainFx">
      <feGaussianBlur in="SourceGraphic" stdDeviation="2" result="blurred"/>
      <feOffset in="SourceGraphic" dx="5" dy="0" result="shifted"/>
      <feBlend in="blurred" in2="shifted" mode="multiply"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#blendChainFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('blendChainFx');

      // Blend layers shifted (base) + blurred (top with multiply)
      expect(passes, hasLength(2));
      expect(passes[0].offset, const ui.Offset(5, 0)); // shifted base
      expect(passes[0].blendMode, isNull);
      expect(passes[1].offset, ui.Offset.zero); // blurred with multiply
      expect(passes[1].blendMode, ui.BlendMode.multiply);
      expect(passes[1].imageFilter, isNotNull); // contains blur
    });

    test('feDropShadow as part of larger feMerge composition', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="shadowMergeFx">
      <feDropShadow dx="4" dy="4" stdDeviation="2" result="shadow"/>
      <feGaussianBlur stdDeviation="1" result="blur"/>
      <feMerge>
        <feMergeNode in="shadow"/>
        <feMergeNode in="blur"/>
      </feMerge>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#shadowMergeFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('shadowMergeFx');

      // Merge combines: shadow passes (2 from dropShadow) + blur passes (2 from dropShadow output)
      // dropShadow creates: shadow + source = 2 passes stored in "shadow"
      // blur processes the previous output (dropShadow's 2 passes) = 2 passes stored in "blur"
      // feMerge of shadow (2) + blur (2) = 4 passes total
      expect(passes, hasLength(4));
    });

    test('Filter chain with explicit SourceAlpha input', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="alphaChainFx">
      <feGaussianBlur in="SourceAlpha" stdDeviation="3" result="blurredAlpha"/>
      <feOffset in="blurredAlpha" dx="4" dy="4" result="offsetAlpha"/>
      <feMerge>
        <feMergeNode in="offsetAlpha"/>
        <feMergeNode in="SourceGraphic"/>
      </feMerge>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#alphaChainFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('alphaChainFx');

      // Merge combines: offsetAlpha + SourceGraphic
      expect(passes, hasLength(2));
      expect(passes[0].offset, const ui.Offset(4, 4)); // offset alpha shadow
      expect(passes[0].imageFilter, isNotNull); // has blur
      expect(passes[0].colorFilter, isNotNull); // SourceAlpha filter
      expect(passes[1].offset, ui.Offset.zero); // SourceGraphic
    });

    test('Deeply nested filter chain preserves all effects', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="deepChainFx">
      <feOffset dx="2" dy="0" result="off1"/>
      <feOffset in="off1" dx="3" dy="0" result="off2"/>
      <feOffset in="off2" dx="4" dy="0" result="off3"/>
      <feGaussianBlur in="off3" stdDeviation="1"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#deepChainFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('deepChainFx');

      // Final output: accumulated offset (2+3+4=9) with blur
      expect(passes, hasLength(1));
      expect(passes.single.offset, const ui.Offset(9, 0));
      expect(passes.single.imageFilter, isNotNull);
    });

    test('feMerge forward reference produces transparent black per spec', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="forwardRefFx">
      <feMerge result="merged">
        <feMergeNode in="laterResult"/>
      </feMerge>
      <feOffset dx="5" dy="0" result="laterResult"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#forwardRefFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('forwardRefFx');

      // Forward reference in merge produces empty; final output is offset
      expect(passes, hasLength(1));
      expect(passes.single.offset, const ui.Offset(5, 0));
    });

    test('Result reuse does not cause recomputation side effects', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="reuseTestFx">
      <feGaussianBlur stdDeviation="3" result="shared"/>
      <feComposite in="shared" in2="shared" operator="xor" result="comp1"/>
      <feBlend in="shared" in2="comp1" mode="screen"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#reuseTestFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final passes = document.filters!.resolvePaintPasses('reuseTestFx');

      // feComposite with in="shared" in2="shared" operator="xor" creates:
      //   - shared (base) + shared with xor (top) = 2 passes for comp1
      // feBlend with in="shared" in2="comp1" mode="screen" creates:
      //   - comp1 (2 passes as base) + shared with screen (1 pass on top) = 3 passes
      // All references to "shared" should produce identical blur effect
      expect(passes, hasLength(3));
      expect(passes[0].imageFilter, isNotNull); // comp1 base (shared with blur)
      expect(
        passes[1].imageFilter,
        isNotNull,
      ); // comp1 top (shared with blur + xor)
      expect(
        passes[2].imageFilter,
        isNotNull,
      ); // shared with blur and screen blend
      expect(passes[2].blendMode, ui.BlendMode.screen);
    });
  });
}
