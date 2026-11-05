part of 'animated_svg_painter.dart';

/// The fill and stroke of an SVG 2 context element, captured for the
/// `context-fill` / `context-stroke` paint keywords.
///
/// Inside a marker the context element is the shape that references the
/// marker; inside `<use>` content it is the `<use>` element
/// (https://www.w3.org/TR/SVG2/painting.html#SpecifyingPaint).
///
/// Colors are resolved when the context is captured, so `currentColor` and
/// CSS variables use the context element's values, not the marker's.
class _ContextPaint {
  const _ContextPaint({
    required this.fill,
    required this.stroke,
    required this.bounds,
  });

  /// The context fill: a [ui.Color], a paint-server reference such as
  /// `url(#g)`, or `'none'`.
  final Object fill;

  /// The context stroke, in the same form as [fill].
  final Object stroke;

  /// The context element's bounding box, used for objectBoundingBox paint
  /// servers.
  final ui.Rect bounds;
}

/// A paint value after `context-fill` / `context-stroke` substitution.
typedef _ResolvedContextPaintValue = ({Object value, ui.Rect? bounds});

extension AnimatedSvgPainterContextPaintExtension on AnimatedSvgPainter {
  /// Substitutes the current context element's paint for a `context-fill`
  /// or `context-stroke` [value]. Returns `null` when [value] is neither
  /// keyword. Without a context element both keywords mean `none`.
  _ResolvedContextPaintValue? _resolveContextPaintValue(Object? value) {
    if (value is! String) {
      return null;
    }
    final keyword = value.trim().toLowerCase();
    if (keyword != 'context-fill' && keyword != 'context-stroke') {
      return null;
    }
    final context = _currentContextPaint;
    if (context == null) {
      return (value: 'none', bounds: null);
    }
    return (
      value: keyword == 'context-fill' ? context.fill : context.stroke,
      bounds: context.bounds,
    );
  }

  /// The inherited `fill` or `stroke` of [node], with `context-fill` and
  /// `context-stroke` replaced by the current context element's paint.
  Object? _getInheritedPaintValue(SvgNode node, String property) {
    final value = _getInheritedAttributeValue(node, property);
    return _resolveContextPaintValue(value)?.value ?? value;
  }

  /// Captures [node]'s fill and stroke as the context paint.
  _ContextPaint _captureContextPaint(SvgNode node, ui.Rect bounds) {
    return _ContextPaint(
      // The initial fill is black; the initial stroke is none.
      fill: _captureContextPaintValue(
        node,
        'fill',
        fallback: const ui.Color(0xFF000000),
      ),
      stroke: _captureContextPaintValue(node, 'stroke', fallback: 'none'),
      bounds: bounds,
    );
  }

  Object _captureContextPaintValue(
    SvgNode node,
    String property, {
    required Object fallback,
  }) {
    final value = _getInheritedAttributeValue(node, property);
    // A context element whose own paint is a context keyword (a marker
    // shape inside `<use>` content, say) takes the enclosing context's.
    final outer = _resolveContextPaintValue(value);
    if (outer != null) {
      return outer.value;
    }
    if (value == null) {
      return fallback;
    }
    if (_isPaintNone(value)) {
      return 'none';
    }
    if (_extractPaintServerId(value) != null) {
      return value;
    }
    final source = _findInheritedAttributeSourceNode(node, property) ?? node;
    return _resolveColorForNode(value, source) ?? fallback;
  }

  /// Runs [paint] with [node] as the context element for `context-fill`
  /// and `context-stroke`.
  void _withContextPaint(SvgNode node, ui.Rect bounds, void Function() paint) {
    final previous = _currentContextPaint;
    _currentContextPaint = _captureContextPaint(node, bounds);
    try {
      paint();
    } finally {
      _currentContextPaint = previous;
    }
  }
}
