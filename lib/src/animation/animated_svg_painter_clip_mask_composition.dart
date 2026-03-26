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
/// - Mask inheritance through groups: masks on group elements affect all children
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
    final hasMultipleMasks = _hasMultipleMasks(node);

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
      // Only mask - check for multiple masks
      if (hasMultipleMasks) {
        _applyMultipleMasks(
          canvas,
          node,
          useStack: useStack,
          paintContent: paintContent,
        );
      } else {
        _applyAdvancedMask(
          canvas,
          node,
          useStack: useStack,
          paintContent: paintContent,
        );
      }
      return;
    }

    // Both clip-path and mask: apply clip first, then mask
    _applyClipPath(canvas, node, useStack: useStack);
    if (hasMultipleMasks) {
      _applyMultipleMasks(
        canvas,
        node,
        useStack: useStack,
        paintContent: paintContent,
      );
    } else {
      _applyAdvancedMask(
        canvas,
        node,
        useStack: useStack,
        paintContent: paintContent,
      );
    }
  }

  /// Applies composition chain for group elements with mask inheritance.
  ///
  /// When a group has a mask, the mask affects all children within the group.
  /// Nested masks compose correctly - child mask within a masked group results
  /// in the intersection of both masks' effects.
  void _applyGroupCompositionChain(
    ui.Canvas canvas,
    SvgNode groupNode, {
    required Set<String> useStack,
    required void Function() paintChildren,
  }) {
    final hasClip = _hasClipPath(groupNode);
    final hasMaskRef = _hasMask(groupNode);
    final hasMultipleMasks = _hasMultipleMasks(groupNode);

    if (!hasClip && !hasMaskRef) {
      // No composition on this group, just paint children
      paintChildren();
      return;
    }

    if (hasClip && !hasMaskRef) {
      // Only clip-path on group - clip affects all children
      _applyClipPath(canvas, groupNode, useStack: useStack);
      paintChildren();
      return;
    }

    if (!hasClip && hasMaskRef) {
      // Only mask on group - mask affects all children
      if (hasMultipleMasks) {
        _applyMultipleMasks(
          canvas,
          groupNode,
          useStack: useStack,
          paintContent: paintChildren,
        );
      } else {
        _applyAdvancedMask(
          canvas,
          groupNode,
          useStack: useStack,
          paintContent: paintChildren,
        );
      }
      return;
    }

    // Both clip-path and mask on group
    _applyClipPath(canvas, groupNode, useStack: useStack);
    if (hasMultipleMasks) {
      _applyMultipleMasks(
        canvas,
        groupNode,
        useStack: useStack,
        paintContent: paintChildren,
      );
    } else {
      _applyAdvancedMask(
        canvas,
        groupNode,
        useStack: useStack,
        paintContent: paintChildren,
      );
    }
  }

  /// Computes effective mask bounds for nested masked elements.
  ///
  /// When an element has a mask and is inside a masked group, the effective
  /// mask bounds are the intersection of both mask regions.
  ui.Rect? _computeNestedMaskBounds({
    required SvgNode node,
    required SvgNode? parentMaskNode,
    required Set<String> useStack,
  }) {
    // Get this element's mask bounds
    final maskId = _extractPaintServerId(
      _getStyleOrAttributeValue(node, 'mask'),
    );

    ui.Rect? nodeMaskBounds;
    if (maskId != null && maskId.isNotEmpty) {
      final maskNode = document.root.findById(maskId);
      if (maskNode != null && maskNode.tagName == 'mask') {
        nodeMaskBounds = _computeMaskBounds(
          maskedNode: node,
          maskNode: maskNode,
        );
      }
    }

    // Get parent mask bounds if provided
    ui.Rect? parentBounds;
    if (parentMaskNode != null) {
      parentBounds = _computeMaskBounds(
        maskedNode: node,
        maskNode: parentMaskNode,
      );
    }

    // Combine bounds
    if (nodeMaskBounds == null) return parentBounds;
    if (parentBounds == null) return nodeMaskBounds;

    // Return intersection of both mask regions
    return nodeMaskBounds.intersect(parentBounds);
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
    return ui.Path.combine(ui.PathOperation.intersect, primaryPath, nestedPath);
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
      final localBounds = _computeNodeLocalBoundsWithStroke(clippedNode);
      if (localBounds == null) {
        return null;
      }
      // Edge case: zero or very small dimensions
      if (localBounds.width.abs() < _kMinBoundingBoxDimension ||
          localBounds.height.abs() < _kMinBoundingBoxDimension) {
        return null;
      }
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

    _appendClipGeometryWithNesting(
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
        if (bounds.width.abs() < _kMinBoundingBoxDimension ||
            bounds.height.abs() < _kMinBoundingBoxDimension) {
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

  /// Checks if an element should inherit mask from its parent group.
  ///
  /// In SVG, masks on group elements affect all children, creating an
  /// inheritance chain. This method walks up the parent tree to find
  /// any applicable masks.
  SvgNode? _findInheritedMaskNode(SvgNode node) {
    var current = node.parent;
    while (current != null) {
      if (_hasMask(current)) {
        final maskId = _extractPaintServerId(
          _getStyleOrAttributeValue(current, 'mask'),
        );
        if (maskId != null && maskId.isNotEmpty) {
          final maskNode = document.root.findById(maskId);
          if (maskNode != null && maskNode.tagName == 'mask') {
            return maskNode;
          }
        }
      }
      current = current.parent;
    }
    return null;
  }

  /// Checks if an element should inherit clip-path from its parent group.
  SvgNode? _findInheritedClipNode(SvgNode node) {
    var current = node.parent;
    while (current != null) {
      if (_hasClipPath(current)) {
        final clipId = _extractPaintServerId(
          _getStyleOrAttributeValue(current, 'clip-path'),
        );
        if (clipId != null && clipId.isNotEmpty) {
          final clipNode = document.root.findById(clipId);
          if (clipNode != null && clipNode.tagName == 'clipPath') {
            return clipNode;
          }
        }
      }
      current = current.parent;
    }
    return null;
  }
}
