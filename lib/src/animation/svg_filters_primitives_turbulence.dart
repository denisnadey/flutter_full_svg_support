part of 'svg_filters.dart';

/// feTurbulence primitive
///
/// Generates Perlin noise with fractal octaves for procedural texture generation.
/// Implements SVG Filter 1.1 feTurbulence with full numOctaves support.
class SvgTurbulenceFilter extends SvgFilter {
  /// Базовая частота шума по X/Y.
  final double baseFrequencyX;
  final double baseFrequencyY;

  /// Количество октав для фрактального шума.
  /// Each additional octave adds finer detail at half the amplitude.
  final int numOctaves;

  /// Seed генератора шума.
  final double seed;

  /// Режим тайлинга.
  final SvgTurbulenceStitchTiles stitchTiles;

  /// Тип функции шума.
  final SvgTurbulenceType noiseType;

  SvgTurbulenceFilter({
    required super.id,
    required this.baseFrequencyX,
    required this.baseFrequencyY,
    required this.numOctaves,
    required this.seed,
    required this.stitchTiles,
    required this.noiseType,
    super.input,
    super.resultName,
  }) : super(type: SvgFilterType.turbulence);

  @override
  ui.ImageFilter? apply() => null;
}

/// Paint pass for feTurbulence that generates fractal noise.
///
/// This specialized pass carries turbulence parameters and can be used
/// by the painter to generate procedural Perlin noise textures.
class SvgTurbulencePaintPass extends SvgFilterPaintPass {
  const SvgTurbulencePaintPass({
    required this.turbulenceFilter,
    super.imageFilter,
    super.colorFilter,
    super.blendMode,
    super.offset,
    super.paintFill,
    super.paintStroke,
  });

  /// The turbulence filter containing noise generation parameters.
  final SvgTurbulenceFilter turbulenceFilter;

  @override
  SvgFilterPaintPass copyWith({
    ui.ImageFilter? imageFilter,
    ui.ColorFilter? colorFilter,
    ui.BlendMode? blendMode,
    ui.Offset? offset,
    bool? paintFill,
    bool? paintStroke,
  }) {
    return SvgTurbulencePaintPass(
      turbulenceFilter: turbulenceFilter,
      imageFilter: imageFilter ?? this.imageFilter,
      colorFilter: colorFilter ?? this.colorFilter,
      blendMode: blendMode ?? this.blendMode,
      offset: offset ?? this.offset,
      paintFill: paintFill ?? this.paintFill,
      paintStroke: paintStroke ?? this.paintStroke,
    );
  }
}

/// Perlin noise generator for feTurbulence implementation.
///
/// Implements classic Perlin noise with fractal octave summation per SVG spec.
/// Based on Ken Perlin's improved noise algorithm and Blink's implementation.
/// Supports tile stitching for seamless tiling patterns.
class TurbulenceNoiseGenerator {
  TurbulenceNoiseGenerator(double seed) {
    // Initialize permutation table with seed
    _initPermutation(seed);
  }

  static const int _randMaximum = 2147483647;
  static const int _noiseChannelCount = 4;
  late final List<int> _latticeSelector;
  late final List<List<List<double>>> _gradientsByChannel;

  // Gradient vectors for 2D Perlin noise (8 directions for better distribution)
  static const List<List<double>> _gradients = [
    [1.0, 1.0],
    [1.0, -1.0],
    [-1.0, 1.0],
    [-1.0, -1.0],
    [1.0, 0.0],
    [-1.0, 0.0],
    [0.0, 1.0],
    [0.0, -1.0],
  ];

  // Lattice size for standard Perlin noise (matches Skia implementation)
  static const int _latticeSize = 256;
  static const int _latticeMask = _latticeSize - 1;

  /// Maximum number of octaves to prevent overflow.
  /// Higher values cause amplitude to become negligible and waste computation.
  static const int maxOctaves = 16;

  // Tile dimensions/frequency data for stitching.
  double _tileWidth = 0.0;
  double _tileHeight = 0.0;
  double _stitchDataInX = 0.0;
  double _stitchDataInY = 0.0;
  double _adjustedBaseFreqX = 0.0;
  double _adjustedBaseFreqY = 0.0;
  bool _stitchingEnabled = false;

  void _initPermutation(double seed) {
    var state = _normalizeSeed(seed);
    int nextRandom() {
      // Park-Miller minimal standard RNG, matches Skia/legacy SVG behavior.
      const int kRandAmplitude = 16807;
      const int kRandQ = 127773;
      const int kRandR = 2836;
      var result =
          kRandAmplitude * (state % kRandQ) - kRandR * (state ~/ kRandQ);
      if (result <= 0) {
        result += _randMaximum;
      }
      state = result;
      return result;
    }

    _latticeSelector = List<int>.generate(_latticeSize, (i) => i);
    final noise = List<List<List<int>>>.generate(
      _noiseChannelCount,
      (_) => List<List<int>>.generate(
        _latticeSize,
        (_) => List<int>.filled(2, 0),
      ),
    );

    // Populate random gradient seed data.
    for (var channel = 0; channel < _noiseChannelCount; channel++) {
      for (var i = 0; i < _latticeSize; i++) {
        _latticeSelector[i] = i;
        noise[channel][i][0] = nextRandom() % (2 * _latticeSize);
        noise[channel][i][1] = nextRandom() % (2 * _latticeSize);
      }
    }

    // Shuffle selector.
    for (var i = _latticeSize - 1; i > 0; i--) {
      final j = nextRandom() % _latticeSize;
      final tmp = _latticeSelector[i];
      _latticeSelector[i] = _latticeSelector[j];
      _latticeSelector[j] = tmp;
    }

    // Permute per-channel noise by selector.
    final permuted = List<List<List<int>>>.generate(
      _noiseChannelCount,
      (_) => List<List<int>>.generate(
        _latticeSize,
        (_) => List<int>.filled(2, 0),
      ),
    );
    for (var channel = 0; channel < _noiseChannelCount; channel++) {
      for (var i = 0; i < _latticeSize; i++) {
        permuted[channel][i][0] = noise[channel][_latticeSelector[i]][0];
        permuted[channel][i][1] = noise[channel][_latticeSelector[i]][1];
      }
    }

    // Convert to normalized gradients in [-1, 1].
    _gradientsByChannel = List<List<List<double>>>.generate(
      _noiseChannelCount,
      (_) => List<List<double>>.generate(
        _latticeSize,
        (_) => List<double>.filled(2, 0.0),
      ),
    );
    for (var channel = 0; channel < _noiseChannelCount; channel++) {
      for (var i = 0; i < _latticeSize; i++) {
        final gx = (permuted[channel][i][0] - _latticeSize) / _latticeSize;
        final gy = (permuted[channel][i][1] - _latticeSize) / _latticeSize;
        final len = math.sqrt(gx * gx + gy * gy);
        if (len > 0.0) {
          _gradientsByChannel[channel][i][0] = gx / len;
          _gradientsByChannel[channel][i][1] = gy / len;
        } else {
          _gradientsByChannel[channel][i][0] = 1.0;
          _gradientsByChannel[channel][i][1] = 0.0;
        }
      }
    }
  }

  /// Normalizes SVG seed values to match filter reference behavior.
  ///
  /// SVG engines normalize seed to a deterministic integer state used by the
  /// internal RNG. This preserves expected equivalence classes such as:
  /// `-0.8, -0.5, -0.2, 0, 0.2, 0.5, 1.5` producing the same pattern.
  static int _normalizeSeed(double seed) {
    var value = seed.truncate();
    if (value <= 0) {
      value = -(value % (_randMaximum - 1)) + 1;
    }
    if (value > _randMaximum - 1) {
      value = _randMaximum - 1;
    }
    return value;
  }

  /// Sets up stitching for seamless tiling.
  ///
  /// [width] and [height] are the tile dimensions in pixels.
  /// [baseFreqX] and [baseFreqY] are the base frequencies.
  ///
  /// Per SVG spec section 15.25.3, the base frequencies are adjusted so that
  /// the tile contains an integral number of noise periods, ensuring seamless
  /// tiling at tile boundaries.
  void setupStitching(
    double width,
    double height,
    double baseFreqX,
    double baseFreqY,
  ) {
    _tileWidth = width;
    _tileHeight = height;
    _stitchingEnabled = true;
    _adjustedBaseFreqX = baseFreqX;
    _adjustedBaseFreqY = baseFreqY;

    // Match Skia: adjust frequency to nearest floor/ceil bucket so tile edges
    // are continuous when stitchTiles="stitch".
    if (_adjustedBaseFreqX != 0.0 && width > 0.0) {
      final low = (width * _adjustedBaseFreqX).floorToDouble() / width;
      final high = (width * _adjustedBaseFreqX).ceilToDouble() / width;
      final chooseLow =
          low != 0.0 &&
          (_adjustedBaseFreqX / low) < (high / _adjustedBaseFreqX);
      _adjustedBaseFreqX = chooseLow ? low : high;
    }
    if (_adjustedBaseFreqY != 0.0 && height > 0.0) {
      final low = (height * _adjustedBaseFreqY).floorToDouble() / height;
      final high = (height * _adjustedBaseFreqY).ceilToDouble() / height;
      final chooseLow =
          low != 0.0 &&
          (_adjustedBaseFreqY / low) < (high / _adjustedBaseFreqY);
      _adjustedBaseFreqY = chooseLow ? low : high;
    }

    _stitchDataInX = width * _adjustedBaseFreqX;
    _stitchDataInY = height * _adjustedBaseFreqY;
  }

  /// Returns the adjusted frequency for X axis when stitching is enabled.
  ///
  /// The frequency is adjusted so that the tile width contains exactly
  /// _wrapX noise periods, ensuring seamless tiling.
  double getAdjustedFreqX(double baseFreqX) {
    if (!_stitchingEnabled || _tileWidth <= 0) return baseFreqX;
    return _adjustedBaseFreqX;
  }

  /// Returns the adjusted frequency for Y axis when stitching is enabled.
  double getAdjustedFreqY(double baseFreqY) {
    if (!_stitchingEnabled || _tileHeight <= 0) return baseFreqY;
    return _adjustedBaseFreqY;
  }

  /// Resets stitching to default (no stitching).
  void resetStitching() {
    _tileWidth = 0.0;
    _tileHeight = 0.0;
    _stitchDataInX = 0.0;
    _stitchDataInY = 0.0;
    _adjustedBaseFreqX = 0.0;
    _adjustedBaseFreqY = 0.0;
    _stitchingEnabled = false;
  }

  double _noise2DForChannel(
    int channel,
    double x,
    double y, {
    bool stitch = false,
    double stitchDataX = 0.0,
    double stitchDataY = 0.0,
  }) {
    var floorX = x.floorToDouble();
    var floorY = y.floorToDouble();
    var ceilX = floorX + 1.0;
    var ceilY = floorY + 1.0;
    final fractX = x - floorX;
    final fractY = y - floorY;

    if (stitch) {
      if (floorX >= stitchDataX) floorX -= stitchDataX;
      if (floorY >= stitchDataY) floorY -= stitchDataY;
      if (ceilX >= stitchDataX) ceilX -= stitchDataX;
      if (ceilY >= stitchDataY) ceilY -= stitchDataY;
    }

    final latticeIdxX = _latticeSelector[floorX.round() & _latticeMask];
    final latticeIdxY = _latticeSelector[ceilX.round() & _latticeMask];

    final b00 = (latticeIdxX + floorY.round()) & _latticeMask;
    final b10 = (latticeIdxY + floorY.round()) & _latticeMask;
    final b01 = (latticeIdxX + ceilY.round()) & _latticeMask;
    final b11 = (latticeIdxY + ceilY.round()) & _latticeMask;

    final smoothX = fractX * fractX * (3.0 - 2.0 * fractX);
    final smoothY = fractY * fractY * (3.0 - 2.0 * fractY);

    final grad00 = _gradientsByChannel[channel][b00];
    final grad10 = _gradientsByChannel[channel][b10];
    final grad01 = _gradientsByChannel[channel][b01];
    final grad11 = _gradientsByChannel[channel][b11];

    final u = grad00[0] * fractX + grad00[1] * fractY;
    final v = grad10[0] * (fractX - 1.0) + grad10[1] * fractY;
    final a = _lerp(smoothX, u, v);

    final u2 = grad01[0] * fractX + grad01[1] * (fractY - 1.0);
    final v2 = grad11[0] * (fractX - 1.0) + grad11[1] * (fractY - 1.0);
    final b = _lerp(smoothX, u2, v2);

    return _lerp(smoothY, a, b);
  }

  /// Compute single-channel Perlin noise for direct testing/debugging.
  ///
  /// This keeps the previous public API shape used by tests while delegating
  /// to the Skia-aligned channel implementation.
  double noise2D(double x, double y, {bool stitch = false, int octave = 0}) {
    final safeOctave = octave.clamp(0, maxOctaves - 1);
    final octaveScale = 1 << safeOctave;
    final stitchX = _stitchingEnabled ? _stitchDataInX * octaveScale : 0.0;
    final stitchY = _stitchingEnabled ? _stitchDataInY * octaveScale : 0.0;
    return _noise2DForChannel(
      0,
      x,
      y,
      stitch: stitch,
      stitchDataX: stitchX,
      stitchDataY: stitchY,
    );
  }

  /// Generate fractal noise with multiple octaves (fBm - fractional Brownian motion).
  ///
  /// [x], [y] - Coordinates to sample
  /// [baseFreqX], [baseFreqY] - Base frequency
  /// [numOctaves] - Number of octaves to sum (clamped to [maxOctaves])
  /// [isFractalNoise] - true for fractalNoise, false for turbulence
  /// [stitch] - true to enable seamless tiling
  double fractalNoise({
    required double x,
    required double y,
    required double baseFreqX,
    required double baseFreqY,
    required int numOctaves,
    required bool isFractalNoise,
    bool stitch = false,
    int channel = 0,
  }) {
    final effectiveOctaves = numOctaves.clamp(1, maxOctaves);
    var sum = 0.0;
    var ratio = 1.0;

    var freqX = stitch ? getAdjustedFreqX(baseFreqX) : baseFreqX;
    var freqY = stitch ? getAdjustedFreqY(baseFreqY) : baseFreqY;
    var noiseVecX = (x + 0.5) * freqX;
    var noiseVecY = (y + 0.5) * freqY;
    var stitchDataX = _stitchingEnabled ? _stitchDataInX : 0.0;
    var stitchDataY = _stitchingEnabled ? _stitchDataInY : 0.0;
    final safeChannel = channel.clamp(0, _noiseChannelCount - 1);

    for (var i = 0; i < effectiveOctaves; i++) {
      var noiseValue = _noise2DForChannel(
        safeChannel,
        noiseVecX,
        noiseVecY,
        stitch: stitch,
        stitchDataX: stitchDataX,
        stitchDataY: stitchDataY,
      );

      if (!isFractalNoise) {
        noiseValue = noiseValue.abs();
      }
      sum += noiseValue * ratio;

      noiseVecX *= 2.0;
      noiseVecY *= 2.0;
      stitchDataX *= 2.0;
      stitchDataY *= 2.0;
      ratio *= 0.5;
      freqX *= 2.0;
      freqY *= 2.0;
    }

    if (isFractalNoise) {
      sum = sum * 0.5 + 0.5;
    }
    return sum.clamp(0.0, 1.0);
  }

  /// Generate RGBA color from turbulence at (x, y).
  ui.Color generatePixel({
    required double x,
    required double y,
    required double baseFreqX,
    required double baseFreqY,
    required int numOctaves,
    required bool isFractalNoise,
    bool stitch = false,
  }) {
    final r = fractalNoise(
      x: x,
      y: y,
      baseFreqX: baseFreqX,
      baseFreqY: baseFreqY,
      numOctaves: numOctaves,
      isFractalNoise: isFractalNoise,
      stitch: stitch,
      channel: 0,
    );
    final g = fractalNoise(
      x: x,
      y: y,
      baseFreqX: baseFreqX,
      baseFreqY: baseFreqY,
      numOctaves: numOctaves,
      isFractalNoise: isFractalNoise,
      stitch: stitch,
      channel: 1,
    );
    final b = fractalNoise(
      x: x,
      y: y,
      baseFreqX: baseFreqX,
      baseFreqY: baseFreqY,
      numOctaves: numOctaves,
      isFractalNoise: isFractalNoise,
      stitch: stitch,
      channel: 2,
    );
    final a = fractalNoise(
      x: x,
      y: y,
      baseFreqX: baseFreqX,
      baseFreqY: baseFreqY,
      numOctaves: numOctaves,
      isFractalNoise: isFractalNoise,
      stitch: stitch,
      channel: 3,
    );

    // Match Skia turbulence output: clamp and premultiply RGB by alpha.
    final clampedA = a.clamp(0.0, 1.0);
    final clampedR = r.clamp(0.0, 1.0) * clampedA;
    final clampedG = g.clamp(0.0, 1.0) * clampedA;
    final clampedB = b.clamp(0.0, 1.0) * clampedA;

    return ui.Color.from(
      alpha: clampedA,
      red: clampedR,
      green: clampedG,
      blue: clampedB,
    );
  }

  // Fade function: 6t^5 - 15t^4 + 10t^3
  double _fade(double t) => t * t * t * (t * (t * 6 - 15) + 10);

  // Linear interpolation
  double _lerp(double t, double a, double b) => a + t * (b - a);

}

/// Tile-based turbulence renderer for performance optimization.
///
/// For large filter regions, this processes the region in tiles to:
/// - Avoid processing the entire region at once (memory efficiency)
/// - Enable early termination for fully transparent/opaque tiles
/// - Improve cache locality for noise lookups
class TurbulenceTileRenderer {
  const TurbulenceTileRenderer._();

  /// Default tile size for tile-based rendering.
  static const int defaultTileSize = 64;

  /// Maximum filter region size before tile-based rendering is used.
  static const int tileThreshold = 256 * 256;

  /// Generates turbulence texture using tile-based rendering.
  ///
  /// [width], [height] - Output dimensions in pixels.
  /// [turbulence] - The turbulence filter parameters.
  ///
  /// Returns RGBA pixel data (4 bytes per pixel).
  static Uint8List generateTiled({
    required int width,
    required int height,
    required SvgTurbulenceFilter turbulence,
    int tileSize = defaultTileSize,
  }) {
    if (width <= 0 || height <= 0) {
      return Uint8List(0);
    }

    final pixels = Uint8List(width * height * 4);
    final generator = TurbulenceNoiseGenerator(turbulence.seed);
    final stitch = turbulence.stitchTiles == SvgTurbulenceStitchTiles.stitch;
    final isFractalNoise =
        turbulence.noiseType == SvgTurbulenceType.fractalNoise;

    // Setup stitching if enabled
    if (stitch) {
      generator.setupStitching(
        width.toDouble(),
        height.toDouble(),
        turbulence.baseFrequencyX,
        turbulence.baseFrequencyY,
      );
    }

    // Process in tiles for large regions
    final useTiles = width * height > tileThreshold;
    final effectiveTileSize = useTiles ? tileSize : math.max(width, height);

    for (int ty = 0; ty < height; ty += effectiveTileSize) {
      final tileHeight = math.min(effectiveTileSize, height - ty);

      for (int tx = 0; tx < width; tx += effectiveTileSize) {
        final tileWidth = math.min(effectiveTileSize, width - tx);

        // Generate tile pixels
        _generateTilePixels(
          pixels: pixels,
          width: width,
          tileX: tx,
          tileY: ty,
          tileWidth: tileWidth,
          tileHeight: tileHeight,
          generator: generator,
          turbulence: turbulence,
          isFractalNoise: isFractalNoise,
          stitch: stitch,
        );
      }
    }

    return pixels;
  }

  static void _generateTilePixels({
    required Uint8List pixels,
    required int width,
    required int tileX,
    required int tileY,
    required int tileWidth,
    required int tileHeight,
    required TurbulenceNoiseGenerator generator,
    required SvgTurbulenceFilter turbulence,
    required bool isFractalNoise,
    required bool stitch,
  }) {
    for (int y = tileY; y < tileY + tileHeight; y++) {
      for (int x = tileX; x < tileX + tileWidth; x++) {
        final color = generator.generatePixel(
          x: x.toDouble(),
          y: y.toDouble(),
          baseFreqX: turbulence.baseFrequencyX,
          baseFreqY: turbulence.baseFrequencyY,
          numOctaves: turbulence.numOctaves,
          isFractalNoise: isFractalNoise,
          stitch: stitch,
        );

        final index = (y * width + x) * 4;
        pixels[index] = (color.r * 255).round().clamp(0, 255);
        pixels[index + 1] = (color.g * 255).round().clamp(0, 255);
        pixels[index + 2] = (color.b * 255).round().clamp(0, 255);
        pixels[index + 3] = (color.a * 255).round().clamp(0, 255);
      }
    }
  }
}
