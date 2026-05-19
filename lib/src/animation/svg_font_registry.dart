/// SVG-side adapter over the `woff2` package.
///
/// Historically this file owned the WOFF/WOFF2 decoder, `@font-face`
/// CSS parser, and Flutter `FontLoader` wiring. That code was extracted
/// into the standalone [`woff2`](https://pub.dev/packages/woff2)
/// package; this shim re-exports the same types under the names the
/// rest of the SVG renderer (and our public API) already use:
///
/// - [SvgFontLoader] is a typedef over `WoffSrcResolver` — kept for
///   backwards compatibility because it is re-exported from
///   `lib/src/animation.dart` as part of the full_svg_flutter public
///   API.
/// - [SvgFontRegistry] is a thin wrapper around `WoffFontRegistry`
///   that preserves the SVG-side `fontLoader:` parameter name (the
///   underlying package calls it `srcResolver:`).
/// - [CssFontFaceRule] and [extractFontFaceRules] are re-exported from
///   `woff2` unchanged.
library;

import 'package:flutter/services.dart' show Uint8List;
import 'package:woff2/woff2.dart' as woff2;

export 'package:woff2/woff2.dart' show CssFontFaceRule, extractFontFaceRules;

/// Callback to resolve external font bytes for a `@font-face` `src`
/// URL. Receives the raw `src` URL (e.g. a relative path like
/// `fonts/MyFont.ttf`) and returns the font bytes, or `null` if the
/// URL cannot be resolved.
typedef SvgFontLoader = Future<Uint8List?> Function(String href);

/// Registry for managing embedded SVG fonts — a thin adapter over the
/// `woff2` package's `WoffFontRegistry`.
///
/// Handles parsing `@font-face` rules, decoding base64-encoded font
/// data (including WOFF/WOFF2 → SFNT), and registering fonts with
/// Flutter's `FontLoader`.
class SvgFontRegistry {
  /// Creates a new font registry.
  SvgFontRegistry();

  final woff2.WoffFontRegistry _impl = woff2.WoffFontRegistry();

  /// Get the set of registered font family names.
  Set<String> get registeredFontFamilies => _impl.registeredFontFamilies;

  /// Get any errors encountered during font registration.
  List<String> get errors => _impl.errors;

  /// Check if a font family name is registered.
  bool isRegistered(String fontFamily) => _impl.isRegistered(fontFamily);

  /// Register fonts from a list of `@font-face` rules.
  ///
  /// [fontLoader] is an optional callback for resolving external font
  /// URLs (e.g. relative paths like `fonts/MyFont.ttf`). Without it,
  /// only embedded `data:` URLs are supported.
  Future<void> registerFonts(
    List<woff2.CssFontFaceRule> fontFaceRules, {
    SvgFontLoader? fontLoader,
  }) {
    return _impl.registerFonts(fontFaceRules, srcResolver: fontLoader);
  }

  /// Clears all registered fonts and state.
  /// Note: This doesn't unregister fonts from Flutter (not possible).
  void clear() => _impl.clear();
}
