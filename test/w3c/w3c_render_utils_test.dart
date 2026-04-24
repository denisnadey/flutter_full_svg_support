@Tags(['w3c'])
library w3c_render_utils_test;

import 'dart:ui' as ui;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'w3c_render_utils.dart';

void main() {
  testWidgets(
    'compareWithReferencePng applies coords-viewattr-03-b overlay ignore regions',
    (tester) async {
      final renderedPng = await captureSvgFromFile(
        tester,
        'W3C_SVG_11_TestSuite/svg/coords-viewattr-03-b.svg',
      );

      final withoutMask = await tester.runAsync(
        () => compareWithReferencePng(
          renderedPng: renderedPng,
          referencePngPath: 'W3C_SVG_11_TestSuite/png/coords-viewattr-03-b.png',
        ),
      );
      final withMask = await tester.runAsync(
        () => compareWithReferencePng(
          renderedPng: renderedPng,
          referencePngPath: 'W3C_SVG_11_TestSuite/png/coords-viewattr-03-b.png',
          caseName: 'coords-viewattr-03-b',
        ),
      );

      expect(withoutMask, isNotNull);
      expect(withMask, isNotNull);
      expect(
        withMask!.similarity,
        greaterThanOrEqualTo(withoutMask!.similarity - 0.03),
      );
      expect(withMask.passed(kW3cSimilarityThreshold), isTrue);
    },
  );

  testWidgets(
    'compareWithReferencePng applies filters-image-01-b threshold override',
    (tester) async {
      final renderedPng = await captureSvgFromFile(
        tester,
        'W3C_SVG_11_TestSuite/svg/filters-image-01-b.svg',
      );

      final withoutOverride = await tester.runAsync(
        () => compareWithReferencePng(
          renderedPng: renderedPng,
          referencePngPath: 'W3C_SVG_11_TestSuite/png/filters-image-01-b.png',
        ),
      );
      final withOverride = await tester.runAsync(
        () => compareWithReferencePng(
          renderedPng: renderedPng,
          referencePngPath: 'W3C_SVG_11_TestSuite/png/filters-image-01-b.png',
          caseName: 'filters-image-01-b',
        ),
      );

      expect(withoutOverride, isNotNull);
      expect(withOverride, isNotNull);
      expect(
        withOverride!.similarity,
        greaterThanOrEqualTo(withoutOverride!.similarity - 0.03),
      );
      expect(withOverride.passed(kW3cSimilarityThreshold), isTrue);
    },
  );

  testWidgets(
    'compareWithReferencePng applies filters-color-02-b overlay ignore regions',
    (tester) async {
      final renderedPng = await captureSvgFromFile(
        tester,
        'W3C_SVG_11_TestSuite/svg/filters-color-02-b.svg',
      );

      final withoutMask = await tester.runAsync(
        () => compareWithReferencePng(
          renderedPng: renderedPng,
          referencePngPath: 'W3C_SVG_11_TestSuite/png/filters-color-02-b.png',
        ),
      );
      final withMask = await tester.runAsync(
        () => compareWithReferencePng(
          renderedPng: renderedPng,
          referencePngPath: 'W3C_SVG_11_TestSuite/png/filters-color-02-b.png',
          caseName: 'filters-color-02-b',
        ),
      );

      expect(withoutMask, isNotNull);
      expect(withMask, isNotNull);
      expect(
        withMask!.similarity,
        greaterThanOrEqualTo(withoutMask!.similarity - 0.03),
      );
      expect(withMask.passed(kW3cSimilarityThreshold), isTrue);
    },
  );

  testWidgets(
    'compareWithReferencePng applies color-prop-01-b overlay ignore regions',
    (tester) async {
      final renderedPng = await captureSvgFromFile(
        tester,
        'W3C_SVG_11_TestSuite/svg/color-prop-01-b.svg',
      );

      final withoutMask = await tester.runAsync(
        () => compareWithReferencePng(
          renderedPng: renderedPng,
          referencePngPath: 'W3C_SVG_11_TestSuite/png/color-prop-01-b.png',
        ),
      );
      final withMask = await tester.runAsync(
        () => compareWithReferencePng(
          renderedPng: renderedPng,
          referencePngPath: 'W3C_SVG_11_TestSuite/png/color-prop-01-b.png',
          caseName: 'color-prop-01-b',
        ),
      );

      expect(withoutMask, isNotNull);
      expect(withMask, isNotNull);
      expect(
        withMask!.similarity,
        greaterThanOrEqualTo(withoutMask!.similarity - 0.01),
      );
      expect(withMask.passed(kW3cSimilarityThreshold), isTrue);
    },
  );

  testWidgets(
    'compareWithReferencePng applies filters-image-04-f overlay ignore regions',
    (tester) async {
      final renderedPng = await captureSvgFromFile(
        tester,
        'W3C_SVG_11_TestSuite/svg/filters-image-04-f.svg',
      );

      final withoutMask = await tester.runAsync(
        () => compareWithReferencePng(
          renderedPng: renderedPng,
          referencePngPath: 'W3C_SVG_11_TestSuite/png/filters-image-04-f.png',
        ),
      );
      final withMask = await tester.runAsync(
        () => compareWithReferencePng(
          renderedPng: renderedPng,
          referencePngPath: 'W3C_SVG_11_TestSuite/png/filters-image-04-f.png',
          caseName: 'filters-image-04-f',
        ),
      );

      expect(withoutMask, isNotNull);
      expect(withMask, isNotNull);
      expect(
        withMask!.similarity,
        greaterThanOrEqualTo(withoutMask!.similarity - 0.01),
      );
    },
  );

  testWidgets('captureSvgFromFile includes asynchronously decoded image content', (
    tester,
  ) async {
    final rendered = await captureSvgFromFile(
      tester,
      'W3C_SVG_11_TestSuite/svg/filters-blend-01-b.svg',
    );

    final decoded = await tester.runAsync<_DecodedPng?>(
      () => _decodePngToRawRgba(rendered),
    );
    expect(decoded, isNotNull);
    final image = decoded!;

    // This pixel sits inside the stretched background image area but above
    // the first blue rectangle. If image decode is missing, this area is black.
    final sample = _samplePixel(image, x: 200, y: 20);
    expect(sample.a, greaterThan(0));
    final isBlack = sample.r == 0 && sample.g == 0 && sample.b == 0;
    expect(
      isBlack,
      isFalse,
      reason:
          'Expected decoded background image content at (200,20), got black pixel.',
    );
  });
}

class _DecodedPng {
  const _DecodedPng({
    required this.width,
    required this.height,
    required this.rgba,
  });

  final int width;
  final int height;
  final Uint8List rgba;
}

class _Rgba {
  const _Rgba({
    required this.r,
    required this.g,
    required this.b,
    required this.a,
  });

  final int r;
  final int g;
  final int b;
  final int a;
}

Future<_DecodedPng?> _decodePngToRawRgba(Uint8List pngBytes) async {
  final codec = await ui.instantiateImageCodec(pngBytes);
  try {
    final frame = await codec.getNextFrame();
    final image = frame.image;
    try {
      final byteData = await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      if (byteData == null) {
        return null;
      }
      return _DecodedPng(
        width: image.width,
        height: image.height,
        rgba: byteData.buffer.asUint8List(),
      );
    } finally {
      image.dispose();
    }
  } finally {
    codec.dispose();
  }
}

_Rgba _samplePixel(_DecodedPng image, {required int x, required int y}) {
  expect(x, inInclusiveRange(0, image.width - 1));
  expect(y, inInclusiveRange(0, image.height - 1));

  final index = (y * image.width + x) * 4;
  return _Rgba(
    r: image.rgba[index],
    g: image.rgba[index + 1],
    b: image.rgba[index + 2],
    a: image.rgba[index + 3],
  );
}
