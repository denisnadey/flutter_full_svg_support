part of 'animated_svg_painter.dart';

/// Internal use context being passed during rendering.
/// Used to track CSS inheritance across `<use>` boundaries.
_UseInheritanceContext? _currentUseContext;

void _paintNodeImpl(
  AnimatedSvgPainter painter,
  ui.Canvas canvas,
  SvgNode node, {
  Set<String>? useStack,
  SvgNode? foreignObjectParent,
}) {
  _paintNodeImplWithUseContext(
    painter,
    canvas,
    node,
    useStack: useStack,
    foreignObjectParent: foreignObjectParent,
    useContext: null,
  );
}

/// Paints a node with use inheritance context for proper CSS cascade.
/// This is the core rendering function that handles CSS property inheritance
/// from `<use>` elements to their referenced content.
void _paintNodeImplWithUseContext(
  AnimatedSvgPainter painter,
  ui.Canvas canvas,
  SvgNode node, {
  Set<String>? useStack,
  SvgNode? foreignObjectParent,
  _UseInheritanceContext? useContext,
}) {
  // Store use context for attribute resolution
  final previousUseContext = _currentUseContext;
  final previousUseContextLookup = useContextCustomPropertyLookup;

  if (useContext != null) {
    _currentUseContext = useContext;
    // Set up CSS custom property lookup through use context.
    // This enables var(--custom-property) to resolve from <use> elements.
    useContextCustomPropertyLookup = (name) =>
        useContext.getCustomProperty(name);
  }
  final display = painter
      ._getStyleOrAttributeValue(node, 'display')
      ?.toString()
      .trim();
  if (display?.toLowerCase() == 'none') {
    _currentUseContext = previousUseContext;
    useContextCustomPropertyLookup = previousUseContextLookup;
    return;
  }

  final visibility = painter._getInheritedString(node, 'visibility');
  final normalizedVisibility = visibility?.toLowerCase();
  final isHidden =
      normalizedVisibility == 'hidden' || normalizedVisibility == 'collapse';

  final currentUseStack = useStack ?? <String>{};
  canvas.save();

  // Apply transform if present.
  painter._applyTransform(canvas, node);

  // Baseline foreignObject viewport: offset + clip children to the region.
  painter._applyForeignObjectViewport(canvas, node);

  // Apply nested SVG viewport transform within foreignObject
  painter._applyNestedSvgViewportInForeignObject(
    canvas,
    node,
    foreignObjectParent,
  );

  // Apply nested SVG viewport transform for regular SVG-in-SVG nesting.
  painter._applyNestedSvgViewport(canvas, node, foreignObjectParent);

  // Apply clipPath if present.
  painter._applyClipPath(canvas, node, useStack: currentUseStack);

  // Check if node has a mask - use advanced layer-based masking
  final hasMaskApplied = _applyAdvancedMaskWrapper(
    painter,
    canvas,
    node,
    currentUseStack: currentUseStack,
    isHidden: isHidden,
    foreignObjectParent: foreignObjectParent,
    useContext: useContext,
  );

  // If mask was applied via layer, content was painted in the callback
  // Skip normal rendering
  if (hasMaskApplied) {
    // Restore previous use context and CSS variable lookup
    _currentUseContext = previousUseContext;
    useContextCustomPropertyLookup = previousUseContextLookup;
    canvas.restore();
    return;
  }

  // No mask or fallback to basic masking - continue normal rendering
  // Apply basic geometry mask as fallback
  painter._applyMask(canvas, node, useStack: currentUseStack);

  final filterPasses = _resolveFilterPassesImpl(painter, node);
  final nodeBoundsForFilterPasses = painter._getNodeBounds(node);

  // Compute filter region clip rect for output clipping.
  // Per SVG spec, filter output is clipped to the filter region.
  ui.Rect? filterRegionClip;
  final filterId = painter._getFilterId(node);
  if (filterId != null && painter.document.filters != null) {
    final region = painter.document.filters!.getFilterRegion(filterId);
    if (nodeBoundsForFilterPasses.width > 0 &&
        nodeBoundsForFilterPasses.height > 0) {
      filterRegionClip = region.computeRect(nodeBoundsForFilterPasses);
    }
  }

  // Paint the node itself depending on its type.
  if (!isHidden) {
    switch (node.tagName) {
      case 'rect':
        _paintWithFilterPassesImpl(
          painter,
          canvas,
          filterPasses,
          (imageFilter, colorFilter, blendMode) => painter._paintRect(
            canvas,
            node,
            imageFilter: imageFilter,
            colorFilter: colorFilter,
            blendMode: blendMode,
          ),
          targetNodeBounds: nodeBoundsForFilterPasses,
          filterRegionClip: filterRegionClip,
        );
        break;
      case 'circle':
        _paintWithFilterPassesImpl(
          painter,
          canvas,
          filterPasses,
          (imageFilter, colorFilter, blendMode) => painter._paintCircle(
            canvas,
            node,
            imageFilter: imageFilter,
            colorFilter: colorFilter,
            blendMode: blendMode,
          ),
          targetNodeBounds: nodeBoundsForFilterPasses,
          filterRegionClip: filterRegionClip,
        );
        break;
      case 'ellipse':
        _paintWithFilterPassesImpl(
          painter,
          canvas,
          filterPasses,
          (imageFilter, colorFilter, blendMode) => painter._paintEllipse(
            canvas,
            node,
            imageFilter: imageFilter,
            colorFilter: colorFilter,
            blendMode: blendMode,
          ),
          targetNodeBounds: nodeBoundsForFilterPasses,
          filterRegionClip: filterRegionClip,
        );
        break;
      case 'path':
        _paintWithFilterPassesImpl(
          painter,
          canvas,
          filterPasses,
          (imageFilter, colorFilter, blendMode) => painter._paintPath(
            canvas,
            node,
            imageFilter: imageFilter,
            colorFilter: colorFilter,
            blendMode: blendMode,
          ),
          targetNodeBounds: nodeBoundsForFilterPasses,
          filterRegionClip: filterRegionClip,
        );
        break;
      case 'polygon':
        _paintWithFilterPassesImpl(
          painter,
          canvas,
          filterPasses,
          (imageFilter, colorFilter, blendMode) => painter._paintPolygon(
            canvas,
            node,
            imageFilter: imageFilter,
            colorFilter: colorFilter,
            blendMode: blendMode,
          ),
          targetNodeBounds: nodeBoundsForFilterPasses,
          filterRegionClip: filterRegionClip,
        );
        break;
      case 'polyline':
        _paintWithFilterPassesImpl(
          painter,
          canvas,
          filterPasses,
          (imageFilter, colorFilter, blendMode) => painter._paintPolyline(
            canvas,
            node,
            imageFilter: imageFilter,
            colorFilter: colorFilter,
            blendMode: blendMode,
          ),
          targetNodeBounds: nodeBoundsForFilterPasses,
          filterRegionClip: filterRegionClip,
        );
        break;
      case 'line':
        _paintWithFilterPassesImpl(
          painter,
          canvas,
          filterPasses,
          (imageFilter, colorFilter, blendMode) => painter._paintLine(
            canvas,
            node,
            imageFilter: imageFilter,
            colorFilter: colorFilter,
            blendMode: blendMode,
          ),
          targetNodeBounds: nodeBoundsForFilterPasses,
          filterRegionClip: filterRegionClip,
        );
        break;
      case 'image':
        _paintWithFilterPassesImpl(
          painter,
          canvas,
          filterPasses,
          (imageFilter, colorFilter, blendMode) => painter._paintImage(
            canvas,
            node,
            imageFilter: imageFilter,
            colorFilter: colorFilter,
            blendMode: blendMode,
          ),
          targetNodeBounds: nodeBoundsForFilterPasses,
          filterRegionClip: filterRegionClip,
          isImageNode: true,
        );
        break;
      case 'text':
        _paintWithFilterPassesImpl(
          painter,
          canvas,
          filterPasses,
          (imageFilter, colorFilter, blendMode) => painter._paintText(
            canvas,
            node,
            imageFilter: imageFilter,
            colorFilter: colorFilter,
            blendMode: blendMode,
          ),
          targetNodeBounds: nodeBoundsForFilterPasses,
          filterRegionClip: filterRegionClip,
        );
        break;
      case 'tspan':
        // Rendered from the parent <text> pass.
        break;
      case 'textPath':
        // Rendered from the parent <text> pass.
        break;
      case 'use':
        painter._paintUse(
          canvas,
          node,
          useStack: currentUseStack,
          useContext: useContext,
        );
        break;
      case 'a':
      case 'g':
      case 'svg':
      case 'foreignObject':
        // Check requiredExtensions for foreignObject - skip if not supported
        if (node.tagName == 'foreignObject' &&
            !painter._shouldRenderForeignObject(node)) {
          _currentUseContext = previousUseContext;
          useContextCustomPropertyLookup = previousUseContextLookup;
          canvas.restore();
          return;
        }
        // Groups apply saveLayer for opacity compositing if needed.
        // Returns true if children were painted in the layer.
        // Determine the foreignObjectParent context for the group
        final SvgNode? groupFoParent;
        if (node.tagName == 'foreignObject') {
          groupFoParent = node;
        } else if (node.tagName == 'svg') {
          groupFoParent = null;
        } else {
          groupFoParent = foreignObjectParent;
        }
        if (_paintGroupWithOpacity(
          painter,
          canvas,
          node,
          currentUseStack,
          filterPasses: filterPasses,
          foreignObjectParent: groupFoParent,
          useContext: useContext,
        )) {
          // Restore previous use context and CSS variable lookup
          _currentUseContext = previousUseContext;
          useContextCustomPropertyLookup = previousUseContextLookup;
          canvas.restore();
          return;
        }
        break;
      case 'switch':
        painter._paintSwitch(canvas, node, useStack: currentUseStack);
        break;
      default:
        // Ignore unsupported elements (animate, text, etc.).
        break;
    }
  }

  // Recursively paint children.
  if (painter._shouldPaintChildren(node)) {
    // Determine if this node establishes a foreignObject context for children
    // - foreignObject: sets new FO context for direct children
    // - svg: resets FO context (SVG establishes new viewport, not affected by FO)
    // - other elements: preserve FO context from parent
    final SvgNode? foParent;
    if (node.tagName == 'foreignObject') {
      foParent = node;
    } else if (node.tagName == 'svg') {
      foParent = null; // SVG resets the FO context
    } else {
      foParent = foreignObjectParent;
    }
    for (final child in node.children) {
      _paintNodeImplWithUseContext(
        painter,
        canvas,
        child,
        useStack: currentUseStack,
        foreignObjectParent: foParent,
        useContext: useContext,
      );
    }
  }

  // Restore previous use context and CSS variable lookup
  _currentUseContext = previousUseContext;
  useContextCustomPropertyLookup = previousUseContextLookup;

  canvas.restore();
}

/// Paints group children with proper opacity, isolation, and
/// enable-background compositing.
///
/// Uses saveLayer when the group requires compositing isolation:
/// - opacity < 1.0: composite children with reduced opacity
/// - isolation: isolate: create stacking context boundary
/// - enable-background: new: create background capture context
/// - mix-blend-mode on group: implicit stacking context
///
/// Returns true if children were painted (caller should skip normal recursion).
bool _paintGroupWithOpacity(
  AnimatedSvgPainter painter,
  ui.Canvas canvas,
  SvgNode node,
  Set<String> useStack, {
  List<SvgFilterPaintPass>? filterPasses,
  SvgNode? foreignObjectParent,
  _UseInheritanceContext? useContext,
}) {
  // Check for group-level opacity (not inherited)
  final opacityValue = node.getAttributeValue('opacity');
  final opacity = opacityValue != null
      ? (double.tryParse(opacityValue.toString()) ?? 1.0).clamp(0.0, 1.0)
      : 1.0;

  // Check for isolation: isolate CSS property.
  // Per CSS Compositing spec, isolation: isolate creates a new stacking
  // context that prevents mix-blend-mode from compositing with content
  // behind the isolated group.
  final isolationValue = painter
      ._getStyleOrAttributeValue(node, 'isolation')
      ?.toString()
      .trim()
      .toLowerCase();
  final isIsolated = isolationValue == 'isolate';

  // Check for enable-background: new.
  // Per SVG 1.1 spec, enable-background: new on a container element
  // establishes a new background image context for child filter primitives
  // that reference BackgroundImage/BackgroundAlpha.
  final enableBgValue = painter
      ._getStyleOrAttributeValue(node, 'enable-background')
      ?.toString()
      .trim()
      .toLowerCase();
  final hasEnableBackground =
      enableBgValue != null && enableBgValue.startsWith('new');

  // Check for mix-blend-mode on the group itself.
  // Per CSS spec, any non-normal mix-blend-mode creates implicit isolation.
  final groupBlendMode = painter._resolveMixBlendMode(node);
  final hasGroupBlendMode = groupBlendMode != null;

  // Find the first filter pass with a non-trivial image or color filter.
  SvgFilterPaintPass? filterPass;
  if (filterPasses != null) {
    for (final p in filterPasses) {
      if (p.imageFilter != null || p.colorFilter != null) {
        filterPass = p;
        break;
      }
    }
  }
  final hasFilter = filterPass != null;

  // Determine if saveLayer is needed for compositing
  final needsLayer = opacity < 1.0 ||
      isIsolated ||
      hasEnableBackground ||
      hasGroupBlendMode ||
      hasFilter;

  // If no compositing needed, children painted normally by the
  // recursive call after this switch statement.
  if (!needsLayer) {
    return false;
  }

  // Build the layer paint with opacity, blend mode, and optional filter.
  final layerPaint = ui.Paint()
    ..color = ui.Color.fromARGB((opacity * 255).round(), 255, 255, 255);
  if (hasGroupBlendMode) {
    layerPaint.blendMode = groupBlendMode;
  }
  if (hasFilter) {
    if (filterPass.imageFilter != null) {
      layerPaint.imageFilter = filterPass.imageFilter;
    } else if (filterPass.colorFilter != null) {
      layerPaint.colorFilter = filterPass.colorFilter;
    }
  }

  canvas.saveLayer(null, layerPaint);

  // Push background context for enable-background: new.
  // This makes BackgroundImage/BackgroundAlpha available to child filters.
  if (hasEnableBackground && painter.document.filters != null) {
    painter.document.filters!.pushBackgroundContext();
  }

  // Paint children into the layer
  if (painter._shouldPaintChildren(node)) {
    // Determine if this node establishes a foreignObject context for children
    // - foreignObject: sets new FO context for direct children
    // - svg: resets FO context (SVG establishes new viewport)
    // - other elements: preserve FO context from parent
    final SvgNode? foParent;
    if (node.tagName == 'foreignObject') {
      foParent = node;
    } else if (node.tagName == 'svg') {
      foParent = null;
    } else {
      foParent = foreignObjectParent;
    }
    for (final child in node.children) {
      _paintNodeImplWithUseContext(
        painter,
        canvas,
        child,
        useStack: useStack,
        foreignObjectParent: foParent,
        useContext: useContext,
      );
    }
  }

  // Pop background context if it was pushed.
  if (hasEnableBackground && painter.document.filters != null) {
    painter.document.filters!.popBackgroundContext();
  }

  canvas.restore();
  return true;
}

bool _paintLightingPassImpl(
  AnimatedSvgPainter painter,
  ui.Canvas canvas,
  SvgFilterPaintPass pass, {
  required ui.Rect targetNodeBounds,
  ui.Rect? filterRegionClip,
}) {
  final kind = switch (pass) {
    SvgDiffuseLightingPaintPass() => 'diffuse',
    SvgSpecularLightingPaintPass() => 'specular',
    _ => null,
  };
  if (kind == null) {
    return false;
  }

  final outputRect = filterRegionClip ?? targetNodeBounds;
  final width = outputRect.width.round();
  final height = outputRect.height.round();
  if (width <= 0 || height <= 0) {
    return false;
  }

  final filterId = switch (pass) {
    SvgDiffuseLightingPaintPass() => pass.lightingFilter.id,
    SvgSpecularLightingPaintPass() => pass.lightingFilter.id,
    _ => '',
  };
  if (filterId.isEmpty) {
    return false;
  }

  final key = '$filterId|${width}x$height|$kind';
  final image = painter.lightingImagesByFilterKey[key];
  if (image == null) {
    return false;
  }

  final paint = ui.Paint()..isAntiAlias = true;
  if (pass.imageFilter != null) {
    paint.imageFilter = pass.imageFilter;
  }
  if (pass.colorFilter != null) {
    paint.colorFilter = pass.colorFilter;
  }
  if (pass.blendMode != null) {
    paint.blendMode = pass.blendMode!;
  }
  final srcRect = ui.Rect.fromLTWH(
    0,
    0,
    image.width.toDouble(),
    image.height.toDouble(),
  );
  canvas.drawImageRect(image, srcRect, outputRect, paint);
  return true;
}

bool _paintTurbulencePassImpl(
  ui.Canvas canvas,
  SvgTurbulencePaintPass pass, {
  required ui.Rect targetNodeBounds,
  ui.Rect? filterRegionClip,
}) {
  final outputRect = filterRegionClip ?? targetNodeBounds;
  final width = outputRect.width.round();
  final height = outputRect.height.round();
  if (width <= 0 || height <= 0) {
    return false;
  }

  final pixels = TurbulenceTileRenderer.generateTiled(
    width: width,
    height: height,
    turbulence: pass.turbulenceFilter,
  );
  if (pixels.isEmpty) {
    return false;
  }

  final stepX = outputRect.width / width;
  final stepY = outputRect.height / height;
  final paint = ui.Paint()..isAntiAlias = false;

  for (int y = 0; y < height; y++) {
    final top = outputRect.top + y * stepY;
    for (int x = 0; x < width; x++) {
      final idx = (y * width + x) * 4;
      final alpha = pixels[idx + 3];
      if (alpha == 0) {
        continue;
      }

      paint.color = ui.Color.fromARGB(
        alpha,
        pixels[idx],
        pixels[idx + 1],
        pixels[idx + 2],
      );
      canvas.drawRect(
        ui.Rect.fromLTWH(
          outputRect.left + x * stepX,
          top,
          stepX + 0.01,
          stepY + 0.01,
        ),
        paint,
      );
    }
  }

  return true;
}

List<SvgFilterPaintPass> _resolveFilterPassesImpl(
  AnimatedSvgPainter painter,
  SvgNode node,
) {
  final filterId = painter._getFilterId(node);
  if (filterId == null || painter.document.filters == null) {
    return const <SvgFilterPaintPass>[SvgFilterPaintPass.identity];
  }

  // For unresolved/empty filter definitions (including existing <filter>
  // elements with zero primitives), render transparent output.
  if (!painter.document.filters!.hasFilter(filterId)) {
    return const <SvgFilterPaintPass>[];
  }

  // Sync animated attribute values from DOM nodes to filter objects
  // before resolving paint passes. This ensures that SMIL animations
  // targeting filter primitive attributes (stdDeviation, dx, dy, etc.)
  // are reflected in the rendered filter output.
  _syncFilterAnimatedValues(painter.document.filters!, filterId);

  final passes = painter.document.filters!.resolvePaintPasses(
    filterId,
    sourceContext: _buildFilterSourceContextImpl(painter, node),
  );
  if (_isIdentityOnlyFilterPasses(passes)) {
    final primitives = painter.document.filters!.getAllById(filterId);
    if (primitives.length == 1 &&
        primitives.single is SvgDisplacementMapFilter) {
      final displacement = primitives.single as SvgDisplacementMapFilter;
      final input2Ref = displacement.input2?.trim();
      final hasValidInput2 =
          input2Ref != null &&
          input2Ref.isNotEmpty &&
          input2Ref.toLowerCase() != 'none';
      if (displacement.scale.abs() > 0.000001 && hasValidInput2) {
        return <SvgFilterPaintPass>[
          SvgDisplacementMapPaintPass(displacementFilter: displacement),
        ];
      }
    }
  }
  if (passes.isEmpty) {
    return const <SvgFilterPaintPass>[SvgFilterPaintPass.identity];
  }
  return passes;
}

bool _isIdentityOnlyFilterPasses(List<SvgFilterPaintPass> passes) {
  if (passes.length != 1) {
    return false;
  }
  final pass = passes.single;
  return pass.runtimeType == SvgFilterPaintPass &&
      pass.imageFilter == null &&
      pass.colorFilter == null &&
      pass.blendMode == null &&
      pass.offset == ui.Offset.zero;
}

/// Syncs animated attribute values from source SvgNodes to SvgFilter objects.
///
/// When SMIL animations target attributes on filter primitive elements
/// (e.g. `<animate attributeName="stdDeviation">` inside `<feGaussianBlur>`),
/// the animation updates the SvgNode's animated attribute, but the SvgFilter
/// object retains its static parse-time value. This method bridges the gap
/// by reading animated values from the source nodes and updating the filter
/// objects' mutable fields.
void _syncFilterAnimatedValues(SvgFilters filters, String filterId) {
  final primitives = filters.getAllById(filterId);
  for (final primitive in primitives) {
    final sourceNode = primitive.sourceElement;
    if (sourceNode == null || sourceNode is! SvgNode) continue;

    if (primitive is SvgGaussianBlurFilter) {
      _syncGaussianBlurValues(primitive, sourceNode);
    } else if (primitive is SvgOffsetFilter) {
      _syncOffsetValues(primitive, sourceNode);
    } else if (primitive is SvgDropShadowFilter) {
      _syncDropShadowValues(primitive, sourceNode);
    } else if (primitive is SvgColorMatrixFilter) {
      _syncColorMatrixValues(primitive, sourceNode);
    } else if (primitive is SvgComponentTransferFilter) {
      _syncComponentTransferValues(primitive, sourceNode);
    }
  }
}

void _syncGaussianBlurValues(SvgGaussianBlurFilter blur, SvgNode node) {
  final attr = node.getAttribute('stdDeviation');
  if (attr == null || !attr.isAnimated) return;

  final val = attr.effectiveValue;
  if (val is num) {
    blur.stdDeviationX = val.toDouble();
    blur.stdDeviationY = val.toDouble();
  } else if (val is String) {
    final parts = val.trim().split(RegExp(r'[\s,]+'));
    if (parts.isNotEmpty) {
      blur.stdDeviationX = double.tryParse(parts[0]) ?? blur.stdDeviationX;
      blur.stdDeviationY = parts.length > 1
          ? (double.tryParse(parts[1]) ?? blur.stdDeviationX)
          : blur.stdDeviationX;
    }
  }
}

void _syncOffsetValues(SvgOffsetFilter offset, SvgNode node) {
  final dxAttr = node.getAttribute('dx');
  if (dxAttr != null && dxAttr.isAnimated) {
    final val = dxAttr.effectiveValue;
    if (val is num) {
      offset.dx = val.toDouble();
    } else if (val is String) {
      offset.dx = double.tryParse(val) ?? offset.dx;
    }
  }

  final dyAttr = node.getAttribute('dy');
  if (dyAttr != null && dyAttr.isAnimated) {
    final val = dyAttr.effectiveValue;
    if (val is num) {
      offset.dy = val.toDouble();
    } else if (val is String) {
      offset.dy = double.tryParse(val) ?? offset.dy;
    }
  }
}

void _syncDropShadowValues(SvgDropShadowFilter shadow, SvgNode node) {
  final stdAttr = node.getAttribute('stdDeviation');
  if (stdAttr != null && stdAttr.isAnimated) {
    final val = stdAttr.effectiveValue;
    if (val is num) {
      shadow.stdDeviationX = val.toDouble();
      shadow.stdDeviationY = val.toDouble();
    } else if (val is String) {
      final parts = val.trim().split(RegExp(r'[\s,]+'));
      if (parts.isNotEmpty) {
        shadow.stdDeviationX =
            double.tryParse(parts[0]) ?? shadow.stdDeviationX;
        shadow.stdDeviationY = parts.length > 1
            ? (double.tryParse(parts[1]) ?? shadow.stdDeviationX)
            : shadow.stdDeviationX;
      }
    }
  }

  final dxAttr = node.getAttribute('dx');
  if (dxAttr != null && dxAttr.isAnimated) {
    final val = dxAttr.effectiveValue;
    if (val is num) {
      shadow.dx = val.toDouble();
    } else if (val is String) {
      shadow.dx = double.tryParse(val) ?? shadow.dx;
    }
  }

  final dyAttr = node.getAttribute('dy');
  if (dyAttr != null && dyAttr.isAnimated) {
    final val = dyAttr.effectiveValue;
    if (val is num) {
      shadow.dy = val.toDouble();
    } else if (val is String) {
      shadow.dy = double.tryParse(val) ?? shadow.dy;
    }
  }
}

void _syncColorMatrixValues(SvgColorMatrixFilter colorMatrix, SvgNode node) {
  final valuesAttr = node.getAttribute('values');
  if (valuesAttr == null || !valuesAttr.isAnimated) return;

  final parsedValues = _parseNumberList(valuesAttr.effectiveValue);
  if (parsedValues.isEmpty) return;
  colorMatrix.values = parsedValues;
}

void _syncComponentTransferValues(
  SvgComponentTransferFilter transfer,
  SvgNode node,
) {
  SvgComponentTransferFunction? funcR = transfer.funcR;
  SvgComponentTransferFunction? funcG = transfer.funcG;
  SvgComponentTransferFunction? funcB = transfer.funcB;
  SvgComponentTransferFunction? funcA = transfer.funcA;
  var hasChannelNodes = false;

  for (final child in node.children) {
    switch (child.tagName) {
      case 'feFuncR':
        hasChannelNodes = true;
        funcR = _parseComponentTransferFunctionFromNode(
          child,
          transfer.effectiveFuncR,
        );
      case 'feFuncG':
        hasChannelNodes = true;
        funcG = _parseComponentTransferFunctionFromNode(
          child,
          transfer.effectiveFuncG,
        );
      case 'feFuncB':
        hasChannelNodes = true;
        funcB = _parseComponentTransferFunctionFromNode(
          child,
          transfer.effectiveFuncB,
        );
      case 'feFuncA':
        hasChannelNodes = true;
        funcA = _parseComponentTransferFunctionFromNode(
          child,
          transfer.effectiveFuncA,
        );
    }
  }

  if (!hasChannelNodes) return;
  transfer.updateFunctions(
    funcR: funcR,
    funcG: funcG,
    funcB: funcB,
    funcA: funcA,
  );
}

SvgComponentTransferFunction _parseComponentTransferFunctionFromNode(
  SvgNode node,
  SvgComponentTransferFunction fallback,
) {
  final type = _parseComponentTransferType(
    node.getAttributeValue('type')?.toString(),
    fallback.type,
  );

  return SvgComponentTransferFunction(
    type: type,
    tableValues: _parseNumberList(node.getAttributeValue('tableValues')),
    slope: _parseDouble(
      node.getAttributeValue('slope'),
      fallback: fallback.slope,
    ),
    intercept: _parseDouble(
      node.getAttributeValue('intercept'),
      fallback: fallback.intercept,
    ),
    amplitude: _parseDouble(
      node.getAttributeValue('amplitude'),
      fallback: fallback.amplitude,
    ),
    exponent: _parseDouble(
      node.getAttributeValue('exponent'),
      fallback: fallback.exponent,
    ),
    offset: _parseDouble(
      node.getAttributeValue('offset'),
      fallback: fallback.offset,
    ),
  );
}

SvgComponentTransferType _parseComponentTransferType(
  String? value,
  SvgComponentTransferType fallback,
) {
  switch (value?.trim().toLowerCase()) {
    case 'identity':
      return SvgComponentTransferType.identity;
    case 'table':
      return SvgComponentTransferType.table;
    case 'discrete':
      return SvgComponentTransferType.discrete;
    case 'linear':
      return SvgComponentTransferType.linear;
    case 'gamma':
      return SvgComponentTransferType.gamma;
    default:
      return fallback;
  }
}

double _parseDouble(Object? value, {required double fallback}) {
  if (value is num) return value.toDouble();
  if (value is String) {
    final parsed = double.tryParse(value.trim());
    if (parsed != null) return parsed;
    final unitless = value.trim().replaceAll(RegExp(r'[a-zA-Z%]+$'), '');
    return double.tryParse(unitless) ?? fallback;
  }
  return fallback;
}

List<double> _parseNumberList(Object? value) {
  if (value == null) return const <double>[];
  if (value is num) return <double>[value.toDouble()];
  if (value is List) {
    return value
        .map((item) => item is num ? item.toDouble() : double.tryParse('$item'))
        .whereType<double>()
        .toList(growable: false);
  }
  if (value is String) {
    return value
        .trim()
        .split(RegExp(r'[\s,]+'))
        .map((part) => double.tryParse(part))
        .whereType<double>()
        .toList(growable: false);
  }
  return const <double>[];
}

SvgFilterSourceContext _buildFilterSourceContextImpl(
  AnimatedSvgPainter painter,
  SvgNode node,
) {
  // Build source context with fill and stroke paint passes.
  // BackgroundImage and BackgroundAlpha represent the content behind the
  // filtered element. For proper Blink-parity, these need to capture the
  // rendered content of elements that appear behind this node in the
  // stacking context.
  //
  // Current implementation:
  // - When no explicit background context is available, fallback to
  //   SourceGraphic/SourceAlpha placeholders (baseline behavior).
  // - External callers can provide backgroundImage/backgroundAlpha via
  //   SvgFilterSourceContext for advanced use cases.
  return SvgFilterSourceContext(
    fillPaint: _resolveFilterPaintSourcePassesImpl(
      painter,
      node,
      paintAttribute: 'fill',
      paintOpacityAttribute: 'fill-opacity',
    ),
    strokePaint: _resolveFilterPaintSourcePassesImpl(
      painter,
      node,
      paintAttribute: 'stroke',
      paintOpacityAttribute: 'stroke-opacity',
    ),
    fillPaintColor: _resolveFilterPaintSourceColorImpl(
      painter,
      node,
      paintAttribute: 'fill',
      paintOpacityAttribute: 'fill-opacity',
    ),
    strokePaintColor: _resolveFilterPaintSourceColorImpl(
      painter,
      node,
      paintAttribute: 'stroke',
      paintOpacityAttribute: 'stroke-opacity',
    ),
    // Background inputs are resolved from external context when available.
    // Default fallback to source placeholders handled in filter pipeline.
    backgroundImage: null,
    backgroundAlpha: null,
    // Resolve color-interpolation-filters for pixel-level processing.
    useLinearRGB: painter._isLinearRGBFilterSpace(node),
  );
}

List<SvgFilterPaintPass>? _resolveFilterPaintSourcePassesImpl(
  AnimatedSvgPainter painter,
  SvgNode node, {
  required String paintAttribute,
  required String paintOpacityAttribute,
}) {
  final paintValue = painter._getInheritedAttributeValue(node, paintAttribute);
  if (paintValue == null) {
    return null;
  }
  if (painter._isPaintNone(paintValue)) {
    return const <SvgFilterPaintPass>[];
  }
  if (painter._extractPaintServerId(paintValue) != null) {
    return null;
  }

  final color = painter._resolveColorForNode(paintValue, node);
  if (color == null) {
    return null;
  }

  final opacity = (painter._getInheritedNumber(node, 'opacity') ?? 1.0).clamp(
    0.0,
    1.0,
  );
  final paintOpacity =
      (painter._getInheritedNumber(node, paintOpacityAttribute) ?? 1.0).clamp(
        0.0,
        1.0,
      );
  final effectiveColor = painter._applyOpacity(color, opacity * paintOpacity);
  final isFillContext = paintAttribute.toLowerCase() == 'fill';
  return <SvgFilterPaintPass>[
    SvgSolidPaintSourcePass(
      paintColor: effectiveColor,
      colorFilter: ui.ColorFilter.mode(effectiveColor, ui.BlendMode.srcIn),
      paintFill: isFillContext,
      paintStroke: !isFillContext,
    ),
  ];
}

ui.Color? _resolveFilterPaintSourceColorImpl(
  AnimatedSvgPainter painter,
  SvgNode node, {
  required String paintAttribute,
  required String paintOpacityAttribute,
}) {
  final paintValue = painter._getInheritedAttributeValue(node, paintAttribute);
  if (paintValue == null || painter._isPaintNone(paintValue)) {
    return null;
  }
  if (painter._extractPaintServerId(paintValue) != null) {
    return null;
  }

  final color = painter._resolveColorForNode(paintValue, node);
  if (color == null) {
    return null;
  }

  final opacity = (painter._getInheritedNumber(node, 'opacity') ?? 1.0).clamp(
    0.0,
    1.0,
  );
  final paintOpacity =
      (painter._getInheritedNumber(node, paintOpacityAttribute) ?? 1.0).clamp(
        0.0,
        1.0,
      );
  return painter._applyOpacity(color, opacity * paintOpacity);
}

void _paintWithFilterPassesImpl(
  AnimatedSvgPainter painter,
  ui.Canvas canvas,
  List<SvgFilterPaintPass> passes,
  void Function(
    ui.ImageFilter? imageFilter,
    ui.ColorFilter? colorFilter,
    ui.BlendMode? blendMode,
  )
  paint, {
  ui.Rect? targetNodeBounds,
  ui.Rect? filterRegionClip,
  bool isImageNode = false,
}) {
  final previousFillFlag = painter._currentPassPaintFill;
  final previousStrokeFlag = painter._currentPassPaintStroke;
  final previousFillOverride = painter._currentPassFillColorOverride;
  final previousStrokeOverride = painter._currentPassStrokeColorOverride;
  final previousFilterPass = painter._currentFilterPass;
  for (final pass in passes) {
    canvas.save();
    if (filterRegionClip != null) {
      canvas.clipRect(filterRegionClip);
    }
    painter._currentPassPaintFill = pass.paintFill;
    painter._currentPassPaintStroke = pass.paintStroke;
    painter._currentPassFillColorOverride = pass.fillColorOverride;
    painter._currentPassStrokeColorOverride = pass.strokeColorOverride;
    painter._currentFilterPass = pass;
    if (pass.offset != ui.Offset.zero) {
      canvas.translate(pass.offset.dx, pass.offset.dy);
    }
    if (pass is SvgDisplacementMapPaintPass && targetNodeBounds != null) {
      final painted = _paintDisplacementPassImpl(
        painter,
        canvas,
        pass,
        targetNodeBounds: targetNodeBounds,
        filterRegionClip: filterRegionClip,
      );
      if (!painted && pass.textureHref == null && pass.mapHref == null) {
        paint(pass.imageFilter, pass.colorFilter, pass.blendMode);
      }
      canvas.restore();
      continue;
    }
    if (pass is SvgTurbulencePaintPass && targetNodeBounds != null) {
      final painted = _paintTurbulencePassImpl(
        canvas,
        pass,
        targetNodeBounds: targetNodeBounds,
        filterRegionClip: filterRegionClip,
      );
      if (!painted) {
        paint(pass.imageFilter, pass.colorFilter, pass.blendMode);
      }
      canvas.restore();
      continue;
    }
    if (pass is SvgFeImagePaintPass) {
      _paintFeImagePassImpl(
        painter,
        canvas,
        pass,
        targetNodeBounds: targetNodeBounds,
      );
      canvas.restore();
      continue;
    }
    if ((pass is SvgDiffuseLightingPaintPass ||
            pass is SvgSpecularLightingPaintPass) &&
        targetNodeBounds != null &&
        !isImageNode) {
      final painted = _paintLightingPassImpl(
        painter,
        canvas,
        pass,
        targetNodeBounds: targetNodeBounds,
        filterRegionClip: filterRegionClip,
      );
      if (!painted) {
        paint(pass.imageFilter, pass.colorFilter, pass.blendMode);
      }
      canvas.restore();
      continue;
    }
    paint(pass.imageFilter, pass.colorFilter, pass.blendMode);
    canvas.restore();
  }
  painter._currentPassPaintFill = previousFillFlag;
  painter._currentPassPaintStroke = previousStrokeFlag;
  painter._currentPassFillColorOverride = previousFillOverride;
  painter._currentPassStrokeColorOverride = previousStrokeOverride;
  painter._currentFilterPass = previousFilterPass;
}

bool _paintDisplacementPassImpl(
  AnimatedSvgPainter painter,
  ui.Canvas canvas,
  SvgDisplacementMapPaintPass pass, {
  required ui.Rect targetNodeBounds,
  ui.Rect? filterRegionClip,
}) {
  final useFilterRegionRect =
      filterRegionClip != null &&
      pass.textureHref == null &&
      pass.mapHref == null;
  final outputRect = useFilterRegionRect ? filterRegionClip : targetNodeBounds;
  final width = outputRect.width.round();
  final height = outputRect.height.round();
  if (width <= 0 || height <= 0) {
    return false;
  }

  final key = '${pass.displacementFilter.id}|${width}x$height';
  final image = painter.displacementImagesByFilterKey[key];
  if (image == null) {
    return false;
  }

  final srcRect = ui.Rect.fromLTWH(
    0,
    0,
    image.width.toDouble(),
    image.height.toDouble(),
  );

  final paint = ui.Paint();
  if (pass.imageFilter != null) {
    paint.imageFilter = pass.imageFilter;
  }
  if (pass.colorFilter != null) {
    paint.colorFilter = pass.colorFilter;
  }
  if (pass.blendMode != null) {
    paint.blendMode = pass.blendMode!;
  }

  canvas.drawImageRect(image, srcRect, outputRect, paint);
  return true;
}

void _paintFeImagePassImpl(
  AnimatedSvgPainter painter,
  ui.Canvas canvas,
  SvgFeImagePaintPass pass, {
  ui.Rect? targetNodeBounds,
}) {
  final href = pass.feImageFilter.href?.trim();
  if (href == null || href.isEmpty) {
    return;
  }

  // Element-reference feImage requires dedicated sub-tree rendering semantics.
  // Keep a transparent fallback until that path is fully wired.
  if (pass.isElementReference) {
    return;
  }

  final image = painter.imagesByHref[href];
  if (image == null) {
    return;
  }

  final viewport = _resolveFeImageViewportRect(
    painter,
    pass,
    targetNodeBounds: targetNodeBounds,
  );
  if (viewport.width <= 0 || viewport.height <= 0) {
    return;
  }

  final srcRect = ui.Rect.fromLTWH(
    0,
    0,
    image.width.toDouble(),
    image.height.toDouble(),
  );

  final layout = resolveSvgViewportLayout(
    viewport: viewport,
    sourceSize: srcRect.size,
    preserveAspectRatio: pass.feImageFilter.preserveAspectRatio,
  );

  final paint = ui.Paint();
  if (pass.imageFilter != null) {
    paint.imageFilter = pass.imageFilter;
  }
  if (pass.colorFilter != null) {
    paint.colorFilter = pass.colorFilter;
  }
  if (pass.blendMode != null) {
    paint.blendMode = pass.blendMode!;
  }

  if (layout.clipToViewport) {
    canvas.save();
    canvas.clipRect(viewport, doAntiAlias: true);
    canvas.drawImageRect(image, srcRect, layout.destinationRect, paint);
    canvas.restore();
    return;
  }

  canvas.drawImageRect(image, srcRect, layout.destinationRect, paint);
}

ui.Rect _resolveFeImageViewportRect(
  AnimatedSvgPainter painter,
  SvgFeImagePaintPass pass, {
  ui.Rect? targetNodeBounds,
}) {
  final fallback = pass.subregion;
  final objectBounds = targetNodeBounds;
  if (objectBounds == null ||
      objectBounds.width <= 0 ||
      objectBounds.height <= 0) {
    return fallback;
  }

  final filterRegion = _resolveFeImageFilterRegionRect(
    painter,
    pass,
    objectBounds,
  );
  final isObjectBoundingBox = _isFeImagePrimitiveUnitsObjectBoundingBox(pass);
  final viewportSize = _resolveFeImageUserSpaceViewportSize(
    painter,
    objectBounds,
  );

  final x = _resolveFeImageCoordinate(
    rawValue: pass.feImageFilter.xRaw,
    parsedFallback: pass.feImageFilter.x,
    defaultValue: filterRegion.left,
    isHorizontal: true,
    isPosition: true,
    isObjectBoundingBox: isObjectBoundingBox,
    objectBounds: objectBounds,
    viewportSize: viewportSize,
  );
  final y = _resolveFeImageCoordinate(
    rawValue: pass.feImageFilter.yRaw,
    parsedFallback: pass.feImageFilter.y,
    defaultValue: filterRegion.top,
    isHorizontal: false,
    isPosition: true,
    isObjectBoundingBox: isObjectBoundingBox,
    objectBounds: objectBounds,
    viewportSize: viewportSize,
  );
  final width = _resolveFeImageCoordinate(
    rawValue: pass.feImageFilter.widthRaw,
    parsedFallback: pass.feImageFilter.width,
    defaultValue: filterRegion.width,
    isHorizontal: true,
    isPosition: false,
    isObjectBoundingBox: isObjectBoundingBox,
    objectBounds: objectBounds,
    viewportSize: viewportSize,
  );
  final height = _resolveFeImageCoordinate(
    rawValue: pass.feImageFilter.heightRaw,
    parsedFallback: pass.feImageFilter.height,
    defaultValue: filterRegion.height,
    isHorizontal: false,
    isPosition: false,
    isObjectBoundingBox: isObjectBoundingBox,
    objectBounds: objectBounds,
    viewportSize: viewportSize,
  );

  if (width <= 0 || height <= 0) {
    return ui.Rect.fromLTWH(fallback.left, fallback.top, 0, 0);
  }
  return ui.Rect.fromLTWH(x, y, width, height);
}

ui.Rect _resolveFeImageFilterRegionRect(
  AnimatedSvgPainter painter,
  SvgFeImagePaintPass pass,
  ui.Rect objectBounds,
) {
  final filters = painter.document.filters;
  if (filters == null) {
    return objectBounds;
  }
  final region = filters.getFilterRegion(pass.feImageFilter.id);
  return region.computeRect(objectBounds);
}

bool _isFeImagePrimitiveUnitsObjectBoundingBox(SvgFeImagePaintPass pass) {
  final source = pass.feImageFilter.sourceElement as SvgNode?;
  final rawPrimitiveUnits = source?.parent
      ?.getRawAttributeValue('primitiveUnits')
      ?.trim();
  if (rawPrimitiveUnits == null || rawPrimitiveUnits.isEmpty) {
    return false; // default: userSpaceOnUse
  }
  return rawPrimitiveUnits.toLowerCase() == 'objectboundingbox';
}

ui.Size _resolveFeImageUserSpaceViewportSize(
  AnimatedSvgPainter painter,
  ui.Rect objectBounds,
) {
  final activeViewBox = painter.document.activeViewBox;
  if (activeViewBox != null &&
      activeViewBox.width > 0 &&
      activeViewBox.height > 0) {
    return activeViewBox.size;
  }

  final width = painter.document.width;
  final height = painter.document.height;
  if (width != null && height != null && width > 0 && height > 0) {
    return ui.Size(width, height);
  }

  return ui.Size(objectBounds.width, objectBounds.height);
}

double _resolveFeImageCoordinate({
  required String? rawValue,
  required double parsedFallback,
  required double defaultValue,
  required bool isHorizontal,
  required bool isPosition,
  required bool isObjectBoundingBox,
  required ui.Rect objectBounds,
  required ui.Size viewportSize,
}) {
  final raw = rawValue?.trim();
  if (raw == null || raw.isEmpty) {
    return defaultValue;
  }

  final isPercent = raw.endsWith('%');
  final numeric = _parseSvgNumericToken(raw);
  if (numeric == null) {
    return parsedFallback;
  }

  if (isObjectBoundingBox) {
    final normalized = isPercent ? (numeric / 100.0) : numeric;
    final scale = isHorizontal ? objectBounds.width : objectBounds.height;
    if (isPosition) {
      final origin = isHorizontal ? objectBounds.left : objectBounds.top;
      return origin + normalized * scale;
    }
    return normalized * scale;
  }

  if (isPercent) {
    final scale = isHorizontal ? viewportSize.width : viewportSize.height;
    return (numeric / 100.0) * scale;
  }

  return numeric;
}

double? _parseSvgNumericToken(String value) {
  final cleaned = value.trim().replaceAll(RegExp(r'[a-zA-Z%]+$'), '');
  return double.tryParse(cleaned);
}

/// Wrapper function for applying advanced layer-based masks.
///
/// This checks if the node has a mask and applies it using the advanced
/// masking system with proper luminance/alpha handling. If the node has
/// a mask, this function paints the entire subtree content within the
/// mask layer and returns true. Otherwise, returns false to allow
/// normal rendering to proceed.
bool _applyAdvancedMaskWrapper(
  AnimatedSvgPainter painter,
  ui.Canvas canvas,
  SvgNode node, {
  required Set<String> currentUseStack,
  required bool isHidden,
  SvgNode? foreignObjectParent,
  _UseInheritanceContext? useContext,
}) {
  // Check if node has a mask reference
  final maskValue = painter._getStyleOrAttributeValue(node, 'mask');
  final maskId = painter._extractPaintServerId(maskValue);
  if (maskId == null || maskId.isEmpty) {
    return false;
  }

  // Apply advanced mask with content callback
  return painter._applyAdvancedMask(
    canvas,
    node,
    useStack: currentUseStack,
    paintContent: () {
      // Paint the node content and children within the mask layer
      _paintNodeContentWithinMask(
        painter,
        canvas,
        node,
        isHidden: isHidden,
        currentUseStack: currentUseStack,
        foreignObjectParent: foreignObjectParent,
        useContext: useContext,
      );
    },
  );
}

/// Paints the node content and children within a mask layer context.
void _paintNodeContentWithinMask(
  AnimatedSvgPainter painter,
  ui.Canvas canvas,
  SvgNode node, {
  required bool isHidden,
  required Set<String> currentUseStack,
  SvgNode? foreignObjectParent,
  _UseInheritanceContext? useContext,
}) {
  final filterPasses = _resolveFilterPassesImpl(painter, node);
  final nodeBoundsForFilterPasses = painter._getNodeBounds(node);

  // Render the node content if not hidden
  if (!isHidden) {
    switch (node.tagName) {
      case 'rect':
        _paintWithFilterPassesImpl(
          painter,
          canvas,
          filterPasses,
          (imageFilter, colorFilter, blendMode) => painter._paintRect(
            canvas,
            node,
            imageFilter: imageFilter,
            colorFilter: colorFilter,
            blendMode: blendMode,
          ),
          targetNodeBounds: nodeBoundsForFilterPasses,
          isImageNode: true,
        );
        break;
      case 'circle':
        _paintWithFilterPassesImpl(
          painter,
          canvas,
          filterPasses,
          (imageFilter, colorFilter, blendMode) => painter._paintCircle(
            canvas,
            node,
            imageFilter: imageFilter,
            colorFilter: colorFilter,
            blendMode: blendMode,
          ),
          targetNodeBounds: nodeBoundsForFilterPasses,
        );
        break;
      case 'ellipse':
        _paintWithFilterPassesImpl(
          painter,
          canvas,
          filterPasses,
          (imageFilter, colorFilter, blendMode) => painter._paintEllipse(
            canvas,
            node,
            imageFilter: imageFilter,
            colorFilter: colorFilter,
            blendMode: blendMode,
          ),
          targetNodeBounds: nodeBoundsForFilterPasses,
        );
        break;
      case 'path':
        _paintWithFilterPassesImpl(
          painter,
          canvas,
          filterPasses,
          (imageFilter, colorFilter, blendMode) => painter._paintPath(
            canvas,
            node,
            imageFilter: imageFilter,
            colorFilter: colorFilter,
            blendMode: blendMode,
          ),
          targetNodeBounds: nodeBoundsForFilterPasses,
        );
        break;
      case 'polygon':
        _paintWithFilterPassesImpl(
          painter,
          canvas,
          filterPasses,
          (imageFilter, colorFilter, blendMode) => painter._paintPolygon(
            canvas,
            node,
            imageFilter: imageFilter,
            colorFilter: colorFilter,
            blendMode: blendMode,
          ),
          targetNodeBounds: nodeBoundsForFilterPasses,
        );
        break;
      case 'polyline':
        _paintWithFilterPassesImpl(
          painter,
          canvas,
          filterPasses,
          (imageFilter, colorFilter, blendMode) => painter._paintPolyline(
            canvas,
            node,
            imageFilter: imageFilter,
            colorFilter: colorFilter,
            blendMode: blendMode,
          ),
          targetNodeBounds: nodeBoundsForFilterPasses,
        );
        break;
      case 'line':
        _paintWithFilterPassesImpl(
          painter,
          canvas,
          filterPasses,
          (imageFilter, colorFilter, blendMode) => painter._paintLine(
            canvas,
            node,
            imageFilter: imageFilter,
            colorFilter: colorFilter,
            blendMode: blendMode,
          ),
          targetNodeBounds: nodeBoundsForFilterPasses,
        );
        break;
      case 'image':
        _paintWithFilterPassesImpl(
          painter,
          canvas,
          filterPasses,
          (imageFilter, colorFilter, blendMode) => painter._paintImage(
            canvas,
            node,
            imageFilter: imageFilter,
            colorFilter: colorFilter,
            blendMode: blendMode,
          ),
          targetNodeBounds: nodeBoundsForFilterPasses,
        );
        break;
      case 'text':
        _paintWithFilterPassesImpl(
          painter,
          canvas,
          filterPasses,
          (imageFilter, colorFilter, blendMode) => painter._paintText(
            canvas,
            node,
            imageFilter: imageFilter,
            colorFilter: colorFilter,
            blendMode: blendMode,
          ),
          targetNodeBounds: nodeBoundsForFilterPasses,
        );
        break;
      case 'use':
        painter._paintUse(
          canvas,
          node,
          useStack: currentUseStack,
          useContext: useContext,
        );
        break;
      case 'a':
      case 'g':
      case 'svg':
      case 'foreignObject':
        // Groups painted through children recursion below
        break;
      case 'switch':
        painter._paintSwitch(canvas, node, useStack: currentUseStack);
        break;
      default:
        break;
    }
  }

  // Paint children
  if (painter._shouldPaintChildren(node)) {
    // Determine foreignObject context for children
    // - foreignObject: sets new FO context
    // - svg: resets FO context (new viewport)
    // - other elements: preserve from parent
    final SvgNode? foParent;
    if (node.tagName == 'foreignObject') {
      foParent = node;
    } else if (node.tagName == 'svg') {
      foParent = null;
    } else {
      foParent = foreignObjectParent;
    }
    for (final child in node.children) {
      _paintNodeImplWithUseContext(
        painter,
        canvas,
        child,
        useStack: currentUseStack,
        foreignObjectParent: foParent,
        useContext: useContext,
      );
    }
  }
}
