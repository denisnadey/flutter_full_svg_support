part of 'animated_svg_painter.dart';

/// Text rendering utilities for SVG text styling.
///
/// Contains methods for building and rendering text:
/// - Paragraph building with font features and variations
/// - Unicode bidirectional text handling
/// - Text path support and spacing calculations
/// - Text content extraction with whitespace handling
extension AnimatedSvgPainterTextStyleRenderingExtension on AnimatedSvgPainter {
  /// Builds a Flutter Paragraph with the resolved text style.
  ui.Paragraph _buildTextParagraph(String text, _ResolvedTextStyle style) {
    // Apply font-size-adjust if specified
    // font-size-adjust preserves x-height when font-fallback occurs
    // adjusted-font-size = font-size * (font-size-adjust / actual-aspect-ratio)
    var effectiveFontSize = style.fontSize;
    if (style.fontSizeAdjust != null && style.fontSizeAdjust! > 0) {
      // Estimate aspect ratio (x-height/font-size) - typical value is ~0.48 for many fonts
      // This is a heuristic since Flutter doesn't expose actual x-height
      const estimatedAspectRatio = 0.48;
      effectiveFontSize =
          style.fontSize * (style.fontSizeAdjust! / estimatedAspectRatio);
    }

    // Build font variations list for variable font support
    final fontVariations = <ui.FontVariation>[];

    // Apply font-stretch via 'wdth' variation axis
    // font-stretch 100 = normal, maps to wdth 100
    if ((style.fontStretch - 100.0).abs() > 0.1) {
      fontVariations.add(ui.FontVariation('wdth', style.fontStretch));
    }

    // Apply unicode-bidi by wrapping text with Unicode directional control characters
    final processedText = _applyUnicodeBidi(
      text,
      style.unicodeBidi,
      style.textDirection,
    );

    // Generate cache key for text paragraph (include new properties)
    final cacheKey = _RenderCache.textKey(
      processedText,
      effectiveFontSize,
      style.fontFamily,
      style.fontWeight.index,
      style.fontStyle.index,
      style.letterSpacing,
      style.color.toARGB32(),
    );

    // Check cache first
    final cached = _renderCache.textParagraphs[cacheKey];
    if (cached != null) {
      return cached;
    }

    // Build the paragraph
    final paragraphBuilder = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        fontSize: effectiveFontSize,
        fontFamily: style.fontFamily,
        fontWeight: style.fontWeight,
        fontStyle: style.fontStyle,
        textDirection: style.textDirection,
      ),
    );
    final decoration = _buildTextDecoration(style.decorations);
    paragraphBuilder.pushStyle(
      ui.TextStyle(
        color: style.color,
        fontSize: effectiveFontSize,
        fontFamily: style.fontFamily,
        fontWeight: style.fontWeight,
        fontStyle: style.fontStyle,
        letterSpacing: style.letterSpacing,
        wordSpacing: style.wordSpacing,
        decoration: decoration,
        decorationColor: style.decorationColor ?? style.color,
        fontFeatures: style.fontFeatures.isNotEmpty ? style.fontFeatures : null,
        fontVariations: fontVariations.isNotEmpty ? fontVariations : null,
      ),
    );
    paragraphBuilder.addText(processedText);
    final paragraph = paragraphBuilder.build();
    paragraph.layout(const ui.ParagraphConstraints(width: 1000000));

    // Cache the result
    _renderCache.textParagraphs[cacheKey] = paragraph;

    return paragraph;
  }

  /// Applies unicode-bidi handling by wrapping text with Unicode directional control characters.
  /// - embed: LRE/RLE + text + PDF
  /// - bidi-override: LRO/RLO + text + PDF
  /// - isolate: LRI/RLI + text + PDI
  /// - isolate-override: FSI + LRO/RLO + text + PDF + PDI
  /// - plaintext: FSI + text + PDI (determine direction from first strong char)
  String _applyUnicodeBidi(
    String text,
    String? unicodeBidi,
    ui.TextDirection textDirection,
  ) {
    if (unicodeBidi == null) {
      return text;
    }

    // Unicode directional formatting characters
    const String lre = '\u202A'; // Left-to-Right Embedding
    const String rle = '\u202B'; // Right-to-Left Embedding
    const String lro = '\u202D'; // Left-to-Right Override
    const String rlo = '\u202E'; // Right-to-Left Override
    const String pdf = '\u202C'; // Pop Directional Formatting
    const String lri = '\u2066'; // Left-to-Right Isolate
    const String rli = '\u2067'; // Right-to-Left Isolate
    const String fsi = '\u2068'; // First Strong Isolate
    const String pdi = '\u2069'; // Pop Directional Isolate

    final isRtl = textDirection == ui.TextDirection.rtl;

    switch (unicodeBidi) {
      case 'embed':
        // Embed a new level of directionality
        return isRtl ? '$rle$text$pdf' : '$lre$text$pdf';

      case 'bidi-override':
        // Force all characters to use the specified direction
        return isRtl ? '$rlo$text$pdf' : '$lro$text$pdf';

      case 'isolate':
        // Isolate text from surrounding bidi context
        return isRtl ? '$rli$text$pdi' : '$lri$text$pdi';

      case 'isolate-override':
        // Isolate and override direction
        return isRtl ? '$fsi$rlo$text$pdf$pdi' : '$fsi$lro$text$pdf$pdi';

      case 'plaintext':
        // Determine direction from first strong character
        return '$fsi$text$pdi';

      case 'normal':
      default:
        // Use normal Unicode bidi algorithm
        return text;
    }
  }

  /// Draws a paragraph with optional effects (filter, color filter, blend mode).
  void _drawParagraphWithEffects(
    ui.Canvas canvas, {
    required ui.Paragraph paragraph,
    required double x,
    required double y,
    ui.ImageFilter? imageFilter,
    ui.ColorFilter? colorFilter,
    ui.BlendMode? blendMode,
  }) {
    if (imageFilter == null && colorFilter == null && blendMode == null) {
      canvas.drawParagraph(paragraph, ui.Offset(x, y));
      return;
    }

    final layerPaint = ui.Paint();
    if (imageFilter != null) {
      layerPaint.imageFilter = imageFilter;
    }
    if (colorFilter != null) {
      layerPaint.colorFilter = colorFilter;
    }
    if (blendMode != null) {
      layerPaint.blendMode = blendMode;
    }
    final bounds = ui.Rect.fromLTWH(
      x,
      y,
      paragraph.maxIntrinsicWidth,
      paragraph.height,
    ).inflate(1.0);
    canvas.saveLayer(bounds, layerPaint);
    canvas.drawParagraph(paragraph, ui.Offset(x, y));
    canvas.restore();
  }

  /// Calculates spacing after a glyph for text path rendering.
  double _textPathSpacingAfterGlyph({
    required String glyph,
    required bool isLast,
    required _ResolvedTextStyle style,
  }) {
    if (isLast) {
      return 0.0;
    }
    var spacing = style.letterSpacing;
    if (glyph == ' ' || glyph == '\u00A0') {
      spacing += style.wordSpacing;
    }
    return spacing;
  }

  /// Resolves the top position of text from baseline coordinates.
  double _resolveTextTopFromBaseline({
    required ui.Paragraph paragraph,
    required _ResolvedTextStyle style,
    required double baselineY,
  }) {
    final baselineRef = _resolveBaselineReference(
      paragraph: paragraph,
      dominantBaseline: style.dominantBaseline,
      writingMode: style.writingMode,
    );
    final shiftedBaselineY = baselineY - style.baselineShift;
    return shiftedBaselineY - baselineRef;
  }

  /// Resolves textLength attribute value.
  double? _resolveTextLength(SvgNode node) {
    final value = node.getAttributeValue('textLength');
    if (value == null) {
      return null;
    }
    if (value is num) {
      final length = value.toDouble();
      return length > 0 ? length : null;
    }
    final raw = value.toString().trim();
    if (raw.isEmpty) {
      return null;
    }
    final cleaned = raw.replaceAll(RegExp(r'[a-zA-Z%]+$'), '');
    final parsed = double.tryParse(cleaned);
    if (parsed == null || parsed <= 0) {
      return null;
    }
    return parsed;
  }

  /// Resolves lengthAdjust attribute value.
  _SvgTextLengthAdjust _resolveLengthAdjust(SvgNode node) {
    final raw = node.getAttributeValue('lengthAdjust')?.toString().trim();
    if (raw == null || raw.isEmpty) {
      return _SvgTextLengthAdjust.spacing;
    }
    return raw.toLowerCase() == 'spacingandglyphs'
        ? _SvgTextLengthAdjust.spacingAndGlyphs
        : _SvgTextLengthAdjust.spacing;
  }

  /// Resolves textPath geometry from href reference.
  ui.Path? _resolveTextPathGeometry(SvgNode textPathNode) {
    final hrefId = _extractHrefId(textPathNode);
    if (hrefId == null || hrefId.isEmpty) {
      return null;
    }

    final referenced = document.root.findById(hrefId);
    if (referenced == null || referenced.tagName != 'path') {
      return null;
    }

    final path = _buildGeometryPath(referenced);
    if (path == null) {
      return null;
    }

    final transform = _buildTransformMatrixFromValue(
      referenced.getAttributeValue('transform'),
    );
    if (transform == null) {
      return path;
    }
    return path.transform(transform.storage);
  }

  /// Parses textPath startOffset attribute.
  double _parseTextPathStartOffset(SvgNode textPathNode, double pathLength) {
    final raw = textPathNode.getAttributeValue('startOffset');
    if (raw == null) {
      return 0.0;
    }

    if (raw is num) {
      return raw.toDouble().clamp(0.0, pathLength);
    }

    final value = raw.toString().trim();
    if (value.isEmpty) {
      return 0.0;
    }

    if (value.endsWith('%')) {
      final percent = double.tryParse(value.substring(0, value.length - 1));
      if (percent == null) {
        return 0.0;
      }
      return (pathLength * percent / 100.0).clamp(0.0, pathLength);
    }

    return (double.tryParse(value) ?? 0.0).clamp(0.0, pathLength);
  }

  /// Extracts text content from a text node with whitespace handling.
  String? _extractTextContent(SvgNode node) {
    final raw = _getString(node, '__text');
    if (raw == null) {
      return null;
    }

    // Check white-space CSS property first (modern)
    final whiteSpace = _getInheritedString(node, 'white-space')?.toLowerCase();
    if (whiteSpace != null) {
      switch (whiteSpace) {
        case 'pre':
        case 'pre-wrap':
        case 'break-spaces':
          // Preserve whitespace (convert newlines to spaces)
          final preserved = raw.replaceAll('\n', ' ').replaceAll('\r', ' ');
          return preserved.isEmpty ? null : preserved;
        case 'pre-line':
          // Collapse spaces but preserve newlines (then convert to spaces)
          final preLine = raw.replaceAll(RegExp(r'[ \t]+'), ' ');
          return preLine.isEmpty ? null : preLine;
        case 'normal':
        case 'nowrap':
        default:
          // Collapse whitespace
          final collapsed = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
          return collapsed.isEmpty ? null : collapsed;
      }
    }

    // Fall back to xml:space attribute for whitespace handling
    final xmlSpace = _getInheritedString(node, 'xml:space')?.toLowerCase();
    if (xmlSpace == 'preserve') {
      // Preserve whitespace as-is (only convert newlines to spaces)
      final preserved = raw.replaceAll('\n', ' ').replaceAll('\r', ' ');
      return preserved.isEmpty ? null : preserved;
    }

    // Default: collapse whitespace
    final normalized = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    return normalized.isEmpty ? null : normalized;
  }

  /// Extracts text content with XML whitespace normalization for multi-tspan flow.
  /// Handles whitespace between tspans per SVG/XML specification:
  /// - Leading/trailing whitespace is stripped unless xml:space="preserve"
  /// - Multiple whitespace characters are collapsed to single space
  /// - Whitespace between elements is preserved as single space for flow
  String? _extractTextContentWithWhitespaceNormalization(
    SvgNode node,
    _ResolvedTextStyle? parentStyle,
  ) {
    final raw = _getString(node, '__text');
    if (raw == null) {
      return null;
    }

    // Check xml:space attribute for whitespace handling
    final xmlSpace = _getInheritedString(node, 'xml:space')?.toLowerCase();
    final whiteSpace = _getInheritedString(node, 'white-space')?.toLowerCase();

    // Preserve mode: xml:space="preserve" or white-space: pre/pre-wrap
    final preserveWhitespace =
        xmlSpace == 'preserve' ||
        whiteSpace == 'pre' ||
        whiteSpace == 'pre-wrap' ||
        whiteSpace == 'break-spaces';

    if (preserveWhitespace) {
      // Only convert newlines to spaces
      final preserved = raw.replaceAll('\n', ' ').replaceAll('\r', ' ');
      return preserved.isEmpty ? null : preserved;
    }

    // Default whitespace normalization for SVG text
    // Per SVG spec: collapse whitespace, but preserve single space for flow
    var normalized = raw.replaceAll(RegExp(r'\s+'), ' ');

    // For tspan children (parentStyle != null), preserve leading space for flow
    // but still normalize multiple spaces
    if (parentStyle != null) {
      // Don't trim leading space if it exists - it's needed for text flow
      // Only trim trailing space
      normalized = normalized.trimRight();
      if (normalized.isEmpty && raw.contains(RegExp(r'\s'))) {
        // If text was only whitespace, preserve as single space for flow
        return ' ';
      }
    } else {
      // For root text, trim both ends
      normalized = normalized.trim();
    }

    return normalized.isEmpty ? null : normalized;
  }

  /// Resolves text-rendering CSS property to font features.
  /// - auto: default (kerning enabled)
  /// - optimizeSpeed: disable kerning and ligatures
  /// - optimizeLegibility: enable kerning and ligatures
  /// - geometricPrecision: precise geometry, disable hinting
  List<ui.FontFeature> _resolveTextRenderingFeatures(String? value) {
    if (value == null || value.trim().isEmpty) {
      return const <ui.FontFeature>[];
    }

    switch (value.trim().toLowerCase()) {
      case 'optimizespeed':
        // Disable kerning for speed
        return const <ui.FontFeature>[
          ui.FontFeature.disable('kern'),
          ui.FontFeature.disable('liga'),
        ];
      case 'optimizelegibility':
        // Enable kerning and common ligatures for better readability
        return const <ui.FontFeature>[
          ui.FontFeature.enable('kern'),
          ui.FontFeature.enable('liga'),
          ui.FontFeature.enable('clig'),
        ];
      case 'geometricprecision':
        // Precise geometry - enable kerning
        return const <ui.FontFeature>[ui.FontFeature.enable('kern')];
      case 'auto':
      default:
        return const <ui.FontFeature>[];
    }
  }

  /// Resolves forced-color-adjust CSS property.
  /// Controls forced colors mode behavior.
  /// Returns: auto, none, preserve-parent-color.
  String _resolveForcedColorAdjust(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'auto';
    }
    final normalized = value.trim().toLowerCase();
    switch (normalized) {
      case 'none':
        return 'none';
      case 'preserve-parent-color':
        return 'preserve-parent-color';
      case 'auto':
      default:
        return 'auto';
    }
  }

  /// Resolves print-color-adjust CSS property.
  /// Controls printing color adjustment.
  /// Returns: economy, exact.
  String _resolvePrintColorAdjust(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'economy';
    }
    final normalized = value.trim().toLowerCase();
    if (normalized == 'exact') {
      return 'exact';
    }
    return 'economy';
  }

  /// Resolves content-visibility CSS property.
  /// Controls rendering visibility optimization.
  /// Returns: visible, hidden, auto.
  String _resolveContentVisibility(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'visible';
    }
    final normalized = value.trim().toLowerCase();
    switch (normalized) {
      case 'hidden':
        return 'hidden';
      case 'auto':
        return 'auto';
      case 'visible':
      default:
        return 'visible';
    }
  }

  /// Resolves contain-intrinsic-size CSS property.
  /// Controls intrinsic size for content-visibility.
  /// Returns: none, auto, or size value.
  String? _resolveContainIntrinsicSize(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // none
    }
    final normalized = value.trim().toLowerCase();
    if (normalized == 'none') {
      return null;
    }
    // Return as-is for size parsing
    return value.trim();
  }

  /// Resolves will-change CSS property.
  /// Hints browser about expected changes.
  /// Returns: auto, or property names.
  String _resolveWillChange(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'auto';
    }
    final normalized = value.trim().toLowerCase();
    if (normalized == 'auto') {
      return 'auto';
    }
    // Return as-is for property names
    return value.trim();
  }

  /// Resolves mix-blend-mode CSS property.
  /// Controls blending mode.
  /// Returns: normal, multiply, screen, overlay, etc.
  String _resolveCssMixBlendMode(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'normal';
    }
    final normalized = value.trim().toLowerCase();
    const validModes = <String>{
      'normal',
      'multiply',
      'screen',
      'overlay',
      'darken',
      'lighten',
      'color-dodge',
      'color-burn',
      'hard-light',
      'soft-light',
      'difference',
      'exclusion',
      'hue',
      'saturation',
      'color',
      'luminosity',
    };
    if (validModes.contains(normalized)) {
      return normalized;
    }
    return 'normal';
  }
}
