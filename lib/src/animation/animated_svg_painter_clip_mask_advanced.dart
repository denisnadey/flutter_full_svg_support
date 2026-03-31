part of 'animated_svg_painter.dart';

/// Maximum nesting depth for cascading clip-paths.
const int _kMaxCascadingClipDepth = 10;

/// Context for tracking cascading clip-paths during rendering.
/// Stores transform chain and clip path intersection state.
class _CascadingClipContext {
  _CascadingClipContext({
    required this.depth,
    required this.accumulatedTransform,
    required this.clipPaths,
    this.parentClipPathUnits = 'userSpaceOnUse',
  });

  final int depth;
  final Matrix4 accumulatedTransform;
  final List<ui.Path> clipPaths;
  final String parentClipPathUnits;

  /// Adds a new clip path to the cascade.
  _CascadingClipContext withClipPath(
    ui.Path clipPath, {
    Matrix4? transform,
    String? clipPathUnits,
  }) {
    final newTransform = transform != null
        ? (Matrix4.copy(accumulatedTransform)..multiply(transform))
        : accumulatedTransform;

    return _CascadingClipContext(
      depth: depth + 1,
      accumulatedTransform: newTransform,
      clipPaths: [...clipPaths, clipPath],
      parentClipPathUnits: clipPathUnits ?? parentClipPathUnits,
    );
  }

  /// Computes the effective clip path by intersecting all accumulated paths.
  ui.Path? computeEffectiveClipPath() {
    if (clipPaths.isEmpty) return null;
    if (clipPaths.length == 1) return clipPaths.first;

    // Intersect all paths in sequence
    var result = clipPaths.first;
    for (var i = 1; i < clipPaths.length; i++) {
      result = ui.Path.combine(
        ui.PathOperation.intersect,
        result,
        clipPaths[i],
      );
    }
    return result;
  }
}

/// Extension for advanced clip-path and mask composition.
///
/// Provides methods for:
/// - Cascading multiple clip-paths with proper transform propagation
/// - Mask edge feathering with anti-aliasing
/// - maskContentUnits transitions between nested contexts
/// - Subgraph masking for filtered elements
extension AnimatedSvgPainterClipMaskAdvancedExtension on AnimatedSvgPainter {
  /// Builds cascading clip-path with proper transform propagation through the chain.
  ///
  /// When multiple clip-paths are applied in a hierarchy:
  /// - Parent has clipPath A
  /// - Child has clipPath B
  /// - The effective clip is the intersection of A and B
  ///
  /// This method handles transform propagation correctly through each level,
  /// ensuring coordinate systems are properly mapped at each cascade level.
  ui.Path? _buildCascadingClipPathWithTransformPropagation({
    required SvgNode clippedNode,
    required SvgNode clipPathNode,
    required Set<String> useStack,
    _CascadingClipContext? context,
  }) {
    final effectiveContext = context ??
        _CascadingClipContext(
          depth: 0,
          accumulatedTransform: Matrix4.identity(),
          clipPaths: [],
        );

    // Prevent infinite recursion
    if (effectiveContext.depth >= _kMaxCascadingClipDepth) {
      return effectiveContext.computeEffectiveClipPath();
    }

    // Determine clipPathUnits for this level
    final units = _getString(clipPathNode, 'clipPathUnits')
            ?.trim()
            .toLowerCase() ??
        'userspaceonuse';
    final isObjectBoundingBox = units == 'objectboundingbox';

    // Compute base transform for this clip level
    Matrix4 levelTransform = Matrix4.copy(effectiveContext.accumulatedTransform);

    // Apply objectBoundingBox transform if needed
    if (isObjectBoundingBox) {
      final obbTransform = _computeObjectBoundingBoxTransformAdvanced(
        clippedNode,
        preserveAspectRatio: false,
      );
      if (obbTransform == null) {
        // Zero-size element - return empty path
        return ui.Path();
      }
      levelTransform.multiply(obbTransform);
    }

    // Apply clipPath's own transform attribute
    final clipTransformStr = clipPathNode.getAttributeValue('transform');
    if (clipTransformStr != null) {
      final clipTransform = _buildTransformMatrixFromValue(clipTransformStr);
      if (clipTransform != null) {
        levelTransform.multiply(clipTransform);
      }
    }

    // Build the clip path geometry at this level
    final clipPath = ui.Path();
    _appendClipGeometry(
      target: clipPath,
      node: clipPathNode,
      currentTransform: levelTransform,
      useStack: useStack,
    );

    // Check for valid bounds
    final bounds = clipPath.getBounds();
    if (bounds.width.abs() < _kMinBoundingBoxDimension ||
        bounds.height.abs() < _kMinBoundingBoxDimension) {
      return ui.Path();
    }

    // Create new context with this clip path
    final newContext = effectiveContext.withClipPath(
      clipPath,
      transform: levelTransform,
      clipPathUnits: units,
    );

    // Check for cascading clip-path on the clipPath element itself
    final cascadeClipId = _extractPaintServerId(
      _getStyleOrAttributeValue(clipPathNode, 'clip-path'),
    );

    if (cascadeClipId == null ||
        cascadeClipId.isEmpty ||
        useStack.contains(cascadeClipId)) {
      return newContext.computeEffectiveClipPath();
    }

    final cascadeClipNode = document.root.findById(cascadeClipId);
    if (cascadeClipNode == null || cascadeClipNode.tagName != 'clipPath') {
      return newContext.computeEffectiveClipPath();
    }

    // Recursively build cascading clip
    return _buildCascadingClipPathWithTransformPropagation(
      clippedNode: clippedNode,
      clipPathNode: cascadeClipNode,
      useStack: {...useStack, cascadeClipId},
      context: newContext,
    );
  }

  /// Computes objectBoundingBox transform with advanced handling for edge cases.
  ///
  /// Handles:
  /// - Non-square bounding boxes with proper aspect ratio
  /// - Very small dimensions with safe scaling
  /// - Zero-size elements
  Matrix4? _computeObjectBoundingBoxTransformAdvanced(
    SvgNode targetNode, {
    bool preserveAspectRatio = false,
  }) {
    final bounds = _computeNodeLocalBoundsWithStroke(targetNode);
    if (bounds == null) return null;

    // Edge case: zero width or height
    if (bounds.width.abs() < _kMinBoundingBoxDimension ||
        bounds.height.abs() < _kMinBoundingBoxDimension) {
      return null;
    }

    // Use safe dimensions for very small values
    final safeWidth = bounds.width.abs() < _kMinSafeScaleDimension
        ? _kMinSafeScaleDimension
        : bounds.width;
    final safeHeight = bounds.height.abs() < _kMinSafeScaleDimension
        ? _kMinSafeScaleDimension
        : bounds.height;

    if (preserveAspectRatio) {
      // Use uniform scale (smaller dimension)
      final scale = safeWidth < safeHeight ? safeWidth : safeHeight;
      return Matrix4.identity()
        ..setEntry(0, 0, scale)
        ..setEntry(1, 1, scale)
        ..setEntry(0, 3, bounds.left)
        ..setEntry(1, 3, bounds.top);
    }

    // Non-uniform scaling for non-square bounding boxes
    return Matrix4.identity()
      ..setEntry(0, 0, safeWidth)
      ..setEntry(1, 1, safeHeight)
      ..setEntry(0, 3, bounds.left)
      ..setEntry(1, 3, bounds.top);
  }

  /// Applies mask with proper edge feathering and anti-aliasing.
  ///
  /// Handles semi-transparent mask edges by:
  /// - Using anti-aliased path rendering
  /// - Properly blending alpha values at boundaries
  /// - Supporting soft edges from blur filters in mask content
  void _applyMaskWithEdgeFeathering(
    ui.Canvas canvas,
    SvgNode node, {
    required Set<String> useStack,
    required void Function() paintContent,
    bool enableFeathering = true,
  }) {
    final maskId = _extractPaintServerId(
      _getStyleOrAttributeValue(node, 'mask'),
    );
    if (maskId == null || maskId.isEmpty) {
      paintContent();
      return;
    }

    final maskNode = document.root.findById(maskId);
    if (maskNode == null || maskNode.tagName != 'mask') {
      paintContent();
      return;
    }

    final maskType = _parseMaskType(maskNode, node);
    final maskBounds = _computeMaskBounds(maskedNode: node, maskNode: maskNode);

    if (maskBounds == null ||
        maskBounds.width.abs() < _kMinBoundingBoxDimension ||
        maskBounds.height.abs() < _kMinBoundingBoxDimension) {
      return; // Empty mask - nothing rendered
    }

    // Check for feathering (blur filters in mask content)
    final hasFeathering = enableFeathering && _maskContentHasFeathering(maskNode);
    final effectiveBounds = hasFeathering
        ? _expandMaskBoundsForFeathering(maskBounds, maskNode)
        : maskBounds;

    // Save layer for content
    canvas.saveLayer(effectiveBounds, ui.Paint());

    // Paint the content
    paintContent();

    // Create mask paint based on type
    final maskPaint = maskType == _SvgMaskType.luminance
        ? _createLuminanceMaskPaintAdvanced()
        : _createAlphaMaskPaintAdvanced();

    // Save layer for mask with proper blend mode
    canvas.saveLayer(effectiveBounds, maskPaint);

    // Paint mask content with anti-aliasing
    _paintMaskContentWithAntiAliasing(
      canvas,
      maskNode: maskNode,
      maskedNode: node,
      useStack: useStack,
    );

    // Restore mask layer
    canvas.restore();

    // Restore content layer
    canvas.restore();
  }

  /// Creates luminance mask paint with proper RGB to luminance conversion.
  ///
  /// Per SVG spec: luminance = 0.2126*R + 0.7152*G + 0.0722*B
  /// This ensures correct luminance computation from RGB values.
  ui.Paint _createLuminanceMaskPaintAdvanced() {
    // Per SVG spec, luminance coefficients from ITU-R BT.709
    // These are the same as sRGB luminance coefficients
    final luminanceMatrix = Float64List.fromList(<double>[
      0, 0, 0, 0, 0, // R output = 0
      0, 0, 0, 0, 0, // G output = 0
      0, 0, 0, 0, 0, // B output = 0
      _kLuminanceR, _kLuminanceG, _kLuminanceB, 0, 0, // A = luminance * srcAlpha
    ]);

    return ui.Paint()
      ..blendMode = ui.BlendMode.dstIn
      ..colorFilter = ui.ColorFilter.matrix(luminanceMatrix)
      ..isAntiAlias = true;
  }

  /// Creates alpha mask paint with anti-aliasing support.
  ui.Paint _createAlphaMaskPaintAdvanced() {
    return ui.Paint()
      ..blendMode = ui.BlendMode.dstIn
      ..isAntiAlias = true;
  }

  /// Paints mask content with proper anti-aliasing for smooth edges.
  void _paintMaskContentWithAntiAliasing(
    ui.Canvas canvas, {
    required SvgNode maskNode,
    required SvgNode maskedNode,
    required Set<String> useStack,
  }) {
    final contentUnits = (_getString(maskNode, 'maskContentUnits') ??
            'userSpaceOnUse')
        .trim()
        .toLowerCase();

    Matrix4? contentTransform;
    if (contentUnits == 'objectboundingbox') {
      contentTransform = _computeMaskContentUnitsTransformAdvanced(
        maskedNode: maskedNode,
        maskNode: maskNode,
      );
    }

    if (contentTransform != null) {
      canvas.save();
      canvas.transform(contentTransform.storage);
    }

    // Paint mask children with anti-aliased rendering
    for (final child in maskNode.children) {
      _paintNode(canvas, child, useStack: useStack);
    }

    if (contentTransform != null) {
      canvas.restore();
    }
  }

  /// Computes maskContentUnits transform with proper coordinate system handling.
  ///
  /// Handles transitions between userSpaceOnUse and objectBoundingBox,
  /// especially when the object's bounding box is non-square.
  Matrix4? _computeMaskContentUnitsTransformAdvanced({
    required SvgNode maskedNode,
    required SvgNode maskNode,
  }) {
    final bounds = _computeNodeLocalBoundsWithStroke(maskedNode);
    if (bounds == null) return null;

    // Edge case: zero width or height
    if (bounds.width.abs() < _kMinBoundingBoxDimension ||
        bounds.height.abs() < _kMinBoundingBoxDimension) {
      return null;
    }

    // Handle very small dimensions safely for non-uniform scaling
    final safeWidth = bounds.width.abs() < _kMinSafeScaleDimension
        ? _kMinSafeScaleDimension
        : bounds.width;
    final safeHeight = bounds.height.abs() < _kMinSafeScaleDimension
        ? _kMinSafeScaleDimension
        : bounds.height;

    // Transform from objectBoundingBox (0-1) to user space
    return Matrix4.identity()
      ..setEntry(0, 0, safeWidth) // Scale X
      ..setEntry(1, 1, safeHeight) // Scale Y
      ..setEntry(0, 3, bounds.left) // Translate X
      ..setEntry(1, 3, bounds.top); // Translate Y
  }

  /// Applies nested mask with intersection handling.
  ///
  /// When a mask is applied within an already-masked context,
  /// this ensures proper intersection of the mask regions.
  void _applyNestedMaskWithIntersectionAdvanced(
    ui.Canvas canvas,
    SvgNode node, {
    required SvgNode maskNode,
    required ui.Rect maskBounds,
    required _SvgMaskType maskType,
    required Set<String> useStack,
    required _MaskNestingContext nestingContext,
    required void Function() paintContent,
  }) {
    // Compute effective bounds as intersection with parent mask
    final parentBounds = nestingContext.parentMaskBounds;
    final effectiveBounds = parentBounds != null
        ? maskBounds.intersect(parentBounds)
        : maskBounds;

    if (effectiveBounds.width.abs() < _kMinBoundingBoxDimension ||
        effectiveBounds.height.abs() < _kMinBoundingBoxDimension) {
      return; // No intersection - nothing to render
    }

    // Save content layer
    canvas.saveLayer(effectiveBounds, ui.Paint());

    // Paint content
    paintContent();

    // Create mask paint
    final maskPaint = maskType == _SvgMaskType.luminance
        ? _createLuminanceMaskPaintAdvanced()
        : _createAlphaMaskPaintAdvanced();

    // Save mask layer
    canvas.saveLayer(effectiveBounds, maskPaint);

    // Handle coordinate system transition
    _paintMaskContentWithUnitsTransition(
      canvas,
      maskNode: maskNode,
      maskedNode: node,
      parentContext: nestingContext,
      useStack: useStack,
    );

    // Restore layers
    canvas.restore();
    canvas.restore();
  }

  /// Paints mask content with proper coordinate system transition.
  ///
  /// Handles the transition between maskContentUnits when nested masks
  /// have different unit systems.
  void _paintMaskContentWithUnitsTransition(
    ui.Canvas canvas, {
    required SvgNode maskNode,
    required SvgNode maskedNode,
    required _MaskNestingContext parentContext,
    required Set<String> useStack,
  }) {
    final contentUnits = (_getString(maskNode, 'maskContentUnits') ??
            'userSpaceOnUse')
        .trim()
        .toLowerCase();
    final parentUnits = parentContext.parentMaskContentUnits.toLowerCase();

    Matrix4? contentTransform;

    if (contentUnits == 'objectboundingbox') {
      // Current mask uses objectBoundingBox
      contentTransform = _computeMaskContentUnitsTransformAdvanced(
        maskedNode: maskedNode,
        maskNode: maskNode,
      );

      // If parent was also objectBoundingBox but with different bounds,
      // we need to account for the coordinate difference
      if (parentUnits == 'objectboundingbox' &&
          parentContext.parentObjectBounds != null) {
        final currentBounds = _computeNodeLocalBoundsWithStroke(maskedNode);
        if (currentBounds != null && contentTransform != null) {
          // Compute relative transform between parent and current OBB
          final parentBounds = parentContext.parentObjectBounds!;
          if ((parentBounds.width - currentBounds.width).abs() >
                  _kMinBoundingBoxDimension ||
              (parentBounds.height - currentBounds.height).abs() >
                  _kMinBoundingBoxDimension) {
            // Different bounds - apply correction transform
            // This handles the case where nested masks reference elements
            // with different bounding boxes
            final correctionTransform = _computeOBBTransitionTransform(
              from: parentBounds,
              to: currentBounds,
            );
            if (correctionTransform != null) {
              contentTransform = Matrix4.copy(contentTransform)
                ..multiply(correctionTransform);
            }
          }
        }
      }
    } else if (parentUnits == 'objectboundingbox') {
      // Transitioning from objectBoundingBox to userSpaceOnUse
      // Need to invert the parent's OBB transform
      if (parentContext.accumulatedTransform != null) {
        final inverted = Matrix4.copy(parentContext.accumulatedTransform!);
        final det = inverted.determinant();
        if (det.abs() > 1e-10) {
          inverted.invert();
          contentTransform = inverted;
        }
      }
    }

    if (contentTransform != null) {
      canvas.save();
      canvas.transform(contentTransform.storage);
    }

    // Paint mask children
    for (final child in maskNode.children) {
      _paintNode(canvas, child, useStack: useStack);
    }

    if (contentTransform != null) {
      canvas.restore();
    }
  }

  /// Computes transform for transitioning between objectBoundingBox coordinates.
  Matrix4? _computeOBBTransitionTransform({
    required ui.Rect from,
    required ui.Rect to,
  }) {
    if (from.width.abs() < _kMinBoundingBoxDimension ||
        from.height.abs() < _kMinBoundingBoxDimension ||
        to.width.abs() < _kMinBoundingBoxDimension ||
        to.height.abs() < _kMinBoundingBoxDimension) {
      return null;
    }

    // Compute scale factors
    final scaleX = to.width / from.width;
    final scaleY = to.height / from.height;

    // Compute translation
    final translateX = to.left - from.left * scaleX;
    final translateY = to.top - from.top * scaleY;

    return Matrix4.identity()
      ..setEntry(0, 0, scaleX)
      ..setEntry(1, 1, scaleY)
      ..setEntry(0, 3, translateX)
      ..setEntry(1, 3, translateY);
  }

  /// Renders content with subgraph masking for filtered elements.
  ///
  /// Per CSS Compositing spec, when an element has both filter and mask:
  /// 1. Render element content
  /// 2. Apply filter to rendered content
  /// 3. Apply mask to the filtered result
  ///
  /// This ensures the mask operates on the post-filter image.
  void _renderSubgraphWithMaskAdvanced(
    ui.Canvas canvas, {
    required SvgNode node,
    required SvgNode maskNode,
    required _SvgMaskType maskType,
    required ui.Rect maskBounds,
    required Set<String> useStack,
    required void Function() paintContent,
  }) {
    // Check for feathering in mask content
    final hasFeathering = _maskContentHasFeathering(maskNode);
    final effectiveBounds = hasFeathering
        ? _expandMaskBoundsForFeathering(maskBounds, maskNode)
        : maskBounds;

    // Save content layer - this captures the filtered content
    canvas.saveLayer(effectiveBounds, ui.Paint());

    // Paint the content (filters are applied during normal painting)
    paintContent();

    // Create mask paint based on type
    final maskPaint = maskType == _SvgMaskType.luminance
        ? _createLuminanceMaskPaintAdvanced()
        : _createAlphaMaskPaintAdvanced();

    // Save mask layer with proper blend mode
    canvas.saveLayer(effectiveBounds, maskPaint);

    // Paint mask content
    _paintMaskContentWithAntiAliasing(
      canvas,
      maskNode: maskNode,
      maskedNode: node,
      useStack: useStack,
    );

    // Restore mask layer
    canvas.restore();

    // Restore content layer
    canvas.restore();
  }

  /// Applies mask to an element that has filter effects.
  ///
  /// The rendering order is:
  /// 1. Apply filter first (handled by normal filter rendering)
  /// 2. Apply mask to the filtered result
  ///
  /// This ensures masks operate on post-filter graphics.
  bool _applyMaskToFilteredElement(
    ui.Canvas canvas,
    SvgNode node, {
    required Set<String> useStack,
    required void Function() paintFilteredContent,
  }) {
    final maskId = _extractPaintServerId(
      _getStyleOrAttributeValue(node, 'mask'),
    );
    if (maskId == null || maskId.isEmpty) {
      return false;
    }

    final maskNode = document.root.findById(maskId);
    if (maskNode == null || maskNode.tagName != 'mask') {
      return false;
    }

    final maskType = _parseMaskType(maskNode, node);
    final maskBounds = _computeMaskBounds(maskedNode: node, maskNode: maskNode);

    if (maskBounds == null ||
        maskBounds.width.abs() < _kMinBoundingBoxDimension ||
        maskBounds.height.abs() < _kMinBoundingBoxDimension) {
      return true; // Mask present but no visible region
    }

    // Render with mask applied after filter processing
    _renderSubgraphWithMaskAdvanced(
      canvas,
      node: node,
      maskNode: maskNode,
      maskType: maskType,
      maskBounds: maskBounds,
      useStack: useStack,
      paintContent: paintFilteredContent,
    );

    return true;
  }
}
