part of 'animated_svg_picture.dart';

/// Advanced hit-testing extensions for markers, glyph precision text,
/// animation events, use element event delegation, and evenodd fill-rule.
extension _AnimatedSvgPictureStateHitTestAdvancedExtension
    on _AnimatedSvgPictureState {
  // ============================================================================
  // MARKER HIT-TESTING
  // ============================================================================

  /// Checks if a point hits any markers on a path element.
  /// Markers include marker-start, marker-mid, and marker-end.
  bool _markersContainPoint(
    SvgNode node,
    Offset documentPoint,
    Matrix4 transform,
  ) {
    final path = _buildGeometryPath(node);
    if (path == null) return false;

    final (markerStartId, markerMidId, markerEndId) = _resolveMarkerRefsForHit(
      node,
    );
    if (markerStartId == null && markerMidId == null && markerEndId == null) {
      return false;
    }

    final inverse = Matrix4.tryInvert(transform);
    if (inverse == null) return false;
    final localPoint = MatrixUtils.transformPoint(inverse, documentPoint);

    final strokeWidth = _getInheritedNumber(node, 'stroke-width') ?? 1.0;
    final vertices = _extractHitTestVertices(path);
    if (vertices.isEmpty) return false;

    // Check marker-start
    if (markerStartId != null && vertices.isNotEmpty) {
      final marker = _resolveMarkerForHit(markerStartId);
      if (marker != null) {
        final pos = vertices.first;
        final angle = _calculateStartAngleForHit(vertices);
        final effectiveAngle = _getEffectiveMarkerAngleForHit(
          marker,
          angle,
          true,
        );
        if (_markerContainsPoint(
          marker,
          pos,
          effectiveAngle,
          strokeWidth,
          localPoint,
        )) {
          return true;
        }
      }
    }

    // Check marker-mid
    if (markerMidId != null && vertices.length > 2) {
      final marker = _resolveMarkerForHit(markerMidId);
      if (marker != null) {
        for (int i = 1; i < vertices.length - 1; i++) {
          final pos = vertices[i];
          final angle = _calculateMidAngleForHit(vertices, i);
          final effectiveAngle = _getEffectiveMarkerAngleForHit(
            marker,
            angle,
            false,
          );
          if (_markerContainsPoint(
            marker,
            pos,
            effectiveAngle,
            strokeWidth,
            localPoint,
          )) {
            return true;
          }
        }
      }
    }

    // Check marker-end
    if (markerEndId != null && vertices.length >= 2) {
      final marker = _resolveMarkerForHit(markerEndId);
      if (marker != null) {
        final pos = vertices.last;
        final angle = _calculateEndAngleForHit(vertices);
        final effectiveAngle = _getEffectiveMarkerAngleForHit(
          marker,
          angle,
          false,
        );
        if (_markerContainsPoint(
          marker,
          pos,
          effectiveAngle,
          strokeWidth,
          localPoint,
        )) {
          return true;
        }
      }
    }

    return false;
  }

  /// Resolves marker references (marker-start, marker-mid, marker-end).
  (String?, String?, String?) _resolveMarkerRefsForHit(SvgNode node) {
    String? parseMarkerUrl(String? value) {
      if (value == null || value.isEmpty) return null;
      final match = RegExp(r'url\s*\(\s*#([^)]+)\s*\)').firstMatch(value);
      return match?.group(1);
    }

    // Check shorthand 'marker' first
    final markerAll = _getInheritedAttributeValue(node, 'marker')?.toString();
    var markerStart = parseMarkerUrl(markerAll);
    var markerMid = parseMarkerUrl(markerAll);
    var markerEnd = parseMarkerUrl(markerAll);

    // Override with specific attributes
    final startVal = _getInheritedAttributeValue(
      node,
      'marker-start',
    )?.toString();
    final midVal = _getInheritedAttributeValue(node, 'marker-mid')?.toString();
    final endVal = _getInheritedAttributeValue(node, 'marker-end')?.toString();

    if (startVal != null && startVal.isNotEmpty) {
      if (startVal.toLowerCase() == 'none') {
        markerStart = null;
      } else {
        markerStart = parseMarkerUrl(startVal);
      }
    }
    if (midVal != null && midVal.isNotEmpty) {
      if (midVal.toLowerCase() == 'none') {
        markerMid = null;
      } else {
        markerMid = parseMarkerUrl(midVal);
      }
    }
    if (endVal != null && endVal.isNotEmpty) {
      if (endVal.toLowerCase() == 'none') {
        markerEnd = null;
      } else {
        markerEnd = parseMarkerUrl(endVal);
      }
    }

    return (markerStart, markerMid, markerEnd);
  }

  /// Resolves a marker definition for hit-testing.
  _MarkerHitDefinition? _resolveMarkerForHit(String markerId) {
    final node = _document.root.findById(markerId);
    if (node == null || node.tagName != 'marker') {
      return null;
    }

    final refX = _getNumber(node, 'refX') ?? 0.0;
    final refY = _getNumber(node, 'refY') ?? 0.0;
    final markerWidth = _getNumber(node, 'markerWidth') ?? 3.0;
    final markerHeight = _getNumber(node, 'markerHeight') ?? 3.0;

    // Parse markerUnits
    final unitsStr = _getInheritedString(node, 'markerUnits')?.toLowerCase();
    final useStrokeWidth = unitsStr != 'userspaceonuse';

    // Parse orient
    final orientStr = _getInheritedString(node, 'orient')?.toLowerCase().trim();
    _MarkerOrientMode orient;
    double orientAngle = 0.0;
    if (orientStr == null || orientStr == 'auto' || orientStr.isEmpty) {
      orient = _MarkerOrientMode.auto;
    } else if (orientStr == 'auto-start-reverse') {
      orient = _MarkerOrientMode.autoStartReverse;
    } else {
      orient = _MarkerOrientMode.angle;
      orientAngle = _parseAngleForHit(orientStr);
    }

    // Parse viewBox if present
    final viewBoxStr = _getInheritedString(node, 'viewBox');
    Rect? viewBox;
    if (viewBoxStr != null && viewBoxStr.isNotEmpty) {
      final parts = viewBoxStr.trim().split(RegExp(r'[\s,]+'));
      if (parts.length == 4) {
        final minX = double.tryParse(parts[0]) ?? 0.0;
        final minY = double.tryParse(parts[1]) ?? 0.0;
        final vbWidth = double.tryParse(parts[2]) ?? markerWidth;
        final vbHeight = double.tryParse(parts[3]) ?? markerHeight;
        viewBox = Rect.fromLTWH(minX, minY, vbWidth, vbHeight);
      }
    }

    return _MarkerHitDefinition(
      node: node,
      refX: refX,
      refY: refY,
      markerWidth: markerWidth,
      markerHeight: markerHeight,
      useStrokeWidth: useStrokeWidth,
      orient: orient,
      orientAngle: orientAngle,
      viewBox: viewBox,
    );
  }

  /// Checks if a point is inside a marker's geometry.
  bool _markerContainsPoint(
    _MarkerHitDefinition marker,
    Offset position,
    double angle,
    double strokeWidth,
    Offset testPoint,
  ) {
    // Transform test point into marker's local coordinate system
    var scaleX = 1.0;
    var scaleY = 1.0;
    if (marker.useStrokeWidth) {
      scaleX = strokeWidth;
      scaleY = strokeWidth;
    }

    // Apply viewBox scaling
    if (marker.viewBox != null) {
      final vb = marker.viewBox!;
      if (vb.width > 0 && vb.height > 0) {
        scaleX *= marker.markerWidth / vb.width;
        scaleY *= marker.markerHeight / vb.height;
      }
    }

    // Transform point to marker's local space (inverse of marker transform)
    final dx = testPoint.dx - position.dx;
    final dy = testPoint.dy - position.dy;

    // Inverse rotation
    final radians = -angle * math.pi / 180.0;
    final cos = math.cos(radians);
    final sin = math.sin(radians);
    final rotatedX = dx * cos - dy * sin;
    final rotatedY = dx * sin + dy * cos;

    // Inverse scale
    final scaledX = scaleX != 0 ? rotatedX / scaleX : 0.0;
    final scaledY = scaleY != 0 ? rotatedY / scaleY : 0.0;

    // Add refX/refY to get local coordinates
    final localX = scaledX + marker.refX;
    final localY = scaledY + marker.refY;
    final localPoint = Offset(localX, localY);

    // Check against marker content geometry
    for (final child in marker.node.children) {
      final childPath = _buildGeometryPath(child);
      if (childPath != null && childPath.contains(localPoint)) {
        return true;
      }
    }

    return false;
  }

  /// Extracts vertices from a path for marker placement hit-testing.
  List<Offset> _extractHitTestVertices(Path path) {
    final vertices = <Offset>[];
    final metrics = path.computeMetrics();

    for (final metric in metrics) {
      if (metric.length <= 0) continue;

      // Start point
      final startTangent = metric.getTangentForOffset(0);
      if (startTangent != null) {
        vertices.add(startTangent.position);
      }

      // Sample corners by detecting significant angle changes
      const sampleInterval = 1.0;
      var distance = sampleInterval;
      while (distance < metric.length - sampleInterval) {
        final tangent = metric.getTangentForOffset(distance);
        if (tangent != null) {
          final prevTangent = metric.getTangentForOffset(
            distance - sampleInterval * 0.5,
          );
          final nextTangent = metric.getTangentForOffset(
            distance + sampleInterval * 0.5,
          );
          if (prevTangent != null && nextTangent != null) {
            final angleDiff =
                (prevTangent.angle - nextTangent.angle).abs() * 180 / math.pi;
            if (angleDiff > 15) {
              vertices.add(tangent.position);
            }
          }
        }
        distance += sampleInterval;
      }

      // End point
      final endTangent = metric.getTangentForOffset(metric.length);
      if (endTangent != null) {
        vertices.add(endTangent.position);
      }
    }

    return vertices;
  }

  double _calculateStartAngleForHit(List<Offset> vertices) {
    if (vertices.length < 2) return 0.0;
    return _angleBetweenPointsForHit(vertices[0], vertices[1]);
  }

  double _calculateEndAngleForHit(List<Offset> vertices) {
    if (vertices.length < 2) return 0.0;
    return _angleBetweenPointsForHit(
      vertices[vertices.length - 2],
      vertices[vertices.length - 1],
    );
  }

  double _calculateMidAngleForHit(List<Offset> vertices, int index) {
    if (index <= 0 || index >= vertices.length - 1) return 0.0;
    final p0 = vertices[index - 1];
    final p1 = vertices[index];
    final p2 = vertices[index + 1];

    final inAngle = _angleBetweenPointsForHit(p0, p1);
    final outAngle = _angleBetweenPointsForHit(p1, p2);

    var bisector = (inAngle + outAngle) / 2.0;
    final diff = (outAngle - inAngle).abs();
    if (diff > 180.0) {
      bisector += 180.0;
    }
    return bisector;
  }

  double _angleBetweenPointsForHit(Offset p1, Offset p2) {
    final dx = p2.dx - p1.dx;
    final dy = p2.dy - p1.dy;
    return (dy == 0 && dx == 0) ? 0.0 : math.atan2(dy, dx) * 180.0 / math.pi;
  }

  double _getEffectiveMarkerAngleForHit(
    _MarkerHitDefinition marker,
    double pathAngle,
    bool isStart,
  ) {
    switch (marker.orient) {
      case _MarkerOrientMode.auto:
        return pathAngle;
      case _MarkerOrientMode.autoStartReverse:
        return isStart ? pathAngle + 180.0 : pathAngle;
      case _MarkerOrientMode.angle:
        return marker.orientAngle;
    }
  }

  double _parseAngleForHit(String value) {
    final trimmed = value.trim().toLowerCase();
    if (trimmed.endsWith('rad')) {
      final num = double.tryParse(trimmed.replaceAll('rad', '')) ?? 0.0;
      return num * 180.0 / math.pi;
    } else if (trimmed.endsWith('grad')) {
      final num = double.tryParse(trimmed.replaceAll('grad', '')) ?? 0.0;
      return num * 0.9;
    } else if (trimmed.endsWith('turn')) {
      final num = double.tryParse(trimmed.replaceAll('turn', '')) ?? 0.0;
      return num * 360.0;
    } else {
      return double.tryParse(trimmed.replaceAll('deg', '')) ?? 0.0;
    }
  }

  // ============================================================================
  // GLYPH-PRECISION TEXT HIT-TESTING
  // ============================================================================

  /// Performs glyph-precision hit-testing for text.
  /// Uses per-character bounding boxes computed from font metrics.
  bool _glyphPrecisionTextContainsPoint(
    SvgNode node,
    Offset point, {
    required String pointerEvents,
    required bool visibilityHidden,
  }) {
    final textRoot = _findTextLayoutRoot(node);
    if (textRoot == null) return false;

    final runs = _buildGlyphPrecisionHitRuns(textRoot);
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

    if (!allowFill && !allowStroke) return false;

    for (final run in runs) {
      if (!_isNodeOrDescendant(run.owner, node)) continue;

      // Use the glyph's path outline for precise hit-testing
      if (run.glyphPath != null) {
        final testPoint = run.rotation != 0.0
            ? _inverseRotatePoint(point, run.rotationCenter, run.rotation)
            : point;

        if (allowFill && run.glyphPath!.contains(testPoint)) {
          return true;
        }
        if (allowStroke) {
          final tolerance = _strokeTolerance(node);
          if (_pathStrokeContains(run.glyphPath!, testPoint, tolerance)) {
            return true;
          }
        }
      } else if (run.bounds != null) {
        // Fall back to bounding box
        final testPoint = run.rotation != 0.0
            ? _inverseRotatePoint(point, run.rotationCenter, run.rotation)
            : point;
        if (run.bounds!.contains(testPoint)) {
          return true;
        }
      }
    }

    return false;
  }

  /// Builds glyph-precision hit runs with per-character bounds.
  List<_GlyphHitRun> _buildGlyphPrecisionHitRuns(SvgNode textRoot) {
    if (textRoot.tagName != 'text') return const [];

    final runs = <_GlyphHitRun>[];
    final xList = _getNumberList(textRoot, 'x');
    final yList = _getNumberList(textRoot, 'y');
    final dxList = _getNumberList(textRoot, 'dx');
    final dyList = _getNumberList(textRoot, 'dy');
    final rotateList = _getNumberList(textRoot, 'rotate');

    final startX = xList.isNotEmpty ? xList[0] : 0.0;
    final startY = yList.isNotEmpty ? yList[0] : 0.0;
    final cursor = _GlyphCursor(x: startX, y: startY);

    _appendGlyphPrecisionRuns(
      textRoot,
      cursor,
      runs,
      xList: xList,
      yList: yList,
      dxList: dxList,
      dyList: dyList,
      rotateList: rotateList,
    );

    return runs;
  }

  void _appendGlyphPrecisionRuns(
    SvgNode node,
    _GlyphCursor cursor,
    List<_GlyphHitRun> runs, {
    required List<double> xList,
    required List<double> yList,
    required List<double> dxList,
    required List<double> dyList,
    required List<double> rotateList,
  }) {
    // Parse position lists from this node
    final nodeXList = _getNumberList(node, 'x');
    final nodeYList = _getNumberList(node, 'y');
    final nodeDxList = _getNumberList(node, 'dx');
    final nodeDyList = _getNumberList(node, 'dy');
    final nodeRotateList = _getNumberList(node, 'rotate');

    // Merge with parent lists
    final effectiveXList = nodeXList.isNotEmpty ? nodeXList : xList;
    final effectiveYList = nodeYList.isNotEmpty ? nodeYList : yList;
    final effectiveDxList = nodeDxList.isNotEmpty ? nodeDxList : dxList;
    final effectiveDyList = nodeDyList.isNotEmpty ? nodeDyList : dyList;
    final effectiveRotateList = nodeRotateList.isNotEmpty
        ? nodeRotateList
        : rotateList;

    // Reset position if has absolute positioning
    if (nodeXList.isNotEmpty) cursor.x = nodeXList[0];
    if (nodeYList.isNotEmpty) cursor.y = nodeYList[0];

    final text = _extractTextContent(node);
    if (text != null && text.isNotEmpty) {
      final runes = text.runes.toList();
      final letterSpacing = _getInheritedNumber(node, 'letter-spacing') ?? 0.0;
      final textAnchor = _resolveTextAnchor(node);

      // Pre-calculate total width for text-anchor
      double totalWidth = 0.0;
      if (textAnchor != _TextAnchor.start) {
        for (int i = 0; i < runes.length; i++) {
          final char = String.fromCharCode(runes[i]);
          totalWidth += _measureText(char, node).width;
          if (i < runes.length - 1) totalWidth += letterSpacing;
        }
      }

      double anchorOffset = 0.0;
      if (textAnchor == _TextAnchor.middle) {
        anchorOffset = -totalWidth / 2;
      } else if (textAnchor == _TextAnchor.end) {
        anchorOffset = -totalWidth;
      }

      double charX = cursor.x + anchorOffset;
      int listIdx = cursor.charIndex;

      for (int i = 0; i < runes.length; i++) {
        final char = String.fromCharCode(runes[i]);

        // Apply per-character positioning
        if (listIdx < effectiveXList.length) {
          charX = effectiveXList[listIdx] + anchorOffset;
        }
        double charY = cursor.y;
        if (listIdx < effectiveYList.length) {
          charY = effectiveYList[listIdx];
        }
        if (listIdx < effectiveDxList.length) {
          charX += effectiveDxList[listIdx];
        }
        if (listIdx < effectiveDyList.length) {
          charY += effectiveDyList[listIdx];
        }

        double rotation = 0.0;
        if (effectiveRotateList.isNotEmpty) {
          rotation = listIdx < effectiveRotateList.length
              ? effectiveRotateList[listIdx]
              : effectiveRotateList.last;
        }

        final charMetrics = _measureText(char, node);
        final top = _resolveTextTopFromBaseline(
          node: node,
          baselineY: charY,
          metrics: charMetrics,
        );

        final charBounds = Rect.fromLTWH(
          charX,
          top,
          charMetrics.width,
          charMetrics.height,
        );

        // Create approximate glyph path from bounds
        // This gives per-character precision without font outline access
        final glyphPath = Path()..addRect(charBounds);

        runs.add(
          _GlyphHitRun(
            owner: node,
            bounds: charBounds,
            glyphPath: glyphPath,
            rotation: rotation,
            rotationCenter: Offset(charX, charY),
          ),
        );

        charX += charMetrics.width + letterSpacing;
        listIdx++;
      }

      cursor.x = charX - anchorOffset;
      cursor.charIndex += runes.length;
    }

    // Process children
    for (final child in node.children) {
      if (child.tagName == 'tspan') {
        _appendGlyphPrecisionRuns(
          child,
          cursor,
          runs,
          xList: effectiveXList,
          yList: effectiveYList,
          dxList: effectiveDxList,
          dyList: effectiveDyList,
          rotateList: effectiveRotateList,
        );
      }
    }
  }

  // ============================================================================
  // ADVANCED EVENODD FILL-RULE HIT-TESTING
  // ============================================================================

  /// Checks if a point is inside a path using evenodd fill rule with
  /// improved handling of degenerate cases (collinear edges, zero-length
  /// segments, cusps).
  bool _evenoddContainsPointAdvanced(Path path, Offset point) {
    // First, use Flutter's built-in containment check
    final flutterResult = path.contains(point);

    // For most cases, Flutter's implementation is sufficient
    // Only apply additional checks for edge cases
    if (!_isNearPathBoundary(path, point)) {
      return flutterResult;
    }

    // For points near path boundary, use winding number with robust handling
    return _robustEvenoddContains(path, point);
  }

  /// Checks if a point is near the path boundary (within tolerance).
  bool _isNearPathBoundary(Path path, Offset point) {
    const tolerance = 0.5;
    final metrics = path.computeMetrics();

    for (final metric in metrics) {
      // Sample along the path to check proximity
      final sampleCount = (metric.length / 2.0).ceil().clamp(10, 100);
      for (int i = 0; i <= sampleCount; i++) {
        final distance = i * metric.length / sampleCount;
        final tangent = metric.getTangentForOffset(distance);
        if (tangent != null) {
          final distToPoint = (tangent.position - point).distance;
          if (distToPoint <= tolerance) {
            return true;
          }
        }
      }
    }

    return false;
  }

  /// Robust evenodd containment test for edge cases.
  bool _robustEvenoddContains(Path path, Offset point) {
    // Convert path to line segments
    final segments = _pathToSegments(path);
    if (segments.isEmpty) return false;

    // Count ray-edge intersections
    int crossings = 0;
    final rayEnd = Offset(point.dx + 10000, point.dy);

    for (final segment in segments) {
      // Skip degenerate (zero-length) segments
      final segmentLength = (segment.end - segment.start).distance;
      if (segmentLength < 1e-10) continue;

      // Check if segment is collinear with ray (horizontal)
      if ((segment.start.dy - point.dy).abs() < 1e-10 &&
          (segment.end.dy - point.dy).abs() < 1e-10) {
        // Collinear segment - check if point is on it
        final minX = math.min(segment.start.dx, segment.end.dx);
        final maxX = math.max(segment.start.dx, segment.end.dx);
        if (point.dx >= minX && point.dx <= maxX) {
          return true; // On boundary
        }
        continue;
      }

      // Check for intersection with horizontal ray
      if (_rayIntersectsSegment(point, rayEnd, segment.start, segment.end)) {
        crossings++;
      }
    }

    // Evenodd: point is inside if crossing count is odd
    return crossings % 2 == 1;
  }

  /// Checks if a horizontal ray intersects a line segment.
  bool _rayIntersectsSegment(
    Offset rayStart,
    Offset rayEnd,
    Offset segStart,
    Offset segEnd,
  ) {
    // Ensure segment endpoints are ordered by Y
    Offset p1, p2;
    if (segStart.dy <= segEnd.dy) {
      p1 = segStart;
      p2 = segEnd;
    } else {
      p1 = segEnd;
      p2 = segStart;
    }

    // Check if ray Y is within segment Y range
    if (rayStart.dy <= p1.dy || rayStart.dy > p2.dy) {
      return false;
    }

    // Check if ray X is left of both segment endpoints
    if (rayStart.dx >= math.max(p1.dx, p2.dx)) {
      return false;
    }

    // Check if ray X is left of minimum X
    if (rayStart.dx < math.min(p1.dx, p2.dx)) {
      return true;
    }

    // Calculate intersection X
    final t = (rayStart.dy - p1.dy) / (p2.dy - p1.dy);
    final intersectX = p1.dx + t * (p2.dx - p1.dx);

    return rayStart.dx < intersectX;
  }

  /// Converts a path to line segments for robust containment testing.
  List<_LineSegment> _pathToSegments(Path path) {
    final segments = <_LineSegment>[];
    final metrics = path.computeMetrics();

    for (final metric in metrics) {
      Offset? lastPoint;
      final sampleCount = (metric.length / 0.5).ceil().clamp(10, 1000);

      for (int i = 0; i <= sampleCount; i++) {
        final distance = i * metric.length / sampleCount;
        final tangent = metric.getTangentForOffset(distance);
        if (tangent != null) {
          if (lastPoint != null) {
            segments.add(_LineSegment(lastPoint, tangent.position));
          }
          lastPoint = tangent.position;
        }
      }
    }

    return segments;
  }
}

// ============================================================================
// HELPER CLASSES
// ============================================================================

/// Marker definition for hit-testing.
class _MarkerHitDefinition {
  const _MarkerHitDefinition({
    required this.node,
    required this.refX,
    required this.refY,
    required this.markerWidth,
    required this.markerHeight,
    required this.useStrokeWidth,
    required this.orient,
    required this.orientAngle,
    this.viewBox,
  });

  final SvgNode node;
  final double refX;
  final double refY;
  final double markerWidth;
  final double markerHeight;
  final bool useStrokeWidth;
  final _MarkerOrientMode orient;
  final double orientAngle;
  final Rect? viewBox;
}

enum _MarkerOrientMode { auto, autoStartReverse, angle }

/// Glyph hit run for per-character precision.
class _GlyphHitRun {
  const _GlyphHitRun({
    required this.owner,
    this.bounds,
    this.glyphPath,
    this.rotation = 0.0,
    required this.rotationCenter,
  });

  final SvgNode owner;
  final Rect? bounds;
  final Path? glyphPath;
  final double rotation;
  final Offset rotationCenter;
}

/// Cursor for glyph positioning.
class _GlyphCursor {
  _GlyphCursor({required this.x, required this.y});

  double x;
  double y;
  int charIndex = 0;
}

/// Line segment for containment testing.
class _LineSegment {
  const _LineSegment(this.start, this.end);

  final Offset start;
  final Offset end;
}
