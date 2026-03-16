part of 'animated_svg_picture.dart';

extension _AnimatedSvgPictureStateHitTestVisibilityExtension
    on _AnimatedSvgPictureState {
  bool _isPointVisibleForNode(
    SvgNode node,
    Offset documentPoint,
    Matrix4 transform,
  ) {
    final inverse = Matrix4.tryInvert(transform);
    if (inverse == null) {
      return false;
    }
    final localPoint = MatrixUtils.transformPoint(inverse, documentPoint);
    return _isPointVisibleInNodeSpace(node, localPoint);
  }

  bool _isPointVisibleInNodeSpace(SvgNode node, Offset localPoint) {
    if (!_isPointInsideClipPath(node, localPoint)) {
      return false;
    }
    if (!_isPointInsideMask(node, localPoint)) {
      return false;
    }
    if (!_isPointInsideForeignObjectViewport(node, localPoint)) {
      return false;
    }
    return true;
  }

  bool _isPointInsideClipPath(SvgNode node, Offset localPoint) {
    final clipValue = _extractStyleValue(node, 'clip-path');
    final clipId = _extractUrlId(
      clipValue ?? node.getAttributeValue('clip-path'),
    );
    if (clipId == null || clipId.isEmpty) {
      return true;
    }
    final clipNode = _document.root.findById(clipId);
    if (clipNode == null || clipNode.tagName != 'clipPath') {
      return true;
    }
    final rootTransform = _resolveContainerRootTransformForUnits(
      targetNode: node,
      unitsValue: clipNode.getAttributeValue('clipPathUnits')?.toString(),
      defaultValue: 'userspaceonuse',
    );
    if (rootTransform == null) {
      return true;
    }
    final clipPath = _buildContainerGeometryPath(
      clipNode,
      rootTransform: rootTransform,
    );
    if (clipPath == null) {
      return true;
    }
    return clipPath.contains(localPoint);
  }

  bool _isPointInsideMask(SvgNode node, Offset localPoint) {
    final maskValue = _extractStyleValue(node, 'mask');
    final maskId = _extractUrlId(maskValue ?? node.getAttributeValue('mask'));
    if (maskId == null || maskId.isEmpty) {
      return true;
    }
    final maskNode = _document.root.findById(maskId);
    if (maskNode == null || maskNode.tagName != 'mask') {
      return true;
    }
    final maskRegion = _resolveMaskRegionRectForNodeSpace(
      targetNode: node,
      maskNode: maskNode,
    );
    if (maskRegion != null && !maskRegion.contains(localPoint)) {
      return false;
    }
    final rootTransform = _resolveContainerRootTransformForUnits(
      targetNode: node,
      unitsValue: maskNode.getAttributeValue('maskContentUnits')?.toString(),
      defaultValue: 'userspaceonuse',
    );
    if (rootTransform == null) {
      return true;
    }
    final maskPath = _buildContainerGeometryPath(
      maskNode,
      rootTransform: rootTransform,
    );
    if (maskPath == null) {
      return true;
    }
    return maskPath.contains(localPoint);
  }

  Matrix4? _resolveContainerRootTransformForUnits({
    required SvgNode targetNode,
    required String? unitsValue,
    required String defaultValue,
  }) {
    final normalized = (unitsValue ?? defaultValue).trim().toLowerCase();
    if (normalized != 'objectboundingbox') {
      return Matrix4.identity();
    }
    final localBounds = _computeNodeLocalBounds(targetNode);
    if (localBounds == null ||
        localBounds.width.abs() < 1e-6 ||
        localBounds.height.abs() < 1e-6) {
      return null;
    }
    return Matrix4.identity()
      ..setEntry(0, 0, localBounds.width)
      ..setEntry(1, 1, localBounds.height)
      ..setEntry(0, 3, localBounds.left)
      ..setEntry(1, 3, localBounds.top);
  }

  Rect? _resolveMaskRegionRectForNodeSpace({
    required SvgNode targetNode,
    required SvgNode maskNode,
  }) {
    final units =
        (maskNode.getAttributeValue('maskUnits')?.toString() ??
                'objectBoundingBox')
            .trim()
            .toLowerCase();
    if (units == 'objectboundingbox') {
      final targetBounds = _computeNodeLocalBounds(targetNode);
      if (targetBounds == null) {
        return null;
      }
      final x = _parseObjectBoundingBoxValue(maskNode.getAttributeValue('x'));
      final y = _parseObjectBoundingBoxValue(maskNode.getAttributeValue('y'));
      final width = _parseObjectBoundingBoxValue(
        maskNode.getAttributeValue('width'),
      );
      final height = _parseObjectBoundingBoxValue(
        maskNode.getAttributeValue('height'),
      );
      final resolvedX = x ?? -0.1;
      final resolvedY = y ?? -0.1;
      final resolvedWidth = width ?? 1.2;
      final resolvedHeight = height ?? 1.2;
      if (resolvedWidth <= 0 || resolvedHeight <= 0) {
        return null;
      }
      return Rect.fromLTWH(
        targetBounds.left + resolvedX * targetBounds.width,
        targetBounds.top + resolvedY * targetBounds.height,
        targetBounds.width * resolvedWidth,
        targetBounds.height * resolvedHeight,
      );
    }

    final x = _resolveMaskUserSpaceLength(
      maskNode: maskNode,
      attributeName: 'x',
      horizontal: true,
      isSize: false,
      defaultRaw: '-10%',
    );
    final y = _resolveMaskUserSpaceLength(
      maskNode: maskNode,
      attributeName: 'y',
      horizontal: false,
      isSize: false,
      defaultRaw: '-10%',
    );
    final width = _resolveMaskUserSpaceLength(
      maskNode: maskNode,
      attributeName: 'width',
      horizontal: true,
      isSize: true,
      defaultRaw: '120%',
    );
    final height = _resolveMaskUserSpaceLength(
      maskNode: maskNode,
      attributeName: 'height',
      horizontal: false,
      isSize: true,
      defaultRaw: '120%',
    );
    if (x == null || y == null || width == null || height == null) {
      return null;
    }
    if (width <= 0 || height <= 0) {
      return null;
    }
    return Rect.fromLTWH(x, y, width, height);
  }

  double? _resolveMaskUserSpaceLength({
    required SvgNode maskNode,
    required String attributeName,
    required bool horizontal,
    required bool isSize,
    required String defaultRaw,
  }) {
    final rawValue = maskNode.getAttributeValue(attributeName) ?? defaultRaw;
    if (rawValue is num) {
      return rawValue.toDouble();
    }
    final raw = rawValue.toString().trim();
    if (raw.isEmpty) {
      return null;
    }
    if (raw.endsWith('%')) {
      final percent = double.tryParse(raw.substring(0, raw.length - 1));
      final viewport = _resolveMaskUnitsViewportRect();
      if (percent == null || viewport == null) {
        return null;
      }
      final dimension = horizontal ? viewport.width : viewport.height;
      final value = dimension * percent / 100.0;
      if (isSize) {
        return value;
      }
      final origin = horizontal ? viewport.left : viewport.top;
      return origin + value;
    }
    final cleaned = raw.replaceAll(RegExp(r'[a-zA-Z]+$'), '');
    return double.tryParse(cleaned);
  }

  Rect? _resolveMaskUnitsViewportRect() {
    final viewBox = _document.viewBox;
    if (viewBox != null && viewBox.width > 0 && viewBox.height > 0) {
      return viewBox;
    }
    final root = _document.root;
    final width = _getNumber(root, 'width');
    final height = _getNumber(root, 'height');
    if (width == null || height == null || width <= 0 || height <= 0) {
      return null;
    }
    return Rect.fromLTWH(0, 0, width, height);
  }

  double? _parseObjectBoundingBoxValue(Object? rawValue) {
    if (rawValue == null) {
      return null;
    }
    if (rawValue is num) {
      return rawValue.toDouble();
    }
    final raw = rawValue.toString().trim();
    if (raw.isEmpty) {
      return null;
    }
    if (raw.endsWith('%')) {
      final percent = double.tryParse(raw.substring(0, raw.length - 1));
      if (percent == null) {
        return null;
      }
      return percent / 100.0;
    }
    return double.tryParse(raw);
  }

  bool _isPointInsideForeignObjectViewport(SvgNode node, Offset localPoint) {
    if (node.tagName != 'foreignObject') {
      return true;
    }
    final x = _getNumber(node, 'x') ?? 0.0;
    final y = _getNumber(node, 'y') ?? 0.0;
    final width = _getNumber(node, 'width') ?? 0.0;
    final height = _getNumber(node, 'height') ?? 0.0;
    if (width <= 0 || height <= 0) {
      return false;
    }
    return Rect.fromLTWH(x, y, width, height).contains(localPoint);
  }

  String? _extractUrlId(Object? value) {
    final raw = value?.toString().trim();
    if (raw == null || raw.isEmpty) {
      return null;
    }
    if (raw.startsWith('#') && raw.length > 1) {
      return raw.substring(1);
    }
    final urlMatch = RegExp(
      r'''url\(\s*['"]?#([^'")\s]+)['"]?\s*\)''',
      caseSensitive: false,
    ).firstMatch(raw);
    return urlMatch?.group(1);
  }
}
