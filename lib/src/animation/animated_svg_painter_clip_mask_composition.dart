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
/// - Luminosity masking: mask opacity from luminance (default per SVG spec)
/// - Alpha masking: mask opacity from alpha channel
/// - Mask edge feathering: soft edges via blur filters

/// Luminance coefficients per ITU-R BT.709 / sRGB for composition operations.
const double _kCompositionLuminanceR = 0.2126;
const double _kCompositionLuminanceG = 0.7152;
const double _kCompositionLuminanceB = 0.0722;

/// Mask type enumeration for composition operations.
enum _CompositionMaskType {
  /// Alpha masking - uses alpha channel directly.
  alpha,

  /// Luminance masking - converts RGB to grayscale luminance.
  /// Formula: L = 0.2126 * R + 0.7152 * G + 0.0722 * B
  /// Per SVG spec, this is the DEFAULT mask-type.
  luminance,
}

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

  // ============================================================================
  // Luminosity Masking Support
  // ============================================================================

  /// Parses the mask-type for composition operations.
  ///
  /// Per SVG spec, the default mask-type is `luminance` (not alpha!).
  /// Priority order:
  /// 1. CSS mask-mode property on the masked element
  /// 2. CSS mask-type property on the masked element
  /// 3. type attribute on the mask element
  /// 4. mask-type style on mask element
  /// 5. Default: luminance (per SVG spec)
  _CompositionMaskType _parseCompositionMaskType(
    SvgNode maskNode,
    SvgNode maskedNode,
  ) {
    // Check CSS mask-mode property (CSS Masking Level 1)
    // mask-mode can be: alpha | luminance | match-source
    final maskModeValue = _getStyleOrAttributeValue(maskedNode, 'mask-mode');
    if (maskModeValue != null) {
      final normalized = maskModeValue.toString().trim().toLowerCase();
      if (normalized == 'alpha') return _CompositionMaskType.alpha;
      if (normalized == 'luminance') return _CompositionMaskType.luminance;
      // match-source uses the mask element's type
    }

    // Check CSS mask-type property on the masked element
    final maskTypeValue = _getStyleOrAttributeValue(maskedNode, 'mask-type');
    if (maskTypeValue != null) {
      final normalized = maskTypeValue.toString().trim().toLowerCase();
      if (normalized == 'alpha') return _CompositionMaskType.alpha;
      if (normalized == 'luminance') return _CompositionMaskType.luminance;
    }

    // Check type attribute on the mask element
    final typeAttr = _getString(maskNode, 'type');
    if (typeAttr != null) {
      final normalized = typeAttr.trim().toLowerCase();
      if (normalized == 'alpha') return _CompositionMaskType.alpha;
      if (normalized == 'luminance') return _CompositionMaskType.luminance;
    }

    // Check mask-type style on mask element
    final maskElementType = _getStyleOrAttributeValue(maskNode, 'mask-type');
    if (maskElementType != null) {
      final normalized = maskElementType.toString().trim().toLowerCase();
      if (normalized == 'alpha') return _CompositionMaskType.alpha;
      if (normalized == 'luminance') return _CompositionMaskType.luminance;
    }

    // Default to luminance masking per SVG spec
    return _CompositionMaskType.luminance;
  }

  /// Creates the color matrix for luminance-to-alpha conversion.
  ///
  /// Per sRGB standard (ITU-R BT.709):
  /// Luminance = 0.2126 * R + 0.7152 * G + 0.0722 * B
  ///
  /// The matrix converts RGB to luminance and outputs it as alpha.
  /// White (1,1,1) -> alpha = 1.0 (fully visible)
  /// Black (0,0,0) -> alpha = 0.0 (fully hidden)
  /// Gray (0.5,0.5,0.5) -> alpha = 0.5 (50% visible)
  Float64List _createLuminanceToAlphaMatrix() {
    return Float64List.fromList(<double>[
      0, 0, 0, 0, 0, // R output = 0
      0, 0, 0, 0, 0, // G output = 0
      0, 0, 0, 0, 0, // B output = 0
      _kCompositionLuminanceR,
      _kCompositionLuminanceG,
      _kCompositionLuminanceB,
      0, // Luminance coefficients for alpha
      0, // Bias
    ]);
  }

  /// Creates a paint for luminance-based masking with DST_IN blend.
  ui.Paint _createCompositionLuminanceMaskPaint() {
    return ui.Paint()
      ..blendMode = ui.BlendMode.dstIn
      ..colorFilter = ui.ColorFilter.matrix(_createLuminanceToAlphaMatrix());
  }

  /// Computes the luminance value for a given color.
  ///
  /// Returns a value between 0.0 (black) and 1.0 (white).
  double _computeLuminance(ui.Color color) {
    final r = color.r;
    final g = color.g;
    final b = color.b;
    return _kCompositionLuminanceR * r +
        _kCompositionLuminanceG * g +
        _kCompositionLuminanceB * b;
  }

  // ============================================================================
  // Mask Edge Feathering Support
  // ============================================================================

  /// Gets the feather radius for mask edges.
  ///
  /// Feathering creates soft mask edges using blur. Sources:
  /// 1. feGaussianBlur applied to mask content
  /// 2. CSS mask-border-outset (not commonly used)
  /// 3. Explicit feather attribute (non-standard but useful)
  double? _getMaskFeatherRadius(SvgNode maskNode) {
    // Check for blur filter on mask content
    for (final child in maskNode.children) {
      final filterId = _getFilterId(child);
      if (filterId != null) {
        final filterNode = document.root.findById(filterId);
        if (filterNode != null && filterNode.tagName == 'filter') {
          for (final primitive in filterNode.children) {
            if (primitive.tagName == 'feGaussianBlur') {
              final stdDeviation = _getString(primitive, 'stdDeviation');
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
        }
      }
    }

    // Check for feather attribute (non-standard extension)
    final featherAttr = _getNumber(maskNode, 'feather');
    if (featherAttr != null && featherAttr > 0) {
      return featherAttr;
    }

    return null;
  }

  /// Creates an image filter for mask edge feathering.
  ///
  /// Uses Gaussian blur to create soft, anti-aliased mask edges.
  ui.ImageFilter? _createMaskFeatherFilter(double sigma) {
    if (sigma <= 0) return null;
    return ui.ImageFilter.blur(
      sigmaX: sigma,
      sigmaY: sigma,
      tileMode: ui.TileMode.decal,
    );
  }

  /// Creates a mask filter for soft edges.
  ///
  /// This provides feathered edges when applied to mask content.
  ui.MaskFilter? _createMaskEdgeFeather(double sigma) {
    if (sigma <= 0) return null;
    return ui.MaskFilter.blur(ui.BlurStyle.normal, sigma);
  }

  /// Applies mask with feathering support.
  ///
  /// When mask content has anti-aliased edges or blur filters,
  /// the mask produces smooth (feathered) transitions.
  void _applyFeatheredMask(
    ui.Canvas canvas,
    SvgNode maskedNode,
    SvgNode maskNode, {
    required ui.Rect maskBounds,
    required Set<String> useStack,
    required void Function() paintContent,
    double? featherRadius,
  }) {
    final maskType = _parseCompositionMaskType(maskNode, maskedNode);
    final effectiveFeather = featherRadius ?? _getMaskFeatherRadius(maskNode);

    // Save layer for the content
    canvas.saveLayer(maskBounds, ui.Paint());

    // Paint the content
    paintContent();

    // Create mask paint based on type
    final ui.Paint maskPaint;
    if (maskType == _CompositionMaskType.luminance) {
      maskPaint = _createCompositionLuminanceMaskPaint();
    } else {
      maskPaint = ui.Paint()..blendMode = ui.BlendMode.dstIn;
    }

    // Add feather filter if specified
    if (effectiveFeather != null && effectiveFeather > 0) {
      maskPaint.imageFilter = _createMaskFeatherFilter(effectiveFeather);
    }

    canvas.saveLayer(maskBounds, maskPaint);

    // Render mask content
    _paintMaskContentForComposition(
      canvas,
      maskNode: maskNode,
      maskedNode: maskedNode,
      useStack: useStack,
    );

    canvas.restore(); // mask layer
    canvas.restore(); // content layer
  }

  /// Paints mask content with proper coordinate transformation for composition.
  void _paintMaskContentForComposition(
    ui.Canvas canvas, {
    required SvgNode maskNode,
    required SvgNode maskedNode,
    required Set<String> useStack,
  }) {
    final contentUnits =
        (_getString(maskNode, 'maskContentUnits') ?? 'userSpaceOnUse')
            .trim()
            .toLowerCase();

    Matrix4? contentTransform;
    if (contentUnits == 'objectboundingbox') {
      final localBounds = _computeNodeLocalBoundsWithStroke(maskedNode);
      if (localBounds != null &&
          localBounds.width.abs() >= _kMinBoundingBoxDimension &&
          localBounds.height.abs() >= _kMinBoundingBoxDimension) {
        final safeWidth = localBounds.width.abs() < _kMinSafeScaleDimension
            ? _kMinSafeScaleDimension
            : localBounds.width;
        final safeHeight = localBounds.height.abs() < _kMinSafeScaleDimension
            ? _kMinSafeScaleDimension
            : localBounds.height;
        contentTransform = Matrix4.identity()
          ..setEntry(0, 0, safeWidth)
          ..setEntry(1, 1, safeHeight)
          ..setEntry(0, 3, localBounds.left)
          ..setEntry(1, 3, localBounds.top);
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

  // ============================================================================
  // Subgraph Masking (mask applied after filter)
  // ============================================================================

  /// Applies subgraph mask ensuring proper order: element -> filter -> mask.
  ///
  /// When an element has both filter and mask, the mask is applied to the
  /// filtered result, not the original content.
  void _applySubgraphMaskForComposition(
    ui.Canvas canvas,
    SvgNode node, {
    required Set<String> useStack,
    required void Function() paintFilteredContent,
  }) {
    final maskId = _extractPaintServerId(
      _getStyleOrAttributeValue(node, 'mask'),
    );
    if (maskId == null || maskId.isEmpty) {
      paintFilteredContent();
      return;
    }

    final maskNode = document.root.findById(maskId);
    if (maskNode == null || maskNode.tagName != 'mask') {
      paintFilteredContent();
      return;
    }

    final maskBounds = _computeMaskBounds(maskedNode: node, maskNode: maskNode);
    if (maskBounds == null ||
        maskBounds.width.abs() < _kMinBoundingBoxDimension ||
        maskBounds.height.abs() < _kMinBoundingBoxDimension) {
      return;
    }

    // Apply mask to filtered content
    _applyFeatheredMask(
      canvas,
      node,
      maskNode,
      maskBounds: maskBounds,
      useStack: useStack,
      paintContent: paintFilteredContent,
    );
  }

  // ============================================================================
  // Empty Mask Handling
  // ============================================================================

  /// Checks if a mask is empty (has no visible content).
  ///
  /// Per SVG spec, an empty mask (no children or all transparent children)
  /// should hide the element completely.
  bool _isEmptyMask(SvgNode maskNode) {
    // Check if mask has any valid children
    for (final child in maskNode.children) {
      // Skip animation elements
      if (child.tagName == 'animate' ||
          child.tagName == 'animateTransform' ||
          child.tagName == 'animateColor' ||
          child.tagName == 'animateMotion' ||
          child.tagName == 'set') {
        continue;
      }
      // Has at least one content child
      return false;
    }
    return true;
  }

  // ============================================================================
  // Mask with Transform Support
  // ============================================================================

  /// Applies mask content transform from mask element.
  Matrix4? _getMaskContentTransform(SvgNode maskNode) {
    final transformAttr = maskNode.getAttributeValue('transform');
    if (transformAttr == null) return null;
    return _buildTransformMatrixFromValue(transformAttr);
  }

  /// Renders mask with content transform applied.
  void _renderMaskWithTransform(
    ui.Canvas canvas, {
    required SvgNode maskNode,
    required SvgNode maskedNode,
    required ui.Rect maskBounds,
    required Set<String> useStack,
    required void Function() paintContent,
  }) {
    final maskType = _parseCompositionMaskType(maskNode, maskedNode);
    final contentTransform = _getMaskContentTransform(maskNode);

    // Save layer for the content
    canvas.saveLayer(maskBounds, ui.Paint());

    // Paint the content
    paintContent();

    // Create mask paint based on type
    final ui.Paint maskPaint;
    if (maskType == _CompositionMaskType.luminance) {
      maskPaint = _createCompositionLuminanceMaskPaint();
    } else {
      maskPaint = ui.Paint()..blendMode = ui.BlendMode.dstIn;
    }

    canvas.saveLayer(maskBounds, maskPaint);

    // Apply mask content transform if present
    if (contentTransform != null) {
      canvas.save();
      canvas.transform(contentTransform.storage);
    }

    // Render mask content with maskContentUnits transformation
    _paintMaskContentForComposition(
      canvas,
      maskNode: maskNode,
      maskedNode: maskedNode,
      useStack: useStack,
    );

    if (contentTransform != null) {
      canvas.restore();
    }

    canvas.restore(); // mask layer
    canvas.restore(); // content layer
  }
}
