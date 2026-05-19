import 'dart:async';
import 'dart:io';

import 'package:es_compression/brotli.dart';

/// Called by the flutter test runner before each test file executes.
///
/// On macOS ARM64 (Apple Silicon), `es_compression` ships only an
/// x86_64 `esbrotli-mac64.dylib` that cannot load on `arm64`. If a
/// developer has built a compatible dylib (the parent monorepo keeps
/// one in `test/unit/test_data/esbrotli-mac-arm64.dylib`), point the
/// FFI loader at it.
///
/// Set `WOFF2_BROTLI_DYLIB=/abs/path/to/libesbrotli.dylib` to override.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  if (Platform.isMacOS) {
    _initBrotliPath();
  }
  await testMain();
}

void _initBrotliPath() {
  final candidates = <String>[
    if (Platform.environment['WOFF2_BROTLI_DYLIB'] != null)
      Platform.environment['WOFF2_BROTLI_DYLIB']!,
    // Parent monorepo convention.
    '../../test/unit/test_data/esbrotli-mac-arm64.dylib',
    // Common Homebrew location for the upstream Brotli library.
    '/opt/homebrew/lib/libbrotlienc.dylib',
  ];

  for (final path in candidates) {
    final file = File(path);
    if (!file.existsSync()) continue;
    try {
      BrotliCodec.libraryPath = file.absolute.path;
      return;
    } on StateError {
      // Library already initialised in a prior test file — ignore.
      return;
    }
  }
}
