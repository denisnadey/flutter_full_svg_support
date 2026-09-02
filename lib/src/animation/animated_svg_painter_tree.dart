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

/// Cache key for the node currently being painted.
///
/// `_currentUseContext` links innermost-first, so the collected chain is
/// reversed to match the outermost-first order used when the precomputed
/// image was captured.
String _sourceFilterTargetInstanceKey(SvgNode targetNode) {
  final useChain = <SvgNode>[];
  for (
    _UseInheritanceContext? context = _currentUseContext;
    context != null;
    context = context.parentContext
  ) {
    useChain.add(context.useNode);
  }
  return AnimatedSvgPainter.sourceFilterTargetInstanceKey(
    targetNode,
    useChain.reversed,
  );
}

/// Resolved filter inputs for painting one SVG node.
///
/// The values are computed once per node and shared by every rendering path,
/// including content painted inside an advanced mask layer.
class _ResolvedNodeFilterState {
  const _ResolvedNodeFilterState({
    required this.passes,
    required this.targetBounds,
    required this.requiresFilterExecution,
    this.regionClip,
  });

  final List<SvgFilterPaintPass> passes;
  final ui.Rect targetBounds;

  /// Whether this node has a filter reference that must retain filter
  /// semantics even when its resolved passes are visually identity.
  final bool requiresFilterExecution;

  final ui.Rect? regionClip;
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
  final previousUseContext = _currentUseContext;
  final previousUseContextLookup = useContextCustomPropertyLookup;

  if (useContext != null) {
    _currentUseContext = useContext;
    // Set up CSS custom property lookup through use context.
    // This enables var(--custom-property) to resolve from <use> elements.
    useContextCustomPropertyLookup = (name) =>
        useContext.getCustomProperty(name);
  }

  try {
    final display = painter
        ._getStyleOrAttributeValue(node, 'display')
        ?.toString()
        .trim();
    if (display?.toLowerCase() == 'none') {
      return;
    }

    final visibility = painter._getInheritedString(node, 'visibility');
    final normalizedVisibility = visibility?.toLowerCase();
    final isHidden =
        normalizedVisibility == 'hidden' || normalizedVisibility == 'collapse';
    final currentUseStack = useStack ?? <String>{};

    canvas.save();
    try {
      // Apply transform if present.
      painter._applyTransform(canvas, node);

      // Baseline foreignObject viewport: offset + clip children to the region.
      painter._applyForeignObjectViewport(canvas, node);

      // Apply nested SVG viewport transform within foreignObject.
      painter._applyNestedSvgViewportInForeignObject(
        canvas,
        node,
        foreignObjectParent,
      );

      // Apply nested SVG viewport transform for regular SVG-in-SVG nesting.
      painter._applyNestedSvgViewport(canvas, node, foreignObjectParent);

      // Apply clipPath before the mask and node content.
      painter._applyClipPath(canvas, node, useStack: currentUseStack);

      void paintContent() {
        _paintNodeContent(
          painter,
          canvas,
          node,
          isHidden: isHidden,
          useStack: currentUseStack,
          foreignObjectParent: foreignObjectParent,
          useContext: useContext,
        );
      }

      // Advanced masks capture the same node-content pipeline as normal
      // rendering, so filter, group, and leaf behavior cannot drift.
      if (painter._applyAdvancedMask(
        canvas,
        node,
        useStack: currentUseStack,
        paintContent: paintContent,
      )) {
        return;
      }

      // No advanced mask: retain the existing basic geometry-mask fallback.
      painter._applyMask(canvas, node, useStack: currentUseStack);
      paintContent();
    } finally {
      canvas.restore();
    }
  } finally {
    _currentUseContext = previousUseContext;
    useContextCustomPropertyLookup = previousUseContextLookup;
  }
}

_ResolvedNodeFilterState _resolveNodeFilterState(
  AnimatedSvgPainter painter,
  SvgNode node,
) {
  final passes = _resolveFilterPassesImpl(painter, node);
  final filterId = painter._getFilterId(node);
  // An explicit filter reference must retain its region clip even when its
  // resolved passes are visually identity. Only nodes without filter handling
  // can skip the target-bounds work entirely.
  final requiresFilterExecution =
      filterId != null && painter.document.filters != null;
  final targetBounds = requiresFilterExecution
      ? painter._resolveFilterTargetBounds(node)
      : ui.Rect.zero;

  ui.Rect? regionClip;
  if (filterId != null && painter.document.filters != null) {
    // Applies active SMIL values on the filter's own x/y/width/height.
    final region = resolveSvgEffectiveFilterRegion(painter.document, filterId);
    if (targetBounds.width > 0 && targetBounds.height > 0) {
      regionClip = region.computeRect(targetBounds);
    }
  }

  return _ResolvedNodeFilterState(
    passes: passes,
    targetBounds: targetBounds,
    requiresFilterExecution: requiresFilterExecution,
    regionClip: regionClip,
  );
}

/// Paints [node]'s own output and, unless a group layer already did so, its
/// rendered children. The canvas transform, clip path, and any advanced mask
/// have already been applied by [_paintNodeImplWithUseContext].
void _paintNodeContent(
  AnimatedSvgPainter painter,
  ui.Canvas canvas,
  SvgNode node, {
  required bool isHidden,
  required Set<String> useStack,
  SvgNode? foreignObjectParent,
  _UseInheritanceContext? useContext,
}) {
  final filterState = _resolveNodeFilterState(painter, node);

  if (!isHidden) {
    switch (node.tagName) {
      case 'rect':
        _paintWithFilterPassesImpl(
          painter,
          canvas,
          filterState.passes,
          (imageFilter, colorFilter, blendMode) => painter._paintRect(
            canvas,
            node,
            imageFilter: imageFilter,
            colorFilter: colorFilter,
            blendMode: blendMode,
          ),
          targetNode: node,
          targetNodeBounds: filterState.targetBounds,
          filterRegionClip: filterState.regionClip,
          requiresFilterExecution: filterState.requiresFilterExecution,
        );
        break;
      case 'circle':
        _paintWithFilterPassesImpl(
          painter,
          canvas,
          filterState.passes,
          (imageFilter, colorFilter, blendMode) => painter._paintCircle(
            canvas,
            node,
            imageFilter: imageFilter,
            colorFilter: colorFilter,
            blendMode: blendMode,
          ),
          targetNode: node,
          targetNodeBounds: filterState.targetBounds,
          filterRegionClip: filterState.regionClip,
          requiresFilterExecution: filterState.requiresFilterExecution,
        );
        break;
      case 'ellipse':
        _paintWithFilterPassesImpl(
          painter,
          canvas,
          filterState.passes,
          (imageFilter, colorFilter, blendMode) => painter._paintEllipse(
            canvas,
            node,
            imageFilter: imageFilter,
            colorFilter: colorFilter,
            blendMode: blendMode,
          ),
          targetNode: node,
          targetNodeBounds: filterState.targetBounds,
          filterRegionClip: filterState.regionClip,
          requiresFilterExecution: filterState.requiresFilterExecution,
        );
        break;
      case 'path':
        _paintWithFilterPassesImpl(
          painter,
          canvas,
          filterState.passes,
          (imageFilter, colorFilter, blendMode) => painter._paintPath(
            canvas,
            node,
            imageFilter: imageFilter,
            colorFilter: colorFilter,
            blendMode: blendMode,
          ),
          targetNode: node,
          targetNodeBounds: filterState.targetBounds,
          filterRegionClip: filterState.regionClip,
          requiresFilterExecution: filterState.requiresFilterExecution,
        );
        break;
      case 'polygon':
        _paintWithFilterPassesImpl(
          painter,
          canvas,
          filterState.passes,
          (imageFilter, colorFilter, blendMode) => painter._paintPolygon(
            canvas,
            node,
            imageFilter: imageFilter,
            colorFilter: colorFilter,
            blendMode: blendMode,
          ),
          targetNode: node,
          targetNodeBounds: filterState.targetBounds,
          filterRegionClip: filterState.regionClip,
          requiresFilterExecution: filterState.requiresFilterExecution,
        );
        break;
      case 'polyline':
        _paintWithFilterPassesImpl(
          painter,
          canvas,
          filterState.passes,
          (imageFilter, colorFilter, blendMode) => painter._paintPolyline(
            canvas,
            node,
            imageFilter: imageFilter,
            colorFilter: colorFilter,
            blendMode: blendMode,
          ),
          targetNode: node,
          targetNodeBounds: filterState.targetBounds,
          filterRegionClip: filterState.regionClip,
          requiresFilterExecution: filterState.requiresFilterExecution,
        );
        break;
      case 'line':
        _paintWithFilterPassesImpl(
          painter,
          canvas,
          filterState.passes,
          (imageFilter, colorFilter, blendMode) => painter._paintLine(
            canvas,
            node,
            imageFilter: imageFilter,
            colorFilter: colorFilter,
            blendMode: blendMode,
          ),
          targetNode: node,
          targetNodeBounds: filterState.targetBounds,
          filterRegionClip: filterState.regionClip,
          requiresFilterExecution: filterState.requiresFilterExecution,
        );
        break;
      case 'image':
        _paintWithFilterPassesImpl(
          painter,
          canvas,
          filterState.passes,
          (imageFilter, colorFilter, blendMode) => painter._paintImage(
            canvas,
            node,
            imageFilter: imageFilter,
            colorFilter: colorFilter,
            blendMode: blendMode,
          ),
          targetNode: node,
          targetNodeBounds: filterState.targetBounds,
          filterRegionClip: filterState.regionClip,
          requiresFilterExecution: filterState.requiresFilterExecution,
          isImageNode: true,
        );
        break;
      case 'text':
        _paintWithFilterPassesImpl(
          painter,
          canvas,
          filterState.passes,
          (imageFilter, colorFilter, blendMode) => painter._paintText(
            canvas,
            node,
            imageFilter: imageFilter,
            colorFilter: colorFilter,
            blendMode: blendMode,
          ),
          targetNode: node,
          targetNodeBounds: filterState.targetBounds,
          filterRegionClip: filterState.regionClip,
          requiresFilterExecution: filterState.requiresFilterExecution,
        );
        break;
      case 'tspan':
      case 'textPath':
        // Rendered from the parent <text> pass.
        break;
      case 'use':
        painter._paintUse(
          canvas,
          node,
          useStack: useStack,
          useContext: useContext,
          filterState: filterState,
        );
        break;
      case 'a':
      case 'g':
      case 'svg':
      case 'foreignObject':
        if (node.tagName == 'foreignObject' &&
            !painter._shouldRenderForeignObject(node)) {
          return;
        }
        if (_paintGroupWithOpacity(
          painter,
          canvas,
          node,
          useStack,
          filterPasses: filterState.passes,
          targetNodeBounds: filterState.targetBounds,
          filterRegionClip: filterState.regionClip,
          requiresFilterExecution: filterState.requiresFilterExecution,
          foreignObjectParent: foreignObjectParent,
          useContext: useContext,
        )) {
          return;
        }
        break;
      case 'switch':
        painter._paintSwitch(canvas, node, useStack: useStack);
        break;
      default:
        // Ignore unsupported elements (animate, metadata, etc.).
        break;
    }
  }

  _paintNodeChildren(
    painter,
    canvas,
    node,
    useStack,
    foreignObjectParent: foreignObjectParent,
    useContext: useContext,
  );
}

SvgNode? _childForeignObjectParent(SvgNode node, SvgNode? foreignObjectParent) {
  if (node.tagName == 'foreignObject') {
    return node;
  }
  if (node.tagName == 'svg') {
    return null;
  }
  return foreignObjectParent;
}

void _paintNodeChildren(
  AnimatedSvgPainter painter,
  ui.Canvas canvas,
  SvgNode node,
  Set<String> useStack, {
  SvgNode? foreignObjectParent,
  _UseInheritanceContext? useContext,
}) {
  if (!painter._shouldPaintChildren(node)) {
    return;
  }

  final childForeignObjectParent = _childForeignObjectParent(
    node,
    foreignObjectParent,
  );
  for (final child in node.children) {
    _paintNodeImplWithUseContext(
      painter,
      canvas,
      child,
      useStack: useStack,
      foreignObjectParent: childForeignObjectParent,
      useContext: useContext,
    );
  }
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
  required List<SvgFilterPaintPass> filterPasses,
  required ui.Rect targetNodeBounds,
  required bool requiresFilterExecution,
  ui.Rect? filterRegionClip,
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

  // Filter passes describe the complete output of the filter graph. An
  // explicit identity filter still needs execution so its declared region
  // clips the composited image of the children.
  final hasFilter =
      requiresFilterExecution || !_isIdentityOnlyFilterPasses(filterPasses);

  // Determine if saveLayer is needed for compositing
  final needsLayer =
      opacity < 1.0 ||
      isIsolated ||
      hasEnableBackground ||
      hasGroupBlendMode ||
      hasFilter;

  // If no compositing needed, children painted normally by the
  // recursive call after this switch statement.
  if (!needsLayer) {
    return false;
  }

  // Build the outer layer paint. Group opacity and blend mode apply to the
  // complete filter output, not to each individual filter pass.
  final layerPaint = ui.Paint()
    ..color = ui.Color.fromARGB((opacity * 255).round(), 255, 255, 255);
  if (hasGroupBlendMode) {
    layerPaint.blendMode = groupBlendMode;
  }
  canvas.saveLayer(null, layerPaint);

  // Push background context for enable-background: new.
  // This makes BackgroundImage/BackgroundAlpha available to child filters.
  if (hasEnableBackground && painter.document.filters != null) {
    painter.document.filters!.pushBackgroundContext();
  }

  void paintGroupFilterSource({
    ui.ImageFilter? imageFilter,
    ui.ColorFilter? colorFilter,
    ui.BlendMode? blendMode,
  }) {
    // A pass without paint effects composites the children unchanged;
    // skip the layer in that case, mirroring the <use> source painter.
    final hasPaintEffects =
        imageFilter != null || colorFilter != null || blendMode != null;
    ui.Paint? passPaint;
    if (hasPaintEffects) {
      passPaint = ui.Paint();
      if (imageFilter != null) {
        passPaint.imageFilter = imageFilter;
      }
      if (colorFilter != null) {
        passPaint.colorFilter = colorFilter;
      }
      if (blendMode != null) {
        passPaint.blendMode = blendMode;
      }
      canvas.saveLayer(null, passPaint);
    }
    try {
      _paintNodeChildren(
        painter,
        canvas,
        node,
        useStack,
        foreignObjectParent: foreignObjectParent,
        useContext: useContext,
      );
    } finally {
      if (hasPaintEffects) {
        canvas.restore();
      }
    }
  }

  if (hasFilter) {
    _executeFilterPassesImpl(
      painter,
      canvas,
      filterPasses,
      _FilterRenderTarget(
        targetNode: node,
        bounds: targetNodeBounds,
        filterRegionClip: filterRegionClip,
        paintSource: paintGroupFilterSource,
      ),
    );
  } else {
    _paintNodeChildren(
      painter,
      canvas,
      node,
      useStack,
      foreignObjectParent: foreignObjectParent,
      useContext: useContext,
    );
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
  required SvgNode targetNode,
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

  final key =
      '$filterId|${width}x$height|$kind|${_sourceFilterTargetInstanceKey(targetNode)}';
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

/// Returns true when [passes] consists of a single pass that has no visual
/// effect, i.e. it is equivalent to [SvgFilterPaintPass.identity].
///
/// The check requires the pass to be exactly the base [SvgFilterPaintPass]
/// type (not a specialized subclass such as [SvgDisplacementMapPaintPass] or
/// [SvgTurbulencePaintPass]) and to be fully default: no `imageFilter`, no
/// `colorFilter`, no `blendMode`, a zero `offset`, both paint channels
/// enabled, and no color overrides. A specialized pass is never treated as
/// identity, even if all of those fields happen to be empty, because it
/// renders its output through a dedicated code path. Channel-restricted
/// passes produced for FillPaint/StrokePaint inputs (paintFill/paintStroke
/// selectively disabled) are not identity either: they suppress one paint
/// channel and must go through the pass executor.
///
/// Nodes without a filter reference use this to short-circuit filter handling.
/// An explicit filter that resolves to this pass must still execute so its
/// declared filter region is applied. Pass resolution also uses the check to
/// special-case a lone displacement-map primitive that resolved to identity.
bool _isIdentityOnlyFilterPasses(List<SvgFilterPaintPass> passes) {
  if (passes.length != 1) {
    return false;
  }
  final pass = passes.single;
  return pass.runtimeType == SvgFilterPaintPass &&
      pass.imageFilter == null &&
      pass.colorFilter == null &&
      pass.blendMode == null &&
      pass.offset == ui.Offset.zero &&
      pass.paintFill &&
      pass.paintStroke &&
      pass.fillColorOverride == null &&
      pass.strokeColorOverride == null;
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

typedef _FilterSourcePainter =
    void Function({
      ui.ImageFilter? imageFilter,
      ui.ColorFilter? colorFilter,
      ui.BlendMode? blendMode,
    });

class _FilterRenderTarget {
  const _FilterRenderTarget({
    required this.paintSource,
    required this.targetNode,
    this.bounds,
    this.filterRegionClip,
    this.isImageNode = false,
  });

  final _FilterSourcePainter paintSource;
  final SvgNode targetNode;
  final ui.Rect? bounds;
  final ui.Rect? filterRegionClip;
  final bool isImageNode;
}

/// Ambient paint state for one active filter pass.
///
/// A filter executor replaces the current pass metadata while preserving any
/// channel restriction imposed by an ancestor. The immutable value plus each
/// executor's `try`/`finally` restoration forms a dynamic state stack.
class _FilterPaintState {
  const _FilterPaintState({
    required this.paintFill,
    required this.paintStroke,
    this.fillColorOverride,
    this.strokeColorOverride,
    this.filterPass,
  });

  const _FilterPaintState.initial()
    : paintFill = true,
      paintStroke = true,
      fillColorOverride = null,
      strokeColorOverride = null,
      filterPass = null;

  final bool paintFill;
  final bool paintStroke;
  final ui.Color? fillColorOverride;
  final ui.Color? strokeColorOverride;
  final SvgFilterPaintPass? filterPass;

  _FilterPaintState forPass(SvgFilterPaintPass pass) {
    return _FilterPaintState(
      paintFill: paintFill && pass.paintFill,
      paintStroke: paintStroke && pass.paintStroke,
      fillColorOverride: pass.fillColorOverride,
      strokeColorOverride: pass.strokeColorOverride,
      filterPass: pass,
    );
  }
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
  required SvgNode targetNode,
  ui.Rect? targetNodeBounds,
  ui.Rect? filterRegionClip,
  bool requiresFilterExecution = false,
  bool isImageNode = false,
}) {
  // An unfiltered node resolves to a single fully-default identity pass.
  // Paint it directly without entering the executor so descendant rendering
  // retains the ambient channel restrictions imposed by an ancestor group
  // pass (for example, FillPaint or StrokePaint). An explicit identity filter
  // still enters the executor to apply its declared filter region.
  if (!requiresFilterExecution && _isIdentityOnlyFilterPasses(passes)) {
    paint(null, null, null);
    return;
  }
  _executeFilterPassesImpl(
    painter,
    canvas,
    passes,
    _FilterRenderTarget(
      targetNode: targetNode,
      bounds: targetNodeBounds,
      filterRegionClip: filterRegionClip,
      isImageNode: isImageNode,
      paintSource:
          ({
            ui.ImageFilter? imageFilter,
            ui.ColorFilter? colorFilter,
            ui.BlendMode? blendMode,
          }) {
            paint(imageFilter, colorFilter, blendMode);
          },
    ),
  );
}

void _executeFilterPassesImpl(
  AnimatedSvgPainter painter,
  ui.Canvas canvas,
  List<SvgFilterPaintPass> passes,
  _FilterRenderTarget target,
) {
  final inheritedState = painter._currentFilterPaintState;
  try {
    for (final pass in passes) {
      canvas.save();
      try {
        if (target.filterRegionClip != null) {
          canvas.clipRect(target.filterRegionClip!);
        }
        painter._currentFilterPaintState = inheritedState.forPass(pass);
        if (pass.offset != ui.Offset.zero) {
          canvas.translate(pass.offset.dx, pass.offset.dy);
        }
        if (pass is SvgDisplacementMapPaintPass && target.bounds != null) {
          final painted = _paintDisplacementPassImpl(
            painter,
            canvas,
            pass,
            targetNode: target.targetNode,
            targetNodeBounds: target.bounds!,
            filterRegionClip: target.filterRegionClip,
          );
          if (!painted && pass.textureHref == null && pass.mapHref == null) {
            target.paintSource(
              imageFilter: pass.imageFilter,
              colorFilter: pass.colorFilter,
              blendMode: pass.blendMode,
            );
          }
          continue;
        }
        if (pass is SvgTurbulencePaintPass && target.bounds != null) {
          final painted = _paintTurbulencePassImpl(
            canvas,
            pass,
            targetNodeBounds: target.bounds!,
            filterRegionClip: target.filterRegionClip,
          );
          if (!painted) {
            target.paintSource(
              imageFilter: pass.imageFilter,
              colorFilter: pass.colorFilter,
              blendMode: pass.blendMode,
            );
          }
          continue;
        }
        if (pass is SvgFeImagePaintPass) {
          _paintFeImagePassImpl(
            painter,
            canvas,
            pass,
            targetNodeBounds: target.bounds,
          );
          continue;
        }
        if ((pass is SvgDiffuseLightingPaintPass ||
                pass is SvgSpecularLightingPaintPass) &&
            target.bounds != null &&
            !target.isImageNode) {
          final painted = _paintLightingPassImpl(
            painter,
            canvas,
            pass,
            targetNode: target.targetNode,
            targetNodeBounds: target.bounds!,
            filterRegionClip: target.filterRegionClip,
          );
          if (!painted) {
            target.paintSource(
              imageFilter: pass.imageFilter,
              colorFilter: pass.colorFilter,
              blendMode: pass.blendMode,
            );
          }
          continue;
        }
        if (pass is SvgInnerShadowPaintPass) {
          _paintInnerShadowPassImpl(painter, canvas, pass, target);
          continue;
        }
        target.paintSource(
          imageFilter: pass.imageFilter,
          colorFilter: pass.colorFilter,
          blendMode: pass.blendMode,
        );
      } finally {
        canvas.restore();
      }
    }
  } finally {
    painter._currentFilterPaintState = inheritedState;
  }
}

void _paintInnerShadowPassImpl(
  AnimatedSvgPainter painter,
  ui.Canvas canvas,
  SvgInnerShadowPaintPass pass,
  _FilterRenderTarget target,
) {
  final inheritedState = painter._currentFilterPaintState;

  // Open an isolated layer so dstOut only erases within this element's
  // rendering. Any downstream feColorMatrix is applied at composite time
  // via the saveLayer paint.
  final layerPaint = ui.Paint();
  if (pass.colorFilter != null) layerPaint.colorFilter = pass.colorFilter;
  if (pass.imageFilter != null) layerPaint.imageFilter = pass.imageFilter;
  canvas.saveLayer(null, layerPaint);
  try {
    for (final sourcePass in pass.sourceGraphicPasses) {
      painter._currentFilterPaintState = inheritedState.forPass(sourcePass);
      target.paintSource(
        imageFilter: sourcePass.imageFilter,
        colorFilter: sourcePass.colorFilter,
        blendMode: sourcePass.blendMode,
      );
    }
    for (final alphaPass in pass.blurAlphaPasses) {
      canvas.save();
      try {
        if (alphaPass.offset != ui.Offset.zero) {
          canvas.translate(alphaPass.offset.dx, alphaPass.offset.dy);
        }
        painter._currentFilterPaintState = inheritedState.forPass(alphaPass);
        target.paintSource(
          imageFilter: alphaPass.imageFilter,
          colorFilter: alphaPass.colorFilter,
          blendMode: ui.BlendMode.dstOut,
        );
      } finally {
        canvas.restore();
      }
    }
  } finally {
    painter._currentFilterPaintState = inheritedState;
    canvas.restore();
  }
}

bool _paintDisplacementPassImpl(
  AnimatedSvgPainter painter,
  ui.Canvas canvas,
  SvgDisplacementMapPaintPass pass, {
  required SvgNode targetNode,
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

  final key = pass.textureHref == null && pass.mapHref == null
      ? '${pass.displacementFilter.id}|${width}x$height|${_sourceFilterTargetInstanceKey(targetNode)}'
      : '${pass.displacementFilter.id}|${width}x$height';
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
  final region = resolveSvgEffectiveFilterRegion(
    painter.document,
    pass.feImageFilter.id,
  );
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
