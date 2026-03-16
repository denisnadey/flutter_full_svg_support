part of 'animated_svg_painter.dart';

extension AnimatedSvgPainterGradientsExtension on AnimatedSvgPainter {
  ui.Shader? _resolvePaintServerShader(
    Object? paintValue,
    ui.Rect paintBounds,
  ) {
    final gradientId = _extractPaintServerId(paintValue);
    if (gradientId == null) {
      return null;
    }

    final gradient = _resolveGradientDefinition(gradientId);
    if (gradient == null || gradient.stops.isEmpty) {
      return null;
    }

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
    final colors = gradient.stops.map((s) => s.color).toList(growable: false);
    final offsets = gradient.stops.map((s) => s.offset).toList(growable: false);

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
