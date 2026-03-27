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

    // Mark this as the start of a new text element (for text-indent)
    cursor.isFirstLine = true;

    _paintTextNode(
      canvas,
      node,
      cursor,
      imageFilter: imageFilter,
      colorFilter: colorFilter,
      blendMode: blendMode,
      isRootText: true,
    );
  }

  void _paintTextNode(
    ui.Canvas canvas,
    SvgNode node,
    _TextCursor cursor, {
    ui.ImageFilter? imageFilter,
    ui.ColorFilter? colorFilter,
    ui.BlendMode? blendMode,
    List<double> parentXList = const <double>[],
    List<double> parentYList = const <double>[],
    List<double> parentDxList = const <double>[],
    List<double> parentDyList = const <double>[],
    List<double> parentRotateList = const <double>[],
    bool isRootText = false,
    _ResolvedTextStyle? parentStyle,
  }) {
    // Parse position lists from this node
    final nodeXList = _getNumberList(node, 'x');
    final nodeYList = _getNumberList(node, 'y');
    final nodeDxList = _getNumberList(node, 'dx');
    final nodeDyList = _getNumberList(node, 'dy');
    final nodeRotateList = _getNumberList(node, 'rotate');

    // Check if this tspan creates a new text chunk (has absolute positioning)
    // A new chunk is created when tspan specifies its own x or y position
    final hasAbsoluteX = nodeXList.isNotEmpty;
    final hasAbsoluteY = nodeYList.isNotEmpty;
    final startsNewChunk = !isRootText && (hasAbsoluteX || hasAbsoluteY);

    // If this tspan starts a new chunk, reset charIndex for text-anchor calculation
    if (startsNewChunk) {
      cursor.chunkCharIndex = 0;
    }

    // Merge with parent lists - node lists take precedence
    final xList = nodeXList.isNotEmpty ? nodeXList : parentXList;
    final yList = nodeYList.isNotEmpty ? nodeYList : parentYList;
    final dxList = nodeDxList.isNotEmpty ? nodeDxList : parentDxList;
    final dyList = nodeDyList.isNotEmpty ? nodeDyList : parentDyList;
    final rotateList = nodeRotateList.isNotEmpty
        ? nodeRotateList
        : parentRotateList;

    // Apply first values - reset cursor position for absolute positioning
    if (hasAbsoluteX && nodeXList.isNotEmpty) {
      cursor.x = nodeXList[0];
    }
    if (hasAbsoluteY && nodeYList.isNotEmpty) {
      cursor.y = nodeYList[0];
    }
    // Apply dx/dy as relative adjustments
    if (dxList.isNotEmpty && cursor.charIndex < dxList.length) {
      cursor.x += dxList[cursor.charIndex];
    }
    if (dyList.isNotEmpty && cursor.charIndex < dyList.length) {
      cursor.y += dyList[cursor.charIndex];
    }

    final style = _resolveTextStyle(node);
    final text = _extractTextContentWithWhitespaceNormalization(
      node,
      parentStyle,
    );
    if (text != null && text.isNotEmpty) {
      final consumed = _paintPlainTextWithPositions(
        canvas,
        node: node,
        text: text,
        style: style,
        cursor: cursor,
        xList: xList,
        yList: yList,
        dxList: dxList,
        dyList: dyList,
        rotateList: rotateList,
        startsNewChunk: startsNewChunk || isRootText,
        imageFilter: imageFilter,
        colorFilter: colorFilter,
        blendMode: blendMode,
        parentStyle: parentStyle,
      );
      cursor.x += consumed;
    }

    for (final child in node.children) {
      if (child.tagName == 'tspan') {
        // Handle empty tspans gracefully - skip if no content and no positioning
        final childText = _extractTextContent(child);
        final hasContent = childText != null && childText.isNotEmpty;
        final hasChildPosition =
            _getNumberList(child, 'x').isNotEmpty ||
            _getNumberList(child, 'y').isNotEmpty ||
            _getNumberList(child, 'dx').isNotEmpty ||
            _getNumberList(child, 'dy').isNotEmpty ||
            child.children.isNotEmpty;

        if (!hasContent && !hasChildPosition) {
          continue; // Skip empty tspans with no positioning
        }

        _paintTextNode(
          canvas,
          child,
          cursor,
          imageFilter: imageFilter,
          colorFilter: colorFilter,
          blendMode: blendMode,
          parentXList: xList,
          parentYList: yList,
          parentDxList: dxList,
          parentDyList: dyList,
          parentRotateList: rotateList,
          parentStyle: style,
        );
      } else if (child.tagName == 'tref') {
        // <tref> element: references another element's text content via xlink:href
        final consumed = _paintTrefNode(
          canvas,
          child,
          cursor,
          imageFilter: imageFilter,
          colorFilter: colorFilter,
          blendMode: blendMode,
          parentXList: xList,
          parentYList: yList,
          parentDxList: dxList,
          parentDyList: dyList,
          parentRotateList: rotateList,
          parentStyle: style,
        );
        cursor.x += consumed;
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

  /// Paints a <tref> element that references another element's text content.
  ///
  /// The tref element references text content from another element via xlink:href
  /// and renders it inline with the tref element's own styling applied.
  /// Per SVG 1.1 spec, tref is deprecated in SVG 2 but still supported for compatibility.
  double _paintTrefNode(
    ui.Canvas canvas,
    SvgNode trefNode,
    _TextCursor cursor, {
    ui.ImageFilter? imageFilter,
    ui.ColorFilter? colorFilter,
    ui.BlendMode? blendMode,
    List<double> parentXList = const <double>[],
    List<double> parentYList = const <double>[],
    List<double> parentDxList = const <double>[],
    List<double> parentDyList = const <double>[],
    List<double> parentRotateList = const <double>[],
    _ResolvedTextStyle? parentStyle,
  }) {
    // Resolve the referenced element's text content
    final referencedText = _resolveTrefText(trefNode);
    if (referencedText == null || referencedText.isEmpty) {
      return 0.0;
    }

    // Parse position lists from tref node (tref can have its own positioning)
    final nodeXList = _getNumberList(trefNode, 'x');
    final nodeYList = _getNumberList(trefNode, 'y');
    final nodeDxList = _getNumberList(trefNode, 'dx');
    final nodeDyList = _getNumberList(trefNode, 'dy');
    final nodeRotateList = _getNumberList(trefNode, 'rotate');

    // Check if tref creates a new text chunk
    final hasAbsoluteX = nodeXList.isNotEmpty;
    final hasAbsoluteY = nodeYList.isNotEmpty;
    final startsNewChunk = hasAbsoluteX || hasAbsoluteY;

    if (startsNewChunk) {
      cursor.chunkCharIndex = 0;
    }

    // Merge with parent lists - node lists take precedence
    final xList = nodeXList.isNotEmpty ? nodeXList : parentXList;
    final yList = nodeYList.isNotEmpty ? nodeYList : parentYList;
    final dxList = nodeDxList.isNotEmpty ? nodeDxList : parentDxList;
    final dyList = nodeDyList.isNotEmpty ? nodeDyList : parentDyList;
    final rotateList = nodeRotateList.isNotEmpty
        ? nodeRotateList
        : parentRotateList;

    // Apply position updates
    if (hasAbsoluteX && nodeXList.isNotEmpty) {
      cursor.x = nodeXList[0];
    }
    if (hasAbsoluteY && nodeYList.isNotEmpty) {
      cursor.y = nodeYList[0];
    }
    if (dxList.isNotEmpty && cursor.charIndex < dxList.length) {
      cursor.x += dxList[cursor.charIndex];
    }
    if (dyList.isNotEmpty && cursor.charIndex < dyList.length) {
      cursor.y += dyList[cursor.charIndex];
    }

    // Resolve tref's own styling
    final style = _resolveTextStyle(trefNode);

    // Paint the referenced text with tref's styling
    final consumed = _paintPlainTextWithPositions(
      canvas,
      node: trefNode,
      text: referencedText,
      style: style,
      cursor: cursor,
      xList: xList,
      yList: yList,
      dxList: dxList,
      dyList: dyList,
      rotateList: rotateList,
      startsNewChunk: startsNewChunk,
      imageFilter: imageFilter,
      colorFilter: colorFilter,
      blendMode: blendMode,
      parentStyle: parentStyle,
    );

    return consumed;
  }

  /// Resolves the text content referenced by a <tref> element.
  ///
  /// The tref element uses xlink:href to reference another element,
  /// and its text content is extracted from that element.
  String? _resolveTrefText(SvgNode trefNode) {
    final hrefId = _extractHrefId(trefNode);
    if (hrefId == null || hrefId.isEmpty) {
      return null;
    }

    // Find the referenced element by ID
    final referenced = document.root.findById(hrefId);
    if (referenced == null) {
      return null;
    }

    // Extract all text content from the referenced element and its descendants
    return _extractAllTextContent(referenced);
  }

  /// Extracts all text content from a node and its descendants recursively.
  ///
  /// This is used by tref to get the complete text content of the referenced element.
  String _extractAllTextContent(SvgNode node) {
    final buffer = StringBuffer();

    // Get direct text content
    final directText = _getString(node, '__text');
    if (directText != null && directText.isNotEmpty) {
      buffer.write(directText);
    }

    // Recursively get text from children
    for (final child in node.children) {
      buffer.write(_extractAllTextContent(child));
    }

    return buffer.toString();
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

    // Check if path is closed (for wrapping behavior)
    final isClosed = metric.isClosed;

    // Parse textPath-specific attributes
    final spacing = _resolveTextPathSpacing(textPathNode);
    final method = _resolveTextPathMethod(textPathNode);

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
        spacing: spacing,
        method: method,
        isClosed: isClosed,
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
        spacing: spacing,
        method: method,
        isClosed: isClosed,
        imageFilter: imageFilter,
        colorFilter: colorFilter,
        blendMode: blendMode,
      );
      offset += textConsumed;
      consumed += textConsumed;
    }

    return consumed;
  }

  /// Paints text with per-character positioning from x/y/dx/dy/rotate lists.
  /// Falls back to simple rendering when no multi-position lists are provided.
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
    final hasMultiPositions =
        xList.length > 1 ||
        yList.length > 1 ||
        dxList.length > 1 ||
        dyList.length > 1 ||
        rotateList.isNotEmpty;

    // Check if textLength should be ignored due to explicit positions
    // Per SVG spec, textLength is ignored for characters with explicit positions
    final hasExplicitPositions = xList.length > 1 || yList.length > 1;

    // Fast path: no multi-position attributes, use simple rendering
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

    // Per-character rendering with position lists
    var totalWidth = 0.0;

    // Calculate text-anchor offset for this chunk
    // For RTL text, text-anchor behavior is inverted
    double anchorOffset = 0.0;
    if (startsNewChunk || cursor.chunkCharIndex == 0) {
      // Measure the width of the entire chunk for text-anchor calculation
      final chunkParagraph = _buildTextParagraph(text, style);
      final chunkWidth = chunkParagraph.maxIntrinsicWidth;

      // Determine effective anchor based on direction
      // In RTL mode, start becomes end and vice versa
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

    // Apply text-indent for first line in per-character positioning
    double textIndentOffset = 0.0;
    if (cursor.isFirstLine && style.textIndent != 0.0) {
      textIndentOffset = style.textIndent;
      cursor.isFirstLine = false; // Only apply to first line
    }

    // Calculate hanging punctuation offsets
    // For per-character positioning, we're typically on the first/only line
    final hangingInfo = _calculateHangingPunctuation(
      text: text,
      style: style,
      isFirstLine: true, // Per-char positioning is first line context
      isLastLine: true, // And last line context
    );

    // Apply start hanging offset for first character
    double startHangOffset = 0.0;
    if (hangingInfo.startHangWidth > 0) {
      startHangOffset = -hangingInfo.startHangWidth;
    }

    // For mixed font-size tspans, calculate baseline offset to align properly
    // When child tspan has different font-size than parent, align on alphabetic baseline
    double mixedBaselineOffset = 0.0;
    if (parentStyle != null && parentStyle.fontSize != style.fontSize) {
      // Calculate offset to align child baseline with parent baseline
      final parentParagraph = _buildTextParagraph('X', parentStyle);
      final childParagraph = _buildTextParagraph('X', style);
      final parentBaseline = parentParagraph.alphabeticBaseline;
      final childBaseline = childParagraph.alphabeticBaseline;
      mixedBaselineOffset = parentBaseline - childBaseline;
    }

    // Determine paint order (default: fill first, then stroke)
    final paintOrderParts = style.paintOrder.split(RegExp(r'\s+'));
    final strokeFirst =
        paintOrderParts.isNotEmpty && paintOrderParts.first == 'stroke';

    for (int i = 0; i < glyphs.length; i++) {
      final charIdx = cursor.charIndex + i;

      // Apply position from lists for this character
      if (charIdx < xList.length) {
        cursor.x = xList[charIdx];
      }
      if (charIdx < yList.length) {
        cursor.y = yList[charIdx];
      }
      if (charIdx < dxList.length) {
        cursor.x += dxList[charIdx];
      }
      if (charIdx < dyList.length) {
        cursor.y += dyList[charIdx];
      }

      // Get rotation for this character (last value repeats for remaining chars)
      final rotation = rotateList.isNotEmpty
          ? rotateList[charIdx.clamp(0, rotateList.length - 1)]
          : 0.0;

      final glyph = glyphs[i];
      final paragraph = _buildTextParagraph(glyph, style);
      final glyphWidth = paragraph.maxIntrinsicWidth;

      // Apply anchor offset only to the first character, plus text-indent and hanging offset
      var drawX =
          cursor.x +
          (i == 0 ? anchorOffset + textIndentOffset + startHangOffset : 0.0);

      final drawY = _resolveTextTopFromBaseline(
        paragraph: paragraph,
        style: style,
        baselineY: cursor.y + mixedBaselineOffset,
      );

      // Build stroke paragraph for this glyph
      final strokeParagraph = _buildStrokeTextParagraph(glyph, style, node);

      // Apply rotation around the character's baseline position
      if (rotation != 0.0) {
        canvas.save();
        canvas.translate(drawX, cursor.y);
        canvas.rotate(rotation * 3.1415926535897932 / 180.0);
        canvas.translate(-drawX, -cursor.y);
      }

      // Draw in paint-order
      if (strokeFirst && strokeParagraph != null) {
        // Stroke first
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
        // Fill first (default)
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
        if (strokeParagraph != null) {
          canvas.drawParagraph(strokeParagraph, ui.Offset(drawX, drawY));
        }
      }

      if (rotation != 0.0) {
        canvas.restore();
      }

      cursor.x += glyphWidth + style.letterSpacing;
      totalWidth += glyphWidth + style.letterSpacing;
    }

    cursor.charIndex += glyphs.length;
    cursor.chunkCharIndex += glyphs.length;
    return totalWidth;
  }

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
    // Handle vertical writing modes by rotating the text
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

    // Apply text-indent for first line
    var effectiveX = x;
    if (isFirstLine && style.textIndent != 0.0) {
      effectiveX += style.textIndent;
    }

    // Calculate hanging punctuation offsets
    final hangingInfo = _calculateHangingPunctuation(
      text: text,
      style: style,
      isFirstLine: isFirstLine,
      isLastLine: isLastLine,
    );

    // Apply start hanging offset (negative to move outside the box)
    if (hangingInfo.startHangWidth > 0) {
      effectiveX -= hangingInfo.startHangWidth;
    }

    var effectiveStyle = style;
    var paragraph = _buildTextParagraph(text, effectiveStyle);
    var width = paragraph.maxIntrinsicWidth;
    var scaleX = 1.0;
    // Only apply textLength if not ignored (e.g., when explicit positions are used)
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
      }
    }

    var drawX = effectiveX;
    // Determine effective anchor based on direction
    // In RTL mode, start becomes end and vice versa
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
    final drawY = _resolveTextTopFromBaseline(
      paragraph: paragraph,
      style: effectiveStyle,
      baselineY: baselineY,
    );

    // Build stroke paragraph if stroke is defined
    final strokeParagraph = _buildStrokeTextParagraph(
      text,
      effectiveStyle,
      node,
    );

    // Determine paint order (default: fill first, then stroke)
    final paintOrderParts = effectiveStyle.paintOrder.split(RegExp(r'\s+'));
    final strokeFirst =
        strokeParagraph != null &&
        paintOrderParts.isNotEmpty &&
        paintOrderParts.first == 'stroke';

    // Helper to draw fill
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

    // Helper to draw stroke
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

    // Draw in paint-order
    if (strokeFirst) {
      drawStroke();
      drawFill();
    } else {
      drawFill();
      drawStroke();
    }

    return width;
  }

  /// Paints text vertically (for writing-mode: vertical-rl or vertical-lr).
  /// Each character is rendered top-to-bottom.
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
    if (glyphs.isEmpty) {
      return 0.0;
    }

    // Calculate hanging punctuation for vertical text
    // For vertical text, hanging applies to block-start (top) and block-end (bottom)
    final hangingInfo = _calculateHangingPunctuation(
      text: text,
      style: style,
      isFirstLine: isFirstLine,
      isLastLine: isLastLine,
    );

    var totalHeight = 0.0;
    var cursorY = baselineY;

    // Apply start hanging (at block-start/top for vertical text)
    if (hangingInfo.startHangWidth > 0) {
      cursorY -= hangingInfo.startHangWidth;
    }

    // For vertical text, rotate each character 90 degrees clockwise
    // and stack them vertically
    for (int i = 0; i < glyphs.length; i++) {
      final glyph = glyphs[i];
      final paragraph = _buildTextParagraph(glyph, style);
      final glyphWidth = paragraph.maxIntrinsicWidth;
      final glyphHeight = style.fontSize;

      canvas.save();
      // Position at current y, rotate 90 degrees for vertical
      canvas.translate(x, cursorY);
      // Rotate 90 degrees clockwise for vertical text
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

      cursorY += glyphHeight + style.letterSpacing;
      totalHeight += glyphHeight + style.letterSpacing;
    }

    return totalHeight;
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
    // Build stroke paragraphs for each glyph (null if no stroke)
    final strokeParagraphs = glyphs
        .map((glyph) => _buildStrokeTextParagraph(glyph, style, layoutNode))
        .toList(growable: false);
    final widths = paragraphs
        .map((paragraph) => paragraph.maxIntrinsicWidth)
        .toList(growable: false);
    final advances = <double>[];
    for (int i = 0; i < glyphs.length; i++) {
      // For spacing="exact", don't apply letter-spacing/word-spacing
      // For spacing="auto", apply style spacing
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

    // Calculate available path length from start offset
    final availableLength = metric.length - startOffset;

    // Apply method="stretch" - scale glyphs to fit available path length
    if (method == _SvgTextPathMethod.stretch && totalWidth > 0) {
      // Stretch mode scales all glyphs uniformly to fit the available path
      final stretchFactor = availableLength / totalWidth;
      glyphScaleX = stretchFactor;
      for (int i = 0; i < displayWidths.length; i++) {
        displayWidths[i] *= stretchFactor;
        displayAdvances[i] *= stretchFactor;
      }
      totalWidth = availableLength;
    }

    // Apply textLength (takes precedence over method="stretch")
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

    // Determine paint order (default: fill first, then stroke)
    final paintOrderParts = style.paintOrder.split(RegExp(r'\s+'));
    final strokeFirst =
        paintOrderParts.isNotEmpty && paintOrderParts.first == 'stroke';

    var consumed = 0.0;
    var cursor = drawOffset;
    for (int i = 0; i < paragraphs.length; i++) {
      final paragraph = paragraphs[i];
      final glyphWidth = widths[i];
      final displayWidth = displayWidths[i];
      final glyphAdvance = displayAdvances[i];

      // For closed paths, wrap around when exceeding path length
      double effectiveCenter;
      if (isClosed) {
        // Wrap position around for closed paths
        effectiveCenter = (cursor + displayWidth / 2) % metric.length;
        if (effectiveCenter < 0) {
          effectiveCenter += metric.length;
        }
      } else {
        // For open paths, clamp to path bounds
        effectiveCenter = (cursor + displayWidth / 2).clamp(0.0, metric.length);

        // Skip glyphs that start beyond the path length (overflow handling)
        if (cursor > metric.length) {
          break;
        }
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
      if ((glyphScaleX - 1.0).abs() > 1e-6) {
        canvas.scale(glyphScaleX, 1.0);
      }

      // Draw in paint-order
      if (strokeFirst && strokeParagraph != null) {
        // Stroke first
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
        // Fill first (default)
        _drawParagraphWithEffects(
          canvas,
          paragraph: paragraph,
          x: drawX,
          y: drawY,
          style: style,
          text: glyphs[i],
        );
        if (strokeParagraph != null) {
          canvas.drawParagraph(strokeParagraph, ui.Offset(drawX, drawY));
        }
      }

      canvas.restore();

      cursor += glyphAdvance;
      consumed += glyphAdvance;
    }

    if (needsLayer) {
      canvas.restore();
    }
    return consumed;
  }
}
