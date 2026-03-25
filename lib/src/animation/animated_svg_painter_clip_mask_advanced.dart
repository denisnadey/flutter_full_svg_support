part of 'animated_svg_painter.dart';

/// Mask type for SVG masks.
/// - alpha: mask opacity from alpha channel (default)
/// - luminance: mask opacity from luminance (0.2126*R + 0.7152*G + 0.0722*B)
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
        maskBounds.width.abs() < 1e-6 ||
        maskBounds.height.abs() < 1e-6) {
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

  /// Computes the mask region bounds.
  ui.Rect? _computeMaskBounds({
    required SvgNode maskedNode,
    required SvgNode maskNode,
  }) {
    final units = (_getString(maskNode, 'maskUnits') ?? 'objectBoundingBox')
        .trim()
        .toLowerCase();

    if (units == 'objectboundingbox') {
      final targetBounds = _computeNodeLocalBounds(maskedNode);
      if (targetBounds == null) return null;

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

      return ui.Rect.fromLTWH(
        targetBounds.left + resolvedX * targetBounds.width,
        targetBounds.top + resolvedY * targetBounds.height,
        targetBounds.width * resolvedWidth,
        targetBounds.height * resolvedHeight,
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
  /// Luminance formula: 0.2126*R + 0.7152*G + 0.0722*B
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
    // The color matrix converts RGB to luminance in the alpha channel:
    // R' = 0, G' = 0, B' = 0, A' = 0.2126*R + 0.7152*G + 0.0722*B
    final luminanceToAlphaMatrix = Float64List.fromList(<double>[
      0, 0, 0, 0, 0, // R output
      0, 0, 0, 0, 0, // G output
      0, 0, 0, 0, 0, // B output
      0.2126, 0.7152, 0.0722, 0, 0, // A output = luminance
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
      final localBounds = _computeNodeLocalBounds(maskedNode);
      if (localBounds != null &&
          localBounds.width.abs() >= 1e-6 &&
          localBounds.height.abs() >= 1e-6) {
        contentTransform = Matrix4.identity()
          ..setEntry(0, 0, localBounds.width)
          ..setEntry(1, 1, localBounds.height)
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
}
