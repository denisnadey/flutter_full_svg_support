part of 'animated_svg_picture.dart';

/// Writing modes for text layout.
enum _WritingMode { horizontalTb, verticalRl, verticalLr }

extension _AnimatedSvgPictureStateHitTestTextRunsExtension
    on _AnimatedSvgPictureState {
  bool _textRunsContainPoint(
    SvgNode node,
    Offset point, {
    required String pointerEvents,
    required bool visibilityHidden,
  }) {
    final textRoot = _findTextLayoutRoot(node);
    if (textRoot == null) {
      return false;
    }
    final runs = _buildTextHitRuns(textRoot);
    final allowBoundingBox = _pointerEventsAllowsBoundingBox(
      pointerEvents,
      visibilityHidden: visibilityHidden,
    );
    final allowFill = _pointerEventsAllowsFill(
      node,
      pointerEvents,
      visibilityHidden: visibilityHidden,
    );
    final allowStroke = _pointerEventsAllowsStroke(
      node,
      pointerEvents,
      visibilityHidden: visibilityHidden,
    );
    if (!allowBoundingBox && !allowFill && !allowStroke) {
      return false;
    }

    for (final run in runs) {
      if (!_isNodeOrDescendant(run.owner, node)) {
        continue;
      }
      if (allowBoundingBox && _textRunBoundingBoxContainsPoint(run, point)) {
        return true;
      }
      final containsForFill = _textRunContainsPoint(run, point);
      if (allowFill && containsForFill) {
        return true;
      }
      if (allowStroke && _textRunStrokeContainsPoint(run, point, node)) {
        return true;
      }
    }
    return false;
  }

  bool _textRunBoundingBoxContainsPoint(_TextHitRun run, Offset point) {
    // Transform point inversely if rotation is applied
    final testPoint = run.rotation != 0.0
        ? _inverseRotatePoint(point, run.rotationCenter, run.rotation)
        : point;
    final bounds = run.bounds;
    if (bounds != null) {
      return bounds.contains(testPoint);
    }
    final path = run.path;
    if (path != null) {
      return path.getBounds().contains(testPoint);
    }
    return false;
  }

  bool _textRunContainsPoint(_TextHitRun run, Offset point) {
    // Transform point inversely if rotation is applied
    final testPoint = run.rotation != 0.0
        ? _inverseRotatePoint(point, run.rotationCenter, run.rotation)
        : point;
    final bounds = run.bounds;
    if (bounds != null) {
      return bounds.contains(testPoint);
    }
    final path = run.path;
    if (path != null) {
      // TextPath hit-runs are represented as path segments; use tolerance-based
      // containment for baseline parity in fill/bounding-box modes.
      return _pathStrokeContains(path, testPoint, run.pathTolerance);
    }
    return false;
  }

  bool _textRunStrokeContainsPoint(
    _TextHitRun run,
    Offset point,
    SvgNode styleNode,
  ) {
    // Transform point inversely if rotation is applied
    final testPoint = run.rotation != 0.0
        ? _inverseRotatePoint(point, run.rotationCenter, run.rotation)
        : point;
    final bounds = run.bounds;
    if (bounds != null) {
      final boundsPath = Path()..addRect(bounds);
      return _pathStrokeContains(
        boundsPath,
        testPoint,
        _strokeTolerance(styleNode),
      );
    }
    final path = run.path;
    if (path != null) {
      final tolerance = math.max(
        _strokeTolerance(styleNode),
        run.pathTolerance,
      );
      return _pathStrokeContains(path, testPoint, tolerance);
    }
    return false;
  }

  /// Inversely rotates a point around a center by the given angle (in degrees).
  Offset _inverseRotatePoint(Offset point, Offset center, double angleDegrees) {
    final radians = -angleDegrees * 3.1415926535897932 / 180.0;
    final cos = math.cos(radians);
    final sin = math.sin(radians);
    final dx = point.dx - center.dx;
    final dy = point.dy - center.dy;
    return Offset(
      center.dx + dx * cos - dy * sin,
      center.dy + dx * sin + dy * cos,
    );
  }

  /// Resolves writing-mode for a text node.
  _WritingMode _resolveWritingMode(SvgNode node) {
    final value = _getInheritedString(node, 'writing-mode')?.toLowerCase();
    switch (value) {
      case 'vertical-rl':
      case 'tb-rl':
      case 'tb':
        return _WritingMode.verticalRl;
      case 'vertical-lr':
        return _WritingMode.verticalLr;
      case 'horizontal-tb':
      case 'lr':
      case 'lr-tb':
      default:
        return _WritingMode.horizontalTb;
    }
  }

  SvgNode? _findTextLayoutRoot(SvgNode node) {
    SvgNode? current = node;
    while (current != null) {
      if (current.tagName == 'text') {
        return current;
      }
      current = current.parent;
    }
    return null;
  }

  bool _isNodeOrDescendant(SvgNode node, SvgNode ancestor) {
    SvgNode? current = node;
    while (current != null) {
      if (identical(current, ancestor)) {
        return true;
      }
      current = current.parent;
    }
    return false;
  }

  List<_TextHitRun> _buildTextHitRuns(SvgNode textRoot) {
    if (textRoot.tagName != 'text') {
      return const <_TextHitRun>[];
    }
    final xList = _getNumberList(textRoot, 'x');
    final yList = _getNumberList(textRoot, 'y');
    final startX = xList.isNotEmpty ? xList[0] : 0.0;
    final startY = yList.isNotEmpty ? yList[0] : 0.0;
    final cursor = _HitTextCursor(x: startX, y: startY);
    final runs = <_TextHitRun>[];
    final writingMode = _resolveWritingMode(textRoot);
    _appendTextNodeHitRuns(
      textRoot,
      cursor,
      runs,
      parentXList: xList,
      parentYList: yList,
      parentDxList: _getNumberList(textRoot, 'dx'),
      parentDyList: _getNumberList(textRoot, 'dy'),
      parentRotateList: _getNumberList(textRoot, 'rotate'),
      isRootText: true,
      writingMode: writingMode,
    );
    return runs;
  }

  void _appendTextNodeHitRuns(
    SvgNode node,
    _HitTextCursor cursor,
    List<_TextHitRun> runs, {
    List<double> parentXList = const <double>[],
    List<double> parentYList = const <double>[],
    List<double> parentDxList = const <double>[],
    List<double> parentDyList = const <double>[],
    List<double> parentRotateList = const <double>[],
    bool isRootText = false,
    _WritingMode writingMode = _WritingMode.horizontalTb,
    bool forceCharacterPrecise = false,
  }) {
    // Parse position lists from this node
    final nodeXList = _getNumberList(node, 'x');
    final nodeYList = _getNumberList(node, 'y');
    final nodeDxList = _getNumberList(node, 'dx');
    final nodeDyList = _getNumberList(node, 'dy');
    final nodeRotateList = _getNumberList(node, 'rotate');

    // Check if this tspan creates a new text chunk (has absolute positioning)
    final hasAbsoluteX = nodeXList.isNotEmpty;
    final hasAbsoluteY = nodeYList.isNotEmpty;

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

    final text = _extractTextContent(node);
    if (text != null && text.isNotEmpty) {
      // Segment text into grapheme clusters for proper character handling
      final graphemeClusters = _segmentTextIntoGraphemeClusters(text);
      final glyphCount = graphemeClusters.length;

      // Determine if we should use per-character hit-testing
      // Now also check for forceCharacterPrecise flag for precise selection
      final usePerCharHit =
          forceCharacterPrecise ||
          _shouldUsePerCharacterHitTesting(
            glyphCount,
            xList: xList,
            yList: yList,
            dxList: dxList,
            dyList: dyList,
            rotateList: rotateList,
          );

      if (usePerCharHit) {
        _appendPerCharacterHitRunsWithGraphemes(
          node: node,
          graphemeClusters: graphemeClusters,
          cursor: cursor,
          runs: runs,
          xList: xList,
          yList: yList,
          dxList: dxList,
          dyList: dyList,
          rotateList: rotateList,
          writingMode: writingMode,
        );
      } else {
        // Use single bounding box for the entire text run
        _appendSingleTextRunHit(
          node: node,
          text: text,
          cursor: cursor,
          runs: runs,
          rotateList: rotateList,
          writingMode: writingMode,
        );
      }
    }

    for (final child in node.children) {
      if (child.tagName == 'tspan') {
        _appendTextNodeHitRuns(
          child,
          cursor,
          runs,
          parentXList: xList,
          parentYList: yList,
          parentDxList: dxList,
          parentDyList: dyList,
          parentRotateList: rotateList,
          writingMode: writingMode,
          forceCharacterPrecise: forceCharacterPrecise,
        );
      } else if (child.tagName == 'textPath') {
        final consumed = _appendTextPathHitRuns(child, runs);
        cursor.x += consumed;
      }
    }
  }

  /// Segments text into grapheme clusters for proper character handling.
  /// A grapheme cluster is a user-perceived "character" that may consist of
  /// a base character plus combining marks.
  List<String> _segmentTextIntoGraphemeClusters(String text) {
    if (text.isEmpty) {
      return const <String>[];
    }

    final clusters = <String>[];
    final runes = text.runes.toList();
    var i = 0;

    while (i < runes.length) {
      final start = i;
      i++; // Include base character

      // Consume any following combining marks
      while (i < runes.length && _isHitTestCombiningMark(runes[i])) {
        i++;
      }

      // Extract the grapheme cluster
      final cluster = String.fromCharCodes(runes.sublist(start, i));
      clusters.add(cluster);
    }

    return clusters;
  }

  /// Checks if a code point is a combining mark for hit-testing purposes.
  bool _isHitTestCombiningMark(int codePoint) {
    // Combining Diacritical Marks (0300-036F)
    if (codePoint >= 0x0300 && codePoint <= 0x036F) {
      return true;
    }
    // Combining Diacritical Marks Extended (1AB0-1AFF)
    if (codePoint >= 0x1AB0 && codePoint <= 0x1AFF) {
      return true;
    }
    // Combining Diacritical Marks Supplement (1DC0-1DFF)
    if (codePoint >= 0x1DC0 && codePoint <= 0x1DFF) {
      return true;
    }
    // Combining Half Marks (FE20-FE2F)
    if (codePoint >= 0xFE20 && codePoint <= 0xFE2F) {
      return true;
    }
    // Thai combining marks
    if (codePoint == 0x0E31 ||
        (codePoint >= 0x0E34 && codePoint <= 0x0E3A) ||
        (codePoint >= 0x0E47 && codePoint <= 0x0E4E)) {
      return true;
    }
    // Devanagari combining marks
    if (codePoint == 0x093C ||
        (codePoint >= 0x0941 && codePoint <= 0x0948) ||
        codePoint == 0x094D) {
      return true;
    }
    return false;
  }

  /// Appends hit runs for each grapheme cluster in the text.
  void _appendPerCharacterHitRunsWithGraphemes({
    required SvgNode node,
    required List<String> graphemeClusters,
    required _HitTextCursor cursor,
    required List<_TextHitRun> runs,
    required List<double> xList,
    required List<double> yList,
    required List<double> dxList,
    required List<double> dyList,
    required List<double> rotateList,
    _WritingMode writingMode = _WritingMode.horizontalTb,
  }) {
    final textAnchor = _resolveTextAnchor(node);
    final letterSpacing = _getInheritedNumber(node, 'letter-spacing') ?? 0.0;
    final wordSpacing = _getInheritedNumber(node, 'word-spacing') ?? 0.0;
    final isVertical = writingMode != _WritingMode.horizontalTb;

    // Pre-calculate total dimension for text-anchor middle/end
    double totalDimension = 0.0;
    if (textAnchor != _TextAnchor.start) {
      for (int i = 0; i < graphemeClusters.length; i++) {
        final cluster = graphemeClusters[i];
        final charMetrics = _measureText(cluster, node);
        totalDimension += isVertical ? charMetrics.height : charMetrics.width;
        if (i < graphemeClusters.length - 1) {
          totalDimension += _spacingAfterGlyphForHit(
            glyph: cluster,
            isLast: false,
            letterSpacing: letterSpacing,
            wordSpacing: wordSpacing,
          );
        }
      }
    }

    // Calculate initial position offset based on text-anchor
    double anchorOffset = 0.0;
    switch (textAnchor) {
      case _TextAnchor.middle:
        anchorOffset = -totalDimension / 2;
        break;
      case _TextAnchor.end:
        anchorOffset = -totalDimension;
        break;
      case _TextAnchor.start:
        break;
    }

    double charX = isVertical ? cursor.x : cursor.x + anchorOffset;
    double charY = isVertical ? cursor.y + anchorOffset : cursor.y;
    int listIdx = cursor.charIndex;

    for (int i = 0; i < graphemeClusters.length; i++) {
      final cluster = graphemeClusters[i];

      // Apply per-character positioning from lists
      if (listIdx < xList.length) {
        charX = isVertical ? xList[listIdx] : xList[listIdx] + anchorOffset;
      }
      if (listIdx < yList.length) {
        charY = isVertical ? yList[listIdx] + anchorOffset : yList[listIdx];
      }
      if (listIdx < dxList.length) {
        charX += dxList[listIdx];
      }
      if (listIdx < dyList.length) {
        charY += dyList[listIdx];
      }

      // Get rotation for this character
      double rotation = 0.0;
      if (rotateList.isNotEmpty) {
        rotation = listIdx < rotateList.length
            ? rotateList[listIdx]
            : rotateList.last;
      }

      final charMetrics = _measureText(cluster, node);
      final top = _resolveTextTopFromBaseline(
        node: node,
        baselineY: charY,
        metrics: charMetrics,
      );

      // For vertical text, rotate character 90 degrees and swap dimensions
      Rect charBounds;
      if (isVertical) {
        charBounds = Rect.fromLTWH(
          charX - charMetrics.height / 2,
          charY,
          charMetrics.height,
          charMetrics.width,
        );
      } else {
        charBounds = Rect.fromLTWH(
          charX,
          top,
          charMetrics.width,
          charMetrics.height,
        );
      }

      runs.add(
        _TextHitRun.bounds(
          owner: node,
          bounds: charBounds,
          rotation: isVertical ? 90.0 + rotation : rotation,
          rotationCenter: Offset(charX, charY),
        ),
      );

      // Advance for next character
      final charAdvance = isVertical ? charMetrics.height : charMetrics.width;
      final spacingAdvance = _spacingAfterGlyphForHit(
        glyph: cluster,
        isLast: i == graphemeClusters.length - 1,
        letterSpacing: letterSpacing,
        wordSpacing: wordSpacing,
      );

      if (isVertical) {
        charY += charAdvance + spacingAdvance;
      } else {
        charX += charAdvance + spacingAdvance;
      }
      listIdx++;
    }

    if (isVertical) {
      cursor.y = charY - anchorOffset;
    } else {
      cursor.x = charX - anchorOffset;
    }
    cursor.charIndex += graphemeClusters.length;
  }

  /// Checks if per-character hit-testing should be used based on position lists.
  /// Returns true if any list has multiple values that would position characters individually.
  bool _shouldUsePerCharacterHitTesting(
    int glyphCount, {
    required List<double> xList,
    required List<double> yList,
    required List<double> dxList,
    required List<double> dyList,
    required List<double> rotateList,
  }) {
    // Use per-char hit testing when position lists have > 1 value
    // or when they provide positioning for multiple characters
    return xList.length > 1 ||
        yList.length > 1 ||
        dxList.length > 1 ||
        dyList.length > 1 ||
        (rotateList.length > 1 && rotateList.length <= glyphCount);
  }

  /// Appends a single hit run for the entire text (original behavior).
  void _appendSingleTextRunHit({
    required SvgNode node,
    required String text,
    required _HitTextCursor cursor,
    required List<_TextHitRun> runs,
    required List<double> rotateList,
    _WritingMode writingMode = _WritingMode.horizontalTb,
  }) {
    var metrics = _measureText(text, node);
    final targetLength = _resolveTextLength(node);
    final lengthAdjust = _resolveTextLengthAdjust(node);
    final glyphCount = text.runes.length;
    final isVertical = writingMode != _WritingMode.horizontalTb;

    if (targetLength != null && targetLength > 0 && metrics.width > 0) {
      if (lengthAdjust == _TextLengthAdjust.spacing && glyphCount > 1) {
        final extraSpacing = (targetLength - metrics.width) / (glyphCount - 1);
        metrics = _measureText(
          text,
          node,
          additionalLetterSpacing: extraSpacing,
        );
      } else {
        metrics = metrics.copyWith(width: targetLength);
      }
    }

    // Calculate position based on text-anchor and writing-mode
    double left = cursor.x;
    double top;

    if (isVertical) {
      // For vertical text, swap the anchor behavior
      top = cursor.y;
      switch (_resolveTextAnchor(node)) {
        case _TextAnchor.middle:
          top -= metrics.width / 2; // Use width as inline dimension
          break;
        case _TextAnchor.end:
          top -= metrics.width;
          break;
        case _TextAnchor.start:
          break;
      }
      // Adjust left for vertical centering
      left -= metrics.height / 2;
    } else {
      switch (_resolveTextAnchor(node)) {
        case _TextAnchor.middle:
          left -= metrics.width / 2;
          break;
        case _TextAnchor.end:
          left -= metrics.width;
          break;
        case _TextAnchor.start:
          break;
      }
      top = _resolveTextTopFromBaseline(
        node: node,
        baselineY: cursor.y,
        metrics: metrics,
      );
    }

    // Get rotation for hit region (use first value for entire run)
    final rotation = rotateList.isNotEmpty ? rotateList[0] : 0.0;

    // Create bounds with proper dimensions for writing mode
    Rect bounds;
    if (isVertical) {
      // For vertical text, swap width and height
      bounds = Rect.fromLTWH(left, top, metrics.height, metrics.width);
    } else {
      bounds = Rect.fromLTWH(left, top, metrics.width, metrics.height);
    }

    runs.add(
      _TextHitRun.bounds(
        owner: node,
        bounds: bounds,
        rotation: isVertical ? 90.0 + rotation : rotation,
        rotationCenter: Offset(left, cursor.y),
      ),
    );

    // Advance cursor based on writing mode
    if (isVertical) {
      cursor.y += metrics.width;
    } else {
      cursor.x += metrics.width;
    }
    cursor.charIndex += text.runes.length;
  }

  double _appendTextPathHitRuns(SvgNode textPathNode, List<_TextHitRun> runs) {
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

    // Parse textPath-specific attributes
    final spacing = _resolveTextPathSpacing(textPathNode);

    double offset = _parseTextPathStartOffset(textPathNode, metric.length);
    var consumed = 0.0;

    final directText = _extractTextContent(textPathNode);
    if (directText != null && directText.isNotEmpty) {
      final textConsumed = _appendTextPathSegmentRuns(
        owner: textPathNode,
        styleNode: textPathNode,
        text: directText,
        metric: metric,
        startOffset: offset,
        runs: runs,
        spacing: spacing,
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
      final textConsumed = _appendTextPathSegmentRuns(
        owner: child,
        styleNode: child,
        text: childText,
        metric: metric,
        startOffset: offset,
        runs: runs,
        spacing: spacing,
      );
      offset += textConsumed;
      consumed += textConsumed;
    }

    return consumed;
  }
}
