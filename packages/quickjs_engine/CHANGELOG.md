# Changelog

## Unreleased

- Fixed the macOS prebuilt bridge so it contains both arm64 and x86_64
  slices and is built with an explicit deployment target.

## 0.1.4

- Fixed Windows builds by declaring the exported C API plugin class in the
  Flutter manifest, so generated registrants call
  `QuickjsEnginePluginCApiRegisterWithRegistrar` instead of the missing
  `QuickjsEnginePluginRegisterWithRegistrar` symbol.
- Added the canonical `quickjs_engine_plugin_c_api.h` public header expected by
  Flutter's Windows tooling while preserving the previous header as a
  compatibility include.
- Added a clean Windows release-build workflow to catch plugin registration,
  header, and native-link regressions.

## 0.1.3

- Linked Android native libraries with 16 KB ELF `LOAD` segment alignment so
  apps run natively on 16 KB page-size devices when built with NDK r27.
- Added release APK checks for both ELF segment alignment and ZIP alignment.
- Preserved compatibility with the package's CMake 3.10 minimum.

## 0.1.2

- Fixed Android release builds by linking the native QuickJS bridge with the
  Android `log` system library used by `__android_log_print`.
- Aligned the Android plugin Java/Kotlin JVM target settings so clean release
  builds complete on modern Flutter/Gradle toolchains.

## 0.1.1

Documentation + tooling additions, no engine changes.

- Rewrote `README.md` with explicit per-platform tables (Android / iOS / macOS / Linux / Windows) covering how the library is produced and what action is required from package consumers (usually: none).
- Added a **When you might need to rebuild** section so it's clear that typical app development needs no native toolchain.
- Added a **Troubleshooting** section: macOS "tests can't find dylib", deployment-target warnings, Android NDK requirements, Windows `cl.exe` environment, missing-dylib after fresh checkout.
- New `tool/build_native.ps1` — PowerShell version of the build script for Windows hosts. Handles MSVC's `Release\` config subdirectory.
- `tool/build_native.sh` is now platform-aware (detects macOS vs Linux via `uname -s`) and stages the output appropriately on macOS, while leaving the Linux build under `native/build/` since the consumer's plugin CMake rebuilds anyway.

## 0.1.0

Initial release.

- Forked from `flutter_js` 0.8.7 (MIT, by Ábner Oliveira). Dart-side API
  surface is API-compatible: `getJavascriptRuntime()`, `evaluate()`,
  `onMessage()`, `enableFetch()`, `enableHandlePromises()`,
  `QuickJsRuntime2`, `JavascriptRuntime` all work as upstream.
- **Replaced bundled JS engine** with [QuickJS-NG 0.14.0][qjsng] (May 2026).
  Same engine on every platform — Android, iOS, macOS, Linux, Windows. No
  more JavaScriptCore fallback on Apple targets.
- Patched the FFI bridge (`native/cxx/libfastdev_quickjs_runtime.cpp`)
  against QuickJS-NG's updated API:
    - `JS_NewClassID(rt, &id)` takes an explicit runtime
    - `JS_IsPromise`, `JS_IsArray`, `JS_IsError` are single-argument
    - `JS_BOOL` → `bool`
- Native build wiring:
    - Android: NDK CMake driven from `android/build.gradle` →
      `native/CMakeLists.txt` (armeabi-v7a, arm64-v8a, x86, x86_64).
    - iOS: podspec compiles bridge + QuickJS sources into the plugin
      framework via `source_files`.
    - macOS: podspec vendors a prebuilt
      `libquickjs_c_bridge_plugin.dylib`; rebuild via
      `tools/build_native.sh`.
    - Linux/Windows: plugin CMakeLists pulls in `native/CMakeLists.txt`
      via `add_subdirectory`.
- Runtime selector (`getJavascriptRuntime()`) always returns the QuickJS
  path on every platform; the `JavascriptCoreRuntime` bindings are kept
  in `lib/javascriptcore/` for ABI compatibility but unused.

[qjsng]: https://github.com/quickjs-ng/quickjs
