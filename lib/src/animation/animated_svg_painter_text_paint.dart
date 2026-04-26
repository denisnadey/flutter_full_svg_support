part of 'animated_svg_painter.dart';

/// Extension for painting text elements.
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
    int parentRotateStartIndex = 0,
    bool isRootText = false,
    _ResolvedTextStyle? parentStyle,
    _TextLengthDistribution? inheritedDistribution,
  }) {
    final nodeXList = _getNumberList(node, 'x');
    final nodeYList = _getNumberList(node, 'y');
    final nodeDxList = _getNumberList(node, 'dx');
    final nodeDyList = _getNumberList(node, 'dy');
    final nodeRotateList = _getNumberList(node, 'rotate');
    final hasAbsoluteX = nodeXList.isNotEmpty;
    final hasAbsoluteY = nodeYList.isNotEmpty;
    final startsNewChunk = !isRootText && (hasAbsoluteX || hasAbsoluteY);
    if (startsNewChunk) cursor.chunkCharIndex = 0;
    final xList = nodeXList.isNotEmpty ? nodeXList : parentXList;
    final yList = nodeYList.isNotEmpty ? nodeYList : parentYList;
    final dxList = nodeDxList.isNotEmpty ? nodeDxList : parentDxList;
    final dyList = nodeDyList.isNotEmpty ? nodeDyList : parentDyList;
    final hasOwnRotateList = nodeRotateList.isNotEmpty;
    final rotateList = hasOwnRotateList ? nodeRotateList : parentRotateList;
    final rotateListStartIndex = hasOwnRotateList
        ? cursor.charIndex
        : parentRotateStartIndex;
    if (hasAbsoluteX && nodeXList.isNotEmpty) cursor.x = nodeXList[0];
    if (hasAbsoluteY && nodeYList.isNotEmpty) cursor.y = nodeYList[0];
    if (dxList.isNotEmpty && cursor.charIndex < dxList.length) {
      cursor.x += dxList[cursor.charIndex];
    }
    if (dyList.isNotEmpty && cursor.charIndex < dyList.length) {
      cursor.y += dyList[cursor.charIndex];
    }
    final style = _resolveTextStyle(node, parentStyle: parentStyle);

    // Build bidi context for elements with direction or unicode-bidi attributes.
    // This tracks direction changes through the hierarchy for proper RTL/LTR handling.
    final hasBidiAttributes =
        node.getAttributeValue('direction') != null ||
        node.getAttributeValue('unicode-bidi') != null;
    _BidiContext? bidiContext;
    if (hasBidiAttributes || isRootText) {
      bidiContext = _buildBidiContext(node);
    }

    // Track whether we're at a direction boundary (RTL<->LTR transition).
    // This is used for correct cursor advancement in mixed-direction text.
    final isDirectionBoundary = bidiContext?.isDirectionBoundary ?? false;
    final effectiveTextDirection =
        bidiContext?.currentDirection ?? style.textDirection;

    // Compute textLength distribution for parent elements with nested tspan
    // children. This distributes the textLength proportionally across all
    // children, either as extra spacing or scale factor.
    _TextLengthDistribution? effectiveDistribution = inheritedDistribution;
    final hasTspanChildren = node.children.any((c) => c.tagName == 'tspan');
    if (isRootText && hasTspanChildren && _resolveTextLength(node) != null) {
      effectiveDistribution = _computeTextLengthDistribution(node, style);
    }

    // Apply distribution to the style if needed.
    // Also apply effective text direction from bidi context if available.
    var effectiveStyle = style;
    if (effectiveDistribution != null && effectiveDistribution.isSpacing) {
      effectiveStyle = style.copyWith(
        letterSpacing: style.letterSpacing + effectiveDistribution.extraSpacing,
      );
    }
    // Use bidi context direction if it differs from style direction (direction boundary)
    if (isDirectionBoundary && effectiveTextDirection != style.textDirection) {
      effectiveStyle = effectiveStyle.copyWith(
        textDirection: effectiveTextDirection,
      );
    }

    final text = _extractTextContentWithWhitespaceNormalization(
      node,
      parentStyle,
    );
    if (text != null && text.isNotEmpty) {
      final consumed = _paintPlainTextWithPositions(
        canvas,
        node: node,
        text: text,
        style: effectiveStyle,
        cursor: cursor,
        xList: xList,
        yList: yList,
        dxList: dxList,
        dyList: dyList,
        rotateList: rotateList,
        rotateListStartIndex: rotateListStartIndex,
        startsNewChunk: startsNewChunk || isRootText,
        imageFilter: imageFilter,
        colorFilter: colorFilter,
        blendMode: blendMode,
        parentStyle: parentStyle,
        textLengthDistribution: effectiveDistribution,
      );
      cursor.x += consumed;
    }
    for (final child in node.children) {
      if (child.tagName == 'tspan') {
        final childText = _extractTextContent(child);
        final hasContent = childText != null && childText.isNotEmpty;
        final hasChildPosition =
            _getNumberList(child, 'x').isNotEmpty ||
            _getNumberList(child, 'y').isNotEmpty ||
            _getNumberList(child, 'dx').isNotEmpty ||
            _getNumberList(child, 'dy').isNotEmpty ||
            child.children.isNotEmpty;
        if (!hasContent && !hasChildPosition) continue;
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
          parentRotateStartIndex: rotateListStartIndex,
          parentStyle: effectiveStyle,
          inheritedDistribution: effectiveDistribution,
        );
      } else if (child.tagName == 'tref') {
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
          parentRotateStartIndex: rotateListStartIndex,
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
      } else if (child.tagName == 'bdo') {
        // BDO (bi-directional override) element - forces direction
        _paintBdoNode(
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
          parentRotateStartIndex: rotateListStartIndex,
          parentStyle: effectiveStyle,
          inheritedDistribution: effectiveDistribution,
        );
      }
    }
  }

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
    int parentRotateStartIndex = 0,
    _ResolvedTextStyle? parentStyle,
  }) {
    final referencedText = _resolveTrefText(trefNode);
    if (referencedText == null || referencedText.isEmpty) return 0.0;
    final nodeXList = _getNumberList(trefNode, 'x');
    final nodeYList = _getNumberList(trefNode, 'y');
    final nodeDxList = _getNumberList(trefNode, 'dx');
    final nodeDyList = _getNumberList(trefNode, 'dy');
    final nodeRotateList = _getNumberList(trefNode, 'rotate');
    final hasAbsoluteX = nodeXList.isNotEmpty;
    final hasAbsoluteY = nodeYList.isNotEmpty;
    final startsNewChunk = hasAbsoluteX || hasAbsoluteY;
    if (startsNewChunk) cursor.chunkCharIndex = 0;
    final xList = nodeXList.isNotEmpty ? nodeXList : parentXList;
    final yList = nodeYList.isNotEmpty ? nodeYList : parentYList;
    final dxList = nodeDxList.isNotEmpty ? nodeDxList : parentDxList;
    final dyList = nodeDyList.isNotEmpty ? nodeDyList : parentDyList;
    final hasOwnRotateList = nodeRotateList.isNotEmpty;
    final rotateList = hasOwnRotateList ? nodeRotateList : parentRotateList;
    final rotateListStartIndex = hasOwnRotateList
        ? cursor.charIndex
        : parentRotateStartIndex;
    if (hasAbsoluteX && nodeXList.isNotEmpty) cursor.x = nodeXList[0];
    if (hasAbsoluteY && nodeYList.isNotEmpty) cursor.y = nodeYList[0];
    if (dxList.isNotEmpty && cursor.charIndex < dxList.length) {
      cursor.x += dxList[cursor.charIndex];
    }
    if (dyList.isNotEmpty && cursor.charIndex < dyList.length) {
      cursor.y += dyList[cursor.charIndex];
    }
    final style = _resolveTextStyle(trefNode, parentStyle: parentStyle);
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
      rotateListStartIndex: rotateListStartIndex,
      startsNewChunk: startsNewChunk,
      imageFilter: imageFilter,
      colorFilter: colorFilter,
      blendMode: blendMode,
      parentStyle: parentStyle,
    );
    return consumed;
  }

  String? _resolveTrefText(SvgNode trefNode) {
    final hrefId = _extractHrefId(trefNode);
    if (hrefId == null || hrefId.isEmpty) return null;
    final referenced = document.root.findById(hrefId);
    if (referenced == null) return null;
    return _extractAllTextContent(referenced);
  }

  String _extractAllTextContent(SvgNode node) {
    final buffer = StringBuffer();
    final directText = _getString(node, '__text');
    if (directText != null && directText.isNotEmpty) buffer.write(directText);
    for (final child in node.children) {
      buffer.write(_extractAllTextContent(child));
    }
    return buffer.toString();
  }

  /// Paints a BDO (bi-directional override) element.
  ///
  /// BDO elements force direction override for their content.
  /// The `dir` attribute controls the direction:
  /// - dir="ltr" - forces left-to-right
  /// - dir="rtl" - forces right-to-left
  /// - dir="auto" - determines direction from first strong character
  void _paintBdoNode(
    ui.Canvas canvas,
    SvgNode bdoNode,
    _TextCursor cursor, {
    ui.ImageFilter? imageFilter,
    ui.ColorFilter? colorFilter,
    ui.BlendMode? blendMode,
    List<double> parentXList = const <double>[],
    List<double> parentYList = const <double>[],
    List<double> parentDxList = const <double>[],
    List<double> parentDyList = const <double>[],
    List<double> parentRotateList = const <double>[],
    int parentRotateStartIndex = 0,
    _ResolvedTextStyle? parentStyle,
    _TextLengthDistribution? inheritedDistribution,
  }) {
    // Extract text content for auto-direction detection
    final textContent = _extractTextContent(bdoNode);

    // Resolve BDO direction
    final bdoDirection = _bidiResolveBdoDirection(bdoNode, textContent);

    // Get position lists
    final nodeXList = _getNumberList(bdoNode, 'x');
    final nodeYList = _getNumberList(bdoNode, 'y');
    final nodeDxList = _getNumberList(bdoNode, 'dx');
    final nodeDyList = _getNumberList(bdoNode, 'dy');
    final nodeRotateList = _getNumberList(bdoNode, 'rotate');

    final hasAbsoluteX = nodeXList.isNotEmpty;
    final hasAbsoluteY = nodeYList.isNotEmpty;
    final startsNewChunk = hasAbsoluteX || hasAbsoluteY;
    if (startsNewChunk) cursor.chunkCharIndex = 0;

    final xList = nodeXList.isNotEmpty ? nodeXList : parentXList;
    final yList = nodeYList.isNotEmpty ? nodeYList : parentYList;
    final dxList = nodeDxList.isNotEmpty ? nodeDxList : parentDxList;
    final dyList = nodeDyList.isNotEmpty ? nodeDyList : parentDyList;
    final hasOwnRotateList = nodeRotateList.isNotEmpty;
    final rotateList = hasOwnRotateList ? nodeRotateList : parentRotateList;
    final rotateListStartIndex = hasOwnRotateList
        ? cursor.charIndex
        : parentRotateStartIndex;

    if (hasAbsoluteX && nodeXList.isNotEmpty) cursor.x = nodeXList[0];
    if (hasAbsoluteY && nodeYList.isNotEmpty) cursor.y = nodeYList[0];
    if (dxList.isNotEmpty && cursor.charIndex < dxList.length) {
      cursor.x += dxList[cursor.charIndex];
    }
    if (dyList.isNotEmpty && cursor.charIndex < dyList.length) {
      cursor.y += dyList[cursor.charIndex];
    }

    // Resolve style with forced direction from BDO
    final baseStyle = _resolveTextStyle(bdoNode, parentStyle: parentStyle);
    final style = baseStyle.copyWith(
      textDirection: bdoDirection,
      unicodeBidi: 'bidi-override',
    );

    // Paint direct text content with override
    if (textContent != null && textContent.isNotEmpty) {
      final consumed = _paintPlainTextWithPositions(
        canvas,
        node: bdoNode,
        text: textContent,
        style: style,
        cursor: cursor,
        xList: xList,
        yList: yList,
        dxList: dxList,
        dyList: dyList,
        rotateList: rotateList,
        rotateListStartIndex: rotateListStartIndex,
        startsNewChunk: startsNewChunk,
        imageFilter: imageFilter,
        colorFilter: colorFilter,
        blendMode: blendMode,
        parentStyle: parentStyle,
        textLengthDistribution: inheritedDistribution,
      );
      cursor.x += consumed;
    }

    // Paint child elements with inherited BDO direction
    for (final child in bdoNode.children) {
      if (child.tagName == 'tspan' || child.tagName == 'bdo') {
        if (child.tagName == 'bdo') {
          _paintBdoNode(
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
            parentRotateStartIndex: rotateListStartIndex,
            parentStyle: style,
            inheritedDistribution: inheritedDistribution,
          );
        } else {
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
            parentRotateStartIndex: rotateListStartIndex,
            parentStyle: style,
            inheritedDistribution: inheritedDistribution,
          );
        }
      }
    }
  }
}
