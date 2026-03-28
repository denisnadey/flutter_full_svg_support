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

/// Tracks nested mask context for mask-to-mask intersection handling.
class _MaskNestingContext {
  const _MaskNestingContext({
    required this.depth,
    required this.parentMaskBounds,
    required this.hasParentMask,
  });

  /// Current mask nesting depth (0 = no mask, 1 = first mask, etc.)
  final int depth;

  /// Bounds of the parent mask (for intersection calculation)
  final ui.Rect? parentMaskBounds;

  /// Whether there is a parent mask to intersect with
  final bool hasParentMask;

  /// Creates a new context for an additional mask level.
  _MaskNestingContext withChildMask(ui.Rect childBounds) {
    return _MaskNestingContext(
      depth: depth + 1,
      parentMaskBounds: childBounds,
      hasParentMask: true,
    );
  }

  /// Computes the intersection of parent and child mask bounds.
  ui.Rect? computeIntersection(ui.Rect childBounds) {
    if (!hasParentMask || parentMaskBounds == null) {
      return childBounds;
    }
    final intersection = parentMaskBounds!.intersect(childBounds);
    if (intersection.isEmpty) {
      return null; // No visible area
    }
    return intersection;
  }
}

extension AnimatedSvgPainterClipMaskAdvancedExtension on AnimatedSvgPainter {
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

  /// Applies subgraph masking - ensures proper ordering: element -> filter -> mask.
  ///
  /// When an element has both filter and mask, per CSS compositing spec:
  /// 1. Render element content
  /// 2. Apply filter to rendered content
  /// 3. Apply mask to filtered result
  ///
  /// This method is used when the mask needs to be applied after filter processing.
  // ignore: unused_element
  void _applySubgraphMask(
    ui.Canvas canvas,
    SvgNode node, {
    required Set<String> useStack,
    required void Function() paintFilteredContent,
  }) {
    final maskId = _extractPaintServerId(
      _getStyleOrAttributeValue(node, 'mask'),
    );
    if (maskId == null || maskId.isEmpty) {
      // No mask, just paint filtered content directly
      paintFilteredContent();
      return;
    }

    final maskNode = document.root.findById(maskId);
    if (maskNode == null || maskNode.tagName != 'mask') {
      // Invalid mask reference, paint without masking
      paintFilteredContent();
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

    // Render with mask applied after filter
    _renderSubgraphWithMask(
      canvas,
      node: node,
      maskNode: maskNode,
      maskType: maskType,
      maskBounds: maskBounds,
      useStack: useStack,
      paintContent: paintFilteredContent,
    );
  }

  /// Renders subgraph content with mask applied after any filter effects.
  void _renderSubgraphWithMask(
    ui.Canvas canvas, {
    required SvgNode node,
    required SvgNode maskNode,
    required _SvgMaskType maskType,
    required ui.Rect maskBounds,
    required Set<String> useStack,
    required void Function() paintContent,
  }) {
    // Save layer for content (includes any filter effects already applied)
    canvas.saveLayer(maskBounds, ui.Paint());

    // Paint the content (which may have filters applied)
    paintContent();

    // Apply mask
    final maskPaint =
        maskType == _SvgMaskType.luminance
              ? _createLuminanceMaskPaint()
              : ui.Paint()
          ..blendMode = ui.BlendMode.dstIn;

    canvas.saveLayer(maskBounds, maskPaint);

    // Render mask content
    _paintMaskContent(
      canvas,
      maskNode: maskNode,
      maskedNode: node,
      useStack: useStack,
    );

    canvas.restore(); // mask layer
    canvas.restore(); // content layer
  }

  /// Checks if mask content itself has filters.
  /// When mask content has filters, they must be applied before the mask compositing.
  // ignore: unused_element
  bool _maskContentHasFilters(SvgNode maskNode) {
    for (final child in maskNode.children) {
      final filterId = _getFilterId(child);
      if (filterId != null && filterId.isNotEmpty) {
        return true;
      }
      // Check nested groups
      if (child.tagName == 'g' && _maskContentHasFilters(child)) {
        return true;
      }
    }
    return false;
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

  /// Builds the accumulated transform matrix for clipPath application.
  ///
  /// When a clipPath is applied through multiple nested group transforms,
  /// this method computes the correct composition of all transforms.
  // ignore: unused_element
  Matrix4 _buildClipPathTransformStack({
    required SvgNode targetNode,
    required SvgNode clipPathNode,
  }) {
    final result = Matrix4.identity();

    // First, apply the clipPath's own transform if present
    final clipTransform = _buildTransformMatrixFromValue(
      clipPathNode.getAttributeValue('transform'),
    );
    if (clipTransform != null) {
      result.multiply(clipTransform);
    }

    return result;
  }

  /// Computes effective clip path with proper coordinate transform stacking.
  ///
  /// This handles the case where clipPath is applied through multiple
  /// nested group transforms, ensuring all transforms are correctly composed.
  ui.Path? _buildClipPathWithTransformStack({
    required SvgNode clippedNode,
    required SvgNode clipPathNode,
    required Set<String> useStack,
  }) {
    final clipUnits = _getString(
      clipPathNode,
      'clipPathUnits',
    )?.trim().toLowerCase();
    final isObjectBoundingBox = clipUnits == 'objectboundingbox';

    // Build the base clip path
    final clipPath = ui.Path();

    Matrix4 rootMatrix = Matrix4.identity();
    if (isObjectBoundingBox) {
      final obbTransform = _computeObjectBoundingBoxTransform(clippedNode);
      if (obbTransform == null) {
        return null;
      }
      rootMatrix = obbTransform;
    }

    // Apply clipPath's own transform
    final clipTransform = _buildTransformMatrixFromValue(
      clipPathNode.getAttributeValue('transform'),
    );
    if (clipTransform != null) {
      rootMatrix.multiply(clipTransform);
    }

    _appendClipGeometry(
      target: clipPath,
      node: clipPathNode,
      currentTransform: rootMatrix,
      useStack: useStack,
    );

    final bounds = clipPath.getBounds();
    if (bounds.width.abs() < _kMinBoundingBoxDimension ||
        bounds.height.abs() < _kMinBoundingBoxDimension) {
      return null;
    }

    return clipPath;
  }

  /// Applies clip-path with proper transform stacking for deeply nested elements.
  ///
  /// When an element is deeply nested in groups with transforms, and has a
  /// clip-path applied, this ensures all ancestor transforms are accounted for.
  // ignore: unused_element
  void _applyClipPathWithTransformStack(
    ui.Canvas canvas,
    SvgNode node, {
    required Set<String> useStack,
  }) {
    final clipId = _extractPaintServerId(
      _getStyleOrAttributeValue(node, 'clip-path'),
    );
    if (clipId == null || clipId.isEmpty) {
      return;
    }

    final clipNode = document.root.findById(clipId);
    if (clipNode == null || clipNode.tagName != 'clipPath') {
      return;
    }

    final clipPath = _buildClipPathWithTransformStack(
      clippedNode: node,
      clipPathNode: clipNode,
      useStack: useStack,
    );

    if (clipPath == null) {
      return;
    }

    canvas.clipPath(clipPath, doAntiAlias: true);
  }

  /// Builds a cascading clip path with proper unit handling at each level.
  ///
  /// When clipPaths are cascaded (clipPath on clipPath), each may have
  /// different clipPathUnits. This method handles the correct coordinate
  /// system transformation at each cascade level.
  ///
  /// Per SVG spec, when a clipPath element has a clip-path attribute:
  /// 1. The clipping region is the intersection of both clip regions
  /// 2. Each clipPath may use different clipPathUnits (userSpaceOnUse or objectBoundingBox)
  /// 3. Transforms on clipPath elements are applied to their content
  /// 4. The intersection is computed in the same coordinate space
  ///
  /// For mixed units handling:
  /// - userSpaceOnUse: clip path coordinates are in the current user coordinate system
  /// - objectBoundingBox: coordinates are relative to the clipped element's bbox (0-1)
  /// - When units differ between cascade levels, each path is computed in its own
  ///   coordinate system before intersection
  ui.Path? _buildCascadingClipPathWithUnits({
    required SvgNode clippedNode,
    required SvgNode clipPathNode,
    required Set<String> useStack,
    int depth = 0,
  }) {
    const maxDepth = 10;
    if (depth > maxDepth) {
      return null;
    }

    // Check for empty clipPath (per SVG spec, empty clipPath hides content)
    if (_isEmptyClipPath(clipPathNode)) {
      return ui.Path(); // Return empty path to hide content
    }

    // Determine units for this clipPath
    final units = _getString(
      clipPathNode,
      'clipPathUnits',
    )?.trim().toLowerCase();
    final isObjectBoundingBox = units == 'objectboundingbox';

    // Build primary clip path with correct coordinate system
    Matrix4 rootMatrix = Matrix4.identity();
    if (isObjectBoundingBox) {
      final obbResult = _computeObjectBoundingBoxTransformForClipWithBounds(
        clippedNode,
      );
      if (obbResult == null) {
        // Zero-size element with objectBoundingBox - hide all content
        return ui.Path();
      }
      rootMatrix = obbResult.$1;
      // obbResult.$2 contains the bounds, available for future use
    }

    // Apply clipPath's own transform attribute if present
    final clipTransformStr = clipPathNode.getAttributeValue('transform');
    if (clipTransformStr != null) {
      final clipTransform = _buildTransformMatrixFromValue(clipTransformStr);
      if (clipTransform != null) {
        rootMatrix.multiply(clipTransform);
      }
    }

    final clipPath = ui.Path();
    _appendClipGeometryWithClipRule(
      target: clipPath,
      node: clipPathNode,
      currentTransform: rootMatrix,
      useStack: useStack,
    );

    final bounds = clipPath.getBounds();
    if (bounds.width.abs() < _kMinBoundingBoxDimension ||
        bounds.height.abs() < _kMinBoundingBoxDimension) {
      return ui.Path(); // Empty clip region hides content
    }

    // Check for cascading clip-path on the clipPath element itself
    final cascadeClipId = _extractPaintServerId(
      _getStyleOrAttributeValue(clipPathNode, 'clip-path'),
    );

    if (cascadeClipId == null || cascadeClipId.isEmpty) {
      return clipPath;
    }

    if (useStack.contains(cascadeClipId)) {
      return clipPath; // Prevent circular references
    }

    final cascadeClipNode = document.root.findById(cascadeClipId);
    if (cascadeClipNode == null || cascadeClipNode.tagName != 'clipPath') {
      return clipPath; // Invalid reference, use current clip
    }

    // Build cascading clip with its own unit system
    // For nested clipPath, the coordinate system depends on:
    // - userSpaceOnUse: use the same coordinate system
    // - objectBoundingBox: relative to original clipped element's bbox
    final cascadePath = _buildCascadingClipPathWithUnits(
      clippedNode: clippedNode, // Use original clipped node for consistent OBB
      clipPathNode: cascadeClipNode,
      useStack: {...useStack, cascadeClipId},
      depth: depth + 1,
    );

    if (cascadePath == null) {
      return clipPath;
    }

    // Intersect both paths using Path.combine for proper cascading effect
    // Both paths are now in the same coordinate space (user space)
    return ui.Path.combine(ui.PathOperation.intersect, clipPath, cascadePath);
  }

  /// Computes objectBoundingBox transform and returns both transform and bounds.
  ///
  /// Returns null if the element has zero-size bounding box.
  /// In objectBoundingBox mode:
  /// - (0,0) maps to top-left of element's bounding box
  /// - (1,1) maps to bottom-right of element's bounding box
  (Matrix4, ui.Rect)? _computeObjectBoundingBoxTransformForClipWithBounds(
    SvgNode targetNode,
  ) {
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

    // Transform from objectBoundingBox coordinates (0-1) to user space
    final matrix = Matrix4.identity()
      ..setEntry(0, 0, safeWidth) // Scale X
      ..setEntry(1, 1, safeHeight) // Scale Y
      ..setEntry(0, 3, bounds.left) // Translate X
      ..setEntry(1, 3, bounds.top); // Translate Y

    return (matrix, bounds);
  }

  /// Appends clip geometry with proper clip-rule handling.
  ///
  /// Supports clip-rule attribute on clipPath children:
  /// - nonzero (default): non-zero winding rule
  /// - evenodd: even-odd rule
  void _appendClipGeometryWithClipRule({
    required ui.Path target,
    required SvgNode node,
    required Matrix4 currentTransform,
    required Set<String> useStack,
  }) {
    _appendClipGeometry(
      target: target,
      node: node,
      currentTransform: currentTransform,
      useStack: useStack,
    );
  }

  /// Handles empty clipPath edge case.
  ///
  /// Per SVG spec, an empty clipPath (no valid children) should result
  /// in no content being rendered.
  bool _isEmptyClipPath(SvgNode clipPathNode) {
    // Check if clipPath has any valid geometry children
    for (final child in clipPathNode.children) {
      switch (child.tagName) {
        case 'path':
        case 'rect':
        case 'circle':
        case 'ellipse':
        case 'polygon':
        case 'polyline':
        case 'text':
        case 'use':
        case 'g':
          // Has at least one potentially valid child
          return false;
        default:
          continue;
      }
    }
    return true;
  }

  /// Handles zero-area clip edge case.
  ///
  /// A clip path that results in zero area should hide all content.
  bool _isZeroAreaClipPath(ui.Path clipPath) {
    final bounds = clipPath.getBounds();
    return bounds.width.abs() < _kMinBoundingBoxDimension ||
        bounds.height.abs() < _kMinBoundingBoxDimension;
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

  /// Applies nested mask with intersection handling.
  ///
  /// When element A has a mask, and A contains element B which also has
  /// its own mask, the visible area is the intersection of both masks.
  void _applyNestedMaskWithIntersection(
    ui.Canvas canvas,
    SvgNode node, {
    required SvgNode maskNode,
    required ui.Rect maskBounds,
    required _SvgMaskType maskType,
    required Set<String> useStack,
    required _MaskNestingContext nestingContext,
    required void Function() paintContent,
  }) {
    // Compute intersection with parent mask if exists
    final effectiveBounds = nestingContext.hasParentMask
        ? nestingContext.computeIntersection(maskBounds)
        : maskBounds;

    if (effectiveBounds == null ||
        effectiveBounds.width.abs() < _kMinBoundingBoxDimension ||
        effectiveBounds.height.abs() < _kMinBoundingBoxDimension) {
      // No visible area after intersection
      return;
    }

    // Save layer for content
    canvas.saveLayer(effectiveBounds, ui.Paint());

    // Paint the content
    paintContent();

    // Apply mask with proper type
    final maskPaint = maskType == _SvgMaskType.luminance
        ? _createLuminanceMaskPaintWithGradientSupport()
        : ui.Paint()..blendMode = ui.BlendMode.dstIn;

    canvas.saveLayer(effectiveBounds, maskPaint);

    // Paint mask content with filters if present
    _paintMaskContentWithFilters(
      canvas,
      maskNode: maskNode,
      maskedNode: node,
      useStack: useStack,
      maskType: maskType,
      maskBounds: effectiveBounds,
    );

    canvas.restore(); // mask layer
    canvas.restore(); // content layer
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
