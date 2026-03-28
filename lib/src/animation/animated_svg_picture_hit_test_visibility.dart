part of 'animated_svg_picture.dart';

/// Maximum recursion depth for nested clipPath/mask references.
const int _kMaxClipMaskRecursionDepth = 10;

/// Luminance coefficients per ITU-R BT.709 / sRGB for hit-testing.
const double _kHitTestLuminanceR = 0.2126;
const double _kHitTestLuminanceG = 0.7152;
const double _kHitTestLuminanceB = 0.0722;

/// Minimum luminance threshold for hit detection in luminance masks.
/// Points under mask content with luminance below this are not hittable.
const double _kMinLuminanceForHit = 0.05;

extension _AnimatedSvgPictureStateHitTestVisibilityExtension
    on _AnimatedSvgPictureState {
  bool _isPointVisibleForNode(
    SvgNode node,
    Offset documentPoint,
    Matrix4 transform,
  ) {
    final inverse = Matrix4.tryInvert(transform);
    if (inverse == null) {
      return false;
    }
    final localPoint = MatrixUtils.transformPoint(inverse, documentPoint);
    return _isPointVisibleInNodeSpace(node, localPoint);
  }

  bool _isPointVisibleInNodeSpace(SvgNode node, Offset localPoint) {
    if (!_isPointInsideClipPath(
      node,
      localPoint,
      visitedClipPaths: <String>{},
    )) {
      return false;
    }
    if (!_isPointInsideMask(node, localPoint, visitedMasks: <String>{})) {
      return false;
    }
    if (!_isPointInsideForeignObjectViewport(node, localPoint)) {
      return false;
    }
    return true;
  }

  /// Checks if a point is inside the clipPath region.
  /// Handles nested clipPaths (clipPath referencing another clipPath),
  /// clipPathUnits transformations, and clipPath-on-clipPath transforms.
  bool _isPointInsideClipPath(
    SvgNode node,
    Offset localPoint, {
    required Set<String> visitedClipPaths,
  }) {
    final clipValue = _extractStyleValue(node, 'clip-path');
    final clipId = _extractUrlId(
      clipValue ?? node.getAttributeValue('clip-path'),
    );
    if (clipId == null || clipId.isEmpty) {
      return true;
    }
    // Prevent infinite recursion from circular clipPath references
    if (visitedClipPaths.contains(clipId) ||
        visitedClipPaths.length >= _kMaxClipMaskRecursionDepth) {
      return true;
    }
    final clipNode = _document.root.findById(clipId);
    if (clipNode == null || clipNode.tagName != 'clipPath') {
      return true;
    }

    // Check if clipPath itself has a clip-path (nested clipPath)
    final nestedVisited = <String>{...visitedClipPaths, clipId};
    if (!_isPointInsideClipPath(
      clipNode,
      localPoint,
      visitedClipPaths: nestedVisited,
    )) {
      return false;
    }

    final rootTransform = _resolveContainerRootTransformForUnits(
      targetNode: node,
      unitsValue: clipNode.getAttributeValue('clipPathUnits')?.toString(),
      defaultValue: 'userspaceonuse',
    );
    if (rootTransform == null) {
      return true;
    }

    final clipPath = _buildClipPathGeometryWithTransforms(
      clipNode,
      rootTransform: rootTransform,
      visitedClipPaths: nestedVisited,
    );
    if (clipPath == null) {
      return true;
    }
    return clipPath.contains(localPoint);
  }

  /// Builds clipPath geometry handling child transforms.
  /// Each child shape can have its own transform which must be applied.
  Path? _buildClipPathGeometryWithTransforms(
    SvgNode clipPathNode, {
    required Matrix4 rootTransform,
    required Set<String> visitedClipPaths,
  }) {
    final path = Path();
    final added = _appendClipPathGeometryWithTransforms(
      target: path,
      node: clipPathNode,
      currentTransform: rootTransform,
      useStack: <String>{},
      visitedClipPaths: visitedClipPaths,
    );
    return added ? path : null;
  }

  /// Appends geometry from clipPath children, handling transforms on each child.
  bool _appendClipPathGeometryWithTransforms({
    required Path target,
    required SvgNode node,
    required Matrix4 currentTransform,
    required Set<String> useStack,
    required Set<String> visitedClipPaths,
  }) {
    final matrix = Matrix4.copy(currentTransform);
    _applyNodeTransform(matrix, node);

    switch (node.tagName) {
      case 'clipPath':
      case 'g':
      case 'svg':
      case 'symbol':
        var added = false;
        for (final child in node.children) {
          if (_appendClipPathGeometryWithTransforms(
            target: target,
            node: child,
            currentTransform: matrix,
            useStack: useStack,
            visitedClipPaths: visitedClipPaths,
          )) {
            added = true;
          }
        }
        return added;
      case 'switch':
        final activeChild = resolveActiveSwitchChild(node);
        if (activeChild == null) {
          return false;
        }
        return _appendClipPathGeometryWithTransforms(
          target: target,
          node: activeChild,
          currentTransform: matrix,
          useStack: useStack,
          visitedClipPaths: visitedClipPaths,
        );
      case 'use':
        final hrefId = _extractHrefId(node);
        if (hrefId == null || hrefId.isEmpty || useStack.contains(hrefId)) {
          return false;
        }
        final referenced = _document.root.findById(hrefId);
        if (referenced == null ||
            !_isUseReferenceAllowedTag(referenced.tagName)) {
          return false;
        }
        final translated = Matrix4.copy(matrix)
          ..translateByDouble(
            _getNumber(node, 'x') ?? 0.0,
            _getNumber(node, 'y') ?? 0.0,
            0,
            1,
          );
        final nextUseStack = <String>{...useStack, hrefId};
        if (_isUseViewportReferenceTag(referenced.tagName)) {
          final useReferenceTransform = Matrix4.copy(translated);
          _applyUseViewportTransform(useReferenceTransform, node, referenced);
          return _appendClipPathGeometryWithTransforms(
            target: target,
            node: referenced,
            currentTransform: useReferenceTransform,
            useStack: nextUseStack,
            visitedClipPaths: visitedClipPaths,
          );
        }
        return _appendClipPathGeometryWithTransforms(
          target: target,
          node: referenced,
          currentTransform: translated,
          useStack: nextUseStack,
          visitedClipPaths: visitedClipPaths,
        );
      default:
        final geometry = _buildGeometryPath(node);
        if (geometry == null) {
          return false;
        }
        // Apply clip-rule for proper fill type in hit-testing
        _applyClipRuleToHitTestPath(geometry, node);
        target.addPath(geometry.transform(matrix.storage), Offset.zero);
        return true;
    }
  }

  /// Applies clip-rule to a hit-test path.
  void _applyClipRuleToHitTestPath(Path path, SvgNode node) {
    final clipRule = _getInheritedString(node, 'clip-rule')?.toLowerCase();
    if (clipRule == 'evenodd') {
      path.fillType = PathFillType.evenOdd;
    } else {
      path.fillType = PathFillType.nonZero;
    }
  }

  /// Checks if a point is inside the mask region.
  /// Handles mask transforms, maskUnits/maskContentUnits, nested masks,
  /// luminance-based hit detection, and gradient alpha threshold-based hit detection.
  bool _isPointInsideMask(
    SvgNode node,
    Offset localPoint, {
    required Set<String> visitedMasks,
  }) {
    final maskValue = _extractStyleValue(node, 'mask');
    final maskId = _extractUrlId(maskValue ?? node.getAttributeValue('mask'));
    if (maskId == null || maskId.isEmpty) {
      return true;
    }
    // Prevent infinite recursion from circular mask references
    if (visitedMasks.contains(maskId) ||
        visitedMasks.length >= _kMaxClipMaskRecursionDepth) {
      return true;
    }
    final maskNode = _document.root.findById(maskId);
    if (maskNode == null || maskNode.tagName != 'mask') {
      return true;
    }

    // Check if mask itself has a mask (nested mask)
    final nestedVisited = <String>{...visitedMasks, maskId};
    if (!_isPointInsideMask(
      maskNode,
      localPoint,
      visitedMasks: nestedVisited,
    )) {
      return false;
    }

    final maskRegion = _resolveMaskRegionRectForNodeSpace(
      targetNode: node,
      maskNode: maskNode,
    );
    if (maskRegion != null && !maskRegion.contains(localPoint)) {
      return false;
    }

    final rootTransform = _resolveContainerRootTransformForUnits(
      targetNode: node,
      unitsValue: maskNode.getAttributeValue('maskContentUnits')?.toString(),
      defaultValue: 'userspaceonuse',
    );
    if (rootTransform == null) {
      return true;
    }

    // Determine mask type for luminance-aware hit testing
    final maskType = _resolveMaskTypeForHitTest(maskNode, node);
    final useLuminanceHitTest = maskType == 'luminance';

    // Build path from mask content that has visible paint (considering luminance)
    final maskPath = _buildVisibleMaskGeometryPath(
      maskNode,
      rootTransform: rootTransform,
      visitedMasks: nestedVisited,
      useLuminanceHitTest: useLuminanceHitTest,
    );
    if (maskPath == null) {
      // No visible mask content - allow hit
      return true;
    }
    return maskPath.contains(localPoint);
  }

  /// Resolves the mask-type for hit-testing purposes.
  ///
  /// Returns 'luminance' (default per SVG spec) or 'alpha'.
  String _resolveMaskTypeForHitTest(SvgNode maskNode, SvgNode maskedNode) {
    // Check CSS mask-mode property on masked element
    final maskMode = _extractStyleValue(maskedNode, 'mask-mode');
    if (maskMode != null) {
      final normalized = maskMode.toString().trim().toLowerCase();
      if (normalized == 'luminance') return 'luminance';
      if (normalized == 'alpha') return 'alpha';
    }

    // Check CSS mask-type property on masked element
    final maskType = _extractStyleValue(maskedNode, 'mask-type');
    if (maskType != null) {
      final normalized = maskType.toString().trim().toLowerCase();
      if (normalized == 'luminance') return 'luminance';
      if (normalized == 'alpha') return 'alpha';
    }

    // Check type attribute on mask element
    final typeAttr = maskNode.getAttributeValue('type')?.toString();
    if (typeAttr != null) {
      final normalized = typeAttr.trim().toLowerCase();
      if (normalized == 'luminance') return 'luminance';
      if (normalized == 'alpha') return 'alpha';
    }

    // Check mask-type style on mask element
    final maskElementType = _extractStyleValue(maskNode, 'mask-type');
    if (maskElementType != null) {
      final normalized = maskElementType.toString().trim().toLowerCase();
      if (normalized == 'luminance') return 'luminance';
      if (normalized == 'alpha') return 'alpha';
    }

    // Default to luminance per SVG 2 spec
    return 'luminance';
  }

  /// Builds a geometry path from mask content that has visible paint.
  /// Excludes shapes with both fill:none and stroke:none, since they
  /// contribute nothing to the mask's visual output (zero alpha/luminance).
  ///
  /// When [useLuminanceHitTest] is true, also excludes black/dark content
  /// that would have near-zero luminance in a luminance mask.
  Path? _buildVisibleMaskGeometryPath(
    SvgNode containerNode, {
    required Matrix4 rootTransform,
    required Set<String> visitedMasks,
    bool useLuminanceHitTest = false,
  }) {
    final path = Path();
    final added = _appendVisibleMaskGeometry(
      target: path,
      node: containerNode,
      currentTransform: rootTransform,
      useStack: <String>{},
      visitedMasks: visitedMasks,
      useLuminanceHitTest: useLuminanceHitTest,
    );
    return added ? path : null;
  }

  bool _appendVisibleMaskGeometry({
    required Path target,
    required SvgNode node,
    required Matrix4 currentTransform,
    required Set<String> useStack,
    required Set<String> visitedMasks,
    bool useLuminanceHitTest = false,
  }) {
    final matrix = Matrix4.copy(currentTransform);
    _applyNodeTransform(matrix, node);

    switch (node.tagName) {
      case 'a':
      case 'mask':
      case 'g':
      case 'svg':
      case 'symbol':
        var added = false;
        for (final child in node.children) {
          if (_appendVisibleMaskGeometry(
            target: target,
            node: child,
            currentTransform: matrix,
            useStack: useStack,
            visitedMasks: visitedMasks,
            useLuminanceHitTest: useLuminanceHitTest,
          )) {
            added = true;
          }
        }
        return added;
      case 'switch':
        final activeChild = resolveActiveSwitchChild(node);
        if (activeChild == null) {
          return false;
        }
        return _appendVisibleMaskGeometry(
          target: target,
          node: activeChild,
          currentTransform: matrix,
          useStack: useStack,
          visitedMasks: visitedMasks,
          useLuminanceHitTest: useLuminanceHitTest,
        );
      case 'use':
        final hrefId = _extractHrefId(node);
        if (hrefId == null || hrefId.isEmpty || useStack.contains(hrefId)) {
          return false;
        }
        final referenced = _document.root.findById(hrefId);
        if (referenced == null ||
            !_isUseReferenceAllowedTag(referenced.tagName)) {
          return false;
        }
        final translated = Matrix4.copy(matrix)
          ..translateByDouble(
            _getNumber(node, 'x') ?? 0.0,
            _getNumber(node, 'y') ?? 0.0,
            0,
            1,
          );
        final nextUseStack = <String>{...useStack, hrefId};
        if (_isUseViewportReferenceTag(referenced.tagName)) {
          final useReferenceTransform = Matrix4.copy(translated);
          _applyUseViewportTransform(useReferenceTransform, node, referenced);
          return _appendVisibleMaskGeometry(
            target: target,
            node: referenced,
            currentTransform: useReferenceTransform,
            useStack: nextUseStack,
            visitedMasks: visitedMasks,
            useLuminanceHitTest: useLuminanceHitTest,
          );
        }
        return _appendVisibleMaskGeometry(
          target: target,
          node: referenced,
          currentTransform: translated,
          useStack: nextUseStack,
          visitedMasks: visitedMasks,
          useLuminanceHitTest: useLuminanceHitTest,
        );
      default:
        // Check if this element has any visible paint contribution
        // For masks, elements with fill:none and stroke:none contribute zero alpha
        // For luminance masks, also check if the color has luminance > threshold
        if (!_hasMaskVisiblePaint(
          node,
          useLuminanceHitTest: useLuminanceHitTest,
        )) {
          return false;
        }
        final geometry = _buildGeometryPath(node);
        if (geometry == null) {
          return false;
        }
        target.addPath(geometry.transform(matrix.storage), Offset.zero);
        return true;
    }
  }

  /// Checks if a mask content element has any visible paint that would
  /// contribute to the mask's alpha/luminance output.
  ///
  /// When [useLuminanceHitTest] is true, also checks that the fill/stroke
  /// color has sufficient luminance (black = 0 luminance = not hittable).
  bool _hasMaskVisiblePaint(SvgNode node, {bool useLuminanceHitTest = false}) {
    // Check fill - default is black which contributes to mask
    final fillValue = _getInheritedAttributeValue(node, 'fill');
    final hasFill = !_isPaintNone(fillValue);

    // Check stroke
    final strokeValue = _getInheritedAttributeValue(node, 'stroke');
    final hasStroke = strokeValue != null && !_isPaintNone(strokeValue);

    // Check opacity - fully transparent elements don't contribute
    final opacity = _getInheritedNumber(node, 'opacity') ?? 1.0;
    if (opacity <= 0) {
      return false;
    }

    // Check fill-opacity and stroke-opacity
    final fillOpacity = _getInheritedNumber(node, 'fill-opacity') ?? 1.0;
    final strokeOpacity = _getInheritedNumber(node, 'stroke-opacity') ?? 1.0;

    // For luminance-based hit testing, check if colors have sufficient luminance
    if (useLuminanceHitTest) {
      bool fillHasLuminance = false;
      bool strokeHasLuminance = false;

      if (hasFill && fillOpacity > 0 && fillValue != null) {
        final luminance = _computeColorLuminanceForHitTest(fillValue);
        fillHasLuminance = luminance >= _kMinLuminanceForHit;
      }

      if (hasStroke && strokeOpacity > 0) {
        final luminance = _computeColorLuminanceForHitTest(strokeValue);
        strokeHasLuminance = luminance >= _kMinLuminanceForHit;
      }

      return fillHasLuminance || strokeHasLuminance;
    }

    // For alpha-based hit testing, just check opacity
    return (hasFill && fillOpacity > 0) || (hasStroke && strokeOpacity > 0);
  }

  /// Computes the luminance of a color value for hit-testing purposes.
  ///
  /// Returns 1.0 for white, 0.0 for black, and intermediate values for
  /// other colors. For gradient references, returns 0.5 as a safe default.
  double _computeColorLuminanceForHitTest(Object? colorValue) {
    if (colorValue == null) {
      return 0.0; // No color = black = 0 luminance
    }

    final colorStr = colorValue.toString().trim().toLowerCase();

    // Handle 'none' - no paint = 0 luminance
    if (colorStr == 'none') {
      return 0.0;
    }

    // Handle gradient references - assume partial visibility
    if (colorStr.startsWith('url(')) {
      return 0.5; // Conservative: assume gradient has some visible parts
    }

    // Handle named colors
    final namedColor = _resolveNamedColorForHitTest(colorStr);
    if (namedColor != null) {
      return _computeRgbLuminance(namedColor);
    }

    // Handle hex colors
    if (colorStr.startsWith('#')) {
      final hex = colorStr.substring(1);
      int? r, g, b;

      if (hex.length == 3) {
        // #RGB
        r = int.tryParse(hex[0] + hex[0], radix: 16);
        g = int.tryParse(hex[1] + hex[1], radix: 16);
        b = int.tryParse(hex[2] + hex[2], radix: 16);
      } else if (hex.length == 6) {
        // #RRGGBB
        r = int.tryParse(hex.substring(0, 2), radix: 16);
        g = int.tryParse(hex.substring(2, 4), radix: 16);
        b = int.tryParse(hex.substring(4, 6), radix: 16);
      }

      if (r != null && g != null && b != null) {
        return _computeRgbLuminance((r, g, b));
      }
    }

    // Handle rgb() function
    final rgbMatch = RegExp(
      r'rgb\s*\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*\)',
    ).firstMatch(colorStr);
    if (rgbMatch != null) {
      final r = int.tryParse(rgbMatch.group(1)!);
      final g = int.tryParse(rgbMatch.group(2)!);
      final b = int.tryParse(rgbMatch.group(3)!);
      if (r != null && g != null && b != null) {
        return _computeRgbLuminance((r, g, b));
      }
    }

    // Default: assume some visibility
    return 0.5;
  }

  /// Computes luminance from RGB components (0-255 each).
  double _computeRgbLuminance((int, int, int) rgb) {
    final (r, g, b) = rgb;
    // Normalize to 0-1 range and apply luminance coefficients
    return (r / 255.0) * _kHitTestLuminanceR +
        (g / 255.0) * _kHitTestLuminanceG +
        (b / 255.0) * _kHitTestLuminanceB;
  }

  /// Resolves common named colors for luminance calculation.
  (int, int, int)? _resolveNamedColorForHitTest(String colorName) {
    switch (colorName) {
      case 'white':
        return (255, 255, 255);
      case 'black':
        return (0, 0, 0);
      case 'red':
        return (255, 0, 0);
      case 'lime':
      case 'green':
        return (0, 255, 0);
      case 'blue':
        return (0, 0, 255);
      case 'yellow':
        return (255, 255, 0);
      case 'cyan':
      case 'aqua':
        return (0, 255, 255);
      case 'magenta':
      case 'fuchsia':
        return (255, 0, 255);
      case 'gray':
      case 'grey':
        return (128, 128, 128);
      case 'silver':
        return (192, 192, 192);
      case 'maroon':
        return (128, 0, 0);
      case 'olive':
        return (128, 128, 0);
      case 'purple':
        return (128, 0, 128);
      case 'teal':
        return (0, 128, 128);
      case 'navy':
        return (0, 0, 128);
      case 'orange':
        return (255, 165, 0);
      case 'transparent':
        return (0, 0, 0); // Transparent has 0 luminance contribution
      default:
        return null; // Unknown named color
    }
  }

  Matrix4? _resolveContainerRootTransformForUnits({
    required SvgNode targetNode,
    required String? unitsValue,
    required String defaultValue,
  }) {
    final normalized = (unitsValue ?? defaultValue).trim().toLowerCase();
    if (normalized != 'objectboundingbox') {
      return Matrix4.identity();
    }
    final localBounds = _computeNodeLocalBounds(targetNode);
    if (localBounds == null ||
        localBounds.width.abs() < 1e-6 ||
        localBounds.height.abs() < 1e-6) {
      return null;
    }
    return Matrix4.identity()
      ..setEntry(0, 0, localBounds.width)
      ..setEntry(1, 1, localBounds.height)
      ..setEntry(0, 3, localBounds.left)
      ..setEntry(1, 3, localBounds.top);
  }

  Rect? _resolveMaskRegionRectForNodeSpace({
    required SvgNode targetNode,
    required SvgNode maskNode,
  }) {
    final units =
        (maskNode.getAttributeValue('maskUnits')?.toString() ??
                'objectBoundingBox')
            .trim()
            .toLowerCase();
    if (units == 'objectboundingbox') {
      final targetBounds = _computeNodeLocalBounds(targetNode);
      if (targetBounds == null) {
        return null;
      }
      // Use raw attribute values to detect percentages since the parser
      // strips the '%' suffix from numeric attributes.
      final x = _parseMaskRegionBoundingBoxValueForHitTest(maskNode, 'x');
      final y = _parseMaskRegionBoundingBoxValueForHitTest(maskNode, 'y');
      final width = _parseMaskRegionBoundingBoxValueForHitTest(
        maskNode,
        'width',
      );
      final height = _parseMaskRegionBoundingBoxValueForHitTest(
        maskNode,
        'height',
      );
      final resolvedX = x ?? -0.1;
      final resolvedY = y ?? -0.1;
      final resolvedWidth = width ?? 1.2;
      final resolvedHeight = height ?? 1.2;
      if (resolvedWidth <= 0 || resolvedHeight <= 0) {
        return null;
      }
      return Rect.fromLTWH(
        targetBounds.left + resolvedX * targetBounds.width,
        targetBounds.top + resolvedY * targetBounds.height,
        targetBounds.width * resolvedWidth,
        targetBounds.height * resolvedHeight,
      );
    }

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
    return Rect.fromLTWH(x, y, width, height);
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

  Rect? _resolveMaskUnitsViewportRect() {
    final viewBox = _document.viewBox;
    if (viewBox != null && viewBox.width > 0 && viewBox.height > 0) {
      return viewBox;
    }
    final root = _document.root;
    final width = _getNumber(root, 'width');
    final height = _getNumber(root, 'height');
    if (width == null || height == null || width <= 0 || height <= 0) {
      return null;
    }
    return Rect.fromLTWH(0, 0, width, height);
  }

  /// Parses a mask region attribute for objectBoundingBox units in hit-testing.
  ///
  /// Uses raw attribute values to properly detect percentage values,
  /// since the SVG parser strips the '%' suffix from numeric attributes.
  /// In objectBoundingBox mode, percentages like "25%" should be treated
  /// as 0.25 (a fraction of the bounding box).
  double? _parseMaskRegionBoundingBoxValueForHitTest(
    SvgNode maskNode,
    String attrName,
  ) {
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

  bool _isPointInsideForeignObjectViewport(SvgNode node, Offset localPoint) {
    if (node.tagName != 'foreignObject') {
      return true;
    }

    // Check requiredExtensions - if specified, foreignObject doesn't render
    final requiredExtensions = node.getAttributeValue('requiredExtensions');
    if (requiredExtensions != null &&
        requiredExtensions.toString().trim().isNotEmpty) {
      return false;
    }

    final x = _getNumber(node, 'x') ?? 0.0;
    final y = _getNumber(node, 'y') ?? 0.0;
    final width = _getNumber(node, 'width') ?? 0.0;
    final height = _getNumber(node, 'height') ?? 0.0;
    if (width <= 0 || height <= 0) {
      return false;
    }

    // Check overflow attribute - default for foreignObject is hidden
    final overflow = _getInheritedString(node, 'overflow')?.toLowerCase();
    if (overflow == 'visible') {
      // With overflow:visible, no clipping is applied
      return true;
    }

    return Rect.fromLTWH(x, y, width, height).contains(localPoint);
  }

  String? _extractUrlId(Object? value) {
    final raw = value?.toString().trim();
    if (raw == null || raw.isEmpty) {
      return null;
    }
    if (raw.startsWith('#') && raw.length > 1) {
      return raw.substring(1);
    }
    final urlMatch = RegExp(
      r'''url\(\s*['"]?#([^'")\s]+)['"]?\s*\)''',
      caseSensitive: false,
    ).firstMatch(raw);
    return urlMatch?.group(1);
  }
}
