part of 'animated_svg_painter.dart';

extension AnimatedSvgPainterGradientsExtension on AnimatedSvgPainter {
  ui.Shader? _resolvePaintServerShader(
    Object? paintValue,
    ui.Rect paintBounds,
  ) {
    final serverId = _extractPaintServerId(paintValue);
    if (serverId == null) {
      return null;
    }

    // Try gradient first
    final gradient = _resolveGradientDefinition(serverId);
    if (gradient != null && gradient.stops.isNotEmpty) {
      return _createGradientShaderCached(serverId, gradient, paintBounds);
    }

    // Try pattern
    final patternShader = _createPatternShader(
      serverId,
      targetBounds: paintBounds,
    );
    if (patternShader != null) {
      return patternShader;
    }

    return null;
  }

  /// Creates a gradient shader with caching support.
  ui.Shader? _createGradientShaderCached(
    String gradientId,
    _ResolvedGradientDefinition gradient,
    ui.Rect paintBounds,
  ) {
    // Generate cache key including all gradient parameters
    final cacheKey = _RenderCache.gradientKey(
      gradientId,
      paintBounds,
      gradient.attributes,
    );

    // Check cache first
    final cached = _renderCache.gradientShaders[cacheKey];
    if (cached != null) {
      return cached;
    }

    // Create the shader
    final shader = _createGradientShader(gradient, paintBounds);

    // Cache the result if valid
    if (shader != null) {
      _renderCache.gradientShaders[cacheKey] = shader;
    }

    return shader;
  }

  ui.Shader? _createGradientShader(
    _ResolvedGradientDefinition gradient,
    ui.Rect paintBounds,
  ) {
    final bounds = _normalizePaintBounds(paintBounds);
    final gradientUnits = gradient.attributes['gradientUnits']
        ?.toString()
        .trim()
        .toLowerCase();
    final isUserSpaceOnUse = gradientUnits == 'userspaceonuse';
    final tileMode = _parseTileMode(gradient.attributes['spreadMethod']);
    final matrix4 = _parseGradientTransformMatrix(
      gradient.attributes['gradientTransform'],
    );

    // Apply linearRGB color interpolation if specified
    final List<ui.Color> colors;
    final List<double> offsets;
    if (gradient.useLinearRGB && gradient.stops.length >= 2) {
      final linearStops = _createLinearRGBInterpolatedStops(gradient.stops);
      colors = linearStops.map((s) => s.color).toList(growable: false);
      offsets = linearStops.map((s) => s.offset).toList(growable: false);
    } else {
      colors = gradient.stops.map((s) => s.color).toList(growable: false);
      offsets = gradient.stops.map((s) => s.offset).toList(growable: false);
    }

    if (gradient.type == 'linearGradient') {
      final x1 = _resolveGradientCoordinate(
        gradient.attributes['x1'],
        defaultValue: 0.0,
        axis: _GradientAxis.x,
        bounds: bounds,
        isUserSpaceOnUse: isUserSpaceOnUse,
      );
      final y1 = _resolveGradientCoordinate(
        gradient.attributes['y1'],
        defaultValue: 0.0,
        axis: _GradientAxis.y,
        bounds: bounds,
        isUserSpaceOnUse: isUserSpaceOnUse,
      );
      final x2 = _resolveGradientCoordinate(
        gradient.attributes['x2'],
        defaultValue: 100.0,
        axis: _GradientAxis.x,
        bounds: bounds,
        isUserSpaceOnUse: isUserSpaceOnUse,
      );
      final y2 = _resolveGradientCoordinate(
        gradient.attributes['y2'],
        defaultValue: 0.0,
        axis: _GradientAxis.y,
        bounds: bounds,
        isUserSpaceOnUse: isUserSpaceOnUse,
      );

      return ui.Gradient.linear(
        ui.Offset(x1, y1),
        ui.Offset(x2, y2),
        colors,
        offsets,
        tileMode,
        matrix4,
      );
    }

    final cx = _resolveGradientCoordinate(
      gradient.attributes['cx'],
      defaultValue: 50.0,
      axis: _GradientAxis.x,
      bounds: bounds,
      isUserSpaceOnUse: isUserSpaceOnUse,
    );
    final cy = _resolveGradientCoordinate(
      gradient.attributes['cy'],
      defaultValue: 50.0,
      axis: _GradientAxis.y,
      bounds: bounds,
      isUserSpaceOnUse: isUserSpaceOnUse,
    );
    final radius = _resolveGradientCoordinate(
      gradient.attributes['r'],
      defaultValue: 50.0,
      axis: _GradientAxis.radius,
      bounds: bounds,
      isUserSpaceOnUse: isUserSpaceOnUse,
    );
    if (radius <= 0) {
      return null;
    }

    final hasFocal =
        gradient.attributes.containsKey('fx') ||
        gradient.attributes.containsKey('fy');
    final focalX = _resolveGradientCoordinate(
      gradient.attributes['fx'] ?? gradient.attributes['cx'],
      defaultValue: 50.0,
      axis: _GradientAxis.x,
      bounds: bounds,
      isUserSpaceOnUse: isUserSpaceOnUse,
    );
    final focalY = _resolveGradientCoordinate(
      gradient.attributes['fy'] ?? gradient.attributes['cy'],
      defaultValue: 50.0,
      axis: _GradientAxis.y,
      bounds: bounds,
      isUserSpaceOnUse: isUserSpaceOnUse,
    );
    final focalRadius = _resolveGradientCoordinate(
      gradient.attributes['fr'],
      defaultValue: 0.0,
      axis: _GradientAxis.radius,
      bounds: bounds,
      isUserSpaceOnUse: isUserSpaceOnUse,
    ).clamp(0.0, radius);

    return ui.Gradient.radial(
      ui.Offset(cx, cy),
      radius,
      colors,
      offsets,
      tileMode,
      matrix4,
      hasFocal ? ui.Offset(focalX, focalY) : null,
      focalRadius,
    );
  }
}
