part of 'svg_filters.dart';

/// Gaussian Blur фильтр
///
/// Использует ImageFilter.blur для размытия
class SvgGaussianBlurFilter extends SvgFilter {
  /// Стандартное отклонение по X (размытие по горизонтали)
  final double stdDeviationX;

  /// Стандартное отклонение по Y (размытие по вертикали)
  final double stdDeviationY;

  SvgGaussianBlurFilter({
    required super.id,
    required this.stdDeviationX,
    required this.stdDeviationY,
    super.input,
    super.resultName,
  }) : super(type: SvgFilterType.gaussianBlur);

  @override
  ui.ImageFilter? apply() {
    // Flutter ImageFilter.blur использует sigma (стандартное отклонение)
    // В SVG stdDeviation = sigma
    return ui.ImageFilter.blur(sigmaX: stdDeviationX, sigmaY: stdDeviationY);
  }
}

/// Morphology фильтр
///
/// Использует ImageFilter.erode/dilate для базовой SVG feMorphology-поддержки.
class SvgMorphologyFilter extends SvgFilter {
  /// Оператор morphology: erode или dilate.
  final SvgMorphologyOperator operatorType;

  /// Радиус по X.
  final double radiusX;

  /// Радиус по Y.
  final double radiusY;

  SvgMorphologyFilter({
    required super.id,
    required this.operatorType,
    required this.radiusX,
    required this.radiusY,
    super.input,
    super.resultName,
  }) : super(type: SvgFilterType.morphology);

  @override
  ui.ImageFilter? apply() {
    final clampedX = radiusX.clamp(0.0, 4096.0).toDouble();
    final clampedY = radiusY.clamp(0.0, 4096.0).toDouble();
    if (clampedX <= 0.0 && clampedY <= 0.0) {
      return null;
    }
    switch (operatorType) {
      case SvgMorphologyOperator.dilate:
        return ui.ImageFilter.dilate(radiusX: clampedX, radiusY: clampedY);
      case SvgMorphologyOperator.erode:
        return ui.ImageFilter.erode(radiusX: clampedX, radiusY: clampedY);
    }
  }
}

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
/// Baseline-поддержка хранит параметры генератора шума для parity-аудита.
/// До полноценной растерной реализации примитив ведет себя как pass-through.
class SvgTurbulenceFilter extends SvgFilter {
  /// Базовая частота шума по X/Y.
  final double baseFrequencyX;
  final double baseFrequencyY;

  /// Количество октав.
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
