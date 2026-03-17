part of 'animated_svg_painter.dart';

/// Text positioning resolvers for SVG text styling.
///
/// Contains resolver methods for text positioning CSS properties:
/// - writing-mode, direction, text-orientation
/// - dominant-baseline, alignment-baseline
/// - baseline-shift, glyph-orientation-vertical
/// - unicode-bidi, text-combine-upright
///
/// Note: _resolveTextAnchor is defined in animated_svg_painter_values.dart
/// and shared across extensions.
extension AnimatedSvgPainterTextStylePositioningExtension
    on AnimatedSvgPainter {
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

  /// Resolves baseline-shift attribute value.
  /// Supports: baseline, sub, super, percentage, length values.
  /// Per SVG spec, percentage is relative to line-height (computed height of line box).
  double _resolveBaselineShift(
    Object? rawValue,
    double fontSize, {
    double? lineHeight,
  }) {
    if (rawValue == null) {
      return 0.0;
    }
    if (rawValue is num) {
      return rawValue.toDouble().clamp(-4096.0, 4096.0);
    }
    final value = rawValue.toString().trim().toLowerCase();
    if (value.isEmpty || value == 'baseline') {
      return 0.0;
    }
    // Subscript: shift down by a factor of font-size
    // Blink uses ~0.3em descent from baseline
    if (value == 'sub') {
      return -fontSize * 0.3;
    }
    // Superscript: shift up by a factor of font-size
    // Blink uses ~0.4em above baseline
    if (value == 'super') {
      return fontSize * 0.4;
    }
    // Percentage: relative to line-height (or 1.2 * fontSize as default)
    if (value.endsWith('%')) {
      final percent = double.tryParse(value.substring(0, value.length - 1));
      if (percent == null) {
        return 0.0;
      }
      // Use line-height if provided, otherwise default to 1.2 * fontSize
      final effectiveLineHeight = lineHeight ?? (fontSize * 1.2);
      return (effectiveLineHeight * percent / 100.0).clamp(-4096.0, 4096.0);
    }
    // em units: relative to font-size
    if (value.endsWith('em')) {
      final em = double.tryParse(value.substring(0, value.length - 2));
      if (em != null) {
        return (fontSize * em).clamp(-4096.0, 4096.0);
      }
      return 0.0;
    }
    // ex units: relative to x-height (~0.5 * font-size)
    if (value.endsWith('ex')) {
      final ex = double.tryParse(value.substring(0, value.length - 2));
      if (ex != null) {
        return (fontSize * 0.5 * ex).clamp(-4096.0, 4096.0);
      }
      return 0.0;
    }
    // Plain number or px: treat as user units
    final numeric = double.tryParse(value.replaceAll(RegExp(r'[a-z]+$'), ''));
    return (numeric ?? 0.0).clamp(-4096.0, 4096.0);
  }

  /// Resolves baseline offset from paragraph metrics.
  /// Returns the y-offset from the paragraph top to the specified baseline.
  double _resolveBaselineReference({
    required ui.Paragraph paragraph,
    required _SvgDominantBaseline dominantBaseline,
  }) {
    // Get font metrics from paragraph
    final height = paragraph.height;
    final alphabeticBaseline = paragraph.alphabeticBaseline;
    final ideographicBaseline = paragraph.ideographicBaseline;

    // Calculate approximate ascent from alphabetic baseline
    // alphabeticBaseline is the distance from top to baseline
    final ascent = alphabeticBaseline;

    // Approximate x-height as ~50% of ascent (typical for Latin fonts)
    final xHeight = ascent * 0.5;

    return switch (dominantBaseline) {
      _SvgDominantBaseline.alphabetic => alphabeticBaseline,
      _SvgDominantBaseline.central => height / 2,
      _SvgDominantBaseline.middle => height / 2,
      _SvgDominantBaseline.textBeforeEdge => 0.0,
      _SvgDominantBaseline.textAfterEdge => height,
      // Hanging baseline: approximately 80% of ascent from top
      // Used for Indic scripts where the main stroke hangs from the top
      _SvgDominantBaseline.hanging => ascent * 0.8,
      // Mathematical baseline: centered on math operators
      // Typically at x-height / 2 + some offset (~50% of x-height above baseline)
      _SvgDominantBaseline.mathematical => alphabeticBaseline - xHeight * 0.5,
      // Ideographic baseline: at the bottom of the ideographic em box
      // Use the ideographicBaseline if available, else approximate
      _SvgDominantBaseline.ideographic => ideographicBaseline,
    };
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
