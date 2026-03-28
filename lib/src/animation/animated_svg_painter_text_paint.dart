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
    bool isRootText = false,
    _ResolvedTextStyle? parentStyle,
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
    final rotateList = nodeRotateList.isNotEmpty ? nodeRotateList : parentRotateList;
    if (hasAbsoluteX && nodeXList.isNotEmpty) cursor.x = nodeXList[0];
    if (hasAbsoluteY && nodeYList.isNotEmpty) cursor.y = nodeYList[0];
    if (dxList.isNotEmpty && cursor.charIndex < dxList.length) cursor.x += dxList[cursor.charIndex];
    if (dyList.isNotEmpty && cursor.charIndex < dyList.length) cursor.y += dyList[cursor.charIndex];
    final style = _resolveTextStyle(node);
    final text = _extractTextContentWithWhitespaceNormalization(node, parentStyle);
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
          parentStyle: style,
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
    final rotateList = nodeRotateList.isNotEmpty ? nodeRotateList : parentRotateList;
    if (hasAbsoluteX && nodeXList.isNotEmpty) cursor.x = nodeXList[0];
    if (hasAbsoluteY && nodeYList.isNotEmpty) cursor.y = nodeYList[0];
    if (dxList.isNotEmpty && cursor.charIndex < dxList.length) cursor.x += dxList[cursor.charIndex];
    if (dyList.isNotEmpty && cursor.charIndex < dyList.length) cursor.y += dyList[cursor.charIndex];
    final style = _resolveTextStyle(trefNode);
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
}
