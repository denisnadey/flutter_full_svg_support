part of 'animated_svg_painter.dart';

extension AnimatedSvgPainterPaintsExtension on AnimatedSvgPainter {
  ui.Paint? _createFillPaint(
    SvgNode node, {
    required ui.Rect paintBounds,
    ui.ImageFilter? imageFilter,
    ui.ColorFilter? colorFilter,
    ui.BlendMode? blendMode,
  }) {
    if (!_currentPassPaintFill) {
      return null;
    }
    final fillValue = _getInheritedAttributeValue(node, 'fill');
    if (_isPaintNone(fillValue)) {
      return null;
    }

    final opacity = _getInheritedNumber(node, 'opacity') ?? 1.0;
    final fillOpacity = _getInheritedNumber(node, 'fill-opacity') ?? 1.0;
    final finalOpacity = (opacity * fillOpacity).clamp(0.0, 1.0);

    final paint = ui.Paint()..style = ui.PaintingStyle.fill;
    final shader = _resolvePaintServerShader(fillValue, paintBounds);
    if (shader != null) {
      paint
        ..shader = shader
        ..color = const ui.Color(0xFFFFFFFF).withValues(alpha: finalOpacity);
    } else {
      final color = _resolveColorValue(fillValue) ?? const ui.Color(0xFF000000);
      paint.color = _applyOpacity(color, finalOpacity);
    }

    if (imageFilter != null) {
      paint.imageFilter = imageFilter;
    }
    if (colorFilter != null) {
      paint.colorFilter = colorFilter;
    }
    if (blendMode != null) {
      paint.blendMode = blendMode;
    }
    return paint;
  }

  /// Получить ID фильтра из атрибута filter
  /// Поддерживает формат url(#filterId) или просто filterId
  String? _getFilterId(SvgNode node) {
    final filterAttr = _getStyleOrAttributeValue(node, 'filter')?.toString();
    if (filterAttr == null || filterAttr.trim().isEmpty) {
      return null;
    }

    final paintServerId = _extractPaintServerId(filterAttr);
    if (paintServerId != null && paintServerId.isNotEmpty) {
      return paintServerId;
    }

    final normalized = filterAttr.trim();
    if (normalized.toLowerCase() == 'none') {
      return null;
    }

    // Или просто ID если нет url()
    return normalized;
  }

  Object? _getStyleOrAttributeValue(SvgNode node, String attributeName) {
    final styleValue = _extractStyleValue(node, attributeName.toLowerCase());
    if (styleValue != null) {
      return styleValue;
    }
    return node.getAttributeValue(attributeName);
  }

  /// Создаёт Paint для stroke (или null если нет stroke).
  ui.Paint? _createStrokePaint(
    SvgNode node, {
    required ui.Rect paintBounds,
    ui.ImageFilter? imageFilter,
    ui.ColorFilter? colorFilter,
    ui.BlendMode? blendMode,
  }) {
    if (!_currentPassPaintStroke) {
      return null;
    }
    final strokeValue = _getInheritedAttributeValue(node, 'stroke');
    if (strokeValue == null || _isPaintNone(strokeValue)) {
      return null;
    }

    final strokeWidth = _getInheritedNumber(node, 'stroke-width') ?? 1.0;
    final opacity = _getInheritedNumber(node, 'opacity') ?? 1.0;
    final strokeOpacity = _getInheritedNumber(node, 'stroke-opacity') ?? 1.0;
    final finalOpacity = (opacity * strokeOpacity).clamp(0.0, 1.0);

    final paint = ui.Paint()
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final shader = _resolvePaintServerShader(strokeValue, paintBounds);
    if (shader != null) {
      paint
        ..shader = shader
        ..color = const ui.Color(0xFFFFFFFF).withValues(alpha: finalOpacity);
    } else {
      final strokeColor = _resolveColorValue(strokeValue);
      if (strokeColor == null) {
        return null;
      }
      paint.color = _applyOpacity(strokeColor, finalOpacity);
    }

    if (imageFilter != null) {
      paint.imageFilter = imageFilter;
    }
    if (colorFilter != null) {
      paint.colorFilter = colorFilter;
    }
    if (blendMode != null) {
      paint.blendMode = blendMode;
    }
    return paint;
  }

  /// Applies stroke-dasharray / stroke-dashoffset to a path.
  ///
  /// If stroke-dasharray is not set or is 'none', returns [path] unchanged.
  /// Otherwise walks the path's PathMetrics and builds a new dashed path.
  ui.Path _buildDashedPath(ui.Path path, SvgNode node) {
    final dashArrayRaw = _getInheritedString(node, 'stroke-dasharray')?.trim();
    if (dashArrayRaw == null ||
        dashArrayRaw.isEmpty ||
        dashArrayRaw.toLowerCase() == 'none') {
      return path;
    }

    final dashes = _parseDashArray(dashArrayRaw);
    if (dashes.isEmpty || dashes.every((d) => d == 0)) {
      return path;
    }

    // SVG spec: odd-length dasharray is doubled.
    final pattern = dashes.length.isOdd ? [...dashes, ...dashes] : dashes;

    final totalDash = pattern.fold<double>(0.0, (s, d) => s + d);
    if (totalDash <= 0) return path;

    final rawOffset = _getInheritedNumber(node, 'stroke-dashoffset') ?? 0.0;
    // Normalise offset into [0, totalDash). SVG offset shifts the pattern start.
    var phase = rawOffset % totalDash;
    if (phase < 0) phase += totalDash;

    // Find which pattern index corresponds to [phase].
    var patternIndex = 0;
    var phaseAccum = 0.0;
    for (int i = 0; i < pattern.length; i++) {
      if (phaseAccum + pattern[i] > phase) {
        patternIndex = i;
        phaseAccum = phase - phaseAccum; // consumed from current segment
        break;
      }
      phaseAccum += pattern[i];
      patternIndex = i + 1;
      if (patternIndex >= pattern.length) {
        patternIndex = 0;
        phaseAccum = 0;
      }
    }

    // remaining = how much is left in the current pattern segment.
    var remaining = pattern[patternIndex] - phaseAccum;
    var drawing = patternIndex.isEven; // even indices are dash, odd are gap

    final dashedPath = ui.Path();
    for (final metric in path.computeMetrics()) {
      final pathLength = metric.length;
      if (pathLength <= 0) continue;

      var pathPos = 0.0;
      var segRemaining = remaining;
      var segDrawing = drawing;
      var segPatternIndex = patternIndex;

      while (pathPos < pathLength) {
        final segEnd = math.min(pathPos + segRemaining, pathLength);
        if (segDrawing) {
          dashedPath.addPath(
            metric.extractPath(pathPos, segEnd),
            ui.Offset.zero,
          );
        }
        final consumed = segEnd - pathPos;
        pathPos = segEnd;
        segRemaining -= consumed;

        if (segRemaining <= 1e-6) {
          // Advance to next pattern segment.
          segPatternIndex = (segPatternIndex + 1) % pattern.length;
          segDrawing = !segDrawing;
          segRemaining = pattern[segPatternIndex];
        }
      }
    }

    return dashedPath;
  }

  /// Parses stroke-dasharray value into a list of doubles.
  List<double> _parseDashArray(String value) {
    return value
        .split(RegExp(r'[\s,]+'))
        .map((s) {
          final cleaned = s.trim().replaceAll(RegExp(r'[a-zA-Z%]+$'), '');
          return double.tryParse(cleaned) ?? 0.0;
        })
        .where((d) => d >= 0)
        .toList();
  }
}
