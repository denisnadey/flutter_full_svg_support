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

  /// Maximum exponent value to prevent numerical overflow.
  static const double _maxExponent = 100.0;

  /// Minimum positive value for gamma input to prevent log(0).
  static const double _minGammaInput = 1e-10;

  /// Maximum amplitude to prevent overflow in gamma function.
  static const double _maxAmplitude = 1e6;

  /// Applies the transfer function to a normalized value [0..1].
  /// Returns the result clamped to [0..1].
  double apply(double value) {
    // Input clamping per SVG spec
    final clamped = value.clamp(0.0, 1.0);
    final result = switch (type) {
      SvgComponentTransferType.identity => clamped,
      SvgComponentTransferType.linear => _applyLinear(clamped),
      SvgComponentTransferType.gamma => _applyGamma(clamped),
      SvgComponentTransferType.table => _applyTable(clamped),
      SvgComponentTransferType.discrete => _applyDiscrete(clamped),
    };
    // Output clamping per SVG spec - always clamp to [0, 1]
    return result.clamp(0.0, 1.0);
  }

  /// Linear: C' = slope * C + intercept
  double _applyLinear(double c) => slope * c + intercept;

  /// Gamma: C' = amplitude * pow(C, exponent) + offset
  ///
  /// Edge cases handled:
  /// - c <= 0: Returns offset (pow(0, x) = 0 for x > 0, undefined for x <= 0)
  /// - Very large exponents: Clamped to prevent overflow
  /// - Very small exponents: Handled with precision
  /// - Large amplitude: Clamped to prevent overflow
  double _applyGamma(double c) {
    // Handle c = 0 case to avoid pow(0, negative) issues
    if (c <= _minGammaInput) {
      // For c ≈ 0, pow(c, exp) → 0 for positive exp, → infinity for negative
      // Clamp the result to offset for safety
      return offset.clamp(0.0, 1.0);
    }

    // Clamp exponent to prevent extreme values
    final safeExponent = exponent.clamp(-_maxExponent, _maxExponent);

    // Clamp amplitude to prevent overflow
    final safeAmplitude = amplitude.clamp(-_maxAmplitude, _maxAmplitude);

    // Compute gamma with safe values
    final powResult = math.pow(c, safeExponent);

    // Check for infinity/NaN from pow operation
    if (powResult.isInfinite || powResult.isNaN) {
      // Return clamped offset as fallback
      return offset.clamp(0.0, 1.0);
    }

    return safeAmplitude * powResult + offset;
  }

  /// Table: piecewise linear interpolation using tableValues.
  /// For n values, there are n-1 intervals covering [0..1].
  ///
  /// Edge cases handled:
  /// - Empty tableValues: Returns input unchanged (identity)
  /// - Single value: Returns that value for all inputs
  double _applyTable(double c) {
    if (tableValues.isEmpty) return c;
    if (tableValues.length == 1) return tableValues[0].clamp(0.0, 1.0);

    final n = tableValues.length;
    // Map input [0, 1] to [0, n-1] range for interpolation
    final k = (c * (n - 1)).clamp(0.0, (n - 1).toDouble());
    final i = k.floor().clamp(0, n - 2);
    final f = k - i;

    // Linear interpolation between adjacent table values
    return tableValues[i] * (1.0 - f) + tableValues[i + 1] * f;
  }

  /// Discrete: step function using tableValues.
  /// For n values, input is divided into n equal intervals.
  ///
  /// Edge cases handled:
  /// - Empty tableValues: Returns input unchanged (identity)
  /// - Single value: Returns that value for all inputs
  /// - Input = 1.0: Returns last table value (clamped index)
  double _applyDiscrete(double c) {
    if (tableValues.isEmpty) return c;
    if (tableValues.length == 1) return tableValues[0].clamp(0.0, 1.0);

    final n = tableValues.length;
    // Map input [0, 1) to indices [0, n-1]
    // Use floor and clamp to handle edge case where c = 1.0
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

  /// Creates a pre-computed lookup table for fast pixel processing.
  ///
  /// Returns a 256-entry table where index i maps to the transformed value
  /// for input i/255. Values are pre-clamped to [0, 255] as integers.
  ///
  /// This is useful for table and discrete functions where the same
  /// computation would be repeated for many pixels.
  List<int> buildLookupTable() {
    final table = List<int>.filled(256, 0);
    const normalizer = 1.0 / 255.0;

    for (int i = 0; i < 256; i++) {
      final input = i * normalizer;
      final output = apply(input);
      table[i] = (output * 255.0).round().clamp(0, 255);
    }

    return table;
  }
}

/// feComponentTransfer primitive
///
/// Applies per-channel transfer functions to each pixel.
/// Each channel (R, G, B, A) can have a different transfer function type.
class SvgComponentTransferFilter extends SvgFilter {
  SvgComponentTransferFunction? funcR;
  SvgComponentTransferFunction? funcG;
  SvgComponentTransferFunction? funcB;
  SvgComponentTransferFunction? funcA;

  // Cached lookup tables for optimized pixel processing
  List<int>? _lookupR;
  List<int>? _lookupG;
  List<int>? _lookupB;
  List<int>? _lookupA;

  SvgComponentTransferFilter({
    required super.id,
    this.funcR,
    this.funcG,
    this.funcB,
    this.funcA,
    super.input,
    super.resultName,
  }) : super(type: SvgFilterType.componentTransfer);

  /// Updates per-channel transfer functions and invalidates cached lookup
  /// tables so subsequent paint passes use the latest animated values.
  void updateFunctions({
    SvgComponentTransferFunction? funcR,
    SvgComponentTransferFunction? funcG,
    SvgComponentTransferFunction? funcB,
    SvgComponentTransferFunction? funcA,
  }) {
    this.funcR = funcR;
    this.funcG = funcG;
    this.funcB = funcB;
    this.funcA = funcA;
    _lookupR = null;
    _lookupG = null;
    _lookupB = null;
    _lookupA = null;
  }

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

  /// Returns pre-computed lookup table for red channel.
  /// Lazily builds the table on first access.
  List<int> get lookupTableR => _lookupR ??= effectiveFuncR.buildLookupTable();

  /// Returns pre-computed lookup table for green channel.
  List<int> get lookupTableG => _lookupG ??= effectiveFuncG.buildLookupTable();

  /// Returns pre-computed lookup table for blue channel.
  List<int> get lookupTableB => _lookupB ??= effectiveFuncB.buildLookupTable();

  /// Returns pre-computed lookup table for alpha channel.
  List<int> get lookupTableA => _lookupA ??= effectiveFuncA.buildLookupTable();

  /// Creates a ColorFilter matrix for linear-only transforms.
  ///
  /// Returns null if any channel uses table, discrete, or gamma functions.
  /// In that case, use the full pixel-by-pixel processing or lookup tables.
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
    final rSlope = r.type == SvgComponentTransferType.identity
        ? 1.0
        : _adjustLinearSlopeForPremultiplied(r.slope);
    final rInt = r.type == SvgComponentTransferType.identity
        ? 0.0
        : r.intercept;
    final gSlope = g.type == SvgComponentTransferType.identity
        ? 1.0
        : _adjustLinearSlopeForPremultiplied(g.slope);
    final gInt = g.type == SvgComponentTransferType.identity
        ? 0.0
        : g.intercept;
    final bSlope = b.type == SvgComponentTransferType.identity
        ? 1.0
        : _adjustLinearSlopeForPremultiplied(b.slope);
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

  /// Flutter's color filter pipeline operates on premultiplied pixels.
  /// For slope>1 this tends to over-brighten semi-transparent edges compared
  /// to SVG's unpremultiplied component-transfer behavior, so attenuate boost.
  static double _adjustLinearSlopeForPremultiplied(double slope) {
    if (slope <= 1.0) return slope;
    const compensation = 0.40;
    return 1.0 + (slope - 1.0) * compensation;
  }

  /// Transform a single pixel color using the transfer functions.
  ///
  /// For better performance with many pixels, use [transformPixelFast]
  /// with pre-computed lookup tables.
  ui.Color transformPixel(ui.Color color) {
    final r = effectiveFuncR.apply(color.r);
    final g = effectiveFuncG.apply(color.g);
    final b = effectiveFuncB.apply(color.b);
    final a = effectiveFuncA.apply(color.a);
    return ui.Color.from(alpha: a, red: r, green: g, blue: b);
  }

  /// Transform pixel using pre-computed lookup tables for optimal performance.
  ///
  /// [r], [g], [b], [a] are 0-255 integer values.
  /// Returns transformed values as [r, g, b, a] integers 0-255.
  List<int> transformPixelFast(int r, int g, int b, int a) {
    return <int>[
      lookupTableR[r.clamp(0, 255)],
      lookupTableG[g.clamp(0, 255)],
      lookupTableB[b.clamp(0, 255)],
      lookupTableA[a.clamp(0, 255)],
    ];
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
