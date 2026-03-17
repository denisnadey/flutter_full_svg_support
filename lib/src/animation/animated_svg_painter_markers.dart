part of 'animated_svg_painter.dart';

extension AnimatedSvgPainterMarkersExtension on AnimatedSvgPainter {
  /// Resolves a marker definition by ID.
  _ResolvedMarkerDefinition? _resolveMarkerDefinition(String markerId) {
    final cached = _markerCache[markerId];
    if (cached != null || _markerCache.containsKey(markerId)) {
      return cached;
    }

    final node = document.root.findById(markerId);
    if (node == null || node.tagName != 'marker') {
      _markerCache[markerId] = null;
      return null;
    }

    final refX = _getNumber(node, 'refX') ?? 0.0;
    final refY = _getNumber(node, 'refY') ?? 0.0;
    final markerWidth = _getNumber(node, 'markerWidth') ?? 3.0;
    final markerHeight = _getNumber(node, 'markerHeight') ?? 3.0;

    // Parse markerUnits
    final unitsStr = _getString(node, 'markerUnits')?.toLowerCase();
    final markerUnits = unitsStr == 'userspaceonuse'
        ? _SvgMarkerUnits.userSpaceOnUse
        : _SvgMarkerUnits.strokeWidth;

    // Parse orient
    final orientStr = _getString(node, 'orient')?.toLowerCase().trim();
    _SvgMarkerOrient orient;
    double orientAngle = 0.0;
    if (orientStr == null || orientStr == 'auto' || orientStr.isEmpty) {
      orient = _SvgMarkerOrient.auto;
    } else if (orientStr == 'auto-start-reverse') {
      orient = _SvgMarkerOrient.autoStartReverse;
    } else {
      orient = _SvgMarkerOrient.angle;
      // Parse angle value (may include 'deg', 'rad', 'grad', 'turn')
      orientAngle = _parseAngle(orientStr);
    }

    // Parse viewBox if present
    final viewBoxStr = _getString(node, 'viewBox');
    ui.Rect? viewBox;
    if (viewBoxStr != null && viewBoxStr.isNotEmpty) {
      final parts = viewBoxStr.trim().split(RegExp(r'[\s,]+'));
      if (parts.length == 4) {
        final minX = double.tryParse(parts[0]) ?? 0.0;
        final minY = double.tryParse(parts[1]) ?? 0.0;
        final vbWidth = double.tryParse(parts[2]) ?? markerWidth;
        final vbHeight = double.tryParse(parts[3]) ?? markerHeight;
        viewBox = ui.Rect.fromLTWH(minX, minY, vbWidth, vbHeight);
      }
    }

    final resolved = _ResolvedMarkerDefinition(
      node: node,
      refX: refX,
      refY: refY,
      markerWidth: markerWidth,
      markerHeight: markerHeight,
      markerUnits: markerUnits,
      orient: orient,
      orientAngle: orientAngle,
      viewBox: viewBox,
    );
    _markerCache[markerId] = resolved;
    return resolved;
  }

  /// Parses angle value with optional unit (deg, rad, grad, turn).
  double _parseAngle(String value) {
    final trimmed = value.trim().toLowerCase();
    if (trimmed.endsWith('rad')) {
      final num = double.tryParse(trimmed.replaceAll('rad', '')) ?? 0.0;
      return num * 180.0 / 3.14159265358979;
    } else if (trimmed.endsWith('grad')) {
      final num = double.tryParse(trimmed.replaceAll('grad', '')) ?? 0.0;
      return num * 0.9; // 1 grad = 0.9 degrees
    } else if (trimmed.endsWith('turn')) {
      final num = double.tryParse(trimmed.replaceAll('turn', '')) ?? 0.0;
      return num * 360.0;
    } else {
      // Default: degrees (may or may not have 'deg' suffix)
      final num = double.tryParse(trimmed.replaceAll('deg', '')) ?? 0.0;
      return num;
    }
  }

  /// Resolves marker-start, marker-mid, marker-end from a node.
  /// Returns (markerStart, markerMid, markerEnd) or null for each.
  (String?, String?, String?) _resolveMarkerRefs(SvgNode node) {
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
    final startVal =
        _getInheritedAttributeValue(node, 'marker-start')?.toString();
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

  /// Paints markers along a path at start, mid, and end positions.
  void _paintMarkers(
    ui.Canvas canvas,
    SvgNode node,
    ui.Path path, {
    ui.ImageFilter? imageFilter,
    ui.ColorFilter? colorFilter,
    ui.BlendMode? blendMode,
  }) {
    final (markerStartId, markerMidId, markerEndId) = _resolveMarkerRefs(node);
    if (markerStartId == null && markerMidId == null && markerEndId == null) {
      return;
    }

    final strokeWidth = _getInheritedNumber(node, 'stroke-width') ?? 1.0;
    final vertices = _extractPathVertices(path);
    if (vertices.isEmpty) return;

    // Paint marker-start
    if (markerStartId != null && vertices.isNotEmpty) {
      final marker = _resolveMarkerDefinition(markerStartId);
      if (marker != null) {
        final pos = vertices.first;
        final angle = _calculateStartAngle(vertices);
        final effectiveAngle = _getEffectiveMarkerAngle(marker, angle, true);
        _paintMarker(
          canvas,
          marker,
          pos.position,
          effectiveAngle,
          strokeWidth,
          imageFilter: imageFilter,
          colorFilter: colorFilter,
          blendMode: blendMode,
        );
      }
    }

    // Paint marker-mid
    if (markerMidId != null && vertices.length > 2) {
      final marker = _resolveMarkerDefinition(markerMidId);
      if (marker != null) {
        for (int i = 1; i < vertices.length - 1; i++) {
          final pos = vertices[i];
          final angle = _calculateMidAngle(vertices, i);
          final effectiveAngle = _getEffectiveMarkerAngle(marker, angle, false);
          _paintMarker(
            canvas,
            marker,
            pos.position,
            effectiveAngle,
            strokeWidth,
            imageFilter: imageFilter,
            colorFilter: colorFilter,
            blendMode: blendMode,
          );
        }
      }
    }

    // Paint marker-end
    if (markerEndId != null && vertices.length >= 2) {
      final marker = _resolveMarkerDefinition(markerEndId);
      if (marker != null) {
        final pos = vertices.last;
        final angle = _calculateEndAngle(vertices);
        final effectiveAngle = _getEffectiveMarkerAngle(marker, angle, false);
        _paintMarker(
          canvas,
          marker,
          pos.position,
          effectiveAngle,
          strokeWidth,
          imageFilter: imageFilter,
          colorFilter: colorFilter,
          blendMode: blendMode,
        );
      }
    }
  }

  /// Calculates effective angle based on marker orient mode.
  double _getEffectiveMarkerAngle(
    _ResolvedMarkerDefinition marker,
    double pathAngle,
    bool isStart,
  ) {
    switch (marker.orient) {
      case _SvgMarkerOrient.auto:
        return pathAngle;
      case _SvgMarkerOrient.autoStartReverse:
        return isStart ? pathAngle + 180.0 : pathAngle;
      case _SvgMarkerOrient.angle:
        return marker.orientAngle;
    }
  }

  /// Paints a single marker at a position with given angle.
  void _paintMarker(
    ui.Canvas canvas,
    _ResolvedMarkerDefinition marker,
    ui.Offset position,
    double angle,
    double strokeWidth, {
    ui.ImageFilter? imageFilter,
    ui.ColorFilter? colorFilter,
    ui.BlendMode? blendMode,
  }) {
    canvas.save();

    // Move to marker position
    canvas.translate(position.dx, position.dy);

    // Rotate by angle
    if (angle != 0.0) {
      canvas.rotate(angle * 3.14159265358979 / 180.0);
    }

    // Apply scale based on markerUnits
    var scaleX = 1.0;
    var scaleY = 1.0;
    if (marker.markerUnits == _SvgMarkerUnits.strokeWidth) {
      scaleX = strokeWidth;
      scaleY = strokeWidth;
    }

    // Apply viewBox scaling if present
    if (marker.viewBox != null) {
      final vb = marker.viewBox!;
      if (vb.width > 0 && vb.height > 0) {
        scaleX *= marker.markerWidth / vb.width;
        scaleY *= marker.markerHeight / vb.height;
      }
    }

    if (scaleX != 1.0 || scaleY != 1.0) {
      canvas.scale(scaleX, scaleY);
    }

    // Translate by -refX, -refY
    canvas.translate(-marker.refX, -marker.refY);

    // Paint marker contents
    for (final child in marker.node.children) {
      _paintNode(canvas, child);
    }

    canvas.restore();
  }

  /// Calculates start angle (angle at first vertex).
  double _calculateStartAngle(List<_PathVertex> vertices) {
    if (vertices.length < 2) return 0.0;
    final p1 = vertices[0].position;
    final p2 = vertices[1].position;
    return _angleBetweenPoints(p1, p2);
  }

  /// Calculates end angle (angle at last vertex).
  double _calculateEndAngle(List<_PathVertex> vertices) {
    if (vertices.length < 2) return 0.0;
    final p1 = vertices[vertices.length - 2].position;
    final p2 = vertices[vertices.length - 1].position;
    return _angleBetweenPoints(p1, p2);
  }

  /// Calculates mid angle (bisector of incoming and outgoing segments).
  double _calculateMidAngle(List<_PathVertex> vertices, int index) {
    if (index <= 0 || index >= vertices.length - 1) return 0.0;
    final p0 = vertices[index - 1].position;
    final p1 = vertices[index].position;
    final p2 = vertices[index + 1].position;

    final inAngle = _angleBetweenPoints(p0, p1);
    final outAngle = _angleBetweenPoints(p1, p2);

    // Return bisector angle
    var bisector = (inAngle + outAngle) / 2.0;
    // Ensure we get the correct bisector direction
    final diff = (outAngle - inAngle).abs();
    if (diff > 180.0) {
      bisector += 180.0;
    }
    return bisector;
  }

  /// Calculates angle between two points in degrees.
  double _angleBetweenPoints(ui.Offset p1, ui.Offset p2) {
    final dx = p2.dx - p1.dx;
    final dy = p2.dy - p1.dy;
    return (dy == 0 && dx == 0) ? 0.0 : _atan2Degrees(dy, dx);
  }

  double _atan2Degrees(double y, double x) {
    return (x == 0 && y == 0)
        ? 0.0
        : (180.0 / 3.14159265358979) *
            (y < 0
                ? -_acos(x / _sqrt(x * x + y * y))
                : _acos(x / _sqrt(x * x + y * y)));
  }

  double _acos(double x) {
    // Clamp to valid range
    if (x >= 1.0) return 0.0;
    if (x <= -1.0) return 3.14159265358979;
    // Taylor series approximation
    return 3.14159265358979 / 2.0 - _asin(x);
  }

  double _asin(double x) {
    // Clamp to valid range
    if (x >= 1.0) return 3.14159265358979 / 2.0;
    if (x <= -1.0) return -3.14159265358979 / 2.0;
    // Use dart:math through ui library
    return x.isNaN ? 0.0 : _atan2(x, _sqrt(1 - x * x));
  }

  double _sqrt(double x) => x <= 0 ? 0.0 : x * 0.5 + 0.5 * x / (x * 0.5 + 1);

  double _atan2(double y, double x) {
    // Simple atan2 using dart:math
    if (x > 0) {
      return _atan(y / x);
    } else if (x < 0 && y >= 0) {
      return _atan(y / x) + 3.14159265358979;
    } else if (x < 0 && y < 0) {
      return _atan(y / x) - 3.14159265358979;
    } else if (x == 0 && y > 0) {
      return 3.14159265358979 / 2.0;
    } else if (x == 0 && y < 0) {
      return -3.14159265358979 / 2.0;
    }
    return 0.0;
  }

  double _atan(double x) {
    // Taylor series for small values, otherwise use identity
    if (x.abs() <= 1) {
      // Taylor series
      double result = x;
      double term = x;
      for (int i = 1; i < 10; i++) {
        term *= -x * x;
        result += term / (2 * i + 1);
      }
      return result;
    } else if (x > 0) {
      return 3.14159265358979 / 2.0 - _atan(1 / x);
    } else {
      return -3.14159265358979 / 2.0 - _atan(1 / x);
    }
  }
}

/// Represents a vertex in a path.
class _PathVertex {
  const _PathVertex(this.position);
  final ui.Offset position;
}

extension _PathVertexExtraction on AnimatedSvgPainter {
  /// Extracts vertices from a path for marker placement.
  List<_PathVertex> _extractPathVertices(ui.Path path) {
    final vertices = <_PathVertex>[];
    final metrics = path.computeMetrics();

    for (final metric in metrics) {
      if (metric.length <= 0) continue;

      // Sample start point
      final startTangent = metric.getTangentForOffset(0);
      if (startTangent != null) {
        vertices.add(_PathVertex(startTangent.position));
      }

      // Sample at regular intervals for intermediate points
      const sampleInterval = 1.0; // Sample every 1 unit
      var distance = sampleInterval;
      while (distance < metric.length - sampleInterval) {
        final tangent = metric.getTangentForOffset(distance);
        if (tangent != null) {
          // Check if this is a "corner" point (significant direction change)
          final prevTangent =
              metric.getTangentForOffset(distance - sampleInterval * 0.5);
          final nextTangent =
              metric.getTangentForOffset(distance + sampleInterval * 0.5);
          if (prevTangent != null && nextTangent != null) {
            final angleDiff =
                (prevTangent.angle - nextTangent.angle).abs() * 180 / 3.14159;
            if (angleDiff > 15) {
              // Corner detected
              vertices.add(_PathVertex(tangent.position));
            }
          }
        }
        distance += sampleInterval;
      }

      // Sample end point
      final endTangent = metric.getTangentForOffset(metric.length);
      if (endTangent != null) {
        vertices.add(_PathVertex(endTangent.position));
      }
    }

    return vertices;
  }
}
