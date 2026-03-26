import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_svg/src/animation/svg_parser.dart';
import 'package:flutter_svg/src/animation/svg_filters.dart';

void main() {
  group('Filter Primitive Edge Cases - Morphology, Convolve, Turbulence', () {
    group('feMorphology Edge Cases', () {
      test('feMorphology erode with asymmetric radius', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="erodeAsym">
      <feMorphology operator="erode" radius="5 2"/>
    </filter>
  </defs>
  <rect filter="url(#erodeAsym)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final filter =
            document.filters!.getById('erodeAsym') as SvgMorphologyFilter;
        expect(filter.operatorType, SvgMorphologyOperator.erode);
        expect(filter.radiusX, 5.0);
        expect(filter.radiusY, 2.0);

        // Verify the ImageFilter is created correctly
        final imageFilter = filter.apply();
        expect(imageFilter, isNotNull);
      });

      test('feMorphology dilate with asymmetric radius', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="dilateAsym">
      <feMorphology operator="dilate" radius="3 8"/>
    </filter>
  </defs>
  <rect filter="url(#dilateAsym)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final filter =
            document.filters!.getById('dilateAsym') as SvgMorphologyFilter;
        expect(filter.operatorType, SvgMorphologyOperator.dilate);
        expect(filter.radiusX, 3.0);
        expect(filter.radiusY, 8.0);

        // Verify the ImageFilter is created correctly
        final imageFilter = filter.apply();
        expect(imageFilter, isNotNull);
      });

      test('feMorphology with radius=0 (passthrough)', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="morphZero">
      <feMorphology operator="erode" radius="0"/>
    </filter>
  </defs>
  <rect filter="url(#morphZero)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final filter =
            document.filters!.getById('morphZero') as SvgMorphologyFilter;
        expect(filter.radiusX, 0.0);
        expect(filter.radiusY, 0.0);

        // Radius 0 should return null (passthrough - no morphology applied)
        final imageFilter = filter.apply();
        expect(imageFilter, isNull);
      });

      test('feMorphology with negative radius (treat as 0)', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="morphNeg">
      <feMorphology operator="dilate" radius="-5 -3"/>
    </filter>
  </defs>
  <rect filter="url(#morphNeg)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final filter =
            document.filters!.getById('morphNeg') as SvgMorphologyFilter;
        // Parser may store negative values, but apply() should treat as 0
        // Per SVG spec, negative radius is treated as 0

        // apply() should clamp negative values to 0 and return null (passthrough)
        final imageFilter = filter.apply();
        expect(imageFilter, isNull);
      });

      test('MorphologyProcessor erode with asymmetric radius', () {
        // 5x5 image with white center
        final pixels = Uint8List(5 * 5 * 4);
        for (int i = 0; i < pixels.length; i += 4) {
          pixels[i] = 0; // R
          pixels[i + 1] = 0; // G
          pixels[i + 2] = 0; // B
          pixels[i + 3] = 255; // A
        }
        // Set center (2,2) to white
        final centerIndex = (2 * 5 + 2) * 4;
        pixels[centerIndex] = 255;
        pixels[centerIndex + 1] = 255;
        pixels[centerIndex + 2] = 255;

        // Apply erode with asymmetric radius: radiusX=2, radiusY=1
        final result = MorphologyProcessor.applyMorphology(
          pixels: pixels,
          width: 5,
          height: 5,
          radiusX: 2,
          radiusY: 1,
          operatorType: SvgMorphologyOperator.erode,
          edgeMode: SvgConvolveEdgeMode.duplicate,
        );

        // After erode with asymmetric radius, center should be black
        // because erode takes minimum from neighborhood
        expect(result[centerIndex], 0);
        expect(result[centerIndex + 1], 0);
        expect(result[centerIndex + 2], 0);
      });

      test('MorphologyProcessor dilate with asymmetric radius', () {
        // 5x5 image with single white pixel in center
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

        // Apply dilate with asymmetric radius: radiusX=1, radiusY=2
        final result = MorphologyProcessor.applyMorphology(
          pixels: pixels,
          width: 5,
          height: 5,
          radiusX: 1,
          radiusY: 2,
          operatorType: SvgMorphologyOperator.dilate,
          edgeMode: SvgConvolveEdgeMode.duplicate,
        );

        // After dilate, pixels at (1,2), (3,2), (2,0), (2,1), (2,3), (2,4) should be white
        // Check horizontal neighbors (within radiusX=1)
        final leftIndex = (2 * 5 + 1) * 4;
        final rightIndex = (2 * 5 + 3) * 4;
        expect(result[leftIndex], 255);
        expect(result[rightIndex], 255);

        // Check vertical neighbors (within radiusY=2)
        final topIndex = (0 * 5 + 2) * 4;
        final bottomIndex = (4 * 5 + 2) * 4;
        expect(result[topIndex], 255);
        expect(result[bottomIndex], 255);
      });
    });

    group('feConvolveMatrix Edge Cases', () {
      test('feConvolveMatrix with edgeMode="duplicate"', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="convDup">
      <feConvolveMatrix 
        kernelMatrix="1 1 1 1 1 1 1 1 1"
        edgeMode="duplicate"/>
    </filter>
  </defs>
  <rect filter="url(#convDup)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final filter =
            document.filters!.getById('convDup') as SvgConvolveMatrixFilter;
        expect(filter.edgeMode, SvgConvolveEdgeMode.duplicate);

        // Verify processor handles duplicate edge mode correctly
        final pixels = Uint8List.fromList([
          255,
          255,
          255,
          255,
          255,
          255,
          255,
          255,
          255,
          255,
          255,
          255,
          255,
          255,
          255,
          255,
        ]);

        final result = ConvolveMatrixProcessor.applyConvolution(
          pixels: pixels,
          width: 2,
          height: 2,
          kernel: filter.kernelMatrix,
          orderX: filter.orderX,
          orderY: filter.orderY,
          targetX: filter.targetX,
          targetY: filter.targetY,
          divisor: filter.divisor,
          bias: filter.bias,
          edgeMode: SvgConvolveEdgeMode.duplicate,
          preserveAlpha: false,
        );

        // With all-white image and box blur kernel with duplicate edges,
        // result should remain white (255)
        expect(result[0], 255);
      });

      test('feConvolveMatrix with edgeMode="wrap"', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="convWrap">
      <feConvolveMatrix 
        kernelMatrix="0 0 0 0 1 0 0 0 0"
        edgeMode="wrap"/>
    </filter>
  </defs>
  <rect filter="url(#convWrap)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final filter =
            document.filters!.getById('convWrap') as SvgConvolveMatrixFilter;
        expect(filter.edgeMode, SvgConvolveEdgeMode.wrap);

        // Verify processor wraps coordinates correctly
        final pixels = Uint8List.fromList([
          255, 0, 0, 255, // red
          0, 255, 0, 255, // green
          0, 0, 255, 255, // blue
          255, 255, 255, 255, // white
        ]);

        final result = ConvolveMatrixProcessor.applyConvolution(
          pixels: pixels,
          width: 2,
          height: 2,
          kernel: <double>[0, 0, 0, 0, 1, 0, 0, 0, 0],
          orderX: 3,
          orderY: 3,
          targetX: 1,
          targetY: 1,
          divisor: 1.0,
          bias: 0.0,
          edgeMode: SvgConvolveEdgeMode.wrap,
          preserveAlpha: false,
        );

        // Identity kernel should preserve pixels
        expect(result, equals(pixels));
      });

      test('feConvolveMatrix with edgeMode="none"', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="convNone">
      <feConvolveMatrix 
        kernelMatrix="1 1 1 1 1 1 1 1 1"
        edgeMode="none"/>
    </filter>
  </defs>
  <rect filter="url(#convNone)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final filter =
            document.filters!.getById('convNone') as SvgConvolveMatrixFilter;
        expect(filter.edgeMode, SvgConvolveEdgeMode.none);

        // With edgeMode=none, pixels outside bounds are transparent black
        final pixels = Uint8List.fromList([
          255,
          255,
          255,
          255,
          255,
          255,
          255,
          255,
          255,
          255,
          255,
          255,
          255,
          255,
          255,
          255,
        ]);

        final result = ConvolveMatrixProcessor.applyConvolution(
          pixels: pixels,
          width: 2,
          height: 2,
          kernel: <double>[1, 1, 1, 1, 1, 1, 1, 1, 1],
          orderX: 3,
          orderY: 3,
          targetX: 1,
          targetY: 1,
          divisor: 9.0,
          bias: 0.0,
          edgeMode: SvgConvolveEdgeMode.none,
          preserveAlpha: false,
        );

        // Only 4 of 9 kernel cells are in-bounds for corner pixels
        // 4 * 255 / 9 ≈ 113
        expect(result[0], closeTo(113, 1));
      });

      test('feConvolveMatrix with preserveAlpha=true', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="convPA">
      <feConvolveMatrix 
        kernelMatrix="0 -1 0 -1 5 -1 0 -1 0"
        preserveAlpha="true"/>
    </filter>
  </defs>
  <rect filter="url(#convPA)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final filter =
            document.filters!.getById('convPA') as SvgConvolveMatrixFilter;
        expect(filter.preserveAlpha, isTrue);

        // Verify alpha is preserved during convolution
        final pixels = Uint8List.fromList([
          255, 0, 0, 128, // semi-transparent red
          0, 255, 0, 64, // quarter-transparent green
          0, 0, 255, 255, // opaque blue
          128, 128, 128, 0, // fully transparent gray
        ]);

        final result = ConvolveMatrixProcessor.applyConvolution(
          pixels: pixels,
          width: 2,
          height: 2,
          kernel: filter.kernelMatrix,
          orderX: filter.orderX,
          orderY: filter.orderY,
          targetX: filter.targetX,
          targetY: filter.targetY,
          divisor: filter.divisor,
          bias: filter.bias,
          edgeMode: filter.edgeMode,
          preserveAlpha: true,
        );

        // Alpha values must be preserved exactly
        expect(result[3], 128);
        expect(result[7], 64);
        expect(result[11], 255);
        expect(result[15], 0);
      });

      test('feConvolveMatrix with explicit divisor and bias', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="convDB">
      <feConvolveMatrix 
        kernelMatrix="1"
        order="1"
        divisor="2"
        bias="0.25"/>
    </filter>
  </defs>
  <rect filter="url(#convDB)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final filter =
            document.filters!.getById('convDB') as SvgConvolveMatrixFilter;
        expect(filter.divisor, 2.0);
        expect(filter.bias, 0.25);

        // Test computation: (pixel * kernel / divisor) + bias*255
        // With black pixel (0): 0/2 + 63.75 ≈ 64
        final pixels = Uint8List.fromList([0, 0, 0, 255]);

        final result = ConvolveMatrixProcessor.applyConvolution(
          pixels: pixels,
          width: 1,
          height: 1,
          kernel: <double>[1],
          orderX: 1,
          orderY: 1,
          targetX: 0,
          targetY: 0,
          divisor: 2.0,
          bias: 0.25,
          edgeMode: SvgConvolveEdgeMode.duplicate,
          preserveAlpha: false,
        );

        // 0 * 1 / 2 + 0.25 * 255 = 63.75 → 64
        expect(result[0], closeTo(64, 1));
        expect(result[1], closeTo(64, 1));
        expect(result[2], closeTo(64, 1));
      });

      test('feConvolveMatrix with targetX/targetY offset', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="convTarget">
      <feConvolveMatrix 
        kernelMatrix="0 1 0 0 0 0 0 0 0"
        targetX="1"
        targetY="0"/>
    </filter>
  </defs>
  <rect filter="url(#convTarget)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final filter =
            document.filters!.getById('convTarget') as SvgConvolveMatrixFilter;
        expect(filter.targetX, 1);
        expect(filter.targetY, 0);

        // The kernel has 1 at position (1,0), so with targetX=1, targetY=0
        // This means we sample from one row above the current pixel
        final pixels = Uint8List.fromList([
          255, 0, 0, 255, // top-left (0,0)
          0, 255, 0, 255, // top-right (1,0)
          0, 0, 255, 255, // bottom-left (0,1)
          128, 128, 128, 255, // bottom-right (1,1)
        ]);

        final result = ConvolveMatrixProcessor.applyConvolution(
          pixels: pixels,
          width: 2,
          height: 2,
          kernel: <double>[0, 1, 0, 0, 0, 0, 0, 0, 0],
          orderX: 3,
          orderY: 3,
          targetX: 1,
          targetY: 0,
          divisor: 1.0,
          bias: 0.0,
          edgeMode: SvgConvolveEdgeMode.duplicate,
          preserveAlpha: false,
        );

        // Result should have valid pixel data
        expect(result.length, pixels.length);
      });

      test('feConvolveMatrix divisor defaults to kernel sum, 0 becomes 1', () {
        // Test default divisor calculation
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="convDefDiv">
      <feConvolveMatrix 
        kernelMatrix="1 1 1 1 1 1 1 1 1"/>
    </filter>
  </defs>
  <rect filter="url(#convDefDiv)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final filter =
            document.filters!.getById('convDefDiv') as SvgConvolveMatrixFilter;
        // Sum of kernel is 9, so divisor should be 9
        expect(filter.divisor, 9.0);

        // Test that zero-sum kernel gets divisor of 1
        final svgString2 = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="convZeroSum">
      <feConvolveMatrix 
        kernelMatrix="-1 -1 -1 -1 8 -1 -1 -1 -1"/>
    </filter>
  </defs>
  <rect filter="url(#convZeroSum)"/>
</svg>
''';

        final document2 = SvgParser.parse(svgString2);
        final filter2 =
            document2.filters!.getById('convZeroSum')
                as SvgConvolveMatrixFilter;
        // Sum of edge detection kernel is 0, so divisor should be 1
        expect(filter2.divisor, 1.0);
      });
    });

    group('feTurbulence Edge Cases', () {
      test('feTurbulence with two baseFrequency values', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="turbTwoFreq">
      <feTurbulence baseFrequency="0.05 0.02" numOctaves="3"/>
    </filter>
  </defs>
  <rect filter="url(#turbTwoFreq)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final filter =
            document.filters!.getById('turbTwoFreq') as SvgTurbulenceFilter;
        expect(filter.baseFrequencyX, 0.05);
        expect(filter.baseFrequencyY, 0.02);
      });

      test('feTurbulence with numOctaves=0 clamped to 1', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="turbZeroOct">
      <feTurbulence baseFrequency="0.01" numOctaves="0"/>
    </filter>
  </defs>
  <rect filter="url(#turbZeroOct)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final filter =
            document.filters!.getById('turbZeroOct') as SvgTurbulenceFilter;
        // Parser clamps numOctaves to minimum of 1 (valid range: 1-64)
        // This ensures at least one octave of noise is generated
        expect(filter.numOctaves, 1);
      });

      test('feTurbulence with stitchTiles attribute', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="turbStitch">
      <feTurbulence baseFrequency="0.05" stitchTiles="stitch"/>
    </filter>
  </defs>
  <rect filter="url(#turbStitch)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final filter =
            document.filters!.getById('turbStitch') as SvgTurbulenceFilter;
        expect(filter.stitchTiles, SvgTurbulenceStitchTiles.stitch);
      });

      test('feTurbulence with noStitch default', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="turbNoStitch">
      <feTurbulence baseFrequency="0.05"/>
    </filter>
  </defs>
  <rect filter="url(#turbNoStitch)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final filter =
            document.filters!.getById('turbNoStitch') as SvgTurbulenceFilter;
        expect(filter.stitchTiles, SvgTurbulenceStitchTiles.noStitch);
      });

      test('feTurbulence with seed for deterministic noise', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="turbSeed">
      <feTurbulence baseFrequency="0.01" seed="12345"/>
    </filter>
  </defs>
  <rect filter="url(#turbSeed)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final filter =
            document.filters!.getById('turbSeed') as SvgTurbulenceFilter;
        expect(filter.seed, 12345.0);

        // Verify deterministic noise generation
        final gen1 = TurbulenceNoiseGenerator(12345.0);
        final gen2 = TurbulenceNoiseGenerator(12345.0);
        expect(gen1.noise2D(0.5, 0.5), gen2.noise2D(0.5, 0.5));
      });

      test('feTurbulence negative numOctaves clamped to 1', () {
        // Parser clamps invalid numOctaves values to valid range (1-64)
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="turbNegOct">
      <feTurbulence baseFrequency="0.01" numOctaves="-5"/>
    </filter>
  </defs>
  <rect filter="url(#turbNegOct)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final filter =
            document.filters!.getById('turbNegOct') as SvgTurbulenceFilter;
        // Negative values are clamped to minimum (1)
        expect(filter.numOctaves, 1);
      });
    });
  });
}
