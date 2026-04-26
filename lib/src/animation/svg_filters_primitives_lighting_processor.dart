part of 'svg_filters.dart';

/// Helper extension to compute lighting effect from light source.
extension SvgLightSourceExtension on SvgLightSource {
  /// Get the primary light direction for this light source.
  ///
  /// For distant lights, returns the constant direction.
  /// For point/spot lights, returns direction from origin as approximation.
  // ignore: library_private_types_in_public_api
  _LightingVector3 getPrimaryDirection() {
    if (this is SvgDistantLightSource) {
      final distant = this as SvgDistantLightSource;
      return _DistantLightCalculator(
        azimuthDegrees: distant.azimuth,
        elevationDegrees: distant.elevation,
      ).direction;
    } else if (this is SvgPointLightSource) {
      final point = this as SvgPointLightSource;
      // Direction from origin to light (approximate)
      return _LightingVector3(point.x, point.y, point.z).normalize();
    } else if (this is SvgSpotLightSource) {
      final spot = this as SvgSpotLightSource;
      // Use spot direction
      return _SpotLightCalculator(
            lightX: spot.x,
            lightY: spot.y,
            lightZ: spot.z,
            pointsAtX: spot.pointsAtX,
            pointsAtY: spot.pointsAtY,
            pointsAtZ: spot.pointsAtZ,
            specularExponent: spot.specularExponent,
            limitingConeAngleDegrees: spot.limitingConeAngle,
          ).spotDirection *
          -1.0; // Reverse for light direction
    }
    // Default: light from above
    return const _LightingVector3(0, 0, 1);
  }

  /// Get average light intensity (1.0 for distant/point, variable for spot).
  double getAverageIntensity() {
    if (this is SvgSpotLightSource) {
      // Spot light has attenuation, use 0.5 as average
      return 0.5;
    }
    return 1.0;
  }

  /// Get light direction and intensity at a specific surface point.
  ///
  /// [surfaceX], [surfaceY], [surfaceZ] are the surface point coordinates.
  /// Returns (direction, intensity) tuple.
  (_LightingVector3, double) getDirectionAndIntensityAt(
    double surfaceX,
    double surfaceY,
    double surfaceZ,
  ) {
    if (this is SvgDistantLightSource) {
      final distant = this as SvgDistantLightSource;
      final dir = _DistantLightCalculator(
        azimuthDegrees: distant.azimuth,
        elevationDegrees: distant.elevation,
      ).direction;
      return (dir, 1.0);
    } else if (this is SvgPointLightSource) {
      final point = this as SvgPointLightSource;
      final calc = _PointLightCalculator(
        lightX: point.x,
        lightY: point.y,
        lightZ: point.z,
        // SVG fePointLight does not define distance falloff attenuation.
        useDistanceAttenuation: false,
      );
      return calc.directionAndIntensityAt(surfaceX, surfaceY, surfaceZ);
    } else if (this is SvgSpotLightSource) {
      final spot = this as SvgSpotLightSource;
      final calc = _SpotLightCalculator(
        lightX: spot.x,
        lightY: spot.y,
        lightZ: spot.z,
        pointsAtX: spot.pointsAtX,
        pointsAtY: spot.pointsAtY,
        pointsAtZ: spot.pointsAtZ,
        specularExponent: spot.specularExponent,
        limitingConeAngleDegrees: spot.limitingConeAngle,
      );
      return calc.directionAndIntensityAt(surfaceX, surfaceY, surfaceZ);
    }
    // Default: light from above
    return (const _LightingVector3(0, 0, 1), 1.0);
  }
}

/// Per-pixel lighting processor for full Blink-style lighting effects.
///
/// This class handles the complete lighting computation pipeline:
/// 1. Extract alpha channel as height map
/// 2. Compute surface normals using Sobel operator
/// 3. Apply lighting model (diffuse or specular) per pixel
/// 4. Output RGBA image data
class LightingProcessor {
  const LightingProcessor({
    required this.surfaceScale,
    required this.lightSource,
    required this.lightingColor,
    this.kernelUnitLengthX,
    this.kernelUnitLengthY,
    this.edgeMode = LightingEdgeMode.duplicate,
    this.primitiveUnitsObjectBoundingBox = false,
    this.objectBoundingBoxWidth,
    this.objectBoundingBoxHeight,
    this.objectBoundingBoxX,
    this.objectBoundingBoxY,
    this.surfaceOriginX = 0.0,
    this.surfaceOriginY = 0.0,
    this.specularUseInputAlphaMask = false,
    this.specularFlipLightZForHalfVector = false,
  });

  final double surfaceScale;
  final SvgLightSource lightSource;
  final ui.Color lightingColor;
  final double? kernelUnitLengthX;
  final double? kernelUnitLengthY;
  final LightingEdgeMode edgeMode;
  final bool primitiveUnitsObjectBoundingBox;
  final double? objectBoundingBoxWidth;
  final double? objectBoundingBoxHeight;
  final double? objectBoundingBoxX;
  final double? objectBoundingBoxY;
  final double surfaceOriginX;
  final double surfaceOriginY;
  final bool specularUseInputAlphaMask;
  final bool specularFlipLightZForHalfVector;

  SvgLightSource _effectiveLightSourceForImageSize(int width, int height) {
    if (!primitiveUnitsObjectBoundingBox) {
      return lightSource;
    }

    final bboxWidth = (objectBoundingBoxWidth ?? width.toDouble()).clamp(
      0.0,
      double.infinity,
    );
    final bboxHeight = (objectBoundingBoxHeight ?? height.toDouble()).clamp(
      0.0,
      double.infinity,
    );
    if (bboxWidth <= 0 || bboxHeight <= 0) {
      return lightSource;
    }
    final bboxX = objectBoundingBoxX ?? 0.0;
    final bboxY = objectBoundingBoxY ?? 0.0;

    final zScale = math.sqrt(
      (bboxWidth * bboxWidth + bboxHeight * bboxHeight) / 2.0,
    );

    final source = lightSource;
    if (source is SvgPointLightSource) {
      return SvgPointLightSource(
        x: bboxX + source.x * bboxWidth,
        y: bboxY + source.y * bboxHeight,
        z: source.z * zScale,
      );
    }
    if (source is SvgSpotLightSource) {
      return SvgSpotLightSource(
        x: bboxX + source.x * bboxWidth,
        y: bboxY + source.y * bboxHeight,
        z: source.z * zScale,
        pointsAtX: bboxX + source.pointsAtX * bboxWidth,
        pointsAtY: bboxY + source.pointsAtY * bboxHeight,
        pointsAtZ: source.pointsAtZ * zScale,
        specularExponent: source.specularExponent,
        limitingConeAngle: source.limitingConeAngle,
      );
    }

    return source;
  }

  /// Process diffuse lighting on image data.
  ///
  /// [imageData] is RGBA byte array (4 bytes per pixel).
  /// [width], [height] are image dimensions.
  /// [diffuseConstant] is the kd coefficient.
  ///
  /// Returns processed RGBA image data.
  Uint8List processDiffuse(
    Uint8List imageData,
    int width,
    int height,
    double diffuseConstant,
  ) {
    // Extract alpha channel
    final alphaData = _extractAlpha(imageData, width, height);

    // Create normal calculator
    final normalCalc = _SurfaceNormalCalculator(
      surfaceScale: surfaceScale,
      kernelUnitLengthX: kernelUnitLengthX,
      kernelUnitLengthY: kernelUnitLengthY,
      edgeMode: edgeMode,
    );

    // Create output buffer
    final output = Uint8List(width * height * 4);

    final effectiveLightSource = _effectiveLightSourceForImageSize(
      width,
      height,
    );

    // Process each pixel
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final idx = (y * width + x) * 4;

        // Compute surface normal
        final normal = normalCalc.computeNormalAt(
          alphaData,
          x,
          y,
          width,
          height,
        );

        // Compute surface height
        final surfaceZ = alphaData[y * width + x] / 255.0 * surfaceScale;
        final surfaceX = surfaceOriginX + x.toDouble();
        final surfaceY = surfaceOriginY + y.toDouble();

        // Get light direction and intensity
        final (lightDir, lightIntensity) = effectiveLightSource
            .getDirectionAndIntensityAt(surfaceX, surfaceY, surfaceZ);

        // Compute diffuse: kd * max(0, N·L) * lightIntensity
        final nDotL = normal.dot(lightDir).clamp(0.0, 1.0);
        final factor = (diffuseConstant * nDotL * lightIntensity).clamp(
          0.0,
          1.0,
        );

        // Apply to lighting color
        output[idx] = (lightingColor.r * 255 * factor).round().clamp(0, 255);
        output[idx + 1] = (lightingColor.g * 255 * factor).round().clamp(
          0,
          255,
        );
        output[idx + 2] = (lightingColor.b * 255 * factor).round().clamp(
          0,
          255,
        );
        output[idx + 3] = 255; // Diffuse alpha is always 1.0
      }
    }

    return output;
  }

  /// Process specular lighting on image data.
  ///
  /// [imageData] is RGBA byte array (4 bytes per pixel).
  /// [width], [height] are image dimensions.
  /// [specularConstant] is the ks coefficient.
  /// [specularExponent] is the shininess exponent.
  ///
  /// Returns processed RGBA image data.
  Uint8List processSpecular(
    Uint8List imageData,
    int width,
    int height,
    double specularConstant,
    double specularExponent,
  ) {
    // Extract alpha channel
    final alphaData = _extractAlpha(imageData, width, height);

    // Create normal calculator
    final normalCalc = _SurfaceNormalCalculator(
      surfaceScale: surfaceScale,
      kernelUnitLengthX: kernelUnitLengthX,
      kernelUnitLengthY: kernelUnitLengthY,
      edgeMode: edgeMode,
    );

    // Eye direction (viewer at infinity on z-axis)
    const eyeDir = _LightingVector3(0, 0, 1);

    // Create output buffer
    final output = Uint8List(width * height * 4);

    final effectiveLightSource = _effectiveLightSourceForImageSize(
      width,
      height,
    );

    // Process each pixel
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final idx = (y * width + x) * 4;

        // Compute surface normal
        final normal = normalCalc.computeNormalAt(
          alphaData,
          x,
          y,
          width,
          height,
        );

        // Compute surface height
        final surfaceZ = alphaData[y * width + x] / 255.0 * surfaceScale;
        final surfaceX = surfaceOriginX + x.toDouble();
        final surfaceY = surfaceOriginY + y.toDouble();

        // Get light direction and intensity
        final (lightDir, lightIntensity) = effectiveLightSource
            .getDirectionAndIntensityAt(surfaceX, surfaceY, surfaceZ);

        final halfVectorLightDir = specularFlipLightZForHalfVector
            ? _LightingVector3(lightDir.x, lightDir.y, -lightDir.z)
            : lightDir;
        final halfVector = (halfVectorLightDir + eyeDir).normalize();

        // Compute specular: ks * (N·H)^exp * lightIntensity
        final nDotH = normal.dot(halfVector).clamp(0.0, 1.0);
        final specular = math.pow(nDotH, specularExponent).toDouble();
        final alphaFactor = specularUseInputAlphaMask
            ? alphaData[y * width + x] / 255.0
            : 1.0;
        final factor =
            (specularConstant * specular * lightIntensity * alphaFactor).clamp(
              0.0,
              1.0,
            );

        // Apply to lighting color
        final r = (lightingColor.r * 255 * factor).round().clamp(0, 255);
        final g = (lightingColor.g * 255 * factor).round().clamp(0, 255);
        final b = (lightingColor.b * 255 * factor).round().clamp(0, 255);

        output[idx] = r;
        output[idx + 1] = g;
        output[idx + 2] = b;
        // Specular alpha = max(r, g, b)
        output[idx + 3] = math.max(r, math.max(g, b));
      }
    }

    return output;
  }

  /// Extract alpha channel from RGBA image data.
  Uint8List _extractAlpha(Uint8List imageData, int width, int height) {
    final alpha = Uint8List(width * height);
    for (int i = 0; i < width * height; i++) {
      alpha[i] = imageData[i * 4 + 3];
    }
    return alpha;
  }
}

/// Computes a sample of lighting values for a given light source configuration.
///
/// This is useful for generating preview colors or testing lighting setups.
class LightingSampler {
  const LightingSampler({
    required this.lightSource,
    required this.lightingColor,
    required this.surfaceScale,
  });

  final SvgLightSource lightSource;
  final ui.Color lightingColor;
  final double surfaceScale;

  /// Sample diffuse lighting at multiple points.
  ///
  /// Returns average color across sample points.
  ui.Color sampleDiffuse(double diffuseConstant, {int sampleCount = 9}) {
    double totalR = 0, totalG = 0, totalB = 0;
    final gridSize = math.sqrt(sampleCount).ceil();

    for (int i = 0; i < gridSize; i++) {
      for (int j = 0; j < gridSize; j++) {
        final x = i * 10.0;
        final y = j * 10.0;
        final z = surfaceScale * 0.5; // Mid-height assumption

        final (lightDir, intensity) = lightSource.getDirectionAndIntensityAt(
          x,
          y,
          z,
        );

        // Assume flat normal (0, 0, 1) for sampling
        const normal = _LightingVector3(0, 0, 1);
        final nDotL = normal.dot(lightDir).clamp(0.0, 1.0);
        final factor = (diffuseConstant * nDotL * intensity).clamp(0.0, 1.0);

        totalR += lightingColor.r * factor;
        totalG += lightingColor.g * factor;
        totalB += lightingColor.b * factor;
      }
    }

    final count = gridSize * gridSize;
    return ui.Color.fromARGB(
      255,
      (totalR / count * 255).round().clamp(0, 255),
      (totalG / count * 255).round().clamp(0, 255),
      (totalB / count * 255).round().clamp(0, 255),
    );
  }

  /// Sample specular lighting at multiple points.
  ///
  /// Returns average color across sample points.
  ui.Color sampleSpecular(
    double specularConstant,
    double specularExponent, {
    int sampleCount = 9,
  }) {
    double totalR = 0, totalG = 0, totalB = 0;
    final gridSize = math.sqrt(sampleCount).ceil();
    const eyeDir = _LightingVector3(0, 0, 1);

    for (int i = 0; i < gridSize; i++) {
      for (int j = 0; j < gridSize; j++) {
        final x = i * 10.0;
        final y = j * 10.0;
        final z = surfaceScale * 0.5;

        final (lightDir, intensity) = lightSource.getDirectionAndIntensityAt(
          x,
          y,
          z,
        );

        // Assume flat normal for sampling
        const normal = _LightingVector3(0, 0, 1);
        final halfVector = (lightDir + eyeDir).normalize();
        final nDotH = normal.dot(halfVector).clamp(0.0, 1.0);
        final specular = math.pow(nDotH, specularExponent).toDouble();
        final factor = (specularConstant * specular * intensity).clamp(
          0.0,
          1.0,
        );

        totalR += lightingColor.r * factor;
        totalG += lightingColor.g * factor;
        totalB += lightingColor.b * factor;
      }
    }

    final count = gridSize * gridSize;
    final r = (totalR / count * 255).round().clamp(0, 255);
    final g = (totalG / count * 255).round().clamp(0, 255);
    final b = (totalB / count * 255).round().clamp(0, 255);
    return ui.Color.fromARGB(math.max(r, math.max(g, b)), r, g, b);
  }
}
