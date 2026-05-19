import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:woff2/woff2.dart';

import '_fixtures.dart';

void main() {
  group('decodeFontIfWoff — non-WOFF input', () {
    test('returns notWoff for plain TTF signature', () {
      final bytes = Uint8List.fromList([0x00, 0x01, 0x00, 0x00, 0, 0, 0, 0]);
      final (result, out) = decodeFontIfWoff(bytes);
      expect(result, WoffDecodeResult.notWoff);
      expect(out, bytes);
    });

    test('returns notWoff for OTF (OTTO) signature', () {
      final bytes = Uint8List.fromList([0x4F, 0x54, 0x54, 0x4F, 0, 0, 0, 0]);
      final (result, _) = decodeFontIfWoff(bytes);
      expect(result, WoffDecodeResult.notWoff);
    });

    test('returns notWoff for too-short input', () {
      final bytes = Uint8List.fromList([0x77, 0x4F]);
      final (result, _) = decodeFontIfWoff(bytes);
      expect(result, WoffDecodeResult.notWoff);
    });
  });

  group('decodeFontIfWoff — malformed input', () {
    test('returns malformed for truncated WOFF1 header', () {
      // 'wOFF' magic + 4 bytes of garbage — too short for the 44-byte
      // WOFF1 header.
      final bytes = Uint8List.fromList([0x77, 0x4F, 0x46, 0x46, 0, 0, 0, 0]);
      final (result, _) = decodeFontIfWoff(bytes);
      expect(result, WoffDecodeResult.malformed);
    });

    test('returns malformed for truncated WOFF2 header', () {
      // 'wOF2' magic with insufficient padding — header is 48 bytes.
      final bytes = Uint8List.fromList([0x77, 0x4F, 0x46, 0x32, 0, 0, 0, 0]);
      final (result, _) = decodeFontIfWoff(bytes);
      expect(result, WoffDecodeResult.malformed);
    });

    test('returns malformed for WOFF1 with truncated directory', () {
      final hdr = Uint8List(44);
      final w = ByteData.sublistView(hdr);
      w.setUint32(0, 0x774F4646); // 'wOFF'
      w.setUint32(4, 0x00010000); // flavor
      w.setUint32(8, 44); // length
      w.setUint16(12, 3); // numTables = 3 but no directory follows
      final (result, _) = decodeFontIfWoff(hdr);
      expect(result, WoffDecodeResult.malformed);
    });
  });

  group('decodeFontIfWoff — WOFF1 round-trip', () {
    test('uncompressed WOFF1 decodes back to original SFNT', () {
      final sfnt = buildMinimalSfnt();
      final woff1 = wrapInWoff1(sfnt);

      // Sanity check: the wrapper produces a WOFF1 magic header.
      expect(
        (woff1[0] << 24) | (woff1[1] << 16) | (woff1[2] << 8) | woff1[3],
        0x774F4646,
      );

      final (result, decoded) = decodeFontIfWoff(woff1);
      expect(result, WoffDecodeResult.ok);
      expect(decoded, isNotNull);

      // The decoded magic must equal the original SFNT magic
      // ('OTTO' = 0x4F54544F).
      final magic = (decoded![0] << 24) |
          (decoded[1] << 16) |
          (decoded[2] << 8) |
          decoded[3];
      expect(magic, 0x4F54544F);

      // numTables byte (after the 4-byte magic) is preserved.
      expect((decoded[4] << 8) | decoded[5], 2);
    });

    test('zlib-compressed WOFF1 decodes back to original SFNT', () {
      // For a tiny font there's no real win from zlib, but the code path
      // still triggers when compLength < origLength.
      final sfnt = buildMinimalSfnt();
      final woff1 = wrapInWoff1(sfnt, useZlib: true);

      final (result, decoded) = decodeFontIfWoff(woff1);
      expect(result, WoffDecodeResult.ok);
      expect(decoded, isNotNull);

      final magic = (decoded![0] << 24) |
          (decoded[1] << 16) |
          (decoded[2] << 8) |
          decoded[3];
      expect(magic, 0x4F54544F);
    });
  });

  group('decodeFontIfWoff — WOFF2 round-trip', () {
    test('non-transformed WOFF2 decodes back to a valid SFNT', () {
      final sfnt = buildMinimalSfnt();
      final woff2 = wrapInWoff2(sfnt);

      // Sanity check: WOFF2 magic.
      expect(
        (woff2[0] << 24) | (woff2[1] << 16) | (woff2[2] << 8) | woff2[3],
        0x774F4632,
      );

      final (result, decoded) = decodeFontIfWoff(woff2);
      expect(result, WoffDecodeResult.ok);
      expect(decoded, isNotNull);

      final magic = (decoded![0] << 24) |
          (decoded[1] << 16) |
          (decoded[2] << 8) |
          decoded[3];
      expect(magic, 0x4F54544F);
      expect((decoded[4] << 8) | decoded[5], 2);
    });

    test('WOFF2 with TTC flavor returns malformed (collections '
        'are not supported)', () {
      // Build a 48-byte WOFF2 header where flavor = 'ttcf'.
      final hdr = Uint8List(48);
      final w = ByteData.sublistView(hdr);
      w.setUint32(0, 0x774F4632); // 'wOF2'
      w.setUint32(4, 0x74746366); // 'ttcf' — TTC collection
      w.setUint16(12, 1);
      final (result, _) = decodeFontIfWoff(hdr);
      // The decoder rejects TTC; it surfaces as `malformed` because
      // `_decodeWoff2` returns null in that branch.
      expect(result, WoffDecodeResult.malformed);
    });
  });
}
