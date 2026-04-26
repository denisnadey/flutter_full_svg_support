import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:full_svg_flutter/src/animation/svg_parser.dart';
import 'package:full_svg_flutter/src/animation/svg_filters.dart';

void main() {
  group('feDisplacementMap Edge Cases', () {
    test(
      'feDisplacementMap with xChannelSelector="R", yChannelSelector="G"',
      () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="dispRG">
      <feDisplacementMap in="SourceGraphic" in2="SourceGraphic"
        xChannelSelector="R" yChannelSelector="G" scale="10"/>
    </filter>
  </defs>
  <rect filter="url(#dispRG)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final filter =
            document.filters!.getById('dispRG') as SvgDisplacementMapFilter;
        expect(filter.xChannelSelector, SvgChannelSelector.r);
        expect(filter.yChannelSelector, SvgChannelSelector.g);
        expect(filter.scale, 10.0);
      },
    );

    test(
      'feDisplacementMap with xChannelSelector="B", yChannelSelector="A"',
      () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="dispBA">
      <feDisplacementMap in="SourceGraphic" in2="SourceGraphic"
        xChannelSelector="B" yChannelSelector="A" scale="20"/>
    </filter>
  </defs>
  <rect filter="url(#dispBA)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final filter =
            document.filters!.getById('dispBA') as SvgDisplacementMapFilter;
        expect(filter.xChannelSelector, SvgChannelSelector.b);
        expect(filter.yChannelSelector, SvgChannelSelector.a);
        expect(filter.scale, 20.0);
      },
    );

    test('feDisplacementMap with default channel selectors (A, A)', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="dispDefault">
      <feDisplacementMap in="SourceGraphic" in2="SourceGraphic" scale="5"/>
    </filter>
  </defs>
  <rect filter="url(#dispDefault)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final filter =
          document.filters!.getById('dispDefault') as SvgDisplacementMapFilter;
      // Per SVG spec, default channel selectors are A for both x and y
      expect(filter.xChannelSelector, SvgChannelSelector.a);
      expect(filter.yChannelSelector, SvgChannelSelector.a);
      expect(filter.scale, 5.0);
    });

    test('feDisplacementMap with scale=0 produces no displacement', () {
      // 3x3 solid red image
      final inputPixels = Uint8List.fromList([
        255, 0, 0, 255, 255, 0, 0, 255, 255, 0, 0, 255, // Row 0
        255, 0, 0, 255, 255, 0, 0, 255, 255, 0, 0, 255, // Row 1
        255, 0, 0, 255, 255, 0, 0, 255, 255, 0, 0, 255, // Row 2
      ]);

      // Displacement map with varying R channel (wouldn't matter with scale=0)
      final mapPixels = Uint8List.fromList([
        0, 128, 0, 255, 128, 128, 0, 255, 255, 128, 0, 255, // Row 0
        0, 128, 0, 255, 128, 128, 0, 255, 255, 128, 0, 255, // Row 1
        0, 128, 0, 255, 128, 128, 0, 255, 255, 128, 0, 255, // Row 2
      ]);

      final result = DisplacementMapProcessor.applyDisplacement(
        inputPixels: inputPixels,
        mapPixels: mapPixels,
        width: 3,
        height: 3,
        scale: 0.0, // No displacement
        xChannel: SvgChannelSelector.r,
        yChannel: SvgChannelSelector.g,
        edgeMode: SvgDisplacementEdgeMode.none,
      );

      // With scale=0, output should be identical to input
      expect(result, inputPixels);
    });

    test(
      'feDisplacementMap with large scale causes out-of-bounds (transparent black)',
      () {
        // 3x3 solid blue image
        final inputPixels = Uint8List.fromList([
          0, 0, 255, 255, 0, 0, 255, 255, 0, 0, 255, 255, // Row 0
          0, 0, 255, 255, 0, 0, 255, 255, 0, 0, 255, 255, // Row 1
          0, 0, 255, 255, 0, 0, 255, 255, 0, 0, 255, 255, // Row 2
        ]);

        // Displacement map with maximum R and G values
        // This will cause maximum displacement in both directions
        final mapPixels = Uint8List.fromList([
          255, 255, 0, 255, 255, 255, 0, 255, 255, 255, 0, 255, // Row 0
          255, 255, 0, 255, 255, 255, 0, 255, 255, 255, 0, 255, // Row 1
          255, 255, 0, 255, 255, 255, 0, 255, 255, 255, 0, 255, // Row 2
        ]);

        final result = DisplacementMapProcessor.applyDisplacement(
          inputPixels: inputPixels,
          mapPixels: mapPixels,
          width: 3,
          height: 3,
          scale: 100.0, // Very large scale to push outside bounds
          xChannel: SvgChannelSelector.r,
          yChannel: SvgChannelSelector.g,
          edgeMode: SvgDisplacementEdgeMode.none,
        );

        // With edge mode 'none', out-of-bounds samples should be transparent black
        // Every pixel will be displaced way outside the image
        for (int i = 0; i < result.length; i += 4) {
          expect(result[i], 0, reason: 'Red channel should be 0 (transparent)');
          expect(
            result[i + 1],
            0,
            reason: 'Green channel should be 0 (transparent)',
          );
          expect(
            result[i + 2],
            0,
            reason: 'Blue channel should be 0 (transparent)',
          );
          expect(
            result[i + 3],
            0,
            reason: 'Alpha channel should be 0 (transparent)',
          );
        }
      },
    );
  });

  group('feTile Edge Cases', () {
    test('feTile with small input tiled across large region', () {
      // 2x2 input: Red, Green, Blue, Yellow
      final inputPixels = Uint8List.fromList([
        255, 0, 0, 255, 0, 255, 0, 255, // Row 0: Red, Green
        0, 0, 255, 255, 255, 255, 0, 255, // Row 1: Blue, Yellow
      ]);

      // Tile to 4x4 output
      final result = TileProcessor.applyTiling(
        inputPixels: inputPixels,
        inputWidth: 2,
        inputHeight: 2,
        outputWidth: 4,
        outputHeight: 4,
      );

      // Expected: 4x4 tiled pattern
      // [R, G, R, G]
      // [B, Y, B, Y]
      // [R, G, R, G]
      // [B, Y, B, Y]
      expect(result.length, 4 * 4 * 4);

      // Check top-left 2x2 (original input position)
      expect(result.sublist(0, 4), [255, 0, 0, 255]); // (0,0) = Red
      expect(result.sublist(4, 8), [0, 255, 0, 255]); // (1,0) = Green
      expect(result.sublist(16, 20), [0, 0, 255, 255]); // (0,1) = Blue
      expect(result.sublist(20, 24), [255, 255, 0, 255]); // (1,1) = Yellow

      // Check tiled pixels (should repeat)
      expect(result.sublist(8, 12), [255, 0, 0, 255]); // (2,0) = Red (tiled)
      expect(result.sublist(12, 16), [0, 255, 0, 255]); // (3,0) = Green (tiled)

      // Row 2 should be same as row 0
      final row2Start = 4 * 4 * 2;
      expect(result.sublist(row2Start, row2Start + 4), [
        255,
        0,
        0,
        255,
      ]); // (0,2) = Red
      expect(result.sublist(row2Start + 4, row2Start + 8), [
        0,
        255,
        0,
        255,
      ]); // (1,2) = Green
    });

    test('feTile with input matching filter region (single tile)', () {
      // 3x3 gradient input
      final inputPixels = Uint8List.fromList([
        10, 10, 10, 255, 20, 20, 20, 255, 30, 30, 30, 255, // Row 0
        40, 40, 40, 255, 50, 50, 50, 255, 60, 60, 60, 255, // Row 1
        70, 70, 70, 255, 80, 80, 80, 255, 90, 90, 90, 255, // Row 2
      ]);

      // Output same size as input (no actual tiling needed)
      final result = TileProcessor.applyTiling(
        inputPixels: inputPixels,
        inputWidth: 3,
        inputHeight: 3,
        outputWidth: 3,
        outputHeight: 3,
      );

      // Result should be identical to input
      expect(result, inputPixels);
    });

    test('feTile with empty input produces transparent black output', () {
      // Empty input
      final emptyPixels = Uint8List(0);

      // Tile to 3x3 output
      final result = TileProcessor.applyTiling(
        inputPixels: emptyPixels,
        inputWidth: 0,
        inputHeight: 0,
        outputWidth: 3,
        outputHeight: 3,
      );

      // All pixels should be transparent black
      expect(result.length, 3 * 3 * 4);
      for (int i = 0; i < result.length; i++) {
        expect(result[i], 0);
      }
    });
  });
}
