part of 'svg_filters.dart';

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
