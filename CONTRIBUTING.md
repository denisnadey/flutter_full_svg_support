# Contributing to full_svg_flutter

Thanks for helping. Bug reports with a minimal SVG that reproduces the problem
are the most useful thing you can send. Open an
[issue](https://github.com/denisnadey/flutter_full_svg_support/issues) and
attach the file, or paste it if it is small.

## Setup

The repository pins Flutter 3.38.1 in `.fvmrc`. With [FVM](https://fvm.app):

```bash
fvm install
fvm flutter pub get
```

A global Flutter 3.38.x works as well.

`flutter test` runs in a plain Dart VM, so two native libraries are provided
by hand:

- **QuickJS bridge** (tests that run SVG `<script>`). Point the loader at the
  prebuilt universal macOS library:

  ```bash
  export LIBQUICKJSC_TEST_PATH=$PWD/packages/quickjs_engine/macos/Frameworks/libquickjs_c_bridge_plugin.dylib
  ```

  On Linux or Windows, build it with
  `sh packages/quickjs_engine/tool/build_native.sh` (or `build_native.ps1`);
  the loader then finds it under `packages/quickjs_engine/native/build/`.

- **Brotli** (WOFF2 tests on macOS). `test/flutter_test_config.dart` loads an
  arm64 dylib that re-exports Homebrew's libbrotli: `brew install brotli`.

## How the engine is put together

There is one rendering engine. `SvgPicture` (the `flutter_svg`-compatible
API), `AnimatedSvgPicture` and `FSvgPicture` all parse the SVG into a
DOM-preserving tree and paint it directly on the canvas:

```
SVG text ─▶ svg_parser*.dart ─▶ SvgDocument / SvgNode (svg_dom.dart)
                                   │
            CSS (css_*.dart) ──────┤  cascade, @keyframes → SMIL
            SMIL (smil/) ──────────┤  SvgTimeline ticks animations
            JS (svg_js_bridge*.dart, native only) ─ mutates the DOM
                                   ▼
                    animated_svg_painter*.dart ─▶ Canvas
```

| Path | Contents |
|---|---|
| `lib/svg.dart` | `SvgPicture`, `FSvgPicture` |
| `lib/src/animation/animated_svg_picture*.dart` | The engine widget: lifecycle, DevTools, hit-testing |
| `lib/src/animation/animated_svg_painter*.dart` | Painter and its feature modules |
| `lib/src/animation/svg_parser*.dart`, `svg_dom.dart` | XML → DOM |
| `lib/src/animation/css_*.dart` | CSS parsing, cascade, animations |
| `lib/src/animation/smil/` | SMIL timing, interpolation, motion paths |
| `lib/src/animation/svg_filters*.dart` | Filter primitives |
| `lib/src/animation/svg_js_bridge*.dart` | QuickJS bridge (native) and the web stub |
| `packages/quickjs_engine/` | Embedded QuickJS via FFI, published separately |
| `packages/woff2/` | WOFF/WOFF2 decoder, published separately |

Platform-specific code goes behind conditional exports keyed on
`dart.library.js_interop` (see `lib/src/utilities/file.dart` and
`lib/src/animation/svg_js_bridge_platform.dart`). Never import `dart:ffi`,
`dart:io` or `package:quickjs_engine` unconditionally from `lib/`: web builds
break, or pub.dev stops listing Web.

### An animation doesn't play?

Check, in order:

1. `AnimationDetector.hasAnimations()` returns `true` for the source.
2. `SmilParser.parseAnimations()` returns the animation.
3. `SmilAnimation.computeValue(t)` produces the values you expect.
4. The painter applies the animated value.

## Tests

```bash
flutter test                           # everything, ~5,300 tests
flutter test test/animation/           # one area
./tool/w3c_goldens/run_w3c_comparison.sh --tier smoke --skip-browser --enable-render
```

Test runs rewrite `test/goldens/w3c/reports/w3c_latest_report.json`; revert
it unless you mean to change it.

To keep widget tests from hanging:

- Wrap `toImage()` and other real async work in `tester.runAsync()`.
- Don't use `pumpAndSettle()` with infinite animations.
- Don't cache a `Future` across `testWidgets` bodies: each body runs in its
  own FakeAsync zone, and awaiting a Future from an earlier test never resumes.
- `RepaintBoundary.toImage()` captures only its subtree; wrap content in a
  `ColoredBox` if you compare against an opaque reference.

## Before you open a pull request

```bash
dart format lib
flutter analyze
flutter test
```

CI (`.github/workflows/ci.yml`) runs the same checks, plus a publish dry-run,
web builds (dart2js and wasm) and a Linux build. Changes that touch `lib/` or
`test/` also run the W3C smoke suite; changes to `packages/quickjs_engine/`
run the native link checks on Android, macOS, Windows and iOS/macOS SwiftPM.

Add a test with your fix. For rendering bugs, a pixel check against the
expected output (see existing tests under `test/animation/`) is better than
asserting on internal state.
