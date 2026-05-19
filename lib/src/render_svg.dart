import 'dart:ui' as ui;

import 'animation/animated_svg_painter.dart';
import 'animation/svg_dom.dart';
import 'animation/svg_parser.dart';
import 'animation/svg_theme_apply.dart';
import 'svg_theme.dart';

/// A rendered SVG picture together with its natural size.
///
/// Replaces the `PictureInfo` type that earlier versions re-exported from the
/// `vector_graphics` package.
class PictureInfo {
  /// Creates a [PictureInfo].
  const PictureInfo({required this.picture, required this.size});

  /// The recorded vector content of the SVG.
  final ui.Picture picture;

  /// The size, in logical pixels, the [picture] was recorded at.
  final ui.Size size;

  /// Releases the native resources held by [picture].
  void dispose() => picture.dispose();
}

/// Returns the intrinsic size of [document] in logical pixels.
///
/// Prefers the `viewBox`, then the declared `width`/`height`, and finally
/// falls back to a 1x1 size when the document declares no dimensions.
ui.Size svgIntrinsicSize(SvgDocument document) {
  final viewBox = document.viewBox;
  if (viewBox != null && viewBox.width > 0 && viewBox.height > 0) {
    return viewBox.size;
  }
  final width = document.width;
  final height = document.height;
  if (width != null && height != null && width > 0 && height > 0) {
    return ui.Size(width, height);
  }
  return const ui.Size(1, 1);
}

/// Parses [rawSvg] and records it into a [ui.Picture].
///
/// When [size] is omitted the SVG is recorded at its intrinsic size. Pass a
/// [theme] to control `currentColor` and font-relative units, and a
/// [colorMapper] to substitute colors while parsing.
///
/// The returned [PictureInfo] owns a native [ui.Picture]; call
/// [PictureInfo.dispose] when finished with it.
PictureInfo renderSvgToPicture(
  String rawSvg, {
  ui.Size? size,
  SvgTheme? theme,
  ColorMapper? colorMapper,
}) {
  final document = SvgParser.parse(rawSvg);
  applySvgTheme(document, theme: theme, colorMapper: colorMapper);

  final renderSize = size ?? svgIntrinsicSize(document);
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  AnimatedSvgPainter(
    document: document,
    hasAnimations: false,
  ).paint(canvas, renderSize);

  return PictureInfo(picture: recorder.endRecording(), size: renderSize);
}
