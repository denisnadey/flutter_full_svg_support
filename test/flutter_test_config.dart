import 'dart:async';
import 'dart:io';

import 'package:es_compression/brotli.dart';

/// Called by the flutter test runner before each test file executes.
///
/// On macOS ARM64 (Apple Silicon), es_compression ships only an x86_64
/// esbrotli dylib that cannot load on arm64. We substitute a combined
/// ARM64 dylib built from Homebrew's brotli libraries that re-exports all
/// needed symbols (enc + dec + common).
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  if (Platform.isMacOS) {
    _initBrotliPath();
  }
  await testMain();
}

void _initBrotliPath() {
  final dylib = File('test/unit/test_data/esbrotli-mac-arm64.dylib');
  if (!dylib.existsSync()) return;
  try {
    BrotliCodec.libraryPath = dylib.absolute.path;
  } on StateError {
    // Library already initialised in a prior test file — ignore.
  }
}
