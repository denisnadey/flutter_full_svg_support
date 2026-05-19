# Changelog

## 0.1.0 — initial release

First public release. The decoder and Flutter FontLoader wrapper
were extracted from
[`flutter_full_svg_support`](https://pub.dev/packages/full_svg_flutter),
where they have shipped since `v1.0.0` driving SVG `@font-face`
handling.

### Added

- `decodeFontIfWoff(Uint8List bytes)` — pure-Dart WOFF1 and WOFF2
  → SFNT (TTF/OTF) decoder. Implements the full W3C WOFF2 spec
  including `glyf`/`loca`/`hmtx` transformations.
- `loadWoffFontFromAsset({fontFamily, assetPath})` — one-call helper
  that loads a `.woff2` asset and registers it with Flutter's
  `FontLoader` so it works in `Text(...)` and `TextStyle`.
- `loadWoffFontFromBytes({fontFamily, bytes})` — the same, for bytes
  in memory (network, file system, runtime-generated).
- `WoffFontRegistry` — batch-registers multiple weight/style variants
  of one or more font families, typically from a parsed CSS file.
- `extractFontFaceRules(String cssText)` — minimal CSS `@font-face`
  parser that returns `CssFontFaceRule` value objects with
  `font-family`, `font-weight` (normalised to numeric), `font-style`,
  `src`, and `format`.

### Known limitations

- WOFF2 TTC collections are not supported (decoder returns
  `WoffDecodeResult.malformed`).
- Flutter Web is not a target platform — modern browsers handle
  `.woff2` natively via `@font-face` in CSS.
