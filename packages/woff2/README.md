# woff2

**WOFF and WOFF2 font support for Flutter.** Use `.woff2` / `.woff`
web-font files directly in your Flutter app, the same way you would
use a `.ttf` or `.otf` — in `Text(...)`, `TextStyle(fontFamily: ...)`,
themes, and `Material` widgets.

[![pub package](https://img.shields.io/pub/v/woff2.svg)](https://pub.dev/packages/woff2)
[![license](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)

> ### Why this package?
>
> **Flutter's `FontLoader` only accepts uncompressed SFNT (TTF/OTF)**.
> If you try to load a `.woff2` file via `FontLoader.addFont(...)` and
> use it in `Text(...)`, the glyphs render as `□ □ □` (tofu) — the
> engine silently rejects the unsupported container. There's no
> built-in WOFF/WOFF2 decoder in Dart or Flutter.
>
> This package is the missing piece. It decodes WOFF1 and WOFF2 in
> pure Dart, then hands the resulting TTF/OTF bytes to Flutter's
> `FontLoader` for you. Drop in your `.woff2` file, call one function,
> and `Text(..., style: TextStyle(fontFamily: 'YourFont'))` just works.

## Features

- 🅰️ **One-call asset loader** — `loadWoffFontFromAsset(...)` takes
  a `font-family` name and an asset path, and you're done.
- 🗜️ **Decodes WOFF1 and WOFF2** to SFNT (TTF/OTF) entirely in Dart.
  WOFF1 uses `dart:io`'s zlib; WOFF2 uses Brotli decompression and
  implements the full W3C `glyf` / `loca` / `hmtx` transformations.
- 🎨 **Use in `Text`, `TextStyle`, `ThemeData`** — once registered, the
  font is a normal Flutter font family. Works with Material 3 themes,
  custom widgets, anything that takes a `fontFamily` string.
- 📰 **`@font-face` CSS parser** — extract `font-family`, `font-weight`,
  `font-style`, `src`, and `format` from a CSS string. Useful for
  SVG, HTML, and EPUB renderers that bundle styles with their content.
- 📦 **Batch-register** multiple weights/styles of the same family
  using `WoffFontRegistry`.
- 🌐 **Embedded `data:` URL fonts** — `data:font/woff2;base64,...`
  works out of the box.
- 🪶 **No native plugins, no FFI for your app code.** The package is
  pure Dart (Brotli native lib is bundled by the `es_compression`
  dependency).
- 🧪 **Tested** — 35 unit tests covering round-trip encoding for both
  WOFF1 (raw + zlib) and WOFF2 (Brotli, non-transformed), plus edge
  cases (malformed headers, truncated input, TTC collections).

## Install

```yaml
dependencies:
  woff2: ^0.1.0
```

```dart
import 'package:woff2/woff2.dart';
```

## Quick start

The most common case: you have a `.woff2` in `assets/fonts/`, you want
to use it in a `Text` widget.

### 1. Declare the asset

`pubspec.yaml`:

```yaml
flutter:
  assets:
    - assets/fonts/Inter.woff2
```

> **Note**: do **not** put it under `flutter: fonts:` — that key is for
> Flutter's built-in TTF/OTF loader, which won't accept WOFF/WOFF2.
> List it as a regular `assets:` entry instead.

### 2. Load the font at app start

```dart
import 'package:flutter/material.dart';
import 'package:woff2/woff2.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await loadWoffFontFromAsset(
    fontFamily: 'Inter',
    assetPath: 'assets/fonts/Inter.woff2',
  );

  runApp(const MyApp());
}
```

### 3. Use it like any Flutter font

```dart
Text(
  'Hello, WOFF2!',
  style: TextStyle(fontFamily: 'Inter', fontSize: 24),
)
```

That's it.

## Loading from bytes (network, file system, RAM)

When you already have the font bytes — fetched over HTTP, read from
`getApplicationDocumentsDirectory()`, or built at runtime:

```dart
final response = await http.get(Uri.parse('https://example.com/font.woff2'));
await loadWoffFontFromBytes(
  fontFamily: 'Remote',
  bytes: response.bodyBytes,
);
```

## Multiple weights and styles

Use `WoffFontRegistry` for batch registration, typically when the
variants come from a CSS stylesheet:

```dart
final registry = WoffFontRegistry();

await registry.registerFonts(
  [
    const CssFontFaceRule(
      fontFamily: 'Inter',
      fontWeight: '400',
      src: 'fonts/Inter-Regular.woff2',
      format: 'woff2',
    ),
    const CssFontFaceRule(
      fontFamily: 'Inter',
      fontWeight: '700',
      src: 'fonts/Inter-Bold.woff2',
      format: 'woff2',
    ),
  ],
  srcResolver: (src) async {
    final data = await rootBundle.load('assets/$src');
    return data.buffer.asUint8List();
  },
);

if (registry.errors.isNotEmpty) {
  debugPrint('Font errors: ${registry.errors}');
}
```

## Parsing `@font-face` blocks from CSS

If you have CSS text — extracted from a `<style>` tag in an SVG, an
embedded HTML email, an EPUB stylesheet, etc. — pass it through
`extractFontFaceRules`:

```dart
const css = '''
@font-face {
  font-family: 'Inter';
  font-weight: 400;
  src: url('fonts/Inter.woff2') format('woff2');
}
''';

final rules = extractFontFaceRules(css);
await registry.registerFonts(rules, srcResolver: ...);
```

The parser handles the awkward bits:

- `data:` URLs with embedded semicolons (`data:font/ttf;charset=utf-8;base64,...`)
- HTML-encoded quotes inside `font-family` (`&quot;My Font&quot;`)
- Keyword `font-weight` values (`normal`, `bold`, `lighter`, `bolder`)
- Single- and double-quoted strings
- `url(...)` with and without quotes

## Embedded `data:` URL fonts

Need to ship a font without a separate asset file? Use a `data:` URL
in your `CssFontFaceRule`:

```dart
const rule = CssFontFaceRule(
  fontFamily: 'Inline',
  src: 'data:font/woff2;base64,d09GMgABAAAAAAo...',
  format: 'woff2',
);
await registry.registerFonts([rule]);
```

## Low-level decoder

If you don't need the Flutter wiring — for example you're writing your
own font pipeline or doing offline conversion — call the decoder
directly:

```dart
import 'package:woff2/woff2.dart';

final (result, sfntBytes) = decodeFontIfWoff(bytes);
switch (result) {
  case WoffDecodeResult.notWoff:
    // Input was plain TTF/OTF — use `bytes` as-is.
  case WoffDecodeResult.ok:
    // `sfntBytes` is non-null, ready for any SFNT consumer.
  case WoffDecodeResult.woff2Unsupported:
    // WOFF2 TTC collection — see Limitations below.
  case WoffDecodeResult.malformed:
    // Bad input.
}
```

## API reference

| Symbol                       | Purpose                                                          |
| ---------------------------- | ---------------------------------------------------------------- |
| `loadWoffFontFromAsset`      | One-call helper: bundled `.woff2` asset → `TextStyle.fontFamily` |
| `loadWoffFontFromBytes`      | Same, but from raw bytes                                          |
| `WoffFontRegistry`           | Batch registration with weight/style variants                     |
| `CssFontFaceRule`            | Value object for a parsed `@font-face` block                      |
| `extractFontFaceRules`       | Pull all `@font-face` rules out of a CSS string                   |
| `WoffSrcResolver`            | Callback used by the registry to fetch `url(...)` bytes           |
| `decodeFontIfWoff`           | Low-level: `Uint8List` → `(WoffDecodeResult, Uint8List?)`         |
| `WoffDecodeResult`           | `notWoff`, `ok`, `woff2Unsupported`, `malformed`                  |

## Limitations

- **WOFF2 collections (TTC) are not supported.** A `.woff2` whose
  `flavor` field is `'ttcf'` will be reported as
  `WoffDecodeResult.malformed`. TTC support requires reconstructing
  multiple sub-fonts from one shared `glyf` stream and is a
  follow-up item.
- **Web platform:** the underlying Brotli decoder (from
  `es_compression`) is FFI-based, which means this package runs on
  Android, iOS, macOS, Linux, and Windows — but not Flutter Web.
  On the web, your browser already understands `.woff2` natively, so
  you don't need this package there; use the standard `@font-face`
  CSS in `web/index.html` instead.
- **Variable fonts** (with `fvar` / `gvar` tables) decode correctly
  on the SFNT level, but Flutter's `FontLoader` doesn't currently
  expose the variable axes to widget styling. The font will load and
  use its default named instance.

## Tested platforms

The decoder is tested with self-contained round-trip suites:

- WOFF1 with **raw** tables (`compLength == origLength`)
- WOFF1 with **zlib-compressed** tables
- WOFF2 with **non-transformed** tables (full glyf/loca/hmtx
  transformations are exercised by integration tests in the parent
  monorepo against real font files)

```text
$ flutter test
00:01 +35: All tests passed!
```

## Related packages

This package was extracted from
[**flutter_full_svg_support**][svg], a Flutter renderer for animated
SVGs that needed reliable WOFF/WOFF2 decoding to handle `@font-face`
rules inside SVG files. If you're rendering SVGs that ship their own
fonts, you already get this package transitively.

The same monorepo also ships [**quickjs_engine**][qjs] — a modern
QuickJS-NG JavaScript runtime for Flutter — if you need bundled JS
execution.

[svg]: https://pub.dev/packages/full_svg_flutter
[qjs]: https://pub.dev/packages/quickjs_engine

## Contributing

Bugs and PRs welcome at
[github.com/denisnadey/flutter_full_svg_support][repo]. The package
source lives at `packages/woff2/` in that monorepo.

[repo]: https://github.com/denisnadey/flutter_full_svg_support

## License

Apache License 2.0 — see [LICENSE](LICENSE).

---

<sub>**Keywords**: Flutter WOFF, Flutter WOFF2, Flutter web fonts,
load WOFF2 in Flutter, decode WOFF2 Dart, Flutter custom fonts
WOFF2, `@font-face` Flutter, FontLoader WOFF, Flutter TTF from WOFF,
Brotli font decoder Dart.</sub>
