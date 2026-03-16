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
