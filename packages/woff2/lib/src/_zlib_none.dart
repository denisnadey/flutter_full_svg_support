import 'dart:typed_data';

/// zlib is unavailable on the web build: always throws [UnsupportedError].
Uint8List zlibDecode(Uint8List data) =>
    throw UnsupportedError('zlib decompression is not available on the web');
