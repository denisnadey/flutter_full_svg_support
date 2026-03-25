part of 'animated_svg_painter.dart';

/// Advanced composition chain support for SVG clip-path and mask.
///
/// Implements proper nesting order per SVG 2 specification:
/// - transforms are applied first (handled by _applyTransform)
/// - clip-path is applied next (geometric clipping)
/// - mask is applied last (alpha/luminance masking)
///
/// Supports:
/// - clip-path inside mask: Masked element has clip-path → clip first, then mask
/// - mask inside clip-path: Clipped element has mask → apply both
/// - Nested clip-paths: clip-path on element inside another clipped element
/// - Nested masks: mask on element inside another masked element
/// - Mixed nesting: clip → mask → clip chains
extension AnimatedSvgPainterClipMaskCompositionExtension on AnimatedSvgPainter {
  /// Applies the full composition chain for an element.
  ///
  /// Order: transform (already applied) → clip-path → mask → paint content
  ///
  /// This method handles the proper nesting of clip and mask operations,
  /// ensuring that nested compositions are handled correctly.
  void _applyCompositionChain(
    ui.Canvas canvas,
    SvgNode node, {
    required Set<String> useStack,
    required void Function() paintContent,
  }) {
    final hasClip = _hasClipPath(node);
    final hasMaskRef = _hasMask(node);

    if (!hasClip && !hasMaskRef) {
      // No composition needed, just paint
      paintContent();
      return;
    }

    if (hasClip && !hasMaskRef) {
      // Only clip-path
      _applyClipPath(canvas, node, useStack: useStack);
      paintContent();
      return;
    }

    if (!hasClip && hasMaskRef) {
      // Only mask - use advanced masking with proper compositing
      _applyAdvancedMask(
        canvas,
        node,
        useStack: useStack,
        paintContent: paintContent,
      );
      return;
    }

    // Both clip-path and mask: apply clip first, then mask
    _applyClipPath(canvas, node, useStack: useStack);
    _applyAdvancedMask(
      canvas,
      node,
      useStack: useStack,
      paintContent: paintContent,
    );
  }

  /// Applies nested clip-path composition.
  ///
  /// When a clip-path element itself has a clip-path, both clips are applied
  /// (intersection of the two clip regions).
  ui.Path? _buildNestedClipPath({
    required SvgNode clippedNode,
    required SvgNode clipPathNode,
    required Set<String> useStack,
    int depth = 0,
  }) {
    // Prevent infinite recursion
    if (depth > 10) return null;

    // Build the primary clip path
    final primaryPath = _buildClipPathForNode(
      clippedNode: clippedNode,
      clipPathNode: clipPathNode,
      useStack: useStack,
    );

    if (primaryPath == null) return null;

    // Check if the clipPath element itself has a clip-path
    final nestedClipId = _extractPaintServerId(
      _getStyleOrAttributeValue(clipPathNode, 'clip-path'),
    );

    if (nestedClipId == null || nestedClipId.isEmpty) {
      return primaryPath;
    }

    final nestedClipNode = document.root.findById(nestedClipId);
    if (nestedClipNode == null || nestedClipNode.tagName != 'clipPath') {
      return primaryPath;
    }

    // Build the nested clip path
    final nestedPath = _buildNestedClipPath(
      clippedNode: clipPathNode,
      clipPathNode: nestedClipNode,
      useStack: useStack,
      depth: depth + 1,
    );

    if (nestedPath == null) return primaryPath;

    // Intersect the two clip paths
    return ui.Path.combine(
      ui.PathOperation.intersect,
      primaryPath,
      nestedPath,
    );
  }

  /// Builds a clip-path that handles clip-path references inside the clipPath
  /// element (not on the clipPath element itself, but within its children).
  ui.Path? _buildClipPathWithNestedClips({
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

    _appendClipGeometryWithNesting(
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

  /// Appends clip geometry handling nested clip-path references.
  void _appendClipGeometryWithNesting({
    required ui.Path target,
    required SvgNode node,
    required Matrix4 currentTransform,
    required Set<String> useStack,
  }) {
    // Check if this element itself has a clip-path
    final elementClipId = _extractPaintServerId(
      _getStyleOrAttributeValue(node, 'clip-path'),
    );

    if (elementClipId != null && elementClipId.isNotEmpty) {
      final elementClipNode = document.root.findById(elementClipId);
      if (elementClipNode != null && elementClipNode.tagName == 'clipPath') {
        // This element is clipped - build its clipped geometry
        final elementPath = _buildClipGeometryForElement(
          node: node,
          currentTransform: currentTransform,
          useStack: useStack,
        );

        if (elementPath != null) {
          final clipForElement = _buildClipPathForNode(
            clippedNode: node,
            clipPathNode: elementClipNode,
            useStack: useStack,
          );

          if (clipForElement != null) {
            // Intersect element geometry with its clip-path
            final clippedGeometry = ui.Path.combine(
              ui.PathOperation.intersect,
              elementPath,
              clipForElement,
            );
            target.addPath(clippedGeometry, ui.Offset.zero);
            return;
          }
        }
      }
    }

    // No clip-path on this element, use standard geometry appending
    _appendClipGeometry(
      target: target,
      node: node,
      currentTransform: currentTransform,
      useStack: useStack,
    );
  }

  /// Builds clip geometry for a single element (without recursing to children).
  ui.Path? _buildClipGeometryForElement({
    required SvgNode node,
    required Matrix4 currentTransform,
    required Set<String> useStack,
  }) {
    final matrix = Matrix4.copy(currentTransform);
    final nodeTransform = _buildTransformMatrixFromValue(
      node.getAttributeValue('transform'),
    );
    if (nodeTransform != null) {
      matrix.multiply(nodeTransform);
    }

    switch (node.tagName) {
      case 'clipPath':
      case 'mask':
      case 'g':
      case 'svg':
      case 'symbol':
        // For container elements, combine all children's geometry
        final combinedPath = ui.Path();
        for (final child in node.children) {
          final childPath = _buildClipGeometryForElement(
            node: child,
            currentTransform: matrix,
            useStack: useStack,
          );
          if (childPath != null) {
            combinedPath.addPath(childPath, ui.Offset.zero);
          }
        }
        final bounds = combinedPath.getBounds();
        if (bounds.width.abs() < 1e-6 || bounds.height.abs() < 1e-6) {
          return null;
        }
        return combinedPath;

      case 'use':
        final hrefId = _extractHrefId(node);
        if (hrefId == null || hrefId.isEmpty || useStack.contains(hrefId)) {
          return null;
        }
        if (useStack.length >= _kMaxUseRecursionDepth) {
          return null;
        }
        final referenced = document.root.findById(hrefId);
        if (referenced == null ||
            !_isUseReferenceAllowedTag(referenced.tagName)) {
          return null;
        }
        final x = _getNumber(node, 'x') ?? 0.0;
        final y = _getNumber(node, 'y') ?? 0.0;
        final translated = Matrix4.copy(matrix)
          ..multiply(
            Matrix4.identity()
              ..setEntry(0, 3, x)
              ..setEntry(1, 3, y),
          );
        final nextUseStack = <String>{...useStack, hrefId};
        return _buildClipGeometryForElement(
          node: referenced,
          currentTransform: translated,
          useStack: nextUseStack,
        );

      default:
        final path = _buildGeometryPath(node);
        if (path == null) return null;
        return path.transform(matrix.storage);
    }
  }

  /// Computes the effective clip bounds for nested clips.
  ui.Rect? _computeNestedClipBounds({
    required SvgNode node,
    required Set<String> useStack,
    int depth = 0,
  }) {
    if (depth > 10) return null;

    final clipId = _extractPaintServerId(
      _getStyleOrAttributeValue(node, 'clip-path'),
    );

    if (clipId == null || clipId.isEmpty) return null;

    final clipNode = document.root.findById(clipId);
    if (clipNode == null || clipNode.tagName != 'clipPath') return null;

    final clipPath = _buildClipPathForNode(
      clippedNode: node,
      clipPathNode: clipNode,
      useStack: useStack,
    );

    if (clipPath == null) return null;

    var bounds = clipPath.getBounds();

    // Check for nested clip on the clipPath element
    final nestedBounds = _computeNestedClipBounds(
      node: clipNode,
      useStack: useStack,
      depth: depth + 1,
    );

    if (nestedBounds != null) {
      // Intersect bounds
      bounds = bounds.intersect(nestedBounds);
    }

    return bounds;
  }

  /// Applies clip-path with support for anti-aliased edges.
  ///
  /// When doAntiAlias is true (default), the clip edges are smoothed.
  void _applyClipPathAntiAliased(
    ui.Canvas canvas,
    SvgNode node, {
    required Set<String> useStack,
    bool doAntiAlias = true,
  }) {
    final clipId = _extractPaintServerId(
      _getStyleOrAttributeValue(node, 'clip-path'),
    );
    if (clipId == null || clipId.isEmpty) return;

    final clipNode = document.root.findById(clipId);
    if (clipNode == null || clipNode.tagName != 'clipPath') return;

    final clipPath = _buildClipPathWithNestedClips(
      clippedNode: node,
      clipPathNode: clipNode,
      useStack: useStack,
    );

    if (clipPath == null) return;

    canvas.clipPath(clipPath, doAntiAlias: doAntiAlias);
  }

  /// Gets soft-edge feathering radius from clip-path or mask filter.
  ///
  /// When feGaussianBlur is applied to a clip/mask, edges should be soft.
  double? _getClipMaskFeatherRadius(SvgNode node) {
    // Check if the clip-path or mask references a filter with blur
    final filterId = _getFilterId(node);
    if (filterId == null) return null;

    if (document.filters == null) return null;

    // Look for feGaussianBlur in the filter chain
    final filterNode = document.root.findById(filterId);
    if (filterNode == null || filterNode.tagName != 'filter') return null;

    for (final child in filterNode.children) {
      if (child.tagName == 'feGaussianBlur') {
        final stdDeviation = _getString(child, 'stdDeviation');
        if (stdDeviation != null) {
          final parts = stdDeviation.split(RegExp(r'[\s,]+'));
          if (parts.isNotEmpty) {
            final sigma = double.tryParse(parts.first);
            if (sigma != null && sigma > 0) {
              return sigma;
            }
          }
        }
      }
    }

    return null;
  }
}
