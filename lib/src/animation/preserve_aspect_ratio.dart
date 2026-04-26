import 'dart:math' as math;
import 'dart:ui' as ui;

/// Resolved viewport placement for SVG preserveAspectRatio semantics.
class SvgViewportLayout {
  const SvgViewportLayout({
    required this.destinationRect,
    required this.clipToViewport,
  });

  final ui.Rect destinationRect;
  final bool clipToViewport;
}

/// Resolves an SVG viewport layout according to preserveAspectRatio rules.
///
/// [viewport] is the destination viewport in current coordinates.
/// [sourceSize] is the untransformed source dimensions (e.g. image size or
/// symbol viewBox size).
SvgViewportLayout resolveSvgViewportLayout({
  required ui.Rect viewport,
  required ui.Size sourceSize,
  String? preserveAspectRatio,
}) {
  if (sourceSize.width <= 0 || sourceSize.height <= 0) {
    return SvgViewportLayout(destinationRect: viewport, clipToViewport: false);
  }

  final tokens = (preserveAspectRatio ?? '')
      .trim()
      .split(RegExp(r'\s+'))
      .where((token) => token.isNotEmpty)
      .where((token) => token.toLowerCase() != 'defer')
      .toList();

  final alignToken = tokens.isEmpty ? 'xMidYMid' : tokens.first;
  final fitToken = tokens.length > 1 ? tokens.last.toLowerCase() : 'meet';

  if (alignToken.toLowerCase() == 'none') {
    return SvgViewportLayout(destinationRect: viewport, clipToViewport: false);
  }

  final scaleX = viewport.width / sourceSize.width;
  final scaleY = viewport.height / sourceSize.height;
  final useSlice = fitToken == 'slice';
  final scale = useSlice ? math.max(scaleX, scaleY) : math.min(scaleX, scaleY);

  final drawWidth = sourceSize.width * scale;
  final drawHeight = sourceSize.height * scale;

  final alignLower = alignToken.toLowerCase();
  final alignX = alignLower.contains('xmin')
      ? 0.0
      : alignLower.contains('xmax')
      ? 1.0
      : 0.5;
  final alignY = alignLower.contains('ymin')
      ? 0.0
      : alignLower.contains('ymax')
      ? 1.0
      : 0.5;

  final dx = viewport.left + (viewport.width - drawWidth) * alignX;
  final dy = viewport.top + (viewport.height - drawHeight) * alignY;

  return SvgViewportLayout(
    destinationRect: ui.Rect.fromLTWH(dx, dy, drawWidth, drawHeight),
    clipToViewport: useSlice,
  );
}
