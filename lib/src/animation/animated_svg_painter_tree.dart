part of 'animated_svg_painter.dart';

void _paintNodeImpl(
  AnimatedSvgPainter painter,
  ui.Canvas canvas,
  SvgNode node, {
  Set<String>? useStack,
  SvgNode? foreignObjectParent,
}) {
  final display = painter
      ._getStyleOrAttributeValue(node, 'display')
      ?.toString()
      .trim();
  if (display?.toLowerCase() == 'none') return;

  final visibility = painter._getInheritedString(node, 'visibility');
  final normalizedVisibility = visibility?.toLowerCase();
  final isHidden =
      normalizedVisibility == 'hidden' || normalizedVisibility == 'collapse';

  final currentUseStack = useStack ?? <String>{};
  canvas.save();

  // Применяем transform если есть.
  painter._applyTransform(canvas, node);

  // Baseline foreignObject viewport: смещение + clip children областью.
  painter._applyForeignObjectViewport(canvas, node);

  // Apply nested SVG viewport transform within foreignObject
  painter._applyNestedSvgViewportInForeignObject(
    canvas,
    node,
    foreignObjectParent,
  );

  // Применяем clipPath если есть.
  painter._applyClipPath(canvas, node, useStack: currentUseStack);

  // Применяем mask если есть (baseline geometry mask).
  painter._applyMask(canvas, node, useStack: currentUseStack);

  final filterPasses = _resolveFilterPassesImpl(painter, node);

  // Рисуем сам узел в зависимости от типа.
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
        );
        break;
      case 'tspan':
        // Рендерится из родительского <text> прохода.
        break;
      case 'textPath':
        // Рендерится из родительского <text> прохода.
        break;
      case 'use':
        painter._paintUse(canvas, node, useStack: currentUseStack);
        break;
      case 'a':
      case 'g':
      case 'svg':
      case 'foreignObject':
        // Check requiredExtensions for foreignObject - skip if not supported
        if (node.tagName == 'foreignObject' &&
            !painter._shouldRenderForeignObject(node)) {
          canvas.restore();
          return;
        }
        // Groups apply saveLayer for opacity compositing if needed.
        // Returns true if children were painted in the layer.
        if (_paintGroupWithOpacity(
          painter,
          canvas,
          node,
          currentUseStack,
          foreignObjectParent: node.tagName == 'foreignObject' ? node : null,
        )) {
          // Children already painted in opacity layer, skip normal recursion
          canvas.restore();
          return;
        }
        break;
      case 'switch':
        painter._paintSwitch(canvas, node, useStack: currentUseStack);
        break;
      default:
        // Игнорируем неподдерживаемые элементы (animate, text, etc.).
        break;
    }
  }

  // Рекурсивно рисуем детей.
  if (painter._shouldPaintChildren(node)) {
    // Determine if this node establishes a foreignObject context for children
    final foParent = node.tagName == 'foreignObject' ? node : null;
    for (final child in node.children) {
      _paintNodeImpl(
        painter,
        canvas,
        child,
        useStack: currentUseStack,
        foreignObjectParent: foParent,
      );
    }
  }

  canvas.restore();
}

/// Paints group children with proper opacity compositing.
/// If the group has opacity < 1, uses saveLayer to composite children
/// before applying opacity to the whole group.
/// Returns true if children were painted (caller should skip normal recursion).
bool _paintGroupWithOpacity(
  AnimatedSvgPainter painter,
  ui.Canvas canvas,
  SvgNode node,
  Set<String> useStack, {
  SvgNode? foreignObjectParent,
}) {
  // Check for group-level opacity (not inherited)
  final opacityValue = node.getAttributeValue('opacity');
  final opacity = opacityValue != null
      ? (double.tryParse(opacityValue.toString()) ?? 1.0).clamp(0.0, 1.0)
      : 1.0;

  // If opacity is 1.0, no special handling needed - children painted normally
  // by the recursive call after this switch statement
  if (opacity >= 1.0) {
    return false;
  }

  // Use saveLayer for opacity compositing
  // Using null bounds lets Flutter determine the layer size
  final layerPaint = ui.Paint()
    ..color = ui.Color.fromARGB((opacity * 255).round(), 255, 255, 255);

  canvas.saveLayer(null, layerPaint);

  // Paint children into the layer
  if (painter._shouldPaintChildren(node)) {
    // Determine if this node establishes a foreignObject context for children
    final foParent = node.tagName == 'foreignObject'
        ? node
        : foreignObjectParent;
    for (final child in node.children) {
      _paintNodeImpl(
        painter,
        canvas,
        child,
        useStack: useStack,
        foreignObjectParent: foParent,
      );
    }
  }

  canvas.restore();
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
  final passes = painter.document.filters!.resolvePaintPasses(
    filterId,
    sourceContext: _buildFilterSourceContextImpl(painter, node),
  );
  if (passes.isEmpty) {
    return const <SvgFilterPaintPass>[SvgFilterPaintPass.identity];
  }
  return passes;
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
    // Background inputs are resolved from external context when available.
    // Default fallback to source placeholders handled in filter pipeline.
    backgroundImage: null,
    backgroundAlpha: null,
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
    SvgFilterPaintPass(
      colorFilter: ui.ColorFilter.mode(effectiveColor, ui.BlendMode.srcIn),
      paintFill: isFillContext,
      paintStroke: !isFillContext,
    ),
  ];
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
  paint,
) {
  final previousFillFlag = painter._currentPassPaintFill;
  final previousStrokeFlag = painter._currentPassPaintStroke;
  for (final pass in passes) {
    canvas.save();
    painter._currentPassPaintFill = pass.paintFill;
    painter._currentPassPaintStroke = pass.paintStroke;
    if (pass.offset != ui.Offset.zero) {
      canvas.translate(pass.offset.dx, pass.offset.dy);
    }
    paint(pass.imageFilter, pass.colorFilter, pass.blendMode);
    canvas.restore();
  }
  painter._currentPassPaintFill = previousFillFlag;
  painter._currentPassPaintStroke = previousStrokeFlag;
}
