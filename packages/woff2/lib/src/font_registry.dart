/// Flutter-side integration of the WOFF/WOFF2 decoder.
///
/// `WoffFontRegistry` registers WOFF/WOFF2 (and TTF/OTF) fonts with the
/// running Flutter app so they can be used in `Text(...)` widgets via
/// `TextStyle.fontFamily`. The registry parses `data:` URLs, calls a
/// caller-supplied resolver for `url(...)` references, and decodes WOFF /
/// WOFF2 bytes through [decodeFontIfWoff] before handing them to
/// Flutter's `FontLoader`.
///
/// For the common "I have one .woff2 in my assets and want to use it in
/// `Text(...)`" case, prefer the top-level [loadWoffFontFromAsset]
/// helper.
library;

import 'dart:convert';

import 'package:flutter/services.dart';

import 'font_face_rule.dart';
import 'woff_decoder.dart';

/// Callback used by [WoffFontRegistry] to resolve a `url(...)` reference
/// from a `@font-face` rule into the actual font bytes.
///
/// Receives the raw `src` value (typically a relative path such as
/// `fonts/MyFont.woff2`) and should return the font bytes, or `null` if
/// the URL cannot be resolved.
typedef WoffSrcResolver = Future<Uint8List?> Function(String src);

/// Registry for managing WOFF/WOFF2 (and TTF/OTF) fonts at runtime.
///
/// Use this when you have a batch of fonts to register — for example,
/// after parsing a CSS stylesheet's `@font-face` rules with
/// [extractFontFaceRules]:
///
/// ```dart
/// final registry = WoffFontRegistry();
/// final rules = extractFontFaceRules(cssText);
/// await registry.registerFonts(
///   rules,
///   srcResolver: (src) async => await rootBundle.load(src).then(
///     (b) => b.buffer.asUint8List(),
///   ),
/// );
/// // Now Text(..., style: TextStyle(fontFamily: 'MyFont')) works.
/// ```
///
/// For single-font use cases, see the simpler [loadWoffFontFromAsset]
/// helper.
class WoffFontRegistry {
  /// Creates a new font registry.
  WoffFontRegistry();

  final Set<String> _registeredFonts = <String>{};
  final Map<String, List<CssFontFaceRule>> _fontFaceRules =
      <String, List<CssFontFaceRule>>{};
  final List<String> _errors = <String>[];

  /// The set of font-family names successfully registered so far.
  Set<String> get registeredFontFamilies => Set.unmodifiable(_registeredFonts);

  /// Diagnostic messages produced during registration — malformed WOFF
  /// data, unsupported formats, resolver failures, etc.
  List<String> get errors => List.unmodifiable(_errors);

  /// Returns `true` if [fontFamily] has been registered with this
  /// registry. The comparison strips quotes and surrounding whitespace.
  bool isRegistered(String fontFamily) {
    return _registeredFonts.contains(_normalizeFontFamily(fontFamily));
  }

  /// Registers fonts from a list of `@font-face` rules.
  ///
  /// Rules sharing a `font-family` are grouped and registered as
  /// variants of a single Flutter font family. Pass a [srcResolver] if
  /// any rule uses a `url(...)` reference (relative path or http URL);
  /// without it, only `data:` URLs are loaded.
  Future<void> registerFonts(
    List<CssFontFaceRule> fontFaceRules, {
    WoffSrcResolver? srcResolver,
  }) async {
    final groupedRules = <String, List<CssFontFaceRule>>{};
    for (final rule in fontFaceRules) {
      final normalizedFamily = _normalizeFontFamily(rule.fontFamily);
      groupedRules.putIfAbsent(normalizedFamily, () => []).add(rule);
    }

    for (final entry in groupedRules.entries) {
      final fontFamily = entry.key;
      final rules = entry.value;

      if (_registeredFonts.contains(fontFamily)) {
        continue;
      }

      _fontFaceRules[fontFamily] = rules;
      await _registerFontFamily(fontFamily, rules, srcResolver: srcResolver);
    }
  }

  Future<void> _registerFontFamily(
    String fontFamily,
    List<CssFontFaceRule> rules, {
    WoffSrcResolver? srcResolver,
  }) async {
    final loader = FontLoader(fontFamily);
    var hasValidFonts = false;

    for (final rule in rules) {
      Uint8List? rawBytes;

      if (!rule.isEmbeddedFont) {
        if (srcResolver == null || rule.src == null) {
          _errors.add('Font "$fontFamily": External URLs not supported');
          continue;
        }
        try {
          rawBytes = await srcResolver(rule.src!);
          if (rawBytes == null) {
            _errors.add(
              'Font "$fontFamily": srcResolver returned null for "${rule.src}"',
            );
            continue;
          }
        } catch (e) {
          _errors.add(
            'Font "$fontFamily": Error loading font via srcResolver: $e',
          );
          continue;
        }
      } else {
        if (!rule.isSupportedFormat && !rule.isWoffFormat) {
          _errors.add(
            'Font "$fontFamily": Unsupported format ${rule.format ?? "unknown"}',
          );
          continue;
        }
        rawBytes = _decodeDataUrl(rule.src!);
        if (rawBytes == null) {
          _errors.add('Font "$fontFamily": Failed to decode data URL');
          continue;
        }
      }

      final (decodeResult, sfntBytes) = decodeFontIfWoff(rawBytes);
      switch (decodeResult) {
        case WoffDecodeResult.notWoff:
          loader.addFont(Future.value(ByteData.sublistView(rawBytes)));
          hasValidFonts = true;
        case WoffDecodeResult.ok:
          loader.addFont(Future.value(ByteData.sublistView(sfntBytes!)));
          hasValidFonts = true;
        case WoffDecodeResult.woff2Unsupported:
          _errors.add(
            'Font "$fontFamily": WOFF2 font is a TTC collection '
            '(not supported)',
          );
        case WoffDecodeResult.malformed:
          _errors.add('Font "$fontFamily": Malformed WOFF data');
      }
    }

    if (hasValidFonts) {
      try {
        await loader.load();
        _registeredFonts.add(fontFamily);
      } catch (e) {
        _errors.add('Font "$fontFamily": Error loading font: $e');
      }
    }
  }

  /// Clears registry bookkeeping. Note: Flutter does not expose a way to
  /// *unregister* fonts from the engine, so already-loaded glyphs remain
  /// available in the running app.
  void clear() {
    _registeredFonts.clear();
    _fontFaceRules.clear();
    _errors.clear();
  }

  static Uint8List? _decodeDataUrl(String dataUrl) {
    var url = dataUrl.trim();
    if (url.startsWith('url(') && url.endsWith(')')) {
      url = url.substring(4, url.length - 1).trim();
    }
    if ((url.startsWith('"') && url.endsWith('"')) ||
        (url.startsWith("'") && url.endsWith("'"))) {
      url = url.substring(1, url.length - 1);
    }

    if (!url.startsWith('data:')) {
      return null;
    }

    final commaIndex = url.indexOf(',');
    if (commaIndex == -1) {
      return null;
    }

    final metadata = url.substring(5, commaIndex).toLowerCase();
    if (!metadata.contains('base64')) {
      return null;
    }

    final base64Data = url.substring(commaIndex + 1);
    try {
      return base64.decode(base64Data);
    } catch (e) {
      return null;
    }
  }

  static String _normalizeFontFamily(String fontFamily) {
    var normalized = fontFamily.trim();

    normalized = normalized.replaceAll('&quot;', '"');
    normalized = normalized.replaceAll('&#34;', '"');
    normalized = normalized.replaceAll('&#x22;', '"');

    if ((normalized.startsWith('"') && normalized.endsWith('"')) ||
        (normalized.startsWith("'") && normalized.endsWith("'"))) {
      normalized = normalized.substring(1, normalized.length - 1);
    }

    return normalized.trim();
  }
}

/// Loads a single WOFF / WOFF2 / TTF / OTF font from an asset bundle and
/// registers it under [fontFamily] so it can be used in `Text(...)`
/// widgets.
///
/// This is the one-call helper for the typical
/// "I have `assets/fonts/Inter.woff2`, declared in `pubspec.yaml`, and I
/// want `Text('...', style: TextStyle(fontFamily: 'Inter'))` to work"
/// flow:
///
/// ```dart
/// await loadWoffFontFromAsset(
///   fontFamily: 'Inter',
///   assetPath: 'assets/fonts/Inter.woff2',
/// );
/// ```
///
/// The font format is auto-detected from the byte signature. WOFF1 and
/// WOFF2 are decoded to SFNT (TTF/OTF) before being passed to Flutter's
/// `FontLoader`; raw TTF/OTF bytes are forwarded unchanged.
///
/// Returns `true` on success, `false` if the bytes were unrecognised or
/// malformed.
Future<bool> loadWoffFontFromAsset({
  required String fontFamily,
  required String assetPath,
  AssetBundle? bundle,
}) async {
  final byteData = await (bundle ?? rootBundle).load(assetPath);
  return loadWoffFontFromBytes(
    fontFamily: fontFamily,
    bytes: byteData.buffer.asUint8List(
      byteData.offsetInBytes,
      byteData.lengthInBytes,
    ),
  );
}

/// Loads a single WOFF / WOFF2 / TTF / OTF font from raw [bytes] and
/// registers it under [fontFamily].
///
/// Use this when you already have the font bytes — fetched from network,
/// loaded from disk, or generated at runtime. For static assets bundled
/// with your app, prefer [loadWoffFontFromAsset].
///
/// Returns `true` on success, `false` if the bytes were unrecognised or
/// malformed.
Future<bool> loadWoffFontFromBytes({
  required String fontFamily,
  required Uint8List bytes,
}) async {
  final (decodeResult, sfntBytes) = decodeFontIfWoff(bytes);

  final Uint8List ttfBytes;
  switch (decodeResult) {
    case WoffDecodeResult.notWoff:
      ttfBytes = bytes;
    case WoffDecodeResult.ok:
      ttfBytes = sfntBytes!;
    case WoffDecodeResult.woff2Unsupported:
    case WoffDecodeResult.malformed:
      return false;
  }

  final loader = FontLoader(fontFamily);
  loader.addFont(Future.value(ByteData.sublistView(ttfBytes)));
  await loader.load();
  return true;
}
