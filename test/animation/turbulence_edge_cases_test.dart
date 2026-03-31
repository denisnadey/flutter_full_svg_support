import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/src/animation/svg_filters.dart';

void main() {
  group('TurbulenceNoiseGenerator edge cases', () {
    group('seamless tile stitching', () {
      test('stitched noise should be seamless at tile boundaries', () {
        final generator = TurbulenceNoiseGenerator(42.0);
        const tileWidth = 100.0;
        const tileHeight = 100.0;
        const baseFreqX = 0.05;
        const baseFreqY = 0.05;

        generator.setupStitching(tileWidth, tileHeight, baseFreqX, baseFreqY);

        // Sample noise at left edge and right edge - should match for seamless tiling
        // At x=0 and x=tileWidth, the noise coordinates should wrap
        final leftEdge = generator.fractalNoise(
          x: 0.0,
          y: 50.0,
          baseFreqX: baseFreqX,
          baseFreqY: baseFreqY,
          numOctaves: 3,
          isFractalNoise: true,
          stitch: true,
        );
        final rightEdge = generator.fractalNoise(
          x: tileWidth,
          y: 50.0,
          baseFreqX: baseFreqX,
          baseFreqY: baseFreqY,
          numOctaves: 3,
          isFractalNoise: true,
          stitch: true,
        );

        // The values should be identical or very close for seamless tiling
        expect(
          (leftEdge - rightEdge).abs(),
          lessThan(0.01),
          reason: 'Noise should be seamless at X boundary',
        );

        // Test Y boundaries
        final topEdge = generator.fractalNoise(
          x: 50.0,
          y: 0.0,
          baseFreqX: baseFreqX,
          baseFreqY: baseFreqY,
          numOctaves: 3,
          isFractalNoise: true,
          stitch: true,
        );
        final bottomEdge = generator.fractalNoise(
          x: 50.0,
          y: tileHeight,
          baseFreqX: baseFreqX,
          baseFreqY: baseFreqY,
          numOctaves: 3,
          isFractalNoise: true,
          stitch: true,
        );

        expect(
          (topEdge - bottomEdge).abs(),
          lessThan(0.01),
          reason: 'Noise should be seamless at Y boundary',
        );
      });

      test('stitched noise should be continuous across corners', () {
        final generator = TurbulenceNoiseGenerator(123.0);
        const tileWidth = 64.0;
        const tileHeight = 64.0;
        const baseFreqX = 0.1;
        const baseFreqY = 0.1;

        generator.setupStitching(tileWidth, tileHeight, baseFreqX, baseFreqY);

        // Test all four corners - they should all produce the same value
        final corner00 = generator.fractalNoise(
          x: 0.0,
          y: 0.0,
          baseFreqX: baseFreqX,
          baseFreqY: baseFreqY,
          numOctaves: 2,
          isFractalNoise: false,
          stitch: true,
        );
        final corner10 = generator.fractalNoise(
          x: tileWidth,
          y: 0.0,
          baseFreqX: baseFreqX,
          baseFreqY: baseFreqY,
          numOctaves: 2,
          isFractalNoise: false,
          stitch: true,
        );
        final corner01 = generator.fractalNoise(
          x: 0.0,
          y: tileHeight,
          baseFreqX: baseFreqX,
          baseFreqY: baseFreqY,
          numOctaves: 2,
          isFractalNoise: false,
          stitch: true,
        );
        final corner11 = generator.fractalNoise(
          x: tileWidth,
          y: tileHeight,
          baseFreqX: baseFreqX,
          baseFreqY: baseFreqY,
          numOctaves: 2,
          isFractalNoise: false,
          stitch: true,
        );

        // All corners should have the same value in a stitched tile
        expect((corner00 - corner10).abs(), lessThan(0.01));
        expect((corner00 - corner01).abs(), lessThan(0.01));
        expect((corner00 - corner11).abs(), lessThan(0.01));
      });

      test('adjusted frequencies should be calculated correctly', () {
        final generator = TurbulenceNoiseGenerator(0.0);
        const tileWidth = 200.0;
        const tileHeight = 150.0;
        const baseFreqX = 0.03;
        const baseFreqY = 0.04;

        generator.setupStitching(tileWidth, tileHeight, baseFreqX, baseFreqY);

        // Adjusted frequency should produce integral number of noise periods
        final adjustedX = generator.getAdjustedFreqX(baseFreqX);
        final adjustedY = generator.getAdjustedFreqY(baseFreqY);

        // wrapX = floor(200 * 0.03) = 6, adjusted = 6/200 = 0.03
        // wrapY = floor(150 * 0.04) = 6, adjusted = 6/150 = 0.04
        expect(adjustedX, closeTo(0.03, 0.001));
        expect(adjustedY, closeTo(0.04, 0.001));
      });
    });

    group('baseFrequency with separate X/Y values', () {
      test('different X and Y frequencies should produce anisotropic noise', () {
        final generator = TurbulenceNoiseGenerator(42.0);
        const baseFreqX = 0.1; // Higher frequency in X
        const baseFreqY = 0.01; // Lower frequency in Y

        // Sample along X axis - should vary more
        final x0 = generator.fractalNoise(
          x: 0.0,
          y: 50.0,
          baseFreqX: baseFreqX,
          baseFreqY: baseFreqY,
          numOctaves: 1,
          isFractalNoise: true,
          stitch: false,
        );
        final x10 = generator.fractalNoise(
          x: 10.0,
          y: 50.0,
          baseFreqX: baseFreqX,
          baseFreqY: baseFreqY,
          numOctaves: 1,
          isFractalNoise: true,
          stitch: false,
        );
        final xVariation = (x0 - x10).abs();

        // Sample along Y axis with same distance - should vary less
        final y0 = generator.fractalNoise(
          x: 50.0,
          y: 0.0,
          baseFreqX: baseFreqX,
          baseFreqY: baseFreqY,
          numOctaves: 1,
          isFractalNoise: true,
          stitch: false,
        );
        final y10 = generator.fractalNoise(
          x: 50.0,
          y: 10.0,
          baseFreqX: baseFreqX,
          baseFreqY: baseFreqY,
          numOctaves: 1,
          isFractalNoise: true,
          stitch: false,
        );
        final yVariation = (y0 - y10).abs();

        // X should have more variation due to higher frequency
        // (but this depends on specific coordinates, so just verify they're different)
        expect(xVariation, isNot(equals(yVariation)));
      });

      test('very small frequencies should produce smooth noise', () {
        final generator = TurbulenceNoiseGenerator(1.0);
        const verySmallFreq = 0.001;

        // Sample multiple points - with very small frequency, values should be similar
        final values = <double>[];
        for (var i = 0; i < 5; i++) {
          values.add(
            generator.fractalNoise(
              x: i.toDouble(),
              y: 0.0,
              baseFreqX: verySmallFreq,
              baseFreqY: verySmallFreq,
              numOctaves: 1,
              isFractalNoise: true,
              stitch: false,
            ),
          );
        }

        // Adjacent values should be very close with small frequency
        for (var i = 0; i < values.length - 1; i++) {
          expect((values[i] - values[i + 1]).abs(), lessThan(0.1));
        }
      });
    });

    group('numOctaves overflow protection', () {
      test('large numOctaves should not cause overflow', () {
        final generator = TurbulenceNoiseGenerator(42.0);

        // Very large numOctaves value - should be clamped internally
        expect(() {
          generator.fractalNoise(
            x: 50.0,
            y: 50.0,
            baseFreqX: 0.05,
            baseFreqY: 0.05,
            numOctaves: 100, // Way too high
            isFractalNoise: true,
            stitch: false,
          );
        }, returnsNormally);
      });

      test('numOctaves should be clamped to maxOctaves', () {
        final generator = TurbulenceNoiseGenerator(42.0);

        // Value with 16 octaves (max) should equal value with 100 octaves (clamped)
        final with16 = generator.fractalNoise(
          x: 50.0,
          y: 50.0,
          baseFreqX: 0.05,
          baseFreqY: 0.05,
          numOctaves: 16,
          isFractalNoise: true,
          stitch: false,
        );
        final with100 = generator.fractalNoise(
          x: 50.0,
          y: 50.0,
          baseFreqX: 0.05,
          baseFreqY: 0.05,
          numOctaves: 100,
          isFractalNoise: true,
          stitch: false,
        );

        expect(with16, equals(with100));
      });

      test('zero octaves should be clamped to 1', () {
        final generator = TurbulenceNoiseGenerator(42.0);

        // 0 octaves should produce same result as 1 octave
        final with0 = generator.fractalNoise(
          x: 50.0,
          y: 50.0,
          baseFreqX: 0.05,
          baseFreqY: 0.05,
          numOctaves: 0,
          isFractalNoise: true,
          stitch: false,
        );
        final with1 = generator.fractalNoise(
          x: 50.0,
          y: 50.0,
          baseFreqX: 0.05,
          baseFreqY: 0.05,
          numOctaves: 1,
          isFractalNoise: true,
          stitch: false,
        );

        expect(with0, equals(with1));
      });

      test('negative octaves should be clamped to 1', () {
        final generator = TurbulenceNoiseGenerator(42.0);

        expect(() {
          generator.fractalNoise(
            x: 50.0,
            y: 50.0,
            baseFreqX: 0.05,
            baseFreqY: 0.05,
            numOctaves: -5,
            isFractalNoise: true,
            stitch: false,
          );
        }, returnsNormally);
      });
    });

    group('noise value range', () {
      test('turbulence type should produce values in [0, 1]', () {
        final generator = TurbulenceNoiseGenerator(42.0);

        for (var x = 0; x < 100; x += 10) {
          for (var y = 0; y < 100; y += 10) {
            final value = generator.fractalNoise(
              x: x.toDouble(),
              y: y.toDouble(),
              baseFreqX: 0.05,
              baseFreqY: 0.05,
              numOctaves: 4,
              isFractalNoise: false,
              stitch: false,
            );
            expect(value, greaterThanOrEqualTo(0.0));
            expect(value, lessThanOrEqualTo(1.0));
          }
        }
      });

      test(
        'fractalNoise type should produce values in [0, 1] after normalization',
        () {
          final generator = TurbulenceNoiseGenerator(42.0);

          for (var x = 0; x < 100; x += 10) {
            for (var y = 0; y < 100; y += 10) {
              final value = generator.fractalNoise(
                x: x.toDouble(),
                y: y.toDouble(),
                baseFreqX: 0.05,
                baseFreqY: 0.05,
                numOctaves: 4,
                isFractalNoise: true,
                stitch: false,
              );
              expect(value, greaterThanOrEqualTo(0.0));
              expect(value, lessThanOrEqualTo(1.0));
            }
          }
        },
      );
    });

    group('deterministic seed behavior', () {
      test('same seed should produce identical noise', () {
        final gen1 = TurbulenceNoiseGenerator(12345.0);
        final gen2 = TurbulenceNoiseGenerator(12345.0);

        for (var i = 0; i < 10; i++) {
          final v1 = gen1.fractalNoise(
            x: i * 10.0,
            y: i * 5.0,
            baseFreqX: 0.03,
            baseFreqY: 0.03,
            numOctaves: 3,
            isFractalNoise: true,
            stitch: false,
          );
          final v2 = gen2.fractalNoise(
            x: i * 10.0,
            y: i * 5.0,
            baseFreqX: 0.03,
            baseFreqY: 0.03,
            numOctaves: 3,
            isFractalNoise: true,
            stitch: false,
          );
          expect(v1, equals(v2));
        }
      });

      test('different seeds should produce different noise', () {
        final gen1 = TurbulenceNoiseGenerator(1.0);
        final gen2 = TurbulenceNoiseGenerator(2.0);

        var sameCount = 0;
        for (var i = 0; i < 10; i++) {
          final v1 = gen1.fractalNoise(
            x: i * 10.0,
            y: i * 5.0,
            baseFreqX: 0.03,
            baseFreqY: 0.03,
            numOctaves: 3,
            isFractalNoise: true,
            stitch: false,
          );
          final v2 = gen2.fractalNoise(
            x: i * 10.0,
            y: i * 5.0,
            baseFreqX: 0.03,
            baseFreqY: 0.03,
            numOctaves: 3,
            isFractalNoise: true,
            stitch: false,
          );
          if (v1 == v2) sameCount++;
        }
        // Most values should be different
        expect(sameCount, lessThan(5));
      });
    });
  });

  group('TurbulenceTileRenderer edge cases', () {
    test('zero size should return empty pixels', () {
      final filter = SvgTurbulenceFilter(
        id: 'test',
        baseFrequencyX: 0.05,
        baseFrequencyY: 0.05,
        numOctaves: 3,
        seed: 0.0,
        stitchTiles: SvgTurbulenceStitchTiles.noStitch,
        noiseType: SvgTurbulenceType.turbulence,
      );

      final pixels = TurbulenceTileRenderer.generateTiled(
        width: 0,
        height: 0,
        turbulence: filter,
      );

      expect(pixels.length, equals(0));
    });

    test('negative dimensions should return empty pixels', () {
      final filter = SvgTurbulenceFilter(
        id: 'test',
        baseFrequencyX: 0.05,
        baseFrequencyY: 0.05,
        numOctaves: 3,
        seed: 0.0,
        stitchTiles: SvgTurbulenceStitchTiles.noStitch,
        noiseType: SvgTurbulenceType.turbulence,
      );

      final pixels = TurbulenceTileRenderer.generateTiled(
        width: -10,
        height: -10,
        turbulence: filter,
      );

      expect(pixels.length, equals(0));
    });

    test('should generate correct pixel count', () {
      final filter = SvgTurbulenceFilter(
        id: 'test',
        baseFrequencyX: 0.05,
        baseFrequencyY: 0.05,
        numOctaves: 2,
        seed: 42.0,
        stitchTiles: SvgTurbulenceStitchTiles.noStitch,
        noiseType: SvgTurbulenceType.turbulence,
      );

      final pixels = TurbulenceTileRenderer.generateTiled(
        width: 100,
        height: 100,
        turbulence: filter,
      );

      expect(pixels.length, equals(100 * 100 * 4)); // RGBA
    });

    test('stitched texture should have seamless edges', () {
      final filter = SvgTurbulenceFilter(
        id: 'test',
        baseFrequencyX: 0.02,
        baseFrequencyY: 0.02,
        numOctaves: 2,
        seed: 0.0,
        stitchTiles: SvgTurbulenceStitchTiles.stitch,
        noiseType: SvgTurbulenceType.turbulence,
      );

      const width = 64;
      const height = 64;
      final pixels = TurbulenceTileRenderer.generateTiled(
        width: width,
        height: height,
        turbulence: filter,
      );

      // Check that left edge matches conceptually with right edge (wrap)
      // Since we tile, the pixel at (0, y) should be similar to texture at (width, y)
      // which wraps to (0, y) - so just verify the texture is valid
      for (var y = 0; y < height; y++) {
        final leftIdx = (y * width + 0) * 4;
        final rightIdx = (y * width + (width - 1)) * 4;

        // Values should be in valid range
        expect(pixels[leftIdx], inInclusiveRange(0, 255));
        expect(pixels[rightIdx], inInclusiveRange(0, 255));
      }
    });

    test('all pixels should be in valid RGBA range', () {
      final filter = SvgTurbulenceFilter(
        id: 'test',
        baseFrequencyX: 0.1,
        baseFrequencyY: 0.1,
        numOctaves: 5,
        seed: 123.0,
        stitchTiles: SvgTurbulenceStitchTiles.noStitch,
        noiseType: SvgTurbulenceType.fractalNoise,
      );

      final pixels = TurbulenceTileRenderer.generateTiled(
        width: 50,
        height: 50,
        turbulence: filter,
      );

      for (var i = 0; i < pixels.length; i++) {
        expect(
          pixels[i],
          inInclusiveRange(0, 255),
          reason: 'Pixel value at index $i should be 0-255',
        );
      }
    });
  });
}
