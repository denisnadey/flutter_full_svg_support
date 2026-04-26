part of 'animated_svg_picture.dart';

enum _TextAnchor { start, middle, end }

enum _TextLengthAdjust { spacing, spacingAndGlyphs }

/// SVG textPath spacing attribute values for hit-testing.
enum _TextPathSpacing { auto, exact }

class _HitTextCursor {
  _HitTextCursor({required this.x, required this.y});

  double x;
  double y;

  /// Character index for consuming multi-position attribute lists.
  int charIndex = 0;
}

class _TextMeasure {
  const _TextMeasure({
    required this.width,
    required this.height,
    required this.alphabeticBaseline,
    required this.fontSize,
    this.textDirection = TextDirection.ltr,
  });

  final double width;
  final double height;
  final double alphabeticBaseline;
  final double fontSize;
  final TextDirection textDirection;

  _TextMeasure copyWith({
    double? width,
    double? height,
    double? alphabeticBaseline,
    double? fontSize,
    TextDirection? textDirection,
  }) {
    return _TextMeasure(
      width: width ?? this.width,
      height: height ?? this.height,
      alphabeticBaseline: alphabeticBaseline ?? this.alphabeticBaseline,
      fontSize: fontSize ?? this.fontSize,
      textDirection: textDirection ?? this.textDirection,
    );
  }
}

enum _TextDominantBaseline {
  alphabetic,
  central,
  textBeforeEdge,
  textAfterEdge,
}

class _TextHitRun {
  const _TextHitRun.bounds({
    required this.owner,
    required Rect this.bounds,
    this.rotation = 0.0,
    this.rotationCenter = Offset.zero,
  }) : path = null,
       pathTolerance = 0.0;

  const _TextHitRun.path({
    required this.owner,
    required Path this.path,
    required this.pathTolerance,
  }) : bounds = null,
       rotation = 0.0,
       rotationCenter = Offset.zero;

  final SvgNode owner;
  final Rect? bounds;
  final Path? path;
  final double pathTolerance;

  /// Rotation angle in degrees (for per-character rotation).
  final double rotation;

  /// Center point for rotation (baseline position).
  final Offset rotationCenter;
}
