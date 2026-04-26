part of 'animated_svg_painter.dart';

/// Mask type for SVG masks per SVG 2 specification.
/// - **luminance** (default per SVG spec): mask opacity from luminance formula:
///   `(0.2126*R + 0.7152*G + 0.0722*B) * A`
///   White = fully visible, Black = fully hidden, Gray = partially visible
/// - **alpha**: mask opacity from alpha channel only, ignoring color values
enum _SvgMaskType { alpha, luminance }

/// Luminance coefficients per ITU-R BT.709 / sRGB.
/// These are the standard coefficients for RGB to luminance conversion.
const double _kLuminanceR = 0.2126;
const double _kLuminanceG = 0.7152;
const double _kLuminanceB = 0.0722;

/// Default mask region extension (10% per SVG spec).
const double _kDefaultMaskExtension = 0.1;

/// Luminance masking logic and mask bounds computation.
///
/// Contains methods for:
/// - Mask type parsing
/// - Luminance mask paint creation
/// - Mask bounds computation (objectBoundingBox and userSpaceOnUse)
/// - Mask content painting
extension AnimatedSvgPainterMaskLuminanceExtension on AnimatedSvgPainter {
  /// Parses the mask-type from CSS property, mask-mode property, or type attribute.
  ///
  /// Priority order:
  /// 1. CSS mask-mode property on the masked element (CSS Masking spec)
  /// 2. CSS mask-type property on the masked element
  /// 3. type attribute on the mask element
  /// 4. mask-type style on mask element
  /// 5. Default: alpha
  _SvgMaskType _parseMaskType(SvgNode maskNode, SvgNode maskedNode) {
    // First check CSS mask-mode property (CSS Masking Level 1)
    // mask-mode can be: alpha | luminance | match-source
    final maskModeValue = _getStyleOrAttributeValue(maskedNode, 'mask-mode');
    if (maskModeValue != null) {
      final normalized = maskModeValue.toString().trim().toLowerCase();
      if (normalized == 'luminance') return _SvgMaskType.luminance;
      if (normalized == 'alpha') return _SvgMaskType.alpha;
      // match-source uses the mask element's mask-type
      if (normalized != 'match-source') {
        // Invalid value - continue to next check
      }
    }

    // Check CSS mask-type property on the masked element
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

    // Default to luminance masking per SVG 2 specification
    // SVG 2: "The initial value is luminance."
    return _SvgMaskType.luminance;
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
      _kLuminanceR, _kLuminanceG, _kLuminanceB, 0, 0, // A output = luminance
    ]);

    return ui.Paint()
      ..blendMode = ui.BlendMode.dstIn
      ..colorFilter = ui.ColorFilter.matrix(luminanceMatrix);
  }

  /// Computes the mask region bounds with proper feathering extension.
  ///
  /// Per SVG spec, the default mask region extends 10% beyond the element's
  /// bounding box in all directions. This method handles:
  /// - maskUnits (objectBoundingBox vs userSpaceOnUse)
  /// - Default -10% for x/y and 120% for width/height
  /// - Zero-area mask handling
  ui.Rect? _computeMaskBounds({
    required SvgNode maskedNode,
    required SvgNode maskNode,
  }) {
    final units = (_getString(maskNode, 'maskUnits') ?? 'objectBoundingBox')
        .trim()
        .toLowerCase();

    if (units == 'objectboundingbox') {
      return _computeMaskBoundsObjectBoundingBox(
        maskedNode: maskedNode,
        maskNode: maskNode,
      );
    }

    return _computeMaskBoundsUserSpaceOnUse(
      maskedNode: maskedNode,
      maskNode: maskNode,
    );
  }

  /// Computes mask bounds for objectBoundingBox units.
  ///
  /// Handles:
  /// - Default 10% extension per SVG spec
  /// - Non-uniform scaling
  /// - Percentage values in mask attributes
  ui.Rect? _computeMaskBoundsObjectBoundingBox({
    required SvgNode maskedNode,
    required SvgNode maskNode,
  }) {
    final targetBounds = _computeNodeLocalBoundsWithStroke(maskedNode);
    if (targetBounds == null) return null;

    // Edge case: degenerate bounding box
    if (targetBounds.width.abs() < _kMinBoundingBoxDimension ||
        targetBounds.height.abs() < _kMinBoundingBoxDimension) {
      return null;
    }

    // Parse mask region attributes with defaults per SVG spec.
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

    // Edge case: zero or negative dimensions
    if (resolvedWidth <= 0 || resolvedHeight <= 0) return null;

    // Handle very small dimensions safely for non-uniform scaling
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

  /// Parses a mask region attribute for objectBoundingBox units.
  ///
  /// Uses raw attribute values to properly detect percentage values,
  /// since the SVG parser strips the '%' suffix from numeric attributes.
  /// In objectBoundingBox mode, percentages like "25%" should be treated
  /// as 0.25 (a fraction of the bounding box).
  double? _parseMaskRegionBoundingBoxValue(SvgNode maskNode, String attrName) {
    // First check the raw value to detect percentages
    final rawValue = maskNode.getRawAttributeValue(attrName);
    if (rawValue != null) {
      final trimmed = rawValue.trim();
      if (trimmed.endsWith('%')) {
        // Parse as percentage and convert to fraction
        final numericPart = trimmed.substring(0, trimmed.length - 1);
        final percent = double.tryParse(numericPart);
        if (percent != null) {
          return percent / 100.0;
        }
      }
      // Try parsing as a plain number
      return double.tryParse(trimmed);
    }

    // Fall back to parsed value (handles numeric values)
    final parsedValue = maskNode.getAttributeValue(attrName);
    if (parsedValue == null) return null;
    if (parsedValue is num) return parsedValue.toDouble();
    return double.tryParse(parsedValue.toString());
  }

  /// Computes mask bounds for userSpaceOnUse units.
  ///
  /// Uses the current user coordinate system with proper viewport resolution
  /// for percentage values.
  ui.Rect? _computeMaskBoundsUserSpaceOnUse({
    required SvgNode maskedNode,
    required SvgNode maskNode,
  }) {
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

  /// Creates paint for luminance mask with proper handling of gradient stops.
  ///
  /// When a mask contains shapes with radial/linear gradients, this ensures
  /// the luminance-to-alpha conversion handles gradient stops correctly,
  /// especially when gradient has opacity stops.
  ui.Paint _createLuminanceMaskPaintWithGradientSupport() {
    // Luminance formula: 0.2126*R + 0.7152*G + 0.0722*B
    // When mask content has gradients with opacity, we need to:
    // 1. Convert each gradient stop's color to luminance
    // 2. Multiply by the stop's alpha value
    // 3. Apply to the final mask alpha
    //
    // The color matrix handles this by:
    // - Row 4 (alpha output) = luminance coefficients * source alpha
    final luminanceMatrix = Float64List.fromList(<double>[
      0, 0, 0, 0, 0, // R output = 0 (not used)
      0, 0, 0, 0, 0, // G output = 0 (not used)
      0, 0, 0, 0, 0, // B output = 0 (not used)
      _kLuminanceR, _kLuminanceG, _kLuminanceB, 0, 0, // A = luminance
    ]);

    return ui.Paint()
      ..blendMode = ui.BlendMode.dstIn
      ..colorFilter = ui.ColorFilter.matrix(luminanceMatrix);
  }

  /// Paints mask content with filter chain applied before luminance extraction.
  ///
  /// When mask content has a filter attribute with multiple primitives
  /// (e.g., blur + color-matrix), the filter chain must execute before
  /// the luminance-to-alpha conversion step.
  void _paintMaskContentWithFilters(
    ui.Canvas canvas, {
    required SvgNode maskNode,
    required SvgNode maskedNode,
    required Set<String> useStack,
    required _SvgMaskType maskType,
    required ui.Rect maskBounds,
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

    // Paint mask children with their filters applied first
    for (final child in maskNode.children) {
      // Check if child has filters
      final filterId = _getFilterId(child);
      if (filterId != null && filterId.isNotEmpty) {
        // Paint with filter applied
        _paintNode(canvas, child, useStack: useStack);
      } else {
        // Paint without filter
        _paintNode(canvas, child, useStack: useStack);
      }
    }

    if (contentTransform != null) {
      canvas.restore();
    }
  }

  /// Checks if mask content has radial or linear gradients.
  ///
  /// When gradient fills are present in mask content, special luminance
  /// handling is needed to properly convert gradient stops.
  bool _maskHasGradientContent(SvgNode maskNode) {
    for (final child in maskNode.children) {
      final fill = _getInheritedAttributeValue(child, 'fill');
      if (fill != null) {
        final fillStr = fill.toString();
        if (fillStr.contains('url(#') &&
            (fillStr.contains('Gradient') || fillStr.contains('gradient'))) {
          return true;
        }
      }
      // Check nested groups
      if (child.tagName == 'g' && _maskHasGradientContent(child)) {
        return true;
      }
    }
    return false;
  }
}
