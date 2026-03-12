import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

/// Тип SVG фильтра
enum SvgFilterType {
  /// Gaussian blur - размытие
  gaussianBlur,

  /// Morphology - дилатация/эрозия альфа-маски
  morphology,

  /// Displacement map - смещение по карте каналов (baseline pass-through)
  displacementMap,

  /// Image - внешний источник изображения (baseline graph pass-through)
  image,

  /// Convolve matrix - свертка ядром (baseline graph pass-through)
  convolveMatrix,

  /// Turbulence - процедурный шум (baseline graph pass-through)
  turbulence,

  /// Component transfer - поканальная функция цвета (baseline graph pass-through)
  componentTransfer,

  /// Diffuse lighting - диффузное освещение (baseline graph pass-through)
  diffuseLighting,

  /// Specular lighting - зеркальное освещение (baseline graph pass-through)
  specularLighting,

  /// Offset - смещение результата
  offset,

  /// Flood - заливка сплошным цветом
  flood,

  /// Blend - смешивание с подложкой
  blend,

  /// Composite - композиция с подложкой
  composite,

  /// Merge - объединение нескольких входов (feMerge/feMergeNode)
  merge,

  /// Tile - повторение входного изображения (baseline pass-through)
  tile,

  /// Drop shadow - тень
  dropShadow,

  /// Color matrix - цветовые трансформации
  colorMatrix,
}

/// Оператор feMorphology
enum SvgMorphologyOperator {
  /// Эрозия (сужение)
  erode,

  /// Дилатация (расширение)
  dilate,
}

/// Селектор канала для filter primitives с channel selector.
enum SvgChannelSelector {
  /// Red channel
  r,

  /// Green channel
  g,

  /// Blue channel
  b,

  /// Alpha channel
  a,
}

/// Режим обработки краев для feConvolveMatrix.
enum SvgConvolveEdgeMode {
  /// duplicate
  duplicate,

  /// wrap
  wrap,

  /// none
  none,
}

/// Тип генерации шума для feTurbulence.
enum SvgTurbulenceType {
  /// turbulence
  turbulence,

  /// fractalNoise
  fractalNoise,
}

/// Режим тайлинга шума для feTurbulence.
enum SvgTurbulenceStitchTiles {
  /// noStitch
  noStitch,

  /// stitch
  stitch,
}

/// Тип функции канала для feComponentTransfer.
enum SvgComponentTransferType {
  /// identity
  identity,

  /// table
  table,

  /// discrete
  discrete,

  /// linear
  linear,

  /// gamma
  gamma,
}

/// Один проход отрисовки фильтра для source-графики.
///
/// Animated painter может рендерить элемент в несколько проходов
/// (например для `feDropShadow` и `feMerge`).
class SvgFilterPaintPass {
  const SvgFilterPaintPass({
    this.imageFilter,
    this.colorFilter,
    this.blendMode,
    this.offset = ui.Offset.zero,
    this.paintFill = true,
    this.paintStroke = true,
  });

  static const SvgFilterPaintPass identity = SvgFilterPaintPass();

  final ui.ImageFilter? imageFilter;
  final ui.ColorFilter? colorFilter;
  final ui.BlendMode? blendMode;
  final ui.Offset offset;
  final bool paintFill;
  final bool paintStroke;

  SvgFilterPaintPass copyWith({
    ui.ImageFilter? imageFilter,
    ui.ColorFilter? colorFilter,
    ui.BlendMode? blendMode,
    ui.Offset? offset,
    bool? paintFill,
    bool? paintStroke,
  }) {
    return SvgFilterPaintPass(
      imageFilter: imageFilter ?? this.imageFilter,
      colorFilter: colorFilter ?? this.colorFilter,
      blendMode: blendMode ?? this.blendMode,
      offset: offset ?? this.offset,
      paintFill: paintFill ?? this.paintFill,
      paintStroke: paintStroke ?? this.paintStroke,
    );
  }
}

/// Optional context for built-in filter inputs tied to element paint.
class SvgFilterSourceContext {
  const SvgFilterSourceContext({
    this.fillPaint,
    this.strokePaint,
    this.backgroundImage,
    this.backgroundAlpha,
  });

  final List<SvgFilterPaintPass>? fillPaint;
  final List<SvgFilterPaintPass>? strokePaint;
  final List<SvgFilterPaintPass>? backgroundImage;
  final List<SvgFilterPaintPass>? backgroundAlpha;
}

/// Offset фильтр
///
/// Смещает входное изображение на dx/dy.
class SvgOffsetFilter extends SvgFilter {
  /// Смещение по X
  final double dx;

  /// Смещение по Y
  final double dy;

  SvgOffsetFilter({
    required super.id,
    required this.dx,
    required this.dy,
    super.input,
    super.resultName,
  }) : super(type: SvgFilterType.offset);

  @override
  ui.ImageFilter? apply() {
    // Matrix4 в column-major формате: translation в ячейках [12], [13].
    final matrix = Float64List.fromList(<double>[
      1,
      0,
      0,
      0,
      0,
      1,
      0,
      0,
      0,
      0,
      1,
      0,
      dx,
      dy,
      0,
      1,
    ]);
    return ui.ImageFilter.matrix(matrix);
  }
}

/// Тип цветовой матрицы для feColorMatrix
enum SvgColorMatrixType {
  /// Матрица 5x4 (20 значений)
  matrix,

  /// Насыщенность (1 значение: 0-1)
  saturate,

  /// Hue rotate (1 значение: градусы)
  hueRotate,

  /// Luminance to alpha (нет значений)
  luminanceToAlpha,
}

/// Базовый класс для SVG фильтра
abstract class SvgFilter {
  /// ID фильтра
  final String id;

  /// Тип фильтра
  final SvgFilterType type;

  /// Primitive input (`in` attribute).
  final String? input;

  /// Optional secondary input (`in2` attribute).
  final String? input2;

  /// Named primitive result (`result` attribute).
  final String? resultName;

  SvgFilter({
    required this.id,
    required this.type,
    this.input,
    this.input2,
    this.resultName,
  });

  /// Применить фильтр к изображению
  /// Возвращает ImageFilter для использования в Flutter Canvas
  ui.ImageFilter? apply();

  /// Опциональный ColorFilter (если фильтр влияет на цвет напрямую).
  ui.ColorFilter? colorFilter() => null;

  /// Опциональный blend mode (если фильтр задаёт композицию).
  ui.BlendMode? blendMode() => null;
}

/// feFlood: закрашивает результат сплошным цветом.
class SvgFloodFilter extends SvgFilter {
  /// Цвет заливки.
  final ui.Color floodColor;

  /// Прозрачность flood (0..1).
  final double floodOpacity;

  SvgFloodFilter({
    required super.id,
    required this.floodColor,
    required this.floodOpacity,
    super.resultName,
  }) : super(type: SvgFilterType.flood);

  ui.Color get _effectiveColor {
    final opacity = floodOpacity.clamp(0.0, 1.0);
    return floodColor.withValues(alpha: floodColor.a * opacity);
  }

  ui.Color get effectiveColor => _effectiveColor;

  @override
  ui.ImageFilter? apply() {
    return ui.ColorFilter.mode(_effectiveColor, ui.BlendMode.src);
  }

  @override
  ui.ColorFilter? colorFilter() {
    return ui.ColorFilter.mode(_effectiveColor, ui.BlendMode.src);
  }
}

/// feBlend: приближенно задаёт режим смешивания слоя.
class SvgBlendFilter extends SvgFilter {
  /// Режим смешивания.
  final ui.BlendMode mode;

  SvgBlendFilter({
    required super.id,
    required this.mode,
    super.input,
    super.input2,
    super.resultName,
  }) : super(type: SvgFilterType.blend);

  @override
  ui.ImageFilter? apply() => null;

  @override
  ui.BlendMode? blendMode() => mode;
}

/// feComposite: приближенно задаёт режим композиции слоя.
class SvgCompositeFilter extends SvgFilter {
  /// Оператор композиции из SVG (over/in/out/atop/xor/lighter/arithmetic).
  final String operatorType;

  /// Соответствующий Flutter BlendMode (если есть приближение).
  final ui.BlendMode? mode;

  /// Параметры arithmetic (если заданы).
  final double k1;
  final double k2;
  final double k3;
  final double k4;

  SvgCompositeFilter({
    required super.id,
    required this.operatorType,
    required this.mode,
    this.k1 = 0.0,
    this.k2 = 0.0,
    this.k3 = 0.0,
    this.k4 = 0.0,
    super.input,
    super.input2,
    super.resultName,
  }) : super(type: SvgFilterType.composite);

  @override
  ui.ImageFilter? apply() => null;

  @override
  ui.BlendMode? blendMode() => mode;
}

/// feMerge: объединяет несколько входов в один результат.
///
/// В текущем baseline-пайплайне хранит структуру примитива, но не выполняет
/// полноценную графовую композицию входов.
class SvgMergeFilter extends SvgFilter {
  /// Список входов из дочерних `<feMergeNode in="...">`.
  final List<String?> nodeInputs;

  SvgMergeFilter({
    required super.id,
    required this.nodeInputs,
    super.resultName,
  }) : super(type: SvgFilterType.merge);

  /// Количество merge-node в примитиве.
  int get nodeCount => nodeInputs.length;

  @override
  ui.ImageFilter? apply() => null;
}

/// feTile: baseline-pass-through примитив.
///
/// В текущем пайплайне не выполняет растеризованное тайлинг-повторение, но
/// сохраняет граф зависимостей `in/result` и передаёт вход дальше по цепочке.
class SvgTileFilter extends SvgFilter {
  SvgTileFilter({required super.id, super.input, super.resultName})
    : super(type: SvgFilterType.tile);

  @override
  ui.ImageFilter? apply() => null;
}

/// Парсит feBlend mode в Flutter BlendMode.
ui.BlendMode parseSvgBlendMode(String? rawMode) {
  switch ((rawMode ?? 'normal').trim().toLowerCase()) {
    case 'multiply':
      return ui.BlendMode.multiply;
    case 'screen':
      return ui.BlendMode.screen;
    case 'darken':
      return ui.BlendMode.darken;
    case 'lighten':
      return ui.BlendMode.lighten;
    case 'overlay':
      return ui.BlendMode.overlay;
    case 'color-dodge':
      return ui.BlendMode.colorDodge;
    case 'color-burn':
      return ui.BlendMode.colorBurn;
    case 'hard-light':
      return ui.BlendMode.hardLight;
    case 'soft-light':
      return ui.BlendMode.softLight;
    case 'difference':
      return ui.BlendMode.difference;
    case 'exclusion':
      return ui.BlendMode.exclusion;
    case 'hue':
      return ui.BlendMode.hue;
    case 'saturation':
      return ui.BlendMode.saturation;
    case 'color':
      return ui.BlendMode.color;
    case 'luminosity':
      return ui.BlendMode.luminosity;
    case 'normal':
    default:
      return ui.BlendMode.srcOver;
  }
}

/// Парсит feComposite operator в Flutter BlendMode.
///
/// Для `arithmetic` возвращает null (в текущем пайплайне нет точного аналога).
ui.BlendMode? parseSvgCompositeOperator(String? rawOperator) {
  switch ((rawOperator ?? 'over').trim().toLowerCase()) {
    case 'over':
      return ui.BlendMode.srcOver;
    case 'in':
      return ui.BlendMode.srcIn;
    case 'out':
      return ui.BlendMode.srcOut;
    case 'atop':
      return ui.BlendMode.srcATop;
    case 'xor':
      return ui.BlendMode.xor;
    case 'lighter':
      return ui.BlendMode.plus;
    case 'arithmetic':
      return null;
    default:
      return ui.BlendMode.srcOver;
  }
}

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

/// Параметры одной channel-функции (`feFuncR/G/B/A`) для feComponentTransfer.
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

  final SvgComponentTransferType type;
  final List<double> tableValues;
  final double slope;
  final double intercept;
  final double amplitude;
  final double exponent;
  final double offset;
}

/// feComponentTransfer primitive
///
/// Baseline-поддержка хранит структуру channel-функций для parity-аудита.
/// До полноценного color-apply примитив ведет себя как pass-through.
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

  @override
  ui.ImageFilter? apply() => null;
}

/// Базовый тип источника света для lighting-примитивов.
abstract class SvgLightSource {
  const SvgLightSource();
}

/// `feDistantLight`
class SvgDistantLightSource extends SvgLightSource {
  const SvgDistantLightSource({required this.azimuth, required this.elevation});

  final double azimuth;
  final double elevation;
}

/// `fePointLight`
class SvgPointLightSource extends SvgLightSource {
  const SvgPointLightSource({
    required this.x,
    required this.y,
    required this.z,
  });

  final double x;
  final double y;
  final double z;
}

/// `feSpotLight`
class SvgSpotLightSource extends SvgLightSource {
  const SvgSpotLightSource({
    required this.x,
    required this.y,
    required this.z,
    required this.pointsAtX,
    required this.pointsAtY,
    required this.pointsAtZ,
    required this.specularExponent,
    required this.limitingConeAngle,
  });

  final double x;
  final double y;
  final double z;
  final double pointsAtX;
  final double pointsAtY;
  final double pointsAtZ;
  final double specularExponent;
  final double limitingConeAngle;
}

/// `feDiffuseLighting` primitive
///
/// Baseline-поддержка хранит параметры освещения и источник света.
/// До полноценного light shading примитив ведет себя как pass-through.
class SvgDiffuseLightingFilter extends SvgFilter {
  final double x;
  final double y;
  final double width;
  final double height;
  final double surfaceScale;
  final double diffuseConstant;
  final double? kernelUnitLengthX;
  final double? kernelUnitLengthY;
  final ui.Color lightingColor;
  final SvgLightSource? lightSource;

  SvgDiffuseLightingFilter({
    required super.id,
    this.x = 0.0,
    this.y = 0.0,
    this.width = 0.0,
    this.height = 0.0,
    required this.surfaceScale,
    required this.diffuseConstant,
    this.kernelUnitLengthX,
    this.kernelUnitLengthY,
    required this.lightingColor,
    this.lightSource,
    super.input,
    super.resultName,
  }) : super(type: SvgFilterType.diffuseLighting);

  @override
  ui.ImageFilter? apply() => null;
}

/// `feSpecularLighting` primitive
///
/// Baseline-поддержка хранит параметры освещения и источник света.
/// До полноценного light shading примитив ведет себя как pass-through.
class SvgSpecularLightingFilter extends SvgFilter {
  final double x;
  final double y;
  final double width;
  final double height;
  final double surfaceScale;
  final double specularConstant;
  final double specularExponent;
  final double? kernelUnitLengthX;
  final double? kernelUnitLengthY;
  final ui.Color lightingColor;
  final SvgLightSource? lightSource;

  SvgSpecularLightingFilter({
    required super.id,
    this.x = 0.0,
    this.y = 0.0,
    this.width = 0.0,
    this.height = 0.0,
    required this.surfaceScale,
    required this.specularConstant,
    required this.specularExponent,
    this.kernelUnitLengthX,
    this.kernelUnitLengthY,
    required this.lightingColor,
    this.lightSource,
    super.input,
    super.resultName,
  }) : super(type: SvgFilterType.specularLighting);

  @override
  ui.ImageFilter? apply() => null;
}

/// Drop Shadow фильтр
///
/// Создает тень от объекта
class SvgDropShadowFilter extends SvgFilter {
  /// Смещение по X
  final double dx;

  /// Смещение по Y
  final double dy;

  /// Стандартное отклонение по X (размытие тени)
  final double stdDeviationX;

  /// Стандартное отклонение по Y (размытие тени)
  final double stdDeviationY;

  /// Цвет тени
  final ui.Color? floodColor;

  /// Прозрачность тени (0..1)
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

  /// Получить offset для применения через transform
  ui.Offset get offset => ui.Offset(dx, dy);

  /// Эффективный цвет тени с учётом flood-opacity.
  ui.Color get effectiveShadowColor {
    final base = floodColor ?? const ui.Color(0xFF000000);
    final opacity = floodOpacity.clamp(0.0, 1.0);
    return base.withValues(alpha: base.a * opacity);
  }

  /// Совместимость со старым API (среднее по осям).
  double get stdDeviation => (stdDeviationX + stdDeviationY) / 2.0;
}

/// Color Matrix фильтр
///
/// Применяет цветовые трансформации
class SvgColorMatrixFilter extends SvgFilter {
  /// Тип трансформации
  final SvgColorMatrixType matrixType;

  /// Значения для матрицы (зависят от типа)
  final List<double> values;

  SvgColorMatrixFilter({
    required super.id,
    required this.matrixType,
    required this.values,
    super.input,
    super.resultName,
  }) : super(type: SvgFilterType.colorMatrix);

  @override
  ui.ImageFilter? apply() {
    switch (matrixType) {
      case SvgColorMatrixType.matrix:
        if (values.length == 20) {
          // Матрица 5x4 для RGBA
          // Преобразуем в ColorFilter.matrix (4x5 матрица в Flutter)
          return ui.ColorFilter.matrix(_convertSvgMatrixToFlutter(values));
        }
        return null;

      case SvgColorMatrixType.saturate:
        if (values.isNotEmpty) {
          // Насыщенность (0 = grayscale, 1 = normal)
          return ui.ColorFilter.matrix(_saturateMatrix(values[0]));
        }
        return null;

      case SvgColorMatrixType.hueRotate:
        if (values.isNotEmpty) {
          // Hue rotation в градусах
          return ui.ColorFilter.matrix(_hueRotateMatrix(values[0]));
        }
        return null;

      case SvgColorMatrixType.luminanceToAlpha:
        // Luminance to alpha - специальная матрица
        return ui.ColorFilter.matrix(_luminanceToAlphaMatrix());
    }
  }

  /// Конвертирует SVG матрицу 5x4 (20 значений) в Flutter матрицу 4x5 (20 значений)
  ///
  /// SVG формат: строка за строкой (R, G, B, A, 1 для каждой строки)
  /// Flutter формат: столбец за столбцом (RGBA + offset)
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

    // Offset row: Rk, Gk, Bk, Ak (умножаем на 255 так как Flutter работает в [0-1], а SVG в [0-255])
    result.addAll([
      svgMatrix[4] / 255.0,
      svgMatrix[9] / 255.0,
      svgMatrix[14] / 255.0,
      svgMatrix[19] / 255.0,
    ]);

    return result;
  }

  /// Создает матрицу для насыщенности (saturate)
  List<double> _saturateMatrix(double s) {
    // SVG saturate matrix formula
    final r = 0.2126 + 0.7874 * s;
    final g = 0.7152 + 0.2848 * s;
    final b = 0.0722 + 0.9278 * s;

    return [
      r, 0, 0, 0, 0, // Red row
      0, g, 0, 0, 0, // Green row
      0, 0, b, 0, 0, // Blue row
      0, 0, 0, 1, 0, // Alpha row
    ];
  }

  /// Создает матрицу для hue rotation (поворот оттенка)
  List<double> _hueRotateMatrix(double degrees) {
    // Конвертируем градусы в радианы
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

  /// Создает матрицу для luminance to alpha
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

/// Коллекция фильтров в SVG документе
class SvgFilters {
  /// Карта ID фильтра -> список примитивов в порядке объявления.
  final Map<String, List<SvgFilter>> _filters = {};
  List<SvgFilterPaintPass>? _activeFillPaint;
  List<SvgFilterPaintPass>? _activeStrokePaint;
  List<SvgFilterPaintPass>? _activeBackgroundImage;
  List<SvgFilterPaintPass>? _activeBackgroundAlpha;

  /// Добавить фильтр
  void add(SvgFilter filter) {
    _filters.putIfAbsent(filter.id, () => <SvgFilter>[]).add(filter);
  }

  /// Получить последний примитив фильтра по ID (совместимость с legacy API).
  SvgFilter? getById(String id) {
    final list = _filters[id];
    if (list == null || list.isEmpty) {
      return null;
    }
    return list.last;
  }

  /// Получить все примитивы фильтра по ID в порядке объявления.
  List<SvgFilter> getAllById(String id) {
    final list = _filters[id];
    if (list == null) {
      return const <SvgFilter>[];
    }
    return List<SvgFilter>.unmodifiable(list);
  }

  /// Проверить наличие фильтра
  bool hasFilter(String id) {
    final list = _filters[id];
    return list != null && list.isNotEmpty;
  }

  /// Разрешает фильтр в один или несколько paint-проходов.
  ///
  /// Для `feDropShadow` и `feMerge` возвращает multi-pass результат,
  /// чтобы painter мог рендерить исходник и производные результаты по отдельности.
  List<SvgFilterPaintPass> resolvePaintPasses(
    String id, {
    SvgFilterSourceContext? sourceContext,
  }) {
    final list = _filters[id];
    if (list == null || list.isEmpty) {
      return const <SvgFilterPaintPass>[SvgFilterPaintPass.identity];
    }

    final previousFillPaint = _activeFillPaint;
    final previousStrokePaint = _activeStrokePaint;
    final previousBackgroundImage = _activeBackgroundImage;
    final previousBackgroundAlpha = _activeBackgroundAlpha;
    _activeFillPaint = sourceContext?.fillPaint == null
        ? null
        : <SvgFilterPaintPass>[...sourceContext!.fillPaint!];
    _activeStrokePaint = sourceContext?.strokePaint == null
        ? null
        : <SvgFilterPaintPass>[...sourceContext!.strokePaint!];
    _activeBackgroundImage = sourceContext?.backgroundImage == null
        ? null
        : <SvgFilterPaintPass>[...sourceContext!.backgroundImage!];
    _activeBackgroundAlpha = sourceContext?.backgroundAlpha == null
        ? null
        : <SvgFilterPaintPass>[...sourceContext!.backgroundAlpha!];

    try {
      const sourceGraphic = <SvgFilterPaintPass>[SvgFilterPaintPass.identity];
      final sourceAlpha = <SvgFilterPaintPass>[
        const SvgFilterPaintPass(
          colorFilter: ui.ColorFilter.mode(
            ui.Color(0xFFFFFFFF),
            ui.BlendMode.srcIn,
          ),
        ),
      ];

      final namedResults = <String, List<SvgFilterPaintPass>>{};
      var previous = <SvgFilterPaintPass>[...sourceGraphic];

      for (final primitive in list) {
        List<SvgFilterPaintPass> output;
        switch (primitive.type) {
          case SvgFilterType.gaussianBlur:
            final blur = primitive as SvgGaussianBlurFilter;
            final input = _resolveInputPasses(
              requestedInput: blur.input,
              previous: previous,
              namedResults: namedResults,
              sourceGraphic: sourceGraphic,
              sourceAlpha: sourceAlpha,
            );
            final blurFilter = blur.apply();
            output = input
                .map(
                  (pass) => pass.copyWith(
                    imageFilter: _composeImageFilter(
                      blurFilter,
                      pass.imageFilter,
                    ),
                  ),
                )
                .toList(growable: false);

          case SvgFilterType.morphology:
            final morphology = primitive as SvgMorphologyFilter;
            final input = _resolveInputPasses(
              requestedInput: morphology.input,
              previous: previous,
              namedResults: namedResults,
              sourceGraphic: sourceGraphic,
              sourceAlpha: sourceAlpha,
            );
            final morphologyFilter = morphology.apply();
            if (morphologyFilter == null) {
              output = input;
            } else {
              output = input
                  .map(
                    (pass) => pass.copyWith(
                      imageFilter: _composeImageFilter(
                        morphologyFilter,
                        pass.imageFilter,
                      ),
                    ),
                  )
                  .toList(growable: false);
            }

          case SvgFilterType.displacementMap:
            final displacement = primitive as SvgDisplacementMapFilter;
            final input = _resolveInputPasses(
              requestedInput: displacement.input,
              previous: previous,
              namedResults: namedResults,
              sourceGraphic: sourceGraphic,
              sourceAlpha: sourceAlpha,
            );
            final zeroScale = displacement.scale.abs() <= 0.000001;
            final input2Ref = displacement.input2?.trim();
            final input2IsNone = _isNoneInputReference(input2Ref);
            if (!zeroScale &&
                input2Ref != null &&
                input2Ref.isNotEmpty &&
                !input2IsNone) {
              final input2 = _resolveInputPasses(
                requestedInput: input2Ref,
                previous: previous,
                namedResults: namedResults,
                sourceGraphic: sourceGraphic,
                sourceAlpha: sourceAlpha,
              );
              // If explicit in2 cannot be resolved, this primitive produces no
              // output instead of inheriting previous output.
              output = input2.isEmpty ? const <SvgFilterPaintPass>[] : input;
            } else {
              // scale=0 is identity displacement and does not require map input.
              output = input;
            }

          case SvgFilterType.image:
            final imagePrimitive = primitive as SvgFeImageFilter;
            final inputRef = imagePrimitive.input?.trim();
            if (inputRef != null && inputRef.isNotEmpty) {
              output = _resolveInputPasses(
                requestedInput: inputRef,
                previous: previous,
                namedResults: namedResults,
                sourceGraphic: sourceGraphic,
                sourceAlpha: sourceAlpha,
              );
            } else if ((imagePrimitive.href ?? '').trim().isNotEmpty) {
              // Non-source primitive semantics: feImage with href starts a new
              // primitive output instead of inheriting previous chain state.
              // Baseline renderer uses SourceGraphic as placeholder source.
              output = <SvgFilterPaintPass>[...sourceGraphic];
            } else {
              output = previous.isEmpty
                  ? <SvgFilterPaintPass>[...sourceGraphic]
                  : previous;
            }

          case SvgFilterType.convolveMatrix:
            final convolve = primitive as SvgConvolveMatrixFilter;
            output = _resolveInputPasses(
              requestedInput: convolve.input,
              previous: previous,
              namedResults: namedResults,
              sourceGraphic: sourceGraphic,
              sourceAlpha: sourceAlpha,
            );

          case SvgFilterType.turbulence:
            final turbulence = primitive as SvgTurbulenceFilter;
            output = _resolveInputPasses(
              requestedInput: turbulence.input,
              previous: previous,
              namedResults: namedResults,
              sourceGraphic: sourceGraphic,
              sourceAlpha: sourceAlpha,
            );

          case SvgFilterType.componentTransfer:
            final componentTransfer = primitive as SvgComponentTransferFilter;
            output = _resolveInputPasses(
              requestedInput: componentTransfer.input,
              previous: previous,
              namedResults: namedResults,
              sourceGraphic: sourceGraphic,
              sourceAlpha: sourceAlpha,
            );

          case SvgFilterType.diffuseLighting:
            final diffuseLighting = primitive as SvgDiffuseLightingFilter;
            output = _resolveInputPasses(
              requestedInput: diffuseLighting.input,
              previous: previous,
              namedResults: namedResults,
              sourceGraphic: sourceGraphic,
              sourceAlpha: sourceAlpha,
            );

          case SvgFilterType.specularLighting:
            final specularLighting = primitive as SvgSpecularLightingFilter;
            output = _resolveInputPasses(
              requestedInput: specularLighting.input,
              previous: previous,
              namedResults: namedResults,
              sourceGraphic: sourceGraphic,
              sourceAlpha: sourceAlpha,
            );

          case SvgFilterType.offset:
            final offset = primitive as SvgOffsetFilter;
            final input = _resolveInputPasses(
              requestedInput: offset.input,
              previous: previous,
              namedResults: namedResults,
              sourceGraphic: sourceGraphic,
              sourceAlpha: sourceAlpha,
            );
            output = input
                .map(
                  (pass) => pass.copyWith(
                    offset: pass.offset + ui.Offset(offset.dx, offset.dy),
                  ),
                )
                .toList(growable: false);

          case SvgFilterType.flood:
            final flood = primitive as SvgFloodFilter;
            output = <SvgFilterPaintPass>[
              SvgFilterPaintPass(
                colorFilter: ui.ColorFilter.mode(
                  flood.effectiveColor,
                  ui.BlendMode.src,
                ),
              ),
            ];

          case SvgFilterType.blend:
            final blend = primitive as SvgBlendFilter;
            final inputRef = blend.input?.trim();
            final input = _resolveInputPasses(
              requestedInput: inputRef,
              previous: previous,
              namedResults: namedResults,
              sourceGraphic: sourceGraphic,
              sourceAlpha: sourceAlpha,
            );
            if (inputRef != null && inputRef.isNotEmpty && input.isEmpty) {
              output = const <SvgFilterPaintPass>[];
              break;
            }
            final blendedTop = input
                .map((pass) => pass.copyWith(blendMode: blend.mode))
                .toList(growable: false);
            final input2Ref = blend.input2?.trim();
            final input2IsNone = _isNoneInputReference(input2Ref);
            if (input2Ref == null || input2Ref.isEmpty || input2IsNone) {
              output = blendedTop;
            } else {
              final input2 = _resolveInputPasses(
                requestedInput: input2Ref,
                previous: previous,
                namedResults: namedResults,
                sourceGraphic: sourceGraphic,
                sourceAlpha: sourceAlpha,
              );
              if (input2.isEmpty) {
                output = const <SvgFilterPaintPass>[];
              } else {
                output = <SvgFilterPaintPass>[...input2, ...blendedTop];
              }
            }

          case SvgFilterType.composite:
            final composite = primitive as SvgCompositeFilter;
            final inputRef = composite.input?.trim();
            final input = _resolveInputPasses(
              requestedInput: inputRef,
              previous: previous,
              namedResults: namedResults,
              sourceGraphic: sourceGraphic,
              sourceAlpha: sourceAlpha,
            );
            if (inputRef != null && inputRef.isNotEmpty && input.isEmpty) {
              output = const <SvgFilterPaintPass>[];
              break;
            }
            if (composite.mode == null) {
              output = _resolveArithmeticCompositePasses(
                composite: composite,
                input: input,
                previous: previous,
                namedResults: namedResults,
                sourceGraphic: sourceGraphic,
                sourceAlpha: sourceAlpha,
              );
            } else {
              final compositedTop = input
                  .map((pass) => pass.copyWith(blendMode: composite.mode))
                  .toList(growable: false);
              final input2Ref = composite.input2?.trim();
              final input2IsNone = _isNoneInputReference(input2Ref);
              if (input2Ref == null || input2Ref.isEmpty || input2IsNone) {
                output = compositedTop;
              } else {
                final input2 = _resolveInputPasses(
                  requestedInput: input2Ref,
                  previous: previous,
                  namedResults: namedResults,
                  sourceGraphic: sourceGraphic,
                  sourceAlpha: sourceAlpha,
                );
                if (input2.isEmpty) {
                  output = const <SvgFilterPaintPass>[];
                } else {
                  output = <SvgFilterPaintPass>[...input2, ...compositedTop];
                }
              }
            }

          case SvgFilterType.merge:
            final merge = primitive as SvgMergeFilter;
            final merged = <SvgFilterPaintPass>[];
            if (merge.nodeInputs.isEmpty) {
              merged.addAll(previous);
              output = merged.isEmpty ? previous : merged;
            } else {
              for (final nodeInput in merge.nodeInputs) {
                merged.addAll(
                  _resolveInputPasses(
                    requestedInput: nodeInput,
                    previous: previous,
                    namedResults: namedResults,
                    sourceGraphic: sourceGraphic,
                    sourceAlpha: sourceAlpha,
                    // Explicit unresolved merge-node inputs are treated as
                    // empty inputs. Implicit node input (missing `in`) still
                    // resolves via previous-chain semantics.
                  ),
                );
              }
              output = merged;
            }

          case SvgFilterType.tile:
            final tile = primitive as SvgTileFilter;
            output = _resolveInputPasses(
              requestedInput: tile.input,
              previous: previous,
              namedResults: namedResults,
              sourceGraphic: sourceGraphic,
              sourceAlpha: sourceAlpha,
            );

          case SvgFilterType.dropShadow:
            final shadow = primitive as SvgDropShadowFilter;
            final input = _resolveInputPasses(
              requestedInput: shadow.input,
              previous: previous,
              namedResults: namedResults,
              sourceGraphic: sourceGraphic,
              sourceAlpha: sourceAlpha,
            );
            final shadowFilter = shadow.apply();
            final shadowPasses = input
                .map(
                  (pass) => SvgFilterPaintPass(
                    imageFilter: _composeImageFilter(
                      shadowFilter,
                      pass.imageFilter,
                    ),
                    colorFilter: ui.ColorFilter.mode(
                      shadow.effectiveShadowColor,
                      ui.BlendMode.srcIn,
                    ),
                    blendMode: ui.BlendMode.srcOver,
                    offset: pass.offset + shadow.offset,
                    paintFill: pass.paintFill,
                    paintStroke: pass.paintStroke,
                  ),
                )
                .toList(growable: false);
            output = <SvgFilterPaintPass>[...shadowPasses, ...input];

          case SvgFilterType.colorMatrix:
            final colorMatrix = primitive as SvgColorMatrixFilter;
            final input = _resolveInputPasses(
              requestedInput: colorMatrix.input,
              previous: previous,
              namedResults: namedResults,
              sourceGraphic: sourceGraphic,
              sourceAlpha: sourceAlpha,
            );
            final colorFilter = colorMatrix.colorFilter();
            if (colorFilter == null) {
              output = input;
            } else {
              output = input
                  .map((pass) => pass.copyWith(colorFilter: colorFilter))
                  .toList(growable: false);
            }
        }

        previous = output;
        final resultName = primitive.resultName?.trim();
        if (resultName != null && resultName.isNotEmpty) {
          namedResults[resultName] = output
              .map(
                (pass) => SvgFilterPaintPass(
                  imageFilter: pass.imageFilter,
                  colorFilter: pass.colorFilter,
                  blendMode: pass.blendMode,
                  offset: pass.offset,
                  paintFill: pass.paintFill,
                  paintStroke: pass.paintStroke,
                ),
              )
              .toList(growable: false);
        }
      }

      if (previous.isEmpty) {
        return const <SvgFilterPaintPass>[SvgFilterPaintPass.identity];
      }
      return previous;
    } finally {
      _activeFillPaint = previousFillPaint;
      _activeStrokePaint = previousStrokePaint;
      _activeBackgroundImage = previousBackgroundImage;
      _activeBackgroundAlpha = previousBackgroundAlpha;
    }
  }

  List<SvgFilterPaintPass> _resolveArithmeticCompositePasses({
    required SvgCompositeFilter composite,
    required List<SvgFilterPaintPass> input,
    required List<SvgFilterPaintPass> previous,
    required Map<String, List<SvgFilterPaintPass>> namedResults,
    required List<SvgFilterPaintPass> sourceGraphic,
    required List<SvgFilterPaintPass> sourceAlpha,
  }) {
    final k1 = composite.k1;
    final k2 = composite.k2;
    final k3 = composite.k3;
    final k4 = composite.k4;

    final k1Zero = _isApproximately(k1, 0.0);
    final k2Zero = _isApproximately(k2, 0.0);
    final k3Zero = _isApproximately(k3, 0.0);
    final k4Zero = _isApproximately(k4, 0.0);
    final k2One = _isApproximately(k2, 1.0);
    final k3One = _isApproximately(k3, 1.0);

    // arithmetic with all-zero coefficients produces transparent black.
    if (k1Zero && k2Zero && k3Zero && k4Zero) {
      return const <SvgFilterPaintPass>[];
    }

    // arithmetic(k2=1) degenerates to input image.
    if (k1Zero && k3Zero && k4Zero && k2One) {
      return input;
    }

    final input2Ref = composite.input2?.trim();
    final input2IsNone = _isNoneInputReference(input2Ref);
    List<SvgFilterPaintPass> resolveInput2() {
      if (input2IsNone) {
        return const <SvgFilterPaintPass>[];
      }
      return _resolveInputPasses(
        requestedInput: input2Ref,
        previous: previous,
        namedResults: namedResults,
        sourceGraphic: sourceGraphic,
        sourceAlpha: sourceAlpha,
      );
    }

    // arithmetic(k3=1) degenerates to in2.
    if (k1Zero && k2Zero && k4Zero && k3One) {
      if (input2Ref == null || input2Ref.isEmpty) {
        return input;
      }
      final input2 = resolveInput2();
      return input2.isEmpty ? const <SvgFilterPaintPass>[] : input2;
    }

    // arithmetic(k2=1,k3=1) approximates additive composition of in and in2.
    if (k1Zero && k4Zero && k2One && k3One) {
      if (input2Ref == null || input2Ref.isEmpty) {
        return input;
      }
      final input2 = resolveInput2();
      if (input2.isEmpty && !input2IsNone) {
        return const <SvgFilterPaintPass>[];
      }
      final additiveTop = input
          .map((pass) => pass.copyWith(blendMode: ui.BlendMode.plus))
          .toList(growable: false);
      return <SvgFilterPaintPass>[...input2, ...additiveTop];
    }

    return input;
  }

  bool _isNoneInputReference(String? inputRef) {
    if (inputRef == null) {
      return false;
    }
    return inputRef.trim().toLowerCase() == 'none';
  }

  bool _isApproximately(
    double value,
    double expected, [
    double epsilon = 1e-6,
  ]) {
    return (value - expected).abs() <= epsilon;
  }

  List<SvgFilterPaintPass> _resolveInputPasses({
    required String? requestedInput,
    required List<SvgFilterPaintPass> previous,
    required Map<String, List<SvgFilterPaintPass>> namedResults,
    required List<SvgFilterPaintPass> sourceGraphic,
    required List<SvgFilterPaintPass> sourceAlpha,
    bool fallbackToPreviousOnUnknown = false,
  }) {
    final normalized = requestedInput?.trim();
    if (normalized == null || normalized.isEmpty) {
      return previous.isEmpty
          ? <SvgFilterPaintPass>[...sourceGraphic]
          : previous;
    }

    // `in="none"` explicitly requests transparent-black input.
    // It should never fall back to previous output, including merge-node flow.
    if (normalized.toLowerCase() == 'none') {
      return const <SvgFilterPaintPass>[];
    }

    final builtIn = _resolveBuiltInInputPasses(
      normalized,
      sourceGraphic: sourceGraphic,
      sourceAlpha: sourceAlpha,
    );
    if (builtIn != null) {
      return builtIn;
    }

    final named = namedResults[normalized];
    if (named != null && named.isNotEmpty) {
      return <SvgFilterPaintPass>[...named];
    }

    // Built-in inputs are accepted case-insensitively for baseline parity.
    final builtInCaseInsensitive = _resolveBuiltInInputPasses(
      normalized.toLowerCase(),
      sourceGraphic: sourceGraphic,
      sourceAlpha: sourceAlpha,
      isNormalizedLowerCase: true,
    );
    if (builtInCaseInsensitive != null) {
      return builtInCaseInsensitive;
    }

    if (fallbackToPreviousOnUnknown) {
      return previous.isEmpty
          ? <SvgFilterPaintPass>[...sourceGraphic]
          : previous;
    }

    // Explicit unresolved primitive inputs should not fall back to previous
    // output when fallback is disabled (e.g. merge node semantics).
    return const <SvgFilterPaintPass>[];
  }

  List<SvgFilterPaintPass>? _resolveBuiltInInputPasses(
    String normalizedInput, {
    required List<SvgFilterPaintPass> sourceGraphic,
    required List<SvgFilterPaintPass> sourceAlpha,
    bool isNormalizedLowerCase = false,
  }) {
    final fillPaint =
        _activeFillPaint ??
        _maskPaintSourcePasses(
          sourceGraphic,
          paintFill: true,
          paintStroke: false,
        );
    final strokePaint =
        _activeStrokePaint ??
        _maskPaintSourcePasses(
          sourceGraphic,
          paintFill: false,
          paintStroke: true,
        );
    final backgroundImage = _activeBackgroundImage ?? sourceGraphic;
    final backgroundAlpha = _activeBackgroundAlpha ?? sourceAlpha;

    switch (normalizedInput) {
      case 'SourceGraphic':
        return <SvgFilterPaintPass>[...sourceGraphic];
      case 'SourceAlpha':
        return <SvgFilterPaintPass>[...sourceAlpha];
      case 'BackgroundImage':
        return <SvgFilterPaintPass>[...backgroundImage];
      case 'BackgroundAlpha':
        return <SvgFilterPaintPass>[...backgroundAlpha];
      case 'FillPaint':
        return <SvgFilterPaintPass>[...fillPaint];
      case 'StrokePaint':
        return <SvgFilterPaintPass>[...strokePaint];
    }

    if (!isNormalizedLowerCase) {
      return null;
    }

    switch (normalizedInput) {
      case 'sourcegraphic':
        return <SvgFilterPaintPass>[...sourceGraphic];
      case 'sourcealpha':
        return <SvgFilterPaintPass>[...sourceAlpha];
      case 'backgroundimage':
        return <SvgFilterPaintPass>[...backgroundImage];
      case 'backgroundalpha':
        return <SvgFilterPaintPass>[...backgroundAlpha];
      case 'fillpaint':
        return <SvgFilterPaintPass>[...fillPaint];
      case 'strokepaint':
        return <SvgFilterPaintPass>[...strokePaint];
      default:
        return null;
    }
  }

  List<SvgFilterPaintPass> _maskPaintSourcePasses(
    List<SvgFilterPaintPass> source, {
    required bool paintFill,
    required bool paintStroke,
  }) {
    return source
        .map(
          (pass) =>
              pass.copyWith(paintFill: paintFill, paintStroke: paintStroke),
        )
        .toList(growable: false);
  }

  ui.ImageFilter? _composeImageFilter(
    ui.ImageFilter? outer,
    ui.ImageFilter? inner,
  ) {
    if (outer == null) return inner;
    if (inner == null) return outer;
    return ui.ImageFilter.compose(outer: outer, inner: inner);
  }

  /// Скомпоновать ImageFilter цепочку для filter id.
  ui.ImageFilter? resolveImageFilter(String id) {
    final passes = resolvePaintPasses(id);
    for (final pass in passes) {
      if (pass.imageFilter != null) {
        return pass.imageFilter;
      }
    }
    return null;
  }

  /// Получить итоговый ColorFilter для цепочки (последний цветовой примитив).
  ui.ColorFilter? resolveColorFilter(String id) {
    final passes = resolvePaintPasses(id);
    ui.ColorFilter? result;
    for (final pass in passes) {
      final colorFilter = pass.colorFilter;
      if (colorFilter != null) {
        result = colorFilter;
      }
    }
    return result;
  }

  /// Получить итоговый blend mode для цепочки (последний режим композиции).
  ui.BlendMode? resolveBlendMode(String id) {
    final passes = resolvePaintPasses(id);
    ui.BlendMode? result;
    for (final pass in passes) {
      final mode = pass.blendMode;
      if (mode != null) {
        result = mode;
      }
    }
    return result;
  }

  /// Получить все фильтры (flattened).
  List<SvgFilter> get all =>
      _filters.values.expand((filters) => filters).toList(growable: false);
}
