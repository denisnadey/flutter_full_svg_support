part of 'animated_svg_painter.dart';

/// Extension for painting <use> elements and their referenced content.
///
/// This extension handles:
/// - Basic use element rendering with x/y translation
/// - Symbol and SVG element references with viewBox transforms
/// - Use element within clip-path and mask definitions
/// - CSS cascade through use shadow boundaries
/// - Nested use element chains (up to _kMaxUseRecursionDepth levels)
extension AnimatedSvgPainterUseExtension on AnimatedSvgPainter {
  bool _wouldCreateParentCycle({
    required SvgNode parentCandidate,
    required SvgNode childCandidate,
  }) {
    if (identical(parentCandidate, childCandidate)) {
      return true;
    }

    final visited = <SvgNode>{};
    SvgNode? current = parentCandidate;
    var depth = 0;
    while (current != null && depth < _kMaxUseRecursionDepth * 4) {
      if (!visited.add(current)) {
        return true;
      }
      if (identical(current, childCandidate)) {
        return true;
      }
      current = current.parent;
      depth++;
    }
    return false;
  }

  /// Checks if the current rendering context is within a clip-path definition.
  ///
  /// This affects how coordinates are interpreted when clipPathUnits="objectBoundingBox".
  // ignore: unused_element
  bool _isInClipPathContext(SvgNode node) {
    SvgNode? current = node.parent;
    while (current != null) {
      if (current.tagName == 'clipPath') {
        return true;
      }
      current = current.parent;
    }
    return false;
  }

  /// Checks if the current rendering context is within a mask definition.
  ///
  /// This affects how coordinates are interpreted when maskContentUnits="objectBoundingBox".
  // ignore: unused_element
  bool _isInMaskContext(SvgNode node) {
    SvgNode? current = node.parent;
    while (current != null) {
      if (current.tagName == 'mask') {
        return true;
      }
      current = current.parent;
    }
    return false;
  }

  /// Gets the clipPathUnits value from the nearest ancestor clipPath.
  ///
  /// Returns 'userSpaceOnUse' (default) or 'objectBoundingBox'.
  // ignore: unused_element
  String _getAncestorClipPathUnits(SvgNode node) {
    SvgNode? current = node.parent;
    while (current != null) {
      if (current.tagName == 'clipPath') {
        final units = current.getAttributeValue('clipPathUnits')?.toString();
        if (units != null && units.isNotEmpty) {
          return units.trim().toLowerCase();
        }
        return 'userspaceonuse'; // Default
      }
      current = current.parent;
    }
    return 'userspaceonuse';
  }

  /// Gets the maskContentUnits value from the nearest ancestor mask.
  ///
  /// Returns 'userSpaceOnUse' (default) or 'objectBoundingBox'.
  // ignore: unused_element
  String _getAncestorMaskContentUnits(SvgNode node) {
    SvgNode? current = node.parent;
    while (current != null) {
      if (current.tagName == 'mask') {
        final units = current.getAttributeValue('maskContentUnits')?.toString();
        if (units != null && units.isNotEmpty) {
          return units.trim().toLowerCase();
        }
        return 'userspaceonuse'; // Default
      }
      current = current.parent;
    }
    return 'userspaceonuse';
  }

  void _paintUse(
    ui.Canvas canvas,
    SvgNode node, {
    required Set<String> useStack,
    _UseInheritanceContext? useContext,
  }) {
    final hrefId = _extractHrefId(node);
    if (hrefId == null || hrefId.isEmpty) {
      return;
    }
    if (useStack.contains(hrefId)) {
      return;
    }
    if (useContext != null && useContext.hasCircularReference(hrefId)) {
      return;
    }
    if (useStack.length >= _kMaxUseRecursionDepth) {
      return;
    }
    final referenced = document.root.findById(hrefId);
    if (referenced == null || !_isUseReferenceAllowedTag(referenced.tagName)) {
      return;
    }

    // Check display:none on the use element itself
    final useDisplay = _getStyleOrAttributeValue(node, 'display');
    if (useDisplay != null && useDisplay.toString().toLowerCase() == 'none') {
      return;
    }

    // Also check display:none from parent use context
    if (useContext != null && useContext.isDisplayNone()) {
      return;
    }

    final x = _getNumber(node, 'x') ?? 0.0;
    final y = _getNumber(node, 'y') ?? 0.0;
    canvas.save();
    final transformStr = node.getAttributeValue('transform')?.toString();
    if (transformStr != null && transformStr.isNotEmpty) {
      final transformMatrix = _buildTransformMatrixFromValue(transformStr);
      if (transformMatrix != null) {
        canvas.transform(transformMatrix.storage);
      }
    }
    canvas.translate(x, y);
    final currentUseContext = _UseInheritanceContext(
      useNode: node,
      parentContext: useContext,
      cssRules: _currentDocumentCssRules ?? useContext?.cssRules,
      shadowRootId: hrefId,
    );

    // Check visibility from use context - if hidden, skip rendering
    // but respect visibility:visible on referenced content that overrides
    final useVisibility = _getStyleOrAttributeValue(node, 'visibility');
    final isUseHidden =
        useVisibility != null &&
        (useVisibility.toString().toLowerCase() == 'hidden' ||
            useVisibility.toString().toLowerCase() == 'collapse');
    final refVisibility = _getStyleOrAttributeValue(referenced, 'visibility');
    final refOverridesHidden =
        refVisibility != null &&
        refVisibility.toString().toLowerCase() == 'visible';

    // If use is hidden and ref doesn't override, skip rendering
    if (isUseHidden && !refOverridesHidden) {
      canvas.restore();
      return;
    }

    final opacityValue = node.getAttributeValue('opacity');
    final opacity = opacityValue != null
        ? (double.tryParse(opacityValue.toString()) ?? 1.0).clamp(0.0, 1.0)
        : 1.0;
    if (opacity < 1.0) {
      final layerPaint = ui.Paint()
        ..color = ui.Color.fromARGB((opacity * 255).round(), 255, 255, 255);
      canvas.saveLayer(null, layerPaint);
    }
    final filterPasses = _resolveFilterPassesImpl(this, node);
    final nodeBoundsForFilterPasses = _getNodeBounds(node);

    ui.Rect? filterRegionClip;
    final filterId = _getFilterId(node);
    if (filterId != null && document.filters != null) {
      final region = document.filters!.getFilterRegion(filterId);
      if (nodeBoundsForFilterPasses.width > 0 &&
          nodeBoundsForFilterPasses.height > 0) {
        filterRegionClip = region.computeRect(nodeBoundsForFilterPasses);
      }
    }

    void paintReferencedContent(
      ui.ImageFilter? imageFilter,
      ui.ColorFilter? colorFilter,
      ui.BlendMode? blendMode,
    ) {
      if (imageFilter != null || colorFilter != null || blendMode != null) {
        final layerPaint = ui.Paint();
        if (imageFilter != null) {
          layerPaint.imageFilter = imageFilter;
        }
        if (colorFilter != null) {
          layerPaint.colorFilter = colorFilter;
        }
        if (blendMode != null) {
          layerPaint.blendMode = blendMode;
        }
        canvas.saveLayer(null, layerPaint);
      }

      final previousParent = referenced.parent;
      if (_wouldCreateParentCycle(
        parentCandidate: node,
        childCandidate: referenced,
      )) {
        return;
      }
      referenced.parent = node;
      try {
        final nextUseStack = <String>{...useStack, hrefId};
        if (referenced.tagName == 'symbol') {
          _paintSymbolReference(
            canvas,
            useNode: node,
            symbolNode: referenced,
            useStack: nextUseStack,
            useContext: currentUseContext,
          );
        } else if (referenced.tagName == 'svg') {
          _paintSvgUseReference(
            canvas,
            useNode: node,
            svgNode: referenced,
            useStack: nextUseStack,
            useContext: currentUseContext,
          );
        } else {
          _paintNodeWithUseContext(
            canvas,
            referenced,
            useStack: nextUseStack,
            useContext: currentUseContext,
          );
        }
      } finally {
        referenced.parent = previousParent;
      }

      if (imageFilter != null || colorFilter != null || blendMode != null) {
        canvas.restore();
      }
    }

    if (_isIdentityOnlyFilterPasses(filterPasses)) {
      paintReferencedContent(null, null, null);
    } else {
      _paintWithFilterPassesImpl(
        this,
        canvas,
        filterPasses,
        paintReferencedContent,
        targetNodeBounds: nodeBoundsForFilterPasses,
        filterRegionClip: filterRegionClip,
      );
    }

    if (opacity < 1.0) {
      canvas.restore();
    }
    canvas.restore();
  }

  void _paintSymbolReference(
    ui.Canvas canvas, {
    required SvgNode useNode,
    required SvgNode symbolNode,
    required Set<String> useStack,
    _UseInheritanceContext? useContext,
  }) {
    final viewportTransform = _resolveUseViewportTransform(
      useNode: useNode,
      referenceNode: symbolNode,
    );
    if (viewportTransform != null) {
      if (viewportTransform.clipRect != null) {
        canvas.clipRect(viewportTransform.clipRect!, doAntiAlias: true);
      }
      canvas.transform(viewportTransform.matrix.storage);
    } else {
      _applySymbolOverflowClipping(canvas, useNode, symbolNode);
    }
    for (final child in symbolNode.children) {
      _paintNodeWithUseContext(
        canvas,
        child,
        useStack: useStack,
        useContext: useContext,
      );
    }
  }

  void _applySymbolOverflowClipping(
    ui.Canvas canvas,
    SvgNode useNode,
    SvgNode symbolNode,
  ) {
    final overflow = _getInheritedString(symbolNode, 'overflow')?.toLowerCase();
    if (overflow == 'visible') {
      return;
    }
    final useWidth = _getNumber(useNode, 'width');
    final useHeight = _getNumber(useNode, 'height');
    if (useWidth != null &&
        useHeight != null &&
        useWidth > 0 &&
        useHeight > 0) {
      canvas.clipRect(
        ui.Rect.fromLTWH(0, 0, useWidth, useHeight),
        doAntiAlias: true,
      );
      return;
    }
    final viewBox = _parseViewBox(_getString(symbolNode, 'viewBox'));
    if (viewBox != null && viewBox.width > 0 && viewBox.height > 0) {
      canvas.clipRect(viewBox, doAntiAlias: true);
    }
  }

  void _paintSvgUseReference(
    ui.Canvas canvas, {
    required SvgNode useNode,
    required SvgNode svgNode,
    required Set<String> useStack,
    _UseInheritanceContext? useContext,
  }) {
    final viewportTransform = _resolveUseViewportTransform(
      useNode: useNode,
      referenceNode: svgNode,
    );
    if (viewportTransform != null) {
      if (viewportTransform.clipRect != null) {
        canvas.clipRect(viewportTransform.clipRect!, doAntiAlias: true);
      }
      canvas.transform(viewportTransform.matrix.storage);
    }
    _paintNodeWithUseContext(
      canvas,
      svgNode,
      useStack: useStack,
      useContext: useContext,
    );
  }

  void _paintNodeWithUseContext(
    ui.Canvas canvas,
    SvgNode node, {
    required Set<String> useStack,
    _UseInheritanceContext? useContext,
  }) {
    _paintNodeImplWithUseContext(
      this,
      canvas,
      node,
      useStack: useStack,
      useContext: useContext,
    );
  }

  void _paintSwitch(
    ui.Canvas canvas,
    SvgNode switchNode, {
    required Set<String> useStack,
  }) {
    final activeChild = resolveActiveSwitchChild(switchNode);
    if (activeChild == null) {
      return;
    }
    _paintNode(canvas, activeChild, useStack: useStack);
  }

  bool _shouldPaintChildren(SvgNode node) {
    switch (node.tagName) {
      case 'defs':
      case 'symbol':
      case 'linearGradient':
      case 'radialGradient':
      case 'stop':
      case 'clipPath':
      case 'mask':
      case 'pattern':
      case 'filter':
      case 'marker':
      case 'use':
      case 'text':
      case 'tspan':
      case 'textPath':
      case 'image':
      case 'switch':
        return false;
      case 'foreignObject':
        if (!_shouldRenderForeignObject(node)) {
          return false;
        }
        final width = _getNumber(node, 'width') ?? 0.0;
        final height = _getNumber(node, 'height') ?? 0.0;
        return width > 0 && height > 0;
      default:
        return true;
    }
  }
}
