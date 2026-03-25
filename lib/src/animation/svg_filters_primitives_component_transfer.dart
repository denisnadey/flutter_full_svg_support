part of 'svg_filters.dart';

/// Parameters for a single channel function (`feFuncR/G/B/A`) for feComponentTransfer.
class SvgComponentTransferFunction {
  const SvgComponentTransferFunction({
    required this.type,
    this.tableValues = const <double>[],
    this.slope = 1.0,
    this.intercept = 0.0,
    this.amplitude = 1.0,
    this.exponent = 1.0,
    this.offset = 0.0,
  });

  /// Default identity function (no change).
  static const SvgComponentTransferFunction identity =
      SvgComponentTransferFunction(type: SvgComponentTransferType.identity);

  final SvgComponentTransferType type;
  final List<double> tableValues;
  final double slope;
  final double intercept;
  final double amplitude;
  final double exponent;
  final double offset;

  /// Applies the transfer function to a normalized value [0..1].
  /// Returns the result clamped to [0..1].
  double apply(double value) {
    final clamped = value.clamp(0.0, 1.0);
    final result = switch (type) {
      SvgComponentTransferType.identity => clamped,
      SvgComponentTransferType.linear => _applyLinear(clamped),
      SvgComponentTransferType.gamma => _applyGamma(clamped),
      SvgComponentTransferType.table => _applyTable(clamped),
      SvgComponentTransferType.discrete => _applyDiscrete(clamped),
    };
    return result.clamp(0.0, 1.0);
  }

  /// Linear: C' = slope * C + intercept
  double _applyLinear(double c) => slope * c + intercept;

  /// Gamma: C' = amplitude * pow(C, exponent) + offset
  double _applyGamma(double c) {
    if (c <= 0.0) return offset.clamp(0.0, 1.0);
    return amplitude * math.pow(c, exponent) + offset;
  }

  /// Table: piecewise linear interpolation using tableValues.
  /// For n values, there are n-1 intervals covering [0..1].
  double _applyTable(double c) {
    if (tableValues.isEmpty) return c;
    if (tableValues.length == 1) return tableValues[0];

    final n = tableValues.length;
    final k = (c * (n - 1)).clamp(0.0, (n - 1).toDouble());
    final i = k.floor().clamp(0, n - 2);
    final f = k - i;
    return tableValues[i] * (1.0 - f) + tableValues[i + 1] * f;
  }

  /// Discrete: step function using tableValues.
  /// For n values, input is divided into n equal intervals.
  double _applyDiscrete(double c) {
    if (tableValues.isEmpty) return c;

    final n = tableValues.length;
    final i = (c * n).floor().clamp(0, n - 1);
    return tableValues[i];
  }

  /// Whether this function is effectively an identity (no change).
  bool get isIdentity {
    if (type == SvgComponentTransferType.identity) return true;
    if (type == SvgComponentTransferType.linear) {
      return (slope - 1.0).abs() < 0.00001 && intercept.abs() < 0.00001;
    }
    if (type == SvgComponentTransferType.gamma) {
      return (amplitude - 1.0).abs() < 0.00001 &&
          (exponent - 1.0).abs() < 0.00001 &&
          offset.abs() < 0.00001;
    }
    return false;
  }
}

/// feComponentTransfer primitive
///
/// Applies per-channel transfer functions to each pixel.
/// Each channel (R, G, B, A) can have a different transfer function type.
class SvgComponentTransferFilter extends SvgFilter {
  final SvgComponentTransferFunction? funcR;
  final SvgComponentTransferFunction? funcG;
  final SvgComponentTransferFunction? funcB;
  final SvgComponentTransferFunction? funcA;

  SvgComponentTransferFilter({
    required super.id,
    this.funcR,
    this.funcG,
    this.funcB,
    this.funcA,
    super.input,
    super.resultName,
  }) : super(type: SvgFilterType.componentTransfer);

  /// Effective function for red channel (defaults to identity).
  SvgComponentTransferFunction get effectiveFuncR =>
      funcR ?? SvgComponentTransferFunction.identity;

  /// Effective function for green channel (defaults to identity).
  SvgComponentTransferFunction get effectiveFuncG =>
      funcG ?? SvgComponentTransferFunction.identity;

  /// Effective function for blue channel (defaults to identity).
  SvgComponentTransferFunction get effectiveFuncB =>
      funcB ?? SvgComponentTransferFunction.identity;

  /// Effective function for alpha channel (defaults to identity).
  SvgComponentTransferFunction get effectiveFuncA =>
      funcA ?? SvgComponentTransferFunction.identity;

  /// Whether all channels are effectively identity (no change).
  bool get isIdentity =>
      effectiveFuncR.isIdentity &&
      effectiveFuncG.isIdentity &&
      effectiveFuncB.isIdentity &&
      effectiveFuncA.isIdentity;

  /// Creates a ColorFilter matrix for linear-only transforms.
  ///
  /// Returns null if any channel uses table, discrete, or gamma functions.
  /// In that case, use the full pixel-by-pixel processing.
  ui.ColorFilter? linearColorFilter() {
    final r = effectiveFuncR;
    final g = effectiveFuncG;
    final b = effectiveFuncB;
    final a = effectiveFuncA;

    // Only identity and linear can be expressed as a color matrix
    final canUseMatrix =
        (r.type == SvgComponentTransferType.identity ||
            r.type == SvgComponentTransferType.linear) &&
        (g.type == SvgComponentTransferType.identity ||
            g.type == SvgComponentTransferType.linear) &&
        (b.type == SvgComponentTransferType.identity ||
            b.type == SvgComponentTransferType.linear) &&
        (a.type == SvgComponentTransferType.identity ||
            a.type == SvgComponentTransferType.linear);

    if (!canUseMatrix) return null;

    // Extract slope/intercept (identity = slope:1, intercept:0)
    final rSlope = r.type == SvgComponentTransferType.identity ? 1.0 : r.slope;
    final rInt = r.type == SvgComponentTransferType.identity
        ? 0.0
        : r.intercept;
    final gSlope = g.type == SvgComponentTransferType.identity ? 1.0 : g.slope;
    final gInt = g.type == SvgComponentTransferType.identity
        ? 0.0
        : g.intercept;
    final bSlope = b.type == SvgComponentTransferType.identity ? 1.0 : b.slope;
    final bInt = b.type == SvgComponentTransferType.identity
        ? 0.0
        : b.intercept;
    final aSlope = a.type == SvgComponentTransferType.identity ? 1.0 : a.slope;
    final aInt = a.type == SvgComponentTransferType.identity
        ? 0.0
        : a.intercept;

    // ColorFilter.matrix expects a 4x5 row-major matrix:
    // [R'] = [m0  m1  m2  m3  m4 ] [R]
    // [G'] = [m5  m6  m7  m8  m9 ] [G]
    // [B'] = [m10 m11 m12 m13 m14] [B]
    // [A'] = [m15 m16 m17 m18 m19] [A]
    //                              [1]
    return ui.ColorFilter.matrix(<double>[
      rSlope, 0, 0, 0, rInt, // Red row
      0, gSlope, 0, 0, gInt, // Green row
      0, 0, bSlope, 0, bInt, // Blue row
      0, 0, 0, aSlope, aInt, // Alpha row
    ]);
  }

  /// Transform a single pixel color using the transfer functions.
  ui.Color transformPixel(ui.Color color) {
    final r = effectiveFuncR.apply(color.r);
    final g = effectiveFuncG.apply(color.g);
    final b = effectiveFuncB.apply(color.b);
    final a = effectiveFuncA.apply(color.a);
    return ui.Color.from(alpha: a, red: r, green: g, blue: b);
  }

  @override
  ui.ImageFilter? apply() => null;
}

/// Paint pass for feComponentTransfer that requires pixel-level processing.
///
/// Used when transfer functions include table, discrete, or gamma types
/// that cannot be expressed as a simple color matrix.
class SvgComponentTransferPaintPass extends SvgFilterPaintPass {
  const SvgComponentTransferPaintPass({
    required this.transferFilter,
    super.imageFilter,
    super.colorFilter,
    super.blendMode,
    super.offset,
    super.paintFill,
    super.paintStroke,
  });

  /// The component transfer filter configuration.
  final SvgComponentTransferFilter transferFilter;

  @override
  SvgFilterPaintPass copyWith({
    ui.ImageFilter? imageFilter,
    ui.ColorFilter? colorFilter,
    ui.BlendMode? blendMode,
    ui.Offset? offset,
    bool? paintFill,
    bool? paintStroke,
  }) {
    return SvgComponentTransferPaintPass(
      transferFilter: transferFilter,
      imageFilter: imageFilter ?? this.imageFilter,
      colorFilter: colorFilter ?? this.colorFilter,
      blendMode: blendMode ?? this.blendMode,
      offset: offset ?? this.offset,
      paintFill: paintFill ?? this.paintFill,
      paintStroke: paintStroke ?? this.paintStroke,
    );
  }
}
