import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_svg/src/animation/svg_parser.dart';
import 'package:flutter_svg/src/animation/svg_filters.dart';

void main() {
  group('Filter Primitive Edge Cases', () {
    group('feMorphology Edge Modes', () {
      test('Parse feMorphology with edgeMode=duplicate', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="morphDup">
      <feMorphology operator="dilate" radius="2" edgeMode="duplicate"/>
    </filter>
  </defs>
  <rect filter="url(#morphDup)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final filter =
            document.filters!.getById('morphDup') as SvgMorphologyFilter;
        expect(filter.edgeMode, SvgConvolveEdgeMode.duplicate);
        expect(filter.operatorType, SvgMorphologyOperator.dilate);
        expect(filter.radiusX, 2.0);
        expect(filter.radiusY, 2.0);
      });

      test('Parse feMorphology with edgeMode=wrap', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="morphWrap">
      <feMorphology operator="erode" radius="3 2" edgeMode="wrap"/>
    </filter>
  </defs>
  <rect filter="url(#morphWrap)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final filter =
            document.filters!.getById('morphWrap') as SvgMorphologyFilter;
        expect(filter.edgeMode, SvgConvolveEdgeMode.wrap);
        expect(filter.operatorType, SvgMorphologyOperator.erode);
        expect(filter.radiusX, 3.0);
        expect(filter.radiusY, 2.0);
      });

      test('Parse feMorphology with edgeMode=none', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="morphNone">
      <feMorphology operator="dilate" radius="1" edgeMode="none"/>
    </filter>
  </defs>
  <rect filter="url(#morphNone)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final filter =
            document.filters!.getById('morphNone') as SvgMorphologyFilter;
        expect(filter.edgeMode, SvgConvolveEdgeMode.none);
      });

      test('MorphologyProcessor erode with duplicate edge mode', () {
        // 3x3 image with white center
        final pixels = Uint8List.fromList([
          0,
          0,
          0,
          255,
          0,
          0,
          0,
          255,
          0,
          0,
          0,
          255,
          0,
          0,
          0,
          255,
          255,
          255,
          255,
          255,
          0,
          0,
          0,
          255,
          0,
          0,
          0,
          255,
          0,
          0,
          0,
          255,
          0,
          0,
          0,
          255,
        ]);

        final result = MorphologyProcessor.applyMorphology(
          pixels: pixels,
          width: 3,
          height: 3,
          radiusX: 1,
          radiusY: 1,
          operatorType: SvgMorphologyOperator.erode,
          edgeMode: SvgConvolveEdgeMode.duplicate,
        );

        // Center pixel should be black (min operation)
        expect(result[16], 0); // R
        expect(result[17], 0); // G
        expect(result[18], 0); // B
        expect(result[19], 255); // A
      });

      test('MorphologyProcessor dilate with wrap edge mode', () {
        // 3x3 image with single white corner pixel
        final pixels = Uint8List.fromList([
          255,
          255,
          255,
          255,
          0,
          0,
          0,
          255,
          0,
          0,
          0,
          255,
          0,
          0,
          0,
          255,
          0,
          0,
          0,
          255,
          0,
          0,
          0,
          255,
          0,
          0,
          0,
          255,
          0,
          0,
          0,
          255,
          0,
          0,
          0,
          255,
        ]);

        final result = MorphologyProcessor.applyMorphology(
          pixels: pixels,
          width: 3,
          height: 3,
          radiusX: 1,
          radiusY: 1,
          operatorType: SvgMorphologyOperator.dilate,
          edgeMode: SvgConvolveEdgeMode.wrap,
        );

        // Multiple pixels should become white due to wrapping
        expect(result[0], 255); // Top-left stays white
        expect(result[4], 255); // Neighbor gets dilated
      });

      test('MorphologyProcessor dilate with none edge mode', () {
        // 2x2 image
        final pixels = Uint8List.fromList([
          255,
          0,
          0,
          255,
          0,
          255,
          0,
          255,
          0,
          0,
          255,
          255,
          128,
          128,
          128,
          255,
        ]);

        final result = MorphologyProcessor.applyMorphology(
          pixels: pixels,
          width: 2,
          height: 2,
          radiusX: 1,
          radiusY: 1,
          operatorType: SvgMorphologyOperator.dilate,
          edgeMode: SvgConvolveEdgeMode.none,
        );

        // Result should reflect max operation with transparent black edges
        expect(result.length, pixels.length);
      });

      test('MorphologyProcessor erode with wrap edge mode', () {
        // 3x3 image with white pixels on opposite corners
        final pixels = Uint8List.fromList([
          255, 255, 255, 255, // (0,0) white
          0, 0, 0, 255, // (1,0) black
          0, 0, 0, 255, // (2,0) black
          0, 0, 0, 255, // (0,1) black
          128, 128, 128, 255, // (1,1) gray
          0, 0, 0, 255, // (2,1) black
          0, 0, 0, 255, // (0,2) black
          0, 0, 0, 255, // (1,2) black
          255, 255, 255, 255, // (2,2) white
        ]);

        final result = MorphologyProcessor.applyMorphology(
          pixels: pixels,
          width: 3,
          height: 3,
          radiusX: 1,
          radiusY: 1,
          operatorType: SvgMorphologyOperator.erode,
          edgeMode: SvgConvolveEdgeMode.wrap,
        );

        // With wrap, the (0,0) pixel's neighborhood wraps around to include (2,2)
        // Erode takes min, so result should include black pixels
        expect(result.length, pixels.length);
        // Center pixel (1,1) should be 0 (min of neighborhood)
        expect(result[16], 0); // R channel at center
      });

      test('MorphologyProcessor erode with none edge mode', () {
        // 3x3 all-white image
        final pixels = Uint8List(3 * 3 * 4);
        for (int i = 0; i < pixels.length; i += 4) {
          pixels[i] = 255; // R
          pixels[i + 1] = 255; // G
          pixels[i + 2] = 255; // B
          pixels[i + 3] = 255; // A
        }

        final result = MorphologyProcessor.applyMorphology(
          pixels: pixels,
          width: 3,
          height: 3,
          radiusX: 1,
          radiusY: 1,
          operatorType: SvgMorphologyOperator.erode,
          edgeMode: SvgConvolveEdgeMode.none,
        );

        // Edge pixels should erode to 0 because out-of-bounds returns (0,0,0,0)
        // Corner (0,0) has neighborhood extending outside, erode takes min (0)
        expect(result[0], 0); // R at (0,0)
        expect(result[1], 0); // G at (0,0)
        expect(result[2], 0); // B at (0,0)
        expect(result[3], 0); // A at (0,0) - min of alpha

        // Center pixel (1,1) should stay white as all neighbors are in-bounds
        expect(result[16], 255); // R at center
        expect(result[17], 255); // G at center
        expect(result[18], 255); // B at center
        expect(result[19], 255); // A at center
      });

      test('MorphologyProcessor dilate with duplicate edge mode', () {
        // 3x3 image with white center
        final pixels = Uint8List.fromList([
          0, 0, 0, 255,
          0, 0, 0, 255,
          0, 0, 0, 255,
          0, 0, 0, 255,
          255, 255, 255, 255, // center is white
          0, 0, 0, 255,
          0, 0, 0, 255,
          0, 0, 0, 255,
          0, 0, 0, 255,
        ]);

        final result = MorphologyProcessor.applyMorphology(
          pixels: pixels,
          width: 3,
          height: 3,
          radiusX: 1,
          radiusY: 1,
          operatorType: SvgMorphologyOperator.dilate,
          edgeMode: SvgConvolveEdgeMode.duplicate,
        );

        // All 4-connected neighbors of center should become white (dilate takes max)
        expect(result[4], 255); // (1,0) R
        expect(result[12], 255); // (0,1) R
        expect(result[16], 255); // (1,1) R - center stays white
        expect(result[20], 255); // (2,1) R
        expect(result[28], 255); // (1,2) R
      });

      test('MorphologyProcessor single axis zero radius (radiusX=0)', () {
        // 3x3 image with horizontal white stripe
        final pixels = Uint8List.fromList([
          0, 0, 0, 255,
          0, 0, 0, 255,
          0, 0, 0, 255,
          255, 255, 255, 255, // middle row white
          255, 255, 255, 255,
          255, 255, 255, 255,
          0, 0, 0, 255,
          0, 0, 0, 255,
          0, 0, 0, 255,
        ]);

        // radiusX=0, radiusY=1 - should only erode/dilate vertically
        final result = MorphologyProcessor.applyMorphology(
          pixels: pixels,
          width: 3,
          height: 3,
          radiusX: 0,
          radiusY: 1,
          operatorType: SvgMorphologyOperator.dilate,
          edgeMode: SvgConvolveEdgeMode.duplicate,
        );

        // Middle row expands vertically but NOT horizontally
        // Top row should now be white (dilated from middle row)
        expect(result[0], 255); // (0,0) R
        // Bottom row should also be white
        expect(result[24], 255); // (0,2) R
      });

      test('MorphologyProcessor single axis zero radius (radiusY=0)', () {
        // 3x3 image with vertical white stripe
        final pixels = Uint8List.fromList([
          0, 0, 0, 255,
          255, 255, 255, 255, // middle column white
          0, 0, 0, 255,
          0, 0, 0, 255,
          255, 255, 255, 255,
          0, 0, 0, 255,
          0, 0, 0, 255,
          255, 255, 255, 255,
          0, 0, 0, 255,
        ]);

        // radiusX=1, radiusY=0 - should only erode/dilate horizontally
        final result = MorphologyProcessor.applyMorphology(
          pixels: pixels,
          width: 3,
          height: 3,
          radiusX: 1,
          radiusY: 0,
          operatorType: SvgMorphologyOperator.dilate,
          edgeMode: SvgConvolveEdgeMode.duplicate,
        );

        // Middle column expands horizontally but NOT vertically
        // Left column top row should now be white (dilated from middle column)
        expect(result[0], 255); // (0,0) R
        // Right column top row should also be white
        expect(result[8], 255); // (2,0) R
      });

      test('MorphologyProcessor fractional radius rounds correctly', () {
        // 5x5 image with white center
        final pixels = Uint8List(5 * 5 * 4);
        for (int i = 0; i < pixels.length; i += 4) {
          pixels[i] = 0;
          pixels[i + 1] = 0;
          pixels[i + 2] = 0;
          pixels[i + 3] = 255;
        }
        // Set center (2,2) to white
        final centerIndex = (2 * 5 + 2) * 4;
        pixels[centerIndex] = 255;
        pixels[centerIndex + 1] = 255;
        pixels[centerIndex + 2] = 255;

        // Fractional radius 1.4 should round to 1
        final result = MorphologyProcessor.applyMorphology(
          pixels: pixels,
          width: 5,
          height: 5,
          radiusX: 1.4,
          radiusY: 1.4,
          operatorType: SvgMorphologyOperator.dilate,
          edgeMode: SvgConvolveEdgeMode.duplicate,
        );

        // Direct neighbors should be white (radius rounds to 1)
        final upIndex = (1 * 5 + 2) * 4;
        final downIndex = (3 * 5 + 2) * 4;
        expect(result[upIndex], 255);
        expect(result[downIndex], 255);

        // Pixels at distance 2 should still be black
        final farIndex = (0 * 5 + 2) * 4;
        expect(result[farIndex], 0);
      });

      test('MorphologyProcessor fractional radius 1.6 rounds to 2', () {
        // 5x5 image with white center
        final pixels = Uint8List(5 * 5 * 4);
        for (int i = 0; i < pixels.length; i += 4) {
          pixels[i] = 0;
          pixels[i + 1] = 0;
          pixels[i + 2] = 0;
          pixels[i + 3] = 255;
        }
        // Set center (2,2) to white
        final centerIndex = (2 * 5 + 2) * 4;
        pixels[centerIndex] = 255;
        pixels[centerIndex + 1] = 255;
        pixels[centerIndex + 2] = 255;

        // Fractional radius 1.6 should round to 2
        final result = MorphologyProcessor.applyMorphology(
          pixels: pixels,
          width: 5,
          height: 5,
          radiusX: 1.6,
          radiusY: 1.6,
          operatorType: SvgMorphologyOperator.dilate,
          edgeMode: SvgConvolveEdgeMode.duplicate,
        );

        // Pixels at distance 2 should now be white (radius rounds to 2)
        final farIndex = (0 * 5 + 2) * 4;
        expect(result[farIndex], 255);
      });
    });

    group('feConvolveMatrix with kernelUnitLength', () {
      test('Parse feConvolveMatrix with kernelUnitLength', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="convKUL">
      <feConvolveMatrix 
        kernelMatrix="1 0 -1 2 0 -2 1 0 -1"
        kernelUnitLength="2 3"
        edgeMode="wrap"/>
    </filter>
  </defs>
  <rect filter="url(#convKUL)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final filter =
            document.filters!.getById('convKUL') as SvgConvolveMatrixFilter;
        expect(filter.kernelUnitLengthX, 2.0);
        expect(filter.kernelUnitLengthY, 3.0);
        expect(filter.edgeMode, SvgConvolveEdgeMode.wrap);
      });

      test('ConvolveMatrix with kernelUnitLength scaling', () {
        // 4x4 image
        final pixels = Uint8List(4 * 4 * 4);
        for (int i = 0; i < pixels.length; i += 4) {
          pixels[i] = 128; // R
          pixels[i + 1] = 128; // G
          pixels[i + 2] = 128; // B
          pixels[i + 3] = 255; // A
        }

        // Identity-like kernel
        final kernel = <double>[0, 0, 0, 0, 1, 0, 0, 0, 0];

        final result = ConvolveMatrixProcessor.applyConvolution(
          pixels: pixels,
          width: 4,
          height: 4,
          kernel: kernel,
          orderX: 3,
          orderY: 3,
          targetX: 1,
          targetY: 1,
          divisor: 1.0,
          bias: 0.0,
          edgeMode: SvgConvolveEdgeMode.duplicate,
          preserveAlpha: false,
          kernelUnitLengthX: 2.0,
          kernelUnitLengthY: 2.0,
        );

        // Result should still be valid
        expect(result.length, pixels.length);
        expect(result[3], 255); // Alpha preserved
      });

      test('feConvolveMatrix preserveAlpha with edge modes', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="convPA">
      <feConvolveMatrix 
        kernelMatrix="0 -1 0 -1 5 -1 0 -1 0"
        preserveAlpha="true"
        edgeMode="none"/>
    </filter>
  </defs>
  <rect filter="url(#convPA)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final filter =
            document.filters!.getById('convPA') as SvgConvolveMatrixFilter;
        expect(filter.preserveAlpha, isTrue);
        expect(filter.edgeMode, SvgConvolveEdgeMode.none);
      });

      test('ConvolveMatrix preserveAlpha preserves original alpha', () {
        // 2x2 image with varying alpha
        final pixels = Uint8List.fromList([
          255, 0, 0, 128, // semi-transparent red
          0, 255, 0, 64, // more transparent green
          0, 0, 255, 255, // opaque blue
          128, 128, 128, 0, // fully transparent gray
        ]);

        final kernel = <double>[0, 1, 0, 1, 1, 1, 0, 1, 0];

        final result = ConvolveMatrixProcessor.applyConvolution(
          pixels: pixels,
          width: 2,
          height: 2,
          kernel: kernel,
          orderX: 3,
          orderY: 3,
          targetX: 1,
          targetY: 1,
          divisor: 5.0,
          bias: 0.0,
          edgeMode: SvgConvolveEdgeMode.duplicate,
          preserveAlpha: true,
        );

        // Alpha values should be preserved
        expect(result[3], 128); // First pixel alpha
        expect(result[7], 64); // Second pixel alpha
        expect(result[11], 255); // Third pixel alpha
        expect(result[15], 0); // Fourth pixel alpha
      });
    });

    group('feTurbulence Parameter Animation', () {
      test('Parse feTurbulence with animatable baseFrequency', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="turbAnim">
      <feTurbulence baseFrequency="0.05 0.02" numOctaves="3" seed="42" type="fractalNoise">
        <animate attributeName="baseFrequency" from="0.01" to="0.1" dur="2s"/>
      </feTurbulence>
    </filter>
  </defs>
  <rect filter="url(#turbAnim)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final filter =
            document.filters!.getById('turbAnim') as SvgTurbulenceFilter;
        expect(filter.baseFrequencyX, 0.05);
        expect(filter.baseFrequencyY, 0.02);
        expect(filter.numOctaves, 3);
        expect(filter.seed, 42.0);
        expect(filter.noiseType, SvgTurbulenceType.fractalNoise);
      });

      test('Parse feTurbulence with animatable numOctaves', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="turbOct">
      <feTurbulence baseFrequency="0.01" numOctaves="5">
        <animate attributeName="numOctaves" from="1" to="8" dur="3s"/>
      </feTurbulence>
    </filter>
  </defs>
  <rect filter="url(#turbOct)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final filter =
            document.filters!.getById('turbOct') as SvgTurbulenceFilter;
        expect(filter.numOctaves, 5);
      });

      test('Parse feTurbulence with seed animation', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="turbSeed">
      <feTurbulence baseFrequency="0.02" seed="123">
        <animate attributeName="seed" values="0;100;200" dur="5s"/>
      </feTurbulence>
    </filter>
  </defs>
  <rect filter="url(#turbSeed)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final filter =
            document.filters!.getById('turbSeed') as SvgTurbulenceFilter;
        expect(filter.seed, 123.0);
      });

      test('TurbulenceNoiseGenerator produces deterministic output', () {
        final gen1 = TurbulenceNoiseGenerator(42.0);
        final gen2 = TurbulenceNoiseGenerator(42.0);

        final value1 = gen1.noise2D(0.5, 0.5);
        final value2 = gen2.noise2D(0.5, 0.5);

        expect(value1, value2);
      });

      test(
        'TurbulenceNoiseGenerator different seeds produce different output',
        () {
          final gen1 = TurbulenceNoiseGenerator(42.0);
          final gen2 = TurbulenceNoiseGenerator(12345.0);

          // Test at multiple coordinates to ensure different patterns
          final value1a = gen1.noise2D(1.5, 2.5);
          final value2a = gen2.noise2D(1.5, 2.5);

          final value1b = gen1.noise2D(3.7, 4.2);
          final value2b = gen2.noise2D(3.7, 4.2);

          // At least one of the coordinate pairs should have different values
          final hasDifference = value1a != value2a || value1b != value2b;
          expect(
            hasDifference,
            isTrue,
            reason: 'Different seeds should produce different noise patterns',
          );
        },
      );
    });

    group('feTile Advanced Tiling', () {
      test('Parse feTile with subregion', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="tileSubregion">
      <feTile x="10" y="10" width="50" height="50" in="SourceGraphic"/>
    </filter>
  </defs>
  <rect filter="url(#tileSubregion)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final filter =
            document.filters!.getById('tileSubregion') as SvgTileFilter;
        expect(filter.x, 10.0);
        expect(filter.y, 10.0);
        expect(filter.width, 50.0);
        expect(filter.height, 50.0);
        expect(filter.hasSubregion, isTrue);
      });

      test('feTile without subregion has hasSubregion=false', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="tileNoSub">
      <feTile in="SourceGraphic"/>
    </filter>
  </defs>
  <rect filter="url(#tileNoSub)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final filter = document.filters!.getById('tileNoSub') as SvgTileFilter;
        expect(filter.hasSubregion, isFalse);
      });

      test('TileProcessor tiles smaller input to larger output', () {
        // 2x2 input image
        final input = Uint8List.fromList([
          255,
          0,
          0,
          255,
          0,
          255,
          0,
          255,
          0,
          0,
          255,
          255,
          255,
          255,
          0,
          255,
        ]);

        // Tile to 4x4
        final result = TileProcessor.applyTiling(
          inputPixels: input,
          inputWidth: 2,
          inputHeight: 2,
          outputWidth: 4,
          outputHeight: 4,
        );

        expect(result.length, 4 * 4 * 4);

        // First row should be: red, green, red, green
        expect(result[0], 255); // red R
        expect(result[4], 0); // green R
        expect(result[8], 255); // red R (tiled)
        expect(result[12], 0); // green R (tiled)
      });

      test('TileProcessor tiles with offset', () {
        // 2x2 input
        final input = Uint8List.fromList([
          255,
          0,
          0,
          255,
          0,
          255,
          0,
          255,
          0,
          0,
          255,
          255,
          255,
          255,
          255,
          255,
        ]);

        // Tile to 4x4 with offset
        final result = TileProcessor.applyTiling(
          inputPixels: input,
          inputWidth: 2,
          inputHeight: 2,
          outputWidth: 4,
          outputHeight: 4,
          tileX: 1,
          tileY: 1,
        );

        expect(result.length, 4 * 4 * 4);
      });

      test('TileProcessor handles input larger than tile', () {
        // 4x4 input
        final input = Uint8List(4 * 4 * 4);
        for (int i = 0; i < input.length; i += 4) {
          input[i] = 128;
          input[i + 1] = 128;
          input[i + 2] = 128;
          input[i + 3] = 255;
        }

        // Tile with 2x2 tile size
        final result = TileProcessor.applyTiling(
          inputPixels: input,
          inputWidth: 4,
          inputHeight: 4,
          outputWidth: 4,
          outputHeight: 4,
          tileWidth: 2,
          tileHeight: 2,
        );

        expect(result.length, input.length);
      });
    });

    group('feDisplacementMap Scale Animation and Edge Handling', () {
      test('Parse feDisplacementMap with scale', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="dispScale">
      <feDisplacementMap in="SourceGraphic" in2="map" scale="20" 
        xChannelSelector="R" yChannelSelector="G"/>
    </filter>
  </defs>
  <rect filter="url(#dispScale)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final filter =
            document.filters!.getById('dispScale') as SvgDisplacementMapFilter;
        expect(filter.scale, 20.0);
        expect(filter.xChannelSelector, SvgChannelSelector.r);
        expect(filter.yChannelSelector, SvgChannelSelector.g);
      });

      test('Parse feDisplacementMap with scale animation', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="dispAnim">
      <feDisplacementMap in="SourceGraphic" in2="map" scale="10">
        <animate attributeName="scale" from="0" to="50" dur="2s"/>
      </feDisplacementMap>
    </filter>
  </defs>
  <rect filter="url(#dispAnim)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final filter =
            document.filters!.getById('dispAnim') as SvgDisplacementMapFilter;
        expect(filter.scale, 10.0);
      });

      test('DisplacementMapProcessor with zero scale is identity', () {
        final pixels = Uint8List.fromList([
          255,
          0,
          0,
          255,
          0,
          255,
          0,
          255,
          0,
          0,
          255,
          255,
          128,
          128,
          128,
          255,
        ]);

        final mapPixels = Uint8List.fromList([
          128,
          128,
          128,
          255,
          128,
          128,
          128,
          255,
          128,
          128,
          128,
          255,
          128,
          128,
          128,
          255,
        ]);

        final result = DisplacementMapProcessor.applyDisplacement(
          inputPixels: pixels,
          mapPixels: mapPixels,
          width: 2,
          height: 2,
          scale: 0.0,
          xChannel: SvgChannelSelector.r,
          yChannel: SvgChannelSelector.g,
          edgeMode: SvgDisplacementEdgeMode.none,
        );

        // Zero scale means no displacement - should be identity
        expect(result, equals(pixels));
      });

      test('DisplacementMapProcessor with clamp edge mode', () {
        final pixels = Uint8List.fromList([
          255,
          0,
          0,
          255,
          0,
          255,
          0,
          255,
          0,
          0,
          255,
          255,
          128,
          128,
          128,
          255,
        ]);

        // Map with values that cause displacement outside bounds
        final mapPixels = Uint8List.fromList([
          255,
          255,
          0,
          255,
          0,
          0,
          0,
          255,
          128,
          128,
          0,
          255,
          128,
          128,
          0,
          255,
        ]);

        final result = DisplacementMapProcessor.applyDisplacement(
          inputPixels: pixels,
          mapPixels: mapPixels,
          width: 2,
          height: 2,
          scale: 10.0,
          xChannel: SvgChannelSelector.r,
          yChannel: SvgChannelSelector.g,
          edgeMode: SvgDisplacementEdgeMode.clamp,
        );

        // Result should use edge pixels for out-of-bounds
        expect(result.length, pixels.length);
      });

      test('DisplacementMapProcessor with wrap edge mode', () {
        final pixels = Uint8List.fromList([
          255,
          0,
          0,
          255,
          0,
          255,
          0,
          255,
          0,
          0,
          255,
          255,
          128,
          128,
          128,
          255,
        ]);

        final mapPixels = Uint8List.fromList([
          255,
          255,
          0,
          255,
          128,
          128,
          0,
          255,
          128,
          128,
          0,
          255,
          128,
          128,
          0,
          255,
        ]);

        final result = DisplacementMapProcessor.applyDisplacement(
          inputPixels: pixels,
          mapPixels: mapPixels,
          width: 2,
          height: 2,
          scale: 5.0,
          xChannel: SvgChannelSelector.r,
          yChannel: SvgChannelSelector.g,
          edgeMode: SvgDisplacementEdgeMode.wrap,
        );

        expect(result.length, pixels.length);
      });

      test(
        'DisplacementMapProcessor with none edge mode returns transparent black',
        () {
          // Single pixel
          final pixels = Uint8List.fromList([255, 0, 0, 255]);
          // Map causes large displacement
          final mapPixels = Uint8List.fromList([255, 255, 0, 255]);

          final result = DisplacementMapProcessor.applyDisplacement(
            inputPixels: pixels,
            mapPixels: mapPixels,
            width: 1,
            height: 1,
            scale: 100.0, // Large scale to ensure out-of-bounds
            xChannel: SvgChannelSelector.r,
            yChannel: SvgChannelSelector.g,
            edgeMode: SvgDisplacementEdgeMode.none,
          );

          // Out-of-bounds should return transparent black
          expect(result[0], 0); // R
          expect(result[1], 0); // G
          expect(result[2], 0); // B
          expect(result[3], 0); // A
        },
      );

      test('feDisplacementMap channel selectors', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="dispChannels">
      <feDisplacementMap in="SourceGraphic" in2="map" scale="10" 
        xChannelSelector="B" yChannelSelector="A"/>
    </filter>
  </defs>
  <rect filter="url(#dispChannels)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final filter =
            document.filters!.getById('dispChannels')
                as SvgDisplacementMapFilter;
        expect(filter.xChannelSelector, SvgChannelSelector.b);
        expect(filter.yChannelSelector, SvgChannelSelector.a);
      });
    });
  });
}
