part of 'svg_filters.dart';

/// Drop Shadow filter
///
/// Creates a drop shadow for an object
class SvgDropShadowFilter extends SvgFilter {
  /// X offset
  double dx;

  /// Y offset
  double dy;

  /// Standard deviation along X (shadow blur)
  double stdDeviationX;

  /// Standard deviation along Y (shadow blur)
  double stdDeviationY;

  /// Shadow color
  final ui.Color? floodColor;

  /// Shadow opacity (0..1)
  final double floodOpacity;

  SvgDropShadowFilter({
    required super.id,
    required this.dx,
    required this.dy,
    required this.stdDeviationX,
    required this.stdDeviationY,
    this.floodColor,
    this.floodOpacity = 1.0,
    super.input,
    super.resultName,
  }) : super(type: SvgFilterType.dropShadow);

  @override
  ui.ImageFilter? apply() {
    return ui.ImageFilter.blur(sigmaX: stdDeviationX, sigmaY: stdDeviationY);
  }

  /// Get the offset for application via transform
  ui.Offset get offset => ui.Offset(dx, dy);

  /// Effective shadow color taking flood-opacity into account.
  ui.Color get effectiveShadowColor {
    final base = floodColor ?? const ui.Color(0xFF000000);
    final opacity = floodOpacity.clamp(0.0, 1.0);
    return base.withValues(alpha: base.a * opacity);
  }

  /// Compatibility with the old API (average across axes).
  double get stdDeviation => (stdDeviationX + stdDeviationY) / 2.0;
}

/// Paint pass for feDropShadow with Blink multi-pass composition data.
///
/// This specialized pass carries the drop shadow configuration to support
/// advanced rendering scenarios where the painter needs access to the
/// original shadow parameters (e.g., for custom shadow rendering effects).
class SvgDropShadowPaintPass extends SvgFilterPaintPass {
  const SvgDropShadowPaintPass({
    required this.shadowFilter,
    super.imageFilter,
    super.colorFilter,
    super.blendMode,
    super.offset,
    super.paintFill,
    super.paintStroke,
  });

  /// The drop shadow filter containing original parameters.
  final SvgDropShadowFilter shadowFilter;

  @override
  SvgFilterPaintPass copyWith({
    ui.ImageFilter? imageFilter,
    ui.ColorFilter? colorFilter,
    ui.BlendMode? blendMode,
    ui.Offset? offset,
    bool? paintFill,
    bool? paintStroke,
  }) {
    return SvgDropShadowPaintPass(
      shadowFilter: shadowFilter,
      imageFilter: imageFilter ?? this.imageFilter,
      colorFilter: colorFilter ?? this.colorFilter,
      blendMode: blendMode ?? this.blendMode,
      offset: offset ?? this.offset,
      paintFill: paintFill ?? this.paintFill,
      paintStroke: paintStroke ?? this.paintStroke,
    );
  }
}

/// Color Matrix filter
///
/// Applies color transformations
class SvgColorMatrixFilter extends SvgFilter {
  /// Transformation type
  final SvgColorMatrixType matrixType;

  /// Matrix values (depend on the type)
  List<double> values;

  SvgColorMatrixFilter({
    required super.id,
    required this.matrixType,
    required this.values,
    super.input,
    super.resultName,
  }) : super(type: SvgFilterType.colorMatrix);

  @override
  ui.ColorFilter? colorFilter() {
    switch (matrixType) {
      case SvgColorMatrixType.matrix:
        if (values.length == 20) {
          return ui.ColorFilter.matrix(_convertSvgMatrixToFlutter(values));
        }
        return null;

      case SvgColorMatrixType.saturate:
        if (values.isNotEmpty) {
          return ui.ColorFilter.matrix(_saturateMatrix(values[0]));
        }
        return null;

      case SvgColorMatrixType.hueRotate:
        if (values.isNotEmpty) {
          return ui.ColorFilter.matrix(_hueRotateMatrix(values[0]));
        }
        return null;

      case SvgColorMatrixType.luminanceToAlpha:
        return ui.ColorFilter.matrix(_luminanceToAlphaMatrix());
    }
  }

  @override
  ui.ImageFilter? apply() => colorFilter();

  /// Converts an SVG 5x4 matrix (20 values) to a Flutter 4x5 matrix (20 values)
  ///
  /// SVG format: row by row (R, G, B, A, 1 for each row)
  /// Flutter format: column by column (RGBA + offset)
  List<double> _convertSvgMatrixToFlutter(List<double> svgMatrix) {
    // SVG matrix (5x4):
    // [Rr Rg Rb Ra Rk]
    // [Gr Gg Gb Ga Gk]
    // [Br Bg Bb Ba Bk]
    // [Ar Ag Ab Aa Ak]
    //
    // Flutter matrix (4x5):
    // [Rr Gr Br Ar] - red column
    // [Rg Gg Bg Ag] - green column
    // [Rb Gb Bb Ab] - blue column
    // [Ra Ga Ba Aa] - alpha column
    // [Rk Gk Bk Ak] - offset row

    final result = <double>[];

    // Red column: Rr, Gr, Br, Ar
    result.addAll([svgMatrix[0], svgMatrix[5], svgMatrix[10], svgMatrix[15]]);

    // Green column: Rg, Gg, Bg, Ag
    result.addAll([svgMatrix[1], svgMatrix[6], svgMatrix[11], svgMatrix[16]]);

    // Blue column: Rb, Gb, Bb, Ab
    result.addAll([svgMatrix[2], svgMatrix[7], svgMatrix[12], svgMatrix[17]]);

    // Alpha column: Ra, Ga, Ba, Aa
    result.addAll([svgMatrix[3], svgMatrix[8], svgMatrix[13], svgMatrix[18]]);

    // Offset row: Rk, Gk, Bk, Ak (divide by 255 because Flutter works in [0-1] while SVG uses [0-255])
    result.addAll([
      svgMatrix[4] / 255.0,
      svgMatrix[9] / 255.0,
      svgMatrix[14] / 255.0,
      svgMatrix[19] / 255.0,
    ]);

    return result;
  }

  /// Creates a matrix for saturation (saturate)
  List<double> _saturateMatrix(double s) {
    // SVG saturate matrix formula (feColorMatrix type="saturate"):
    // [0.213+0.787s, 0.715-0.715s, 0.072-0.072s, 0, 0]
    // [0.213-0.213s, 0.715+0.285s, 0.072-0.072s, 0, 0]
    // [0.213-0.213s, 0.715-0.715s, 0.072+0.928s, 0, 0]
    // [0,            0,            0,            1, 0]
    return [
      0.213 + 0.787 * s,
      0.715 - 0.715 * s,
      0.072 - 0.072 * s,
      0,
      0,
      0.213 - 0.213 * s,
      0.715 + 0.285 * s,
      0.072 - 0.072 * s,
      0,
      0,
      0.213 - 0.213 * s,
      0.715 - 0.715 * s,
      0.072 + 0.928 * s,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
    ];
  }

  /// Creates a matrix for hue rotation
  List<double> _hueRotateMatrix(double degrees) {
    // Convert degrees to radians
    final radians = degrees * 3.141592653589793 / 180.0;
    final cos = math.cos(radians);
    final sin = math.sin(radians);

    // Hue rotation matrix
    return [
      0.213 + cos * 0.787 + sin * -0.213, // Rr
      0.715 + cos * -0.715 + sin * -0.715, // Rg
      0.072 + cos * -0.072 + sin * 0.928, // Rb
      0, 0, // Ra, Rk

      0.213 + cos * -0.213 + sin * 0.143, // Gr
      0.715 + cos * 0.285 + sin * 0.140, // Gg
      0.072 + cos * -0.072 + sin * -0.283, // Gb
      0, 0, // Ga, Gk

      0.213 + cos * -0.213 + sin * -0.787, // Br
      0.715 + cos * -0.715 + sin * 0.715, // Bg
      0.072 + cos * 0.928 + sin * 0.072, // Bb
      0, 0, // Ba, Bk

      0, 0, 0, 1, 0, // Alpha row
    ];
  }

  /// Creates a matrix for luminance to alpha
  List<double> _luminanceToAlphaMatrix() {
    // Luminance weights: 0.2126 * R + 0.7152 * G + 0.0722 * B
    return [
      0, 0, 0, 0, 0, // Red row
      0, 0, 0, 0, 0, // Green row
      0, 0, 0, 0, 0, // Blue row
      0.2126, 0.7152, 0.0722, 0, 0, // Alpha row
    ];
  }
}
