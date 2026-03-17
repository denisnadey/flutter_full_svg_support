part of 'animated_svg_painter.dart';

/// SVG paint-order layer types.
enum _SvgPaintLayer { fill, stroke, markers }

extension AnimatedSvgPainterPaintOrderExtension on AnimatedSvgPainter {
  /// Parses the paint-order attribute and returns the layers in paint order.
  /// Default SVG order is: fill, stroke, markers.
  List<_SvgPaintLayer> _parsePaintOrder(SvgNode node) {
    final paintOrderValue = _getInheritedString(node, 'paint-order');
    if (paintOrderValue == null || paintOrderValue.trim().isEmpty) {
      // Default SVG paint order
      return const <_SvgPaintLayer>[
        _SvgPaintLayer.fill,
        _SvgPaintLayer.stroke,
        _SvgPaintLayer.markers,
      ];
    }

    final normalized = paintOrderValue.trim().toLowerCase();
    if (normalized == 'normal') {
      return const <_SvgPaintLayer>[
        _SvgPaintLayer.fill,
        _SvgPaintLayer.stroke,
        _SvgPaintLayer.markers,
      ];
    }

    // Parse space-separated tokens
    final tokens = normalized.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    final result = <_SvgPaintLayer>[];
    final seen = <_SvgPaintLayer>{};

    for (final token in tokens) {
      _SvgPaintLayer? layer;
      switch (token) {
        case 'fill':
          layer = _SvgPaintLayer.fill;
          break;
        case 'stroke':
          layer = _SvgPaintLayer.stroke;
          break;
        case 'markers':
          layer = _SvgPaintLayer.markers;
          break;
      }
      if (layer != null && !seen.contains(layer)) {
        result.add(layer);
        seen.add(layer);
      }
    }

    // Add any missing layers in default order at the end
    for (final layer in _SvgPaintLayer.values) {
      if (!seen.contains(layer)) {
        result.add(layer);
      }
    }

    return result;
  }

  /// Paints a shape with proper paint-order handling.
  /// [paintFill] callback draws the fill, [paintStroke] draws the stroke,
  /// [paintMarkers] draws the markers (optional, for shapes that support markers).
  void _paintWithOrder(
    SvgNode node,
    void Function() paintFill,
    void Function() paintStroke, {
    void Function()? paintMarkers,
  }) {
    final order = _parsePaintOrder(node);
    for (final layer in order) {
      switch (layer) {
        case _SvgPaintLayer.fill:
          paintFill();
          break;
        case _SvgPaintLayer.stroke:
          paintStroke();
          break;
        case _SvgPaintLayer.markers:
          paintMarkers?.call();
          break;
      }
    }
  }
}
