part of 'animated_svg_painter.dart';

extension AnimatedSvgPainterTextPaintExtension on AnimatedSvgPainter {
  void _paintText(
    ui.Canvas canvas,
    SvgNode node, {
    ui.ImageFilter? imageFilter,
    ui.ColorFilter? colorFilter,
    ui.BlendMode? blendMode,
  }) {
    final startX = _getNumber(node, 'x') ?? 0.0;
    final startY = _getNumber(node, 'y') ?? 0.0;
    final cursor = _TextCursor(x: startX, y: startY);

    _paintTextNode(
      canvas,
      node,
      cursor,
      imageFilter: imageFilter,
      colorFilter: colorFilter,
      blendMode: blendMode,
    );
  }

  void _paintTextNode(
    ui.Canvas canvas,
    SvgNode node,
    _TextCursor cursor, {
    ui.ImageFilter? imageFilter,
    ui.ColorFilter? colorFilter,
    ui.BlendMode? blendMode,
  }) {
    final x = _getNumber(node, 'x');
    final y = _getNumber(node, 'y');
    final dx = _getNumber(node, 'dx') ?? 0.0;
    final dy = _getNumber(node, 'dy') ?? 0.0;

    if (x != null) {
      cursor.x = x;
    }
    if (y != null) {
      cursor.y = y;
    }
    cursor
      ..x += dx
      ..y += dy;

    final style = _resolveTextStyle(node);
    final text = _extractTextContent(node);
    if (text != null && text.isNotEmpty) {
      final consumed = _paintPlainText(
        canvas,
        node: node,
        text: text,
        style: style,
        x: cursor.x,
        baselineY: cursor.y,
        imageFilter: imageFilter,
        colorFilter: colorFilter,
        blendMode: blendMode,
      );
      cursor.x += consumed;
    }

    for (final child in node.children) {
      if (child.tagName == 'tspan') {
        _paintTextNode(
          canvas,
          child,
          cursor,
          imageFilter: imageFilter,
          colorFilter: colorFilter,
          blendMode: blendMode,
        );
      } else if (child.tagName == 'textPath') {
        final consumed = _paintTextPathNode(
          canvas,
          child,
          imageFilter: imageFilter,
          colorFilter: colorFilter,
          blendMode: blendMode,
        );
        cursor.x += consumed;
      }
    }
  }

  double _paintTextPathNode(
    ui.Canvas canvas,
    SvgNode textPathNode, {
    ui.ImageFilter? imageFilter,
    ui.ColorFilter? colorFilter,
    ui.BlendMode? blendMode,
  }) {
    final path = _resolveTextPathGeometry(textPathNode);
    if (path == null) {
      return 0.0;
    }
    final metricIterator = path.computeMetrics().iterator;
    if (!metricIterator.moveNext()) {
      return 0.0;
    }
    final metric = metricIterator.current;
    if (metric.length <= 0) {
      return 0.0;
    }

    double offset = _parseTextPathStartOffset(textPathNode, metric.length);
    var consumed = 0.0;

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
        imageFilter: imageFilter,
        colorFilter: colorFilter,
        blendMode: blendMode,
      );
      offset += textConsumed;
      consumed += textConsumed;
    }

    for (final child in textPathNode.children) {
      if (child.tagName != 'tspan') {
        continue;
      }
      final childText = _extractTextContent(child);
      if (childText == null || childText.isEmpty) {
        continue;
      }
      final style = _resolveTextStyle(child);
      final textConsumed = _paintTextAlongPath(
        canvas,
        layoutNode: child,
        text: childText,
        style: style,
        metric: metric,
        startOffset: offset,
        imageFilter: imageFilter,
        colorFilter: colorFilter,
        blendMode: blendMode,
      );
      offset += textConsumed;
      consumed += textConsumed;
    }

    return consumed;
  }

  double _paintPlainText(
    ui.Canvas canvas, {
    required SvgNode node,
    required String text,
    required _ResolvedTextStyle style,
    required double x,
    required double baselineY,
    ui.ImageFilter? imageFilter,
    ui.ColorFilter? colorFilter,
    ui.BlendMode? blendMode,
  }) {
    var effectiveStyle = style;
    var paragraph = _buildTextParagraph(text, effectiveStyle);
    var width = paragraph.maxIntrinsicWidth;
    var scaleX = 1.0;
    final targetLength = _resolveTextLength(node);
    if (targetLength != null && targetLength > 0 && width > 0) {
      final lengthAdjust = _resolveLengthAdjust(node);
      final glyphCount = text.runes.length;
      if (lengthAdjust == _SvgTextLengthAdjust.spacing && glyphCount > 1) {
        final extraSpacing = (targetLength - width) / (glyphCount - 1);
        effectiveStyle = effectiveStyle.copyWith(
          letterSpacing: effectiveStyle.letterSpacing + extraSpacing,
        );
        paragraph = _buildTextParagraph(text, effectiveStyle);
        width = paragraph.maxIntrinsicWidth;
      } else {
        scaleX = targetLength / width;
        width = targetLength;
      }
    }

    var drawX = x;
    switch (effectiveStyle.textAnchor) {
      case _SvgTextAnchor.start:
        break;
      case _SvgTextAnchor.middle:
        drawX -= width / 2;
        break;
      case _SvgTextAnchor.end:
        drawX -= width;
        break;
    }
    final drawY = _resolveTextTopFromBaseline(
      paragraph: paragraph,
      style: effectiveStyle,
      baselineY: baselineY,
    );

    if ((scaleX - 1.0).abs() > 1e-6) {
      canvas.save();
      canvas.translate(drawX, 0.0);
      canvas.scale(scaleX, 1.0);
      _drawParagraphWithEffects(
        canvas,
        paragraph: paragraph,
        x: 0.0,
        y: drawY,
        imageFilter: imageFilter,
        colorFilter: colorFilter,
        blendMode: blendMode,
      );
      canvas.restore();
    } else {
      _drawParagraphWithEffects(
        canvas,
        paragraph: paragraph,
        x: drawX,
        y: drawY,
        imageFilter: imageFilter,
        colorFilter: colorFilter,
        blendMode: blendMode,
      );
    }
    return width;
  }

  double _paintTextAlongPath(
    ui.Canvas canvas, {
    required SvgNode layoutNode,
    required String text,
    required _ResolvedTextStyle style,
    required ui.PathMetric metric,
    required double startOffset,
    ui.ImageFilter? imageFilter,
    ui.ColorFilter? colorFilter,
    ui.BlendMode? blendMode,
  }) {
    final glyphs = text.runes
        .map((rune) => String.fromCharCode(rune))
        .toList(growable: false);
    if (glyphs.isEmpty) {
      return 0.0;
    }

    final paragraphs = glyphs
        .map((glyph) => _buildTextParagraph(glyph, style))
        .toList(growable: false);
    final widths = paragraphs
        .map((paragraph) => paragraph.maxIntrinsicWidth)
        .toList(growable: false);
    final advances = <double>[];
    for (int i = 0; i < glyphs.length; i++) {
      final spacing = _textPathSpacingAfterGlyph(
        glyph: glyphs[i],
        isLast: i == glyphs.length - 1,
        style: style,
      );
      advances.add(widths[i] + spacing);
    }
    final displayWidths = List<double>.from(widths);
    final displayAdvances = List<double>.from(advances);
    var totalWidth = displayAdvances.fold<double>(0.0, (sum, w) => sum + w);
    var glyphScaleX = 1.0;
    final targetLength = _resolveTextLength(layoutNode);
    if (targetLength != null && targetLength > 0 && totalWidth > 0) {
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
      if (imageFilter != null) {
        layerPaint.imageFilter = imageFilter;
      }
      if (colorFilter != null) {
        layerPaint.colorFilter = colorFilter;
      }
      if (blendMode != null) {
        layerPaint.blendMode = blendMode;
      }
      final pathBounds = metric
          .extractPath(0.0, metric.length)
          .getBounds()
          .inflate(style.fontSize * 2.0);
      canvas.saveLayer(pathBounds, layerPaint);
    }

    var consumed = 0.0;
    var cursor = drawOffset;
    for (int i = 0; i < paragraphs.length; i++) {
      final paragraph = paragraphs[i];
      final glyphWidth = widths[i];
      final displayWidth = displayWidths[i];
      final glyphAdvance = displayAdvances[i];
      final center = (cursor + displayWidth / 2).clamp(0.0, metric.length);
      final tangent = metric.getTangentForOffset(center);
      if (tangent == null) {
        cursor += glyphAdvance;
        consumed += glyphAdvance;
        continue;
      }

      final baselineRef = _resolveBaselineReference(
        paragraph: paragraph,
        dominantBaseline: style.dominantBaseline,
      );
      canvas.save();
      canvas.translate(tangent.position.dx, tangent.position.dy);
      canvas.rotate(tangent.angle);
      if ((glyphScaleX - 1.0).abs() > 1e-6) {
        canvas.scale(glyphScaleX, 1.0);
      }
      canvas.drawParagraph(
        paragraph,
        ui.Offset(-glyphWidth / 2, -baselineRef - style.baselineShift),
      );
      canvas.restore();

      cursor += glyphAdvance;
      consumed += glyphAdvance;
      if (cursor > metric.length + style.fontSize) {
        break;
      }
    }

    if (needsLayer) {
      canvas.restore();
    }
    return consumed;
  }
}
