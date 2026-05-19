/// Programmatic font-byte builders for the test suite.
///
/// We don't bundle real font files (license clarity, repo size). Instead
/// we construct minimal-but-spec-valid SFNT, WOFF1 and WOFF2 byte
/// sequences in pure Dart. The decoder only needs structural validity,
/// not glyph correctness, so a "font" with two trivial tables is enough
/// to exercise every code path.
library;

import 'dart:io' show zlib;
import 'dart:typed_data';

import 'package:es_compression/brotli.dart';

/// Builds a tiny but spec-valid SFNT (OpenType-CFF flavor) with two
/// arbitrary tables. The bytes are not a *usable* font — we only need
/// the table directory to round-trip cleanly through WOFF encode/decode.
Uint8List buildMinimalSfnt() {
  // Two tables: 'name' and 'cmap'. Order doesn't matter for the
  // directory builder — we'll sort by tag below as the SFNT spec
  // requires.
  final tables = <int, Uint8List>{
    _tag('cmap'): Uint8List.fromList([
      0, 0, // version = 0
      0, 0, // numTables = 0
    ]),
    _tag('name'): Uint8List.fromList([
      0, 0, // format = 0
      0, 0, // count = 0
      0, 6, // stringOffset = 6
    ]),
  };

  return _packSfnt(0x4F54544F /* 'OTTO' */, tables);
}

/// Wraps a TTF/OTF byte stream in a WOFF1 container (uncompressed
/// tables). Returns spec-valid `wOFF` bytes that round-trip back to
/// [sfntBytes] when fed to `decodeFontIfWoff`.
Uint8List wrapInWoff1(Uint8List sfntBytes, {bool useZlib = false}) {
  final hd = ByteData.sublistView(sfntBytes);
  final flavor = hd.getUint32(0);
  final numTables = hd.getUint16(4);

  // Parse SFNT directory entries.
  final entries = <_SfntEntry>[];
  for (var i = 0; i < numTables; i++) {
    final base = 12 + i * 16;
    entries.add(
      _SfntEntry(
        tag: hd.getUint32(base),
        checkSum: hd.getUint32(base + 4),
        offset: hd.getUint32(base + 8),
        length: hd.getUint32(base + 12),
      ),
    );
  }

  // Compress each table (or leave it raw).
  final compressed = <Uint8List>[];
  for (final e in entries) {
    final raw = Uint8List.sublistView(sfntBytes, e.offset, e.offset + e.length);
    if (useZlib) {
      compressed.add(Uint8List.fromList(zlib.encode(raw)));
    } else {
      compressed.add(raw);
    }
  }

  // Compute offsets in the WOFF stream.
  final woffHeaderSize = 44;
  final dirSize = numTables * 20;
  var cursor = woffHeaderSize + dirSize;
  final woffOffsets = <int>[];
  for (var i = 0; i < numTables; i++) {
    woffOffsets.add(cursor);
    final compLen = compressed[i].length;
    final useCompressed = useZlib && compLen < entries[i].length;
    cursor += useCompressed ? compLen : entries[i].length;
    cursor = (cursor + 3) & ~3; // 4-byte align
  }
  final totalLength = cursor;

  final out = Uint8List(totalLength);
  final w = ByteData.sublistView(out);

  // WOFF1 header.
  w.setUint32(0, 0x774F4646); // 'wOFF'
  w.setUint32(4, flavor);
  w.setUint32(8, totalLength);
  w.setUint16(12, numTables);
  w.setUint16(14, 0); // reserved
  w.setUint32(16, sfntBytes.length);
  w.setUint16(20, 1); // majorVersion
  w.setUint16(22, 0); // minorVersion
  w.setUint32(24, 0); // metaOffset
  w.setUint32(28, 0); // metaLength
  w.setUint32(32, 0); // metaOrigLength
  w.setUint32(36, 0); // privOffset
  w.setUint32(40, 0); // privLength

  // Directory.
  for (var i = 0; i < numTables; i++) {
    final base = woffHeaderSize + i * 20;
    final e = entries[i];
    final compLen = compressed[i].length;
    final useCompressed = useZlib && compLen < e.length;
    w.setUint32(base, e.tag);
    w.setUint32(base + 4, woffOffsets[i]);
    w.setUint32(base + 8, useCompressed ? compLen : e.length);
    w.setUint32(base + 12, e.length);
    w.setUint32(base + 16, e.checkSum);
  }

  // Table data.
  for (var i = 0; i < numTables; i++) {
    final compLen = compressed[i].length;
    final useCompressed = useZlib && compLen < entries[i].length;
    final src = useCompressed
        ? compressed[i]
        : Uint8List.sublistView(
            sfntBytes,
            entries[i].offset,
            entries[i].offset + entries[i].length,
          );
    out.setRange(woffOffsets[i], woffOffsets[i] + src.length, src);
  }

  return out;
}

/// Wraps a TTF/OTF byte stream in a WOFF2 container with **no** glyf/loca
/// transformations applied (every table is encoded as-is and Brotli-
/// compressed). Suitable for round-trip testing of the non-transform
/// code paths in `decodeFontIfWoff`.
Uint8List wrapInWoff2(Uint8List sfntBytes) {
  final hd = ByteData.sublistView(sfntBytes);
  final flavor = hd.getUint32(0);
  final numTables = hd.getUint16(4);

  final entries = <_SfntEntry>[];
  for (var i = 0; i < numTables; i++) {
    final base = 12 + i * 16;
    entries.add(
      _SfntEntry(
        tag: hd.getUint32(base),
        checkSum: hd.getUint32(base + 4),
        offset: hd.getUint32(base + 8),
        length: hd.getUint32(base + 12),
      ),
    );
  }

  // Build the uncompressed payload (concatenated table data) and the
  // WOFF2 table directory.
  final payload = BytesBuilder(copy: false);
  final dirBytes = BytesBuilder(copy: false);

  for (final e in entries) {
    // Look up tagIndex in the known-tags table; if absent, use 0x3F and
    // emit the raw tag inline.
    final tagIndex = _kKnownTags.indexOf(e.tag);
    final flagByte = tagIndex >= 0 ? tagIndex : 0x3F;
    // xformVersion bits 6-7 = 0. For non-glyf/non-loca tags, xformVersion
    // 0 means "no transform" — exactly what we want.
    dirBytes.addByte(flagByte);
    if (tagIndex < 0) {
      final tagBuf = ByteData(4)..setUint32(0, e.tag);
      dirBytes.add(tagBuf.buffer.asUint8List(0, 4));
    }
    dirBytes.add(_encodeBase128(e.length));

    final raw = Uint8List.sublistView(sfntBytes, e.offset, e.offset + e.length);
    payload.add(raw);
  }

  final uncompressed = payload.takeBytes();
  final compressed = Uint8List.fromList(brotli.encode(uncompressed));

  final dir = dirBytes.takeBytes();
  final headerSize = 48;
  final totalLength = headerSize + dir.length + compressed.length;

  final out = Uint8List(totalLength);
  final w = ByteData.sublistView(out);

  // WOFF2 header.
  w.setUint32(0, 0x774F4632); // 'wOF2'
  w.setUint32(4, flavor);
  w.setUint32(8, totalLength);
  w.setUint16(12, numTables);
  w.setUint16(14, 0); // reserved
  w.setUint32(16, sfntBytes.length); // totalSfntSize
  w.setUint32(20, compressed.length); // totalCompressedSize
  w.setUint16(24, 1); // majorVersion
  w.setUint16(26, 0); // minorVersion
  w.setUint32(28, 0);
  w.setUint32(32, 0);
  w.setUint32(36, 0);
  w.setUint32(40, 0);
  w.setUint32(44, 0);

  out.setRange(headerSize, headerSize + dir.length, dir);
  out.setRange(
    headerSize + dir.length,
    headerSize + dir.length + compressed.length,
    compressed,
  );

  return out;
}

// -- internals -------------------------------------------------------------

class _SfntEntry {
  _SfntEntry({
    required this.tag,
    required this.checkSum,
    required this.offset,
    required this.length,
  });
  final int tag;
  final int checkSum;
  final int offset;
  final int length;
}

int _tag(String s) {
  assert(s.length == 4);
  return (s.codeUnitAt(0) << 24) |
      (s.codeUnitAt(1) << 16) |
      (s.codeUnitAt(2) << 8) |
      s.codeUnitAt(3);
}

Uint8List _packSfnt(int sfntVersion, Map<int, Uint8List> tables) {
  final sortedTags = tables.keys.toList()..sort();
  final n = sortedTags.length;
  final headerSize = 12 + n * 16;

  final offsets = <int, int>{};
  var cursor = headerSize;
  for (final t in sortedTags) {
    offsets[t] = cursor;
    cursor += (tables[t]!.length + 3) & ~3;
  }
  final total = cursor;

  final out = Uint8List(total);
  final w = ByteData.sublistView(out);

  w.setUint32(0, sfntVersion);
  w.setUint16(4, n);
  // searchRange/entrySelector/rangeShift — set to plausible values
  // (the decoder reads them but doesn't validate).
  w.setUint16(6, 16);
  w.setUint16(8, 0);
  w.setUint16(10, 0);

  for (var i = 0; i < n; i++) {
    final tag = sortedTags[i];
    final base = 12 + i * 16;
    w.setUint32(base, tag);
    w.setUint32(base + 4, 0); // checkSum
    w.setUint32(base + 8, offsets[tag]!);
    w.setUint32(base + 12, tables[tag]!.length);
  }

  for (final tag in sortedTags) {
    final d = tables[tag]!;
    out.setRange(offsets[tag]!, offsets[tag]! + d.length, d);
  }

  return out;
}

Uint8List _encodeBase128(int value) {
  // UIntBase128: 1–5 bytes, big-endian, high bit = continuation.
  if (value < 0) throw ArgumentError('negative');
  if (value == 0) return Uint8List.fromList([0]);
  final bytes = <int>[];
  while (value > 0) {
    bytes.insert(0, value & 0x7F);
    value >>= 7;
  }
  for (var i = 0; i < bytes.length - 1; i++) {
    bytes[i] |= 0x80;
  }
  return Uint8List.fromList(bytes);
}

const _kKnownTags = <int>[
  0x636D6170, 0x68656164, 0x68686561, 0x686D7478,
  0x6D617870, 0x6E616D65, 0x4F532F32, 0x706F7374,
  0x63767420, 0x6670676D, 0x676C7966, 0x6C6F6361,
  0x70726570, 0x43464620, 0x564F5247, 0x45424454,
  0x45424C43, 0x67617370, 0x68646D78, 0x6B65726E,
  0x4C545348, 0x50434C54, 0x56444D58, 0x76686561,
  0x766D7478, 0x42415345, 0x47444546, 0x47504F53,
  0x47535542, 0x45425343, 0x4A535446, 0x4D415448,
  0x43424454, 0x43424C43, 0x434F4C52, 0x4350414C,
  0x53564720, 0x73626978, 0x61636E74, 0x61766172,
  0x62646174, 0x626C6F63, 0x62736C6E, 0x63766172,
  0x66647363, 0x66656174, 0x666D7478, 0x66766172,
  0x67766172, 0x68737479, 0x6A757374, 0x6C636172,
  0x6D6F7274, 0x6D6F7278, 0x6F706264, 0x70726F70,
  0x7472616B, 0x5A617066, 0x53696C66, 0x476C6174,
  0x476C6F63, 0x46656174, 0x53696C6C,
];
