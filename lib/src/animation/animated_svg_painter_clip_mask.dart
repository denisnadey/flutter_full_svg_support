part of 'animated_svg_painter.dart';

extension AnimatedSvgPainterClipMaskExtension on AnimatedSvgPainter {
  void _applyClipPath(
    ui.Canvas canvas,
    SvgNode node, {
    required Set<String> useStack,
  }) {
    final clipId = _extractPaintServerId(
      _getStyleOrAttributeValue(node, 'clip-path'),
    );
    if (clipId == null || clipId.isEmpty) {
      return;
    }

    final clipNode = document.root.findById(clipId);
    if (clipNode == null || clipNode.tagName != 'clipPath') {
      return;
    }

    final clipPath = _buildClipPathForNode(
      clippedNode: node,
      clipPathNode: clipNode,
      useStack: useStack,
    );
    if (clipPath == null) {
      return;
    }

    canvas.clipPath(clipPath, doAntiAlias: true);
  }

  void _applyMask(
    ui.Canvas canvas,
    SvgNode node, {
    required Set<String> useStack,
  }) {
    final maskId = _extractPaintServerId(
      _getStyleOrAttributeValue(node, 'mask'),
    );
    if (maskId == null || maskId.isEmpty) {
      return;
    }

    final maskNode = document.root.findById(maskId);
    if (maskNode == null || maskNode.tagName != 'mask') {
      return;
    }

    final maskPath = _buildMaskPathForNode(
      maskedNode: node,
      maskNode: maskNode,
      useStack: useStack,
    );
    if (maskPath == null) {
      return;
    }

    canvas.clipPath(maskPath, doAntiAlias: true);
  }

  ui.Path? _buildClipPathForNode({
    required SvgNode clippedNode,
    required SvgNode clipPathNode,
    required Set<String> useStack,
  }) {
    final clipPath = ui.Path();

    Matrix4 rootMatrix = Matrix4.identity();
    final clipUnits = _getString(
      clipPathNode,
      'clipPathUnits',
    )?.trim().toLowerCase();
    if (clipUnits == 'objectboundingbox') {
      final localBounds = _computeNodeLocalBounds(clippedNode);
      if (localBounds == null ||
          localBounds.width.abs() < 1e-6 ||
          localBounds.height.abs() < 1e-6) {
        return null;
      }
      rootMatrix = Matrix4.identity()
        ..setEntry(0, 0, localBounds.width)
        ..setEntry(1, 1, localBounds.height)
        ..setEntry(0, 3, localBounds.left)
        ..setEntry(1, 3, localBounds.top);
    }

    _appendClipGeometry(
      target: clipPath,
      node: clipPathNode,
      currentTransform: rootMatrix,
      useStack: useStack,
    );

    final bounds = clipPath.getBounds();
    if (bounds.width.abs() < 1e-6 || bounds.height.abs() < 1e-6) {
      return null;
    }

    return clipPath;
  }

  ui.Path? _buildMaskPathForNode({
    required SvgNode maskedNode,
    required SvgNode maskNode,
    required Set<String> useStack,
  }) {
    final maskPath = ui.Path();

    Matrix4 rootMatrix = Matrix4.identity();
    final contentUnits =
        (_getString(maskNode, 'maskContentUnits') ?? 'userSpaceOnUse')
            .trim()
            .toLowerCase();
    if (contentUnits == 'objectboundingbox') {
      final localBounds = _computeNodeLocalBounds(maskedNode);
      if (localBounds == null ||
          localBounds.width.abs() < 1e-6 ||
          localBounds.height.abs() < 1e-6) {
        return null;
      }
      rootMatrix = Matrix4.identity()
        ..setEntry(0, 0, localBounds.width)
        ..setEntry(1, 1, localBounds.height)
        ..setEntry(0, 3, localBounds.left)
        ..setEntry(1, 3, localBounds.top);
    }

    _appendClipGeometry(
      target: maskPath,
      node: maskNode,
      currentTransform: rootMatrix,
      useStack: useStack,
    );

    final maskRegionPath = _buildMaskUnitsRegionPath(
      maskedNode: maskedNode,
      maskNode: maskNode,
    );
    final effectiveMaskPath = maskRegionPath == null
        ? maskPath
        : ui.Path.combine(ui.PathOperation.intersect, maskPath, maskRegionPath);

    final bounds = effectiveMaskPath.getBounds();
    if (bounds.width.abs() < 1e-6 || bounds.height.abs() < 1e-6) {
      return null;
    }

    return effectiveMaskPath;
  }
}
