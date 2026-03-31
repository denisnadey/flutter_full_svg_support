part of 'animated_svg_painter.dart';

/// Extension for text path rendering functionality.
extension AnimatedSvgPainterTextPathExtension on AnimatedSvgPainter {
  double _paintTextPathNode(
    ui.Canvas canvas,
    SvgNode textPathNode, {
    ui.ImageFilter? imageFilter,
    ui.ColorFilter? colorFilter,
    ui.BlendMode? blendMode,
  }) {
    final path = _resolveTextPathGeometry(textPathNode);
    if (path == null) return 0.0;
    final metricIterator = path.computeMetrics().iterator;
    if (!metricIterator.moveNext()) return 0.0;
    final metric = metricIterator.current;
    if (metric.length <= 0) return 0.0;
    final isClosed = metric.isClosed;
    final spacing = _resolveTextPathSpacing(textPathNode);
    final method = _resolveTextPathMethod(textPathNode);
    double offset = _parseTextPathStartOffset(textPathNode, metric.length);
    var consumed = 0.0;

    // Compute textLength distribution for textPath with nested tspan children.
    final textPathStyle = _resolveTextStyle(textPathNode);
    final hasTspanChildren = textPathNode.children.any(
      (c) => c.tagName == 'tspan',
    );
    _TextLengthDistribution? textLengthDistribution;
    if (hasTspanChildren && _resolveTextLength(textPathNode) != null) {
      textLengthDistribution = _computeTextLengthDistribution(
        textPathNode,
        textPathStyle,
      );
    }

    final directText = _extractTextContent(textPathNode);
    if (directText != null && directText.isNotEmpty) {
      final style = _resolveTextStyle(textPathNode);
      final textConsumed = _paintTextAlongPath(
        canvas,
        layoutNode: textPathNode,
        text: directText,
        style: style,
        metric: metric,
        startOffset: offset,
        spacing: spacing,
        method: method,
        isClosed: isClosed,
        imageFilter: imageFilter,
        colorFilter: colorFilter,
        blendMode: blendMode,
        textLengthDistribution: textLengthDistribution,
      );
      offset += textConsumed;
      consumed += textConsumed;
    }
    for (final child in textPathNode.children) {
      if (child.tagName != 'tspan') continue;
      final childText = _extractTextContent(child);
      if (childText == null || childText.isEmpty) continue;
      final style = _resolveTextStyle(child, parentStyle: textPathStyle);
      final textConsumed = _paintTextAlongPath(
        canvas,
        layoutNode: child,
        text: childText,
        style: style,
        metric: metric,
        startOffset: offset,
        spacing: spacing,
        method: method,
        isClosed: isClosed,
        imageFilter: imageFilter,
        colorFilter: colorFilter,
        blendMode: blendMode,
        textLengthDistribution: textLengthDistribution,
      );
      offset += textConsumed;
      consumed += textConsumed;
    }
    return consumed;
  }

  double _paintTextAlongPath(
    ui.Canvas canvas, {
    required SvgNode layoutNode,
    required String text,
    required _ResolvedTextStyle style,
    required ui.PathMetric metric,
    required double startOffset,
    required _SvgTextPathSpacing spacing,
    _SvgTextPathMethod method = _SvgTextPathMethod.align,
    bool isClosed = false,
    ui.ImageFilter? imageFilter,
    ui.ColorFilter? colorFilter,
    ui.BlendMode? blendMode,
    _TextLengthDistribution? textLengthDistribution,
  }) {
    final glyphs = text.runes
        .map((rune) => String.fromCharCode(rune))
        .toList(growable: false);
    if (glyphs.isEmpty) return 0.0;
    final paragraphs = glyphs
        .map((glyph) => _buildTextParagraph(glyph, style))
        .toList(growable: false);
    final strokeParagraphs = glyphs
        .map((glyph) => _buildStrokeTextParagraph(glyph, style, layoutNode))
        .toList(growable: false);
    final widths = paragraphs
        .map((paragraph) => paragraph.maxIntrinsicWidth)
        .toList(growable: false);
    final advances = <double>[];
    for (int i = 0; i < glyphs.length; i++) {
      final glyphSpacing = spacing == _SvgTextPathSpacing.auto
          ? _textPathSpacingAfterGlyph(
              glyph: glyphs[i],
              isLast: i == glyphs.length - 1,
              style: style,
            )
          : 0.0;
      advances.add(widths[i] + glyphSpacing);
    }
    final displayWidths = List<double>.from(widths);
    final displayAdvances = List<double>.from(advances);
    var totalWidth = displayAdvances.fold<double>(0.0, (sum, w) => sum + w);
    var glyphScaleX = 1.0;
    final availableLength = metric.length - startOffset;
    if (method == _SvgTextPathMethod.stretch && totalWidth > 0) {
      final stretchFactor = availableLength / totalWidth;
      glyphScaleX = stretchFactor;
      for (int i = 0; i < displayWidths.length; i++) {
        displayWidths[i] *= stretchFactor;
        displayAdvances[i] *= stretchFactor;
      }
      totalWidth = availableLength;
    }

    // Apply textLength distribution from parent if provided.
    // This takes precedence over local textLength when the parent has nested
    // tspan children with textLength set on the parent.
    final targetLength = _resolveTextLength(layoutNode);
    final bool useInheritedDistribution =
        textLengthDistribution != null &&
        !textLengthDistribution.isNone &&
        targetLength == null;

    if (useInheritedDistribution) {
      if (textLengthDistribution.isSpacing && glyphs.length > 1) {
        for (int i = 0; i < displayAdvances.length - 1; i++) {
          displayAdvances[i] += textLengthDistribution.extraSpacing;
        }
      } else if (textLengthDistribution.isScale) {
        glyphScaleX *= textLengthDistribution.scaleFactor;
        for (int i = 0; i < displayWidths.length; i++) {
          displayWidths[i] *= textLengthDistribution.scaleFactor;
          displayAdvances[i] *= textLengthDistribution.scaleFactor;
        }
      }
      totalWidth = displayAdvances.fold<double>(0.0, (sum, w) => sum + w);
    } else if (targetLength != null && targetLength > 0 && totalWidth > 0) {
      final lengthAdjust = _resolveLengthAdjust(layoutNode);
      if (lengthAdjust == _SvgTextLengthAdjust.spacing && glyphs.length > 1) {
        final extraSpacing = (targetLength - totalWidth) / (glyphs.length - 1);
        for (int i = 0; i < displayAdvances.length - 1; i++) {
          displayAdvances[i] += extraSpacing;
        }
      } else {
        glyphScaleX = targetLength / totalWidth;
        for (int i = 0; i < displayWidths.length; i++) {
          displayWidths[i] *= glyphScaleX;
          displayAdvances[i] *= glyphScaleX;
        }
      }
      totalWidth = displayAdvances.fold<double>(0.0, (sum, w) => sum + w);
    }
    var drawOffset = startOffset;
    switch (style.textAnchor) {
      case _SvgTextAnchor.start:
        break;
      case _SvgTextAnchor.middle:
        drawOffset -= totalWidth / 2;
        break;
      case _SvgTextAnchor.end:
        drawOffset -= totalWidth;
        break;
    }
    final needsLayer =
        imageFilter != null || colorFilter != null || blendMode != null;
    if (needsLayer) {
      final layerPaint = ui.Paint();
      if (imageFilter != null) layerPaint.imageFilter = imageFilter;
      if (colorFilter != null) layerPaint.colorFilter = colorFilter;
      if (blendMode != null) layerPaint.blendMode = blendMode;
      final pathBounds = metric
          .extractPath(0.0, metric.length)
          .getBounds()
          .inflate(style.fontSize * 2.0);
      canvas.saveLayer(pathBounds, layerPaint);
    }
    // Performance optimization: Check if stroke is first without regex allocation.
    // paintOrder format is space-separated: "stroke fill markers" or similar.
    final paintOrder = style.paintOrder;
    final strokeFirst =
        paintOrder.isNotEmpty && paintOrder.startsWith('stroke');
    var consumed = 0.0;
    var cursor = drawOffset;
    for (int i = 0; i < paragraphs.length; i++) {
      final paragraph = paragraphs[i];
      final glyphWidth = widths[i];
      final displayWidth = displayWidths[i];
      final glyphAdvance = displayAdvances[i];
      double effectiveCenter;
      if (isClosed) {
        effectiveCenter = (cursor + displayWidth / 2) % metric.length;
        if (effectiveCenter < 0) effectiveCenter += metric.length;
      } else {
        effectiveCenter = (cursor + displayWidth / 2).clamp(0.0, metric.length);
        if (cursor > metric.length) break;
      }
      final tangent = metric.getTangentForOffset(effectiveCenter);
      if (tangent == null) {
        cursor += glyphAdvance;
        consumed += glyphAdvance;
        continue;
      }
      final baselineRef = _resolveBaselineReference(
        paragraph: paragraph,
        dominantBaseline: style.dominantBaseline,
      );
      final strokeParagraph = strokeParagraphs[i];
      final drawX = -glyphWidth / 2;
      final drawY = -baselineRef - style.baselineShift;
      canvas.save();
      canvas.translate(tangent.position.dx, tangent.position.dy);
      canvas.rotate(tangent.angle);
      if ((glyphScaleX - 1.0).abs() > 1e-6) canvas.scale(glyphScaleX, 1.0);
      if (strokeFirst && strokeParagraph != null) {
        canvas.drawParagraph(strokeParagraph, ui.Offset(drawX, drawY));
        _drawParagraphWithEffects(
          canvas,
          paragraph: paragraph,
          x: drawX,
          y: drawY,
          style: style,
          text: glyphs[i],
        );
      } else {
        _drawParagraphWithEffects(
          canvas,
          paragraph: paragraph,
          x: drawX,
          y: drawY,
          style: style,
          text: glyphs[i],
        );
        if (strokeParagraph != null)
          canvas.drawParagraph(strokeParagraph, ui.Offset(drawX, drawY));
      }
      canvas.restore();
      cursor += glyphAdvance;
      consumed += glyphAdvance;
    }
    if (needsLayer) canvas.restore();
    return consumed;
  }
}
