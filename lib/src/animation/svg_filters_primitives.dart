part of 'svg_filters.dart';

/// Displacement map фильтр
///
/// Базовая поддержка хранит параметры и графовые входы (`in`/`in2`/`result`).
/// В текущем пайплайне применяется как pass-through для `in`.
class SvgDisplacementMapFilter extends SvgFilter {
  /// Масштаб смещения.
  final double scale;

  /// Канал для X-компоненты смещения.
  final SvgChannelSelector xChannelSelector;

  /// Канал для Y-компоненты смещения.
  final SvgChannelSelector yChannelSelector;

  SvgDisplacementMapFilter({
    required super.id,
    required this.scale,
    required this.xChannelSelector,
    required this.yChannelSelector,
    super.input,
    super.input2,
    super.resultName,
  }) : super(type: SvgFilterType.displacementMap);

  @override
  ui.ImageFilter? apply() => null;
}

/// feImage primitive
///
/// Baseline-поддержка хранит параметры внешнего источника. В текущем пайплайне
/// рендерится как graph pass-through до появления растеризации внешнего источника.
class SvgFeImageFilter extends SvgFilter {
  /// URL/IRI источника изображения.
  final String? href;

  /// Геометрия под-прямоугольника примитива.
  final double x;
  final double y;
  final double width;
  final double height;

  /// Значение preserveAspectRatio у примитива.
  final String? preserveAspectRatio;

  SvgFeImageFilter({
    required super.id,
    this.href,
    this.x = 0.0,
    this.y = 0.0,
    this.width = 0.0,
    this.height = 0.0,
    this.preserveAspectRatio,
    super.input,
    super.resultName,
  }) : super(type: SvgFilterType.image);

  @override
  ui.ImageFilter? apply() => null;
}

/// feConvolveMatrix primitive
///
/// Baseline-поддержка хранит параметры свертки для parity-аудита и графа.
/// До полноценной растерной реализации примитив ведет себя как pass-through.
class SvgConvolveMatrixFilter extends SvgFilter {
  /// Размер ядра свертки.
  final int orderX;
  final int orderY;

  /// Матрица свертки.
  final List<double> kernelMatrix;

  /// Нормализация и смещение результата.
  final double divisor;
  final double bias;

  /// Позиция целевого элемента ядра.
  final int targetX;
  final int targetY;

  /// Поведение на границе.
  final SvgConvolveEdgeMode edgeMode;

  /// Размер единицы ядра в user space (опционально).
  final double? kernelUnitLengthX;
  final double? kernelUnitLengthY;

  /// Сохранять альфу входа.
  final bool preserveAlpha;

  SvgConvolveMatrixFilter({
    required super.id,
    required this.orderX,
    required this.orderY,
    required this.kernelMatrix,
    required this.divisor,
    required this.bias,
    required this.targetX,
    required this.targetY,
    required this.edgeMode,
    this.kernelUnitLengthX,
    this.kernelUnitLengthY,
    this.preserveAlpha = false,
    super.input,
    super.resultName,
  }) : super(type: SvgFilterType.convolveMatrix);

  @override
  ui.ImageFilter? apply() => null;
}

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
class TurbulenceNoiseGenerator {
  TurbulenceNoiseGenerator(double seed) {
    // Initialize permutation table with seed
    _initPermutation(seed);
  }

  late final List<int> _perm;
  
  // Gradient vectors for 2D Perlin noise
  static const List<List<double>> _gradients = [
    [1.0, 1.0], [1.0, -1.0], [-1.0, 1.0], [-1.0, -1.0],
    [1.0, 0.0], [-1.0, 0.0], [0.0, 1.0], [0.0, -1.0],
  ];

  void _initPermutation(double seed) {
    // Create deterministic permutation based on seed
    final random = math.Random(seed.toInt().abs());
    final p = List<int>.generate(256, (i) => i);
    
    // Fisher-Yates shuffle with seeded random
    for (var i = 255; i > 0; i--) {
      final j = random.nextInt(i + 1);
      final temp = p[i];
      p[i] = p[j];
      p[j] = temp;
    }
    
    // Duplicate the permutation table for easy wrapping
    _perm = [...p, ...p];
  }

  /// Compute single octave of Perlin noise at (x, y).
  double noise2D(double x, double y) {
    // Find unit square containing point
    final xi = x.floor() & 255;
    final yi = y.floor() & 255;
    
    // Find relative x, y of point in square
    final xf = x - x.floor();
    final yf = y - y.floor();
    
    // Compute fade curves
    final u = _fade(xf);
    final v = _fade(yf);
    
    // Hash coordinates of the 4 square corners
    final aa = _perm[_perm[xi] + yi];
    final ab = _perm[_perm[xi] + yi + 1];
    final ba = _perm[_perm[xi + 1] + yi];
    final bb = _perm[_perm[xi + 1] + yi + 1];
    
    // Blend results from 4 corners
    return _lerp(v,
      _lerp(u, _grad(aa, xf, yf), _grad(ba, xf - 1, yf)),
      _lerp(u, _grad(ab, xf, yf - 1), _grad(bb, xf - 1, yf - 1)),
    );
  }

  /// Generate fractal noise with multiple octaves (fBm - fractional Brownian motion).
  ///
  /// [x], [y] - Coordinates to sample
  /// [baseFreqX], [baseFreqY] - Base frequency
  /// [numOctaves] - Number of octaves to sum
  /// [isFractalNoise] - true for fractalNoise, false for turbulence
  double fractalNoise({
    required double x,
    required double y,
    required double baseFreqX,
    required double baseFreqY,
    required int numOctaves,
    required bool isFractalNoise,
  }) {
    var sum = 0.0;
    var amplitude = 1.0;
    var freqX = baseFreqX;
    var freqY = baseFreqY;
    var maxAmplitude = 0.0;
    
    for (var i = 0; i < numOctaves; i++) {
      final noiseValue = noise2D(x * freqX, y * freqY);
      
      if (isFractalNoise) {
        // fractalNoise: signed noise [-1, 1]
        sum += noiseValue * amplitude;
      } else {
        // turbulence: absolute value of noise [0, 1]
        sum += noiseValue.abs() * amplitude;
      }
      
      maxAmplitude += amplitude;
      amplitude *= 0.5; // Each octave has half the amplitude
      freqX *= 2.0;     // Double the frequency
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
  }) {
    // Generate noise for each channel with different offsets
    final r = fractalNoise(
      x: x,
      y: y,
      baseFreqX: baseFreqX,
      baseFreqY: baseFreqY,
      numOctaves: numOctaves,
      isFractalNoise: isFractalNoise,
    );
    final g = fractalNoise(
      x: x + 100.0,
      y: y + 100.0,
      baseFreqX: baseFreqX,
      baseFreqY: baseFreqY,
      numOctaves: numOctaves,
      isFractalNoise: isFractalNoise,
    );
    final b = fractalNoise(
      x: x + 200.0,
      y: y + 200.0,
      baseFreqX: baseFreqX,
      baseFreqY: baseFreqY,
      numOctaves: numOctaves,
      isFractalNoise: isFractalNoise,
    );
    final a = fractalNoise(
      x: x + 300.0,
      y: y + 300.0,
      baseFreqX: baseFreqX,
      baseFreqY: baseFreqY,
      numOctaves: numOctaves,
      isFractalNoise: isFractalNoise,
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
