part of 'animated_svg_painter.dart';

/// Maximum recursion depth for nested mask references.
const int _kMaxMaskPaintingRecursionDepth = 10;

/// Tracks visited mask IDs during a single paint cycle to prevent infinite recursion.
/// Used when masks reference each other in a cycle (A masks B which masks A).
Set<String>? _currentPaintingMasksStack;

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

/// Extension for advanced mask composition operations.
/// Handles layer-based masking with luminosity/alpha modes and edge feathering.
extension AnimatedSvgPainterMaskCompositionExtension on AnimatedSvgPainter {
  /// Applies advanced layer-based masking with luminosity/alpha mode support.
  ///
  /// This method uses Canvas.saveLayer for proper compositing instead of
  /// simple path clipping. It supports:
  /// - Luminosity masking (mask-type: luminance, default per SVG spec)
  /// - Alpha masking (mask-type: alpha)
  /// - Edge feathering via blur filters
  /// - Proper rendering order for subgraph masking
  ///
  /// Returns true if masking was applied (caller should use provided callback).
  /// Returns false if no mask is present (caller should render normally).
  bool _applyAdvancedMask(
    ui.Canvas canvas,
    SvgNode node, {
    required Set<String> useStack,
    required void Function() paintContent,
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

    // Circular reference protection: check if we're already painting this mask
    final visitedMasks = _currentPaintingMasksStack ??= <String>{};
    if (visitedMasks.contains(maskId) ||
        visitedMasks.length >= _kMaxMaskPaintingRecursionDepth) {
      // Circular reference or max depth reached - paint content without mask
      paintContent();
      return true;
    }

    // Parse mask type and compute bounds
    final maskType = _parseMaskType(maskNode, node);
    final maskBounds = _computeMaskBounds(maskedNode: node, maskNode: maskNode);

    // Track mask animation state for cache invalidation
    String? animatedMaskCacheKey;
    if (hasAnimations) {
      final isAnimated = _maskContentIsAnimated(maskNode);
      _renderCache.maskAnimationState[maskId] = isAnimated;
      // Generate cache key for animated masks to enable content caching
      if (isAnimated) {
        animatedMaskCacheKey = _generateMaskCacheKey(maskNode, animationTime);
        // Store the cache key for potential mask image caching
        _renderCache.animatedMaskCacheKeys[maskId] = animatedMaskCacheKey;
      }
    }

    if (maskBounds == null ||
        maskBounds.width.abs() < _kMinBoundingBoxDimension ||
        maskBounds.height.abs() < _kMinBoundingBoxDimension) {
      // Empty mask bounds - nothing visible
      return true;
    }

    // Detect if mask content has blur (edge feathering)
    final hasFeathering = _maskContentHasFeathering(maskNode);

    // Expand bounds for feathering if needed
    final effectiveBounds = hasFeathering
        ? _expandMaskBoundsForFeathering(maskBounds, maskNode)
        : maskBounds;

    // Track this mask as being painted (circular reference protection)
    visitedMasks.add(maskId);

    try {
      // Apply layer-based masking
      _renderWithMaskComposition(
        canvas,
        node: node,
        maskNode: maskNode,
        maskType: maskType,
        maskBounds: effectiveBounds,
        hasFeathering: hasFeathering,
        useStack: useStack,
        paintContent: paintContent,
      );
    } finally {
      // Remove from visited set when done
      visitedMasks.remove(maskId);
      // Clear the stack if it's empty (reset for next paint cycle)
      if (visitedMasks.isEmpty) {
        _currentPaintingMasksStack = null;
      }
    }

    return true;
  }

  /// Renders content with mask composition using saveLayer.
  ///
  /// Implements proper compositing order:
  /// 1. Save layer for content
  /// 2. Paint content (may include filter effects)
  /// 3. Save layer with blend mode for mask
  /// 4. Paint mask content
  /// 5. Restore layers
  ///
  /// Supports nested mask intersection when masks are nested.
  void _renderWithMaskComposition(
    ui.Canvas canvas, {
    required SvgNode node,
    required SvgNode maskNode,
    required _SvgMaskType maskType,
    required ui.Rect maskBounds,
    required bool hasFeathering,
    required Set<String> useStack,
    required void Function() paintContent,
  }) {
    // Check for nested mask context and use intersection handling
    final parentContext = _currentMaskNestingContext;
    if (parentContext != null && parentContext.hasParentMask) {
      // Use nested mask intersection handling
      _applyNestedMaskWithIntersection(
        canvas,
        node,
        maskNode: maskNode,
        maskBounds: maskBounds,
        maskType: maskType,
        useStack: useStack,
        nestingContext: parentContext,
        paintContent: () {
          // Update context for children before painting
          final previousContext = _currentMaskNestingContext;
          _currentMaskNestingContext = parentContext.withChildMask(maskBounds);
          try {
            paintContent();
          } finally {
            _currentMaskNestingContext = previousContext;
          }
        },
      );
      return;
    }

    // Set up mask nesting context for children
    final previousContext = _currentMaskNestingContext;
    _currentMaskNestingContext = _MaskNestingContext(
      depth: 1,
      parentMaskBounds: maskBounds,
      hasParentMask: true,
    );

    try {
      // Save content layer - captures all painted content
      canvas.saveLayer(maskBounds, ui.Paint());

      // Paint the content (with any filters already applied)
      paintContent();

      // Create mask paint based on mask type
      // Use gradient-aware luminance paint when mask content contains gradients
      final ui.Paint maskPaint;
      if (maskType == _SvgMaskType.luminance) {
        maskPaint = _maskHasGradientContent(maskNode)
            ? _createLuminanceMaskPaintWithGradientSupport()
            : _createLuminanceMaskPaint();
      } else {
        maskPaint = _createAlphaMaskPaint();
      }

      // Save mask layer with proper blend mode
      canvas.saveLayer(maskBounds, maskPaint);

      // Paint mask content with proper coordinate system
      _paintMaskContentWithFeathering(
        canvas,
        maskNode: maskNode,
        maskedNode: node,
        hasFeathering: hasFeathering,
        useStack: useStack,
      );

      // Restore mask layer
      canvas.restore();

      // Restore content layer
      canvas.restore();
    } finally {
      // Restore previous context
      _currentMaskNestingContext = previousContext;
    }
  }

  /// Creates paint for alpha-based masking.
  ///
  /// Uses DstIn blend mode to composite content with mask alpha channel.
  ui.Paint _createAlphaMaskPaint() {
    return ui.Paint()..blendMode = ui.BlendMode.dstIn;
  }

  /// Checks if mask content includes feathering (blur filters).
  ///
  /// Edge feathering occurs when mask content has gaussian blur,
  /// gradient edges, or anti-aliased boundaries.
  bool _maskContentHasFeathering(SvgNode maskNode) {
    return _checkMaskContentForFeathering(maskNode);
  }

  /// Recursively checks mask content for blur filters.
  bool _checkMaskContentForFeathering(SvgNode node) {
    // Check for filter on this node
    final filterId = _getFilterId(node);
    if (filterId != null && filterId.isNotEmpty) {
      // Check if filter contains blur
      if (_filterContainsBlur(filterId)) {
        return true;
      }
    }

    // Check for opacity/gradient that creates soft edges
    final opacity = _getStyleOrAttributeValue(node, 'opacity');
    if (opacity != null) {
      final opacityValue = double.tryParse(opacity.toString());
      if (opacityValue != null && opacityValue < 1.0 && opacityValue > 0.0) {
        return true;
      }
    }

    // Check children recursively
    for (final child in node.children) {
      if (_checkMaskContentForFeathering(child)) {
        return true;
      }
    }

    return false;
  }

  /// Checks if a filter contains blur primitives.
  bool _filterContainsBlur(String filterId) {
    final filterNode = document.root.findById(filterId);
    if (filterNode == null) return false;

    for (final child in filterNode.children) {
      if (child.tagName == 'feGaussianBlur') {
        return true;
      }
    }
    return false;
  }

  /// Expands mask bounds to account for feathering/blur effect.
  ///
  /// Per SVG spec, gaussian blur extends beyond the source region.
  /// We expand bounds by the blur radius to capture feathered edges.
  ui.Rect _expandMaskBoundsForFeathering(ui.Rect bounds, SvgNode maskNode) {
    // Find maximum blur radius in mask content
    double maxBlurRadius = 0;
    _findMaxBlurRadius(maskNode, (radius) {
      if (radius > maxBlurRadius) {
        maxBlurRadius = radius;
      }
    });

    // Blur extends ~3 sigma beyond source
    final extension = maxBlurRadius * 3;
    if (extension <= 0) {
      return bounds;
    }

    return bounds.inflate(extension);
  }

  /// Recursively finds maximum blur radius in mask content.
  void _findMaxBlurRadius(SvgNode node, void Function(double) onBlurFound) {
    final filterId = _getFilterId(node);
    if (filterId != null && filterId.isNotEmpty) {
      final filterNode = document.root.findById(filterId);
      if (filterNode != null) {
        for (final child in filterNode.children) {
          if (child.tagName == 'feGaussianBlur') {
            final stdDev = child.getAttributeValue('stdDeviation');
            if (stdDev != null) {
              final parts = stdDev.toString().trim().split(RegExp(r'[\s,]+'));
              for (final part in parts) {
                final value = double.tryParse(part);
                if (value != null) {
                  onBlurFound(value);
                }
              }
            }
          }
        }
      }
    }

    for (final child in node.children) {
      _findMaxBlurRadius(child, onBlurFound);
    }
  }

  /// Paints mask content with feathering support.
  ///
  /// When mask content has blur filters, they create soft edges (feathering).
  /// This method ensures blur effects are properly applied to mask content.
  void _paintMaskContentWithFeathering(
    ui.Canvas canvas, {
    required SvgNode maskNode,
    required SvgNode maskedNode,
    required bool hasFeathering,
    required Set<String> useStack,
  }) {
    // Apply maskContentUnits transform if needed
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
        // Handle very small dimensions safely
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

    // Paint mask children with filter support
    for (final child in maskNode.children) {
      _paintNode(canvas, child, useStack: useStack);
    }

    if (contentTransform != null) {
      canvas.restore();
    }
  }

  /// Applies subgraph masking for elements with both filter and mask.
  ///
  /// Per CSS Compositing spec, when an element has both filter and mask:
  /// 1. Render element content
  /// 2. Apply filter to rendered content
  /// 3. Apply mask to filtered result
  ///
  /// This ensures masks operate on post-filter graphics.
  // ignore: unused_element
  bool _applySubgraphMaskWithFilter(
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
      return true;
    }

    // Render with mask applied after filter processing
    _renderSubgraphWithMask(
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

  /// Generates a cache key for animated mask content.
  ///
  /// Used to invalidate mask caches when mask content animates.
  String _generateMaskCacheKey(SvgNode maskNode, double? animationTime) {
    final buffer = StringBuffer();
    buffer.write(maskNode.getAttributeValue('id') ?? 'mask');
    buffer.write('_');
    buffer.write(animationTime?.toStringAsFixed(3) ?? '0');

    // Include animated attribute values in key
    _appendAnimatedAttributesToCacheKey(maskNode, buffer);

    return buffer.toString();
  }

  /// Recursively appends animated attribute values to cache key.
  void _appendAnimatedAttributesToCacheKey(SvgNode node, StringBuffer buffer) {
    // Check for animated attributes on this node
    for (final child in node.children) {
      if (child.tagName == 'animate' || child.tagName == 'set') {
        final attrName = child.getAttributeValue('attributeName');
        if (attrName != null) {
          buffer.write('_');
          buffer.write(attrName.toString());
          // Get current animated value
          final currentValue = node.getAttributeValue(attrName.toString());
          if (currentValue != null) {
            buffer.write(':');
            buffer.write(currentValue.toString().hashCode);
          }
        }
      }
    }

    // Recurse into children
    for (final child in node.children) {
      if (child.tagName != 'animate' && child.tagName != 'set') {
        _appendAnimatedAttributesToCacheKey(child, buffer);
      }
    }
  }

  /// Checks if mask content is animated and needs cache invalidation.
  bool _maskContentIsAnimated(SvgNode maskNode) {
    return _checkMaskContentForAnimations(maskNode);
  }

  /// Recursively checks mask content for SMIL animations.
  bool _checkMaskContentForAnimations(SvgNode node) {
    // Check for animation children on this node
    for (final child in node.children) {
      switch (child.tagName) {
        case 'animate':
        case 'animateTransform':
        case 'animateMotion':
        case 'animateColor':
        case 'set':
          return true;
      }
    }

    // Check children recursively
    for (final child in node.children) {
      if (_checkMaskContentForAnimations(child)) {
        return true;
      }
    }

    return false;
  }
}
