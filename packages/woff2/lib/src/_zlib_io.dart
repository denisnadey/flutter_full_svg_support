import 'dart:io' show zlib;
import 'dart:typed_data';

/// Decompresses a zlib (RFC 1950) stream with `dart:io`'s codec.
///
/// Throws a [FormatException] if [data] is not a valid zlib stream.
Uint8List zlibDecode(Uint8List data) => Uint8List.fromList(zlib.decode(data));
