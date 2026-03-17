part of 'animated_svg_painter.dart';

extension AnimatedSvgPainterTextStyleExtension on AnimatedSvgPainter {
  _ResolvedTextStyle _resolveTextStyle(SvgNode node) {
    final fontSize = (_getInheritedNumber(node, 'font-size') ?? 16.0).clamp(
      1.0,
      4096.0,
    );
    final fillValue = _getInheritedAttributeValue(node, 'fill');
    final fillColor =
        _resolveColorForNode(fillValue, node) ?? const ui.Color(0xFF000000);
    final opacity = (_getInheritedNumber(node, 'opacity') ?? 1.0).clamp(
      0.0,
      1.0,
    );
    final fillOpacity = (_getInheritedNumber(node, 'fill-opacity') ?? 1.0)
        .clamp(0.0, 1.0);
    final color = _applyOpacity(fillColor, opacity * fillOpacity);
    final fontFamily = _getInheritedString(node, 'font-family');
    final fontWeight = _resolveFontWeight(
      _getInheritedString(node, 'font-weight'),
    );
    final fontStyle = _resolveFontStyle(
      _getInheritedString(node, 'font-style'),
    );
    final textAnchor = _resolveTextAnchor(
      _getInheritedString(node, 'text-anchor'),
    );
    final dominantBaseline = _resolveDominantBaseline(
      _getInheritedString(node, 'dominant-baseline') ??
          _getInheritedString(node, 'alignment-baseline'),
    );
    final baselineShift = _resolveBaselineShift(
      _getInheritedAttributeValue(node, 'baseline-shift'),
      fontSize,
    );
    final letterSpacing = (_getInheritedNumber(node, 'letter-spacing') ?? 0.0)
        .clamp(-1024.0, 1024.0);
    final wordSpacing = (_getInheritedNumber(node, 'word-spacing') ?? 0.0)
        .clamp(-1024.0, 1024.0);
    final decorations = _resolveTextDecoration(
      _getInheritedString(node, 'text-decoration'),
    );
    final decorationColorValue =
        _getInheritedAttributeValue(node, 'text-decoration-color');
    final decorationColor = decorationColorValue != null
        ? _resolveColorForNode(decorationColorValue, node)
        : null;
    final writingMode = _resolveWritingMode(
      _getInheritedString(node, 'writing-mode'),
    );
    final fontFeatures = _resolveFontVariant(
      _getInheritedString(node, 'font-variant'),
    );
    final textRenderingFeatures = _resolveTextRenderingFeatures(
      _getInheritedString(node, 'text-rendering'),
    );
    // Merge font features from font-variant and text-rendering
    final allFontFeatures = <ui.FontFeature>[
      ...fontFeatures,
      ...textRenderingFeatures,
    ];
    final textDirection = _resolveTextDirection(
      _getInheritedString(node, 'direction'),
    );
    final glyphOrientationVertical = _resolveGlyphOrientationVertical(
      _getInheritedString(node, 'glyph-orientation-vertical'),
    );
    final unicodeBidi = _resolveUnicodeBidi(
      _getInheritedString(node, 'unicode-bidi'),
    );
    final fontStretch = _resolveFontStretch(
      _getInheritedString(node, 'font-stretch'),
    );
    final fontSizeAdjust = _resolveFontSizeAdjust(
      _getInheritedString(node, 'font-size-adjust'),
    );
    final tabSize = _resolveTabSize(
      _getInheritedString(node, 'tab-size'),
    );
    final textIndent = _resolveTextIndent(
      _getInheritedString(node, 'text-indent'),
      fontSize,
    );
    final wordBreak = _resolveWordBreak(
      _getInheritedString(node, 'word-break'),
    );
    // overflow-wrap, also check word-wrap as legacy fallback
    final overflowWrap = _resolveOverflowWrap(
      _getInheritedString(node, 'overflow-wrap') ??
          _getInheritedString(node, 'word-wrap'),
    );
    final textTransform = _resolveTextTransform(
      _getInheritedString(node, 'text-transform'),
    );
    final hyphens = _resolveHyphens(
      _getInheritedString(node, 'hyphens'),
    );
    final lineBreak = _resolveLineBreak(
      _getInheritedString(node, 'line-break'),
    );
    final hangingPunctuation = _resolveHangingPunctuation(
      _getInheritedString(node, 'hanging-punctuation'),
    );
    final textCombineUpright = _resolveTextCombineUpright(
      _getInheritedString(node, 'text-combine-upright'),
    );

    return _ResolvedTextStyle(
      color: color,
      fontSize: fontSize,
      fontFamily: fontFamily,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      textAnchor: textAnchor,
      dominantBaseline: dominantBaseline,
      baselineShift: baselineShift,
      letterSpacing: letterSpacing,
      wordSpacing: wordSpacing,
      decorations: decorations,
      decorationColor: decorationColor,
      writingMode: writingMode,
      fontFeatures: allFontFeatures,
      textDirection: textDirection,
      glyphOrientationVertical: glyphOrientationVertical,
      unicodeBidi: unicodeBidi,
      fontStretch: fontStretch,
      fontSizeAdjust: fontSizeAdjust,
      tabSize: tabSize,
      textIndent: textIndent,
      wordBreak: wordBreak,
      overflowWrap: overflowWrap,
      textTransform: textTransform,
      hyphens: hyphens,
      lineBreak: lineBreak,
      hangingPunctuation: hangingPunctuation,
      textCombineUpright: textCombineUpright,
    );
  }

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
    if (value == null || value.trim().isEmpty || value.trim().toLowerCase() == 'auto') {
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
    if (value == null || value.trim().isEmpty || value.trim().toLowerCase() == 'normal') {
      return null;
    }
    return value.trim().toLowerCase();
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
    if (value == null || value.trim().isEmpty || value.trim().toLowerCase() == 'none') {
      return null;
    }
    return double.tryParse(value.trim());
  }

  /// Resolves tab-size CSS property.
  /// Returns number of spaces a tab character equals (default 8).
  /// Supports both number and length values.
  int _resolveTabSize(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 8; // CSS default
    }
    final normalized = value.trim().toLowerCase();
    final parsed = int.tryParse(normalized);
    if (parsed != null) {
      return parsed.clamp(1, 32);
    }
    // For length values like "4em", extract the number
    final match = RegExp(r'^(\d+)').firstMatch(normalized);
    if (match != null) {
      return int.tryParse(match.group(1)!)?.clamp(1, 32) ?? 8;
    }
    return 8;
  }

  /// Resolves text-indent CSS property.
  /// Returns indentation in user units (default 0).
  double _resolveTextIndent(String? value, double fontSize) {
    if (value == null || value.trim().isEmpty) {
      return 0.0;
    }
    final normalized = value.trim().toLowerCase();
    // Handle percentage values
    if (normalized.endsWith('%')) {
      final pctStr = normalized.substring(0, normalized.length - 1);
      final pct = double.tryParse(pctStr);
      if (pct != null) {
        // Percentage relative to containing block width, approximate with fontSize * 10
        return fontSize * pct / 10;
      }
      return 0.0;
    }
    // Handle em units
    if (normalized.endsWith('em')) {
      final numStr = normalized.substring(0, normalized.length - 2);
      return (double.tryParse(numStr) ?? 0.0) * fontSize;
    }
    // Handle px units
    if (normalized.endsWith('px')) {
      final numStr = normalized.substring(0, normalized.length - 2);
      return double.tryParse(numStr) ?? 0.0;
    }
    // Plain number treated as px
    return double.tryParse(normalized) ?? 0.0;
  }

  /// Resolves word-break CSS property.
  /// Returns the word breaking mode (normal, break-all, keep-all, break-word).
  String _resolveWordBreak(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'normal';
    }
    final normalized = value.trim().toLowerCase();
    switch (normalized) {
      case 'break-all':
      case 'keep-all':
      case 'break-word':
        return normalized;
      case 'normal':
      default:
        return 'normal';
    }
  }

  /// Resolves overflow-wrap CSS property (also known as word-wrap).
  /// Returns the overflow wrapping mode (normal, break-word, anywhere).
  String _resolveOverflowWrap(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'normal';
    }
    final normalized = value.trim().toLowerCase();
    switch (normalized) {
      case 'break-word':
      case 'anywhere':
        return normalized;
      case 'normal':
      default:
        return 'normal';
    }
  }

  /// Resolves text-transform CSS property.
  /// Returns the text transformation mode.
  String _resolveTextTransform(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'none';
    }
    final normalized = value.trim().toLowerCase();
    switch (normalized) {
      case 'capitalize':
      case 'uppercase':
      case 'lowercase':
      case 'full-width':
      case 'full-size-kana':
        return normalized;
      case 'none':
      default:
        return 'none';
    }
  }

  /// Resolves hyphens CSS property.
  /// Returns the hyphenation mode (none, manual, auto).
  String _resolveHyphens(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'manual';
    }
    final normalized = value.trim().toLowerCase();
    switch (normalized) {
      case 'none':
      case 'auto':
        return normalized;
      case 'manual':
      default:
        return 'manual';
    }
  }

  /// Resolves line-break CSS property.
  /// Returns the line breaking strictness (auto, loose, normal, strict, anywhere).
  String _resolveLineBreak(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'auto';
    }
    final normalized = value.trim().toLowerCase();
    switch (normalized) {
      case 'loose':
      case 'normal':
      case 'strict':
      case 'anywhere':
        return normalized;
      case 'auto':
      default:
        return 'auto';
    }
  }

  /// Resolves hanging-punctuation CSS property.
  /// Returns the hanging punctuation mode (none, first, last, force-end, allow-end).
  String _resolveHangingPunctuation(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'none';
    }
    final normalized = value.trim().toLowerCase();
    // Could be multiple values like "first last"
    final parts = normalized.split(RegExp(r'\s+'));
    final validValues = <String>{};
    for (final part in parts) {
      switch (part) {
        case 'first':
        case 'last':
        case 'force-end':
        case 'allow-end':
          validValues.add(part);
          break;
        case 'none':
          return 'none';
      }
    }
    return validValues.isEmpty ? 'none' : validValues.join(' ');
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
        return const <ui.FontFeature>[
          ui.FontFeature.enable('kern'),
        ];
      case 'auto':
      default:
        return const <ui.FontFeature>[];
    }
  }

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

  ui.Paragraph _buildTextParagraph(String text, _ResolvedTextStyle style) {
    final paragraphBuilder = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        fontSize: style.fontSize,
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
        fontSize: style.fontSize,
        fontFamily: style.fontFamily,
        fontWeight: style.fontWeight,
        fontStyle: style.fontStyle,
        letterSpacing: style.letterSpacing,
        wordSpacing: style.wordSpacing,
        decoration: decoration,
        decorationColor: style.decorationColor ?? style.color,
        fontFeatures: style.fontFeatures.isNotEmpty ? style.fontFeatures : null,
      ),
    );
    paragraphBuilder.addText(text);
    final paragraph = paragraphBuilder.build();
    paragraph.layout(const ui.ParagraphConstraints(width: 1000000));
    return paragraph;
  }

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

  double _resolveTextTopFromBaseline({
    required ui.Paragraph paragraph,
    required _ResolvedTextStyle style,
    required double baselineY,
  }) {
    final baselineRef = _resolveBaselineReference(
      paragraph: paragraph,
      dominantBaseline: style.dominantBaseline,
    );
    final shiftedBaselineY = baselineY - style.baselineShift;
    return shiftedBaselineY - baselineRef;
  }

  double _resolveBaselineReference({
    required ui.Paragraph paragraph,
    required _SvgDominantBaseline dominantBaseline,
  }) {
    return switch (dominantBaseline) {
      _SvgDominantBaseline.alphabetic => paragraph.alphabeticBaseline,
      _SvgDominantBaseline.central => paragraph.height / 2,
      _SvgDominantBaseline.textBeforeEdge => 0.0,
      _SvgDominantBaseline.textAfterEdge => paragraph.height,
    };
  }

  _SvgDominantBaseline _resolveDominantBaseline(String? rawValue) {
    switch (rawValue?.trim().toLowerCase()) {
      case 'middle':
      case 'central':
        return _SvgDominantBaseline.central;
      case 'text-before-edge':
      case 'before-edge':
      case 'hanging':
        return _SvgDominantBaseline.textBeforeEdge;
      case 'text-after-edge':
      case 'after-edge':
      case 'ideographic':
        return _SvgDominantBaseline.textAfterEdge;
      case 'alphabetic':
      default:
        return _SvgDominantBaseline.alphabetic;
    }
  }

  double _resolveBaselineShift(Object? rawValue, double fontSize) {
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
    if (value == 'sub') {
      return -fontSize * 0.6;
    }
    if (value == 'super') {
      return fontSize * 0.6;
    }
    if (value.endsWith('%')) {
      final percent = double.tryParse(value.substring(0, value.length - 1));
      if (percent == null) {
        return 0.0;
      }
      return (fontSize * percent / 100.0).clamp(-4096.0, 4096.0);
    }
    final numeric = double.tryParse(value.replaceAll(RegExp(r'[a-z]+$'), ''));
    return (numeric ?? 0.0).clamp(-4096.0, 4096.0);
  }

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

  _SvgTextLengthAdjust _resolveLengthAdjust(SvgNode node) {
    final raw = node.getAttributeValue('lengthAdjust')?.toString().trim();
    if (raw == null || raw.isEmpty) {
      return _SvgTextLengthAdjust.spacing;
    }
    return raw.toLowerCase() == 'spacingandglyphs'
        ? _SvgTextLengthAdjust.spacingAndGlyphs
        : _SvgTextLengthAdjust.spacing;
  }

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
}
