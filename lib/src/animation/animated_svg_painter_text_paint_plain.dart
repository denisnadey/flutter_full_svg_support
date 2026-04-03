part of 'animated_svg_painter.dart';

/// Extension for plain text and vertical text rendering.
extension AnimatedSvgPainterTextPlainExtension on AnimatedSvgPainter {
  double _paintPlainText(
    ui.Canvas canvas, {
    required SvgNode node,
    required String text,
    required _ResolvedTextStyle style,
    required double x,
    required double baselineY,
    bool ignoreTextLength = false,
    bool isFirstLine = false,
    bool isLastLine = true,
    ui.ImageFilter? imageFilter,
    ui.ColorFilter? colorFilter,
    ui.BlendMode? blendMode,
  }) {
    final isVertical = style.writingMode != _SvgWritingMode.horizontalTb;
    if (isVertical) {
      return _paintPlainTextVertical(
        canvas,
        node: node,
        text: text,
        style: style,
        x: x,
        baselineY: baselineY,
        isFirstLine: isFirstLine,
        isLastLine: isLastLine,
        imageFilter: imageFilter,
        colorFilter: colorFilter,
        blendMode: blendMode,
      );
    }
    var effectiveX = x;
    if (isFirstLine && style.textIndent != 0.0) effectiveX += style.textIndent;
    final hangingInfo = _calculateHangingPunctuation(
      text: text,
      style: style,
      isFirstLine: isFirstLine,
      isLastLine: isLastLine,
    );
    if (hangingInfo.startHangWidth > 0)
      effectiveX -= hangingInfo.startHangWidth;
    var effectiveStyle = style;
    var paragraph = _buildTextParagraph(text, effectiveStyle);
    var width = paragraph.maxIntrinsicWidth;
    var scaleX = 1.0;
    var usesParagraphWidthForAdvance = true;
    final targetLength = ignoreTextLength ? null : _resolveTextLength(node);
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
        usesParagraphWidthForAdvance = false;
      }
    }
    final hasLetterSpacingCompensation =
        text.runes.isNotEmpty && effectiveStyle.letterSpacing != 0.0;
    final anchorEdgeCompensation = hasLetterSpacingCompensation
        ? (effectiveStyle.letterSpacing * scaleX) / 2.0
        : 0.0;
    var drawX = effectiveX;
    var effectiveAnchor = effectiveStyle.textAnchor;
    if (effectiveStyle.textDirection == ui.TextDirection.rtl) {
      switch (effectiveStyle.textAnchor) {
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
        break;
      case _SvgTextAnchor.middle:
        drawX -= width / 2;
        break;
      case _SvgTextAnchor.end:
        drawX -= width;
        break;
    }
    if (anchorEdgeCompensation != 0.0) {
      switch (effectiveAnchor) {
        case _SvgTextAnchor.start:
          drawX -= anchorEdgeCompensation;
          break;
        case _SvgTextAnchor.middle:
          break;
        case _SvgTextAnchor.end:
          drawX += anchorEdgeCompensation;
          break;
      }
    }
    final drawY = _resolveTextTopFromBaseline(
      paragraph: paragraph,
      style: effectiveStyle,
      baselineY: baselineY,
    );
    final strokeParagraph = _buildStrokeTextParagraph(
      text,
      effectiveStyle,
      node,
    );
    // Performance optimization: Check if stroke is first without regex allocation.
    // paintOrder format is space-separated: "stroke fill markers" or similar.
    final paintOrder = effectiveStyle.paintOrder;
    final strokeFirst =
        strokeParagraph != null &&
        paintOrder.isNotEmpty &&
        paintOrder.startsWith('stroke');
    void drawFill() {
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
          style: effectiveStyle,
          text: text,
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
          style: effectiveStyle,
          text: text,
        );
      }
    }

    void drawStroke() {
      if (strokeParagraph == null) return;
      if ((scaleX - 1.0).abs() > 1e-6) {
        canvas.save();
        canvas.translate(drawX, 0.0);
        canvas.scale(scaleX, 1.0);
        canvas.drawParagraph(strokeParagraph, ui.Offset(0.0, drawY));
        canvas.restore();
      } else {
        canvas.drawParagraph(strokeParagraph, ui.Offset(drawX, drawY));
      }
    }

    if (strokeFirst) {
      drawStroke();
      drawFill();
    } else {
      drawFill();
      drawStroke();
    }
    if (usesParagraphWidthForAdvance && hasLetterSpacingCompensation) {
      width -= effectiveStyle.letterSpacing;
    }
    return width;
  }

  double _paintPlainTextVertical(
    ui.Canvas canvas, {
    required SvgNode node,
    required String text,
    required _ResolvedTextStyle style,
    required double x,
    required double baselineY,
    bool isFirstLine = false,
    bool isLastLine = true,
    ui.ImageFilter? imageFilter,
    ui.ColorFilter? colorFilter,
    ui.BlendMode? blendMode,
  }) {
    final glyphs = text.runes.map((r) => String.fromCharCode(r)).toList();
    if (glyphs.isEmpty) return 0.0;
    final hangingInfo = _calculateHangingPunctuation(
      text: text,
      style: style,
      isFirstLine: isFirstLine,
      isLastLine: isLastLine,
    );
    var totalHeight = 0.0;
    var cursorY = baselineY;
    if (hangingInfo.startHangWidth > 0) cursorY -= hangingInfo.startHangWidth;
    for (int i = 0; i < glyphs.length; i++) {
      final glyph = glyphs[i];
      final paragraph = _buildTextParagraph(glyph, style);
      final glyphWidth = paragraph.maxIntrinsicWidth;
      final glyphHeight = style.fontSize;
      canvas.save();
      canvas.translate(x, cursorY);
      canvas.rotate(math.pi / 2);
      _drawParagraphWithEffects(
        canvas,
        paragraph: paragraph,
        x: 0.0,
        y: -glyphWidth / 2,
        imageFilter: imageFilter,
        colorFilter: colorFilter,
        blendMode: blendMode,
        style: style,
        text: glyph,
      );
      canvas.restore();
      final spacing = i < glyphs.length - 1 ? style.letterSpacing : 0.0;
      cursorY += glyphHeight + spacing;
      totalHeight += glyphHeight + spacing;
    }
    return totalHeight;
  }
}
