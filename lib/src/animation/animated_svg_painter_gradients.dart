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
    final gradientUnits = gradient.attributes['gradientUnits']
        ?.toString()
        .trim()
        .toLowerCase();
    final isUserSpaceOnUse = gradientUnits == 'userspaceonuse';

    // Handle degenerate bounding box edge cases for objectBoundingBox
    // Per SVG spec and Blink behavior:
    // - Zero width/height: gradient cannot be rendered
    // - Very small dimensions: normalize to avoid rendering issues
    // - Lines (zero-area bbox): return null to skip gradient
    if (!isUserSpaceOnUse) {
      final isDegenerate = _isDegenerateBoundingBox(paintBounds);
      if (isDegenerate) {
        // For degenerate bounding boxes with objectBoundingBox,
        // return null per Blink behavior (gradient not rendered)
        return null;
      }
    }

    final bounds = _normalizePaintBounds(paintBounds);
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

    // Handle conic/sweep gradient
    if (gradient.type == 'conicGradient') {
      return _createConicGradientShader(
        gradient,
        bounds,
        colors,
        offsets,
        tileMode,
        matrix4,
        isUserSpaceOnUse,
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

  /// Creates a conic (sweep) gradient shader.
  /// Conic gradients distribute colors around a center point at specified angles.
  ui.Shader? _createConicGradientShader(
    _ResolvedGradientDefinition gradient,
    ui.Rect bounds,
    List<ui.Color> colors,
    List<double> offsets,
    ui.TileMode tileMode,
    Float64List? matrix4,
    bool isUserSpaceOnUse,
  ) {
    // Get center point (defaults to center of bounding box)
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

    // Get start angle offset (from attribute or default to 0)
    // The 'from' attribute specifies the starting angle in degrees
    final fromAngle = _parseConicAngle(gradient.attributes['from']);

    // Create the transformation matrix with rotation for the start angle
    final center = ui.Offset(cx, cy);
    Matrix4? transformMatrix;
    if (matrix4 != null) {
      transformMatrix = Matrix4.fromFloat64List(matrix4);
    }
    if (fromAngle != 0.0) {
      final rotationMatrix = Matrix4.identity()
        ..translateByDouble(center.dx, center.dy, 0, 1)
        ..rotateZ(fromAngle)
        ..translateByDouble(-center.dx, -center.dy, 0, 1);
      if (transformMatrix != null) {
        transformMatrix = rotationMatrix..multiply(transformMatrix);
      } else {
        transformMatrix = rotationMatrix;
      }
    }

    // Flutter's SweepGradient expects angles in radians
    // Default sweep is from 0 to 2*pi (full circle)
    const startAngle = 0.0;
    const endAngle = math.pi * 2;

    return ui.Gradient.sweep(
      center,
      colors,
      offsets,
      tileMode,
      startAngle,
      endAngle,
      transformMatrix?.storage,
    );
  }

  /// Parses the 'from' angle for conic gradients.
  /// Supports degrees (default), radians (rad), gradians (grad), and turns.
  double _parseConicAngle(Object? value) {
    if (value == null) return 0.0;

    final str = value.toString().trim().toLowerCase();
    if (str.isEmpty) return 0.0;

    // Parse angle with units
    final match = RegExp(r'^([\d.+-]+)(deg|rad|grad|turn)?$').firstMatch(str);
    if (match == null) return 0.0;

    final number = double.tryParse(match.group(1) ?? '') ?? 0.0;
    final unit = match.group(2) ?? 'deg';

    switch (unit) {
      case 'rad':
        return number;
      case 'grad':
        return number * math.pi / 200; // 400 gradians = 360 degrees
      case 'turn':
        return number * math.pi * 2;
      case 'deg':
      default:
        return number * math.pi / 180;
    }
  }
}
