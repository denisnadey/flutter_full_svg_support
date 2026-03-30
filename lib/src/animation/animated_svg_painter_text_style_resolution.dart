part of 'animated_svg_painter.dart';

/// Text style resolution for CSS properties.
///
/// Contains resolver methods for text styling CSS properties:
/// - writing-mode, direction, text-orientation
/// - dominant-baseline, alignment-baseline
/// - glyph-orientation-vertical
/// - unicode-bidi, text-combine-upright
/// - paint-order, ruby-align, ruby-position
extension AnimatedSvgPainterTextStyleResolutionExtension on AnimatedSvgPainter {
  /// Resolves writing-mode CSS property.
  _SvgWritingMode _resolveWritingMode(String? value) {
    if (value == null || value.trim().isEmpty) {
      return _SvgWritingMode.horizontalTb;
    }
    switch (value.trim().toLowerCase()) {
      case 'vertical-rl':
      case 'tb-rl': // legacy SVG 1.1
        return _SvgWritingMode.verticalRl;
      case 'vertical-lr':
      case 'tb': // legacy SVG 1.1
        return _SvgWritingMode.verticalLr;
      case 'horizontal-tb':
      case 'lr-tb': // legacy SVG 1.1
      case 'lr': // legacy
      default:
        return _SvgWritingMode.horizontalTb;
    }
  }

  /// Resolves direction CSS property to Flutter TextDirection.
  /// Supports: ltr (default), rtl
  ui.TextDirection _resolveTextDirection(String? value) {
    if (value == null || value.trim().isEmpty) {
      return ui.TextDirection.ltr;
    }
    switch (value.trim().toLowerCase()) {
      case 'rtl':
        return ui.TextDirection.rtl;
      case 'ltr':
      default:
        return ui.TextDirection.ltr;
    }
  }

  /// Resolves glyph-orientation-vertical attribute.
  /// Returns angle in degrees for vertical text glyph rotation.
  /// - auto: automatic (returns null, handled by layout)
  /// - 0deg, 0: upright glyphs
  /// - 90deg, 90: rotated 90 degrees clockwise
  double? _resolveGlyphOrientationVertical(String? value) {
    if (value == null ||
        value.trim().isEmpty ||
        value.trim().toLowerCase() == 'auto') {
      return null; // auto orientation
    }
    final normalized = value.trim().toLowerCase().replaceAll('deg', '');
    return double.tryParse(normalized);
  }

  /// Resolves unicode-bidi attribute for bidirectional text handling.
  /// Returns Flutter TextDirection modifier or null for normal.
  /// - normal: use inherited direction
  /// - embed: embed a level of directionality
  /// - isolate: isolate from surrounding text
  /// - bidi-override: override inherited direction for all chars
  /// - isolate-override: combine isolate and override
  /// - plaintext: determine direction from first strong character
  String? _resolveUnicodeBidi(String? value) {
    if (value == null ||
        value.trim().isEmpty ||
        value.trim().toLowerCase() == 'normal') {
      return null;
    }
    return value.trim().toLowerCase();
  }

  /// Resolves text-combine-upright CSS property for vertical writing.
  /// Returns combination mode (none, all, digits <count>).
  String _resolveTextCombineUpright(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'none';
    }
    final normalized = value.trim().toLowerCase();
    if (normalized == 'all') {
      return 'all';
    }
    // Check for "digits" with optional count
    if (normalized.startsWith('digits')) {
      final match = RegExp(r'digits\s*(\d+)?').firstMatch(normalized);
      if (match != null) {
        final count = match.group(1);
        return count != null ? 'digits $count' : 'digits 2';
      }
    }
    return 'none';
  }

  /// Resolves text-orientation CSS property for vertical writing.
  /// Returns orientation mode (mixed, upright, sideways).
  String _resolveTextOrientation(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'mixed';
    }
    final normalized = value.trim().toLowerCase();
    switch (normalized) {
      case 'upright':
      case 'sideways':
      case 'sideways-right': // Legacy alias
        return normalized == 'sideways-right' ? 'sideways' : normalized;
      case 'mixed':
      default:
        return 'mixed';
    }
  }

  /// Resolves dominant-baseline or alignment-baseline attribute value.
  /// SVG 2 spec: https://www.w3.org/TR/SVG2/text.html#DominantBaselineProperty
  _SvgDominantBaseline _resolveDominantBaseline(String? rawValue) {
    switch (rawValue?.trim().toLowerCase()) {
      case 'middle':
        return _SvgDominantBaseline.middle;
      case 'central':
        return _SvgDominantBaseline.central;
      case 'text-before-edge':
      case 'before-edge':
      case 'text-top':
        return _SvgDominantBaseline.textBeforeEdge;
      case 'text-after-edge':
      case 'after-edge':
      case 'text-bottom':
        return _SvgDominantBaseline.textAfterEdge;
      case 'hanging':
        return _SvgDominantBaseline.hanging;
      case 'mathematical':
        return _SvgDominantBaseline.mathematical;
      case 'ideographic':
        return _SvgDominantBaseline.ideographic;
      case 'alphabetic':
      case 'auto':
      default:
        return _SvgDominantBaseline.alphabetic;
    }
  }

  /// Resolves direction CSS property.
  /// Controls text direction.
  /// Returns: ltr or rtl.
  String _resolveCssDirection(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'ltr';
    }
    final normalized = value.trim().toLowerCase();
    if (normalized == 'rtl') {
      return 'rtl';
    }
    return 'ltr';
  }

  /// Resolves paint-order CSS property.
  /// Controls the order of fill, stroke, and markers.
  /// Returns: normal, or space-separated list of fill/stroke/markers.
  String _resolvePaintOrder(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'normal';
    }
    final normalized = value.trim().toLowerCase();
    if (normalized == 'normal') {
      return 'normal';
    }
    // Valid keywords
    final validKeywords = <String>{'fill', 'stroke', 'markers'};
    final parts = normalized.split(RegExp(r'\s+'));
    final result = parts.where((p) => validKeywords.contains(p)).toList();
    return result.isEmpty ? 'normal' : result.join(' ');
  }

  /// Resolves ruby-align CSS property.
  /// Controls alignment of ruby text.
  /// Returns: space-around, start, center, space-between.
  String _resolveRubyAlign(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'space-around';
    }
    final normalized = value.trim().toLowerCase();
    switch (normalized) {
      case 'start':
        return 'start';
      case 'center':
        return 'center';
      case 'space-between':
        return 'space-between';
      case 'space-around':
      default:
        return 'space-around';
    }
  }

  /// Resolves ruby-position CSS property.
  /// Controls position of ruby text.
  /// Returns: over, under, inter-character, alternate.
  String _resolveRubyPosition(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'over';
    }
    final normalized = value.trim().toLowerCase();
    switch (normalized) {
      case 'under':
        return 'under';
      case 'inter-character':
        return 'inter-character';
      case 'alternate':
        return 'alternate';
      case 'over':
      default:
        return 'over';
    }
  }
}
