part of 'svg_filters.dart';

/// SVG filter type
enum SvgFilterType {
  /// Gaussian blur - blur
  gaussianBlur,

  /// Morphology - dilation/erosion of the alpha mask
  morphology,

  /// Displacement map - pixel displacement via channel map (baseline pass-through)
  displacementMap,

  /// Image - external image source (baseline graph pass-through)
  image,

  /// Convolve matrix - kernel convolution (baseline graph pass-through)
  convolveMatrix,

  /// Turbulence - procedural noise (baseline graph pass-through)
  turbulence,

  /// Component transfer - per-channel color function (baseline graph pass-through)
  componentTransfer,

  /// Diffuse lighting - diffuse shading (baseline graph pass-through)
  diffuseLighting,

  /// Specular lighting - specular shading (baseline graph pass-through)
  specularLighting,

  /// Offset - shift the result
  offset,

  /// Flood - fill with a solid color
  flood,

  /// Blend - blend with the backdrop
  blend,

  /// Composite - composite with the backdrop
  composite,

  /// Merge - combine multiple inputs (feMerge/feMergeNode)
  merge,

  /// Tile - repeat the input image (baseline pass-through)
  tile,

  /// Drop shadow - shadow
  dropShadow,

  /// Color matrix - color transformations
  colorMatrix,
}

/// feMorphology operator
enum SvgMorphologyOperator {
  /// Erosion (shrink)
  erode,

  /// Dilation (expand)
  dilate,
}

/// Channel selector for filter primitives with a channel selector.
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

/// Edge handling mode for feConvolveMatrix.
enum SvgConvolveEdgeMode {
  /// duplicate
  duplicate,

  /// wrap
  wrap,

  /// none
  none,
}

/// Noise generation type for feTurbulence.
enum SvgTurbulenceType {
  /// turbulence
  turbulence,

  /// fractalNoise
  fractalNoise,
}

/// Noise tiling mode for feTurbulence.
enum SvgTurbulenceStitchTiles {
  /// noStitch
  noStitch,

  /// stitch
  stitch,
}

/// Channel function type for feComponentTransfer.
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

/// A single filter paint pass for source graphics.
///
/// The animated painter can render an element in multiple passes
/// (e.g. for `feDropShadow` and `feMerge`).
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
      fillColorOverride: fillColorOverride,
      strokeColorOverride: strokeColorOverride,
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
      fillColorOverride: fillColorOverride,
      strokeColorOverride: strokeColorOverride,
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

/// Offset filter
///
/// Shifts the input image by dx/dy.
class SvgOffsetFilter extends SvgFilter {
  /// X offset
  double dx;

  /// Y offset
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
    // Matrix4 in column-major format: translation in cells [12], [13].
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

/// Paint pass for feComposite arithmetic k2=-1, k3=1 (inner-shadow pattern).
///
/// Rendered with an isolated saveLayer so that the dstOut erase only affects
/// the element's own layer rather than the underlying canvas content.
class SvgInnerShadowPaintPass extends SvgFilterPaintPass {
  const SvgInnerShadowPaintPass({
    required this.sourceGraphicPasses,
    required this.blurAlphaPasses,
    super.blendMode,
    super.offset,
    super.paintFill,
    super.paintStroke,
  });

  /// Passes that draw the shape fill (in2 = SourceGraphic).
  final List<SvgFilterPaintPass> sourceGraphicPasses;

  /// Passes for the blurred alpha mask (in = blur); rendered with dstOut.
  final List<SvgFilterPaintPass> blurAlphaPasses;

  @override
  SvgFilterPaintPass copyWith({
    ui.ImageFilter? imageFilter,
    ui.ColorFilter? colorFilter,
    ui.BlendMode? blendMode,
    ui.Offset? offset,
    bool? paintFill,
    bool? paintStroke,
  }) {
    return SvgInnerShadowPaintPass(
      sourceGraphicPasses: sourceGraphicPasses,
      blurAlphaPasses: blurAlphaPasses,
      blendMode: blendMode ?? this.blendMode,
      offset: offset ?? this.offset,
      paintFill: paintFill ?? this.paintFill,
      paintStroke: paintStroke ?? this.paintStroke,
    );
  }
}

/// Color matrix type for feColorMatrix
enum SvgColorMatrixType {
  /// 5x4 matrix (20 values)
  matrix,

  /// Saturation (1 value: 0-1)
  saturate,

  /// Hue rotate (1 value: degrees)
  hueRotate,

  /// Luminance to alpha (no values)
  luminanceToAlpha,
}
