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
    // Using enhanced method that handles clipPathUnits correctly at each cascade level
    final clipPath = _buildCascadingClipPathWithUnits(
      clippedNode: node,
      clipPathNode: clipNode,
      useStack: useStack,
    );
    if (clipPath == null || _isZeroAreaClipPath(clipPath)) {
      // A valid clipPath reference with empty geometry clips out all content.
      canvas.clipPath(ui.Path(), doAntiAlias: false);
      return;
    }

    canvas.clipPath(clipPath, doAntiAlias: true);
  }

  /// Applies mask to an element using layer-based compositing.
  ///
  /// Per SVG spec, masks support two modes:
  /// - **luminance** (default): Uses RGB luminance (0.2126*R + 0.7152*G + 0.0722*B) * A
  /// - **alpha**: Uses only the alpha channel
  ///
  /// This method prepares the mask layer for proper compositing. The actual
  /// mask application happens via saveLayer with proper blend modes.
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

    // For basic path-based clipping fallback, build the geometry mask
    // This provides geometric clipping for the mask region
    final maskPath = _buildMaskPathForNode(
      maskedNode: node,
      maskNode: maskNode,
      useStack: useStack,
    );
    if (maskPath == null) {
      // A resolved mask with empty geometry makes the target fully transparent.
      // Keep rendering semantics by clipping to an empty path.
      canvas.clipPath(ui.Path(), doAntiAlias: false);
      return;
    }

    // Apply geometric mask region clipping
    // Note: Full alpha/luminance masking requires layer-based composition
    // which is handled at the group/element level for proper compositing
    canvas.clipPath(maskPath, doAntiAlias: true);
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
      final localBounds = _computeNodeObjectBounds(maskedNode);
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
}
