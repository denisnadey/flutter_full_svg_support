part of 'animated_svg_painter.dart';

/// Extension for per-character glyph positioning in text rendering.
extension AnimatedSvgPainterTextGlyphExtension on AnimatedSvgPainter {
  double _paintPlainTextWithPositions(
    ui.Canvas canvas, {
    required SvgNode node,
    required String text,
    required _ResolvedTextStyle style,
    required _TextCursor cursor,
    required List<double> xList,
    required List<double> yList,
    required List<double> dxList,
    required List<double> dyList,
    List<double> rotateList = const <double>[],
    bool startsNewChunk = false,
    ui.ImageFilter? imageFilter,
    ui.ColorFilter? colorFilter,
    ui.BlendMode? blendMode,
    _ResolvedTextStyle? parentStyle,
  }) {
    final glyphs = text.runes.map((r) => String.fromCharCode(r)).toList();
    final hasMultiPositions = xList.length > 1 || yList.length > 1 || dxList.length > 1 || dyList.length > 1 || rotateList.isNotEmpty;
    final hasExplicitPositions = xList.length > 1 || yList.length > 1;
    if (!hasMultiPositions) {
      return _paintPlainText(
        canvas,
        node: node,
        text: text,
        style: style,
        x: cursor.x,
        baselineY: cursor.y,
        ignoreTextLength: hasExplicitPositions,
        isFirstLine: cursor.isFirstLine,
        imageFilter: imageFilter,
        colorFilter: colorFilter,
        blendMode: blendMode,
      );
    }
    var totalWidth = 0.0;
    double anchorOffset = 0.0;
    if (startsNewChunk || cursor.chunkCharIndex == 0) {
      final chunkParagraph = _buildTextParagraph(text, style);
      final chunkWidth = chunkParagraph.maxIntrinsicWidth;
      var effectiveAnchor = style.textAnchor;
      if (style.textDirection == ui.TextDirection.rtl) {
        switch (style.textAnchor) {
          case _SvgTextAnchor.start:
            effectiveAnchor = _SvgTextAnchor.end;
            break;
          case _SvgTextAnchor.end:
            effectiveAnchor = _SvgTextAnchor.start;
            break;
          case _SvgTextAnchor.middle:
            effectiveAnchor = _SvgTextAnchor.middle;
            break;
        }
      }
      switch (effectiveAnchor) {
        case _SvgTextAnchor.start:
          anchorOffset = 0.0;
          break;
        case _SvgTextAnchor.middle:
          anchorOffset = -chunkWidth / 2;
          break;
        case _SvgTextAnchor.end:
          anchorOffset = -chunkWidth;
          break;
      }
    }
    double textIndentOffset = 0.0;
    if (cursor.isFirstLine && style.textIndent != 0.0) {
      textIndentOffset = style.textIndent;
      cursor.isFirstLine = false;
    }
    final hangingInfo = _calculateHangingPunctuation(text: text, style: style, isFirstLine: true, isLastLine: true);
    double startHangOffset = 0.0;
    if (hangingInfo.startHangWidth > 0) startHangOffset = -hangingInfo.startHangWidth;
    double mixedBaselineOffset = 0.0;
    if (parentStyle != null && parentStyle.fontSize != style.fontSize) {
      final parentParagraph = _buildTextParagraph('X', parentStyle);
      final childParagraph = _buildTextParagraph('X', style);
      final parentBaseline = parentParagraph.alphabeticBaseline;
      final childBaseline = childParagraph.alphabeticBaseline;
      mixedBaselineOffset = parentBaseline - childBaseline;
    }
    final paintOrderParts = style.paintOrder.split(RegExp(r'\s+'));
    final strokeFirst = paintOrderParts.isNotEmpty && paintOrderParts.first == 'stroke';
    for (int i = 0; i < glyphs.length; i++) {
      final charIdx = cursor.charIndex + i;
      if (charIdx < xList.length) cursor.x = xList[charIdx];
      if (charIdx < yList.length) cursor.y = yList[charIdx];
      if (charIdx < dxList.length) cursor.x += dxList[charIdx];
      if (charIdx < dyList.length) cursor.y += dyList[charIdx];
      final rotation = rotateList.isNotEmpty ? rotateList[charIdx.clamp(0, rotateList.length - 1)] : 0.0;
      final glyph = glyphs[i];
      final paragraph = _buildTextParagraph(glyph, style);
      final glyphWidth = paragraph.maxIntrinsicWidth;
      var drawX = cursor.x + (i == 0 ? anchorOffset + textIndentOffset + startHangOffset : 0.0);
      final drawY = _resolveTextTopFromBaseline(paragraph: paragraph, style: style, baselineY: cursor.y + mixedBaselineOffset);
      final strokeParagraph = _buildStrokeTextParagraph(glyph, style, node);
      if (rotation != 0.0) {
        canvas.save();
        canvas.translate(drawX, cursor.y);
        canvas.rotate(rotation * 3.1415926535897932 / 180.0);
        canvas.translate(-drawX, -cursor.y);
      }
      if (strokeFirst && strokeParagraph != null) {
        canvas.drawParagraph(strokeParagraph, ui.Offset(drawX, drawY));
        _drawParagraphWithEffects(canvas, paragraph: paragraph, x: drawX, y: drawY, imageFilter: imageFilter, colorFilter: colorFilter, blendMode: blendMode, style: style, text: glyph);
      } else {
        _drawParagraphWithEffects(canvas, paragraph: paragraph, x: drawX, y: drawY, imageFilter: imageFilter, colorFilter: colorFilter, blendMode: blendMode, style: style, text: glyph);
        if (strokeParagraph != null) canvas.drawParagraph(strokeParagraph, ui.Offset(drawX, drawY));
      }
      if (rotation != 0.0) canvas.restore();
      cursor.x += glyphWidth + style.letterSpacing;
      totalWidth += glyphWidth + style.letterSpacing;
    }
    cursor.charIndex += glyphs.length;
    cursor.chunkCharIndex += glyphs.length;
    return totalWidth;
  }
}
