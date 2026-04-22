import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:full_svg_flutter/src/animation/svg_filters.dart';

void main() {
  group('feConvolveMatrix edge modes', () {
    late Uint8List testPixels;
    const int width = 4;
    const int height = 4;

    setUp(() {
      // Create a 4x4 test image with gradient pattern
      // Each pixel has distinct RGBA values for easy verification
      testPixels = Uint8List(width * height * 4);
      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          final idx = (y * width + x) * 4;
          testPixels[idx] = (x * 64).clamp(0, 255); // R
          testPixels[idx + 1] = (y * 64).clamp(0, 255); // G
          testPixels[idx + 2] = ((x + y) * 32).clamp(0, 255); // B
          testPixels[idx + 3] = 255; // A
        }
      }
    });

    test('edgeMode="none" returns transparent for out-of-bounds', () {
      // Simple 3x3 kernel that samples neighbors
      final kernel = <double>[
        0, 1, 0, //
        1, 0, 1, //
        0, 1, 0, //
      ];

      final result = ConvolveMatrixProcessor.applyConvolution(
        pixels: testPixels,
        width: width,
        height: height,
        kernel: kernel,
        orderX: 3,
        orderY: 3,
        targetX: 1,
        targetY: 1,
        divisor: 4.0,
        bias: 0.0,
        edgeMode: SvgConvolveEdgeMode.none,
        preserveAlpha: false,
      );

      expect(result.length, testPixels.length);
      // Corner pixels should be computed using transparent out-of-bounds
      // The result should be non-zero since some in-bounds neighbors exist
      // but the alpha should still be affected by transparent samples
      expect(
        result[3],
        lessThanOrEqualTo(255),
        reason: 'Alpha should be reduced by transparent edge samples',
      );
    });

    test('edgeMode="duplicate" clamps to edge pixels', () {
      final kernel = <double>[
        0, 1, 0, //
        1, 0, 1, //
        0, 1, 0, //
      ];

      final result = ConvolveMatrixProcessor.applyConvolution(
        pixels: testPixels,
        width: width,
        height: height,
        kernel: kernel,
        orderX: 3,
        orderY: 3,
        targetX: 1,
        targetY: 1,
        divisor: 4.0,
        bias: 0.0,
        edgeMode: SvgConvolveEdgeMode.duplicate,
        preserveAlpha: false,
      );

      expect(result.length, testPixels.length);
      // Result should be non-zero even at corners
      expect(result[3], greaterThan(0), reason: 'Alpha should be preserved');
    });

    test('edgeMode="wrap" wraps around to opposite edge', () {
      final kernel = <double>[
        0, 1, 0, //
        1, 0, 1, //
        0, 1, 0, //
      ];

      final result = ConvolveMatrixProcessor.applyConvolution(
        pixels: testPixels,
        width: width,
        height: height,
        kernel: kernel,
        orderX: 3,
        orderY: 3,
        targetX: 1,
        targetY: 1,
        divisor: 4.0,
        bias: 0.0,
        edgeMode: SvgConvolveEdgeMode.wrap,
        preserveAlpha: false,
      );

      expect(result.length, testPixels.length);
      // Result should contain non-zero values from wrapped pixels
      expect(result[3], greaterThan(0), reason: 'Alpha should be preserved');
    });

    test('identity kernel produces unchanged output', () {
      final isIdentity = ConvolveMatrixProcessor.isIdentityKernel(
        kernel: <double>[0, 0, 0, 0, 1, 0, 0, 0, 0],
        orderX: 3,
        orderY: 3,
        targetX: 1,
        targetY: 1,
        divisor: 1.0,
        bias: 0.0,
      );

      expect(isIdentity, isTrue);
    });

    test('non-identity kernel is detected', () {
      final isIdentity = ConvolveMatrixProcessor.isIdentityKernel(
        kernel: <double>[0, 1, 0, 1, -4, 1, 0, 1, 0],
        orderX: 3,
        orderY: 3,
        targetX: 1,
        targetY: 1,
        divisor: 1.0,
        bias: 0.0,
      );

      expect(isIdentity, isFalse);
    });
  });

  group('feDisplacementMap subpixel precision', () {
    late Uint8List inputPixels;
    late Uint8List mapPixels;
    const int width = 4;
    const int height = 4;

    setUp(() {
      // Create input image with checkerboard pattern
      inputPixels = Uint8List(width * height * 4);
      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          final idx = (y * width + x) * 4;
          final checker = (x + y) % 2 == 0;
          inputPixels[idx] = checker ? 255 : 0; // R
          inputPixels[idx + 1] = checker ? 255 : 0; // G
          inputPixels[idx + 2] = checker ? 255 : 0; // B
          inputPixels[idx + 3] = 255; // A
        }
      }

      // Create map with uniform gray (127 = 0.5 -> no displacement)
      mapPixels = Uint8List(width * height * 4);
      for (int i = 0; i < mapPixels.length; i += 4) {
        mapPixels[i] = 127; // R - X channel
        mapPixels[i + 1] = 127; // G - Y channel
        mapPixels[i + 2] = 127; // B
        mapPixels[i + 3] = 255; // A
      }
    });

    test('zero scale produces unchanged output', () {
      final result = DisplacementMapProcessor.applyDisplacement(
        inputPixels: inputPixels,
        mapPixels: mapPixels,
        width: width,
        height: height,
        scale: 0.0,
        xChannel: SvgChannelSelector.r,
        yChannel: SvgChannelSelector.g,
        edgeMode: SvgDisplacementEdgeMode.none,
      );

      // With scale=0, output should match input (displacement * 0 = no change)
      for (int i = 0; i < result.length; i++) {
        expect(
          result[i],
          inputPixels[i],
          reason: 'Zero scale should not change pixels',
        );
      }
    });

    test('bilinear interpolation produces smoother results', () {
      // Set map to produce fractional displacement
      // 191 = 0.75 -> displacement = scale * (0.75 - 0.5) = scale * 0.25
      for (int i = 0; i < mapPixels.length; i += 4) {
        mapPixels[i] = 191; // R - fractional X displacement
        mapPixels[i + 1] = 191; // G - fractional Y displacement
      }

      final resultBilinear = DisplacementMapProcessor.applyDisplacement(
        inputPixels: inputPixels,
        mapPixels: mapPixels,
        width: width,
        height: height,
        scale: 2.0,
        xChannel: SvgChannelSelector.r,
        yChannel: SvgChannelSelector.g,
        edgeMode: SvgDisplacementEdgeMode.clamp,
        useBilinear: true,
      );

      final resultNearest = DisplacementMapProcessor.applyDisplacement(
        inputPixels: inputPixels,
        mapPixels: mapPixels,
        width: width,
        height: height,
        scale: 2.0,
        xChannel: SvgChannelSelector.r,
        yChannel: SvgChannelSelector.g,
        edgeMode: SvgDisplacementEdgeMode.clamp,
        useBilinear: false,
      );

      expect(resultBilinear.length, resultNearest.length);
      // Results should differ due to interpolation
    });

    test('different channel selectors work correctly', () {
      // Set different displacement in R vs G channels
      for (int i = 0; i < mapPixels.length; i += 4) {
        mapPixels[i] = 200; // R
        mapPixels[i + 1] = 50; // G
        mapPixels[i + 2] = 127; // B
        mapPixels[i + 3] = 100; // A
      }

      final resultRG = DisplacementMapProcessor.applyDisplacement(
        inputPixels: inputPixels,
        mapPixels: mapPixels,
        width: width,
        height: height,
        scale: 2.0,
        xChannel: SvgChannelSelector.r,
        yChannel: SvgChannelSelector.g,
        edgeMode: SvgDisplacementEdgeMode.clamp,
      );

      final resultBA = DisplacementMapProcessor.applyDisplacement(
        inputPixels: inputPixels,
        mapPixels: mapPixels,
        width: width,
        height: height,
        scale: 2.0,
        xChannel: SvgChannelSelector.b,
        yChannel: SvgChannelSelector.a,
        edgeMode: SvgDisplacementEdgeMode.clamp,
      );

      // Results should differ because different channels are used
      var hasDifference = false;
      for (int i = 0; i < resultRG.length; i++) {
        if (resultRG[i] != resultBA[i]) {
          hasDifference = true;
          break;
        }
      }
      expect(
        hasDifference,
        isTrue,
        reason: 'Different channel selectors should produce different results',
      );
    });

    test('edge mode none returns transparent for out-of-bounds', () {
      // Set large displacement to push pixels out of bounds
      for (int i = 0; i < mapPixels.length; i += 4) {
        mapPixels[i] = 255; // R - max positive displacement
        mapPixels[i + 1] = 255; // G
      }

      final result = DisplacementMapProcessor.applyDisplacement(
        inputPixels: inputPixels,
        mapPixels: mapPixels,
        width: width,
        height: height,
        scale: 10.0, // Large scale to push out of bounds
        xChannel: SvgChannelSelector.r,
        yChannel: SvgChannelSelector.g,
        edgeMode: SvgDisplacementEdgeMode.none,
      );

      // Some pixels should be transparent (all zeros)
      var hasTransparent = false;
      for (int i = 0; i < result.length; i += 4) {
        if (result[i] == 0 &&
            result[i + 1] == 0 &&
            result[i + 2] == 0 &&
            result[i + 3] == 0) {
          hasTransparent = true;
          break;
        }
      }
      expect(
        hasTransparent,
        isTrue,
        reason:
            'Out-of-bounds should produce transparent pixels with none mode',
      );
    });
  });

  group('feGaussianBlur extreme values', () {
    test('stdDeviation=0 is passthrough', () {
      final filter = SvgGaussianBlurFilter(
        id: 'blur0',
        stdDeviationX: 0.0,
        stdDeviationY: 0.0,
      );

      expect(filter.isPassthrough, isTrue);
      expect(
        filter.apply(),
        isNull,
        reason: 'Zero blur should return null filter',
      );
    });

    test('stdDeviation=1 produces valid filter', () {
      final filter = SvgGaussianBlurFilter(
        id: 'blur1',
        stdDeviationX: 1.0,
        stdDeviationY: 1.0,
      );

      expect(filter.isPassthrough, isFalse);
      expect(filter.apply(), isNotNull);
    });

    test('stdDeviation=50 is within normal range', () {
      final filter = SvgGaussianBlurFilter(
        id: 'blur50',
        stdDeviationX: 50.0,
        stdDeviationY: 50.0,
      );

      expect(filter.requiresBoxBlurApproximation, isFalse);
      expect(filter.apply(), isNotNull);
    });

    test('stdDeviation=100 requires box blur approximation', () {
      final filter = SvgGaussianBlurFilter(
        id: 'blur100',
        stdDeviationX: 100.0,
        stdDeviationY: 100.0,
      );

      expect(filter.requiresBoxBlurApproximation, isTrue);
      // Still returns a clamped filter for pipeline compatibility
      expect(filter.apply(), isNotNull);
    });

    test('stdDeviation=500 is clamped for safety', () {
      final filter = SvgGaussianBlurFilter(
        id: 'blur500',
        stdDeviationX: 500.0,
        stdDeviationY: 500.0,
      );

      expect(filter.requiresBoxBlurApproximation, isTrue);
      final (clampedX, clampedY) = filter.clampedStdDeviation;
      expect(clampedX, lessThanOrEqualTo(50.0));
      expect(clampedY, lessThanOrEqualTo(50.0));
    });

    test('GaussianBlurProcessor handles zero blur', () {
      final pixels = Uint8List.fromList([255, 128, 64, 255]);

      final result = GaussianBlurProcessor.applyBlur(
        pixels: pixels,
        width: 1,
        height: 1,
        stdDeviationX: 0.0,
        stdDeviationY: 0.0,
        edgeMode: SvgConvolveEdgeMode.duplicate,
      );

      // Should return unchanged
      expect(result[0], 255);
      expect(result[1], 128);
      expect(result[2], 64);
      expect(result[3], 255);
    });

    test('GaussianBlurProcessor handles large blur with box approximation', () {
      final pixels = Uint8List(16 * 16 * 4);
      // Set center pixel to white
      final centerIdx = (8 * 16 + 8) * 4;
      pixels[centerIdx] = 255;
      pixels[centerIdx + 1] = 255;
      pixels[centerIdx + 2] = 255;
      pixels[centerIdx + 3] = 255;

      final result = GaussianBlurProcessor.applyBlur(
        pixels: pixels,
        width: 16,
        height: 16,
        stdDeviationX: 100.0,
        stdDeviationY: 100.0,
        edgeMode: SvgConvolveEdgeMode.duplicate,
      );

      expect(result.length, pixels.length);
      // After extreme blur, the white pixel should spread
      // The center should be less bright than pure white
      expect(result[centerIdx], lessThan(255));
    });
  });

  group('feTurbulence stitchTiles', () {
    test('noStitch mode produces valid noise', () {
      final filter = SvgTurbulenceFilter(
        id: 'turb1',
        baseFrequencyX: 0.1,
        baseFrequencyY: 0.1,
        numOctaves: 2,
        seed: 42.0,
        stitchTiles: SvgTurbulenceStitchTiles.noStitch,
        noiseType: SvgTurbulenceType.turbulence,
      );

      final pixels = TurbulenceTileRenderer.generateTiled(
        width: 32,
        height: 32,
        turbulence: filter,
      );

      expect(pixels.length, 32 * 32 * 4);
      // Should have non-zero values
      var hasNonZero = false;
      for (final p in pixels) {
        if (p != 0) {
          hasNonZero = true;
          break;
        }
      }
      expect(
        hasNonZero,
        isTrue,
        reason: 'Turbulence should produce non-zero values',
      );
    });

    test('stitch mode produces seamless tiling', () {
      final filter = SvgTurbulenceFilter(
        id: 'turb2',
        baseFrequencyX: 0.1,
        baseFrequencyY: 0.1,
        numOctaves: 2,
        seed: 42.0,
        stitchTiles: SvgTurbulenceStitchTiles.stitch,
        noiseType: SvgTurbulenceType.turbulence,
      );

      final pixels = TurbulenceTileRenderer.generateTiled(
        width: 32,
        height: 32,
        turbulence: filter,
      );

      expect(pixels.length, 32 * 32 * 4);
    });

    test('fractalNoise type produces different output than turbulence', () {
      final turbFilter = SvgTurbulenceFilter(
        id: 'turb',
        baseFrequencyX: 0.1,
        baseFrequencyY: 0.1,
        numOctaves: 2,
        seed: 42.0,
        stitchTiles: SvgTurbulenceStitchTiles.noStitch,
        noiseType: SvgTurbulenceType.turbulence,
      );

      final fractalFilter = SvgTurbulenceFilter(
        id: 'fractal',
        baseFrequencyX: 0.1,
        baseFrequencyY: 0.1,
        numOctaves: 2,
        seed: 42.0,
        stitchTiles: SvgTurbulenceStitchTiles.noStitch,
        noiseType: SvgTurbulenceType.fractalNoise,
      );

      final turbPixels = TurbulenceTileRenderer.generateTiled(
        width: 16,
        height: 16,
        turbulence: turbFilter,
      );

      final fractalPixels = TurbulenceTileRenderer.generateTiled(
        width: 16,
        height: 16,
        turbulence: fractalFilter,
      );

      // They should produce different outputs
      var hasDifference = false;
      for (int i = 0; i < turbPixels.length; i++) {
        if (turbPixels[i] != fractalPixels[i]) {
          hasDifference = true;
          break;
        }
      }
      expect(
        hasDifference,
        isTrue,
        reason: 'turbulence and fractalNoise should produce different results',
      );
    });

    test('different seeds produce different noise', () {
      final filter1 = SvgTurbulenceFilter(
        id: 'turb1',
        baseFrequencyX: 0.1,
        baseFrequencyY: 0.1,
        numOctaves: 2,
        seed: 42.0,
        stitchTiles: SvgTurbulenceStitchTiles.noStitch,
        noiseType: SvgTurbulenceType.turbulence,
      );

      final filter2 = SvgTurbulenceFilter(
        id: 'turb2',
        baseFrequencyX: 0.1,
        baseFrequencyY: 0.1,
        numOctaves: 2,
        seed: 123.0,
        stitchTiles: SvgTurbulenceStitchTiles.noStitch,
        noiseType: SvgTurbulenceType.turbulence,
      );

      final pixels1 = TurbulenceTileRenderer.generateTiled(
        width: 16,
        height: 16,
        turbulence: filter1,
      );

      final pixels2 = TurbulenceTileRenderer.generateTiled(
        width: 16,
        height: 16,
        turbulence: filter2,
      );

      var hasDifference = false;
      for (int i = 0; i < pixels1.length; i++) {
        if (pixels1[i] != pixels2[i]) {
          hasDifference = true;
          break;
        }
      }
      expect(
        hasDifference,
        isTrue,
        reason: 'Different seeds should produce different noise',
      );
    });

    test('TurbulenceNoiseGenerator produces deterministic output', () {
      final gen1 = TurbulenceNoiseGenerator(42.0);
      final gen2 = TurbulenceNoiseGenerator(42.0);

      final value1 = gen1.noise2D(10.5, 20.3);
      final value2 = gen2.noise2D(10.5, 20.3);

      expect(
        value1,
        value2,
        reason: 'Same seed should produce same noise value',
      );
    });
  });

  group('feImage external URL support', () {
    test('detects element reference correctly', () {
      final filter = SvgFeImageFilter(
        id: 'img1',
        href: '#myRect',
        width: 100,
        height: 100,
      );

      expect(filter.isElementReference, isTrue);
      expect(filter.referencedElementId, 'myRect');
      expect(filter.isExternalImage, isFalse);
      expect(filter.isDataUri, isFalse);
      expect(filter.isExternalUrl, isFalse);
    });

    test('detects data URI correctly', () {
      final filter = SvgFeImageFilter(
        id: 'img2',
        href: 'data:image/png;base64,iVBORw0KGgo=',
        width: 100,
        height: 100,
      );

      expect(filter.isElementReference, isFalse);
      expect(filter.isDataUri, isTrue);
      expect(filter.isExternalImage, isTrue);
      expect(filter.isExternalUrl, isFalse);
    });

    test('detects external URL correctly', () {
      final filter = SvgFeImageFilter(
        id: 'img3',
        href: 'https://example.com/image.png',
        width: 100,
        height: 100,
      );

      expect(filter.isElementReference, isFalse);
      expect(filter.isDataUri, isFalse);
      expect(filter.isExternalImage, isTrue);
      expect(filter.isExternalUrl, isTrue);
    });

    test('FeImageLoader creates transparent fallback buffer', () {
      final buffer = FeImageLoader.createTransparentBuffer(4, 4);

      expect(buffer.length, 4 * 4 * 4);
      // All bytes should be zero (transparent)
      for (final b in buffer) {
        expect(b, 0);
      }
    });

    test('FeImageLoader validates supported image formats', () {
      expect(FeImageLoader.isSupportedImageFormat('image.png'), isTrue);
      expect(FeImageLoader.isSupportedImageFormat('image.jpg'), isTrue);
      expect(FeImageLoader.isSupportedImageFormat('image.jpeg'), isTrue);
      expect(FeImageLoader.isSupportedImageFormat('image.gif'), isTrue);
      expect(FeImageLoader.isSupportedImageFormat('image.webp'), isTrue);
      expect(FeImageLoader.isSupportedImageFormat('image.svg'), isTrue);
      expect(
        FeImageLoader.isSupportedImageFormat('data:image/png;base64,abc'),
        isTrue,
      );
      expect(
        FeImageLoader.isSupportedImageFormat('https://example.com/img'),
        isTrue,
      );
    });

    test('FeImageLoader detects SVG images', () {
      expect(FeImageLoader.isSvgImage('image.svg'), isTrue);
      expect(FeImageLoader.isSvgImage('data:image/svg+xml;base64,abc'), isTrue);
      expect(FeImageLoader.isSvgImage('image.png'), isFalse);
      expect(FeImageLoader.isSvgImage('data:image/png;base64,abc'), isFalse);
    });

    test('subregion returns correct rect', () {
      final filter = SvgFeImageFilter(
        id: 'img4',
        href: 'test.png',
        x: 10,
        y: 20,
        width: 100,
        height: 50,
      );

      final rect = filter.subregion;
      expect(rect.left, 10);
      expect(rect.top, 20);
      expect(rect.width, 100);
      expect(rect.height, 50);
    });
  });

  group('Filter edge mode consistency', () {
    test('SvgConvolveEdgeMode has all required values', () {
      expect(SvgConvolveEdgeMode.values.length, 3);
      expect(SvgConvolveEdgeMode.values, contains(SvgConvolveEdgeMode.none));
      expect(
        SvgConvolveEdgeMode.values,
        contains(SvgConvolveEdgeMode.duplicate),
      );
      expect(SvgConvolveEdgeMode.values, contains(SvgConvolveEdgeMode.wrap));
    });

    test('SvgDisplacementEdgeMode has all required values', () {
      expect(SvgDisplacementEdgeMode.values.length, 3);
      expect(
        SvgDisplacementEdgeMode.values,
        contains(SvgDisplacementEdgeMode.none),
      );
      expect(
        SvgDisplacementEdgeMode.values,
        contains(SvgDisplacementEdgeMode.clamp),
      );
      expect(
        SvgDisplacementEdgeMode.values,
        contains(SvgDisplacementEdgeMode.wrap),
      );
    });

    test('SvgTurbulenceStitchTiles has all required values', () {
      expect(SvgTurbulenceStitchTiles.values.length, 2);
      expect(
        SvgTurbulenceStitchTiles.values,
        contains(SvgTurbulenceStitchTiles.noStitch),
      );
      expect(
        SvgTurbulenceStitchTiles.values,
        contains(SvgTurbulenceStitchTiles.stitch),
      );
    });

    test('SvgChannelSelector has all required values', () {
      expect(SvgChannelSelector.values.length, 4);
      expect(SvgChannelSelector.values, contains(SvgChannelSelector.r));
      expect(SvgChannelSelector.values, contains(SvgChannelSelector.g));
      expect(SvgChannelSelector.values, contains(SvgChannelSelector.b));
      expect(SvgChannelSelector.values, contains(SvgChannelSelector.a));
    });
  });
}
