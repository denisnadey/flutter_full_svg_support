/// Public API of the `woff2` package.
///
/// See the package README for a quick start. The three main entry points
/// are:
///
/// - [loadWoffFontFromAsset] — one-call helper for the typical
///   "bundle a `.woff2` in `assets/`, use it in `Text(...)`" case.
/// - [WoffFontRegistry] — batch-register multiple `@font-face`
///   variants (e.g. weight / style families) parsed from a CSS file.
/// - [decodeFontIfWoff] — low-level decoder for callers that just want
///   `WOFF` / `WOFF2` → `SFNT` bytes and will handle font loading
///   themselves.
library;

export 'src/font_face_rule.dart';
export 'src/font_registry.dart';
export 'src/woff_decoder.dart';
