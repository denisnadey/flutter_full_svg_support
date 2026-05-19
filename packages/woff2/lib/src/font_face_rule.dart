/// CSS `@font-face` rule parsing.
///
/// A lightweight, regex-based parser that pulls out the fields needed to
/// load fonts at runtime: `font-family`, `font-style`, `font-weight`,
/// `src` (including `data:` URLs and `url()` references), and the
/// `format(...)` hint.
///
/// Not a full CSS parser. It's intentionally narrow because the goal is
/// font loading, not CSS validation — but it tolerates the long
/// `data:font/ttf;charset=utf-8;base64,...` URL form whose embedded
/// semicolons break naive split-by-`;` strategies.
library;

/// Parsed `@font-face` rule containing font metadata and source.
class CssFontFaceRule {
  /// Creates a font-face rule.
  const CssFontFaceRule({
    required this.fontFamily,
    this.fontStyle = 'normal',
    this.fontWeight = '400',
    this.src,
    this.format,
  });

  /// The `font-family` name (with quotes stripped).
  final String fontFamily;

  /// `font-style`: `normal`, `italic`, or `oblique`. Defaults to `normal`.
  final String fontStyle;

  /// `font-weight` as a numeric string `100`–`900`. Keywords `normal`,
  /// `bold`, `lighter`, `bolder` are normalised to numbers. Defaults to
  /// `400`.
  final String fontWeight;

  /// The `src` URL — either a `data:` URL with embedded font data, or a
  /// `url(...)` reference like `fonts/MyFont.woff2`.
  final String? src;

  /// The `format(...)` hint from the `src` property, e.g.
  /// `woff2`, `woff`, `truetype`, `opentype`. May be `null` when omitted.
  final String? format;

  /// True if [src] is a `data:` URL with embedded font bytes.
  bool get isEmbeddedFont =>
      src != null && src!.startsWith('data:font/') ||
      src != null && src!.startsWith('data:application/');

  /// True if the format is one Flutter's `FontLoader` accepts directly
  /// (TrueType / OpenType). WOFF and WOFF2 are not native-accepted by
  /// Flutter and need decoding first — see [isWoffFormat].
  bool get isSupportedFormat {
    if (format == null) {
      // Try to detect from data URL.
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

  /// True if the format is WOFF or WOFF2 — Flutter won't accept these
  /// directly, decode them via `decodeFontIfWoff` first.
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

/// Extracts every `@font-face { ... }` rule from a CSS text blob.
///
/// Returns a list of [CssFontFaceRule] objects, one per `@font-face`
/// block. Rules that fail to parse (e.g. missing `font-family`) are
/// skipped silently.
List<CssFontFaceRule> extractFontFaceRules(String cssText) {
  final rules = <CssFontFaceRule>[];

  final fontFaceRegex = RegExp(
    r'@font-face\s*\{([^}]+)\}',
    multiLine: true,
    caseSensitive: false,
  );

  for (final match in fontFaceRegex.allMatches(cssText)) {
    final body = match.group(1);
    if (body == null) continue;

    final rule = _parseFontFaceBody(body);
    if (rule != null) {
      rules.add(rule);
    }
  }

  return rules;
}

CssFontFaceRule? _parseFontFaceBody(String body) {
  // Decode the few HTML entities that the CSS commonly carries when
  // embedded inside SVG/HTML. We do this before the regex passes
  // because `&quot;` contains a literal `;`, which would otherwise
  // truncate the `font-family` value when we split simple properties
  // by semicolon below.
  final decodedBody = body
      .replaceAll('&quot;', '"')
      .replaceAll('&#34;', '"')
      .replaceAll('&#x22;', '"');

  final properties = <String, String>{};

  // Extract `src` first — its value may contain semicolons inside a
  // `data:` URL, which a generic split-by-`;` would mishandle.
  final srcMatch = RegExp(
    r'src\s*:\s*(url\s*\([^)]+\)(?:\s*format\s*\([^)]+\))?)',
    caseSensitive: false,
  ).firstMatch(decodedBody);
  if (srcMatch != null) {
    properties['src'] = srcMatch.group(1)!.trim();
  }

  const simpleProps = <String>['font-family', 'font-style', 'font-weight'];
  for (final propName in simpleProps) {
    final propMatch = RegExp(
      '$propName\\s*:\\s*([^;]+)',
      caseSensitive: false,
    ).firstMatch(decodedBody);
    if (propMatch != null) {
      properties[propName] = propMatch.group(1)!.trim();
    }
  }

  final fontFamily = _extractFontFamily(properties['font-family']);
  if (fontFamily == null) return null;

  final src = _extractSrc(properties['src']);
  final format = _extractFormat(properties['src']);

  return CssFontFaceRule(
    fontFamily: fontFamily,
    fontStyle: properties['font-style']?.toLowerCase() ?? 'normal',
    fontWeight: _normalizeFontWeight(properties['font-weight']),
    src: src,
    format: format,
  );
}

String? _extractFontFamily(String? value) {
  if (value == null) return null;

  var family = value.trim();

  family = family.replaceAll('&quot;', '"');
  family = family.replaceAll('&#34;', '"');
  family = family.replaceAll('&#x22;', '"');

  if ((family.startsWith('"') && family.endsWith('"')) ||
      (family.startsWith("'") && family.endsWith("'"))) {
    family = family.substring(1, family.length - 1);
  }

  return family.isEmpty ? null : family;
}

String? _extractSrc(String? value) {
  if (value == null) return null;

  final quotedUrlRegex = RegExp(r'''url\s*\(\s*['"]([^'"]+)['"]\s*\)''');
  var match = quotedUrlRegex.firstMatch(value);
  if (match != null) {
    return match.group(1)?.trim();
  }

  final unquotedUrlRegex = RegExp(r'url\s*\(\s*([^)]+)\)');
  match = unquotedUrlRegex.firstMatch(value);
  if (match != null) {
    return match.group(1)?.trim();
  }

  return null;
}

String? _extractFormat(String? value) {
  if (value == null) return null;

  final formatRegex = RegExp(r'''format\s*\(\s*(['"])([^'"]+)\1\s*\)''');
  final match = formatRegex.firstMatch(value);
  return match?.group(2)?.trim();
}

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
      final parsed = int.tryParse(normalized);
      if (parsed != null && parsed >= 100 && parsed <= 900) {
        return normalized;
      }
      return '400';
  }
}
