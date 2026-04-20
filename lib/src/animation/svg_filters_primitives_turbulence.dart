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

  late final List<int> _perm;

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

  // Lattice size for standard Perlin noise
  static const int _latticeSize = 256;
  static const int _latticeMask = _latticeSize - 1;

  /// Maximum number of octaves to prevent overflow.
  /// Higher values cause amplitude to become negligible and waste computation.
  static const int maxOctaves = 16;

  // Stitch info for seamless tiling
  int _wrapX = _latticeSize;
  int _wrapY = _latticeSize;

  // Per-octave wrap values for seamless stitching
  late List<int> _octaveWrapX;
  late List<int> _octaveWrapY;

  // Tile dimensions for frequency adjustment
  double _tileWidth = 0.0;
  double _tileHeight = 0.0;
  bool _stitchingEnabled = false;

  void _initPermutation(double seed) {
    final normalizedSeed = _normalizeSeed(seed);

    // Create deterministic permutation based on seed
    final random = math.Random(normalizedSeed);
    final p = List<int>.generate(_latticeSize, (i) => i);

    // Fisher-Yates shuffle with seeded random
    for (var i = _latticeSize - 1; i > 0; i--) {
      final j = random.nextInt(i + 1);
      final temp = p[i];
      p[i] = p[j];
      p[j] = temp;
    }

    // Duplicate the permutation table for easy wrapping
    _perm = [...p, ...p];

    // Initialize octave wrap arrays
    _octaveWrapX = List.filled(maxOctaves, _latticeSize);
    _octaveWrapY = List.filled(maxOctaves, _latticeSize);
  }

  /// Normalizes SVG seed values to match filter reference behavior.
  ///
  /// SVG engines normalize seed to a deterministic integer state used by the
  /// internal RNG. This preserves expected equivalence classes such as:
  /// `-0.8, -0.5, -0.2, 0, 0.2, 0.5, 1.5` producing the same pattern.
  static int _normalizeSeed(double seed) {
    final truncated = seed.toInt();
    if (truncated <= 0) {
      // Map non-positive seeds into positive deterministic states.
      return (-truncated) + 1;
    }
    return truncated;
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
    // Store tile dimensions for adjusted frequency calculation
    _tileWidth = width;
    _tileHeight = height;
    _stitchingEnabled = true;

    // Calculate the wrap period for each axis
    // Per SVG spec: wrapX = floor(width * baseFrequencyX)
    // This is the number of noise "tiles" that fit in the filter region
    _wrapX = math.max(1, (width * baseFreqX).floor());
    _wrapY = math.max(1, (height * baseFreqY).floor());

    // Pre-compute per-octave wrap values for seamless stitching
    // Each octave doubles the frequency, so wrap values also double
    for (int i = 0; i < maxOctaves; i++) {
      _octaveWrapX[i] = _wrapX << i;
      _octaveWrapY[i] = _wrapY << i;
    }
  }

  /// Returns the adjusted frequency for X axis when stitching is enabled.
  ///
  /// The frequency is adjusted so that the tile width contains exactly
  /// _wrapX noise periods, ensuring seamless tiling.
  double getAdjustedFreqX(double baseFreqX) {
    if (!_stitchingEnabled || _tileWidth <= 0) return baseFreqX;
    // Adjusted frequency = wrapX / tileWidth
    // This ensures that at x=tileWidth, the noise coord is exactly wrapX
    return _wrapX / _tileWidth;
  }

  /// Returns the adjusted frequency for Y axis when stitching is enabled.
  double getAdjustedFreqY(double baseFreqY) {
    if (!_stitchingEnabled || _tileHeight <= 0) return baseFreqY;
    return _wrapY / _tileHeight;
  }

  /// Resets stitching to default (no stitching).
  void resetStitching() {
    _wrapX = _latticeSize;
    _wrapY = _latticeSize;
    _tileWidth = 0.0;
    _tileHeight = 0.0;
    _stitchingEnabled = false;

    // Reset octave wrap arrays to default
    for (int i = 0; i < maxOctaves; i++) {
      _octaveWrapX[i] = _latticeSize;
      _octaveWrapY[i] = _latticeSize;
    }
  }

  /// Compute single octave of Perlin noise at (x, y) with optional stitching.
  ///
  /// When [stitch] is true, lattice coordinates wrap at tile boundaries
  /// to produce seamless noise at the edges. The wrap period doubles with
  /// each octave to maintain proper frequency relationships.
  double noise2D(double x, double y, {bool stitch = false, int octave = 0}) {
    // Clamp octave to valid range
    final safeOctave = octave.clamp(0, maxOctaves - 1);

    // For stitching, use pre-computed wrap values for this octave
    final wrapX = stitch ? _octaveWrapX[safeOctave] : _latticeSize;
    final wrapY = stitch ? _octaveWrapY[safeOctave] : _latticeSize;

    // Find unit square containing point
    var xi = x.floor();
    var yi = y.floor();

    // Find relative x, y of point in square
    final xf = x - xi;
    final yf = y - yi;

    // Wrap grid coordinates for stitching
    // Use modulo to ensure coordinates stay within wrap period
    xi = xi % wrapX;
    yi = yi % wrapY;
    if (xi < 0) xi += wrapX;
    if (yi < 0) yi += wrapY;

    // Compute next grid coordinates with proper wrapping at tile boundary
    // This is critical for seamless tiling - when we're at the edge,
    // the next coordinate wraps back to 0
    final xi1 = (xi + 1) % wrapX;
    final yi1 = (yi + 1) % wrapY;

    // Compute fade curves using improved Perlin fade function
    final u = _fade(xf);
    final v = _fade(yf);

    // Hash coordinates of the 4 square corners
    // Apply lattice mask AFTER applying stitch wrapping to ensure
    // proper permutation table indexing while respecting tile boundaries
    final xiMasked = xi & _latticeMask;
    final yiMasked = yi & _latticeMask;
    final xi1Masked = xi1 & _latticeMask;
    final yi1Masked = yi1 & _latticeMask;

    final aa = _perm[(_perm[xiMasked] + yiMasked) & _latticeMask];
    final ab = _perm[(_perm[xiMasked] + yi1Masked) & _latticeMask];
    final ba = _perm[(_perm[xi1Masked] + yiMasked) & _latticeMask];
    final bb = _perm[(_perm[xi1Masked] + yi1Masked) & _latticeMask];

    // Blend results from 4 corners using bilinear interpolation
    return _lerp(
      v,
      _lerp(u, _grad(aa, xf, yf), _grad(ba, xf - 1, yf)),
      _lerp(u, _grad(ab, xf, yf - 1), _grad(bb, xf - 1, yf - 1)),
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
  }) {
    // Clamp numOctaves to prevent overflow and wasted computation
    // Values beyond maxOctaves contribute negligible amplitude (<0.003%)
    final effectiveOctaves = numOctaves.clamp(1, maxOctaves);

    var sum = 0.0;
    var amplitude = 1.0;
    var maxAmplitude = 0.0;

    // When stitching, use adjusted frequencies for seamless tiling
    // Per SVG spec, frequencies are adjusted so the tile contains
    // an integral number of noise periods
    var freqX = stitch ? getAdjustedFreqX(baseFreqX) : baseFreqX;
    var freqY = stitch ? getAdjustedFreqY(baseFreqY) : baseFreqY;

    for (var i = 0; i < effectiveOctaves; i++) {
      final noiseValue = noise2D(
        x * freqX,
        y * freqY,
        stitch: stitch,
        octave: i,
      );

      if (isFractalNoise) {
        // fractalNoise: signed noise [-1, 1]
        sum += noiseValue * amplitude;
      } else {
        // turbulence: absolute value of noise [0, 1]
        sum += noiseValue.abs() * amplitude;
      }

      maxAmplitude += amplitude;
      amplitude *= 0.5; // Each octave has half the amplitude
      freqX *= 2.0; // Double the frequency
      freqY *= 2.0;
    }

    // Normalize to [0, 1] range for turbulence, [-1, 1] for fractalNoise
    if (isFractalNoise) {
      return (sum / maxAmplitude + 1.0) / 2.0; // Map to [0, 1]
    } else {
      return sum / maxAmplitude;
    }
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
    // Generate noise for each channel with different offsets
    final r = fractalNoise(
      x: x,
      y: y,
      baseFreqX: baseFreqX,
      baseFreqY: baseFreqY,
      numOctaves: numOctaves,
      isFractalNoise: isFractalNoise,
      stitch: stitch,
    );
    final g = fractalNoise(
      x: x + 100.0,
      y: y + 100.0,
      baseFreqX: baseFreqX,
      baseFreqY: baseFreqY,
      numOctaves: numOctaves,
      isFractalNoise: isFractalNoise,
      stitch: stitch,
    );
    final b = fractalNoise(
      x: x + 200.0,
      y: y + 200.0,
      baseFreqX: baseFreqX,
      baseFreqY: baseFreqY,
      numOctaves: numOctaves,
      isFractalNoise: isFractalNoise,
      stitch: stitch,
    );
    final a = fractalNoise(
      x: x + 300.0,
      y: y + 300.0,
      baseFreqX: baseFreqX,
      baseFreqY: baseFreqY,
      numOctaves: numOctaves,
      isFractalNoise: isFractalNoise,
      stitch: stitch,
    );

    return ui.Color.from(
      alpha: a.clamp(0.0, 1.0),
      red: r.clamp(0.0, 1.0),
      green: g.clamp(0.0, 1.0),
      blue: b.clamp(0.0, 1.0),
    );
  }

  // Fade function: 6t^5 - 15t^4 + 10t^3
  double _fade(double t) => t * t * t * (t * (t * 6 - 15) + 10);

  // Linear interpolation
  double _lerp(double t, double a, double b) => a + t * (b - a);

  // Gradient function
  double _grad(int hash, double x, double y) {
    final grad = _gradients[hash & 7];
    return grad[0] * x + grad[1] * y;
  }
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
