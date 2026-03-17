part of 'animated_svg_painter.dart';

/// Font property resolvers for SVG text styling.
///
/// Contains resolver methods for font-related CSS properties:
/// - font-variant, font-stretch, font-size-adjust, font-kerning
/// - font-optical-sizing, font-synthesis
/// - font-variant-* properties
///
/// Note: _resolveFontWeight and _resolveFontStyle are defined in
/// animated_svg_painter_values.dart and shared across extensions.
extension AnimatedSvgPainterTextStyleFontExtension on AnimatedSvgPainter {
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
