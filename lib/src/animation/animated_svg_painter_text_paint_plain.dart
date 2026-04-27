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

    final svgFont = _resolveSvgFontDefinition(style);
    if (svgFont != null) {
      return _paintSvgFontText(
        canvas,
        node: node,
        text: text,
        style: style,
        font: svgFont,
        x: x,
        baselineY: baselineY,
        isFirstLine: isFirstLine,
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
    if (hangingInfo.startHangWidth > 0) {
      effectiveX -= hangingInfo.startHangWidth;
    }
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
    final fillValue = _getInheritedAttributeValue(node, 'fill');
    final strokeValue = _getInheritedAttributeValue(node, 'stroke');
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

    ui.Rect paragraphBoundsAt(double x) => ui.Rect.fromLTWH(
      x,
      drawY,
      paragraph.maxIntrinsicWidth,
      paragraph.height,
    );

    ui.Rect strokeParagraphBoundsAt(double x) => ui.Rect.fromLTWH(
      x,
      drawY,
      strokeParagraph?.maxIntrinsicWidth ?? paragraph.maxIntrinsicWidth,
      strokeParagraph?.height ?? paragraph.height,
    );

    void drawFill() {
      if (_isPaintNone(fillValue)) {
        return;
      }

      bool drawWithShader(double x) {
        if (fillValue == null) {
          return false;
        }
        final shader = _resolvePaintServerShader(
          fillValue,
          paragraphBoundsAt(x),
        );
        if (shader == null) {
          return false;
        }
        final shaderPaint = ui.Paint()
          ..style = ui.PaintingStyle.fill
          ..shader = shader
          ..color = const ui.Color(
            0xFFFFFFFF,
          ).withValues(alpha: effectiveStyle.color.a);
        final shaderParagraph = _buildTextParagraph(
          text,
          effectiveStyle,
          foregroundPaint: shaderPaint,
        );
        _drawParagraphWithEffects(
          canvas,
          paragraph: shaderParagraph,
          x: x,
          y: drawY,
          imageFilter: imageFilter,
          colorFilter: colorFilter,
          blendMode: blendMode,
          style: effectiveStyle,
          text: text,
        );
        return true;
      }

      if ((scaleX - 1.0).abs() > 1e-6) {
        canvas.save();
        canvas.translate(drawX, 0.0);
        canvas.scale(scaleX, 1.0);
        if (!drawWithShader(0.0)) {
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
        }
        canvas.restore();
      } else {
        if (!drawWithShader(drawX)) {
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
    }

    void drawStroke() {
      if (strokeParagraph == null) return;
      bool drawWithShader(double x) {
        if (strokeValue == null) {
          return false;
        }
        final shader = _resolvePaintServerShader(
          strokeValue,
          strokeParagraphBoundsAt(x),
        );
        if (shader == null) {
          return false;
        }
        final shaderStrokeParagraph = _buildStrokeTextParagraph(
          text,
          effectiveStyle,
          node,
          strokeShader: shader,
        );
        if (shaderStrokeParagraph == null) return false;
        canvas.drawParagraph(shaderStrokeParagraph, ui.Offset(x, drawY));
        return true;
      }

      if ((scaleX - 1.0).abs() > 1e-6) {
        canvas.save();
        canvas.translate(drawX, 0.0);
        canvas.scale(scaleX, 1.0);
        if (!drawWithShader(0.0)) {
          canvas.drawParagraph(strokeParagraph, ui.Offset(0.0, drawY));
        }
        canvas.restore();
      } else {
        if (!drawWithShader(drawX)) {
          canvas.drawParagraph(strokeParagraph, ui.Offset(drawX, drawY));
        }
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
      final isUpright = _isGlyphUprightInVertical(
        glyph,
        style.glyphOrientationVertical,
      );
      canvas.save();
      canvas.translate(x, cursorY);
      if (isUpright) {
        // Upright (CJK or explicit glyph-orientation-vertical=0): center on column axis.
        _drawParagraphWithEffects(
          canvas,
          paragraph: paragraph,
          x: -glyphWidth / 2,
          y: 0.0,
          imageFilter: imageFilter,
          colorFilter: colorFilter,
          blendMode: blendMode,
          style: style,
          text: glyph,
        );
      } else {
        // Rotated 90° clockwise (default for Latin/non-CJK in vertical text).
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
      }
      canvas.restore();
      final spacing = i < glyphs.length - 1 ? style.letterSpacing : 0.0;
      cursorY += glyphHeight + spacing;
      totalHeight += glyphHeight + spacing;
    }
    return totalHeight;
  }

  /// Returns true if the glyph should be drawn upright in vertical text.
  ///
  /// Per SVG 1.1 / CSS Writing Modes:
  /// - glyph-orientation-vertical="0"  → upright for all glyphs.
  /// - glyph-orientation-vertical="90" → rotated for all glyphs.
  /// - auto (null / default)            → CJK and fullwidth chars upright,
  ///                                      others rotated 90°.
  bool _isGlyphUprightInVertical(
    String glyph,
    double? glyphOrientationVertical,
  ) {
    if (glyphOrientationVertical != null) {
      return glyphOrientationVertical.abs() < 1.0;
    }
    if (glyph.isEmpty) return false;
    return _isCjkOrFullwidthRune(glyph.runes.first);
  }

  /// True for code points that are naturally upright in vertical text (CJK,
  /// fullwidth, Hangul, and related blocks per Unicode vertical orientation).
  bool _isCjkOrFullwidthRune(int cp) {
    return (cp >= 0x1100 && cp <= 0x11FF) || // Hangul Jamo
        (cp >= 0x2E80 && cp <= 0x2FFF) || // CJK Radicals / KangXi
        (cp >= 0x3000 &&
            cp <= 0x9FFF) || // CJK Symbols, Hiragana, Katakana, Unified
        (cp >= 0xA000 && cp <= 0xA4FF) || // Yi
        (cp >= 0xAC00 && cp <= 0xD7FF) || // Hangul Syllables
        (cp >= 0xF900 && cp <= 0xFAFF) || // CJK Compatibility Ideographs
        (cp >= 0xFE30 && cp <= 0xFE4F) || // CJK Compatibility Forms
        (cp >= 0xFF00 && cp <= 0xFFEF) || // Fullwidth / Halfwidth
        (cp >= 0x20000 && cp <= 0x2A6DF); // CJK Extension B
  }
}
