/// The strategy used to render an SVG widget.
///
/// Retained for source compatibility with the `flutter_svg`-style API. The
/// renderer in `full_svg_flutter` always paints vector content directly to the
/// canvas and caches the result in a repaint boundary, so this value now acts
/// only as a hint and does not change rendering behaviour.
enum RenderingStrategy {
  /// Paint the SVG as vector content.
  picture,

  /// Rasterize the SVG.
  raster,
}
