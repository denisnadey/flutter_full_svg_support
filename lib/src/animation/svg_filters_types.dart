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
    this.fillColorOverride,
    this.strokeColorOverride,
  });

  static const SvgFilterPaintPass identity = SvgFilterPaintPass();

  final ui.ImageFilter? imageFilter;
  final ui.ColorFilter? colorFilter;
  final ui.BlendMode? blendMode;
  final ui.Offset offset;
  final bool paintFill;
  final bool paintStroke;
  final ui.Color? fillColorOverride;
  final ui.Color? strokeColorOverride;

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
      fillColorOverride: this.fillColorOverride,
      strokeColorOverride: this.strokeColorOverride,
    );
  }
}

/// Paint pass representing a solid FillPaint/StrokePaint source color.
class SvgSolidPaintSourcePass extends SvgFilterPaintPass {
  const SvgSolidPaintSourcePass({
    required this.paintColor,
    super.imageFilter,
    super.colorFilter,
    super.blendMode,
    super.offset,
    super.paintFill,
    super.paintStroke,
    super.fillColorOverride,
    super.strokeColorOverride,
  });

  final ui.Color paintColor;

  @override
  SvgFilterPaintPass copyWith({
    ui.ImageFilter? imageFilter,
    ui.ColorFilter? colorFilter,
    ui.BlendMode? blendMode,
    ui.Offset? offset,
    bool? paintFill,
    bool? paintStroke,
  }) {
    return SvgSolidPaintSourcePass(
      paintColor: paintColor,
      imageFilter: imageFilter ?? this.imageFilter,
      colorFilter: colorFilter ?? this.colorFilter,
      blendMode: blendMode ?? this.blendMode,
      offset: offset ?? this.offset,
      paintFill: paintFill ?? this.paintFill,
      paintStroke: paintStroke ?? this.paintStroke,
      fillColorOverride: this.fillColorOverride,
      strokeColorOverride: this.strokeColorOverride,
    );
  }
}

/// Paint pass for feImage primitive with element reference or external image.
///
/// This specialized pass carries the feImage configuration so the painter
/// can render the referenced element or external image into the filter subregion.
class SvgFeImagePaintPass extends SvgFilterPaintPass {
  const SvgFeImagePaintPass({
    required this.feImageFilter,
    super.imageFilter,
    super.colorFilter,
    super.blendMode,
    super.offset,
    super.paintFill,
    super.paintStroke,
  });

  /// The feImage filter containing href and preserveAspectRatio settings.
  final SvgFeImageFilter feImageFilter;

  /// Whether this feImage references an SVG element by ID (e.g., `#myRect`).
  bool get isElementReference {
    final href = feImageFilter.href;
    return href != null && href.startsWith('#');
  }

  /// Get the referenced element ID if this is an element reference.
  String? get referencedElementId {
    final href = feImageFilter.href;
    if (href == null || !href.startsWith('#')) return null;
    return href.substring(1);
  }

  /// Whether this feImage references an external image.
  bool get isExternalImage {
    final href = feImageFilter.href;
    return href != null && !href.startsWith('#');
  }

  /// Get the primitive subregion for rendering.
  ui.Rect get subregion => ui.Rect.fromLTWH(
    feImageFilter.x,
    feImageFilter.y,
    feImageFilter.width,
    feImageFilter.height,
  );

  @override
  SvgFilterPaintPass copyWith({
    ui.ImageFilter? imageFilter,
    ui.ColorFilter? colorFilter,
    ui.BlendMode? blendMode,
    ui.Offset? offset,
    bool? paintFill,
    bool? paintStroke,
  }) {
    return SvgFeImagePaintPass(
      feImageFilter: feImageFilter,
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
    this.fillPaintColor,
    this.strokePaintColor,
    this.backgroundImage,
    this.backgroundAlpha,
    this.useLinearRGB = false,
  });

  final List<SvgFilterPaintPass>? fillPaint;
  final List<SvgFilterPaintPass>? strokePaint;
  final ui.Color? fillPaintColor;
  final ui.Color? strokePaintColor;
  final List<SvgFilterPaintPass>? backgroundImage;
  final List<SvgFilterPaintPass>? backgroundAlpha;

  /// Whether filter primitives should operate in linearRGB color space.
  /// Per SVG spec, the default for color-interpolation-filters is linearRGB.
  /// When true, pixel-level filter processors should convert sRGB→linearRGB
  /// before processing and linearRGB→sRGB afterwards.
  final bool useLinearRGB;
}

/// Offset фильтр
///
/// Смещает входное изображение на dx/dy.
class SvgOffsetFilter extends SvgFilter {
  /// Смещение по X
  double dx;

  /// Смещение по Y
  double dy;

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
