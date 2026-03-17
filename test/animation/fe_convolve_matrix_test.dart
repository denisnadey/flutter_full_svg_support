import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_svg/src/animation/svg_parser.dart';
import 'package:flutter_svg/src/animation/svg_filters.dart';

void main() {
  group('feConvolveMatrix Filter', () {
    group('Parsing', () {
      test('Parse feConvolveMatrix with all attributes', () {
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

      test('Parse feConvolveMatrix with default values', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="defConvFx">
      <feConvolveMatrix kernelMatrix="0 -1 0 -1 5 -1 0 -1 0"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#defConvFx)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final filter =
            document.filters!.getById('defConvFx') as SvgConvolveMatrixFilter;

        expect(filter.orderX, 3); // default
        expect(filter.orderY, 3); // default
        expect(filter.kernelMatrix.length, 9);
        // divisor defaults to sum of kernel values when not specified
        expect(filter.divisor, 1.0); // sum is 0+(-1)+0+(-1)+5+(-1)+0+(-1)+0 = 1
        expect(filter.bias, 0.0); // default
        expect(filter.targetX, 1); // floor(3/2) = 1
        expect(filter.targetY, 1); // floor(3/2) = 1
        expect(filter.edgeMode, SvgConvolveEdgeMode.duplicate); // default
        expect(filter.preserveAlpha, isFalse); // default
      });

      test('Parse feConvolveMatrix with edgeMode=none', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="noneEdgeFx">
      <feConvolveMatrix 
        kernelMatrix="1 1 1 1 1 1 1 1 1" 
        edgeMode="none"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#noneEdgeFx)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final filter =
            document.filters!.getById('noneEdgeFx') as SvgConvolveMatrixFilter;
        expect(filter.edgeMode, SvgConvolveEdgeMode.none);
      });

      test('Parse feConvolveMatrix with edgeMode=duplicate', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="dupEdgeFx">
      <feConvolveMatrix 
        kernelMatrix="1 1 1 1 1 1 1 1 1" 
        edgeMode="duplicate"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#dupEdgeFx)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final filter =
            document.filters!.getById('dupEdgeFx') as SvgConvolveMatrixFilter;
        expect(filter.edgeMode, SvgConvolveEdgeMode.duplicate);
      });
    });

    group('ConvolveMatrixProcessor', () {
      test('Identity kernel detection', () {
        // 3x3 identity kernel: 0 0 0 / 0 1 0 / 0 0 0
        final identityKernel = <double>[0, 0, 0, 0, 1, 0, 0, 0, 0];
        expect(
          ConvolveMatrixProcessor.isIdentityKernel(
            kernel: identityKernel,
            orderX: 3,
            orderY: 3,
            targetX: 1,
            targetY: 1,
            divisor: 1.0,
            bias: 0.0,
          ),
          isTrue,
        );
      });

      test('Non-identity kernel detection (sharpen)', () {
        // Sharpen kernel: 0 -1 0 / -1 5 -1 / 0 -1 0
        final sharpenKernel = <double>[0, -1, 0, -1, 5, -1, 0, -1, 0];
        expect(
          ConvolveMatrixProcessor.isIdentityKernel(
            kernel: sharpenKernel,
            orderX: 3,
            orderY: 3,
            targetX: 1,
            targetY: 1,
            divisor: 1.0,
            bias: 0.0,
          ),
          isFalse,
        );
      });

      test('Non-identity kernel detection (blur)', () {
        // Box blur kernel: all 1/9
        final blurKernel = List<double>.filled(9, 1.0);
        expect(
          ConvolveMatrixProcessor.isIdentityKernel(
            kernel: blurKernel,
            orderX: 3,
            orderY: 3,
            targetX: 1,
            targetY: 1,
            divisor: 9.0,
            bias: 0.0,
          ),
          isFalse,
        );
      });

      test('Identity kernel with non-zero bias is not identity', () {
        final identityKernel = <double>[0, 0, 0, 0, 1, 0, 0, 0, 0];
        expect(
          ConvolveMatrixProcessor.isIdentityKernel(
            kernel: identityKernel,
            orderX: 3,
            orderY: 3,
            targetX: 1,
            targetY: 1,
            divisor: 1.0,
            bias: 0.1,
          ),
          isFalse,
        );
      });

      test('Identity kernel with non-1 divisor is not identity', () {
        final identityKernel = <double>[0, 0, 0, 0, 1, 0, 0, 0, 0];
        expect(
          ConvolveMatrixProcessor.isIdentityKernel(
            kernel: identityKernel,
            orderX: 3,
            orderY: 3,
            targetX: 1,
            targetY: 1,
            divisor: 2.0,
            bias: 0.0,
          ),
          isFalse,
        );
      });

      test('Apply convolution with identity kernel preserves input', () {
        // 2x2 image: red, green, blue, white pixels
        final pixels = Uint8List.fromList([
          255, 0, 0, 255, // red
          0, 255, 0, 255, // green
          0, 0, 255, 255, // blue
          255, 255, 255, 255, // white
        ]);

        // 3x3 identity kernel
        final identityKernel = <double>[0, 0, 0, 0, 1, 0, 0, 0, 0];

        final result = ConvolveMatrixProcessor.applyConvolution(
          pixels: pixels,
          width: 2,
          height: 2,
          kernel: identityKernel,
          orderX: 3,
          orderY: 3,
          targetX: 1,
          targetY: 1,
          divisor: 1.0,
          bias: 0.0,
          edgeMode: SvgConvolveEdgeMode.duplicate,
          preserveAlpha: false,
        );

        // Should be identical to input
        expect(result, equals(pixels));
      });

      test('Apply convolution with edge mode duplicate', () {
        // 3x3 single red pixel in center
        final pixels = Uint8List.fromList([
          0, 0, 0, 255, // black
          0, 0, 0, 255, // black
          0, 0, 0, 255, // black
          0, 0, 0, 255, // black
          255, 0, 0, 255, // red center
          0, 0, 0, 255, // black
          0, 0, 0, 255, // black
          0, 0, 0, 255, // black
          0, 0, 0, 255, // black
        ]);

        // Box blur kernel
        final blurKernel = List<double>.filled(9, 1.0);

        final result = ConvolveMatrixProcessor.applyConvolution(
          pixels: pixels,
          width: 3,
          height: 3,
          kernel: blurKernel,
          orderX: 3,
          orderY: 3,
          targetX: 1,
          targetY: 1,
          divisor: 9.0,
          bias: 0.0,
          edgeMode: SvgConvolveEdgeMode.duplicate,
          preserveAlpha: false,
        );

        // Center pixel should have red spread out (255/9 ≈ 28)
        expect(result[16], closeTo(28, 1)); // Red channel of center
      });

      test('Apply convolution with edge mode none', () {
        // 2x2 all white
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

        // Box blur 3x3
        final blurKernel = List<double>.filled(9, 1.0);

        final result = ConvolveMatrixProcessor.applyConvolution(
          pixels: pixels,
          width: 2,
          height: 2,
          kernel: blurKernel,
          orderX: 3,
          orderY: 3,
          targetX: 1,
          targetY: 1,
          divisor: 9.0,
          bias: 0.0,
          edgeMode: SvgConvolveEdgeMode.none,
          preserveAlpha: false,
        );

        // With edgeMode=none, only 4 of 9 kernel cells are in-bounds
        // 4 * 255 / 9 ≈ 113
        expect(result[0], closeTo(113, 1)); // Red channel of top-left
      });

      test('Apply convolution with edge mode wrap', () {
        // 2x2 checkerboard: red/green, blue/white
        final pixels = Uint8List.fromList([
          255, 0, 0, 255, // red top-left
          0, 255, 0, 255, // green top-right
          0, 0, 255, 255, // blue bottom-left
          255, 255, 255, 255, // white bottom-right
        ]);

        // Identity kernel - should preserve pixels
        final identityKernel = <double>[0, 0, 0, 0, 1, 0, 0, 0, 0];

        final result = ConvolveMatrixProcessor.applyConvolution(
          pixels: pixels,
          width: 2,
          height: 2,
          kernel: identityKernel,
          orderX: 3,
          orderY: 3,
          targetX: 1,
          targetY: 1,
          divisor: 1.0,
          bias: 0.0,
          edgeMode: SvgConvolveEdgeMode.wrap,
          preserveAlpha: false,
        );

        expect(result, equals(pixels));
      });

      test('Apply convolution preserveAlpha=true keeps original alpha', () {
        // 2x2 with varying alpha
        final pixels = Uint8List.fromList([
          255, 0, 0, 128, // semi-transparent red
          0, 255, 0, 64, // quarter-transparent green
          0, 0, 255, 255, // opaque blue
          255, 255, 255, 0, // transparent white
        ]);

        // Brighten everything
        final brightenKernel = <double>[0, 0, 0, 0, 2, 0, 0, 0, 0];

        final result = ConvolveMatrixProcessor.applyConvolution(
          pixels: pixels,
          width: 2,
          height: 2,
          kernel: brightenKernel,
          orderX: 3,
          orderY: 3,
          targetX: 1,
          targetY: 1,
          divisor: 1.0,
          bias: 0.0,
          edgeMode: SvgConvolveEdgeMode.duplicate,
          preserveAlpha: true,
        );

        // Alpha values should be preserved
        expect(result[3], 128);
        expect(result[7], 64);
        expect(result[11], 255);
        expect(result[15], 0);
      });

      test('Apply convolution with bias', () {
        // 1x1 black pixel
        final pixels = Uint8List.fromList([0, 0, 0, 255]);

        // Identity kernel with bias 0.5 (adds 127.5 to each channel)
        final identityKernel = <double>[1.0];

        final result = ConvolveMatrixProcessor.applyConvolution(
          pixels: pixels,
          width: 1,
          height: 1,
          kernel: identityKernel,
          orderX: 1,
          orderY: 1,
          targetX: 0,
          targetY: 0,
          divisor: 1.0,
          bias: 0.5, // adds 127.5 to result
          edgeMode: SvgConvolveEdgeMode.duplicate,
          preserveAlpha: false,
        );

        expect(result[0], 128); // 0 + 127.5 rounded
        expect(result[1], 128);
        expect(result[2], 128);
      });

      test('Apply Sobel edge detection kernel', () {
        // 3x3 with horizontal gradient: black->white
        final pixels = Uint8List.fromList([
          0, 0, 0, 255, // black
          128, 128, 128, 255, // gray
          255, 255, 255, 255, // white
          0, 0, 0, 255, // black
          128, 128, 128, 255, // gray
          255, 255, 255, 255, // white
          0, 0, 0, 255, // black
          128, 128, 128, 255, // gray
          255, 255, 255, 255, // white
        ]);

        // Sobel X (horizontal edge detection)
        final sobelX = <double>[-1, 0, 1, -2, 0, 2, -1, 0, 1];

        final result = ConvolveMatrixProcessor.applyConvolution(
          pixels: pixels,
          width: 3,
          height: 3,
          kernel: sobelX,
          orderX: 3,
          orderY: 3,
          targetX: 1,
          targetY: 1,
          divisor: 1.0,
          bias: 0.5, // bias to make visible
          edgeMode: SvgConvolveEdgeMode.duplicate,
          preserveAlpha: false,
        );

        // Center pixel should show edge (high value)
        expect(result[16], greaterThan(200)); // Should detect strong edge
      });
    });

    group('Pipeline Integration', () {
      test('Resolve feConvolveMatrix creates SvgConvolveMatrixPaintPass', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="sharpenFx">
      <feConvolveMatrix 
        kernelMatrix="0 -1 0 -1 5 -1 0 -1 0"
        in="SourceGraphic"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#sharpenFx)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final passes = document.filters!.resolvePaintPasses('sharpenFx');

        expect(passes, hasLength(1));
        expect(passes.single, isA<SvgConvolveMatrixPaintPass>());

        final convolvePass = passes.single as SvgConvolveMatrixPaintPass;
        expect(convolvePass.convolveFilter.kernelMatrix.length, 9);
        expect(convolvePass.convolveFilter.divisor, 1.0);
      });

      test(
        'Resolve feConvolveMatrix with identity kernel returns regular pass',
        () {
          final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="identityFx">
      <feConvolveMatrix 
        kernelMatrix="0 0 0 0 1 0 0 0 0"
        divisor="1"
        bias="0"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#identityFx)"/>
</svg>
''';

          final document = SvgParser.parse(svgString);
          final passes = document.filters!.resolvePaintPasses('identityFx');

          expect(passes, hasLength(1));
          // Identity kernel should return regular pass, not SvgConvolveMatrixPaintPass
          expect(passes.single, isNot(isA<SvgConvolveMatrixPaintPass>()));
        },
      );

      test('Resolve feConvolveMatrix with chained filters', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="chainedFx">
      <feOffset dx="5" dy="5" result="offset"/>
      <feConvolveMatrix 
        in="offset"
        kernelMatrix="0 -1 0 -1 5 -1 0 -1 0"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#chainedFx)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final passes = document.filters!.resolvePaintPasses('chainedFx');

        expect(passes, hasLength(1));
        expect(passes.single, isA<SvgConvolveMatrixPaintPass>());

        final convolvePass = passes.single as SvgConvolveMatrixPaintPass;
        // Should have offset from previous filter
        expect(convolvePass.offset, const ui.Offset(5, 5));
      });

      test('Resolve feConvolveMatrix with SourceAlpha input', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="alphaConvFx">
      <feConvolveMatrix 
        in="SourceAlpha"
        kernelMatrix="0 -1 0 -1 5 -1 0 -1 0"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#alphaConvFx)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final passes = document.filters!.resolvePaintPasses('alphaConvFx');

        expect(passes, hasLength(1));
        expect(passes.single, isA<SvgConvolveMatrixPaintPass>());
        // Should have the SourceAlpha color filter
        expect(passes.single.colorFilter, isNotNull);
      });
    });

    group('Common Kernels', () {
      test('Sharpen kernel parsed correctly', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="sharpen">
      <feConvolveMatrix 
        order="3"
        kernelMatrix="0 -1 0 -1 5 -1 0 -1 0"/>
    </filter>
  </defs>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final filter =
            document.filters!.getById('sharpen') as SvgConvolveMatrixFilter;

        expect(filter.kernelMatrix, [0, -1, 0, -1, 5, -1, 0, -1, 0]);
        expect(filter.divisor, 1.0); // sum = 1
      });

      test('Edge detection kernel parsed correctly', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="edges">
      <feConvolveMatrix 
        order="3"
        kernelMatrix="-1 -1 -1 -1 8 -1 -1 -1 -1"/>
    </filter>
  </defs>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final filter =
            document.filters!.getById('edges') as SvgConvolveMatrixFilter;

        expect(filter.kernelMatrix, [-1, -1, -1, -1, 8, -1, -1, -1, -1]);
        expect(filter.divisor, 1.0); // sum = 0, defaults to 1
      });

      test('Emboss kernel parsed correctly', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="emboss">
      <feConvolveMatrix 
        order="3"
        kernelMatrix="-2 -1 0 -1 1 1 0 1 2"/>
    </filter>
  </defs>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final filter =
            document.filters!.getById('emboss') as SvgConvolveMatrixFilter;

        expect(filter.kernelMatrix, [-2, -1, 0, -1, 1, 1, 0, 1, 2]);
        expect(filter.divisor, 1.0); // sum = 1
      });

      test('Box blur 5x5 kernel parsed correctly', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="blur5x5">
      <feConvolveMatrix 
        order="5"
        kernelMatrix="1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1"
        divisor="25"/>
    </filter>
  </defs>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final filter =
            document.filters!.getById('blur5x5') as SvgConvolveMatrixFilter;

        expect(filter.orderX, 5);
        expect(filter.orderY, 5);
        expect(filter.kernelMatrix.length, 25);
        expect(filter.divisor, 25.0);
        expect(filter.targetX, 2); // floor(5/2)
        expect(filter.targetY, 2);
      });
    });
  });
}
