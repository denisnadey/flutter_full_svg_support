/// SVG Font Registry for embedded @font-face font handling.
///
/// This module provides functionality to parse @font-face CSS rules,
/// decode embedded base64 font data, and register fonts with Flutter.
library;

import 'dart:convert';

import 'package:flutter/services.dart';

/// Callback to resolve external font bytes for a @font-face src URL.
///
/// Receives the raw src URL (e.g. a relative path like `fonts/MyFont.ttf`)
/// and should return the font bytes, or null if the URL cannot be resolved.
typedef SvgFontLoader = Future<Uint8List?> Function(String href);

/// Parsed @font-face rule containing font metadata and source.
class CssFontFaceRule {
  /// Creates a font-face rule.
  const CssFontFaceRule({
    required this.fontFamily,
    this.fontStyle = 'normal',
    this.fontWeight = '400',
    this.src,
    this.format,
  });

  /// The font-family name from @font-face rule.
  final String fontFamily;

  /// Font style: normal, italic, oblique.
  final String fontStyle;

  /// Font weight: 100-900 or keywords like normal, bold.
  final String fontWeight;

  /// The src URL (may be data: URL with embedded font).
  final String? src;

  /// The font format (truetype, woff, woff2, opentype).
  final String? format;

  /// Returns true if the src is a data: URL with embedded font data.
  bool get isEmbeddedFont =>
      src != null && src!.startsWith('data:font/') ||
      src != null && src!.startsWith('data:application/');

  /// Returns true if the font format is supported by Flutter.
  /// Flutter natively supports TTF and OTF.
  bool get isSupportedFormat {
    if (format == null) {
      // Try to detect from data URL
      if (src == null) return false;
      final srcLower = src!.toLowerCase();
      return srcLower.contains('font/ttf') ||
          srcLower.contains('font/truetype') ||
          srcLower.contains('font/otf') ||
          srcLower.contains('font/opentype') ||
          srcLower.contains('application/x-font-ttf') ||
          srcLower.contains('application/x-font-opentype');
    }
    final fmt = format!.toLowerCase();
    return fmt == 'truetype' || fmt == 'opentype';
  }

  /// Returns true if the font is WOFF/WOFF2 format (not natively supported).
  bool get isWoffFormat {
    if (format != null) {
      final fmt = format!.toLowerCase();
      return fmt == 'woff' || fmt == 'woff2';
    }
    if (src == null) return false;
    final srcLower = src!.toLowerCase();
    return srcLower.contains('font/woff') ||
        srcLower.contains('application/font-woff');
  }

  @override
  String toString() =>
      'CssFontFaceRule(fontFamily: $fontFamily, weight: $fontWeight, style: $fontStyle)';
}

/// Registry for managing embedded SVG fonts.
///
/// Handles parsing @font-face rules from CSS, decoding base64-encoded
/// font data, and registering fonts with Flutter's font loader.
class SvgFontRegistry {
  /// Creates a new font registry.
  SvgFontRegistry();

  /// Set of font family names that have been registered.
  final Set<String> _registeredFonts = <String>{};

  /// Map of font family names to their font face rules.
  final Map<String, List<CssFontFaceRule>> _fontFaceRules =
      <String, List<CssFontFaceRule>>{};

  /// Errors encountered during font registration.
  final List<String> _errors = <String>[];

  /// Get the set of registered font family names.
  Set<String> get registeredFontFamilies => Set.unmodifiable(_registeredFonts);

  /// Get any errors encountered during font registration.
  List<String> get errors => List.unmodifiable(_errors);

  /// Check if a font family name is registered.
  bool isRegistered(String fontFamily) {
    return _registeredFonts.contains(_normalizeFontFamily(fontFamily));
  }

  /// Register fonts from a list of @font-face rules.
  ///
  /// Returns a [Future] that completes when all fonts are registered.
  /// This should be called during SVG initialization, before rendering.
  ///
  /// [fontLoader] is an optional callback for resolving external font URLs
  /// (e.g. relative paths like `fonts/MyFont.ttf`). Without it, only
  /// embedded data: URLs are supported.
  Future<void> registerFonts(
    List<CssFontFaceRule> fontFaceRules, {
    SvgFontLoader? fontLoader,
  }) async {
    // Group rules by font family for batch registration
    final groupedRules = <String, List<CssFontFaceRule>>{};
    for (final rule in fontFaceRules) {
      final normalizedFamily = _normalizeFontFamily(rule.fontFamily);
      groupedRules.putIfAbsent(normalizedFamily, () => []).add(rule);
    }

    // Register each font family
    for (final entry in groupedRules.entries) {
      final fontFamily = entry.key;
      final rules = entry.value;

      // Skip if already registered
      if (_registeredFonts.contains(fontFamily)) {
        continue;
      }

      // Store the rules for reference
      _fontFaceRules[fontFamily] = rules;

      // Register with Flutter
      await _registerFontFamily(fontFamily, rules, fontLoader: fontLoader);
    }
  }

  /// Registers a font family with all its variants (weights/styles).
  Future<void> _registerFontFamily(
    String fontFamily,
    List<CssFontFaceRule> rules, {
    SvgFontLoader? fontLoader,
  }) async {
    final loader = FontLoader(fontFamily);
    var hasValidFonts = false;

    for (final rule in rules) {
      if (!rule.isEmbeddedFont) {
        if (fontLoader != null && rule.src != null) {
          final src = rule.src!;
          if (_isWoffByExtensionOrFormat(rule)) {
            _errors.add(
              'Font "$fontFamily": WOFF format not natively supported by Flutter',
            );
            continue;
          }
          try {
            final bytes = await fontLoader(src);
            if (bytes != null) {
              loader.addFont(Future.value(ByteData.sublistView(bytes)));
              hasValidFonts = true;
            } else {
              _errors.add(
                'Font "$fontFamily": fontLoader returned null for "$src"',
              );
            }
          } catch (e) {
            _errors.add(
              'Font "$fontFamily": Error loading font via fontLoader: $e',
            );
          }
        } else {
          _errors.add('Font "$fontFamily": External URLs not supported');
        }
        continue;
      }

      if (rule.isWoffFormat) {
        _errors.add(
          'Font "$fontFamily": WOFF format not natively supported by Flutter',
        );
        continue;
      }

      if (!rule.isSupportedFormat) {
        _errors.add(
          'Font "$fontFamily": Unsupported format ${rule.format ?? "unknown"}',
        );
        continue;
      }

      try {
        final fontData = _decodeDataUrl(rule.src!);
        if (fontData != null) {
          loader.addFont(Future.value(ByteData.sublistView(fontData)));
          hasValidFonts = true;
        } else {
          _errors.add('Font "$fontFamily": Failed to decode font data');
        }
      } catch (e) {
        _errors.add('Font "$fontFamily": Error decoding font: $e');
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

  bool _isWoffByExtensionOrFormat(CssFontFaceRule rule) {
    if (rule.format != null) {
      final fmt = rule.format!.toLowerCase();
      return fmt == 'woff' || fmt == 'woff2';
    }
    final src = rule.src;
    if (src == null) return false;
    final lower = src.toLowerCase();
    return lower.endsWith('.woff') || lower.endsWith('.woff2');
  }

  /// Decodes a data: URL to bytes.
  ///
  /// Supports: data:font/ttf;base64,... or data:font/ttf;charset=utf-8;base64,...
  Uint8List? _decodeDataUrl(String dataUrl) {
    // Remove 'url(' wrapper if present
    var url = dataUrl.trim();
    if (url.startsWith('url(') && url.endsWith(')')) {
      url = url.substring(4, url.length - 1).trim();
    }
    // Remove quotes if present
    if ((url.startsWith('"') && url.endsWith('"')) ||
        (url.startsWith("'") && url.endsWith("'"))) {
      url = url.substring(1, url.length - 1);
    }

    if (!url.startsWith('data:')) {
      return null;
    }

    // Find the base64 data after the comma
    final commaIndex = url.indexOf(',');
    if (commaIndex == -1) {
      return null;
    }

    // Check for base64 encoding
    final metadata = url.substring(5, commaIndex).toLowerCase();
    if (!metadata.contains('base64')) {
      return null; // Only base64 encoding supported
    }

    final base64Data = url.substring(commaIndex + 1);
    try {
      return base64.decode(base64Data);
    } catch (e) {
      return null;
    }
  }

  /// Normalizes a font family name by removing quotes and extra whitespace.
  String _normalizeFontFamily(String fontFamily) {
    var normalized = fontFamily.trim();

    // Handle HTML-encoded quotes (&quot;)
    normalized = normalized.replaceAll('&quot;', '"');
    normalized = normalized.replaceAll('&#34;', '"');
    normalized = normalized.replaceAll('&#x22;', '"');

    // Remove outer quotes
    if ((normalized.startsWith('"') && normalized.endsWith('"')) ||
        (normalized.startsWith("'") && normalized.endsWith("'"))) {
      normalized = normalized.substring(1, normalized.length - 1);
    }

    return normalized.trim();
  }

  /// Clears all registered fonts and state.
  /// Note: This doesn't unregister fonts from Flutter (not possible).
  void clear() {
    _registeredFonts.clear();
    _fontFaceRules.clear();
    _errors.clear();
  }
}

/// Extracts @font-face rules from CSS text.
///
/// Returns a list of [CssFontFaceRule] objects parsed from the CSS.
List<CssFontFaceRule> extractFontFaceRules(String cssText) {
  final rules = <CssFontFaceRule>[];

  // Match @font-face { ... } blocks
  final fontFaceRegex = RegExp(
    r'@font-face\s*\{([^}]+)\}',
    multiLine: true,
    caseSensitive: false,
  );

  final matches = fontFaceRegex.allMatches(cssText);

  for (final match in matches) {
    final body = match.group(1);
    if (body == null) continue;

    final rule = _parseFontFaceBody(body);
    if (rule != null) {
      rules.add(rule);
    }
  }

  return rules;
}

/// Parses the body of a @font-face rule.
CssFontFaceRule? _parseFontFaceBody(String body) {
  final properties = <String, String>{};

  // First, extract the src property specially because it may contain semicolons
  // in data URLs like "data:font/ttf;charset=utf-8;base64,..."
  final srcMatch = RegExp(
    r'src\s*:\s*(url\s*\([^)]+\)(?:\s*format\s*\([^)]+\))?)',
    caseSensitive: false,
  ).firstMatch(body);
  if (srcMatch != null) {
    properties['src'] = srcMatch.group(1)!.trim();
  }

  // For other properties, use simple parsing (split by semicolon is safe)
  // Only match simple properties like font-family: 'name'
  final simpleProps = <String>['font-family', 'font-style', 'font-weight'];
  for (final propName in simpleProps) {
    final propMatch = RegExp(
      '$propName\\s*:\\s*([^;]+)',
      caseSensitive: false,
    ).firstMatch(body);
    if (propMatch != null) {
      properties[propName] = propMatch.group(1)!.trim();
    }
  }

  // font-family is required
  final fontFamily = _extractFontFamily(properties['font-family']);
  if (fontFamily == null) return null;

  // Parse src
  final src = _extractSrc(properties['src']);

  // Parse format from src
  final format = _extractFormat(properties['src']);

  return CssFontFaceRule(
    fontFamily: fontFamily,
    fontStyle: properties['font-style']?.toLowerCase() ?? 'normal',
    fontWeight: _normalizeFontWeight(properties['font-weight']),
    src: src,
    format: format,
  );
}

/// Extracts the font family name from a CSS value.
String? _extractFontFamily(String? value) {
  if (value == null) return null;

  var family = value.trim();

  // Handle HTML-encoded quotes
  family = family.replaceAll('&quot;', '"');
  family = family.replaceAll('&#34;', '"');
  family = family.replaceAll('&#x22;', '"');

  // Remove quotes
  if ((family.startsWith('"') && family.endsWith('"')) ||
      (family.startsWith("'") && family.endsWith("'"))) {
    family = family.substring(1, family.length - 1);
  }

  return family.isEmpty ? null : family;
}

/// Extracts the src URL from a CSS src property.
String? _extractSrc(String? value) {
  if (value == null) return null;

  // Try pattern 1: url('...') or url("...") - with quotes
  final quotedUrlRegex = RegExp(r'''url\s*\(\s*['"]([^'"]+)['"]\s*\)''');
  var match = quotedUrlRegex.firstMatch(value);
  if (match != null) {
    return match.group(1)?.trim();
  }

  // Try pattern 2: url(...) without quotes - capture until )
  final unquotedUrlRegex = RegExp(r'url\s*\(\s*([^)]+)\)');
  match = unquotedUrlRegex.firstMatch(value);
  if (match != null) {
    return match.group(1)?.trim();
  }

  return null;
}

/// Extracts the format from a CSS src property.
String? _extractFormat(String? value) {
  if (value == null) return null;

  // Match format('...')
  final formatRegex = RegExp(r'''format\s*\(\s*(['"])([^'"]+)\1\s*\)''');
  final match = formatRegex.firstMatch(value);
  return match?.group(2)?.trim();
}

/// Normalizes a font-weight value to numeric string.
String _normalizeFontWeight(String? value) {
  if (value == null) return '400';

  final normalized = value.toLowerCase().trim();

  switch (normalized) {
    case 'normal':
      return '400';
    case 'bold':
      return '700';
    case 'lighter':
      return '300';
    case 'bolder':
      return '700';
    default:
      // Try to parse as number
      final parsed = int.tryParse(normalized);
      if (parsed != null && parsed >= 100 && parsed <= 900) {
        return normalized;
      }
      return '400';
  }
}
