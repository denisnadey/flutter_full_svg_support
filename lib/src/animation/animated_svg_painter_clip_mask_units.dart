part of 'animated_svg_painter.dart';

/// Extension for handling coordinate units in clip-path and mask elements.
///
/// Supports:
/// - clipPathUnits: userSpaceOnUse (default) | objectBoundingBox
/// - maskUnits: objectBoundingBox (default) | userSpaceOnUse
/// - maskContentUnits: userSpaceOnUse (default) | objectBoundingBox
/// - Coordinate system transitions between nested mask contexts
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
    // Use raw attribute values to detect percentages since the parser
    // strips the '%' suffix from numeric attributes.
    final x = _parseMaskRegionBoundingBoxValue(maskNode, 'x');
    final y = _parseMaskRegionBoundingBoxValue(maskNode, 'y');
    final width = _parseMaskRegionBoundingBoxValue(maskNode, 'width');
    final height = _parseMaskRegionBoundingBoxValue(maskNode, 'height');

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

  /// Computes the transform matrix for maskContentUnits="objectBoundingBox".
  ///
  /// Similar to clipPathUnits but specifically for mask content coordinates.
  /// Handles edge cases including:
  /// - Zero-size bounding box
  /// - Non-uniform scaling (different width/height ratios)
  /// - Percentage values in mask content
  Matrix4? _computeMaskContentObjectBoundingBoxTransform(
    SvgNode maskedNode, {
    bool clampToSafe = true,
  }) {
    final bounds = _computeNodeLocalBoundsWithStroke(maskedNode);
    if (bounds == null) {
      return null;
    }

    // Edge case: zero width or height - mask content becomes invisible
    if (bounds.width.abs() < _kMinBoundingBoxDimension ||
        bounds.height.abs() < _kMinBoundingBoxDimension) {
      return null;
    }

    double safeWidth = bounds.width;
    double safeHeight = bounds.height;

    // Optionally clamp to safe dimensions to prevent extreme scaling
    if (clampToSafe) {
      safeWidth = bounds.width.abs() < _kMinSafeScaleDimension
          ? _kMinSafeScaleDimension
          : bounds.width;
      safeHeight = bounds.height.abs() < _kMinSafeScaleDimension
          ? _kMinSafeScaleDimension
          : bounds.height;
    }

    // Transform from objectBoundingBox coordinates (0-1) to user space
    // (0,0) maps to top-left of masked element's bbox
    // (1,1) maps to bottom-right of masked element's bbox
    return Matrix4.identity()
      ..setEntry(0, 0, safeWidth) // Scale X
      ..setEntry(1, 1, safeHeight) // Scale Y
      ..setEntry(0, 3, bounds.left) // Translate X
      ..setEntry(1, 3, bounds.top); // Translate Y
  }

  /// Handles zero-area mask region edge case.
  ///
  /// Per SVG spec, a mask region with zero width or height results in
  /// nothing being rendered (completely transparent).
  // ignore: unused_element
  bool _isZeroAreaMaskRegion(ui.Rect maskRegion) {
    return maskRegion.width.abs() < _kMinBoundingBoxDimension ||
        maskRegion.height.abs() < _kMinBoundingBoxDimension;
  }

  /// Handles degenerate bounding box for mask calculations.
  ///
  /// Returns a fallback rect if the element has a degenerate bbox,
  /// or null if no fallback is possible.
  // ignore: unused_element
  ui.Rect? _handleDegenerateMaskBoundingBox(
    SvgNode maskedNode,
    SvgNode maskNode,
  ) {
    final bounds = _computeNodeLocalBoundsWithStroke(maskedNode);
    if (bounds == null) {
      return null;
    }

    // Check for zero or negative dimensions
    if (bounds.width <= 0 || bounds.height <= 0) {
      // Try to use viewport as fallback
      final viewport = _resolveMaskUnitsViewportRect();
      if (viewport != null && viewport.width > 0 && viewport.height > 0) {
        return viewport;
      }
      return null;
    }

    return bounds;
  }

  /// Computes mask content transform considering animation state.
  ///
  /// When mask content is animated, the transform may change over time.
  /// This method ensures proper recalculation during animation.
  // ignore: unused_element
  Matrix4? _computeAnimatedMaskContentTransform(
    SvgNode maskedNode,
    SvgNode maskNode,
  ) {
    final contentUnits =
        (_getString(maskNode, 'maskContentUnits') ?? 'userSpaceOnUse')
            .trim()
            .toLowerCase();

    if (contentUnits != 'objectboundingbox') {
      return null; // userSpaceOnUse uses identity transform
    }

    return _computeMaskContentObjectBoundingBoxTransform(
      maskedNode,
      clampToSafe: true,
    );
  }

  /// Resolves percentage values in mask region attributes.
  ///
  /// Handles both objectBoundingBox percentages (relative to bbox)
  /// and userSpaceOnUse percentages (relative to viewport).
  // ignore: unused_element
  double? _resolveMaskPercentageValue(
    SvgNode maskNode,
    String attributeName,
    bool isObjectBoundingBox,
    ui.Rect? targetBounds,
    bool isHorizontal,
  ) {
    final rawValue = maskNode.getAttributeValue(attributeName);
    if (rawValue == null) {
      return null;
    }

    final raw = rawValue.toString().trim();
    if (raw.isEmpty) {
      return null;
    }

    // Check for percentage
    if (raw.endsWith('%')) {
      final percent = double.tryParse(raw.substring(0, raw.length - 1));
      if (percent == null) {
        return null;
      }

      if (isObjectBoundingBox) {
        // Percentage relative to objectBoundingBox is already in 0-1 range
        return percent / 100.0;
      } else {
        // Percentage relative to viewport
        final viewport = _resolveMaskUnitsViewportRect();
        if (viewport == null) {
          return null;
        }
        final dimension = isHorizontal ? viewport.width : viewport.height;
        return dimension * percent / 100.0;
      }
    }

    // Try parsing as number
    return double.tryParse(raw);
  }

  /// Computes transform for maskContentUnits transitions between nested masks.
  ///
  /// When a mask is nested inside another mask with different maskContentUnits,
  /// this method computes the proper coordinate transition transform.
  ///
  /// Handles:
  /// - userSpaceOnUse -> objectBoundingBox: Apply OBB transform
  /// - objectBoundingBox -> userSpaceOnUse: Invert OBB transform
  /// - Non-square bounding boxes with proper aspect ratio handling
  Matrix4? _computeMaskContentUnitsTransitionTransform({
    required String fromUnits,
    required String toUnits,
    required SvgNode maskedNode,
    Matrix4? parentTransform,
  }) {
    final normalizedFrom = fromUnits.trim().toLowerCase();
    final normalizedTo = toUnits.trim().toLowerCase();

    // Same units - no transition needed
    if (normalizedFrom == normalizedTo) {
      return null;
    }

    final bounds = _computeNodeLocalBoundsWithStroke(maskedNode);
    if (bounds == null) return null;

    // Edge case: zero dimensions
    if (bounds.width.abs() < _kMinBoundingBoxDimension ||
        bounds.height.abs() < _kMinBoundingBoxDimension) {
      return null;
    }

    // Use safe dimensions for very small values
    final safeWidth = bounds.width.abs() < _kMinSafeScaleDimension
        ? _kMinSafeScaleDimension
        : bounds.width;
    final safeHeight = bounds.height.abs() < _kMinSafeScaleDimension
        ? _kMinSafeScaleDimension
        : bounds.height;

    if (normalizedFrom == 'userspaceonuse' &&
        normalizedTo == 'objectboundingbox') {
      // Transitioning to objectBoundingBox - apply OBB transform
      return Matrix4.identity()
        ..setEntry(0, 0, safeWidth)
        ..setEntry(1, 1, safeHeight)
        ..setEntry(0, 3, bounds.left)
        ..setEntry(1, 3, bounds.top);
    } else if (normalizedFrom == 'objectboundingbox' &&
        normalizedTo == 'userspaceonuse') {
      // Transitioning from objectBoundingBox - invert OBB transform
      // Need to scale from OBB (0-1) to user space
      // This is the inverse: translate then scale
      final matrix = Matrix4.identity()
        ..setEntry(0, 0, 1.0 / safeWidth)
        ..setEntry(1, 1, 1.0 / safeHeight)
        ..setEntry(0, 3, -bounds.left / safeWidth)
        ..setEntry(1, 3, -bounds.top / safeHeight);

      // If there's a parent transform, compose with its inverse
      if (parentTransform != null) {
        final det = parentTransform.determinant();
        if (det.abs() > 1e-10) {
          final invParent = Matrix4.copy(parentTransform)..invert();
          matrix.multiply(invParent);
        }
      }

      return matrix;
    }

    return null;
  }

  /// Handles non-square bounding box coordinate mapping for maskContentUnits.
  ///
  /// When maskContentUnits="objectBoundingBox" and the element's bounding box
  /// is non-square, this ensures proper aspect ratio handling.
  Matrix4? _computeNonSquareOBBTransform({
    required SvgNode maskedNode,
    bool preserveAspectRatio = false,
  }) {
    final bounds = _computeNodeLocalBoundsWithStroke(maskedNode);
    if (bounds == null) return null;

    // Edge case: zero dimensions
    if (bounds.width.abs() < _kMinBoundingBoxDimension ||
        bounds.height.abs() < _kMinBoundingBoxDimension) {
      return null;
    }

    // Use safe dimensions
    final safeWidth = bounds.width.abs() < _kMinSafeScaleDimension
        ? _kMinSafeScaleDimension
        : bounds.width;
    final safeHeight = bounds.height.abs() < _kMinSafeScaleDimension
        ? _kMinSafeScaleDimension
        : bounds.height;

    if (preserveAspectRatio) {
      // Use uniform scale (smaller of width/height)
      final scale = safeWidth < safeHeight ? safeWidth : safeHeight;
      // Center the content within the bounding box
      final offsetX = bounds.left + (safeWidth - scale) / 2;
      final offsetY = bounds.top + (safeHeight - scale) / 2;

      return Matrix4.identity()
        ..setEntry(0, 0, scale)
        ..setEntry(1, 1, scale)
        ..setEntry(0, 3, offsetX)
        ..setEntry(1, 3, offsetY);
    }

    // Non-uniform scaling (default for SVG)
    return Matrix4.identity()
      ..setEntry(0, 0, safeWidth)
      ..setEntry(1, 1, safeHeight)
      ..setEntry(0, 3, bounds.left)
      ..setEntry(1, 3, bounds.top);
  }
}
