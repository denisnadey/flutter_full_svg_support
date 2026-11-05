/// Platform switch for zlib (RFC 1950) decompression of WOFF1 tables.
///
/// Native platforms (Android, iOS, macOS, Windows, Linux) get
/// `dart:io`'s `zlib` codec from `_zlib_io.dart`. On the web (dart2js and
/// dart2wasm) `dart:io` has no working zlib, so `_zlib_none.dart` is
/// exported instead: [zlibDecode] throws, the WOFF1 decoder catches it and
/// reports the font as malformed, and text falls back to another family.
library;

export '_zlib_io.dart' if (dart.library.js_interop) '_zlib_none.dart';
