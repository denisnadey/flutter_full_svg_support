part of 'animated_svg_painter.dart';

extension AnimatedSvgPainterPatternsExtension on AnimatedSvgPainter {
  /// Resolves a pattern definition by ID.
  _ResolvedPatternDefinition? _resolvePatternDefinition(
    String patternId, {
    Set<String>? visited,
  }) {
    if (visited == null) {
      final cached = _patternCache[patternId];
      if (cached != null || _patternCache.containsKey(patternId)) {
        return cached;
      }
    }

    final localVisited = visited ?? <String>{};
    if (!localVisited.add(patternId)) {
      return null; // Circular reference
    }

    final node = document.root.findById(patternId);
    if (node == null || node.tagName != 'pattern') {
      if (visited == null) {
        _patternCache[patternId] = null;
      }
      return null;
    }

    // Check for href to another pattern (inheritance)
    _ResolvedPatternDefinition? inherited;
    final hrefId = _extractHrefId(node);
    if (hrefId != null) {
      inherited = _resolvePatternDefinition(hrefId, visited: localVisited);
    }

    // Parse attributes with inheritance fallback
    final x = _getNumber(node, 'x') ?? inherited?.x ?? 0.0;
    final y = _getNumber(node, 'y') ?? inherited?.y ?? 0.0;
    final width = _getNumber(node, 'width') ?? inherited?.width ?? 0.0;
    final height = _getNumber(node, 'height') ?? inherited?.height ?? 0.0;

    // Parse patternUnits (default: objectBoundingBox)
    final patternUnitsStr = _getString(node, 'patternUnits')?.toLowerCase();
    final patternUnits = patternUnitsStr == 'userspaceonuse'
        ? _SvgPatternUnits.userSpaceOnUse
        : (inherited?.patternUnits ?? _SvgPatternUnits.objectBoundingBox);

    // Parse patternContentUnits (default: userSpaceOnUse)
    final contentUnitsStr = _getString(
      node,
      'patternContentUnits',
    )?.toLowerCase();
    final patternContentUnits = contentUnitsStr == 'objectboundingbox'
        ? _SvgPatternUnits.objectBoundingBox
        : (inherited?.patternContentUnits ?? _SvgPatternUnits.userSpaceOnUse);

    // Parse viewBox if present
    final viewBoxStr = _getString(node, 'viewBox');
    ui.Rect? viewBox = inherited?.viewBox;
    if (viewBoxStr != null && viewBoxStr.isNotEmpty) {
      final parts = viewBoxStr.trim().split(RegExp(r'[\s,]+'));
      if (parts.length == 4) {
        final minX = double.tryParse(parts[0]) ?? 0.0;
        final minY = double.tryParse(parts[1]) ?? 0.0;
        final vbWidth = double.tryParse(parts[2]) ?? width;
        final vbHeight = double.tryParse(parts[3]) ?? height;
        viewBox = ui.Rect.fromLTWH(minX, minY, vbWidth, vbHeight);
      }
    }

    // Parse patternTransform if present
    final transformStr = _getString(node, 'patternTransform');
    Matrix4? patternTransform = inherited?.patternTransform;
    if (transformStr != null && transformStr.isNotEmpty) {
      patternTransform = _buildTransformMatrixFromValue(transformStr);
    }

    // Determine which node has the actual content
    final contentNode = node.children.isNotEmpty ? node : inherited?.node;
    if (contentNode == null) {
      if (visited == null) {
        _patternCache[patternId] = null;
      }
      return null;
    }

    final resolved = _ResolvedPatternDefinition(
      node: contentNode,
      x: x,
      y: y,
      width: width,
      height: height,
      patternUnits: patternUnits,
      patternContentUnits: patternContentUnits,
      viewBox: viewBox,
      patternTransform: patternTransform,
    );

    if (visited == null) {
      _patternCache[patternId] = resolved;
    }
    return resolved;
  }

  /// Creates an ImageShader from a pattern for use in fill/stroke.
  ui.Shader? _createPatternShader(
    String patternId, {
    required ui.Rect targetBounds,
  }) {
    final pattern = _resolvePatternDefinition(patternId);
    if (pattern == null || pattern.width <= 0 || pattern.height <= 0) {
      return null;
    }

    // Calculate tile dimensions based on patternUnits
    double tileX, tileY, tileWidth, tileHeight;
    if (pattern.patternUnits == _SvgPatternUnits.objectBoundingBox) {
      // Percentages of target bounding box
      tileX = targetBounds.left + pattern.x * targetBounds.width;
      tileY = targetBounds.top + pattern.y * targetBounds.height;
      tileWidth = pattern.width * targetBounds.width;
      tileHeight = pattern.height * targetBounds.height;
    } else {
      // Absolute coordinates
      tileX = pattern.x;
      tileY = pattern.y;
      tileWidth = pattern.width;
      tileHeight = pattern.height;
    }

    if (tileWidth <= 0 || tileHeight <= 0) {
      return null;
    }

    final tileWidthInt = tileWidth.ceil().clamp(1, 2048);
    final tileHeightInt = tileHeight.ceil().clamp(1, 2048);

    // Generate cache key for pattern image
    final cacheKey = _RenderCache.patternKey(
      patternId,
      targetBounds,
      tileWidthInt,
      tileHeightInt,
    );

    // Try to get cached image
    ui.Image? image = _renderCache.patternImages[cacheKey];

    if (image == null) {
      // Render pattern content to a Picture
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);

      // Apply content units transformation
      if (pattern.patternContentUnits == _SvgPatternUnits.objectBoundingBox) {
        canvas.scale(targetBounds.width, targetBounds.height);
      }

      // Apply viewBox transformation if present
      if (pattern.viewBox != null) {
        final vb = pattern.viewBox!;
        if (vb.width > 0 && vb.height > 0) {
          final scaleX = tileWidth / vb.width;
          final scaleY = tileHeight / vb.height;
          canvas.translate(-vb.left * scaleX, -vb.top * scaleY);
          canvas.scale(scaleX, scaleY);
        }
      }

      // Paint pattern children
      for (final child in pattern.node.children) {
        _paintNode(canvas, child);
      }

      final picture = recorder.endRecording();

      // Convert Picture to Image for shader
      image = picture.toImageSync(tileWidthInt, tileHeightInt);

      // Cache the generated image
      _renderCache.patternImages[cacheKey] = image;
    }

    // Create transform matrix for the shader
    final matrix = Matrix4.identity();
    matrix.translateByDouble(tileX, tileY, 0, 1);
    if (pattern.patternTransform != null) {
      matrix.multiply(pattern.patternTransform!);
    }

    return ui.ImageShader(
      image,
      ui.TileMode.repeated,
      ui.TileMode.repeated,
      matrix.storage,
    );
  }
}
