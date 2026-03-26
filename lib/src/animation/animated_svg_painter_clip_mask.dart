part of 'animated_svg_painter.dart';

/// Minimum threshold for valid bounding box dimensions.
/// Values below this are considered degenerate/zero.
const double _kMinBoundingBoxDimension = 1e-6;

/// Minimum threshold for very small bounding box dimensions.
/// Used for scaling safety to prevent excessive magnification.
const double _kMinSafeScaleDimension = 1e-3;

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

    // Build clip path with cascading support (clipPath on clipPath)
    final clipPath = _buildCascadingClipPath(
      clippedNode: node,
      clipPathNode: clipNode,
      useStack: useStack,
    );
    if (clipPath == null) {
      return;
    }

    canvas.clipPath(clipPath, doAntiAlias: true);
  }

  /// Builds a clip path with support for cascading clipPaths.
  ///
  /// When a clipPath element itself has a clip-path attribute, the result
  /// is the intersection of both clip regions. This supports N-level cascading.
  ui.Path? _buildCascadingClipPath({
    required SvgNode clippedNode,
    required SvgNode clipPathNode,
    required Set<String> useStack,
    int depth = 0,
  }) {
    // Prevent infinite recursion
    const maxCascadeDepth = 10;
    if (depth > maxCascadeDepth) {
      return null;
    }

    // Build the primary clip path
    final primaryPath = _buildClipPathForNode(
      clippedNode: clippedNode,
      clipPathNode: clipPathNode,
      useStack: useStack,
    );

    if (primaryPath == null) {
      return null;
    }

    // Check if the clipPath element itself has a clip-path (cascading)
    final cascadeClipId = _extractPaintServerId(
      _getStyleOrAttributeValue(clipPathNode, 'clip-path'),
    );

    if (cascadeClipId == null || cascadeClipId.isEmpty) {
      return primaryPath;
    }

    // Prevent circular references
    if (useStack.contains(cascadeClipId)) {
      return primaryPath;
    }

    final cascadeClipNode = document.root.findById(cascadeClipId);
    if (cascadeClipNode == null || cascadeClipNode.tagName != 'clipPath') {
      return primaryPath;
    }

    // Recursively build the cascading clip path
    final cascadePath = _buildCascadingClipPath(
      clippedNode: clipPathNode,
      clipPathNode: cascadeClipNode,
      useStack: {...useStack, cascadeClipId},
      depth: depth + 1,
    );

    if (cascadePath == null) {
      return primaryPath;
    }

    // Intersect both clip paths for the cascading effect
    return ui.Path.combine(
      ui.PathOperation.intersect,
      primaryPath,
      cascadePath,
    );
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
      final localBounds = _computeNodeLocalBoundsWithStroke(clippedNode);
      if (localBounds == null) {
        return null;
      }
      // Edge case: zero width or height - nothing to clip
      if (localBounds.width.abs() < _kMinBoundingBoxDimension ||
          localBounds.height.abs() < _kMinBoundingBoxDimension) {
        return null;
      }
      // Edge case: very small dimensions - clamp scaling to prevent issues
      final safeWidth = localBounds.width.abs() < _kMinSafeScaleDimension
          ? _kMinSafeScaleDimension
          : localBounds.width;
      final safeHeight = localBounds.height.abs() < _kMinSafeScaleDimension
          ? _kMinSafeScaleDimension
          : localBounds.height;
      rootMatrix = Matrix4.identity()
        ..setEntry(0, 0, safeWidth)
        ..setEntry(1, 1, safeHeight)
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
    if (bounds.width.abs() < _kMinBoundingBoxDimension ||
        bounds.height.abs() < _kMinBoundingBoxDimension) {
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
      final localBounds = _computeNodeLocalBoundsWithStroke(maskedNode);
      if (localBounds == null) {
        return null;
      }
      // Edge case: zero width or height - nothing to mask
      if (localBounds.width.abs() < _kMinBoundingBoxDimension ||
          localBounds.height.abs() < _kMinBoundingBoxDimension) {
        return null;
      }
      // Edge case: very small dimensions - clamp scaling to prevent issues
      final safeWidth = localBounds.width.abs() < _kMinSafeScaleDimension
          ? _kMinSafeScaleDimension
          : localBounds.width;
      final safeHeight = localBounds.height.abs() < _kMinSafeScaleDimension
          ? _kMinSafeScaleDimension
          : localBounds.height;
      rootMatrix = Matrix4.identity()
        ..setEntry(0, 0, safeWidth)
        ..setEntry(1, 1, safeHeight)
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
    if (bounds.width.abs() < _kMinBoundingBoxDimension ||
        bounds.height.abs() < _kMinBoundingBoxDimension) {
      return null;
    }

    return effectiveMaskPath;
  }

  /// Computes local bounds for a node, including stroke width expansion.
  /// This is used for objectBoundingBox calculations in clip-path and mask.
  ui.Rect? _computeNodeLocalBoundsWithStroke(SvgNode node) {
    // For text elements, use enhanced text bounds computation
    if (node.tagName == 'text' || node.tagName == 'tspan') {
      return _computeTextMaskBounds(node);
    }

    // For groups, compute union of all children's bounds
    if (node.tagName == 'g' || node.tagName == 'svg' || node.tagName == 'a') {
      return _computeGroupBoundsWithStroke(node);
    }

    final baseBounds = _computeNodeLocalBounds(node);
    if (baseBounds == null) return null;

    // Expand bounds by stroke width if stroke is applied
    final strokeWidth = _getInheritedNumber(node, 'stroke-width') ?? 1.0;
    final stroke = _getStyleOrAttributeValue(node, 'stroke');
    if (stroke != null && stroke.toString().toLowerCase() != 'none') {
      final halfStroke = strokeWidth / 2;
      return baseBounds.inflate(halfStroke);
    }

    return baseBounds;
  }

  /// Computes bounds for a group element by unioning all children's bounds.
  ui.Rect? _computeGroupBoundsWithStroke(SvgNode group) {
    ui.Rect? combinedBounds;
    for (final child in group.children) {
      final childBounds = _computeNodeLocalBoundsWithStroke(child);
      if (childBounds != null) {
        if (combinedBounds == null) {
          combinedBounds = childBounds;
        } else {
          combinedBounds = combinedBounds.expandToInclude(childBounds);
        }
      }
    }
    return combinedBounds;
  }

  /// Computes mask bounds for text elements including stroke, decorations,
  /// and emphasis marks per SVG spec.
  ui.Rect? _computeTextMaskBounds(SvgNode textNode) {
    final baseBounds = _computeNodeLocalBounds(textNode);
    if (baseBounds == null) return null;

    // Start with base bounds
    var expandedBounds = baseBounds;

    // Expand by stroke width
    final strokeWidth = _getInheritedNumber(textNode, 'stroke-width') ?? 1.0;
    final stroke = _getStyleOrAttributeValue(textNode, 'stroke');
    if (stroke != null && stroke.toString().toLowerCase() != 'none') {
      expandedBounds = expandedBounds.inflate(strokeWidth / 2);
    }

    // Expand for text decoration (underline, overline, line-through)
    final decoration = _getInheritedString(
      textNode,
      'text-decoration',
    )?.toLowerCase();
    if (decoration != null && decoration != 'none') {
      final fontSize = _getInheritedNumber(textNode, 'font-size') ?? 16.0;
      // Expand by ~10% of font size for decoration thickness
      final decorationExpand = fontSize * 0.1;
      if (decoration.contains('underline')) {
        expandedBounds = ui.Rect.fromLTRB(
          expandedBounds.left,
          expandedBounds.top,
          expandedBounds.right,
          expandedBounds.bottom + decorationExpand,
        );
      }
      if (decoration.contains('overline')) {
        expandedBounds = ui.Rect.fromLTRB(
          expandedBounds.left,
          expandedBounds.top - decorationExpand,
          expandedBounds.right,
          expandedBounds.bottom,
        );
      }
    }

    // Expand for text-emphasis marks (dots, circles, etc.)
    final emphasis = _getInheritedString(
      textNode,
      'text-emphasis',
    )?.toLowerCase();
    if (emphasis != null && emphasis != 'none') {
      final fontSize = _getInheritedNumber(textNode, 'font-size') ?? 16.0;
      // Emphasis marks are typically placed above/below text
      final emphasisExpand = fontSize * 0.5;
      expandedBounds = expandedBounds.inflate(emphasisExpand);
    }

    return expandedBounds;
  }
}
