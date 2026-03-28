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

    group('feTurbulence stitchTiles Seamless Tiling', () {
      test('stitchTiles="stitch" produces seamless tiling at boundaries', () {
        // Generate noise with stitching enabled
        final generator = TurbulenceNoiseGenerator(42.0);
        const width = 64.0;
        const height = 64.0;
        const baseFreqX = 0.1;
        const baseFreqY = 0.1;

        generator.setupStitching(width, height, baseFreqX, baseFreqY);

        // Sample noise at left edge (x=0) and right edge (x=width)
        // These should produce the same values for seamless tiling
        final leftEdgeY = 32.0;
        final leftValue = generator.fractalNoise(
          x: 0.0,
          y: leftEdgeY,
          baseFreqX: baseFreqX,
          baseFreqY: baseFreqY,
          numOctaves: 2,
          isFractalNoise: false,
          stitch: true,
        );

        // At x=width, the noise coordinate is width*baseFreqX
        // which should wrap to 0 in stitching mode
        final rightValue = generator.fractalNoise(
          x: width,
          y: leftEdgeY,
          baseFreqX: baseFreqX,
          baseFreqY: baseFreqY,
          numOctaves: 2,
          isFractalNoise: false,
          stitch: true,
        );

        // The values at the boundaries should match (within floating point tolerance)
        expect(leftValue, closeTo(rightValue, 0.01));
      });

      test('stitchTiles="stitch" produces seamless tiling at top/bottom', () {
        final generator = TurbulenceNoiseGenerator(42.0);
        const width = 64.0;
        const height = 64.0;
        const baseFreqX = 0.1;
        const baseFreqY = 0.1;

        generator.setupStitching(width, height, baseFreqX, baseFreqY);

        // Sample noise at top edge (y=0) and bottom edge (y=height)
        final edgeX = 32.0;
        final topValue = generator.fractalNoise(
          x: edgeX,
          y: 0.0,
          baseFreqX: baseFreqX,
          baseFreqY: baseFreqY,
          numOctaves: 2,
          isFractalNoise: false,
          stitch: true,
        );

        final bottomValue = generator.fractalNoise(
          x: edgeX,
          y: height,
          baseFreqX: baseFreqX,
          baseFreqY: baseFreqY,
          numOctaves: 2,
          isFractalNoise: false,
          stitch: true,
        );

        // The values at the boundaries should match
        expect(topValue, closeTo(bottomValue, 0.01));
      });

      test('stitchTiles="stitch" corner consistency', () {
        final generator = TurbulenceNoiseGenerator(123.0);
        const width = 100.0;
        const height = 100.0;
        const baseFreqX = 0.05;
        const baseFreqY = 0.05;

        generator.setupStitching(width, height, baseFreqX, baseFreqY);

        // All four corners should have the same value when tiling seamlessly
        final topLeft = generator.fractalNoise(
          x: 0.0,
          y: 0.0,
          baseFreqX: baseFreqX,
          baseFreqY: baseFreqY,
          numOctaves: 1,
          isFractalNoise: true,
          stitch: true,
        );

        final topRight = generator.fractalNoise(
          x: width,
          y: 0.0,
          baseFreqX: baseFreqX,
          baseFreqY: baseFreqY,
          numOctaves: 1,
          isFractalNoise: true,
          stitch: true,
        );

        final bottomLeft = generator.fractalNoise(
          x: 0.0,
          y: height,
          baseFreqX: baseFreqX,
          baseFreqY: baseFreqY,
          numOctaves: 1,
          isFractalNoise: true,
          stitch: true,
        );

        final bottomRight = generator.fractalNoise(
          x: width,
          y: height,
          baseFreqX: baseFreqX,
          baseFreqY: baseFreqY,
          numOctaves: 1,
          isFractalNoise: true,
          stitch: true,
        );

        // All corners should match
        expect(topLeft, closeTo(topRight, 0.01));
        expect(topLeft, closeTo(bottomLeft, 0.01));
        expect(topLeft, closeTo(bottomRight, 0.01));
      });

      test('stitchTiles="noStitch" does NOT produce seamless tiling', () {
        final generator = TurbulenceNoiseGenerator(42.0);
        const baseFreqX = 0.05;
        const baseFreqY = 0.05;

        // Without stitching, boundaries should generally NOT match
        final leftValue = generator.fractalNoise(
          x: 0.0,
          y: 32.0,
          baseFreqX: baseFreqX,
          baseFreqY: baseFreqY,
          numOctaves: 2,
          isFractalNoise: false,
          stitch: false, // noStitch mode
        );

        final rightValue = generator.fractalNoise(
          x: 64.0,
          y: 32.0,
          baseFreqX: baseFreqX,
          baseFreqY: baseFreqY,
          numOctaves: 2,
          isFractalNoise: false,
          stitch: false, // noStitch mode
        );

        // Values at boundaries should be different without stitching
        // (very unlikely to be equal by chance)
        expect((leftValue - rightValue).abs(), greaterThan(0.001));
      });

      test('TurbulenceTileRenderer generates tileable output with stitch', () {
        final filter = SvgTurbulenceFilter(
          id: 'test',
          baseFrequencyX: 0.05,
          baseFrequencyY: 0.05,
          numOctaves: 2,
          seed: 42.0,
          stitchTiles: SvgTurbulenceStitchTiles.stitch,
          noiseType: SvgTurbulenceType.turbulence,
        );

        const width = 32;
        const height = 32;

        final pixels = TurbulenceTileRenderer.generateTiled(
          width: width,
          height: height,
          turbulence: filter,
        );

        // Just verify the output is valid (non-empty, correct size)
        expect(pixels.length, width * height * 4);
      });

      test('stitchTiles with zero baseFrequency handled gracefully', () {
        final generator = TurbulenceNoiseGenerator(42.0);

        // Zero frequency should result in wrapX/wrapY of at least 1
        generator.setupStitching(100.0, 100.0, 0.0, 0.0);

        // Should not throw, should produce valid (likely constant) output
        final value = generator.fractalNoise(
          x: 50.0,
          y: 50.0,
          baseFreqX: 0.0,
          baseFreqY: 0.0,
          numOctaves: 1,
          isFractalNoise: false,
          stitch: true,
        );

        // Value should be in valid range [0, 1] for turbulence
        expect(value, greaterThanOrEqualTo(0.0));
        expect(value, lessThanOrEqualTo(1.0));
      });

      test('stitchTiles with very small tile size', () {
        final generator = TurbulenceNoiseGenerator(42.0);
        const width = 4.0;
        const height = 4.0;
        const baseFreqX = 0.5;
        const baseFreqY = 0.5;

        generator.setupStitching(width, height, baseFreqX, baseFreqY);

        // With 4x4 tile and baseFreq=0.5, wrapX = floor(4*0.5) = 2
        final leftValue = generator.fractalNoise(
          x: 0.0,
          y: 2.0,
          baseFreqX: baseFreqX,
          baseFreqY: baseFreqY,
          numOctaves: 1,
          isFractalNoise: false,
          stitch: true,
        );

        final rightValue = generator.fractalNoise(
          x: width,
          y: 2.0,
          baseFreqX: baseFreqX,
          baseFreqY: baseFreqY,
          numOctaves: 1,
          isFractalNoise: false,
          stitch: true,
        );

        expect(leftValue, closeTo(rightValue, 0.01));
      });

      test('stitchTiles with large tile size', () {
        final generator = TurbulenceNoiseGenerator(42.0);
        const width = 512.0;
        const height = 512.0;
        const baseFreqX = 0.01;
        const baseFreqY = 0.01;

        generator.setupStitching(width, height, baseFreqX, baseFreqY);

        final leftValue = generator.fractalNoise(
          x: 0.0,
          y: 256.0,
          baseFreqX: baseFreqX,
          baseFreqY: baseFreqY,
          numOctaves: 2,
          isFractalNoise: false,
          stitch: true,
        );

        final rightValue = generator.fractalNoise(
          x: width,
          y: 256.0,
          baseFreqX: baseFreqX,
          baseFreqY: baseFreqY,
          numOctaves: 2,
          isFractalNoise: false,
          stitch: true,
        );

        expect(leftValue, closeTo(rightValue, 0.01));
      });

      test('stitchTiles with multiple octaves maintains seamlessness', () {
        final generator = TurbulenceNoiseGenerator(99.0);
        const width = 64.0;
        const height = 64.0;
        const baseFreqX = 0.1;
        const baseFreqY = 0.1;

        generator.setupStitching(width, height, baseFreqX, baseFreqY);

        // Test with multiple octaves (4)
        final leftValue = generator.fractalNoise(
          x: 0.0,
          y: 32.0,
          baseFreqX: baseFreqX,
          baseFreqY: baseFreqY,
          numOctaves: 4,
          isFractalNoise: true,
          stitch: true,
        );

        final rightValue = generator.fractalNoise(
          x: width,
          y: 32.0,
          baseFreqX: baseFreqX,
          baseFreqY: baseFreqY,
          numOctaves: 4,
          isFractalNoise: true,
          stitch: true,
        );

        expect(leftValue, closeTo(rightValue, 0.01));
      });

      test('noise2D respects octave parameter for stitching wrap', () {
        final generator = TurbulenceNoiseGenerator(42.0);
        generator.setupStitching(64.0, 64.0, 0.1, 0.1);

        // Base octave (0): wrapX = floor(64*0.1) = 6
        // So noise should repeat at interval 6 in frequency space
        final val0 = generator.noise2D(0.0, 0.0, stitch: true, octave: 0);
        final val6 = generator.noise2D(6.0, 0.0, stitch: true, octave: 0);
        expect(val0, closeTo(val6, 0.001));

        // Octave 1: wrapX = 6 << 1 = 12
        final val0_oct1 = generator.noise2D(0.0, 0.0, stitch: true, octave: 1);
        final val12_oct1 = generator.noise2D(
          12.0,
          0.0,
          stitch: true,
          octave: 1,
        );
        expect(val0_oct1, closeTo(val12_oct1, 0.001));
      });

      test('resetStitching returns to default lattice size', () {
        final generator = TurbulenceNoiseGenerator(42.0);
        generator.setupStitching(64.0, 64.0, 0.1, 0.1);

        // After reset, noise should use default lattice size (256)
        generator.resetStitching();

        // Noise should repeat at 256 intervals, not the previous stitch size
        final val0 = generator.noise2D(0.0, 0.0, stitch: true, octave: 0);
        final val256 = generator.noise2D(256.0, 0.0, stitch: true, octave: 0);
        expect(val0, closeTo(val256, 0.001));
      });

      test('TurbulenceNoiseGenerator generatePixel with stitch', () {
        final generator = TurbulenceNoiseGenerator(42.0);
        generator.setupStitching(64.0, 64.0, 0.1, 0.1);

        // Generate a pixel at the left edge
        final leftColor = generator.generatePixel(
          x: 0.0,
          y: 32.0,
          baseFreqX: 0.1,
          baseFreqY: 0.1,
          numOctaves: 2,
          isFractalNoise: false,
          stitch: true,
        );

        // Generate a pixel at the right edge (which wraps)
        final rightColor = generator.generatePixel(
          x: 64.0,
          y: 32.0,
          baseFreqX: 0.1,
          baseFreqY: 0.1,
          numOctaves: 2,
          isFractalNoise: false,
          stitch: true,
        );

        // RGBA values should match at the boundaries
        expect(leftColor.r, closeTo(rightColor.r, 0.02));
        expect(leftColor.g, closeTo(rightColor.g, 0.02));
        expect(leftColor.b, closeTo(rightColor.b, 0.02));
        expect(leftColor.a, closeTo(rightColor.a, 0.02));
      });
    });
  });
}
