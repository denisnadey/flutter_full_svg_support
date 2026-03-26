part of 'animated_svg_painter.dart';

/// Mask type for SVG masks.
/// - alpha: mask opacity from alpha channel (default)
/// - luminance: mask opacity from luminance (0.2126*R + 0.7152*G + 0.0722*B) * A
enum _SvgMaskType { alpha, luminance }

extension AnimatedSvgPainterClipMaskAdvancedExtension on AnimatedSvgPainter {
  /// Parses the mask-type from CSS property or type attribute on mask element.
  _SvgMaskType _parseMaskType(SvgNode maskNode, SvgNode maskedNode) {
    // First check CSS mask-type property on the masked element
    final maskTypeValue = _getStyleOrAttributeValue(maskedNode, 'mask-type');
    if (maskTypeValue != null) {
      final normalized = maskTypeValue.toString().trim().toLowerCase();
      if (normalized == 'luminance') return _SvgMaskType.luminance;
      if (normalized == 'alpha') return _SvgMaskType.alpha;
    }

    // Then check type attribute on the mask element itself
    final typeAttr = _getString(maskNode, 'type');
    if (typeAttr != null) {
      final normalized = typeAttr.trim().toLowerCase();
      if (normalized == 'luminance') return _SvgMaskType.luminance;
      if (normalized == 'alpha') return _SvgMaskType.alpha;
    }

    // Check mask-type style on mask element
    final maskElementType = _getStyleOrAttributeValue(maskNode, 'mask-type');
    if (maskElementType != null) {
      final normalized = maskElementType.toString().trim().toLowerCase();
      if (normalized == 'luminance') return _SvgMaskType.luminance;
      if (normalized == 'alpha') return _SvgMaskType.alpha;
    }

    // Default to alpha masking
    return _SvgMaskType.alpha;
  }

  /// Applies mask with full luminosity support.
  /// For alpha masks, renders mask content and uses alpha channel.
  /// For luminance masks, converts RGB to grayscale luminance.
  void _applyAdvancedMask(
    ui.Canvas canvas,
    SvgNode node, {
    required Set<String> useStack,
    required void Function() paintContent,
  }) {
    final maskId = _extractPaintServerId(
      _getStyleOrAttributeValue(node, 'mask'),
    );
    if (maskId == null || maskId.isEmpty) {
      // No mask, just paint content directly
      paintContent();
      return;
    }

    final maskNode = document.root.findById(maskId);
    if (maskNode == null || maskNode.tagName != 'mask') {
      // Invalid mask reference, paint without masking
      paintContent();
      return;
    }

    final maskType = _parseMaskType(maskNode, node);
    final maskBounds = _computeMaskBounds(maskedNode: node, maskNode: maskNode);

    if (maskBounds == null ||
        maskBounds.width.abs() < _kMinBoundingBoxDimension ||
        maskBounds.height.abs() < _kMinBoundingBoxDimension) {
      // Empty mask bounds - nothing visible
      return;
    }

    // Render mask content to determine visibility
    _renderWithMask(
      canvas,
      node: node,
      maskNode: maskNode,
      maskType: maskType,
      maskBounds: maskBounds,
      useStack: useStack,
      paintContent: paintContent,
    );
  }

  /// Applies multiple masks to an element sequentially.
  /// Each mask's result is used as input to the next mask.
  void _applyMultipleMasks(
    ui.Canvas canvas,
    SvgNode node, {
    required Set<String> useStack,
    required void Function() paintContent,
  }) {
    // Parse multiple mask references from the mask property
    // SVG 2 allows: mask: url(#mask1), url(#mask2), url(#mask3);
    final maskValue = _getStyleOrAttributeValue(node, 'mask');
    if (maskValue == null) {
      paintContent();
      return;
    }

    final maskRefs = _parseMultipleMaskReferences(maskValue.toString());
    if (maskRefs.isEmpty) {
      paintContent();
      return;
    }

    if (maskRefs.length == 1) {
      // Single mask - use regular masking
      _applyAdvancedMask(
        canvas,
        node,
        useStack: useStack,
        paintContent: paintContent,
      );
      return;
    }

    // Multiple masks - composite sequentially
    _applySequentialMasks(
      canvas,
      node: node,
      maskIds: maskRefs,
      useStack: useStack,
      paintContent: paintContent,
    );
  }

  /// Parses multiple mask references from a mask property value.
  /// Returns a list of mask IDs in order of application.
  List<String> _parseMultipleMaskReferences(String maskValue) {
    final refs = <String>[];
    // Split by comma to handle multiple url() references
    final parts = maskValue.split(',');
    for (final part in parts) {
      final id = _extractPaintServerId(part.trim());
      if (id != null && id.isNotEmpty) {
        refs.add(id);
      }
    }
    return refs;
  }

  /// Applies masks sequentially, compositing each mask's result.
  void _applySequentialMasks(
    ui.Canvas canvas, {
    required SvgNode node,
    required List<String> maskIds,
    required Set<String> useStack,
    required void Function() paintContent,
  }) {
    // Compute overall bounds for all masks
    ui.Rect? combinedBounds;
    final validMasks = <(String, SvgNode)>[];

    for (final maskId in maskIds) {
      final maskNode = document.root.findById(maskId);
      if (maskNode != null && maskNode.tagName == 'mask') {
        validMasks.add((maskId, maskNode));
        final bounds = _computeMaskBounds(maskedNode: node, maskNode: maskNode);
        if (bounds != null) {
          if (combinedBounds == null) {
            combinedBounds = bounds;
          } else {
            combinedBounds = combinedBounds.intersect(bounds);
          }
        }
      }
    }

    if (validMasks.isEmpty || combinedBounds == null) {
      paintContent();
      return;
    }

    if (combinedBounds.width.abs() < _kMinBoundingBoxDimension ||
        combinedBounds.height.abs() < _kMinBoundingBoxDimension) {
      // Combined mask bounds are empty - nothing visible
      return;
    }

    // Apply masks sequentially using nested saveLayer calls
    // Each mask creates a layer that clips to the result of the previous
    _applyMaskChain(
      canvas,
      node: node,
      masks: validMasks,
      currentIndex: 0,
      bounds: combinedBounds,
      useStack: useStack,
      paintContent: paintContent,
    );
  }

  /// Recursively applies a chain of masks.
  void _applyMaskChain(
    ui.Canvas canvas, {
    required SvgNode node,
    required List<(String, SvgNode)> masks,
    required int currentIndex,
    required ui.Rect bounds,
    required Set<String> useStack,
    required void Function() paintContent,
  }) {
    if (currentIndex >= masks.length) {
      // All masks applied, paint the content
      paintContent();
      return;
    }

    final (_, maskNode) = masks[currentIndex];
    final maskType = _parseMaskType(maskNode, node);

    // Apply current mask
    canvas.saveLayer(bounds, ui.Paint());

    // Recursively apply remaining masks and paint content
    _applyMaskChain(
      canvas,
      node: node,
      masks: masks,
      currentIndex: currentIndex + 1,
      bounds: bounds,
      useStack: useStack,
      paintContent: paintContent,
    );

    // Apply this mask as DST_IN
    final maskPaint = maskType == _SvgMaskType.luminance
        ? _createLuminanceMaskPaint()
        : ui.Paint()
      ..blendMode = ui.BlendMode.dstIn;

    canvas.saveLayer(bounds, maskPaint);
    _paintMaskContent(
      canvas,
      maskNode: maskNode,
      maskedNode: node,
      useStack: useStack,
    );
    canvas.restore(); // mask layer
    canvas.restore(); // content layer
  }

  /// Creates paint for luminance mask with proper color matrix.
  ui.Paint _createLuminanceMaskPaint() {
    // Luminance formula per SVG spec: 0.2126*R + 0.7152*G + 0.0722*B
    // The color matrix converts RGB to luminance and multiplies by alpha:
    // Output alpha = (0.2126*R + 0.7152*G + 0.0722*B) * A
    //
    // Flutter ColorFilter.matrix uses a 5x4 matrix in row-major order:
    // [R', G', B', A'] = matrix * [R, G, B, A, 1]
    // We want: A' = 0.2126*R + 0.7152*G + 0.0722*B (scaled by original A)
    // R' = G' = B' = 0 (we only care about alpha for masking)
    final luminanceMatrix = Float64List.fromList(<double>[
      0, 0, 0, 0, 0, // R output = 0
      0, 0, 0, 0, 0, // G output = 0
      0, 0, 0, 0, 0, // B output = 0
      0.2126, 0.7152, 0.0722, 0, 0, // A output = luminance
    ]);

    return ui.Paint()
      ..blendMode = ui.BlendMode.dstIn
      ..colorFilter = ui.ColorFilter.matrix(luminanceMatrix);
  }

  /// Computes the mask region bounds.
  ui.Rect? _computeMaskBounds({
    required SvgNode maskedNode,
    required SvgNode maskNode,
  }) {
    final units = (_getString(maskNode, 'maskUnits') ?? 'objectBoundingBox')
        .trim()
        .toLowerCase();

    if (units == 'objectboundingbox') {
      final targetBounds = _computeNodeLocalBoundsWithStroke(maskedNode);
      if (targetBounds == null) return null;

      // Edge case: degenerate bounding box
      if (targetBounds.width.abs() < _kMinBoundingBoxDimension ||
          targetBounds.height.abs() < _kMinBoundingBoxDimension) {
        return null;
      }

      final x = _parseObjectBoundingBoxValue(maskNode.getAttributeValue('x'));
      final y = _parseObjectBoundingBoxValue(maskNode.getAttributeValue('y'));
      final width = _parseObjectBoundingBoxValue(
        maskNode.getAttributeValue('width'),
      );
      final height = _parseObjectBoundingBoxValue(
        maskNode.getAttributeValue('height'),
      );

      final resolvedX = x ?? -0.1;
      final resolvedY = y ?? -0.1;
      final resolvedWidth = width ?? 1.2;
      final resolvedHeight = height ?? 1.2;

      if (resolvedWidth <= 0 || resolvedHeight <= 0) return null;

      // Handle very small dimensions safely
      final safeWidth = targetBounds.width.abs() < _kMinSafeScaleDimension
          ? _kMinSafeScaleDimension
          : targetBounds.width;
      final safeHeight = targetBounds.height.abs() < _kMinSafeScaleDimension
          ? _kMinSafeScaleDimension
          : targetBounds.height;

      return ui.Rect.fromLTWH(
        targetBounds.left + resolvedX * safeWidth,
        targetBounds.top + resolvedY * safeHeight,
        safeWidth * resolvedWidth,
        safeHeight * resolvedHeight,
      );
    }

    // userSpaceOnUse
    final x = _resolveMaskUserSpaceLength(
      maskNode: maskNode,
      attributeName: 'x',
      horizontal: true,
      isSize: false,
      defaultRaw: '-10%',
    );
    final y = _resolveMaskUserSpaceLength(
      maskNode: maskNode,
      attributeName: 'y',
      horizontal: false,
      isSize: false,
      defaultRaw: '-10%',
    );
    final width = _resolveMaskUserSpaceLength(
      maskNode: maskNode,
      attributeName: 'width',
      horizontal: true,
      isSize: true,
      defaultRaw: '120%',
    );
    final height = _resolveMaskUserSpaceLength(
      maskNode: maskNode,
      attributeName: 'height',
      horizontal: false,
      isSize: true,
      defaultRaw: '120%',
    );

    if (x == null || y == null || width == null || height == null) return null;
    if (width <= 0 || height <= 0) return null;

    return ui.Rect.fromLTWH(x, y, width, height);
  }

  /// Renders content with mask applied using saveLayer for proper compositing.
  void _renderWithMask(
    ui.Canvas canvas, {
    required SvgNode node,
    required SvgNode maskNode,
    required _SvgMaskType maskType,
    required ui.Rect maskBounds,
    required Set<String> useStack,
    required void Function() paintContent,
  }) {
    // For luminance masking, we need to:
    // 1. Render the mask content to a layer
    // 2. Apply luminance-to-alpha conversion
    // 3. Use that as the mask for the content

    if (maskType == _SvgMaskType.luminance) {
      _renderWithLuminanceMask(
        canvas,
        node: node,
        maskNode: maskNode,
        maskBounds: maskBounds,
        useStack: useStack,
        paintContent: paintContent,
      );
    } else {
      _renderWithAlphaMask(
        canvas,
        node: node,
        maskNode: maskNode,
        maskBounds: maskBounds,
        useStack: useStack,
        paintContent: paintContent,
      );
    }
  }

  /// Renders content with alpha-based mask.
  void _renderWithAlphaMask(
    ui.Canvas canvas, {
    required SvgNode node,
    required SvgNode maskNode,
    required ui.Rect maskBounds,
    required Set<String> useStack,
    required void Function() paintContent,
  }) {
    // Save layer for the content
    canvas.saveLayer(maskBounds, ui.Paint());

    // Paint the content
    paintContent();

    // Apply mask as source-in blend to use mask alpha
    final maskPaint = ui.Paint()..blendMode = ui.BlendMode.dstIn;
    canvas.saveLayer(maskBounds, maskPaint);

    // Render the mask content
    _paintMaskContent(
      canvas,
      maskNode: maskNode,
      maskedNode: node,
      useStack: useStack,
    );

    canvas.restore(); // mask layer
    canvas.restore(); // content layer
  }

  /// Renders content with luminance-based mask.
  /// Luminance formula: (0.2126*R + 0.7152*G + 0.0722*B) * A
  void _renderWithLuminanceMask(
    ui.Canvas canvas, {
    required SvgNode node,
    required SvgNode maskNode,
    required ui.Rect maskBounds,
    required Set<String> useStack,
    required void Function() paintContent,
  }) {
    // Save layer for the content
    canvas.saveLayer(maskBounds, ui.Paint());

    // Paint the content
    paintContent();

    // Apply mask with luminance-to-alpha conversion
    // The color matrix converts RGB to luminance and multiplies by alpha:
    // Output alpha = (0.2126*R + 0.7152*G + 0.0722*B) * originalAlpha
    //
    // For proper luminance masking per SVG spec, we need:
    // maskAlpha = luminance(maskColor) * maskAlpha
    //
    // Flutter's ColorFilter.matrix uses 5x4 matrix in row-major order.
    // To include the original alpha, we use the matrix column for A:
    final luminanceToAlphaMatrix = Float64List.fromList(<double>[
      0, 0, 0, 0, 0, // R output = 0
      0, 0, 0, 0, 0, // G output = 0
      0, 0, 0, 0, 0, // B output = 0
      0.2126, 0.7152, 0.0722, 0, 0, // A = luminance (note: alpha multiplied implicitly)
    ]);

    final maskPaint = ui.Paint()
      ..blendMode = ui.BlendMode.dstIn
      ..colorFilter = ui.ColorFilter.matrix(luminanceToAlphaMatrix);

    canvas.saveLayer(maskBounds, maskPaint);

    // Render the mask content
    _paintMaskContent(
      canvas,
      maskNode: maskNode,
      maskedNode: node,
      useStack: useStack,
    );

    canvas.restore(); // mask layer
    canvas.restore(); // content layer
  }

  /// Paints the mask content with proper coordinate transformation.
  void _paintMaskContent(
    ui.Canvas canvas, {
    required SvgNode maskNode,
    required SvgNode maskedNode,
    required Set<String> useStack,
  }) {
    final contentUnits =
        (_getString(maskNode, 'maskContentUnits') ?? 'userSpaceOnUse')
            .trim()
            .toLowerCase();

    Matrix4? contentTransform;
    if (contentUnits == 'objectboundingbox') {
      final localBounds = _computeNodeLocalBoundsWithStroke(maskedNode);
      if (localBounds != null &&
          localBounds.width.abs() >= _kMinBoundingBoxDimension &&
          localBounds.height.abs() >= _kMinBoundingBoxDimension) {
        // Handle very small dimensions safely
        final safeWidth = localBounds.width.abs() < _kMinSafeScaleDimension
            ? _kMinSafeScaleDimension
            : localBounds.width;
        final safeHeight = localBounds.height.abs() < _kMinSafeScaleDimension
            ? _kMinSafeScaleDimension
            : localBounds.height;
        contentTransform = Matrix4.identity()
          ..setEntry(0, 0, safeWidth)
          ..setEntry(1, 1, safeHeight)
          ..setEntry(0, 3, localBounds.left)
          ..setEntry(1, 3, localBounds.top);
      }
    }

    if (contentTransform != null) {
      canvas.save();
      canvas.transform(contentTransform.storage);
    }

    // Paint mask children
    for (final child in maskNode.children) {
      _paintNode(canvas, child, useStack: useStack);
    }

    if (contentTransform != null) {
      canvas.restore();
    }
  }

  /// Checks if a mask exists for the node.
  bool _hasMask(SvgNode node) {
    final maskId = _extractPaintServerId(
      _getStyleOrAttributeValue(node, 'mask'),
    );
    if (maskId == null || maskId.isEmpty) return false;

    final maskNode = document.root.findById(maskId);
    return maskNode != null && maskNode.tagName == 'mask';
  }

  /// Checks if a clip-path exists for the node.
  bool _hasClipPath(SvgNode node) {
    final clipId = _extractPaintServerId(
      _getStyleOrAttributeValue(node, 'clip-path'),
    );
    if (clipId == null || clipId.isEmpty) return false;

    final clipNode = document.root.findById(clipId);
    return clipNode != null && clipNode.tagName == 'clipPath';
  }

  /// Checks if the node has multiple masks defined.
  bool _hasMultipleMasks(SvgNode node) {
    final maskValue = _getStyleOrAttributeValue(node, 'mask');
    if (maskValue == null) return false;
    final refs = _parseMultipleMaskReferences(maskValue.toString());
    return refs.length > 1;
  }
}
