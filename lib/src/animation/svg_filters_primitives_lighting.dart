part of 'svg_filters.dart';

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
/// Implements Lambertian diffuse lighting model.
/// result.rgb = diffuseConstant * max(0, N·L) * lightColor
/// result.a = 1.0
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

  /// Compute the diffuse lighting color filter based on light source.
  ///
  /// Uses average intensity approximation for ColorFilter-based rendering.
  @override
  ui.ColorFilter? colorFilter() {
    final source = lightSource;
    if (source == null) {
      // No light source - return identity (no color modification)
      return null;
    }

    // Get primary light direction from light source
    final lightDir = source.getPrimaryDirection();
    final lightIntensity = source.getAverageIntensity();

    // Calculate diffuse intensity using default normal (0, 0, 1)
    final calculator = _DiffuseLightingCalculator(
      diffuseConstant: diffuseConstant,
      lightingColor: lightingColor,
    );
    final intensity = calculator.getAverageIntensity(lightDir) * lightIntensity;

    // Create modulated color
    final effectiveColor = ui.Color.fromARGB(
      255, // Diffuse always has alpha = 1.0
      (lightingColor.r * 255.0 * intensity).round().clamp(0, 255),
      (lightingColor.g * 255.0 * intensity).round().clamp(0, 255),
      (lightingColor.b * 255.0 * intensity).round().clamp(0, 255),
    );

    // Use srcIn blend mode to apply lighting color to input alpha shape
    return ui.ColorFilter.mode(effectiveColor, ui.BlendMode.srcIn);
  }
}

/// `feSpecularLighting` primitive
///
/// Implements Blinn-Phong specular lighting model.
/// H = normalize(L + (0, 0, 1))
/// result.rgb = specularConstant * max(0, N·H)^specularExponent * lightColor
/// result.a = max(result.r, result.g, result.b)
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

  /// Compute the specular lighting color filter based on light source.
  ///
  /// Uses average intensity approximation for ColorFilter-based rendering.
  @override
  ui.ColorFilter? colorFilter() {
    final source = lightSource;
    if (source == null) {
      // No light source - return identity (no color modification)
      return null;
    }

    // Get primary light direction from light source
    final lightDir = source.getPrimaryDirection();
    final lightIntensity = source.getAverageIntensity();

    // Calculate specular intensity using default normal (0, 0, 1)
    final calculator = _SpecularLightingCalculator(
      specularConstant: specularConstant,
      specularExponent: specularExponent,
      lightingColor: lightingColor,
    );
    final intensity = calculator.getAverageIntensity(lightDir) * lightIntensity;

    // Create modulated color
    // For specular, alpha = max(r, g, b) / 255
    final r = (lightingColor.r * 255.0 * intensity).round().clamp(0, 255);
    final g = (lightingColor.g * 255.0 * intensity).round().clamp(0, 255);
    final b = (lightingColor.b * 255.0 * intensity).round().clamp(0, 255);
    final a = math.max(r, math.max(g, b));

    final effectiveColor = ui.Color.fromARGB(a, r, g, b);

    // Use srcIn blend mode to apply lighting color to input alpha shape
    return ui.ColorFilter.mode(effectiveColor, ui.BlendMode.srcIn);
  }
}

/// Paint pass for feDiffuseLighting that requires pixel-level processing.
///
/// Implements full Blink-style diffuse lighting with:
/// - Per-pixel surface normal computation from bump map
/// - Light direction calculation based on light source type
/// - Lambertian diffuse shading model
class SvgDiffuseLightingPaintPass extends SvgFilterPaintPass {
  const SvgDiffuseLightingPaintPass({
    required this.lightingFilter,
    super.imageFilter,
    super.colorFilter,
    super.blendMode,
    super.offset,
    super.paintFill,
    super.paintStroke,
  });

  /// The diffuse lighting filter configuration.
  final SvgDiffuseLightingFilter lightingFilter;

  /// Get the light source from the filter.
  SvgLightSource? get lightSource => lightingFilter.lightSource;

  /// Get the surface scale.
  double get surfaceScale => lightingFilter.surfaceScale;

  /// Get the diffuse constant.
  double get diffuseConstant => lightingFilter.diffuseConstant;

  /// Get the lighting color.
  ui.Color get lightingColor => lightingFilter.lightingColor;

  /// Get kernel unit length X.
  double? get kernelUnitLengthX => lightingFilter.kernelUnitLengthX;

  /// Get kernel unit length Y.
  double? get kernelUnitLengthY => lightingFilter.kernelUnitLengthY;

  bool get _usesObjectBoundingBoxPrimitiveUnits {
    final dynamic source = lightingFilter.sourceElement;
    final rawPrimitiveUnits = source?.parent
        ?.getRawAttributeValue('primitiveUnits')
        ?.toString()
        .trim();
    if (rawPrimitiveUnits == null || rawPrimitiveUnits.isEmpty) {
      return false; // default: userSpaceOnUse
    }
    return rawPrimitiveUnits.toLowerCase() == 'objectboundingbox';
  }

  /// Create a LightingProcessor for this filter.
  LightingProcessor? createProcessor({
    double? objectBoundingBoxWidth,
    double? objectBoundingBoxHeight,
    double? objectBoundingBoxX,
    double? objectBoundingBoxY,
    double surfaceOriginX = 0.0,
    double surfaceOriginY = 0.0,
  }) {
    final source = lightSource;
    if (source == null) return null;

    return LightingProcessor(
      surfaceScale: surfaceScale,
      lightSource: source,
      lightingColor: lightingColor,
      kernelUnitLengthX: kernelUnitLengthX,
      kernelUnitLengthY: kernelUnitLengthY,
      primitiveUnitsObjectBoundingBox: _usesObjectBoundingBoxPrimitiveUnits,
      objectBoundingBoxWidth: objectBoundingBoxWidth,
      objectBoundingBoxHeight: objectBoundingBoxHeight,
      objectBoundingBoxX: objectBoundingBoxX,
      objectBoundingBoxY: objectBoundingBoxY,
      surfaceOriginX: surfaceOriginX,
      surfaceOriginY: surfaceOriginY,
    );
  }

  @override
  SvgFilterPaintPass copyWith({
    ui.ImageFilter? imageFilter,
    ui.ColorFilter? colorFilter,
    ui.BlendMode? blendMode,
    ui.Offset? offset,
    bool? paintFill,
    bool? paintStroke,
  }) {
    return SvgDiffuseLightingPaintPass(
      lightingFilter: lightingFilter,
      imageFilter: imageFilter ?? this.imageFilter,
      colorFilter: colorFilter ?? this.colorFilter,
      blendMode: blendMode ?? this.blendMode,
      offset: offset ?? this.offset,
      paintFill: paintFill ?? this.paintFill,
      paintStroke: paintStroke ?? this.paintStroke,
    );
  }
}

/// Paint pass for feSpecularLighting that requires pixel-level processing.
///
/// Implements full Blink-style specular lighting with:
/// - Per-pixel surface normal computation from bump map
/// - Light direction calculation based on light source type
/// - Blinn-Phong specular shading model
/// - Alpha output equals max(r, g, b)
class SvgSpecularLightingPaintPass extends SvgFilterPaintPass {
  const SvgSpecularLightingPaintPass({
    required this.lightingFilter,
    super.imageFilter,
    super.colorFilter,
    super.blendMode,
    super.offset,
    super.paintFill,
    super.paintStroke,
  });

  /// The specular lighting filter configuration.
  final SvgSpecularLightingFilter lightingFilter;

  /// Get the light source from the filter.
  SvgLightSource? get lightSource => lightingFilter.lightSource;

  /// Get the surface scale.
  double get surfaceScale => lightingFilter.surfaceScale;

  /// Get the specular constant.
  double get specularConstant => lightingFilter.specularConstant;

  /// Get the specular exponent.
  double get specularExponent => lightingFilter.specularExponent;

  /// Get the lighting color.
  ui.Color get lightingColor => lightingFilter.lightingColor;

  /// Get kernel unit length X.
  double? get kernelUnitLengthX => lightingFilter.kernelUnitLengthX;

  /// Get kernel unit length Y.
  double? get kernelUnitLengthY => lightingFilter.kernelUnitLengthY;

  bool get _usesObjectBoundingBoxPrimitiveUnits {
    final dynamic source = lightingFilter.sourceElement;
    final rawPrimitiveUnits = source?.parent
        ?.getRawAttributeValue('primitiveUnits')
        ?.toString()
        .trim();
    if (rawPrimitiveUnits == null || rawPrimitiveUnits.isEmpty) {
      return false; // default: userSpaceOnUse
    }
    return rawPrimitiveUnits.toLowerCase() == 'objectboundingbox';
  }

  /// Create a LightingProcessor for this filter.
  LightingProcessor? createProcessor({
    double? objectBoundingBoxWidth,
    double? objectBoundingBoxHeight,
    double? objectBoundingBoxX,
    double? objectBoundingBoxY,
    double surfaceOriginX = 0.0,
    double surfaceOriginY = 0.0,
  }) {
    final source = lightSource;
    if (source == null) return null;

    return LightingProcessor(
      surfaceScale: surfaceScale,
      lightSource: source,
      lightingColor: lightingColor,
      kernelUnitLengthX: kernelUnitLengthX,
      kernelUnitLengthY: kernelUnitLengthY,
      primitiveUnitsObjectBoundingBox: _usesObjectBoundingBoxPrimitiveUnits,
      objectBoundingBoxWidth: objectBoundingBoxWidth,
      objectBoundingBoxHeight: objectBoundingBoxHeight,
      objectBoundingBoxX: objectBoundingBoxX,
      objectBoundingBoxY: objectBoundingBoxY,
      surfaceOriginX: surfaceOriginX,
      surfaceOriginY: surfaceOriginY,
    );
  }

  @override
  SvgFilterPaintPass copyWith({
    ui.ImageFilter? imageFilter,
    ui.ColorFilter? colorFilter,
    ui.BlendMode? blendMode,
    ui.Offset? offset,
    bool? paintFill,
    bool? paintStroke,
  }) {
    return SvgSpecularLightingPaintPass(
      lightingFilter: lightingFilter,
      imageFilter: imageFilter ?? this.imageFilter,
      colorFilter: colorFilter ?? this.colorFilter,
      blendMode: blendMode ?? this.blendMode,
      offset: offset ?? this.offset,
      paintFill: paintFill ?? this.paintFill,
      paintStroke: paintStroke ?? this.paintStroke,
    );
  }
}
