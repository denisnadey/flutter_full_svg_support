part of 'animated_svg_painter.dart';

/// Text decoration resolvers for SVG text styling.
///
/// Contains resolver methods for text-decoration related CSS properties:
/// - text-decoration, text-decoration-line, text-decoration-style
/// - text-decoration-color, text-decoration-thickness
/// - text-underline-position, text-underline-offset
/// - text-decoration-skip, text-decoration-skip-ink
extension AnimatedSvgPainterTextStyleDecorationExtension on AnimatedSvgPainter {
  /// Resolves text-decoration CSS property to a set of decoration types.
  Set<_SvgTextDecoration> _resolveTextDecoration(String? value) {
    if (value == null || value.trim().isEmpty || value.trim() == 'none') {
      return const <_SvgTextDecoration>{};
    }
    final result = <_SvgTextDecoration>{};
    final parts = value.toLowerCase().split(RegExp(r'\s+'));
    for (final part in parts) {
      switch (part.trim()) {
        case 'underline':
          result.add(_SvgTextDecoration.underline);
          break;
        case 'overline':
          result.add(_SvgTextDecoration.overline);
          break;
        case 'line-through':
          result.add(_SvgTextDecoration.lineThrough);
          break;
      }
    }
    return result;
  }

  /// Builds Flutter TextDecoration from SVG decoration set.
  ui.TextDecoration _buildTextDecoration(Set<_SvgTextDecoration> decorations) {
    if (decorations.isEmpty) {
      return ui.TextDecoration.none;
    }
    final list = <ui.TextDecoration>[];
    if (decorations.contains(_SvgTextDecoration.underline)) {
      list.add(ui.TextDecoration.underline);
    }
    if (decorations.contains(_SvgTextDecoration.overline)) {
      list.add(ui.TextDecoration.overline);
    }
    if (decorations.contains(_SvgTextDecoration.lineThrough)) {
      list.add(ui.TextDecoration.lineThrough);
    }
    return ui.TextDecoration.combine(list);
  }

  /// Resolves text-underline-position CSS property.
  /// Returns underline position (auto, under, left, right).
  String _resolveTextUnderlinePosition(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'auto';
    }
    final normalized = value.trim().toLowerCase();
    // Can have multiple values like "under left"
    final parts = normalized.split(RegExp(r'\s+'));
    final validValues = <String>{};
    for (final part in parts) {
      switch (part) {
        case 'under':
        case 'left':
        case 'right':
        case 'from-font':
          validValues.add(part);
          break;
        case 'auto':
          return 'auto';
      }
    }
    return validValues.isEmpty ? 'auto' : validValues.join(' ');
  }

  /// Resolves text-underline-offset CSS property.
  /// Returns offset value in user units or null for auto.
  double? _resolveTextUnderlineOffset(String? value, double fontSize) {
    if (value == null ||
        value.trim().isEmpty ||
        value.trim().toLowerCase() == 'auto') {
      return null;
    }
    final normalized = value.trim().toLowerCase();
    // Handle em units
    if (normalized.endsWith('em')) {
      final numStr = normalized.substring(0, normalized.length - 2);
      return (double.tryParse(numStr) ?? 0.0) * fontSize;
    }
    // Handle px units
    if (normalized.endsWith('px')) {
      final numStr = normalized.substring(0, normalized.length - 2);
      return double.tryParse(numStr);
    }
    // Plain number treated as px
    return double.tryParse(normalized);
  }

  /// Resolves text-decoration-thickness CSS property.
  /// Returns thickness value in user units or null for auto/from-font.
  double? _resolveTextDecorationThickness(String? value, double fontSize) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    final normalized = value.trim().toLowerCase();
    if (normalized == 'auto' || normalized == 'from-font') {
      return null;
    }
    // Handle em units
    if (normalized.endsWith('em')) {
      final numStr = normalized.substring(0, normalized.length - 2);
      return (double.tryParse(numStr) ?? 0.0) * fontSize;
    }
    // Handle px units
    if (normalized.endsWith('px')) {
      final numStr = normalized.substring(0, normalized.length - 2);
      return double.tryParse(numStr);
    }
    // Handle percentage (relative to 1em)
    if (normalized.endsWith('%')) {
      final pctStr = normalized.substring(0, normalized.length - 1);
      final pct = double.tryParse(pctStr);
      if (pct != null) {
        return fontSize * pct / 100;
      }
      return null;
    }
    // Plain number treated as px
    return double.tryParse(normalized);
  }

  /// Resolves text-decoration-skip-ink CSS property.
  /// Controls how underlines/overlines interact with glyph descenders/ascenders.
  /// Returns: auto, all, or none.
  String _resolveTextDecorationSkipInk(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'auto';
    }
    final normalized = value.trim().toLowerCase();
    switch (normalized) {
      case 'all':
        return 'all';
      case 'none':
        return 'none';
      case 'auto':
      default:
        return 'auto';
    }
  }

  /// Resolves text-decoration-skip CSS property.
  /// Controls what elements text decoration lines skip over.
  /// Returns space-separated values: none, objects, spaces, leading-spaces,
  /// trailing-spaces, edges, box-decoration.
  String _resolveTextDecorationSkip(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'objects';
    }
    final normalized = value.trim().toLowerCase();
    // Parse valid keywords
    final validKeywords = <String>{
      'none',
      'objects',
      'spaces',
      'leading-spaces',
      'trailing-spaces',
      'edges',
      'box-decoration',
    };
    if (normalized == 'none') {
      return 'none';
    }
    final parts = normalized.split(RegExp(r'\s+'));
    final result = parts.where((p) => validKeywords.contains(p)).toList();
    return result.isEmpty ? 'objects' : result.join(' ');
  }

  /// Resolves text-decoration-style CSS property.
  /// Controls the style of the decoration line.
  /// Returns: solid, double, dotted, dashed, or wavy.
  String _resolveTextDecorationStyle(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'solid';
    }
    final normalized = value.trim().toLowerCase();
    switch (normalized) {
      case 'double':
        return 'double';
      case 'dotted':
        return 'dotted';
      case 'dashed':
        return 'dashed';
      case 'wavy':
        return 'wavy';
      case 'solid':
      default:
        return 'solid';
    }
  }

  /// Resolves text-decoration-line CSS property.
  /// Controls which lines to display.
  /// Returns: none, or combination of underline/overline/line-through/blink.
  String _resolveTextDecorationLine(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'none';
    }
    final normalized = value.trim().toLowerCase();
    if (normalized == 'none') {
      return 'none';
    }
    // Valid keywords
    final validKeywords = <String>{
      'underline',
      'overline',
      'line-through',
      'blink',
    };
    final parts = normalized.split(RegExp(r'\s+'));
    final result = parts.where((p) => validKeywords.contains(p)).toList();
    return result.isEmpty ? 'none' : result.join(' ');
  }

  /// Resolves text-decoration-color CSS property.
  /// Controls color of text decorations.
  /// Returns: null for currentColor, or color string.
  String? _resolveCssTextDecorationColor(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // currentColor
    }
    final normalized = value.trim().toLowerCase();
    if (normalized == 'currentcolor') {
      return null;
    }
    return value.trim();
  }

  /// Resolves text-shadow CSS property.
  /// Returns normalized shadow string or null for none.
  /// Format: "offset-x offset-y blur-radius color" (multiple comma-separated)
  String? _resolveTextShadow(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    final normalized = value.trim().toLowerCase();
    if (normalized == 'none' ||
        normalized == 'inherit' ||
        normalized == 'initial') {
      return null;
    }
    // Return the value as-is for further processing
    return value.trim();
  }

  /// Resolves text-emphasis CSS property.
  /// Controls emphasis marks for text.
  /// Returns: none, or emphasis style string.
  String? _resolveTextEmphasis(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    final normalized = value.trim().toLowerCase();
    if (normalized == 'none') {
      return null;
    }
    // Return as-is for further processing
    return value.trim();
  }

  /// Resolves text-emphasis-position CSS property.
  /// Controls position of emphasis marks.
  /// Returns: over, under, over right, under left, etc.
  String _resolveTextEmphasisPosition(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'over right';
    }
    final normalized = value.trim().toLowerCase();
    // Valid combinations: over/under + right/left
    final validKeywords = <String>{'over', 'under', 'right', 'left'};
    final parts = normalized.split(RegExp(r'\s+'));
    final result = parts.where((p) => validKeywords.contains(p)).toList();
    return result.isEmpty ? 'over right' : result.join(' ');
  }

  /// Resolves text-emphasis-color CSS property.
  /// Controls color of emphasis marks.
  /// Returns: null for currentColor, or color string.
  String? _resolveTextEmphasisColor(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // currentColor
    }
    final normalized = value.trim().toLowerCase();
    if (normalized == 'currentcolor') {
      return null;
    }
    return value.trim();
  }

  /// Resolves text-emphasis-style CSS property.
  /// Controls style of emphasis marks.
  /// Returns: none, filled, open, dot, circle, double-circle, triangle, sesame.
  String? _resolveTextEmphasisStyle(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    final normalized = value.trim().toLowerCase();
    if (normalized == 'none') {
      return null;
    }
    // Return as-is for further processing
    return value.trim();
  }
}
