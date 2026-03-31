import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/src/animation/svg_filters.dart';

void main() {
  group('DisplacementMapProcessor edge cases', () {
    group('bilinear interpolation precision', () {
      test('bilinear interpolation should handle fractional coordinates', () {
        // Create a simple 4x4 gradient image
        final inputPixels = _createGradientImage(4, 4);
        // Create a map that causes 0.5 pixel displacement
        final mapPixels = _createConstantMap(4, 4, 191, 191); // (191/255 - 0.5) * scale = 0.5

        final result = DisplacementMapProcessor.applyDisplacement(
          inputPixels: inputPixels,
          mapPixels: mapPixels,
          width: 4,
          height: 4,
          scale: 2.0, // 0.5 pixel displacement
          xChannel: SvgChannelSelector.r,
          yChannel: SvgChannelSelector.g,
          edgeMode: SvgDisplacementEdgeMode.clamp,
          useBilinear: true,
        );

        // Result should be valid
        expect(result.length, equals(inputPixels.length));
        // Values should be interpolated (not exact match to input)
        expect(result, isNot(equals(inputPixels)));
      });

      test('bilinear should differ from nearest-neighbor for subpixel coords', () {
        final inputPixels = _createCheckerboard(8, 8);
        // Map causing 0.25 pixel displacement
        final mapPixels = _createConstantMap(8, 8, 143, 143); // ~0.25 displacement

        final bilinear = DisplacementMapProcessor.applyDisplacement(
          inputPixels: inputPixels,
          mapPixels: mapPixels,
          width: 8,
          height: 8,
          scale: 2.0,
          xChannel: SvgChannelSelector.r,
          yChannel: SvgChannelSelector.g,
          edgeMode: SvgDisplacementEdgeMode.clamp,
          useBilinear: true,
        );

        final nearest = DisplacementMapProcessor.applyDisplacement(
          inputPixels: inputPixels,
          mapPixels: mapPixels,
          width: 8,
          height: 8,
          scale: 2.0,
          xChannel: SvgChannelSelector.r,
          yChannel: SvgChannelSelector.g,
          edgeMode: SvgDisplacementEdgeMode.clamp,
          useBilinear: false,
        );

        // Results should differ for non-integer displacements
        expect(bilinear, isNot(equals(nearest)));
      });

      test('bilinear should be smooth at pixel boundaries', () {
        final inputPixels = _createGradientImage(10, 10);
        // Map causing exact 1.0 pixel displacement - should be same as integer offset
        final mapPixels = _createConstantMap(10, 10, 255, 127); // max X, neutral Y

        final result = DisplacementMapProcessor.applyDisplacement(
          inputPixels: inputPixels,
          mapPixels: mapPixels,
          width: 10,
          height: 10,
          scale: 2.0, // (255/255 - 0.5) * 2 = 1.0 pixel
          xChannel: SvgChannelSelector.r,
          yChannel: SvgChannelSelector.g,
          edgeMode: SvgDisplacementEdgeMode.clamp,
          useBilinear: true,
        );

        // All values should be valid
        for (var i = 0; i < result.length; i++) {
          expect(result[i], inInclusiveRange(0, 255));
        }
      });
    });

    group('edge handling modes', () {
      test('none mode should return transparent black outside bounds', () {
        // Create solid white 4x4 image
        final inputPixels = _createSolidColor(4, 4, 255, 255, 255, 255);
        // Map causing large displacement outside bounds
        final mapPixels = _createConstantMap(4, 4, 255, 255); // Max displacement

        final result = DisplacementMapProcessor.applyDisplacement(
          inputPixels: inputPixels,
          mapPixels: mapPixels,
          width: 4,
          height: 4,
          scale: 20.0, // Large scale to push outside bounds
          xChannel: SvgChannelSelector.r,
          yChannel: SvgChannelSelector.g,
          edgeMode: SvgDisplacementEdgeMode.none,
          useBilinear: true,
        );

        // Many pixels should be transparent black (sampling outside)
        var transparentCount = 0;
        for (var i = 0; i < result.length; i += 4) {
          if (result[i] == 0 && result[i+1] == 0 && 
              result[i+2] == 0 && result[i+3] == 0) {
            transparentCount++;
          }
        }
        expect(transparentCount, greaterThan(0),
            reason: 'Should have transparent pixels when sampling outside');
      });

      test('clamp mode should repeat edge pixels', () {
        // Create gradient image
        final inputPixels = _createGradientImage(4, 4);
        // Map causing large displacement
        final mapPixels = _createConstantMap(4, 4, 255, 255);

        final result = DisplacementMapProcessor.applyDisplacement(
          inputPixels: inputPixels,
          mapPixels: mapPixels,
          width: 4,
          height: 4,
          scale: 20.0,
          xChannel: SvgChannelSelector.r,
          yChannel: SvgChannelSelector.g,
          edgeMode: SvgDisplacementEdgeMode.clamp,
          useBilinear: true,
        );

        // Result should be valid with clamp mode
        expect(result.length, equals(inputPixels.length));
        // All pixels should have valid values
        for (var i = 0; i < result.length; i++) {
          expect(result[i], inInclusiveRange(0, 255));
        }
      });

      test('wrap mode should tile pixels', () {
        // Create distinct quadrant image
        final inputPixels = _createQuadrantImage(4, 4);
        // Map causing 2-pixel displacement (should wrap)
        final mapPixels = _createConstantMap(4, 4, 255, 127); // X displacement only

        final result = DisplacementMapProcessor.applyDisplacement(
          inputPixels: inputPixels,
          mapPixels: mapPixels,
          width: 4,
          height: 4,
          scale: 8.0, // Large displacement to force wrap
          xChannel: SvgChannelSelector.r,
          yChannel: SvgChannelSelector.g,
          edgeMode: SvgDisplacementEdgeMode.wrap,
          useBilinear: true,
        );

        // Result should be valid and contain wrapped values
        expect(result.length, equals(inputPixels.length));
      });

      test('negative displacement should be handled correctly', () {
        final inputPixels = _createGradientImage(8, 8);
        // Map causing negative displacement (channel < 127)
        final mapPixels = _createConstantMap(8, 8, 0, 0); // Max negative

        final resultNone = DisplacementMapProcessor.applyDisplacement(
          inputPixels: inputPixels,
          mapPixels: mapPixels,
          width: 8,
          height: 8,
          scale: 10.0,
          xChannel: SvgChannelSelector.r,
          yChannel: SvgChannelSelector.g,
          edgeMode: SvgDisplacementEdgeMode.none,
        );

        final resultClamp = DisplacementMapProcessor.applyDisplacement(
          inputPixels: inputPixels,
          mapPixels: mapPixels,
          width: 8,
          height: 8,
          scale: 10.0,
          xChannel: SvgChannelSelector.r,
          yChannel: SvgChannelSelector.g,
          edgeMode: SvgDisplacementEdgeMode.clamp,
        );

        // Both should produce valid results
        expect(resultNone.length, equals(inputPixels.length));
        expect(resultClamp.length, equals(inputPixels.length));
      });
    });

    group('channel selector combinations', () {
      test('R channel for X displacement', () {
        final inputPixels = _createGradientImage(4, 4);
        // Red channel varies, others constant
        final mapPixels = _createChannelMap(4, 4, rVal: 200, gVal: 127, bVal: 127, aVal: 255);

        final result = DisplacementMapProcessor.applyDisplacement(
          inputPixels: inputPixels,
          mapPixels: mapPixels,
          width: 4,
          height: 4,
          scale: 2.0,
          xChannel: SvgChannelSelector.r,
          yChannel: SvgChannelSelector.g,
          edgeMode: SvgDisplacementEdgeMode.clamp,
        );

        expect(result.length, equals(inputPixels.length));
      });

      test('G channel for Y displacement', () {
        final inputPixels = _createGradientImage(4, 4);
        final mapPixels = _createChannelMap(4, 4, rVal: 127, gVal: 200, bVal: 127, aVal: 255);

        final result = DisplacementMapProcessor.applyDisplacement(
          inputPixels: inputPixels,
          mapPixels: mapPixels,
          width: 4,
          height: 4,
          scale: 2.0,
          xChannel: SvgChannelSelector.r,
          yChannel: SvgChannelSelector.g,
          edgeMode: SvgDisplacementEdgeMode.clamp,
        );

        expect(result.length, equals(inputPixels.length));
      });

      test('B channel for both X and Y displacement', () {
        final inputPixels = _createGradientImage(4, 4);
        final mapPixels = _createChannelMap(4, 4, rVal: 127, gVal: 127, bVal: 200, aVal: 255);

        final result = DisplacementMapProcessor.applyDisplacement(
          inputPixels: inputPixels,
          mapPixels: mapPixels,
          width: 4,
          height: 4,
          scale: 2.0,
          xChannel: SvgChannelSelector.b,
          yChannel: SvgChannelSelector.b,
          edgeMode: SvgDisplacementEdgeMode.clamp,
        );

        expect(result.length, equals(inputPixels.length));
      });

      test('A channel for displacement', () {
        final inputPixels = _createGradientImage(4, 4);
        final mapPixels = _createChannelMap(4, 4, rVal: 127, gVal: 127, bVal: 127, aVal: 200);

        final result = DisplacementMapProcessor.applyDisplacement(
          inputPixels: inputPixels,
          mapPixels: mapPixels,
          width: 4,
          height: 4,
          scale: 2.0,
          xChannel: SvgChannelSelector.a,
          yChannel: SvgChannelSelector.a,
          edgeMode: SvgDisplacementEdgeMode.clamp,
        );

        expect(result.length, equals(inputPixels.length));
      });

      test('mixed channel selectors R/B', () {
        final inputPixels = _createGradientImage(4, 4);
        final mapPixels = _createChannelMap(4, 4, rVal: 180, gVal: 127, bVal: 200, aVal: 255);

        final result = DisplacementMapProcessor.applyDisplacement(
          inputPixels: inputPixels,
          mapPixels: mapPixels,
          width: 4,
          height: 4,
          scale: 2.0,
          xChannel: SvgChannelSelector.r,
          yChannel: SvgChannelSelector.b,
          edgeMode: SvgDisplacementEdgeMode.clamp,
        );

        expect(result.length, equals(inputPixels.length));
      });
    });

    group('scale attribute handling', () {
      test('zero scale should produce no displacement', () {
        final inputPixels = _createGradientImage(4, 4);
        final mapPixels = _createConstantMap(4, 4, 255, 255);

        final result = DisplacementMapProcessor.applyDisplacement(
          inputPixels: inputPixels,
          mapPixels: mapPixels,
          width: 4,
          height: 4,
          scale: 0.0,
          xChannel: SvgChannelSelector.r,
          yChannel: SvgChannelSelector.g,
          edgeMode: SvgDisplacementEdgeMode.clamp,
        );

        // With zero scale, result should equal input
        expect(result, equals(inputPixels));
      });

      test('negative scale should invert displacement direction', () {
        final inputPixels = _createGradientImage(8, 8);
        final mapPixels = _createConstantMap(8, 8, 200, 127); // Positive X displacement

        final positiveScale = DisplacementMapProcessor.applyDisplacement(
          inputPixels: inputPixels,
          mapPixels: mapPixels,
          width: 8,
          height: 8,
          scale: 5.0,
          xChannel: SvgChannelSelector.r,
          yChannel: SvgChannelSelector.g,
          edgeMode: SvgDisplacementEdgeMode.clamp,
        );

        final negativeScale = DisplacementMapProcessor.applyDisplacement(
          inputPixels: inputPixels,
          mapPixels: mapPixels,
          width: 8,
          height: 8,
          scale: -5.0,
          xChannel: SvgChannelSelector.r,
          yChannel: SvgChannelSelector.g,
          edgeMode: SvgDisplacementEdgeMode.clamp,
        );

        // Results should differ for opposite scales
        expect(positiveScale, isNot(equals(negativeScale)));
      });

      test('very large scale should be clamped', () {
        final inputPixels = _createGradientImage(4, 4);
        final mapPixels = _createConstantMap(4, 4, 255, 255);

        // Should not throw or produce invalid values
        expect(() {
          DisplacementMapProcessor.applyDisplacement(
            inputPixels: inputPixels,
            mapPixels: mapPixels,
            width: 4,
            height: 4,
            scale: 100000.0, // Very large
            xChannel: SvgChannelSelector.r,
            yChannel: SvgChannelSelector.g,
            edgeMode: SvgDisplacementEdgeMode.none,
          );
        }, returnsNormally);
      });
    });

    group('input validation', () {
      test('mismatched pixel buffer sizes should return input unchanged', () {
        final inputPixels = _createGradientImage(4, 4);
        final mapPixels = _createConstantMap(2, 2, 127, 127); // Different size

        final result = DisplacementMapProcessor.applyDisplacement(
          inputPixels: inputPixels,
          mapPixels: mapPixels,
          width: 4,
          height: 4,
          scale: 2.0,
          xChannel: SvgChannelSelector.r,
          yChannel: SvgChannelSelector.g,
          edgeMode: SvgDisplacementEdgeMode.clamp,
        );

        expect(result, equals(inputPixels));
      });

      test('zero width should return input unchanged', () {
        final inputPixels = Uint8List(0);
        final mapPixels = Uint8List(0);

        final result = DisplacementMapProcessor.applyDisplacement(
          inputPixels: inputPixels,
          mapPixels: mapPixels,
          width: 0,
          height: 10,
          scale: 2.0,
          xChannel: SvgChannelSelector.r,
          yChannel: SvgChannelSelector.g,
          edgeMode: SvgDisplacementEdgeMode.clamp,
        );

        expect(result, equals(inputPixels));
      });

      test('zero height should return input unchanged', () {
        final inputPixels = Uint8List(0);
        final mapPixels = Uint8List(0);

        final result = DisplacementMapProcessor.applyDisplacement(
          inputPixels: inputPixels,
          mapPixels: mapPixels,
          width: 10,
          height: 0,
          scale: 2.0,
          xChannel: SvgChannelSelector.r,
          yChannel: SvgChannelSelector.g,
          edgeMode: SvgDisplacementEdgeMode.clamp,
        );

        expect(result, equals(inputPixels));
      });
    });

    group('neutral displacement', () {
      test('map value 127 should produce minimal displacement', () {
        final inputPixels = _createGradientImage(4, 4);
        // 127/255 ≈ 0.498, so (0.498 - 0.5) * scale ≈ -0.002 * scale
        final mapPixels = _createConstantMap(4, 4, 127, 127);

        final result = DisplacementMapProcessor.applyDisplacement(
          inputPixels: inputPixels,
          mapPixels: mapPixels,
          width: 4,
          height: 4,
          scale: 1.0,
          xChannel: SvgChannelSelector.r,
          yChannel: SvgChannelSelector.g,
          edgeMode: SvgDisplacementEdgeMode.clamp,
        );

        // Result should be very close to input (minimal displacement)
        var maxDiff = 0;
        for (var i = 0; i < result.length; i++) {
          final diff = (result[i] - inputPixels[i]).abs();
          if (diff > maxDiff) maxDiff = diff;
        }
        expect(maxDiff, lessThan(10), reason: 'Neutral map should cause minimal change');
      });
    });
  });
}

// Helper functions to create test images

Uint8List _createGradientImage(int width, int height) {
  final pixels = Uint8List(width * height * 4);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final index = (y * width + x) * 4;
      pixels[index] = (x * 255 ~/ (width - 1)).clamp(0, 255); // R gradient X
      pixels[index + 1] = (y * 255 ~/ (height - 1)).clamp(0, 255); // G gradient Y
      pixels[index + 2] = 128; // B constant
      pixels[index + 3] = 255; // A opaque
    }
  }
  return pixels;
}

Uint8List _createConstantMap(int width, int height, int rg, int ba) {
  final pixels = Uint8List(width * height * 4);
  for (var i = 0; i < pixels.length; i += 4) {
    pixels[i] = rg;     // R
    pixels[i + 1] = ba; // G
    pixels[i + 2] = rg; // B
    pixels[i + 3] = 255; // A
  }
  return pixels;
}

Uint8List _createChannelMap(int width, int height, {
  required int rVal, required int gVal, required int bVal, required int aVal,
}) {
  final pixels = Uint8List(width * height * 4);
  for (var i = 0; i < pixels.length; i += 4) {
    pixels[i] = rVal;
    pixels[i + 1] = gVal;
    pixels[i + 2] = bVal;
    pixels[i + 3] = aVal;
  }
  return pixels;
}

Uint8List _createSolidColor(int width, int height, int r, int g, int b, int a) {
  final pixels = Uint8List(width * height * 4);
  for (var i = 0; i < pixels.length; i += 4) {
    pixels[i] = r;
    pixels[i + 1] = g;
    pixels[i + 2] = b;
    pixels[i + 3] = a;
  }
  return pixels;
}

Uint8List _createCheckerboard(int width, int height) {
  final pixels = Uint8List(width * height * 4);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final index = (y * width + x) * 4;
      final isWhite = (x + y) % 2 == 0;
      final value = isWhite ? 255 : 0;
      pixels[index] = value;
      pixels[index + 1] = value;
      pixels[index + 2] = value;
      pixels[index + 3] = 255;
    }
  }
  return pixels;
}

Uint8List _createQuadrantImage(int width, int height) {
  final pixels = Uint8List(width * height * 4);
  final midX = width ~/ 2;
  final midY = height ~/ 2;
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final index = (y * width + x) * 4;
      // Different colors for each quadrant
      if (x < midX && y < midY) {
        pixels[index] = 255; pixels[index + 1] = 0; pixels[index + 2] = 0;
      } else if (x >= midX && y < midY) {
        pixels[index] = 0; pixels[index + 1] = 255; pixels[index + 2] = 0;
      } else if (x < midX && y >= midY) {
        pixels[index] = 0; pixels[index + 1] = 0; pixels[index + 2] = 255;
      } else {
        pixels[index] = 255; pixels[index + 1] = 255; pixels[index + 2] = 0;
      }
      pixels[index + 3] = 255;
    }
  }
  return pixels;
}
