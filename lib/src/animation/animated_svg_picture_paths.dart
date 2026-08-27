part of 'animated_svg_picture.dart';

extension _AnimatedSvgPictureStatePathsExtension on _AnimatedSvgPictureState {
  /// Invalidate hit-test path cache when animation time changes.
  void _prepareHitTestCache(double? animationTime) {
    if (_hasAnimations && _hitTestCacheTime != animationTime) {
      _hitTestPathCache.clear();
      _hitTestCacheTime = animationTime;
    }
  }

  Path? _buildPathGeometry(SvgNode node) {
    final pathData = node.getAttributeValue('d')?.toString();
    if (pathData == null || pathData.isEmpty) {
      return null;
    }

    // Generate cache key from node ID (or fallback to pathData hash)
    final nodeId = node.id ?? '';
    final cacheKey = 'p:$nodeId|h:${pathData.hashCode}';

    // Check cache first
    final cached = _hitTestPathCache[cacheKey];
    if (cached != null) {
      return cached;
    }

    final path = _buildPath(pathData);
    if (path == null) {
      return null;
    }

    _applyPathFillType(path, node);

    // Cache the result
    _hitTestPathCache[cacheKey] = path;

    return path;
  }

  Path? _buildGeometryPath(SvgNode node) {
    switch (node.tagName) {
      case 'rect':
        final x =
            resolveSvgLength(
              node,
              _document,
              'x',
              reference: SvgLengthReference.horizontal,
            ) ??
            0.0;
        final y =
            resolveSvgLength(
              node,
              _document,
              'y',
              reference: SvgLengthReference.vertical,
            ) ??
            0.0;
        final width =
            resolveSvgLength(
              node,
              _document,
              'width',
              reference: SvgLengthReference.horizontal,
            ) ??
            0.0;
        final height =
            resolveSvgLength(
              node,
              _document,
              'height',
              reference: SvgLengthReference.vertical,
            ) ??
            0.0;
        if (width <= 0 || height <= 0) {
          return null;
        }

        // SVG spec: rx/ry handling
        final rxRaw = resolveSvgLength(
          node,
          _document,
          'rx',
          reference: SvgLengthReference.horizontal,
        );
        final ryRaw = resolveSvgLength(
          node,
          _document,
          'ry',
          reference: SvgLengthReference.vertical,
        );

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
        if (rx < 0 || ry < 0) return null;

        // Clamp rx/ry to half of width/height
        rx = rx.clamp(0.0, width / 2);
        ry = ry.clamp(0.0, height / 2);

        if (rx > 0 || ry > 0) {
          return Path()..addRRect(
            RRect.fromRectXY(Rect.fromLTWH(x, y, width, height), rx, ry),
          );
        }
        return Path()..addRect(Rect.fromLTWH(x, y, width, height));
      case 'circle':
        final cx =
            resolveSvgLength(
              node,
              _document,
              'cx',
              reference: SvgLengthReference.horizontal,
            ) ??
            0.0;
        final cy =
            resolveSvgLength(
              node,
              _document,
              'cy',
              reference: SvgLengthReference.vertical,
            ) ??
            0.0;
        final r =
            resolveSvgLength(
              node,
              _document,
              'r',
              reference: SvgLengthReference.normalizedDiagonal,
            ) ??
            0.0;
        if (r <= 0) {
          return null;
        }
        return Path()
          ..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r));
      case 'ellipse':
        final cx =
            resolveSvgLength(
              node,
              _document,
              'cx',
              reference: SvgLengthReference.horizontal,
            ) ??
            0.0;
        final cy =
            resolveSvgLength(
              node,
              _document,
              'cy',
              reference: SvgLengthReference.vertical,
            ) ??
            0.0;
        final rx =
            resolveSvgLength(
              node,
              _document,
              'rx',
              reference: SvgLengthReference.horizontal,
            ) ??
            0.0;
        final ry =
            resolveSvgLength(
              node,
              _document,
              'ry',
              reference: SvgLengthReference.vertical,
            ) ??
            0.0;
        if (rx <= 0 || ry <= 0) {
          return null;
        }
        return Path()..addOval(
          Rect.fromCenter(
            center: Offset(cx, cy),
            width: rx * 2,
            height: ry * 2,
          ),
        );
      case 'line':
        final x1 =
            resolveSvgLength(
              node,
              _document,
              'x1',
              reference: SvgLengthReference.horizontal,
            ) ??
            0.0;
        final y1 =
            resolveSvgLength(
              node,
              _document,
              'y1',
              reference: SvgLengthReference.vertical,
            ) ??
            0.0;
        final x2 =
            resolveSvgLength(
              node,
              _document,
              'x2',
              reference: SvgLengthReference.horizontal,
            ) ??
            0.0;
        final y2 =
            resolveSvgLength(
              node,
              _document,
              'y2',
              reference: SvgLengthReference.vertical,
            ) ??
            0.0;
        return Path()
          ..moveTo(x1, y1)
          ..lineTo(x2, y2);
      case 'polygon':
        final points = _parsePoints(node);
        if (points.length < 3) {
          return null;
        }
        final path = Path()..moveTo(points.first.dx, points.first.dy);
        for (int i = 1; i < points.length; i++) {
          path.lineTo(points[i].dx, points[i].dy);
        }
        path.close();
        _applyPathFillType(path, node);
        return path;
      case 'polyline':
        final points = _parsePoints(node);
        if (points.length < 2) {
          return null;
        }
        final path = Path()..moveTo(points.first.dx, points.first.dy);
        for (int i = 1; i < points.length; i++) {
          path.lineTo(points[i].dx, points[i].dy);
        }
        _applyPathFillType(path, node);
        return path;
      case 'path':
        return _buildPathGeometry(node);
      default:
        return null;
    }
  }

  Rect? _computeNodeLocalBounds(SvgNode node) {
    final path = _buildGeometryPath(node);
    if (path == null) {
      return null;
    }
    final bounds = path.getBounds();
    if (bounds.width.abs() < 1e-6 || bounds.height.abs() < 1e-6) {
      return null;
    }
    return bounds;
  }

  Path? _resolveTextPathGeometry(SvgNode textPathNode) {
    final hrefId = _extractHrefId(textPathNode);
    if (hrefId == null || hrefId.isEmpty) {
      return null;
    }

    final referenced = _document.root.findById(hrefId);
    if (referenced == null || referenced.tagName != 'path') {
      return null;
    }

    final path = _buildPathGeometry(referenced);
    if (path == null) {
      return null;
    }

    final transformAttr = referenced.getAttributeValue('transform');
    if (transformAttr == null || transformAttr.toString().trim().isEmpty) {
      return path;
    }
    final matrix = Matrix4.identity();
    _applyNodeTransform(matrix, referenced);
    return path.transform(matrix.storage);
  }
}
