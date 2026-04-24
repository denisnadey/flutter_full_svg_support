part of 'animated_svg_painter.dart';

/// Text paragraph building and rendering utilities.
///
/// Contains methods for:
/// - Paragraph building with font features and variations
/// - Stroke text rendering
/// - Font variant feature handling
/// - Style resolution for text rendering
extension AnimatedSvgPainterTextLayoutRenderExtension on AnimatedSvgPainter {
  /// Builds a Flutter Paragraph with the resolved text style.
  ui.Paragraph _buildTextParagraph(
    String text,
    _ResolvedTextStyle style, {
    ui.Paint? foregroundPaint,
  }) {
    final normalizedText = _normalizeTextNfc(text);
    var transformedText = _applyTextTransform(
      normalizedText,
      style.textTransform,
    );

    var effectiveFontSize = style.fontSize;
    if (style.fontSizeAdjust != null && style.fontSizeAdjust! > 0) {
      const estimatedAspectRatio = 0.48;
      effectiveFontSize =
          style.fontSize * (style.fontSizeAdjust! / estimatedAspectRatio);
    }

    final fontVariations = <ui.FontVariation>[];
    if ((style.fontStretch - 100.0).abs() > 0.1) {
      fontVariations.add(ui.FontVariation('wdth', style.fontStretch));
    }
    if (style.fontOpticalSizing == 'auto') {
      fontVariations.add(ui.FontVariation('opsz', effectiveFontSize));
    }
    if (style.fontVariationSettings != null) {
      fontVariations.addAll(
        _parseFontVariationSettings(style.fontVariationSettings!),
      );
    }

    final processedText = _applyUnicodeBidi(
      transformedText,
      style.unicodeBidi,
      style.textDirection,
    );
    final allFontFeatures = <ui.FontFeature>[...style.fontFeatures];
    _addFontVariantCapsFeatures(allFontFeatures, style.fontVariantCaps);
    _addFontVariantNumericFeatures(allFontFeatures, style.fontVariantNumeric);
    _addFontVariantLigaturesFeatures(
      allFontFeatures,
      style.fontVariantLigatures,
    );
    _addFontVariantPositionFeatures(allFontFeatures, style.fontVariantPosition);

    if (style.fontKerning == 'none') {
      allFontFeatures.add(const ui.FontFeature.disable('kern'));
    } else if (style.fontKerning == 'normal') {
      allFontFeatures.add(const ui.FontFeature.enable('kern'));
    }

    final fontFeaturesKey = _fontFeaturesHashKey(allFontFeatures);
    final useCache = foregroundPaint == null;
    final cacheKey =
        _RenderCache.textKey(
          processedText,
          effectiveFontSize,
          style.fontFamily,
          style.fontWeight.index,
          style.fontStyle.index,
          style.letterSpacing,
          style.color.toARGB32(),
        ) +
        '|$fontFeaturesKey';

    if (useCache) {
      final cached = _renderCache.textParagraphs[cacheKey];
      if (cached != null) return cached;
    }

    List<String>? fontFamilyFallback;
    String? primaryFontFamily = style.fontFamily;
    if (style.fontFamily != null && style.fontFamily!.contains(',')) {
      final families = style.fontFamily!
          .split(',')
          .map((f) => f.trim())
          .where((f) => f.isNotEmpty)
          .toList();
      if (families.isNotEmpty) {
        primaryFontFamily = families.first;
        if (families.length > 1) fontFamilyFallback = families.sublist(1);
      }
    }

    final paragraphBuilder = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        fontSize: effectiveFontSize,
        fontFamily: primaryFontFamily,
        fontWeight: style.fontWeight,
        fontStyle: style.fontStyle,
        textDirection: style.textDirection,
        height: style.lineHeight != null
            ? style.lineHeight! / effectiveFontSize
            : null,
      ),
    );
    final fillPaint =
        foregroundPaint ??
        (ui.Paint()
          ..style = ui.PaintingStyle.fill
          ..color = style.color);
    final decoration = _buildTextDecoration(style.decorations);
    paragraphBuilder.pushStyle(
      ui.TextStyle(
        foreground: fillPaint,
        fontSize: effectiveFontSize,
        fontFamily: primaryFontFamily,
        fontFamilyFallback: fontFamilyFallback,
        fontWeight: style.fontWeight,
        fontStyle: style.fontStyle,
        letterSpacing: style.letterSpacing,
        wordSpacing: style.wordSpacing,
        decoration: decoration,
        decorationColor: style.decorationColor ?? style.color,
        decorationStyle: _mapDecorationStyle(style.textDecorationStyle),
        decorationThickness: style.textDecorationThickness,
        height: style.lineHeight != null
            ? style.lineHeight! / effectiveFontSize
            : null,
        shadows: style.textShadow != null
            ? _parseTextShadows(style.textShadow!)
            : null,
        fontFeatures: allFontFeatures.isNotEmpty ? allFontFeatures : null,
        fontVariations: fontVariations.isNotEmpty ? fontVariations : null,
      ),
    );
    paragraphBuilder.addText(processedText);
    final paragraph = paragraphBuilder.build();
    paragraph.layout(const ui.ParagraphConstraints(width: 1000000));
    if (useCache) {
      _renderCache.textParagraphs[cacheKey] = paragraph;
    }
    return paragraph;
  }

  // ignore: unused_element
  ui.Paragraph _buildMultiRunParagraph(List<_MultiRunTextRun> runs) {
    if (runs.isEmpty) {
      final builder = ui.ParagraphBuilder(ui.ParagraphStyle());
      final paragraph = builder.build();
      paragraph.layout(const ui.ParagraphConstraints(width: 1000000));
      return paragraph;
    }
    if (runs.length == 1)
      return _buildTextParagraph(runs.first.text, runs.first.style);

    final firstStyle = runs.first.style;
    final cacheKeyBuffer = StringBuffer('mr:');
    for (var i = 0; i < runs.length; i++) {
      final run = runs[i];
      final featuresKey = _fontFeaturesHashKey(run.fontFeatures);
      cacheKeyBuffer.write('${run.text.hashCode}|$featuresKey');
      if (i < runs.length - 1) cacheKeyBuffer.write(',');
    }
    final cacheKey = cacheKeyBuffer.toString();
    final cached = _renderCache.textParagraphs[cacheKey];
    if (cached != null) return cached;

    var effectiveFontSize = firstStyle.fontSize;
    if (firstStyle.fontSizeAdjust != null && firstStyle.fontSizeAdjust! > 0) {
      const estimatedAspectRatio = 0.48;
      effectiveFontSize =
          firstStyle.fontSize *
          (firstStyle.fontSizeAdjust! / estimatedAspectRatio);
    }

    List<String>? fontFamilyFallback;
    String? primaryFontFamily = firstStyle.fontFamily;
    if (firstStyle.fontFamily != null && firstStyle.fontFamily!.contains(',')) {
      final families = firstStyle.fontFamily!
          .split(',')
          .map((f) => f.trim())
          .where((f) => f.isNotEmpty)
          .toList();
      if (families.isNotEmpty) {
        primaryFontFamily = families.first;
        if (families.length > 1) fontFamilyFallback = families.sublist(1);
      }
    }

    final paragraphBuilder = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        fontSize: effectiveFontSize,
        fontFamily: primaryFontFamily,
        fontWeight: firstStyle.fontWeight,
        fontStyle: firstStyle.fontStyle,
        textDirection: firstStyle.textDirection,
        height: firstStyle.lineHeight != null
            ? firstStyle.lineHeight! / effectiveFontSize
            : null,
      ),
    );

    List<ui.FontFeature>? prevFeatures;
    for (var i = 0; i < runs.length; i++) {
      final run = runs[i];
      final style = run.style;
      final normalizedText = _normalizeTextNfc(run.text);
      var transformedText = _applyTextTransform(
        normalizedText,
        style.textTransform,
      );
      final processedText = _applyUnicodeBidi(
        transformedText,
        style.unicodeBidi,
        style.textDirection,
      );

      final canShareLigatures =
          prevFeatures == null ||
          _areLigatureFeaturesCompatible(prevFeatures, run.fontFeatures);
      if (!canShareLigatures && i > 0) paragraphBuilder.addText('\u200C');

      final fontVariations = <ui.FontVariation>[];
      if ((style.fontStretch - 100.0).abs() > 0.1)
        fontVariations.add(ui.FontVariation('wdth', style.fontStretch));
      if (style.fontOpticalSizing == 'auto')
        fontVariations.add(ui.FontVariation('opsz', style.fontSize));
      if (style.fontVariationSettings != null)
        fontVariations.addAll(
          _parseFontVariationSettings(style.fontVariationSettings!),
        );

      final decoration = _buildTextDecoration(style.decorations);
      final runFillPaint = ui.Paint()
        ..style = ui.PaintingStyle.fill
        ..color = style.color;
      paragraphBuilder.pushStyle(
        ui.TextStyle(
          foreground: runFillPaint,
          fontSize: style.fontSize,
          fontFamily: style.fontFamily?.split(',').first.trim(),
          fontFamilyFallback: fontFamilyFallback,
          fontWeight: style.fontWeight,
          fontStyle: style.fontStyle,
          letterSpacing: style.letterSpacing,
          wordSpacing: style.wordSpacing,
          decoration: decoration,
          decorationColor: style.decorationColor ?? style.color,
          decorationStyle: _mapDecorationStyle(style.textDecorationStyle),
          decorationThickness: style.textDecorationThickness,
          height: style.lineHeight != null
              ? style.lineHeight! / style.fontSize
              : null,
          shadows: style.textShadow != null
              ? _parseTextShadows(style.textShadow!)
              : null,
          fontFeatures: run.fontFeatures.isNotEmpty ? run.fontFeatures : null,
          fontVariations: fontVariations.isNotEmpty ? fontVariations : null,
        ),
      );
      paragraphBuilder.addText(processedText);
      paragraphBuilder.pop();
      prevFeatures = run.fontFeatures;
    }

    final paragraph = paragraphBuilder.build();
    paragraph.layout(const ui.ParagraphConstraints(width: 1000000));
    _renderCache.textParagraphs[cacheKey] = paragraph;
    return paragraph;
  }

  // ignore: unused_element
  List<ui.FontFeature> _buildFontFeaturesForRun(_ResolvedTextStyle style) {
    final features = <ui.FontFeature>[...style.fontFeatures];
    _addFontVariantCapsFeatures(features, style.fontVariantCaps);
    _addFontVariantNumericFeatures(features, style.fontVariantNumeric);
    _addFontVariantLigaturesFeatures(features, style.fontVariantLigatures);
    _addFontVariantPositionFeatures(features, style.fontVariantPosition);
    if (style.fontKerning == 'none')
      features.add(const ui.FontFeature.disable('kern'));
    else if (style.fontKerning == 'normal')
      features.add(const ui.FontFeature.enable('kern'));
    return features;
  }

  // ignore: unused_element
  bool _isLigatureCandidate(String char, String? nextChar) {
    if (nextChar == null) return false;
    final c = char.toLowerCase();
    final n = nextChar.toLowerCase();
    if (c == 'f' && (n == 'i' || n == 'l' || n == 'f')) return true;
    if ((c == 's' && n == 't') || (c == 'c' && n == 't')) return true;
    if ((char == 'T' && nextChar == 'h') || (char == 'Q' && nextChar == 'u'))
      return true;
    return false;
  }

  ui.Paragraph? _buildStrokeTextParagraph(
    String text,
    _ResolvedTextStyle style,
    SvgNode node, {
    ui.Shader? strokeShader,
  }) {
    final strokeValue = _getInheritedAttributeValue(node, 'stroke');
    if (strokeValue == null ||
        strokeValue.toString().trim() == 'none' ||
        strokeValue.toString().trim().isEmpty)
      return null;

    final strokeColor = _resolveColorForNode(strokeValue, node);
    final strokeUsesPaintServer = _extractPaintServerId(strokeValue) != null;
    if (strokeColor == null && !strokeUsesPaintServer) return null;

    final strokeWidth = (_getInheritedNumber(node, 'stroke-width') ?? 1.0)
        .clamp(0.0, 100.0);
    if (strokeWidth <= 0) return null;

    final opacity = (_getInheritedNumber(node, 'opacity') ?? 1.0).clamp(
      0.0,
      1.0,
    );
    final strokeOpacity = (_getInheritedNumber(node, 'stroke-opacity') ?? 1.0)
        .clamp(0.0, 1.0);
    final effectiveOpacity = (opacity * strokeOpacity).clamp(0.0, 1.0);
    final effectiveColor = strokeColor != null
        ? _applyOpacity(strokeColor, effectiveOpacity)
        : const ui.Color(0xFFFFFFFF).withValues(alpha: effectiveOpacity);

    final normalizedText = _normalizeTextNfc(text);
    var transformedText = _applyTextTransform(
      normalizedText,
      style.textTransform,
    );
    final processedText = _applyUnicodeBidi(
      transformedText,
      style.unicodeBidi,
      style.textDirection,
    );

    var effectiveFontSize = style.fontSize;
    if (style.fontSizeAdjust != null && style.fontSizeAdjust! > 0) {
      const estimatedAspectRatio = 0.48;
      effectiveFontSize =
          style.fontSize * (style.fontSizeAdjust! / estimatedAspectRatio);
    }

    List<String>? fontFamilyFallback;
    String? primaryFontFamily = style.fontFamily;
    if (style.fontFamily != null && style.fontFamily!.contains(',')) {
      final families = style.fontFamily!
          .split(',')
          .map((f) => f.trim())
          .where((f) => f.isNotEmpty)
          .toList();
      if (families.isNotEmpty) {
        primaryFontFamily = families.first;
        if (families.length > 1) fontFamilyFallback = families.sublist(1);
      }
    }

    final strokePaint = ui.Paint()
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = effectiveColor;
    if (strokeShader != null) {
      strokePaint
        ..shader = strokeShader
        ..color = const ui.Color(
          0xFFFFFFFF,
        ).withValues(alpha: effectiveOpacity);
    }

    final lineCap = _getInheritedString(node, 'stroke-linecap');
    if (lineCap != null) {
      switch (lineCap.toLowerCase()) {
        case 'round':
          strokePaint.strokeCap = ui.StrokeCap.round;
          break;
        case 'square':
          strokePaint.strokeCap = ui.StrokeCap.square;
          break;
        default:
          strokePaint.strokeCap = ui.StrokeCap.butt;
      }
    }

    final lineJoin = _getInheritedString(node, 'stroke-linejoin');
    if (lineJoin != null) {
      switch (lineJoin.toLowerCase()) {
        case 'round':
          strokePaint.strokeJoin = ui.StrokeJoin.round;
          break;
        case 'bevel':
          strokePaint.strokeJoin = ui.StrokeJoin.bevel;
          break;
        default:
          strokePaint.strokeJoin = ui.StrokeJoin.miter;
      }
    }

    final paragraphBuilder = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        fontSize: effectiveFontSize,
        fontFamily: primaryFontFamily,
        fontWeight: style.fontWeight,
        fontStyle: style.fontStyle,
        textDirection: style.textDirection,
      ),
    );
    paragraphBuilder.pushStyle(
      ui.TextStyle(
        foreground: strokePaint,
        fontSize: effectiveFontSize,
        fontFamily: primaryFontFamily,
        fontFamilyFallback: fontFamilyFallback,
        fontWeight: style.fontWeight,
        fontStyle: style.fontStyle,
        letterSpacing: style.letterSpacing,
        wordSpacing: style.wordSpacing,
      ),
    );
    paragraphBuilder.addText(processedText);
    final paragraph = paragraphBuilder.build();
    paragraph.layout(const ui.ParagraphConstraints(width: 1000000));
    return paragraph;
  }

  /// Resolves text-rendering font features.
  List<ui.FontFeature> _resolveTextRenderingFeatures(String? value) {
    if (value == null || value.trim().isEmpty) return const <ui.FontFeature>[];
    switch (value.trim().toLowerCase()) {
      case 'optimizespeed':
        return const <ui.FontFeature>[
          ui.FontFeature.disable('kern'),
          ui.FontFeature.disable('liga'),
        ];
      case 'optimizelegibility':
        return const <ui.FontFeature>[
          ui.FontFeature.enable('kern'),
          ui.FontFeature.enable('liga'),
          ui.FontFeature.enable('clig'),
        ];
      case 'geometricprecision':
        return const <ui.FontFeature>[ui.FontFeature.enable('kern')];
      case 'auto':
      default:
        return const <ui.FontFeature>[];
    }
  }

  String _resolveForcedColorAdjust(String? value) {
    if (value == null || value.trim().isEmpty) return 'auto';
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

  String _resolvePrintColorAdjust(String? value) {
    if (value == null || value.trim().isEmpty) return 'economy';
    final normalized = value.trim().toLowerCase();
    if (normalized == 'exact') return 'exact';
    return 'economy';
  }

  String _resolveContentVisibility(String? value) {
    if (value == null || value.trim().isEmpty) return 'visible';
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

  String? _resolveContainIntrinsicSize(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final normalized = value.trim().toLowerCase();
    if (normalized == 'none') return null;
    return value.trim();
  }

  String _resolveWillChange(String? value) {
    if (value == null || value.trim().isEmpty) return 'auto';
    final normalized = value.trim().toLowerCase();
    if (normalized == 'auto') return 'auto';
    return value.trim();
  }

  String _resolveCssMixBlendMode(String? value) {
    if (value == null || value.trim().isEmpty) return 'normal';
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
    if (validModes.contains(normalized)) return normalized;
    return 'normal';
  }

  void _addFontVariantCapsFeatures(
    List<ui.FontFeature> features,
    String value,
  ) {
    if (value == 'normal') return;
    switch (value) {
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
    }
  }

  void _addFontVariantNumericFeatures(
    List<ui.FontFeature> features,
    String value,
  ) {
    if (value == 'normal') return;
    final parts = value.split(RegExp(r'\s+'));
    for (final part in parts) {
      switch (part) {
        case 'lining-nums':
          features.add(const ui.FontFeature.liningFigures());
          break;
        case 'oldstyle-nums':
          features.add(const ui.FontFeature.oldstyleFigures());
          break;
        case 'proportional-nums':
          features.add(const ui.FontFeature.proportionalFigures());
          break;
        case 'tabular-nums':
          features.add(const ui.FontFeature.tabularFigures());
          break;
        case 'diagonal-fractions':
          features.add(const ui.FontFeature.enable('frac'));
          break;
        case 'stacked-fractions':
          features.add(const ui.FontFeature.enable('afrc'));
          break;
        case 'ordinal':
          features.add(const ui.FontFeature.enable('ordn'));
          break;
        case 'slashed-zero':
          features.add(const ui.FontFeature.slashedZero());
          break;
      }
    }
  }

  void _addFontVariantLigaturesFeatures(
    List<ui.FontFeature> features,
    String value,
  ) {
    if (value == 'normal') return;
    if (value == 'none') {
      features.add(const ui.FontFeature.disable('liga'));
      features.add(const ui.FontFeature.disable('clig'));
      features.add(const ui.FontFeature.disable('dlig'));
      features.add(const ui.FontFeature.disable('hlig'));
      features.add(const ui.FontFeature.disable('calt'));
      return;
    }
    final parts = value.split(RegExp(r'\s+'));
    for (final part in parts) {
      switch (part) {
        case 'common-ligatures':
          features.add(const ui.FontFeature.enable('liga'));
          features.add(const ui.FontFeature.enable('clig'));
          break;
        case 'no-common-ligatures':
          features.add(const ui.FontFeature.disable('liga'));
          features.add(const ui.FontFeature.disable('clig'));
          break;
        case 'discretionary-ligatures':
          features.add(const ui.FontFeature.enable('dlig'));
          break;
        case 'no-discretionary-ligatures':
          features.add(const ui.FontFeature.disable('dlig'));
          break;
        case 'historical-ligatures':
          features.add(const ui.FontFeature.enable('hlig'));
          break;
        case 'no-historical-ligatures':
          features.add(const ui.FontFeature.disable('hlig'));
          break;
        case 'contextual':
          features.add(const ui.FontFeature.enable('calt'));
          break;
        case 'no-contextual':
          features.add(const ui.FontFeature.disable('calt'));
          break;
      }
    }
  }

  void _addFontVariantPositionFeatures(
    List<ui.FontFeature> features,
    String value,
  ) {
    if (value == 'normal') return;
    switch (value) {
      case 'sub':
        features.add(const ui.FontFeature.enable('subs'));
        break;
      case 'super':
        features.add(const ui.FontFeature.enable('sups'));
        break;
    }
  }

  List<ui.FontVariation> _parseFontVariationSettings(String value) {
    final variations = <ui.FontVariation>[];
    final settings = value.split(',');
    for (final setting in settings) {
      final trimmed = setting.trim();
      if (trimmed.isEmpty) continue;
      final match = RegExp(
        r"""['"]([a-zA-Z0-9]{4})['"](?:\s+([\d.+-]+))?""",
      ).firstMatch(trimmed);
      if (match != null) {
        final axis = match.group(1)!;
        final val = double.tryParse(match.group(2) ?? '1') ?? 1.0;
        variations.add(ui.FontVariation(axis, val));
      }
    }
    return variations;
  }
}
