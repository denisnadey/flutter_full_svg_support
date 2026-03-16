part of 'animated_svg_picture.dart';

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
    final bounds = run.bounds;
    if (bounds != null) {
      return bounds.contains(point);
    }
    final path = run.path;
    if (path != null) {
      return path.getBounds().contains(point);
    }
    return false;
  }

  bool _textRunContainsPoint(_TextHitRun run, Offset point) {
    final bounds = run.bounds;
    if (bounds != null) {
      return bounds.contains(point);
    }
    final path = run.path;
    if (path != null) {
      // TextPath hit-runs are represented as path segments; use tolerance-based
      // containment for baseline parity in fill/bounding-box modes.
      return _pathStrokeContains(path, point, run.pathTolerance);
    }
    return false;
  }

  bool _textRunStrokeContainsPoint(
    _TextHitRun run,
    Offset point,
    SvgNode styleNode,
  ) {
    final bounds = run.bounds;
    if (bounds != null) {
      final boundsPath = Path()..addRect(bounds);
      return _pathStrokeContains(
        boundsPath,
        point,
        _strokeTolerance(styleNode),
      );
    }
    final path = run.path;
    if (path != null) {
      final tolerance = math.max(
        _strokeTolerance(styleNode),
        run.pathTolerance,
      );
      return _pathStrokeContains(path, point, tolerance);
    }
    return false;
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
    final startX = _getNumber(textRoot, 'x') ?? 0.0;
    final startY = _getNumber(textRoot, 'y') ?? 0.0;
    final cursor = _HitTextCursor(x: startX, y: startY);
    final runs = <_TextHitRun>[];
    _appendTextNodeHitRuns(textRoot, cursor, runs);
    return runs;
  }

  void _appendTextNodeHitRuns(
    SvgNode node,
    _HitTextCursor cursor,
    List<_TextHitRun> runs,
  ) {
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

    final text = _extractTextContent(node);
    if (text != null && text.isNotEmpty) {
      var metrics = _measureText(text, node);
      final targetLength = _resolveTextLength(node);
      final lengthAdjust = _resolveTextLengthAdjust(node);
      final glyphCount = text.runes.length;
      if (targetLength != null && targetLength > 0 && metrics.width > 0) {
        if (lengthAdjust == _TextLengthAdjust.spacing && glyphCount > 1) {
          final extraSpacing =
              (targetLength - metrics.width) / (glyphCount - 1);
          metrics = _measureText(
            text,
            node,
            additionalLetterSpacing: extraSpacing,
          );
        } else {
          metrics = metrics.copyWith(width: targetLength);
        }
      }
      var left = cursor.x;
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
      final top = _resolveTextTopFromBaseline(
        node: node,
        baselineY: cursor.y,
        metrics: metrics,
      );
      runs.add(
        _TextHitRun.bounds(
          owner: node,
          bounds: Rect.fromLTWH(left, top, metrics.width, metrics.height),
        ),
      );
      cursor.x += metrics.width;
    }

    for (final child in node.children) {
      if (child.tagName == 'tspan') {
        _appendTextNodeHitRuns(child, cursor, runs);
      } else if (child.tagName == 'textPath') {
        final consumed = _appendTextPathHitRuns(child, runs);
        cursor.x += consumed;
      }
    }
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
      );
      offset += textConsumed;
      consumed += textConsumed;
    }

    return consumed;
  }
}
