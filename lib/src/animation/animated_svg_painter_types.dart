part of 'animated_svg_painter.dart';

enum _GradientAxis { x, y, radius }

class _GradientLength {
  const _GradientLength(this.value, this.isPercent);

  final double value;
  final bool isPercent;
}

class _UseViewportTransform {
  const _UseViewportTransform({required this.matrix, required this.clipRect});

  final Matrix4 matrix;
  final ui.Rect? clipRect;
}

class _GradientStop {
  const _GradientStop({required this.offset, required this.color});

  final double offset;
  final ui.Color color;
}

class _ResolvedGradientDefinition {
  const _ResolvedGradientDefinition({
    required this.type,
    required this.attributes,
    required this.stops,
    this.useLinearRGB = false,
  });

  final String type;
  final Map<String, Object?> attributes;
  final List<_GradientStop> stops;
  final bool useLinearRGB;
}

class _TextCursor {
  _TextCursor({required this.x, required this.y});

  double x;
  double y;

  /// Character index for consuming multi-position attribute lists.
  int charIndex = 0;

  /// Character index within the current text chunk (for text-anchor calculation).
  int chunkCharIndex = 0;

  /// Whether this is the first line of text (for text-indent).
  bool isFirstLine = false;
}

enum _SvgTextAnchor { start, middle, end }

/// SVG dominant-baseline and alignment-baseline attribute values.
enum _SvgDominantBaseline {
  /// Default alphabetic baseline.
  alphabetic,

  /// Central baseline (middle of em box).
  central,

  /// Top of em box.
  textBeforeEdge,

  /// Bottom of em box.
  textAfterEdge,

  /// Hanging baseline (for Indic scripts, ~80% of ascent).
  hanging,

  /// Mathematical baseline (centered on operators, ~50% of x-height).
  mathematical,

  /// Ideographic baseline (for CJK, at bottom of em box).
  ideographic,

  /// Middle baseline (deprecated, same as central).
  middle,
}

enum _SvgTextLengthAdjust { spacing, spacingAndGlyphs }

/// SVG textPath spacing attribute values.
enum _SvgTextPathSpacing { auto, exact }

/// SVG textPath method attribute values.
/// - align: Glyphs are aligned with the path (default)
/// - stretch: Glyphs are stretched/compressed to fit the path
enum _SvgTextPathMethod { align, stretch }

/// SVG text-decoration line types.
enum _SvgTextDecoration { underline, overline, lineThrough }

/// SVG writing-mode attribute values.
enum _SvgWritingMode { horizontalTb, verticalRl, verticalLr }

/// Unicode bidirectional category for text direction detection.
enum _BidiCategory { l, r, al, en, other }

/// A run of text with consistent directionality.
class _BidiRun {
  const _BidiRun({
    required this.text,
    required this.direction,
    required this.start,
    required this.end,
  });

  final String text;
  final ui.TextDirection direction;
  final int start;
  final int end;
}

/// SVG markerUnits attribute values.
enum _SvgMarkerUnits { userSpaceOnUse, strokeWidth }

/// SVG marker orient attribute values.
enum _SvgMarkerOrient { auto, autoStartReverse, angle }

/// Resolved marker definition.
class _ResolvedMarkerDefinition {
  const _ResolvedMarkerDefinition({
    required this.node,
    required this.refX,
    required this.refY,
    required this.markerWidth,
    required this.markerHeight,
    required this.markerUnits,
    required this.orient,
    required this.orientAngle,
    this.viewBox,
  });

  final SvgNode node;
  final double refX;
  final double refY;
  final double markerWidth;
  final double markerHeight;
  final _SvgMarkerUnits markerUnits;
  final _SvgMarkerOrient orient;
  final double orientAngle;
  final ui.Rect? viewBox;
}

/// SVG patternUnits / patternContentUnits attribute values.
enum _SvgPatternUnits { userSpaceOnUse, objectBoundingBox }

/// Resolved pattern definition.
class _ResolvedPatternDefinition {
  const _ResolvedPatternDefinition({
    required this.node,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.patternUnits,
    required this.patternContentUnits,
    this.viewBox,
    this.patternTransform,
  });

  final SvgNode node;
  final double x;
  final double y;
  final double width;
  final double height;
  final _SvgPatternUnits patternUnits;
  final _SvgPatternUnits patternContentUnits;
  final ui.Rect? viewBox;
  final Matrix4? patternTransform;
}
