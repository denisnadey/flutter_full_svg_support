part of 'animated_svg_painter.dart';

/// Extension for foreign object handling in use elements.
extension AnimatedSvgPainterUseForeignObjectExtension on AnimatedSvgPainter {
  /// Checks if foreignObject should be rendered based on requiredExtensions.
  bool _shouldRenderForeignObject(SvgNode node) {
    if (node.tagName != 'foreignObject') {
      return true;
    }
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
    final overflow = _getInheritedString(node, 'overflow')?.toLowerCase();
    if (overflow != 'visible') {
      canvas.clipRect(ui.Rect.fromLTWH(0, 0, width, height), doAntiAlias: true);
    }
  }

  /// Applies nested SVG viewport transform within foreignObject.
  ///
  /// This method establishes an independent viewport for nested SVG elements:
  /// - The nested SVG's viewBox is resolved relative to the foreignObject's
  ///   width/height (or the nested SVG's explicit dimensions)
  /// - Coordinate system transformations reset at the nested SVG boundary
  /// - The nested SVG's overflow attribute is respected
  /// - Percentage-based dimensions on nested SVG are resolved against
  ///   the foreignObject viewport
  ///
  /// Delegates transform computation to [_computeForeignObjectNestedSvgTransform]
  /// which correctly handles all preserveAspectRatio values.
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
    final foWidth = _getNumber(foreignObjectParent, 'width') ?? 0.0;
    final foHeight = _getNumber(foreignObjectParent, 'height') ?? 0.0;
    if (foWidth <= 0 || foHeight <= 0) {
      return;
    }

    // Handle nested SVG position (x, y)
    final svgX = _getNumber(svgNode, 'x') ?? 0.0;
    final svgY = _getNumber(svgNode, 'y') ?? 0.0;

    // Resolve nested SVG dimensions - support percentages relative to foreignObject
    final svgWidth =
        _resolveForeignObjectNestedDimension(svgNode, 'width', foWidth) ??
        foWidth;
    final svgHeight =
        _resolveForeignObjectNestedDimension(svgNode, 'height', foHeight) ??
        foHeight;

    if (svgWidth <= 0 || svgHeight <= 0) {
      return;
    }

    // Apply position offset
    if (svgX != 0 || svgY != 0) {
      canvas.translate(svgX, svgY);
    }

    // Use the dedicated transform computation method from shapes_image extension
    // This properly handles all preserveAspectRatio values via _parsePreserveAspectRatioForNested
    final transform = _computeForeignObjectNestedSvgTransform(
      foreignObjectParent,
      svgNode,
    );

    if (transform != null) {
      // Apply the computed transform
      canvas.transform(transform.storage);

      // Get viewBox for clipping calculation
      final viewBoxAttr = svgNode.getAttributeValue('viewBox')?.toString();
      final viewBox = viewBoxAttr != null && viewBoxAttr.trim().isNotEmpty
          ? _parseForeignObjectViewBox(viewBoxAttr)
          : null;

      // Handle overflow clipping for nested SVG
      final overflow = svgNode
          .getAttributeValue('overflow')
          ?.toString()
          .toLowerCase();

      // Default overflow for SVG is 'hidden' unless explicitly set to 'visible'
      if (viewBox != null && overflow != 'visible') {
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
    } else {
      // No viewBox transform needed - apply overflow clipping to SVG viewport
      final overflow = svgNode
          .getAttributeValue('overflow')
          ?.toString()
          .toLowerCase();
      // Default overflow for SVG is 'hidden'
      if (overflow != 'visible') {
        canvas.clipRect(
          ui.Rect.fromLTWH(0, 0, svgWidth, svgHeight),
          doAntiAlias: true,
        );
      }
    }
  }

  /// Resolves a dimension value for nested SVG within foreignObject.
  /// Supports percentage values relative to the foreignObject viewport.
  double? _resolveForeignObjectNestedDimension(
    SvgNode node,
    String attributeName,
    double referenceValue,
  ) {
    final value = node.getAttributeValue(attributeName);
    if (value == null) return null;

    final str = value.toString().trim();
    if (str.isEmpty) return null;

    // Handle percentage values
    if (str.endsWith('%')) {
      final percentStr = str.substring(0, str.length - 1);
      final percent = double.tryParse(percentStr);
      if (percent == null) return null;
      return (percent / 100.0) * referenceValue;
    }

    // Handle absolute values with units
    final cleaned = str.replaceAll(RegExp(r'[a-zA-Z]+$'), '');
    return double.tryParse(cleaned);
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
}
