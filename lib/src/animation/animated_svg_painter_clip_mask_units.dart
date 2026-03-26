part of 'animated_svg_painter.dart';

/// Extension for handling coordinate units in clip-path and mask elements.
///
/// Supports:
/// - clipPathUnits: userSpaceOnUse (default) | objectBoundingBox
/// - maskUnits: objectBoundingBox (default) | userSpaceOnUse
/// - maskContentUnits: userSpaceOnUse (default) | objectBoundingBox
extension AnimatedSvgPainterClipMaskUnitsExtension on AnimatedSvgPainter {
  /// Builds the mask region path based on maskUnits attribute.
  ///
  /// When maskUnits="objectBoundingBox", the mask region is defined relative
  /// to the masked element's bounding box. The default mask region extends
  /// 10% beyond the bbox in all directions (x=-10%, y=-10%, width=120%, height=120%).
  ///
  /// When maskUnits="userSpaceOnUse", the mask region is in user coordinates.
  ui.Path? _buildMaskUnitsRegionPath({
    required SvgNode maskedNode,
    required SvgNode maskNode,
  }) {
    final units = (_getString(maskNode, 'maskUnits') ?? 'objectBoundingBox')
        .trim()
        .toLowerCase();
    if (units == 'objectboundingbox') {
      return _buildMaskRegionPathObjectBoundingBox(
        maskedNode: maskedNode,
        maskNode: maskNode,
      );
    }

    return _buildMaskRegionPathUserSpaceOnUse(maskNode: maskNode);
  }

  /// Builds mask region path for objectBoundingBox units.
  ///
  /// Handles edge cases:
  /// - Zero-area bounding box
  /// - Non-uniform scaling (different width/height ratios)
  /// - Percentage values in mask attributes
  ui.Path? _buildMaskRegionPathObjectBoundingBox({
    required SvgNode maskedNode,
    required SvgNode maskNode,
  }) {
    final targetBounds = _computeNodeLocalBoundsWithStroke(maskedNode);
    if (targetBounds == null) {
      return null;
    }
    // Edge case: zero width or height - nothing to mask
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

    // Default: -10% for x/y, 120% for width/height (10% extension per side)
    final resolvedX = x ?? -_kDefaultMaskExtension;
    final resolvedY = y ?? -_kDefaultMaskExtension;
    final resolvedWidth = width ?? (1.0 + 2 * _kDefaultMaskExtension);
    final resolvedHeight = height ?? (1.0 + 2 * _kDefaultMaskExtension);

    if (resolvedWidth <= 0 || resolvedHeight <= 0) {
      return null;
    }
    // Handle very small target bounds by using safe dimensions
    // This prevents division by zero and extreme scaling artifacts
    final safeWidth = targetBounds.width.abs() < _kMinSafeScaleDimension
        ? _kMinSafeScaleDimension
        : targetBounds.width;
    final safeHeight = targetBounds.height.abs() < _kMinSafeScaleDimension
        ? _kMinSafeScaleDimension
        : targetBounds.height;
    final rect = ui.Rect.fromLTWH(
      targetBounds.left + resolvedX * safeWidth,
      targetBounds.top + resolvedY * safeHeight,
      safeWidth * resolvedWidth,
      safeHeight * resolvedHeight,
    );
    return ui.Path()..addRect(rect);
  }

  /// Builds mask region path for userSpaceOnUse units.
  ///
  /// Uses the current user coordinate system, resolving percentage values
  /// against the viewport.
  ui.Path? _buildMaskRegionPathUserSpaceOnUse({required SvgNode maskNode}) {
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
    if (x == null || y == null || width == null || height == null) {
      return null;
    }
    if (width <= 0 || height <= 0) {
      return null;
    }
    return ui.Path()..addRect(ui.Rect.fromLTWH(x, y, width, height));
  }

  double? _resolveMaskUserSpaceLength({
    required SvgNode maskNode,
    required String attributeName,
    required bool horizontal,
    required bool isSize,
    required String defaultRaw,
  }) {
    final rawValue = maskNode.getAttributeValue(attributeName) ?? defaultRaw;
    if (rawValue is num) {
      return rawValue.toDouble();
    }
    final raw = rawValue.toString().trim();
    if (raw.isEmpty) {
      return null;
    }
    if (raw.endsWith('%')) {
      final percent = double.tryParse(raw.substring(0, raw.length - 1));
      final viewport = _resolveMaskUnitsViewportRect();
      if (percent == null || viewport == null) {
        return null;
      }
      final dimension = horizontal ? viewport.width : viewport.height;
      final value = dimension * percent / 100.0;
      if (isSize) {
        return value;
      }
      final origin = horizontal ? viewport.left : viewport.top;
      return origin + value;
    }
    final cleaned = raw.replaceAll(RegExp(r'[a-zA-Z]+$'), '');
    return double.tryParse(cleaned);
  }

  ui.Rect? _resolveMaskUnitsViewportRect() {
    final viewBox = document.viewBox;
    if (viewBox != null && viewBox.width > 0 && viewBox.height > 0) {
      return viewBox;
    }
    final root = document.root;
    final width = _getNumber(root, 'width');
    final height = _getNumber(root, 'height');
    if (width == null || height == null || width <= 0 || height <= 0) {
      return null;
    }
    return ui.Rect.fromLTWH(0, 0, width, height);
  }

  double? _parseObjectBoundingBoxValue(Object? rawValue) {
    if (rawValue == null) {
      return null;
    }
    if (rawValue is num) {
      return rawValue.toDouble();
    }
    final raw = rawValue.toString().trim();
    if (raw.isEmpty) {
      return null;
    }
    if (raw.endsWith('%')) {
      final percent = double.tryParse(raw.substring(0, raw.length - 1));
      if (percent == null) {
        return null;
      }
      return percent / 100.0;
    }
    return double.tryParse(raw);
  }

  /// Computes the transform matrix for clipPathUnits="objectBoundingBox".
  ///
  /// This handles non-uniform scaling when the element's bounding box
  /// has different width and height values.
  Matrix4? _computeObjectBoundingBoxTransform(
    SvgNode targetNode, {
    bool preserveAspectRatio = false,
  }) {
    final bounds = _computeNodeLocalBoundsWithStroke(targetNode);
    if (bounds == null) {
      return null;
    }

    // Edge case: zero width or height
    if (bounds.width.abs() < _kMinBoundingBoxDimension ||
        bounds.height.abs() < _kMinBoundingBoxDimension) {
      return null;
    }

    // Use safe dimensions to prevent extreme scaling
    final safeWidth = bounds.width.abs() < _kMinSafeScaleDimension
        ? _kMinSafeScaleDimension
        : bounds.width;
    final safeHeight = bounds.height.abs() < _kMinSafeScaleDimension
        ? _kMinSafeScaleDimension
        : bounds.height;

    if (preserveAspectRatio) {
      // Use uniform scale (smaller of the two)
      final scale = safeWidth < safeHeight ? safeWidth : safeHeight;
      return Matrix4.identity()
        ..setEntry(0, 0, scale)
        ..setEntry(1, 1, scale)
        ..setEntry(0, 3, bounds.left)
        ..setEntry(1, 3, bounds.top);
    }

    // Non-uniform scaling
    return Matrix4.identity()
      ..setEntry(0, 0, safeWidth)
      ..setEntry(1, 1, safeHeight)
      ..setEntry(0, 3, bounds.left)
      ..setEntry(1, 3, bounds.top);
  }

  /// Computes the accumulated transform for userSpaceOnUse with nested transforms.
  ///
  /// When clipPathUnits="userSpaceOnUse", the clip path coordinates are in the
  /// current user coordinate system. This method accumulates all ancestor
  /// transforms to properly position the clip.
  Matrix4 _computeUserSpaceTransformStack(SvgNode node) {
    final transforms = <Matrix4>[];

    // Collect transforms from ancestors (excluding the node itself)
    var current = node.parent;
    while (current != null) {
      final transform = _buildTransformMatrixFromValue(
        current.getAttributeValue('transform'),
      );
      if (transform != null) {
        transforms.add(transform);
      }
      current = current.parent;
    }

    if (transforms.isEmpty) {
      return Matrix4.identity();
    }

    // Compose transforms in reverse order (from root to parent)
    final result = Matrix4.identity();
    for (int i = transforms.length - 1; i >= 0; i--) {
      result.multiply(transforms[i]);
    }

    return result;
  }

  /// Resolves clipPathUnits for cascaded clipPaths.
  ///
  /// When clipPaths are cascaded, each may have different units.
  /// This determines the correct coordinate system for each level.
  String _resolveClipPathUnits(SvgNode clipPathNode) {
    final units = _getString(
      clipPathNode,
      'clipPathUnits',
    )?.trim().toLowerCase();
    return units ?? 'userspaceonuse';
  }

  /// Transforms a clip path based on clipPathUnits setting and nested transforms.
  ///
  /// For objectBoundingBox: scales clip coordinates to target element bounds
  /// For userSpaceOnUse: uses current user coordinate system with nested transforms
  ui.Path? _transformClipPathForUnits({
    required ui.Path clipPath,
    required SvgNode targetNode,
    required SvgNode clipPathNode,
    Matrix4? additionalTransform,
  }) {
    final units = _resolveClipPathUnits(clipPathNode);

    Matrix4 transform = Matrix4.identity();

    if (units == 'objectboundingbox') {
      final obbTransform = _computeObjectBoundingBoxTransform(targetNode);
      if (obbTransform == null) {
        return null;
      }
      transform = obbTransform;
    } else {
      // userSpaceOnUse - accumulate nested transforms if needed
      transform = _computeUserSpaceTransformStack(targetNode);
    }

    // Apply any additional transform (e.g., from cascading clipPaths)
    if (additionalTransform != null) {
      transform.multiply(additionalTransform);
    }

    // Transform the clip path
    return clipPath.transform(transform.storage);
  }

  /// Computes the transform matrix for maskContentUnits="objectBoundingBox".
  ///
  /// When maskContentUnits="objectBoundingBox", the mask content is in a
  /// coordinate space where (0,0) is the top-left of the masked element's
  /// bounding box and (1,1) is the bottom-right.
  ///
  /// Handles non-uniform scaling when width != height.
  Matrix4? _computeMaskContentTransform(
    SvgNode maskedNode, {
    bool preserveAspectRatio = false,
  }) {
    final bounds = _computeNodeLocalBoundsWithStroke(maskedNode);
    if (bounds == null) {
      return null;
    }

    // Edge case: zero width or height
    if (bounds.width.abs() < _kMinBoundingBoxDimension ||
        bounds.height.abs() < _kMinBoundingBoxDimension) {
      return null;
    }

    // Use safe dimensions to prevent extreme scaling
    final safeWidth = bounds.width.abs() < _kMinSafeScaleDimension
        ? _kMinSafeScaleDimension
        : bounds.width;
    final safeHeight = bounds.height.abs() < _kMinSafeScaleDimension
        ? _kMinSafeScaleDimension
        : bounds.height;

    if (preserveAspectRatio) {
      // Use uniform scale (smaller of the two)
      final scale = safeWidth < safeHeight ? safeWidth : safeHeight;
      return Matrix4.identity()
        ..setEntry(0, 0, scale)
        ..setEntry(1, 1, scale)
        ..setEntry(0, 3, bounds.left)
        ..setEntry(1, 3, bounds.top);
    }

    // Non-uniform scaling (allows stretching)
    return Matrix4.identity()
      ..setEntry(0, 0, safeWidth)
      ..setEntry(1, 1, safeHeight)
      ..setEntry(0, 3, bounds.left)
      ..setEntry(1, 3, bounds.top);
  }

  /// Gets animated mask attribute value with SMIL animation support.
  ///
  /// Supports animation of mask region attributes (x, y, width, height)
  /// via SMIL <animate> elements. The SMIL system updates attribute values
  /// automatically, so we just need to read the current value.
  double? _getAnimatedMaskAttribute(
    SvgNode maskNode,
    String attributeName, {
    double? defaultValue,
  }) {
    // Read the attribute value (SMIL system updates these during animation)
    final staticValue = maskNode.getAttributeValue(attributeName);
    if (staticValue != null) {
      final parsed = _parseObjectBoundingBoxValue(staticValue);
      if (parsed != null) {
        return parsed;
      }
    }

    return defaultValue;
  }

  /// Computes animated mask bounds for mask attribute animation.
  ///
  /// When mask attributes (x, y, width, height) are animated via SMIL,
  /// this method returns the current animated bounds.
  ui.Rect? _computeAnimatedMaskBounds({
    required SvgNode maskedNode,
    required SvgNode maskNode,
  }) {
    final units = (_getString(maskNode, 'maskUnits') ?? 'objectBoundingBox')
        .trim()
        .toLowerCase();

    if (units == 'objectboundingbox') {
      final targetBounds = _computeNodeLocalBoundsWithStroke(maskedNode);
      if (targetBounds == null) return null;

      if (targetBounds.width.abs() < _kMinBoundingBoxDimension ||
          targetBounds.height.abs() < _kMinBoundingBoxDimension) {
        return null;
      }

      // Get animated attribute values
      final x = _getAnimatedMaskAttribute(
        maskNode,
        'x',
        defaultValue: -_kDefaultMaskExtension,
      );
      final y = _getAnimatedMaskAttribute(
        maskNode,
        'y',
        defaultValue: -_kDefaultMaskExtension,
      );
      final width = _getAnimatedMaskAttribute(
        maskNode,
        'width',
        defaultValue: 1.0 + 2 * _kDefaultMaskExtension,
      );
      final height = _getAnimatedMaskAttribute(
        maskNode,
        'height',
        defaultValue: 1.0 + 2 * _kDefaultMaskExtension,
      );

      if (x == null || y == null || width == null || height == null) {
        return null;
      }
      if (width <= 0 || height <= 0) return null;

      final safeWidth = targetBounds.width.abs() < _kMinSafeScaleDimension
          ? _kMinSafeScaleDimension
          : targetBounds.width;
      final safeHeight = targetBounds.height.abs() < _kMinSafeScaleDimension
          ? _kMinSafeScaleDimension
          : targetBounds.height;

      return ui.Rect.fromLTWH(
        targetBounds.left + x * safeWidth,
        targetBounds.top + y * safeHeight,
        safeWidth * width,
        safeHeight * height,
      );
    }

    // userSpaceOnUse - animation with viewport-relative values
    return _computeMaskBoundsUserSpaceOnUse(
      maskedNode: maskedNode,
      maskNode: maskNode,
    );
  }

  /// Checks if mask attributes are being animated.
  bool _hasMaskAttributeAnimation(SvgNode maskNode) {
    for (final child in maskNode.children) {
      if (child.tagName == 'animate' || child.tagName == 'set') {
        final attributeName = _getString(child, 'attributeName');
        if (attributeName == 'x' ||
            attributeName == 'y' ||
            attributeName == 'width' ||
            attributeName == 'height' ||
            attributeName == 'maskUnits' ||
            attributeName == 'maskContentUnits') {
          return true;
        }
      }
    }
    return false;
  }

  /// Checks if mask content elements are being animated.
  bool _hasMaskContentAnimation(SvgNode maskNode) {
    for (final child in maskNode.children) {
      if (_hasAnyAnimation(child)) {
        return true;
      }
    }
    return false;
  }

  /// Checks if a node or its descendants have any SMIL animation.
  bool _hasAnyAnimation(SvgNode node) {
    // Check direct animation children
    for (final child in node.children) {
      if (child.tagName == 'animate' ||
          child.tagName == 'animateTransform' ||
          child.tagName == 'animateColor' ||
          child.tagName == 'animateMotion' ||
          child.tagName == 'set') {
        return true;
      }
      // Recursively check descendants
      if (_hasAnyAnimation(child)) {
        return true;
      }
    }
    return false;
  }
}
