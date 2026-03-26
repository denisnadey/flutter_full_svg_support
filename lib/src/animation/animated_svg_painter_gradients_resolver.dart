part of 'animated_svg_painter.dart';

extension AnimatedSvgPainterGradientResolverExtension on AnimatedSvgPainter {
  _ResolvedGradientDefinition? _resolveGradientDefinition(
    String gradientId, {
    Set<String>? visited,
  }) {
    if (visited == null) {
      final cached = _gradientCache[gradientId];
      if (cached != null || _gradientCache.containsKey(gradientId)) {
        return cached;
      }
    }

    final localVisited = visited ?? <String>{};
    if (!localVisited.add(gradientId)) {
      return null;
    }

    final node = document.root.findById(gradientId);
    if (node == null) {
      if (visited == null) {
        _gradientCache[gradientId] = null;
      }
      return null;
    }

    if (node.tagName != 'linearGradient' &&
        node.tagName != 'radialGradient' &&
        node.tagName != 'conicGradient') {
      if (visited == null) {
        _gradientCache[gradientId] = null;
      }
      return null;
    }

    _ResolvedGradientDefinition? inherited;
    final hrefId = _extractHrefId(node);
    if (hrefId != null) {
      inherited = _resolveGradientDefinition(hrefId, visited: localVisited);
    }

    final attributes = <String, Object?>{};
    if (inherited != null) {
      attributes.addAll(inherited.attributes);
    }
    for (final entry in node.attributes.entries) {
      attributes[entry.key] = entry.value.effectiveValue;
    }

    final ownStops = _parseGradientStops(node);
    final stops = ownStops.isNotEmpty ? ownStops : inherited?.stops;

    // Get color-interpolation mode
    final colorInterpolation =
        (attributes['color-interpolation']?.toString() ?? 'sRGB').toLowerCase();

    final resolved = _ResolvedGradientDefinition(
      type: node.tagName,
      attributes: attributes,
      stops: stops ?? const <_GradientStop>[],
      useLinearRGB: colorInterpolation == 'linearrgb',
    );

    if (visited == null) {
      _gradientCache[gradientId] = resolved;
    }
    return resolved;
  }

  List<_GradientStop> _parseGradientStops(SvgNode gradientNode) {
    final stops = <_GradientStop>[];
    for (final child in gradientNode.children) {
      if (child.tagName != 'stop') {
        continue;
      }

      final offset = _parseStopOffset(child.getAttributeValue('offset'));
      final styleStopColor = _extractStyleValue(child, 'stop-color');
      final styleStopOpacity = _extractStyleValue(child, 'stop-opacity');
      final stopColorValue =
          child.getAttributeValue('stop-color') ?? styleStopColor;
      final stopColor =
          _resolveColorValue(stopColorValue) ?? const ui.Color(0xFF000000);

      final stopOpacity =
          _parseOpacityValue(
            child.getAttributeValue('stop-opacity') ?? styleStopOpacity,
          ) ??
          1.0;
      final opacity =
          (_parseOpacityValue(child.getAttributeValue('opacity')) ?? 1.0).clamp(
            0.0,
            1.0,
          );

      stops.add(
        _GradientStop(
          offset: offset,
          color: _applyOpacity(
            stopColor,
            (stopOpacity * opacity).clamp(0.0, 1.0),
          ),
        ),
      );
    }

    if (stops.isEmpty) {
      return const <_GradientStop>[];
    }

    stops.sort((a, b) => a.offset.compareTo(b.offset));

    if (stops.length == 1) {
      final only = stops.first;
      return <_GradientStop>[
        _GradientStop(offset: 0.0, color: only.color),
        _GradientStop(offset: 1.0, color: only.color),
      ];
    }

    return stops;
  }

  String? _extractStyleValue(SvgNode node, String property) {
    final style = node.getAttributeValue('style')?.toString();
    if (style == null || style.trim().isEmpty) {
      return null;
    }

    // Parse and store custom properties from this node's style
    node.parseAndSetCustomProperties(style);

    for (final declaration in style.split(';')) {
      final parts = declaration.split(':');
      if (parts.length < 2) {
        continue;
      }
      final key = parts.first.trim().toLowerCase();
      if (key != property) {
        continue;
      }
      var value = parts.sublist(1).join(':').trim();
      value = value
          .replaceFirst(RegExp(r'\s*!important\s*$', caseSensitive: false), '')
          .trim();
      if (value.isEmpty) {
        return null;
      }
      // Resolve CSS variables if present
      if (containsVarReference(value)) {
        value = CssVariableResolver.resolveValue(value, node);
      }
      return value.isEmpty ? null : value;
    }
    return null;
  }
}
