part of 'animated_svg_picture.dart';

extension _AnimatedSvgPictureStatePathsExtension on _AnimatedSvgPictureState {
  Path? _buildPathGeometry(SvgNode node) {
    final pathData = node.getAttributeValue('d')?.toString();
    if (pathData == null || pathData.isEmpty) {
      return null;
    }

    final path = _buildPath(pathData);
    if (path == null) {
      return null;
    }

    _applyPathFillType(path, node);
    return path;
  }

  Path? _buildGeometryPath(SvgNode node) {
    switch (node.tagName) {
      case 'rect':
        final x = _getNumber(node, 'x') ?? 0.0;
        final y = _getNumber(node, 'y') ?? 0.0;
        final width = _getNumber(node, 'width') ?? 0.0;
        final height = _getNumber(node, 'height') ?? 0.0;
        if (width <= 0 || height <= 0) {
          return null;
        }
        final rx = _getNumber(node, 'rx') ?? 0.0;
        final ry = _getNumber(node, 'ry') ?? rx;
        if (rx > 0 || ry > 0) {
          return Path()..addRRect(
            RRect.fromRectXY(Rect.fromLTWH(x, y, width, height), rx, ry),
          );
        }
        return Path()..addRect(Rect.fromLTWH(x, y, width, height));
      case 'circle':
        final cx = _getNumber(node, 'cx') ?? 0.0;
        final cy = _getNumber(node, 'cy') ?? 0.0;
        final r = _getNumber(node, 'r') ?? 0.0;
        if (r <= 0) {
          return null;
        }
        return Path()
          ..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r));
      case 'ellipse':
        final cx = _getNumber(node, 'cx') ?? 0.0;
        final cy = _getNumber(node, 'cy') ?? 0.0;
        final rx = _getNumber(node, 'rx') ?? 0.0;
        final ry = _getNumber(node, 'ry') ?? 0.0;
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
        final x1 = _getNumber(node, 'x1') ?? 0.0;
        final y1 = _getNumber(node, 'y1') ?? 0.0;
        final x2 = _getNumber(node, 'x2') ?? 0.0;
        final y2 = _getNumber(node, 'y2') ?? 0.0;
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

  Path? _buildContainerGeometryPath(
    SvgNode containerNode, {
    Matrix4? rootTransform,
  }) {
    final path = Path();
    final added = _appendContainerGeometry(
      target: path,
      node: containerNode,
      currentTransform: rootTransform ?? Matrix4.identity(),
      useStack: <String>{},
    );
    return added ? path : null;
  }

  bool _appendContainerGeometry({
    required Path target,
    required SvgNode node,
    required Matrix4 currentTransform,
    required Set<String> useStack,
  }) {
    final matrix = Matrix4.copy(currentTransform);
    _applyNodeTransform(matrix, node);

    switch (node.tagName) {
      case 'clipPath':
      case 'mask':
      case 'g':
      case 'svg':
      case 'symbol':
        var added = false;
        for (final child in node.children) {
          if (_appendContainerGeometry(
            target: target,
            node: child,
            currentTransform: matrix,
            useStack: useStack,
          )) {
            added = true;
          }
        }
        return added;
      case 'switch':
        final activeChild = resolveActiveSwitchChild(node);
        if (activeChild == null) {
          return false;
        }
        return _appendContainerGeometry(
          target: target,
          node: activeChild,
          currentTransform: matrix,
          useStack: useStack,
        );
      case 'use':
        final hrefId = _extractHrefId(node);
        if (hrefId == null || hrefId.isEmpty || useStack.contains(hrefId)) {
          return false;
        }
        final referenced = _document.root.findById(hrefId);
        if (referenced == null ||
            !_isUseReferenceAllowedTag(referenced.tagName)) {
          return false;
        }
        final translated = Matrix4.copy(matrix)
          ..translateByDouble(
            _getNumber(node, 'x') ?? 0.0,
            _getNumber(node, 'y') ?? 0.0,
            0,
            1,
          );
        final nextUseStack = <String>{...useStack, hrefId};
        if (_isUseViewportReferenceTag(referenced.tagName)) {
          final useReferenceTransform = Matrix4.copy(translated);
          _applyUseViewportTransform(useReferenceTransform, node, referenced);
          return _appendContainerGeometry(
            target: target,
            node: referenced,
            currentTransform: useReferenceTransform,
            useStack: nextUseStack,
          );
        }
        return _appendContainerGeometry(
          target: target,
          node: referenced,
          currentTransform: translated,
          useStack: nextUseStack,
        );
      default:
        final geometry = _buildGeometryPath(node);
        if (geometry == null) {
          return false;
        }
        target.addPath(geometry.transform(matrix.storage), Offset.zero);
        return true;
    }
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
