part of 'animated_svg_painter.dart';

/// Tracks nested mask context for mask-to-mask intersection handling.
class _MaskNestingContext {
  const _MaskNestingContext({
    required this.depth,
    required this.parentMaskBounds,
    required this.hasParentMask,
  });

  /// Current mask nesting depth (0 = no mask, 1 = first mask, etc.)
  final int depth;

  /// Bounds of the parent mask (for intersection calculation)
  final ui.Rect? parentMaskBounds;

  /// Whether there is a parent mask to intersect with
  final bool hasParentMask;

  /// Creates a new context for an additional mask level.
  _MaskNestingContext withChildMask(ui.Rect childBounds) {
    return _MaskNestingContext(
      depth: depth + 1,
      parentMaskBounds: childBounds,
      hasParentMask: true,
    );
  }

  /// Computes the intersection of parent and child mask bounds.
  ui.Rect? computeIntersection(ui.Rect childBounds) {
    if (!hasParentMask || parentMaskBounds == null) {
      return childBounds;
    }
    final intersection = parentMaskBounds!.intersect(childBounds);
    if (intersection.isEmpty) {
      return null; // No visible area
    }
    return intersection;
  }
}

/// Combined mask + clip-path application and subgraph masking.
///
/// Contains methods for:
/// - Subgraph mask application (element -> filter -> mask ordering)
/// - Nested mask intersection handling
/// - Filter chain support in mask content
extension AnimatedSvgPainterMaskClipCombinationExtension on AnimatedSvgPainter {
  /// Applies subgraph masking - ensures proper ordering: element -> filter -> mask.
  ///
  /// When an element has both filter and mask, per CSS compositing spec:
  /// 1. Render element content
  /// 2. Apply filter to rendered content
  /// 3. Apply mask to filtered result
  ///
  /// This method is used when the mask needs to be applied after filter processing.
  // ignore: unused_element
  void _applySubgraphMask(
    ui.Canvas canvas,
    SvgNode node, {
    required Set<String> useStack,
    required void Function() paintFilteredContent,
  }) {
    final maskId = _extractPaintServerId(
      _getStyleOrAttributeValue(node, 'mask'),
    );
    if (maskId == null || maskId.isEmpty) {
      // No mask, just paint filtered content directly
      paintFilteredContent();
      return;
    }

    final maskNode = document.root.findById(maskId);
    if (maskNode == null || maskNode.tagName != 'mask') {
      // Invalid mask reference, paint without masking
      paintFilteredContent();
      return;
    }

    final maskType = _parseMaskType(maskNode, node);
    final maskBounds = _computeMaskBounds(maskedNode: node, maskNode: maskNode);

    if (maskBounds == null ||
        maskBounds.width.abs() < _kMinBoundingBoxDimension ||
        maskBounds.height.abs() < _kMinBoundingBoxDimension) {
      // Empty mask bounds - nothing visible
      return;
    }

    // Render with mask applied after filter
    _renderSubgraphWithMask(
      canvas,
      node: node,
      maskNode: maskNode,
      maskType: maskType,
      maskBounds: maskBounds,
      useStack: useStack,
      paintContent: paintFilteredContent,
    );
  }

  /// Renders subgraph content with mask applied after any filter effects.
  void _renderSubgraphWithMask(
    ui.Canvas canvas, {
    required SvgNode node,
    required SvgNode maskNode,
    required _SvgMaskType maskType,
    required ui.Rect maskBounds,
    required Set<String> useStack,
    required void Function() paintContent,
  }) {
    // Save layer for content (includes any filter effects already applied)
    canvas.saveLayer(maskBounds, ui.Paint());

    // Paint the content (which may have filters applied)
    paintContent();

    // Apply mask
    final maskPaint =
        maskType == _SvgMaskType.luminance
              ? _createLuminanceMaskPaint()
              : ui.Paint()
          ..blendMode = ui.BlendMode.dstIn;

    canvas.saveLayer(maskBounds, maskPaint);

    // Render mask content
    _paintMaskContent(
      canvas,
      maskNode: maskNode,
      maskedNode: node,
      useStack: useStack,
    );

    canvas.restore(); // mask layer
    canvas.restore(); // content layer
  }

  /// Checks if mask content itself has filters.
  /// When mask content has filters, they must be applied before the mask compositing.
  // ignore: unused_element
  bool _maskContentHasFilters(SvgNode maskNode) {
    for (final child in maskNode.children) {
      final filterId = _getFilterId(child);
      if (filterId != null && filterId.isNotEmpty) {
        return true;
      }
      // Check nested groups
      if (child.tagName == 'g' && _maskContentHasFilters(child)) {
        return true;
      }
    }
    return false;
  }

  /// Applies nested mask with intersection handling.
  ///
  /// When element A has a mask, and A contains element B which also has
  /// its own mask, the visible area is the intersection of both masks.
  void _applyNestedMaskWithIntersection(
    ui.Canvas canvas,
    SvgNode node, {
    required SvgNode maskNode,
    required ui.Rect maskBounds,
    required _SvgMaskType maskType,
    required Set<String> useStack,
    required _MaskNestingContext nestingContext,
    required void Function() paintContent,
  }) {
    // Compute intersection with parent mask if exists
    final effectiveBounds = nestingContext.hasParentMask
        ? nestingContext.computeIntersection(maskBounds)
        : maskBounds;

    if (effectiveBounds == null ||
        effectiveBounds.width.abs() < _kMinBoundingBoxDimension ||
        effectiveBounds.height.abs() < _kMinBoundingBoxDimension) {
      // No visible area after intersection
      return;
    }

    // Save layer for content
    canvas.saveLayer(effectiveBounds, ui.Paint());

    // Paint the content
    paintContent();

    // Apply mask with proper type
    final maskPaint =
        maskType == _SvgMaskType.luminance
              ? _createLuminanceMaskPaintWithGradientSupport()
              : ui.Paint()
          ..blendMode = ui.BlendMode.dstIn;

    canvas.saveLayer(effectiveBounds, maskPaint);

    // Paint mask content with filters if present
    _paintMaskContentWithFilters(
      canvas,
      maskNode: maskNode,
      maskedNode: node,
      useStack: useStack,
      maskType: maskType,
      maskBounds: effectiveBounds,
    );

    canvas.restore(); // mask layer
    canvas.restore(); // content layer
  }
}
