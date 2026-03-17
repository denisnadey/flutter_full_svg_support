part of 'animated_svg_painter.dart';

/// Maximum recursion depth for nested <use> elements (matching Blink).
/// This prevents infinite loops and excessive resource usage.
const int _kMaxUseRecursionDepth = 10;

extension AnimatedSvgPainterUseExtension on AnimatedSvgPainter {
  /// Checks if foreignObject should be rendered based on requiredExtensions.
  /// Per SVG spec, if requiredExtensions is specified and not supported,
  /// the foreignObject should not render (allowing <switch> fallback pattern).
  bool _shouldRenderForeignObject(SvgNode node) {
    if (node.tagName != 'foreignObject') {
      return true;
    }

    // Check requiredExtensions - if specified, foreignObject should not render
    // as we don't support any foreign extensions in this implementation.
    final requiredExtensions = node.getAttributeValue('requiredExtensions');
    if (requiredExtensions != null &&
        requiredExtensions.toString().trim().isNotEmpty) {
      return false;
    }

    return true;
  }

  void _applyForeignObjectViewport(ui.Canvas canvas, SvgNode node) {
    if (node.tagName != 'foreignObject') {
      return;
    }

    final x = _getNumber(node, 'x') ?? 0.0;
    final y = _getNumber(node, 'y') ?? 0.0;
    final width = _getNumber(node, 'width') ?? 0.0;
    final height = _getNumber(node, 'height') ?? 0.0;
    if (width <= 0 || height <= 0) {
      return;
    }

    canvas.translate(x, y);

    // Check overflow attribute - default for foreignObject is hidden
    final overflow = _getInheritedString(node, 'overflow')?.toLowerCase();
    if (overflow != 'visible') {
      canvas.clipRect(ui.Rect.fromLTWH(0, 0, width, height), doAntiAlias: true);
    }
  }

  /// Applies nested SVG viewport transform within foreignObject.
  /// When foreignObject contains an <svg> element, the inner SVG establishes
  /// its own coordinate system with its own viewBox/viewport.
  void _applyNestedSvgViewportInForeignObject(
    ui.Canvas canvas,
    SvgNode svgNode,
    SvgNode? foreignObjectParent,
  ) {
    if (svgNode.tagName != 'svg' || foreignObjectParent == null) {
      return;
    }
    if (foreignObjectParent.tagName != 'foreignObject') {
      return;
    }

    // Get foreignObject viewport dimensions
    final foWidth = _getNumber(foreignObjectParent, 'width') ?? 0.0;
    final foHeight = _getNumber(foreignObjectParent, 'height') ?? 0.0;
    if (foWidth <= 0 || foHeight <= 0) {
      return;
    }

    // Get nested SVG attributes
    final svgX = _getNumber(svgNode, 'x') ?? 0.0;
    final svgY = _getNumber(svgNode, 'y') ?? 0.0;
    var svgWidth = _getNumber(svgNode, 'width');
    var svgHeight = _getNumber(svgNode, 'height');

    // Default width/height to 100% of foreignObject viewport
    svgWidth ??= foWidth;
    svgHeight ??= foHeight;

    if (svgWidth <= 0 || svgHeight <= 0) {
      return;
    }

    // Translate to SVG position
    if (svgX != 0 || svgY != 0) {
      canvas.translate(svgX, svgY);
    }

    // Apply viewBox transform if present
    final viewBoxAttr = svgNode.getAttributeValue('viewBox')?.toString();
    if (viewBoxAttr != null && viewBoxAttr.trim().isNotEmpty) {
      final viewBox = _parseForeignObjectViewBox(viewBoxAttr);
      if (viewBox != null && viewBox.width > 0 && viewBox.height > 0) {
        final layout = resolveSvgViewportLayout(
          viewport: ui.Rect.fromLTWH(0, 0, svgWidth, svgHeight),
          sourceSize: ui.Size(viewBox.width, viewBox.height),
          preserveAspectRatio:
              svgNode.getAttributeValue('preserveAspectRatio')?.toString(),
        );

        // Compute viewBox to viewport transform
        final scaleX = layout.destinationRect.width / viewBox.width;
        final scaleY = layout.destinationRect.height / viewBox.height;
        final translateX = layout.destinationRect.left - viewBox.left * scaleX;
        final translateY = layout.destinationRect.top - viewBox.top * scaleY;

        final transform = Matrix4.identity()
          ..translateByDouble(translateX, translateY, 0, 1)
          ..scaleByDouble(scaleX, scaleY, 1, 1);
        canvas.transform(transform.storage);

        // Clip if slice mode or overflow hidden
        final overflow =
            svgNode.getAttributeValue('overflow')?.toString().toLowerCase();
        if (layout.clipToViewport || overflow != 'visible') {
          canvas.clipRect(
            ui.Rect.fromLTWH(
              viewBox.left,
              viewBox.top,
              viewBox.width,
              viewBox.height,
            ),
            doAntiAlias: true,
          );
        }
      }
    } else {
      // No viewBox - clip to SVG dimensions if overflow is hidden
      final overflow =
          svgNode.getAttributeValue('overflow')?.toString().toLowerCase();
      if (overflow != 'visible') {
        canvas.clipRect(
          ui.Rect.fromLTWH(0, 0, svgWidth, svgHeight),
          doAntiAlias: true,
        );
      }
    }
  }

  ui.Rect? _parseForeignObjectViewBox(String viewBoxStr) {
    final parts = viewBoxStr.trim().split(RegExp(r'[\s,]+'));
    if (parts.length < 4) return null;
    final minX = double.tryParse(parts[0]);
    final minY = double.tryParse(parts[1]);
    final width = double.tryParse(parts[2]);
    final height = double.tryParse(parts[3]);
    if (minX == null || minY == null || width == null || height == null) {
      return null;
    }
    return ui.Rect.fromLTWH(minX, minY, width, height);
  }

  void _paintUse(
    ui.Canvas canvas,
    SvgNode node, {
    required Set<String> useStack,
  }) {
    final hrefId = _extractHrefId(node);
    if (hrefId == null || hrefId.isEmpty || useStack.contains(hrefId)) {
      return;
    }

    // Limit recursion depth for nested <use> elements (Blink limits to ~10).
    if (useStack.length >= _kMaxUseRecursionDepth) {
      return;
    }

    final referenced = document.root.findById(hrefId);
    if (referenced == null || !_isUseReferenceAllowedTag(referenced.tagName)) {
      return;
    }

    final x = _getNumber(node, 'x') ?? 0.0;
    final y = _getNumber(node, 'y') ?? 0.0;

    canvas.save();
    canvas.translate(x, y);

    final previousParent = referenced.parent;
    referenced.parent = node;
    try {
      final nextUseStack = <String>{...useStack, hrefId};
      if (referenced.tagName == 'symbol') {
        _paintSymbolReference(
          canvas,
          useNode: node,
          symbolNode: referenced,
          useStack: nextUseStack,
        );
      } else if (referenced.tagName == 'svg') {
        _paintSvgUseReference(
          canvas,
          useNode: node,
          svgNode: referenced,
          useStack: nextUseStack,
        );
      } else {
        _paintNode(canvas, referenced, useStack: nextUseStack);
      }
    } finally {
      referenced.parent = previousParent;
    }

    canvas.restore();
  }

  void _paintSymbolReference(
    ui.Canvas canvas, {
    required SvgNode useNode,
    required SvgNode symbolNode,
    required Set<String> useStack,
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
    }

    for (final child in symbolNode.children) {
      _paintNode(canvas, child, useStack: useStack);
    }
  }

  void _paintSvgUseReference(
    ui.Canvas canvas, {
    required SvgNode useNode,
    required SvgNode svgNode,
    required Set<String> useStack,
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

    _paintNode(canvas, svgNode, useStack: useStack);
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
        // Check requiredExtensions - if specified, don't render children
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
