part of 'animated_svg_painter.dart';

extension AnimatedSvgPainterUseExtension on AnimatedSvgPainter {
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

  void _paintUse(
    ui.Canvas canvas,
    SvgNode node, {
    required Set<String> useStack,
  }) {
    final hrefId = _extractHrefId(node);
    if (hrefId == null || hrefId.isEmpty || useStack.contains(hrefId)) {
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
        final width = _getNumber(node, 'width') ?? 0.0;
        final height = _getNumber(node, 'height') ?? 0.0;
        return width > 0 && height > 0;
      default:
        return true;
    }
  }
}
