part of 'animated_svg_painter.dart';

/// Result of parsing a font-family CSS value into primary font and fallbacks.
///
/// Used to properly construct Flutter TextStyle with fontFamily and
/// fontFamilyFallback properties for correct font fallback behavior.
class FontFallbackResult {
  /// Creates a font fallback result.
  const FontFallbackResult({
    this.primaryFont,
    this.fallbackFonts = const <String>[],
  });

  /// The primary font family to use (first in the chain).
  ///
  /// This should be used as the `fontFamily` property in TextStyle.
  final String? primaryFont;

  /// The list of fallback font families in priority order.
  ///
  /// This should be used as the `fontFamilyFallback` property in TextStyle.
  final List<String> fallbackFonts;

  /// Whether this result has any fonts specified.
  bool get isEmpty => primaryFont == null && fallbackFonts.isEmpty;

  /// Whether this result has fonts specified.
  bool get isNotEmpty => !isEmpty;

  /// Returns all fonts as a single list (primary first, then fallbacks).
  List<String> toFontList() {
    if (primaryFont == null) return List<String>.unmodifiable(fallbackFonts);
    return List<String>.unmodifiable(<String>[primaryFont!, ...fallbackFonts]);
  }

  @override
  String toString() {
    if (isEmpty) return 'FontFallbackResult(empty)';
    return 'FontFallbackResult(primary: $primaryFont, fallbacks: $fallbackFonts)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! FontFallbackResult) return false;
    return primaryFont == other.primaryFont &&
        _listEquals(fallbackFonts, other.fallbackFonts);
  }

  @override
  int get hashCode => Object.hash(primaryFont, Object.hashAll(fallbackFonts));

  static bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Font property resolvers for SVG text styling.
///
/// Contains resolver methods for font-related CSS properties:
/// - font-variant, font-stretch, font-size-adjust, font-kerning
/// - font-optical-sizing, font-synthesis
/// - font-variant-* properties
/// - font-family parsing with fallback chains
/// - Complex font fallback with platform-specific resolution
///
/// Note: _resolveFontWeight and _resolveFontStyle are defined in
/// animated_svg_painter_values.dart and shared across extensions.
extension AnimatedSvgPainterTextStyleFontExtension on AnimatedSvgPainter {
  /// Resolves font-family CSS property with support for complex fallback chains.
  ///
  /// Parses the font-family property which can contain:
  /// - Multiple comma-separated font names
  /// - Quoted font names (e.g., "Helvetica Neue", 'Open Sans')
  /// - Generic family names (serif, sans-serif, monospace, cursive, fantasy, system-ui)
  ///
  /// For embedded fonts (registered via @font-face), the font family is used
  /// directly without fallback expansion. For other fonts, the fallback chain
  /// works as follows:
  /// 1. Try each font in order until one is available
  /// 2. Generic families are mapped to platform-specific defaults
  /// 3. Maintains metrics consistency by preferring fonts with similar x-heights
  ///
  /// Returns the parsed font family string suitable for Flutter's TextStyle.
  /// Flutter handles the fallback chain automatically with this comma-separated list.
  String? _resolveFontFamily(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    // Handle HTML-encoded quotes (&quot;)
    var processedValue = value;
    processedValue = processedValue.replaceAll('&quot;', '"');
    processedValue = processedValue.replaceAll('&#34;', '"');
    processedValue = processedValue.replaceAll('&#x22;', '"');

    final families = <String>[];
    final buffer = StringBuffer();
    var inQuotes = false;
    var quoteChar = '';

    for (var i = 0; i < processedValue.length; i++) {
      final char = processedValue[i];

      if (!inQuotes && (char == '"' || char == "'")) {
        inQuotes = true;
        quoteChar = char;
        continue;
      }

      if (inQuotes && char == quoteChar) {
        inQuotes = false;
        quoteChar = '';
        continue;
      }

      if (!inQuotes && char == ',') {
        final family = buffer.toString().trim();
        if (family.isNotEmpty) {
          final resolved = _resolveAndExpandFontFamily(family);
          families.addAll(resolved);
        }
        buffer.clear();
        continue;
      }

      buffer.write(char);
    }

    // Handle last family
    final lastFamily = buffer.toString().trim();
    if (lastFamily.isNotEmpty) {
      final resolved = _resolveAndExpandFontFamily(lastFamily);
      families.addAll(resolved);
    }

    if (families.isEmpty) {
      return null;
    }

    // Remove duplicates while preserving order
    final seen = <String>{};
    final uniqueFamilies = families
        .where((f) => seen.add(f.toLowerCase()))
        .toList();

    return uniqueFamilies.join(', ');
  }

  /// Resolves a single font family and expands to fallback variants.
  ///
  /// For registered fonts (embedded via @font-face), returns the font name
  /// directly without fallback expansion. For generic families, returns
  /// platform-specific font stacks. For specific fonts, adds metric-compatible
  /// fallbacks.
  List<String> _resolveAndExpandFontFamily(String family) {
    // Normalize the family name
    var normalized = family.trim();

    // Handle HTML-encoded quotes
    normalized = normalized.replaceAll('&quot;', '"');
    normalized = normalized.replaceAll('&#34;', '"');
    normalized = normalized.replaceAll('&#x22;', '"');

    // Remove outer quotes
    if ((normalized.startsWith('"') && normalized.endsWith('"')) ||
        (normalized.startsWith("'") && normalized.endsWith("'"))) {
      normalized = normalized.substring(1, normalized.length - 1);
    }

    // Check if this font is registered via @font-face
    if (document.isFontRegistered(normalized)) {
      // Use registered font directly without fallback expansion
      return <String>[normalized];
    }

    final normalizedLower = normalized.toLowerCase();

    switch (normalizedLower) {
      case 'serif':
      case 'ui-serif':
        // Platform-aware serif stack with metric compatibility
        return <String>[
          'Georgia',
          'Cambria',
          'Times New Roman',
          'Times',
          'serif',
        ];
      case 'sans-serif':
      case 'ui-sans-serif':
        // Platform-aware sans-serif stack
        return <String>[
          'Roboto',
          'Segoe UI',
          'Helvetica Neue',
          'Helvetica',
          'Arial',
          'sans-serif',
        ];
      case 'monospace':
      case 'ui-monospace':
        // Monospace stack with similar metrics
        return <String>[
          'Roboto Mono',
          'SF Mono',
          'Consolas',
          'Monaco',
          'Courier New',
          'monospace',
        ];
      case 'cursive':
        return <String>['Brush Script MT', 'Segoe Script', 'cursive'];
      case 'fantasy':
        return <String>['Papyrus', 'Impact', 'fantasy'];
      case 'system-ui':
      case '-apple-system':
      case 'blinkmacsystemfont':
        // System UI fonts for each platform
        return <String>[
          'Roboto',
          'Segoe UI',
          '-apple-system',
          'BlinkMacSystemFont',
          'sans-serif',
        ];
      case 'ui-rounded':
        return <String>[
          'SF Pro Rounded',
          'Nunito',
          'Varela Round',
          'sans-serif',
        ];
      case 'math':
        // Fonts suitable for mathematical typesetting
        return <String>[
          'Cambria Math',
          'STIX Two Math',
          'Latin Modern Math',
          'serif',
        ];
      case 'emoji':
        // Emoji fonts
        return <String>[
          'Apple Color Emoji',
          'Segoe UI Emoji',
          'Noto Color Emoji',
          normalized,
        ];
      default:
        // Keep original family name (normalized, without quotes)
        return <String>[normalized];
    }
  }

  /// Resolves font-feature-settings CSS property.
  ///
  /// Parses the CSS font-feature-settings property and returns a list
  /// of Flutter FontFeatures. Supports:
  /// - Four-letter OpenType feature tags: 'liga', 'kern', 'smcp', etc.
  /// - Feature values: 'kern' 1, 'liga' on/off, 'ss01' 2
  ///
  /// Example: 'kern' 1, 'liga' off, 'smcp' on
  ///
  /// Gracefully handles unsupported features - Flutter's text engine will
  /// simply ignore features the font doesn't support, so we pass them through
  /// without validation. This ensures correct width calculations match
  /// actual rendered output.
  List<ui.FontFeature> _resolveFontFeatureSettings(String? value) {
    if (value == null ||
        value.trim().isEmpty ||
        value.trim().toLowerCase() == 'normal') {
      return const <ui.FontFeature>[];
    }

    final features = <ui.FontFeature>[];
    final settings = value.split(',');

    for (final setting in settings) {
      final trimmed = setting.trim();
      if (trimmed.isEmpty) continue;

      // Parse feature tag and value
      // Format: "'tag'" or "'tag' value" or '"tag" value'
      final match = RegExp(
        r'''['"]([a-zA-Z0-9]{4})['"](?:\s+(\d+|on|off))?''',
      ).firstMatch(trimmed);

      if (match != null) {
        final tag = match.group(1)!;
        final valueStr = match.group(2);

        int featureValue = 1; // Default is enabled
        if (valueStr != null) {
          if (valueStr.toLowerCase() == 'off') {
            featureValue = 0;
          } else if (valueStr.toLowerCase() == 'on') {
            featureValue = 1;
          } else {
            featureValue = int.tryParse(valueStr) ?? 1;
          }
        }

        // Add feature regardless of whether font supports it.
        // Flutter's text engine gracefully ignores unsupported features,
        // and by passing them through we ensure our metrics match actual
        // rendered output (no crash, correct fallback behavior).
        features.add(ui.FontFeature(tag, featureValue));
      }
    }

    return features;
  }

  /// Generates a hash string representing the font features list.
  ///
  /// This is used for cache key generation to ensure that paragraphs with
  /// different font-feature-settings produce different cache entries.
  /// Critical for proper rendering of tabular vs proportional numerals,
  /// ligature variations, etc.
  String _fontFeaturesHashKey(List<ui.FontFeature> features) {
    if (features.isEmpty) return 'ff:none';
    // Sort features by tag for consistent cache keys regardless of order
    final sortedFeatures = List<ui.FontFeature>.from(features)
      ..sort((a, b) => a.feature.compareTo(b.feature));
    return 'ff:${sortedFeatures.map((f) => '${f.feature}=${f.value}').join('|')}';
  }

  /// Checks if two lists of font features are compatible for ligature shaping.
  ///
  /// When text spans across multiple tspans with different styles, ligatures
  /// (like "fi", "fl", "ffi") can only form if the ligature-related features
  /// are compatible between adjacent runs.
  ///
  /// Returns true if adjacent runs can share ligature shaping.
  bool _areLigatureFeaturesCompatible(
    List<ui.FontFeature> features1,
    List<ui.FontFeature> features2,
  ) {
    // Ligature-related feature tags
    const ligatureFeatures = <String>{
      'liga', // Standard ligatures
      'clig', // Contextual ligatures
      'dlig', // Discretionary ligatures
      'hlig', // Historical ligatures
      'calt', // Contextual alternates
    };

    // Extract ligature features from each list
    final ligatures1 = <String, int>{};
    final ligatures2 = <String, int>{};

    for (final f in features1) {
      if (ligatureFeatures.contains(f.feature)) {
        ligatures1[f.feature] = f.value;
      }
    }

    for (final f in features2) {
      if (ligatureFeatures.contains(f.feature)) {
        ligatures2[f.feature] = f.value;
      }
    }

    // For each ligature feature present in either list, check if values match
    final allTags = <String>{...ligatures1.keys, ...ligatures2.keys};
    for (final tag in allTags) {
      // Default is enabled (1) if not explicitly set
      final value1 = ligatures1[tag] ?? 1;
      final value2 = ligatures2[tag] ?? 1;
      if (value1 != value2) {
        return false;
      }
    }

    return true;
  }

  /// Checks if two font feature lists have the same numeric figure settings.
  ///
  /// This is important for cache key generation to ensure that text with
  /// different numeral styles (tabular vs proportional, lining vs oldstyle)
  /// produces correctly sized glyphs.
  // ignore: unused_element
  bool _areNumericFeaturesIdentical(
    List<ui.FontFeature> features1,
    List<ui.FontFeature> features2,
  ) {
    // Numeric-related feature tags that affect glyph width
    const numericFeatures = <String>{
      'tnum', // Tabular figures
      'pnum', // Proportional figures
      'lnum', // Lining figures
      'onum', // Oldstyle figures
      'zero', // Slashed zero
      'ordn', // Ordinals
      'frac', // Fractions
      'afrc', // Alternative fractions
    };

    final numerics1 = <String, int>{};
    final numerics2 = <String, int>{};

    for (final f in features1) {
      if (numericFeatures.contains(f.feature)) {
        numerics1[f.feature] = f.value;
      }
    }

    for (final f in features2) {
      if (numericFeatures.contains(f.feature)) {
        numerics2[f.feature] = f.value;
      }
    }

    // Must have identical sets of numeric features with same values
    if (numerics1.length != numerics2.length) return false;
    for (final entry in numerics1.entries) {
      if (numerics2[entry.key] != entry.value) return false;
    }
    return true;
  }

  /// Resolves font-variant CSS property to Flutter FontFeatures.
  /// Supports: normal, small-caps, all-small-caps, petite-caps, all-petite-caps,
  /// unicase, titling-caps
  List<ui.FontFeature> _resolveFontVariant(String? value) {
    if (value == null || value.trim().isEmpty || value.trim() == 'normal') {
      return const <ui.FontFeature>[];
    }

    final features = <ui.FontFeature>[];
    final parts = value.toLowerCase().split(RegExp(r'\s+'));

    for (final part in parts) {
      switch (part.trim()) {
        case 'small-caps':
          features.add(const ui.FontFeature.enable('smcp'));
          break;
        case 'all-small-caps':
          features.add(const ui.FontFeature.enable('smcp'));
          features.add(const ui.FontFeature.enable('c2sc'));
          break;
        case 'petite-caps':
          features.add(const ui.FontFeature.enable('pcap'));
          break;
        case 'all-petite-caps':
          features.add(const ui.FontFeature.enable('pcap'));
          features.add(const ui.FontFeature.enable('c2pc'));
          break;
        case 'unicase':
          features.add(const ui.FontFeature.enable('unic'));
          break;
        case 'titling-caps':
          features.add(const ui.FontFeature.enable('titl'));
          break;
        case 'oldstyle-nums':
          features.add(const ui.FontFeature.oldstyleFigures());
          break;
        case 'lining-nums':
          features.add(const ui.FontFeature.liningFigures());
          break;
        case 'tabular-nums':
          features.add(const ui.FontFeature.tabularFigures());
          break;
        case 'proportional-nums':
          features.add(const ui.FontFeature.proportionalFigures());
          break;
      }
    }

    return features;
  }

  /// Resolves font-stretch attribute to width percentage.
  /// Returns width as percentage (100 = normal).
  /// Supports keywords and percentage values.
  double _resolveFontStretch(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 100.0; // normal
    }
    final normalized = value.trim().toLowerCase();

    // Handle percentage values
    if (normalized.endsWith('%')) {
      final numStr = normalized.substring(0, normalized.length - 1);
      return double.tryParse(numStr)?.clamp(50.0, 200.0) ?? 100.0;
    }

    // Handle keyword values
    switch (normalized) {
      case 'ultra-condensed':
        return 50.0;
      case 'extra-condensed':
        return 62.5;
      case 'condensed':
        return 75.0;
      case 'semi-condensed':
        return 87.5;
      case 'normal':
        return 100.0;
      case 'semi-expanded':
        return 112.5;
      case 'expanded':
        return 125.0;
      case 'extra-expanded':
        return 150.0;
      case 'ultra-expanded':
        return 200.0;
      default:
        return double.tryParse(normalized)?.clamp(50.0, 200.0) ?? 100.0;
    }
  }

  /// Resolves font-size-adjust attribute.
  /// Returns aspect ratio value (x-height / font-size) or null if none.
  /// This is used to scale font size to maintain consistent x-height
  /// when fallback fonts have different aspect ratios.
  double? _resolveFontSizeAdjust(String? value) {
    if (value == null ||
        value.trim().isEmpty ||
        value.trim().toLowerCase() == 'none') {
      return null;
    }
    return double.tryParse(value.trim());
  }

  /// Resolves font-kerning CSS property.
  /// Controls kerning behavior.
  /// Returns: auto, normal, or none.
  String _resolveFontKerning(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'auto';
    }
    final normalized = value.trim().toLowerCase();
    switch (normalized) {
      case 'normal':
        return 'normal';
      case 'none':
        return 'none';
      case 'auto':
      default:
        return 'auto';
    }
  }

  /// Resolves font-variant-numeric CSS property.
  /// Controls numeric glyph variants.
  /// Returns space-separated values or 'normal'.
  String _resolveFontVariantNumeric(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'normal';
    }
    final normalized = value.trim().toLowerCase();
    if (normalized == 'normal' || normalized == 'inherit') {
      return 'normal';
    }
    // Valid keywords for numeric variants
    final validKeywords = <String>{
      'lining-nums',
      'oldstyle-nums',
      'proportional-nums',
      'tabular-nums',
      'diagonal-fractions',
      'stacked-fractions',
      'ordinal',
      'slashed-zero',
    };
    final parts = normalized.split(RegExp(r'\s+'));
    final result = parts.where((p) => validKeywords.contains(p)).toList();
    return result.isEmpty ? 'normal' : result.join(' ');
  }

  /// Resolves font-variant-ligatures CSS property.
  /// Controls ligature usage.
  /// Returns: normal, none, or specific ligature keywords.
  String _resolveFontVariantLigatures(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'normal';
    }
    final normalized = value.trim().toLowerCase();
    if (normalized == 'normal' || normalized == 'inherit') {
      return 'normal';
    }
    if (normalized == 'none') {
      return 'none';
    }
    // Valid keywords
    final validKeywords = <String>{
      'common-ligatures',
      'no-common-ligatures',
      'discretionary-ligatures',
      'no-discretionary-ligatures',
      'historical-ligatures',
      'no-historical-ligatures',
      'contextual',
      'no-contextual',
    };
    final parts = normalized.split(RegExp(r'\s+'));
    final result = parts.where((p) => validKeywords.contains(p)).toList();
    return result.isEmpty ? 'normal' : result.join(' ');
  }

  /// Resolves font-variant-caps CSS property.
  /// Controls capital letter glyph variants.
  /// Returns: normal, small-caps, all-small-caps, petite-caps, all-petite-caps, unicase, titling-caps.
  String _resolveFontVariantCaps(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'normal';
    }
    final normalized = value.trim().toLowerCase();
    switch (normalized) {
      case 'small-caps':
        return 'small-caps';
      case 'all-small-caps':
        return 'all-small-caps';
      case 'petite-caps':
        return 'petite-caps';
      case 'all-petite-caps':
        return 'all-petite-caps';
      case 'unicase':
        return 'unicase';
      case 'titling-caps':
        return 'titling-caps';
      case 'normal':
      default:
        return 'normal';
    }
  }

  /// Resolves font-optical-sizing CSS property.
  /// Controls optical sizing.
  /// Returns: auto or none.
  String _resolveFontOpticalSizing(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'auto';
    }
    final normalized = value.trim().toLowerCase();
    if (normalized == 'none') {
      return 'none';
    }
    return 'auto';
  }

  /// Resolves font-synthesis CSS property.
  /// Controls automatic font synthesis.
  /// Returns: none, or space-separated list of weight/style/small-caps.
  String _resolveFontSynthesis(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'weight style small-caps';
    }
    final normalized = value.trim().toLowerCase();
    if (normalized == 'none') {
      return 'none';
    }
    // Valid keywords
    final validKeywords = <String>{'weight', 'style', 'small-caps'};
    final parts = normalized.split(RegExp(r'\s+'));
    final result = parts.where((p) => validKeywords.contains(p)).toList();
    return result.isEmpty ? 'weight style small-caps' : result.join(' ');
  }

  /// Resolves font-variant-position CSS property.
  /// Controls subscript/superscript glyph variants.
  /// Returns: normal, sub, or super.
  String _resolveFontVariantPosition(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'normal';
    }
    final normalized = value.trim().toLowerCase();
    switch (normalized) {
      case 'sub':
        return 'sub';
      case 'super':
        return 'super';
      case 'normal':
      default:
        return 'normal';
    }
  }

  /// Resolves font-variant-east-asian CSS property.
  /// Controls East Asian font variants.
  /// Returns: normal, or space-separated list of keywords.
  String _resolveFontVariantEastAsian(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'normal';
    }
    final normalized = value.trim().toLowerCase();
    if (normalized == 'normal') {
      return 'normal';
    }
    // Valid keywords
    final validKeywords = <String>{
      'jis78',
      'jis83',
      'jis90',
      'jis04',
      'simplified',
      'traditional',
      'full-width',
      'proportional-width',
      'ruby',
    };
    final parts = normalized.split(RegExp(r'\s+'));
    final result = parts.where((p) => validKeywords.contains(p)).toList();
    return result.isEmpty ? 'normal' : result.join(' ');
  }

  /// Resolves font-language-override CSS property.
  /// Controls OpenType language system.
  /// Returns: normal, or language tag.
  String? _resolveFontLanguageOverride(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // normal
    }
    final normalized = value.trim().toLowerCase();
    if (normalized == 'normal') {
      return null;
    }
    // Return as-is for language tag
    return value.trim();
  }

  /// Resolves font-variant-alternates CSS property.
  /// Controls OpenType stylistic alternates.
  /// Returns: normal, or alternate functions.
  String? _resolveFontVariantAlternates(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // normal
    }
    final normalized = value.trim().toLowerCase();
    if (normalized == 'normal') {
      return null;
    }
    // Return as-is for alternate functions
    return value.trim();
  }

  /// Resolves font-palette CSS property.
  /// Controls color font palettes.
  /// Returns: normal, light, dark, or palette name.
  String? _resolveFontPalette(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // normal
    }
    final normalized = value.trim().toLowerCase();
    if (normalized == 'normal') {
      return null;
    }
    if (normalized == 'light' || normalized == 'dark') {
      return normalized;
    }
    // Return as-is for custom palette
    return value.trim();
  }

  /// Resolves font-variation-settings CSS property.
  /// Controls variable font axes.
  /// Returns: normal, or axis settings string.
  String? _resolveFontVariationSettings(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // normal
    }
    final normalized = value.trim().toLowerCase();
    if (normalized == 'normal') {
      return null;
    }
    // Return as-is for axis settings
    return value.trim();
  }
}
