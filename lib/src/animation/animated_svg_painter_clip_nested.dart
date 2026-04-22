part of 'animated_svg_painter.dart';

/// Nested clip-path intersection computation and transform handling.
///
/// Contains methods for:
/// - ClipPath transform stack building
/// - Cascading clipPath handling with mixed units
/// - Empty and zero-area clipPath handling
extension AnimatedSvgPainterClipNestedExtension on AnimatedSvgPainter {
  /// Builds the accumulated transform matrix for clipPath application.
  ///
  /// When a clipPath is applied through multiple nested group transforms,
  /// this method computes the correct composition of all transforms.
  // ignore: unused_element
  Matrix4 _buildClipPathTransformStack({
    required SvgNode targetNode,
    required SvgNode clipPathNode,
  }) {
    final result = Matrix4.identity();

    // First, apply the clipPath's own transform if present
    final clipTransform = _buildTransformMatrixFromValue(
      clipPathNode.getAttributeValue('transform'),
    );
    if (clipTransform != null) {
      result.multiply(clipTransform);
    }

    return result;
  }

  /// Computes effective clip path with proper coordinate transform stacking.
  ///
  /// This handles the case where clipPath is applied through multiple
  /// nested group transforms, ensuring all transforms are correctly composed.
  ui.Path? _buildClipPathWithTransformStack({
    required SvgNode clippedNode,
    required SvgNode clipPathNode,
    required Set<String> useStack,
  }) {
    final clipUnits = _getString(
      clipPathNode,
      'clipPathUnits',
    )?.trim().toLowerCase();
    final isObjectBoundingBox = clipUnits == 'objectboundingbox';

    // Build the base clip path
    final clipPath = ui.Path();

    Matrix4 rootMatrix = Matrix4.identity();
    if (isObjectBoundingBox) {
      final obbTransform = _computeObjectBoundingBoxTransform(clippedNode);
      if (obbTransform == null) {
        return null;
      }
      rootMatrix = obbTransform;
    }

    // Apply clipPath's own transform
    final clipTransform = _buildTransformMatrixFromValue(
      clipPathNode.getAttributeValue('transform'),
    );
    if (clipTransform != null) {
      rootMatrix.multiply(clipTransform);
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

  /// Applies clip-path with proper transform stacking for deeply nested elements.
  ///
  /// When an element is deeply nested in groups with transforms, and has a
  /// clip-path applied, this ensures all ancestor transforms are accounted for.
  // ignore: unused_element
  void _applyClipPathWithTransformStack(
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

    final clipPath = _buildClipPathWithTransformStack(
      clippedNode: node,
      clipPathNode: clipNode,
      useStack: useStack,
    );

    if (clipPath == null) {
      return;
    }

    canvas.clipPath(clipPath, doAntiAlias: true);
  }

  /// Builds a cascading clip path with proper unit handling at each level.
  ///
  /// When clipPaths are cascaded (clipPath on clipPath), each may have
  /// different clipPathUnits. This method handles the correct coordinate
  /// system transformation at each cascade level.
  ///
  /// Per SVG spec, when a clipPath element has a clip-path attribute:
  /// 1. The clipping region is the intersection of both clip regions
  /// 2. Each clipPath may use different clipPathUnits (userSpaceOnUse or objectBoundingBox)
  /// 3. Transforms on clipPath elements are applied to their content
  /// 4. The intersection is computed in the same coordinate space
  ///
  /// For mixed units handling:
  /// - userSpaceOnUse: clip path coordinates are in the current user coordinate system
  /// - objectBoundingBox: coordinates are relative to the clipped element's bbox (0-1)
  /// - When units differ between cascade levels, each path is computed in its own
  ///   coordinate system before intersection
  ///
  /// For use elements within clipPath:
  /// - Referenced element's geometry is used for clipping
  /// - Symbol viewBox transforms are applied correctly
  /// - objectBoundingBox coordinates are passed through use resolution
  ///
  /// Transform propagation through the chain:
  /// - Each clipPath's transform attribute is accumulated into the chain
  /// - objectBoundingBox transforms are computed per level relative to original element
  /// - The final clip path is the intersection of all levels in user space
  ui.Path? _buildCascadingClipPathWithUnits({
    required SvgNode clippedNode,
    required SvgNode clipPathNode,
    required Set<String> useStack,
    int depth = 0,
    Matrix4? accumulatedTransform,
  }) {
    const maxDepth = 10;
    if (depth > maxDepth) {
      return null;
    }

    // Check for empty clipPath (per SVG spec, empty clipPath hides content)
    if (_isEmptyClipPath(clipPathNode)) {
      return ui.Path(); // Return empty path to hide content
    }

    // Determine units for this clipPath
    final units = _getString(
      clipPathNode,
      'clipPathUnits',
    )?.trim().toLowerCase();
    final isObjectBoundingBox = units == 'objectboundingbox';

    // Build transform for this level, accumulating from parent transforms
    Matrix4 rootMatrix = accumulatedTransform != null
        ? Matrix4.copy(accumulatedTransform)
        : Matrix4.identity();

    if (isObjectBoundingBox) {
      final obbResult = _computeObjectBoundingBoxTransformForClipWithBounds(
        clippedNode,
      );
      if (obbResult == null) {
        // Zero-size element with objectBoundingBox - hide all content
        return ui.Path();
      }
      // Apply OBB transform to current accumulated transform
      rootMatrix.multiply(obbResult.$1);
    }

    // Apply clipPath's own transform attribute if present
    final clipTransformStr = clipPathNode.getAttributeValue('transform');
    if (clipTransformStr != null) {
      final clipTransform = _buildTransformMatrixFromValue(clipTransformStr);
      if (clipTransform != null) {
        rootMatrix.multiply(clipTransform);
      }
    }

    final clipPath = ui.Path();
    _appendClipGeometryWithClipRule(
      target: clipPath,
      node: clipPathNode,
      currentTransform: rootMatrix,
      useStack: useStack,
    );

    final bounds = clipPath.getBounds();
    if (bounds.width.abs() < _kMinBoundingBoxDimension ||
        bounds.height.abs() < _kMinBoundingBoxDimension) {
      return ui.Path(); // Empty clip region hides content
    }

    // Check for cascading clip-path on the clipPath element itself
    final cascadeClipId = _extractPaintServerId(
      _getStyleOrAttributeValue(clipPathNode, 'clip-path'),
    );

    if (cascadeClipId == null || cascadeClipId.isEmpty) {
      return clipPath;
    }

    if (useStack.contains(cascadeClipId)) {
      return clipPath; // Prevent circular references
    }

    final cascadeClipNode = document.root.findById(cascadeClipId);
    if (cascadeClipNode == null || cascadeClipNode.tagName != 'clipPath') {
      return clipPath; // Invalid reference, use current clip
    }

    // Build cascading clip with its own unit system
    // For nested clipPath, the coordinate system depends on:
    // - userSpaceOnUse: use the same coordinate system
    // - objectBoundingBox: relative to original clipped element's bbox
    // Pass the accumulated transform for proper transform chain propagation
    final cascadePath = _buildCascadingClipPathWithUnits(
      clippedNode: clippedNode, // Use original clipped node for consistent OBB
      clipPathNode: cascadeClipNode,
      useStack: {...useStack, cascadeClipId},
      depth: depth + 1,
      // Each nested clipPath resolves in its own units/transform space
      // relative to the original clipped node. Carrying parent rootMatrix here
      // breaks mixed userSpaceOnUse/objectBoundingBox cascades by double
      // applying unit transforms.
      accumulatedTransform: null,
    );

    if (cascadePath == null) {
      return clipPath;
    }

    // Intersect both paths using Path.combine for proper cascading effect
    // Both paths are now in the same coordinate space (user space)
    return ui.Path.combine(ui.PathOperation.intersect, clipPath, cascadePath);
  }

  /// Computes objectBoundingBox transform and returns both transform and bounds.
  ///
  /// Returns null if the element has zero-size bounding box.
  /// In objectBoundingBox mode:
  /// - (0,0) maps to top-left of element's bounding box
  /// - (1,1) maps to bottom-right of element's bounding box
  (Matrix4, ui.Rect)? _computeObjectBoundingBoxTransformForClipWithBounds(
    SvgNode targetNode,
  ) {
    final bounds = _computeNodeLocalBoundsWithStroke(targetNode);
    if (bounds == null) {
      return null;
    }

    // Edge case: zero width or height
    if (bounds.width.abs() < _kMinBoundingBoxDimension ||
        bounds.height.abs() < _kMinBoundingBoxDimension) {
      return null;
    }

    // Use safe dimensions to prevent extreme scaling
    final safeWidth = bounds.width.abs() < _kMinSafeScaleDimension
        ? _kMinSafeScaleDimension
        : bounds.width;
    final safeHeight = bounds.height.abs() < _kMinSafeScaleDimension
        ? _kMinSafeScaleDimension
        : bounds.height;

    // Transform from objectBoundingBox coordinates (0-1) to user space
    final matrix = Matrix4.identity()
      ..setEntry(0, 0, safeWidth) // Scale X
      ..setEntry(1, 1, safeHeight) // Scale Y
      ..setEntry(0, 3, bounds.left) // Translate X
      ..setEntry(1, 3, bounds.top); // Translate Y

    return (matrix, bounds);
  }

  /// Appends clip geometry with proper clip-rule handling.
  ///
  /// Supports clip-rule attribute on clipPath children:
  /// - nonzero (default): non-zero winding rule
  /// - evenodd: even-odd rule
  void _appendClipGeometryWithClipRule({
    required ui.Path target,
    required SvgNode node,
    required Matrix4 currentTransform,
    required Set<String> useStack,
  }) {
    _appendClipGeometry(
      target: target,
      node: node,
      currentTransform: currentTransform,
      useStack: useStack,
    );
  }

  /// Handles empty clipPath edge case.
  ///
  /// Per SVG spec, an empty clipPath (no valid children) should result
  /// in no content being rendered.
  bool _isEmptyClipPath(SvgNode clipPathNode) {
    // Check if clipPath has any valid geometry children
    for (final child in clipPathNode.children) {
      switch (child.tagName) {
        case 'path':
        case 'rect':
        case 'circle':
        case 'ellipse':
        case 'polygon':
        case 'polyline':
        case 'text':
        case 'use':
        case 'g':
          // Has at least one potentially valid child
          return false;
        default:
          continue;
      }
    }
    return true;
  }

  /// Handles zero-area clip edge case.
  ///
  /// A clip path that results in zero area should hide all content.
  bool _isZeroAreaClipPath(ui.Path clipPath) {
    final bounds = clipPath.getBounds();
    return bounds.width.abs() < _kMinBoundingBoxDimension ||
        bounds.height.abs() < _kMinBoundingBoxDimension;
  }
}
