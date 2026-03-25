part of 'animated_svg_picture.dart';

extension _AnimatedSvgPictureStateHitTestGeometryExtension
    on _AnimatedSvgPictureState {
  bool _nodeContainsPoint(
    SvgNode node,
    Offset documentPoint,
    Matrix4 transform,
  ) {
    final inverse = Matrix4.tryInvert(transform);
    if (inverse == null) {
      return false;
    }
    final point = MatrixUtils.transformPoint(inverse, documentPoint);
    final pointerEvents = _resolvePointerEventsMode(node);
    final visibilityHidden = _isVisibilityHidden(node);

    switch (node.tagName) {
      case 'rect':
        final x = _getNumber(node, 'x') ?? 0.0;
        final y = _getNumber(node, 'y') ?? 0.0;
        final width = _getNumber(node, 'width') ?? 0.0;
        final height = _getNumber(node, 'height') ?? 0.0;
        if (width <= 0 || height <= 0) return false;
        if (pointerEvents == 'bounding-box') {
          return Rect.fromLTWH(x, y, width, height).contains(point);
        }

        // SVG spec: rx/ry handling
        final rxRaw = _getNumber(node, 'rx');
        final ryRaw = _getNumber(node, 'ry');

        double rx;
        double ry;
        if (rxRaw == null && ryRaw == null) {
          rx = 0.0;
          ry = 0.0;
        } else if (rxRaw != null && ryRaw == null) {
          rx = rxRaw;
          ry = rxRaw;
        } else if (rxRaw == null && ryRaw != null) {
          rx = ryRaw;
          ry = ryRaw;
        } else {
          rx = rxRaw!;
          ry = ryRaw!;
        }

        // Negative rx/ry is an error
        if (rx < 0 || ry < 0) return false;

        // Clamp rx/ry to half of width/height
        rx = rx.clamp(0.0, width / 2);
        ry = ry.clamp(0.0, height / 2);

        final rect = Rect.fromLTWH(x, y, width, height);
        final rectPath = Path();
        if (rx > 0 || ry > 0) {
          rectPath.addRRect(RRect.fromRectXY(rect, rx, ry));
        } else {
          rectPath.addRect(rect);
        }
        if (_pointerEventsAllowsFill(
              node,
              pointerEvents,
              visibilityHidden: visibilityHidden,
            ) &&
            rectPath.contains(point)) {
          return true;
        }
        if (_pointerEventsAllowsStroke(
          node,
          pointerEvents,
          visibilityHidden: visibilityHidden,
        )) {
          final tolerance = _strokeTolerance(node);
          return _pathStrokeContains(rectPath, point, tolerance);
        }
        return false;
      case 'circle':
        final cx = _getNumber(node, 'cx') ?? 0.0;
        final cy = _getNumber(node, 'cy') ?? 0.0;
        final r = _getNumber(node, 'r') ?? 0.0;
        if (r <= 0) return false;
        if (pointerEvents == 'bounding-box') {
          return Rect.fromCircle(
            center: Offset(cx, cy),
            radius: r,
          ).contains(point);
        }
        final circlePath = Path()
          ..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r));
        if (_pointerEventsAllowsFill(
              node,
              pointerEvents,
              visibilityHidden: visibilityHidden,
            ) &&
            circlePath.contains(point)) {
          return true;
        }
        if (_pointerEventsAllowsStroke(
          node,
          pointerEvents,
          visibilityHidden: visibilityHidden,
        )) {
          final tolerance = _strokeTolerance(node);
          return _pathStrokeContains(circlePath, point, tolerance);
        }
        return false;
      case 'ellipse':
        final cx = _getNumber(node, 'cx') ?? 0.0;
        final cy = _getNumber(node, 'cy') ?? 0.0;
        final rx = _getNumber(node, 'rx') ?? 0.0;
        final ry = _getNumber(node, 'ry') ?? 0.0;
        if (rx <= 0 || ry <= 0) return false;
        if (pointerEvents == 'bounding-box') {
          return Rect.fromCenter(
            center: Offset(cx, cy),
            width: rx * 2,
            height: ry * 2,
          ).contains(point);
        }
        final ellipsePath = Path()
          ..addOval(
            Rect.fromCenter(
              center: Offset(cx, cy),
              width: rx * 2,
              height: ry * 2,
            ),
          );
        if (_pointerEventsAllowsFill(
              node,
              pointerEvents,
              visibilityHidden: visibilityHidden,
            ) &&
            ellipsePath.contains(point)) {
          return true;
        }
        if (_pointerEventsAllowsStroke(
          node,
          pointerEvents,
          visibilityHidden: visibilityHidden,
        )) {
          final tolerance = _strokeTolerance(node);
          return _pathStrokeContains(ellipsePath, point, tolerance);
        }
        return false;
      case 'line':
        final x1 = _getNumber(node, 'x1') ?? 0.0;
        final y1 = _getNumber(node, 'y1') ?? 0.0;
        final x2 = _getNumber(node, 'x2') ?? 0.0;
        final y2 = _getNumber(node, 'y2') ?? 0.0;
        if (pointerEvents == 'bounding-box') {
          final bounds = Rect.fromLTRB(
            math.min(x1, x2),
            math.min(y1, y2),
            math.max(x1, x2),
            math.max(y1, y2),
          );
          // Degenerate line bounds are inflated by stroke tolerance so
          // vertical/horizontal lines remain hit-testable.
          final tolerance = _strokeTolerance(node);
          return bounds.inflate(tolerance).contains(point);
        }
        if (!_pointerEventsAllowsStroke(
          node,
          pointerEvents,
          visibilityHidden: visibilityHidden,
        )) {
          return false;
        }
        final tolerance = _strokeTolerance(node);
        final linecapTolerance = _strokeLinecapTolerance(node);
        final startPoint = Offset(x1, y1);
        final endPoint = Offset(x2, y2);

        // Check distance to endpoints with linecap consideration
        // For round/square linecap, endpoints have extra hit area
        if (linecapTolerance > 0) {
          final startDist = (point - startPoint).distance;
          final endDist = (point - endPoint).distance;
          if (startDist <= tolerance + linecapTolerance ||
              endDist <= tolerance + linecapTolerance) {
            return true;
          }
        }

        // Check distance to line segment
        final distance = _distanceToSegment(point, startPoint, endPoint);
        return distance <= tolerance;
      case 'image':
        final x = _getNumber(node, 'x') ?? 0.0;
        final y = _getNumber(node, 'y') ?? 0.0;
        final width = _getNumber(node, 'width') ?? 0.0;
        final height = _getNumber(node, 'height') ?? 0.0;
        if (width <= 0 ||
            height <= 0 ||
            !_pointerEventsAllowsBoundingBox(
              pointerEvents,
              visibilityHidden: visibilityHidden,
            )) {
          return false;
        }
        return Rect.fromLTWH(x, y, width, height).contains(point);
      case 'foreignObject':
        final x = _getNumber(node, 'x') ?? 0.0;
        final y = _getNumber(node, 'y') ?? 0.0;
        final width = _getNumber(node, 'width') ?? 0.0;
        final height = _getNumber(node, 'height') ?? 0.0;
        if (width <= 0 ||
            height <= 0 ||
            !_pointerEventsAllowsBoundingBox(
              pointerEvents,
              visibilityHidden: visibilityHidden,
            )) {
          return false;
        }
        return Rect.fromLTWH(x, y, width, height).contains(point);
      case 'path':
        final path = _buildPathGeometry(node);
        if (path == null) {
          return false;
        }
        if (pointerEvents == 'bounding-box') {
          return path.getBounds().contains(point);
        }

        if (_pointerEventsAllowsFill(
              node,
              pointerEvents,
              visibilityHidden: visibilityHidden,
            ) &&
            path.contains(point)) {
          return true;
        }

        if (_pointerEventsAllowsStroke(
          node,
          pointerEvents,
          visibilityHidden: visibilityHidden,
        )) {
          final tolerance = _strokeTolerance(node);
          return _pathStrokeContains(path, point, tolerance);
        }
        return false;
      case 'polygon':
        final polygonPoints = _parsePoints(node);
        if (polygonPoints.length < 3) return false;

        final polygonPath = Path()
          ..moveTo(polygonPoints.first.dx, polygonPoints.first.dy);
        for (int i = 1; i < polygonPoints.length; i++) {
          polygonPath.lineTo(polygonPoints[i].dx, polygonPoints[i].dy);
        }
        polygonPath.close();
        if (pointerEvents == 'bounding-box') {
          return polygonPath.getBounds().contains(point);
        }

        if (_pointerEventsAllowsFill(
              node,
              pointerEvents,
              visibilityHidden: visibilityHidden,
            ) &&
            polygonPath.contains(point)) {
          return true;
        }

        if (_pointerEventsAllowsStroke(
          node,
          pointerEvents,
          visibilityHidden: visibilityHidden,
        )) {
          final tolerance = _strokeTolerance(node);
          for (int i = 0; i < polygonPoints.length; i++) {
            final a = polygonPoints[i];
            final b = polygonPoints[(i + 1) % polygonPoints.length];
            if (_distanceToSegment(point, a, b) <= tolerance) {
              return true;
            }
          }
        }
        return false;
      case 'polyline':
        final polylinePoints = _parsePoints(node);
        if (polylinePoints.length < 2) return false;
        if (pointerEvents == 'bounding-box') {
          final polylinePath = Path()
            ..moveTo(polylinePoints.first.dx, polylinePoints.first.dy);
          for (int i = 1; i < polylinePoints.length; i++) {
            polylinePath.lineTo(polylinePoints[i].dx, polylinePoints[i].dy);
          }
          return polylinePath.getBounds().contains(point);
        }

        if (_pointerEventsAllowsStroke(
          node,
          pointerEvents,
          visibilityHidden: visibilityHidden,
        )) {
          final tolerance = _strokeTolerance(node);
          final linecapTolerance = _strokeLinecapTolerance(node);

          // Check endpoints with linecap
          if (linecapTolerance > 0) {
            final startDist = (point - polylinePoints.first).distance;
            final endDist = (point - polylinePoints.last).distance;
            if (startDist <= tolerance + linecapTolerance ||
                endDist <= tolerance + linecapTolerance) {
              return true;
            }
          }

          // Check each segment
          for (int i = 0; i < polylinePoints.length - 1; i++) {
            if (_distanceToSegment(
                  point,
                  polylinePoints[i],
                  polylinePoints[i + 1],
                ) <=
                tolerance) {
              return true;
            }
          }
        }

        if (_pointerEventsAllowsFill(
          node,
          pointerEvents,
          visibilityHidden: visibilityHidden,
        )) {
          final polylinePath = Path()
            ..moveTo(polylinePoints.first.dx, polylinePoints.first.dy);
          for (int i = 1; i < polylinePoints.length; i++) {
            polylinePath.lineTo(polylinePoints[i].dx, polylinePoints[i].dy);
          }
          return polylinePath.contains(point);
        }
        return false;
      case 'text':
      case 'tspan':
        return _textNodeContainsPoint(
          node,
          point,
          pointerEvents: pointerEvents,
          visibilityHidden: visibilityHidden,
        );
      case 'textPath':
        return _textPathContainsPoint(
          node,
          point,
          pointerEvents: pointerEvents,
          visibilityHidden: visibilityHidden,
        );
      default:
        return false;
    }
  }

  bool _textNodeContainsPoint(
    SvgNode node,
    Offset point, {
    required String pointerEvents,
    required bool visibilityHidden,
  }) {
    return _textRunsContainPoint(
      node,
      point,
      pointerEvents: pointerEvents,
      visibilityHidden: visibilityHidden,
    );
  }

  bool _textPathContainsPoint(
    SvgNode textPathNode,
    Offset point, {
    required String pointerEvents,
    required bool visibilityHidden,
  }) {
    return _textRunsContainPoint(
      textPathNode,
      point,
      pointerEvents: pointerEvents,
      visibilityHidden: visibilityHidden,
    );
  }
}
