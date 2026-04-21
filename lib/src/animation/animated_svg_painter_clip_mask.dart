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

    // For use elements, resolve the referenced element and compute bounds
    if (node.tagName == 'use') {
      return _computeUseBoundsWithStroke(node);
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

  /// Computes bounds for a use element by resolving the referenced element
  /// and applying the use element's x/y offset.
  ui.Rect? _computeUseBoundsWithStroke(SvgNode useNode) {
    // Extract href to find referenced element
    final href =
        useNode.getAttributeValue('href')?.toString() ??
        useNode.getAttributeValue('xlink:href')?.toString();
    if (href == null || href.isEmpty) return null;

    // Extract ID from href (remove leading #)
    final hrefId = href.startsWith('#') ? href.substring(1) : href;
    if (hrefId.isEmpty) return null;

    // Find the referenced element
    final referencedNode = document.root.findById(hrefId);
    if (referencedNode == null) return null;

    // Compute bounds of the referenced element
    final refBounds = _computeNodeLocalBoundsWithStroke(referencedNode);
    if (refBounds == null) return null;

    // Apply the use element's x/y offset
    final x = _getNumber(useNode, 'x') ?? 0.0;
    final y = _getNumber(useNode, 'y') ?? 0.0;

    return refBounds.translate(x, y);
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
