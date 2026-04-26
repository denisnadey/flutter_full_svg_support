import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:full_svg_flutter/src/animation/svg_woff_decoder.dart';

void main() {
  group('decodeFontIfWoff', () {
    test('returns notWoff for non-WOFF bytes', () {
      final bytes = Uint8List.fromList([0x00, 0x01, 0x00, 0x00]);
      final (result, _) = decodeFontIfWoff(bytes);
      expect(result, WoffDecodeResult.notWoff);
    });

    test('returns notWoff for too-short input', () {
      final bytes = Uint8List.fromList([0x77, 0x4F]);
      final (result, _) = decodeFontIfWoff(bytes);
      expect(result, WoffDecodeResult.notWoff);
    });

    test('returns malformed for truncated WOFF1', () {
      final bytes = Uint8List.fromList([0x77, 0x4F, 0x46, 0x46, 0, 0, 0, 0]);
      final (result, _) = decodeFontIfWoff(bytes);
      expect(result, WoffDecodeResult.malformed);
    });

    test('returns malformed for truncated WOFF2', () {
      // WOFF2 magic with minimal padding — not enough to parse header
      final bytes = Uint8List.fromList([0x77, 0x4F, 0x46, 0x32, 0, 0, 0, 0]);
      final (result, _) = decodeFontIfWoff(bytes);
      expect(result, WoffDecodeResult.malformed);
    });

    test('decodes real WOFF1 fonts from W3C test suite', () {
      for (final name in ['Blocky.woff', 'EzraSILSR.woff', 'anglepoi.woff']) {
        final path =
            'W3C_SVG_11_TestSuite/resources/$name';
        final file = File(path);
        if (!file.existsSync()) continue;

        final bytes = file.readAsBytesSync();
        final (result, sfnt) = decodeFontIfWoff(bytes);
        expect(result, WoffDecodeResult.ok,
            reason: '$name should decode to ok');
        expect(sfnt, isNotNull, reason: '$name sfnt should be non-null');

        // Check SFNT magic byte (0x00010000 for TrueType or 'OTTO' for CFF).
        final magic = (sfnt![0] << 24) |
            (sfnt[1] << 16) |
            (sfnt[2] << 8) |
            sfnt[3];
        expect(
          magic == 0x00010000 || magic == 0x4F54544F || magic == 0x74727565,
          isTrue,
          reason: '$name should have valid SFNT magic, got 0x${magic.toRadixString(16)}',
        );
      }
    });

    test('decodes WOFF2 if test file available', () {
      final file = File('test/unit/test_data/sample.woff2');
      if (!file.existsSync()) {
        // Skip gracefully if no WOFF2 test file available.
        return;
      }
      final bytes = file.readAsBytesSync();
      final (result, sfnt) = decodeFontIfWoff(bytes);
      expect(result, WoffDecodeResult.ok);
      expect(sfnt, isNotNull);
      // Check SFNT magic.
      final magic = (sfnt![0] << 24) |
          (sfnt[1] << 16) |
          (sfnt[2] << 8) |
          sfnt[3];
      expect(
        magic == 0x00010000 || magic == 0x4F54544F || magic == 0x74727565,
        isTrue,
        reason: 'WOFF2 should produce valid SFNT magic',
      );
    });
  });
}
