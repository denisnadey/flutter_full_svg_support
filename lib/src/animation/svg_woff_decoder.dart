/// WOFF font decoder for SVG font loading.
///
/// Converts WOFF1 (web open font format) bytes to raw SFNT (TTF/OTF) bytes
/// so they can be loaded via Flutter's [FontLoader].
///
/// WOFF2 is not yet supported — returns null with [WoffDecodeResult.woff2Unsupported].
library;

import 'dart:io' show zlib;
import 'dart:math' as math;
import 'dart:typed_data';

/// Result of a WOFF decode attempt.
enum WoffDecodeResult {
  /// Not a WOFF file — caller should use bytes as-is.
  notWoff,

  /// Successfully decoded WOFF1 → SFNT.
  ok,

  /// WOFF2 detected but not supported.
  woff2Unsupported,

  /// WOFF1 file is malformed.
  malformed,
}

/// Inspects [bytes] and converts WOFF1 to SFNT if needed.
///
/// Returns `(result, sfntBytes)`:
/// - [WoffDecodeResult.notWoff] → bytes unchanged (not a WOFF file)
/// - [WoffDecodeResult.ok] → sfntBytes contains the decoded TTF/OTF
/// - [WoffDecodeResult.woff2Unsupported] → null bytes, WOFF2 not implemented
/// - [WoffDecodeResult.malformed] → null bytes, bad WOFF1 data
(WoffDecodeResult, Uint8List?) decodeFontIfWoff(Uint8List bytes) {
  if (bytes.length < 4) {
    return (WoffDecodeResult.notWoff, bytes);
  }

  final sig = (bytes[0] << 24) | (bytes[1] << 16) | (bytes[2] << 8) | bytes[3];

  if (sig == 0x774F4646) {
    // WOFF1
    final sfnt = _decodeWoff1(bytes);
    if (sfnt == null) {
      return (WoffDecodeResult.malformed, null);
    }
    return (WoffDecodeResult.ok, sfnt);
  }

  if (sig == 0x774F4632) {
    // WOFF2
    return (WoffDecodeResult.woff2Unsupported, null);
  }

  return (WoffDecodeResult.notWoff, bytes);
}

// ---------------------------------------------------------------------------
// WOFF1 decoder
// ---------------------------------------------------------------------------

// WOFF header layout (44 bytes):
//   0  uint32 signature  = 0x774F4646
//   4  uint32 flavor     = sfVersion (copied to SFNT header)
//   8  uint32 length
//  12  uint16 numTables
//  14  uint16 reserved
//  16  uint32 totalSfntSize
//  20  uint16 majorVersion
//  22  uint16 minorVersion
//  24  uint32 metaOffset
//  28  uint32 metaLength
//  32  uint32 metaOrigLength
//  36  uint32 privOffset
//  40  uint32 privLength
//
// Table directory entry (20 bytes each, right after header):
//   0  uint32 tag
//   4  uint32 offset      (from WOFF file start)
//   8  uint32 compLength
//  12  uint32 origLength
//  16  uint32 origCheckSum
//
// Output SFNT offset table (12 bytes):
//   0  uint32 sfVersion  (= WOFF flavor)
//   4  uint16 numTables
//   6  uint16 searchRange
//   8  uint16 entrySelector
//  10  uint16 rangeShift
//
// Output table directory entry (16 bytes each):
//   0  uint32 tag
//   4  uint32 checkSum   (= origCheckSum from WOFF)
//   8  uint32 offset     (new offset in reconstructed SFNT)
//  12  uint32 length     (= origLength)

Uint8List? _decodeWoff1(Uint8List woff) {
  if (woff.length < 44) return null;

  final hdr = woff.buffer.asByteData(woff.offsetInBytes, woff.lengthInBytes);

  final flavor = hdr.getUint32(4);
  final numTables = hdr.getUint16(12);

  if (woff.length < 44 + numTables * 20) return null;

  // ── 1. Read WOFF table directory ─────────────────────────────────────────
  final entries = List<_WoffEntry>.generate(numTables, (i) {
    final base = 44 + i * 20;
    return _WoffEntry(
      tag: hdr.getUint32(base),
      woffOffset: hdr.getUint32(base + 4),
      compLength: hdr.getUint32(base + 8),
      origLength: hdr.getUint32(base + 12),
      checkSum: hdr.getUint32(base + 16),
    );
  });

  // SFNT requires table directory sorted by tag.
  entries.sort((a, b) => a.tag.compareTo(b.tag));

  // ── 2. Decompress each table ──────────────────────────────────────────────
  final tableData = <Uint8List?>[];
  for (final e in entries) {
    final end = e.woffOffset + e.compLength;
    if (end > woff.length) return null;

    final compData = Uint8List.sublistView(woff, e.woffOffset, end);

    if (e.compLength < e.origLength) {
      // zlib-compressed (RFC 1950)
      Uint8List raw;
      try {
        raw = Uint8List.fromList(zlib.decode(compData));
      } catch (_) {
        return null;
      }
      if (raw.length != e.origLength) return null;
      tableData.add(raw);
    } else if (e.compLength == e.origLength) {
      // Stored uncompressed.
      tableData.add(compData);
    } else {
      return null; // compLength > origLength is invalid
    }
  }

  // ── 3. Calculate SFNT table offsets (4-byte aligned) ────────────────────
  // SFNT offset table:  12 bytes
  // SFNT table dir:     numTables * 16 bytes
  final sfntHeaderSize = 12 + numTables * 16;
  final offsets = List<int>.filled(numTables, 0);
  var cursor = sfntHeaderSize;
  for (var i = 0; i < numTables; i++) {
    offsets[i] = cursor;
    cursor += (entries[i].origLength + 3) & ~3; // pad to 4 bytes
  }
  final totalSize = cursor;

  // ── 4. Write output ───────────────────────────────────────────────────────
  final out = Uint8List(totalSize); // zero-initialised → padding already 0
  final w = out.buffer.asByteData();
  var pos = 0;

  // SFNT offset table
  w.setUint32(pos, flavor); pos += 4;
  w.setUint16(pos, numTables); pos += 2;
  final log2n = numTables > 0 ? math.log(numTables) ~/ math.log(2) : 0;
  final searchRange = (1 << log2n) * 16;
  final entrySelector = log2n;
  final rangeShift = numTables * 16 - searchRange;
  w.setUint16(pos, searchRange); pos += 2;
  w.setUint16(pos, entrySelector); pos += 2;
  w.setUint16(pos, rangeShift); pos += 2;

  // SFNT table directory
  for (var i = 0; i < numTables; i++) {
    final e = entries[i];
    w.setUint32(pos, e.tag); pos += 4;
    w.setUint32(pos, e.checkSum); pos += 4;
    w.setUint32(pos, offsets[i]); pos += 4;
    w.setUint32(pos, e.origLength); pos += 4;
  }

  // Table data
  for (var i = 0; i < numTables; i++) {
    final d = tableData[i]!;
    out.setRange(offsets[i], offsets[i] + d.length, d);
  }

  return out;
}

class _WoffEntry {
  const _WoffEntry({
    required this.tag,
    required this.woffOffset,
    required this.compLength,
    required this.origLength,
    required this.checkSum,
  });

  final int tag;
  final int woffOffset;
  final int compLength;
  final int origLength;
  final int checkSum;
}
