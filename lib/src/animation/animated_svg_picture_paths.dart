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

  /// Unpainted object bounds of [node] in its local user coordinate system.
  ///
  /// Mirrors the painter's `_computeNodeObjectBounds`: fill geometry only,
  /// without stroke or other paint effects, so objectBoundingBox clip and
  /// mask hit testing shares one bounds definition with painting. Containers
  /// unite their children mapped through each child's own transform, `<use>`
  /// resolves the referenced content through the same viewport mapping as
  /// hit traversal and (like the painter) includes its own x/y translation,
  /// and text bounds come from the glyph-precision hit runs.
  ///
  /// [useGuard] breaks circular `<use>` reference chains.
  Rect? _computeNodeLocalBounds(SvgNode node, [Set<String>? useGuard]) {
    var bounds = _resolveObjectBoundsForHitTesting(node, useGuard);
    if (bounds == null) {
      return null;
    }
    if (node.tagName == 'use') {
      bounds = bounds.shift(
        Offset(
          _resolveHitTestLength(node, 'x', horizontal: true),
          _resolveHitTestLength(node, 'y', horizontal: false),
        ),
      );
    }
    if (bounds.width.abs() < 1e-6 || bounds.height.abs() < 1e-6) {
      return null;
    }
    return bounds;
  }

  /// Fill geometry of [node] excluding its own transform and, for `<use>`,
  /// its x/y translation. Container traversal applies both in
  /// [_mapChildObjectBoundsToParentForHitTesting].
  Rect? _resolveObjectBoundsForHitTesting(SvgNode node, Set<String>? useGuard) {
    switch (node.tagName) {
      case 'text':
      case 'tspan':
      case 'tref':
        return _computeTextObjectBoundsForHitTesting(node);
      case 'g':
      case 'a':
      case 'svg':
      case 'symbol':
      case 'foreignObject':
        return _unionChildObjectBoundsForHitTesting(node, useGuard);
      case 'switch':
        final activeChild = resolveActiveSwitchChild(node);
        if (activeChild == null || _isDisplayNoneForBounds(activeChild)) {
          return null;
        }
        final childBounds = _resolveObjectBoundsForHitTesting(
          activeChild,
          useGuard,
        );
        if (childBounds == null) {
          return null;
        }
        return _mapChildObjectBoundsToParentForHitTesting(
          activeChild,
          childBounds,
        );
      case 'use':
        return _resolveUseObjectBoundsForHitTesting(node, useGuard);
      case 'image':
        return Rect.fromLTWH(
          _resolveHitTestLength(node, 'x', horizontal: true),
          _resolveHitTestLength(node, 'y', horizontal: false),
          _resolveHitTestLength(node, 'width', horizontal: true),
          _resolveHitTestLength(node, 'height', horizontal: false),
        );
      default:
        return _buildGeometryPath(node)?.getBounds();
    }
  }

  Rect? _unionChildObjectBoundsForHitTesting(
    SvgNode node,
    Set<String>? useGuard,
  ) {
    Rect? bounds;
    for (final child in node.children) {
      if (_isDisplayNoneForBounds(child)) {
        continue;
      }
      final childBounds = _resolveObjectBoundsForHitTesting(child, useGuard);
      if (childBounds == null ||
          childBounds.width <= 0 ||
          childBounds.height <= 0) {
        continue;
      }
      final mapped = _mapChildObjectBoundsToParentForHitTesting(
        child,
        childBounds,
      );
      bounds = bounds == null ? mapped : bounds.expandToInclude(mapped);
    }
    return bounds;
  }

  /// Maps a child's local bounds into its parent's coordinate system using
  /// the same transform chain as hit traversal: the child's transform
  /// attribute, then the x/y translation of `<foreignObject>`, nested
  /// `<svg>` (with its viewBox mapping), and `<use>`.
  Rect _mapChildObjectBoundsToParentForHitTesting(SvgNode child, Rect bounds) {
    final matrix = Matrix4.identity();
    _applyNodeTransform(matrix, child);
    switch (child.tagName) {
      case 'foreignObject':
      case 'use':
        matrix.translateByDouble(
          _resolveHitTestLength(child, 'x', horizontal: true),
          _resolveHitTestLength(child, 'y', horizontal: false),
          0,
          1,
        );
      case 'svg':
        if (!identical(child, _document.root)) {
          _applyNestedSvgViewportTransform(matrix, child);
        }
    }
    return MatrixUtils.transformRect(matrix, bounds);
  }

  Rect? _resolveUseObjectBoundsForHitTesting(
    SvgNode useNode,
    Set<String>? useGuard,
  ) {
    final hrefId = _extractHrefId(useNode);
    if (hrefId == null || hrefId.isEmpty) {
      return null;
    }
    final guard = useGuard ?? <String>{};
    if (!guard.add(hrefId)) {
      return null;
    }
    try {
      final referenced = _document.root.findById(hrefId);
      if (referenced == null ||
          !isSvgUseReferenceAllowedTag(referenced.tagName) ||
          _isDisplayNoneForBounds(referenced)) {
        return null;
      }
      if (!_isUseViewportReferenceTag(referenced.tagName)) {
        final referencedBounds = _resolveObjectBoundsForHitTesting(
          referenced,
          guard,
        );
        if (referencedBounds == null) {
          return null;
        }
        return _mapChildObjectBoundsToParentForHitTesting(
          referenced,
          referencedBounds,
        );
      }

      // use → symbol / svg establishes a viewport sized by the use element.
      var contentBounds = _unionChildObjectBoundsForHitTesting(
        referenced,
        guard,
      );
      if (contentBounds == null) {
        return null;
      }
      if (referenced.tagName == 'svg') {
        // A referenced <svg> is traversed as a normal nested svg after the
        // use viewport mapping, so its own x/y and viewBox apply as well.
        contentBounds = _mapChildObjectBoundsToParentForHitTesting(
          referenced,
          contentBounds,
        );
      }
      final viewBox = _parseViewBox(referenced.getAttributeValue('viewBox'));
      final useWidth = resolveSvgLength(
        useNode,
        _document,
        'width',
        reference: SvgLengthReference.horizontal,
      );
      final useHeight = resolveSvgLength(
        useNode,
        _document,
        'height',
        reference: SvgLengthReference.vertical,
      );
      final hasViewportTransform =
          viewBox != null &&
          viewBox.width > 0 &&
          viewBox.height > 0 &&
          useWidth != null &&
          useHeight != null &&
          useWidth > 0 &&
          useHeight > 0;
      if (!hasViewportTransform) {
        // No viewBox-to-viewport mapping: the content is rendered unscaled
        // but still clipped to the use width/height (or the viewBox) unless
        // overflow is visible. Mirror the painter's bounds resolver.
        final overflow = _getInheritedString(
          referenced,
          'overflow',
        )?.toLowerCase();
        if (overflow == 'visible') {
          return contentBounds;
        }
        Rect? rendererClip;
        if (useWidth != null &&
            useHeight != null &&
            useWidth > 0 &&
            useHeight > 0) {
          rendererClip = Rect.fromLTWH(0, 0, useWidth, useHeight);
        } else if (viewBox != null && viewBox.width > 0 && viewBox.height > 0) {
          rendererClip = viewBox;
        }
        return rendererClip == null
            ? contentBounds
            : _intersectBoundsOrNull(contentBounds, rendererClip);
      }
      final matrix = Matrix4.identity();
      final clipRect = _applyUseViewportTransform(matrix, useNode, referenced);
      final mapped = MatrixUtils.transformRect(matrix, contentBounds);
      return clipRect == null
          ? mapped
          : _intersectBoundsOrNull(mapped, clipRect);
    } finally {
      guard.remove(hrefId);
    }
  }

  Rect? _intersectBoundsOrNull(Rect a, Rect b) {
    final intersection = a.intersect(b);
    if (intersection.width <= 0 || intersection.height <= 0) {
      return null;
    }
    return intersection;
  }

  bool _isDisplayNoneForBounds(SvgNode node) {
    final display =
        (_extractStyleValue(node, 'display') ??
                node.getAttributeValue('display'))
            ?.toString()
            .trim()
            .toLowerCase();
    return display == 'none';
  }

  double _resolveHitTestLength(
    SvgNode node,
    String attributeName, {
    required bool horizontal,
  }) {
    return resolveSvgLength(
          node,
          _document,
          attributeName,
          reference: horizontal
              ? SvgLengthReference.horizontal
              : SvgLengthReference.vertical,
        ) ??
        0.0;
  }

  /// Unpainted bounds of a text node or text content child from the glyph
  /// runs the glyph-precision hit path builds, in the text's local space.
  Rect? _computeTextObjectBoundsForHitTesting(SvgNode node) {
    final textRoot = _findTextLayoutRoot(node);
    if (textRoot == null) {
      return null;
    }
    Rect? bounds;
    for (final run in _buildGlyphPrecisionHitRuns(textRoot)) {
      if (!_isNodeOrDescendant(run.owner, node)) {
        continue;
      }
      var runBounds = run.bounds ?? run.glyphPath?.getBounds();
      if (runBounds == null || runBounds.isEmpty) {
        continue;
      }
      if (run.rotation != 0.0) {
        final rotation = Matrix4.identity()
          ..translateByDouble(
            run.rotationCenter.dx,
            run.rotationCenter.dy,
            0,
            1,
          )
          ..rotateZ(run.rotation * math.pi / 180.0)
          ..translateByDouble(
            -run.rotationCenter.dx,
            -run.rotationCenter.dy,
            0,
            1,
          );
        runBounds = MatrixUtils.transformRect(rotation, runBounds);
      }
      bounds = bounds == null ? runBounds : bounds.expandToInclude(runBounds);
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
