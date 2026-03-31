part of 'animated_svg_painter.dart';

/// Extension for per-character glyph positioning in text rendering.
///
/// Supports grapheme cluster-aware rendering for proper handling of:
/// - Combining marks and diacritics (e.g., 'e' + combining acute = 'é')
/// - Complex scripts (Arabic, Thai, Devanagari, Bengali, Tamil)
/// - Emoji sequences (ZWJ, skin tone modifiers, flags)
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
    _TextLengthDistribution? textLengthDistribution,
  }) {
    // Apply NFC normalization per SVG spec
    final normalizedText = _normalizeTextToNFC(text);
    
    // Detect script type for appropriate handling
    final scriptType = _detectScriptType(normalizedText);
    final isComplexScript = _isComplexScript(scriptType);
    
    // Use grapheme clusters instead of runes for proper character handling
    // This ensures combining marks and multi-codepoint characters are treated as single units
    final glyphs = _segmentIntoGraphemeClusters(normalizedText);
    final hasMultiPositions =
        xList.length > 1 ||
        yList.length > 1 ||
        dxList.length > 1 ||
        dyList.length > 1 ||
        rotateList.isNotEmpty;
    final hasExplicitPositions = xList.length > 1 || yList.length > 1;
    
    // For complex scripts with no multi-positions, render as a single unit
    // to allow proper shaping and ligature formation
    if (isComplexScript && !hasMultiPositions && !hasExplicitPositions) {
      return _paintComplexScriptText(
        canvas,
        node: node,
        text: normalizedText,
        style: style,
        cursor: cursor,
        scriptType: scriptType,
        imageFilter: imageFilter,
        colorFilter: colorFilter,
        blendMode: blendMode,
      );
    }

    // Compute accumulated transform for deeply nested tspan elements.
    // This ensures per-character positions are resolved in the correct
    // coordinate space when transforms are applied at multiple nesting levels.
    final accumulatedTransform = _computeTextElementAccumulatedTransform(node);
    final hasAccumulatedTransform = !accumulatedTransform.isIdentity();

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
    final hangingInfo = _calculateHangingPunctuation(
      text: text,
      style: style,
      isFirstLine: true,
      isLastLine: true,
    );
    double startHangOffset = 0.0;
    if (hangingInfo.startHangWidth > 0)
      startHangOffset = -hangingInfo.startHangWidth;
    double mixedBaselineOffset = 0.0;
    if (parentStyle != null && parentStyle.fontSize != style.fontSize) {
      final parentParagraph = _buildTextParagraph('X', parentStyle);
      final childParagraph = _buildTextParagraph('X', style);
      final parentBaseline = parentParagraph.alphabeticBaseline;
      final childBaseline = childParagraph.alphabeticBaseline;
      mixedBaselineOffset = parentBaseline - childBaseline;
    }
    // Performance optimization: Check if stroke is first without regex allocation.
    // paintOrder format is space-separated: "stroke fill markers" or similar.
    final paintOrder = style.paintOrder;
    final strokeFirst =
        paintOrder.isNotEmpty && paintOrder.startsWith('stroke');

    // Compute scale factor from textLength distribution if using spacingAndGlyphs mode.
    final scaleFactor = textLengthDistribution != null &&
            textLengthDistribution.isScale
        ? textLengthDistribution.scaleFactor
        : 1.0;
    final hasScaleFactor = (scaleFactor - 1.0).abs() > 1e-6;

    for (int i = 0; i < glyphs.length; i++) {
      final charIdx = cursor.charIndex + i;
      if (charIdx < xList.length) cursor.x = xList[charIdx];
      if (charIdx < yList.length) cursor.y = yList[charIdx];
      if (charIdx < dxList.length) cursor.x += dxList[charIdx];
      if (charIdx < dyList.length) cursor.y += dyList[charIdx];
      final rotation = rotateList.isNotEmpty
          ? rotateList[charIdx.clamp(0, rotateList.length - 1)]
          : 0.0;
      final glyph = glyphs[i];
      final paragraph = _buildTextParagraph(glyph, style);
      final glyphWidth = paragraph.maxIntrinsicWidth;
      var drawX =
          cursor.x +
          (i == 0 ? anchorOffset + textIndentOffset + startHangOffset : 0.0);
      var drawY = _resolveTextTopFromBaseline(
        paragraph: paragraph,
        style: style,
        baselineY: cursor.y + mixedBaselineOffset,
      );

      // Apply accumulated transform for deeply nested tspan elements.
      // This correctly positions glyphs when transforms exist at multiple
      // ancestor levels in the tspan hierarchy.
      if (hasAccumulatedTransform) {
        final transformedPos = _transformPointForText(
          ui.Offset(drawX, drawY),
          accumulatedTransform,
        );
        drawX = transformedPos.dx;
        drawY = transformedPos.dy;
      }

      final strokeParagraph = _buildStrokeTextParagraph(glyph, style, node);
      final needsCanvasSave = rotation != 0.0 || hasScaleFactor;
      if (needsCanvasSave) {
        canvas.save();
        if (hasScaleFactor) {
          canvas.translate(drawX, 0.0);
          canvas.scale(scaleFactor, 1.0);
          drawX = 0.0;
        }
        if (rotation != 0.0) {
          final pivotX = hasScaleFactor ? 0.0 : drawX;
          canvas.translate(pivotX, cursor.y);
          canvas.rotate(rotation * 3.1415926535897932 / 180.0);
          canvas.translate(-pivotX, -cursor.y);
        }
      }
      if (strokeFirst && strokeParagraph != null) {
        canvas.drawParagraph(strokeParagraph, ui.Offset(drawX, drawY));
        _drawParagraphWithEffects(
          canvas,
          paragraph: paragraph,
          x: drawX,
          y: drawY,
          imageFilter: imageFilter,
          colorFilter: colorFilter,
          blendMode: blendMode,
          style: style,
          text: glyph,
        );
      } else {
        _drawParagraphWithEffects(
          canvas,
          paragraph: paragraph,
          x: drawX,
          y: drawY,
          imageFilter: imageFilter,
          colorFilter: colorFilter,
          blendMode: blendMode,
          style: style,
          text: glyph,
        );
        if (strokeParagraph != null)
          canvas.drawParagraph(strokeParagraph, ui.Offset(drawX, drawY));
      }
      if (needsCanvasSave) canvas.restore();
      final scaledWidth = glyphWidth * scaleFactor;
      cursor.x += scaledWidth + style.letterSpacing;
      totalWidth += scaledWidth + style.letterSpacing;
    }
    cursor.charIndex += glyphs.length;
    cursor.chunkCharIndex += glyphs.length;
    return totalWidth;
  }
  
  /// Renders complex script text as a single unit for proper shaping.
  ///
  /// Complex scripts like Arabic, Thai, Devanagari require contextual shaping
  /// where glyphs change form based on their neighbors. Rendering the entire
  /// text run together allows the text engine to apply proper ligatures,
  /// conjuncts, and contextual alternates.
  double _paintComplexScriptText(
    ui.Canvas canvas, {
    required SvgNode node,
    required String text,
    required _ResolvedTextStyle style,
    required _TextCursor cursor,
    required _ScriptType scriptType,
    ui.ImageFilter? imageFilter,
    ui.ColorFilter? colorFilter,
    ui.BlendMode? blendMode,
  }) {
    // Use script-appropriate text direction
    final effectiveDirection = _getScriptDirection(scriptType);
    final effectiveStyle = style.textDirection != effectiveDirection
        ? style.copyWith(textDirection: effectiveDirection)
        : style;
    
    // Render as single text run for proper shaping
    return _paintPlainText(
      canvas,
      node: node,
      text: text,
      style: effectiveStyle,
      x: cursor.x,
      baselineY: cursor.y,
      ignoreTextLength: false,
      isFirstLine: cursor.isFirstLine,
      imageFilter: imageFilter,
      colorFilter: colorFilter,
      blendMode: blendMode,
    );
  }

  /// Reorders glyphs for visual display in bidirectional text.
  ///
  /// For RTL text direction, this reverses the order of characters
  /// within the visual run while preserving the overall run positions.
  // ignore: unused_element
  List<String> _bidiReorderGlyphsForDirection(
    List<String> glyphs,
    ui.TextDirection direction,
  ) {
    if (direction == ui.TextDirection.rtl) {
      return glyphs.reversed.toList();
    }
    return glyphs;
  }

  /// Computes visual X offset for a glyph in RTL context.
  ///
  /// In RTL text, glyphs are laid out right-to-left, so we need
  /// to compute the offset from the right edge.
  // ignore: unused_element
  double _bidiComputeVisualGlyphOffset(
    int glyphIndex,
    int totalGlyphs,
    double totalWidth,
    ui.TextDirection direction,
  ) {
    if (direction == ui.TextDirection.rtl) {
      // For RTL, start from the right
      return totalWidth - (glyphIndex + 1) * (totalWidth / totalGlyphs);
    }
    // For LTR, standard left-to-right offset
    return glyphIndex * (totalWidth / totalGlyphs);
  }

  /// Adjusts cursor position after painting for bidirectional text.
  ///
  /// For RTL text, cursor advances leftward (negative direction),
  /// while for LTR text, cursor advances rightward (positive).
  // ignore: unused_element
  double _bidiAdjustCursorAdvance(
    double advance,
    ui.TextDirection direction,
  ) {
    if (direction == ui.TextDirection.rtl) {
      return -advance;
    }
    return advance;
  }

  /// Computes the visual bounds for hit-testing a glyph in mixed-direction text.
  ///
  /// Returns the visual rectangle where the glyph is rendered, accounting
  /// for RTL text direction and any reordering.
  // ignore: unused_element
  ui.Rect _bidiComputeGlyphHitTestBounds(
    int logicalIndex,
    List<_BidiTextRun> runs,
    double startX,
    double baselineY,
    double glyphWidth,
    double glyphHeight,
  ) {
    // Map logical to visual position
    final mapping = _bidiMapLogicalToVisualPosition(logicalIndex, runs);

    // Calculate X position based on visual index
    final visualX = startX + mapping.visualIndex * glyphWidth;

    return ui.Rect.fromLTWH(
      visualX,
      baselineY - glyphHeight * 0.8, // Approximate ascent
      glyphWidth,
      glyphHeight,
    );
  }
}
