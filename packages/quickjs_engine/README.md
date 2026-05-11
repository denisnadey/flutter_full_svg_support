# quickjs_engine

A self-contained, up-to-date QuickJS runtime for Flutter — bundles
[**QuickJS-NG 0.14.0**][qjsng] (2026 release) directly into your app, so
every platform runs the **same** modern JavaScript engine. No JavaScriptCore
fallback. No 5-year-old vendored copy of QuickJS. No mystery platform
divergence.

[qjsng]: https://github.com/quickjs-ng/quickjs

> A fork of [`flutter_js`][upstream] by Ábner Oliveira, with the JS engine
> replaced by `quickjs-ng` and the FFI bridge patched against its new API.
> Born out of debugging an SVGator player that produced different numeric
> output on iOS (JSC) vs Android (old QuickJS) vs Chrome (V8) — see the
> "Why" section below.

[upstream]: https://pub.dev/packages/flutter_js

## Features

- 🌍 **Single JS engine on every platform** — macOS, iOS, Android, Linux,
  Windows. No more "works on Android, broken on iOS" QuickJS-vs-JSC bugs.
- 🚀 **Modern QuickJS-NG** — Symbol.iterator, Proxy, async/await, Promise,
  WeakMap/WeakSet, BigInt, regex named groups, all the ES2020+ features the
  2021-vintage upstream QuickJS doesn't have.
- 🔌 **API-compatible drop-in** for projects already using `flutter_js`
  (`getJavascriptRuntime()`, `evaluate()`, `onMessage()`, `enableFetch()`,
  `enableHandlePromises()`).
- 🧰 **Bundles the native bridge** — no `cmake`/CocoaPods voodoo for
  consumers; the platform plugin builds and links a `libquickjs_c_bridge_plugin`
  shared library for your app automatically.

## Quick start

```yaml
dependencies:
  quickjs_engine: ^0.1.0
```

```dart
import 'package:quickjs_engine/quickjs_engine.dart';

void main() {
  final js = getJavascriptRuntime(xhr: false);

  // Evaluate.
  final r = js.evaluate('2 + 2');
  print(r.stringResult); // 4

  // Bidirectional messaging — call back into Dart from JS.
  js.onMessage('myChannel', (dynamic args) {
    print('JS sent: $args');
    return 'pong';
  });
  js.evaluate('sendMessage("myChannel", JSON.stringify({hello: "world"}))');

  js.dispose();
}
```

## Why a fork?

The published `flutter_js` package uses QuickJS dated **2021-03-27** on
Android/Windows/Linux, and **JavaScriptCore** on macOS/iOS. Two consequences
matter for anyone running a non-trivial JS workload (e.g. SVG animation
players, custom expression engines, JSON-schema validators, sandboxed user
scripts):

1. **Engine divergence per platform.** JSC and QuickJS-2021 have different
   numeric edge cases, garbage-collection timings, and proxy/iterator
   semantics. Code that works on Android may misbehave on iOS without
   warning.
2. **Old engine, old bugs.** QuickJS-NG has had ~5 years of fixes since
   2021 (codegen, regex, arithmetic, GC). Most are silent — but if your JS
   uses Proxy traps, Symbol iteration, async/await, or arc-length-style
   bezier math (we hit this one), the diff is real.

This package bundles **one** engine — QuickJS-NG 0.14.0, same on every
platform — and ships a patched FFI bridge that compiles against the new
QuickJS-NG API (`JS_NewClassID(rt, &id)`, `JS_IsPromise(val)`,
`JS_IsArray(val)`, etc.).

## Platform support

| Platform | Engine          | How it's loaded                          |
|----------|-----------------|------------------------------------------|
| Android  | QuickJS-NG via NDK CMake | CMakeLists in `native/` builds .so per ABI |
| iOS      | QuickJS-NG via CocoaPods | Podspec compiles bridge + qjs sources into the plugin framework |
| macOS    | QuickJS-NG via CocoaPods | Prebuilt dylib vendored under `macos/Frameworks/`; rebuild with `tool/build_native.sh` |
| Linux    | QuickJS-NG via CMake     | Bundled into the app's plugin lib |
| Windows  | QuickJS-NG via CMake     | Bundled into the app's plugin lib |

JavaScriptCore bindings from the upstream package are kept for ABI but the
runtime selector (`getJavascriptRuntime()`) always returns the QuickJS path.

## Rebuilding the macOS dylib

The macOS plugin ships a prebuilt dylib so `pod install` "just works" out of
the box. If you change the bridge source, run:

```bash
cd packages/quickjs_engine
tool/build_native.sh
```

This invokes `cmake -S native -B native/build && cmake --build native/build`
and copies the resulting `libquickjs_c_bridge_plugin.dylib` into
`macos/Frameworks/`.

## Acknowledgements

- [`flutter_js`][upstream] by Ábner Oliveira — the bridge architecture,
  message-channel design, and JSC bindings come straight from upstream.
- [`quickjs-ng`][qjsng] — the actively-maintained QuickJS fork
  (Fabrice Bellard, Charlie Gordon, Ben Noordhuis, Saúl Ibarra Corretgé).
- [`flutter_qjs_engine`'s bridge cpp][bridge] for the `JS_NewClassID(rt,...)`
  API porting pattern.

[bridge]: https://github.com/abner/flutter_js/tree/master/native/cxx

## License

MIT — see [LICENSE](LICENSE). Bundled upstream sources are also MIT
(Ábner Oliveira for `flutter_js`; Fabrice Bellard et al. for QuickJS-NG).
The full text of each upstream license is reproduced in `LICENSE`.
