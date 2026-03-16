part of 'animated_svg_painter.dart';

extension AnimatedSvgPainterTextStyleExtension on AnimatedSvgPainter {
  _ResolvedTextStyle _resolveTextStyle(SvgNode node) {
    final fontSize = (_getInheritedNumber(node, 'font-size') ?? 16.0).clamp(
      1.0,
      4096.0,
    );
    final fillValue = _getInheritedAttributeValue(node, 'fill');
    final fillColor =
        _resolveColorValue(fillValue) ?? const ui.Color(0xFF000000);
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
    );
  }

  ui.Paragraph _buildTextParagraph(String text, _ResolvedTextStyle style) {
    final paragraphBuilder = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        fontSize: style.fontSize,
        fontFamily: style.fontFamily,
        fontWeight: style.fontWeight,
        fontStyle: style.fontStyle,
      ),
    );
    paragraphBuilder.pushStyle(
      ui.TextStyle(
        color: style.color,
        fontSize: style.fontSize,
        fontFamily: style.fontFamily,
        fontWeight: style.fontWeight,
        fontStyle: style.fontStyle,
        letterSpacing: style.letterSpacing,
        wordSpacing: style.wordSpacing,
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
    final normalized = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    return normalized.isEmpty ? null : normalized;
  }
}
