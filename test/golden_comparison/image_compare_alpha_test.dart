import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/golden_capture/image_compare.dart';

void main() {
  group('compareRawPixels alpha-aware matching', () {
    test('ignores RGB payload differences for fully transparent pixels', () {
      final pixelsA = Uint8List.fromList(<int>[255, 255, 255, 0]);
      final pixelsB = Uint8List.fromList(<int>[0, 0, 0, 0]);

      final result = compareRawPixels(
        pixelsA: pixelsA,
        pixelsB: pixelsB,
        width: 1,
        height: 1,
        perPixelThreshold: 0,
      );

      expect(result.similarity, 1);
      expect(result.differentPixels, 0);
    });

    test('still detects alpha mismatch outside near-transparent range', () {
      final pixelsA = Uint8List.fromList(<int>[255, 255, 255, 0]);
      final pixelsB = Uint8List.fromList(<int>[255, 255, 255, 32]);

      final result = compareRawPixels(
        pixelsA: pixelsA,
        pixelsB: pixelsB,
        width: 1,
        height: 1,
        perPixelThreshold: 0,
      );

      expect(result.similarity, 0);
      expect(result.differentPixels, 1);
    });
  });
}
