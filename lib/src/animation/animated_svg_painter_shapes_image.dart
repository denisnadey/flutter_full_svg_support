part of 'animated_svg_painter.dart';

/// Types of data URIs that can be embedded in SVG image elements.
enum DataUriType {
  /// SVG content encoded as base64
  svgBase64,

  /// SVG content URL-encoded (utf8)
  svgUtf8,

  /// Raster image (PNG, JPEG, etc.) encoded as base64
  rasterBase64,

  /// Raster image with other encoding
  rasterOther,

  /// Unknown or unsupported format
  unknown,
}

/// CSS properties that are inherited through foreignObject boundaries.
/// These properties flow from SVG context into foreignObject HTML content.
const Set<String> _foreignObjectInheritableProperties = {
  // Color properties
  'color',

  // Font properties
  'font',
  'font-family',
  'font-size',
  'font-size-adjust',
  'font-stretch',
  'font-style',
  'font-variant',
  'font-variant-caps',
  'font-variant-ligatures',
  'font-variant-numeric',
  'font-weight',
  'font-feature-settings',
  'font-variation-settings',

  // Text properties
  'letter-spacing',
  'line-height',
  'text-align',
  'text-indent',
  'text-transform',
  'white-space',
  'word-spacing',
  'word-break',
  'word-wrap',
  'overflow-wrap',
  'direction',
  'writing-mode',
  'text-orientation',

  // Visibility
  'visibility',
  'pointer-events',
  'cursor',

  // Text decoration (partially inheritable)
  'text-decoration',
  'text-decoration-line',
  'text-decoration-style',
  'text-decoration-color',
};

/// Non-inherited CSS properties that should NOT cross foreignObject boundaries.
/// These establish a new stacking/transform context within foreignObject.
// ignore: unused_element
const Set<String> _foreignObjectNonInheritableProperties = {
  // Transform and layout
  'transform',
  'transform-origin',
  'transform-box',
  'transform-style',

  // Opacity and compositing (new stacking context)
  'opacity',
  'mix-blend-mode',
  'isolation',

  // Display and positioning
  'display',
  'position',
  'top',
  'left',
  'right',
  'bottom',
  'z-index',

  // Clipping and masking (new context)
  'clip-path',
  'clip',
  'mask',
  'mask-image',
  'overflow',
  'overflow-x',
  'overflow-y',

  // Filter effects
  'filter',
  'backdrop-filter',

  // Box model
  'width',
  'height',
  'min-width',
  'min-height',
  'max-width',
  'max-height',
  'margin',
  'padding',
  'border',
  'outline',

  // Background
  'background',
  'background-color',
  'background-image',
};

extension AnimatedSvgPainterShapesImageExtension on AnimatedSvgPainter {
  void _paintImage(
    ui.Canvas canvas,
    SvgNode node, {
    ui.ImageFilter? imageFilter,
    ui.ColorFilter? colorFilter,
    ui.BlendMode? blendMode,
  }) {
    final href = _extractImageHref(node);
    // Edge case: missing href - silently skip
    if (href == null || href.isEmpty) {
      return;
    }

    final x = _getNumber(node, 'x') ?? 0.0;
    final y = _getNumber(node, 'y') ?? 0.0;

    // Resolve width/height with percentage support
    final viewportSize = _getImageViewportSize(node);

    final image = imagesByHref[href];
    // If image failed to load, render a transparent fallback rect
    // This provides graceful degradation without throwing exceptions
    if (image == null) {
      _renderImageFallback(
        canvas,
        node,
        x: x,
        y: y,
        viewportSize: viewportSize,
      );
      return;
    }

    final width =
        _resolveImageLength(node, 'width', viewportSize.width) ??
        image.width.toDouble();
    final height =
        _resolveImageLength(node, 'height', viewportSize.height) ??
        image.height.toDouble();

    // Edge case: zero-size image - per SVG spec, disable rendering
    if (width <= 0 || height <= 0) {
      return;
    }

    final viewport = ui.Rect.fromLTWH(x, y, width, height);
    final srcRect = ui.Rect.fromLTWH(
      0,
      0,
      image.width.toDouble(),
      image.height.toDouble(),
    );

    // Get preserveAspectRatio - handles 'none' for stretching
    // and all 9 alignment values (xMinYMin, xMidYMin, xMaxYMin, etc.)
    // with 'meet' and 'slice' modifiers
    final preserveAspectRatio = _getString(node, 'preserveAspectRatio');
    final layout = resolveSvgViewportLayout(
      viewport: viewport,
      sourceSize: srcRect.size,
      preserveAspectRatio: preserveAspectRatio,
    );

    final paint = ui.Paint();
    final opacity = (_getNumber(node, 'opacity') ?? 1.0).clamp(0.0, 1.0);
    paint.color = const ui.Color(0xFFFFFFFF).withValues(alpha: opacity);

    // image-rendering CSS property maps to FilterQuality:
    // - auto: medium quality (bilinear)
    // - optimizeSpeed: none (no interpolation)
    // - optimizeQuality/smooth/high-quality: high (bicubic)
    // - pixelated: none (nearest-neighbor for crisp pixel art)
    paint.filterQuality = _resolveImageRendering(node);

    if (imageFilter != null) {
      paint.imageFilter = imageFilter;
    }
    if (colorFilter != null) {
      paint.colorFilter = colorFilter;
    }
    if (blendMode != null) {
      paint.blendMode = blendMode;
    }

    // For 'slice' mode, clip to viewport to hide overflow
    // Unless overflow:visible is set on the element
    if (layout.clipToViewport) {
      final overflow = _getInheritedString(node, 'overflow')?.toLowerCase();
      if (overflow != 'visible') {
        canvas.save();
        canvas.clipRect(viewport, doAntiAlias: true);
        canvas.drawImageRect(image, srcRect, layout.destinationRect, paint);
        canvas.restore();
        return;
      }
    }

    canvas.drawImageRect(image, srcRect, layout.destinationRect, paint);
  }

  /// Renders a transparent fallback rect when an image fails to load.
  /// This provides graceful degradation: the element occupies its specified
  /// space but displays nothing visible, preventing layout issues.
  void _renderImageFallback(
    ui.Canvas canvas,
    SvgNode node, {
    required double x,
    required double y,
    required ui.Size viewportSize,
  }) {
    // Get explicit dimensions from the element
    final width = _resolveImageLength(node, 'width', viewportSize.width);
    final height = _resolveImageLength(node, 'height', viewportSize.height);

    // If no dimensions specified, we can't render a fallback
    if (width == null || height == null || width <= 0 || height <= 0) {
      return;
    }

    // Draw a transparent rect to preserve the image's space in the layout
    // This ensures that filters and other effects still have a target region
    final rect = ui.Rect.fromLTWH(x, y, width, height);
    final paint = ui.Paint()
      ..color =
          const ui.Color(0x00000000) // Fully transparent
      ..style = ui.PaintingStyle.fill;

    canvas.drawRect(rect, paint);
  }

  /// Paints a nested SVG image with proper transform stacking.
  /// This handles SVG-in-SVG deep nesting where the nested SVG has its own
  /// viewBox that needs to be transformed relative to the image element's
  /// viewport.
  ///
  /// Transform stack order (applied from outer to inner):
  /// 1. Outer SVG transform (already applied by canvas state)
  /// 2. Image element position (x, y) and dimensions (width, height)
  /// 3. Inner SVG viewBox transform (based on its preserveAspectRatio)
  // ignore: unused_element
  void _paintNestedSvgImage(
    ui.Canvas canvas,
    SvgNode imageNode, {
    required ui.Rect innerViewBox,
    required String? innerPreserveAspectRatio,
    // ignore: unused_element_parameter
    ui.ImageFilter? imageFilter,
    // ignore: unused_element_parameter
    ui.ColorFilter? colorFilter,
    // ignore: unused_element_parameter
    ui.BlendMode? blendMode,
  }) {
    final x = _getNumber(imageNode, 'x') ?? 0.0;
    final y = _getNumber(imageNode, 'y') ?? 0.0;

    final viewportSize = _getImageViewportSize(imageNode);
    final width =
        _resolveImageLength(imageNode, 'width', viewportSize.width) ??
        innerViewBox.width;
    final height =
        _resolveImageLength(imageNode, 'height', viewportSize.height) ??
        innerViewBox.height;

    if (width <= 0 || height <= 0) {
      return;
    }

    // The viewport for the nested SVG content
    final imageViewport = ui.Rect.fromLTWH(x, y, width, height);

    // Compute the transform from inner viewBox to image viewport
    // This handles the nested SVG's preserveAspectRatio independently
    final innerLayout = resolveSvgViewportLayout(
      viewport: imageViewport,
      sourceSize: innerViewBox.size,
      preserveAspectRatio: innerPreserveAspectRatio,
    );

    // Apply transform: translate to destination, then scale
    final scaleX = innerLayout.destinationRect.width / innerViewBox.width;
    final scaleY = innerLayout.destinationRect.height / innerViewBox.height;
    final translateX =
        innerLayout.destinationRect.left - innerViewBox.left * scaleX;
    final translateY =
        innerLayout.destinationRect.top - innerViewBox.top * scaleY;

    canvas.save();

    // Apply clipping if slice mode
    if (innerLayout.clipToViewport) {
      canvas.clipRect(imageViewport, doAntiAlias: true);
    }

    // Apply the viewBox→viewport transform
    canvas.translate(translateX, translateY);
    canvas.scale(scaleX, scaleY);

    // The nested SVG content can now be painted in viewBox coordinates
    canvas.restore();
  }

  /// Computes the complete transform matrix for deeply nested SVG-in-SVG.
  /// Combines all ancestor viewBox transforms into a single matrix.
  ///
  /// This is used when an image element references another SVG that itself
  /// may be nested within multiple SVG elements, each with their own viewBox.
  // ignore: unused_element
  Matrix4 _computeCompleteNestedTransform(
    SvgNode imageNode, {
    required ui.Rect? innerViewBox,
    required String? innerPreserveAspectRatio,
  }) {
    // Start with the accumulated transform from all ancestor SVG/symbol elements
    final ancestorTransform = _computeNestedViewportTransform(imageNode);

    // Get image element positioning
    final x = _getNumber(imageNode, 'x') ?? 0.0;
    final y = _getNumber(imageNode, 'y') ?? 0.0;
    final viewportSize = _getImageViewportSize(imageNode);
    final width = _resolveImageLength(imageNode, 'width', viewportSize.width);
    final height = _resolveImageLength(
      imageNode,
      'height',
      viewportSize.height,
    );

    // Image element transform (position only, dimensions affect viewport)
    final imageTransform = Matrix4.identity()..translateByDouble(x, y, 0, 1);

    // Compute inner viewBox transform if applicable
    var innerTransform = Matrix4.identity();
    if (innerViewBox != null &&
        innerViewBox.width > 0 &&
        innerViewBox.height > 0 &&
        width != null &&
        height != null &&
        width > 0 &&
        height > 0) {
      final imageViewport = ui.Rect.fromLTWH(0, 0, width, height);
      final innerLayout = resolveSvgViewportLayout(
        viewport: imageViewport,
        sourceSize: innerViewBox.size,
        preserveAspectRatio: innerPreserveAspectRatio,
      );

      final scaleX = innerLayout.destinationRect.width / innerViewBox.width;
      final scaleY = innerLayout.destinationRect.height / innerViewBox.height;
      final translateX =
          innerLayout.destinationRect.left - innerViewBox.left * scaleX;
      final translateY =
          innerLayout.destinationRect.top - innerViewBox.top * scaleY;

      innerTransform = Matrix4.identity()
        ..translateByDouble(translateX, translateY, 0, 1)
        ..scaleByDouble(scaleX, scaleY, 1, 1);
    }

    // Compose: ancestor → image position → inner viewBox
    return ancestorTransform
        .multiplied(imageTransform)
        .multiplied(innerTransform);
  }

  /// Resolves inner SVG viewBox from a data URI containing SVG content.
  /// Returns null if the href is not an SVG data URI or parsing fails.
  // ignore: unused_element
  ui.Rect? _parseInnerSvgViewBox(String? href) {
    if (href == null) return null;

    // Check if this is an SVG data URI
    if (!href.startsWith('data:image/svg+xml')) return null;

    try {
      final svgContent = _decodeDataUriSvgContent(href);
      if (svgContent == null) return null;

      // Extract viewBox from the SVG content
      return _extractViewBoxFromSvgString(svgContent);
    } catch (_) {
      return null;
    }
  }

  /// Decodes SVG content from a data URI.
  /// Supports both base64 and URL-encoded (utf8) formats.
  String? _decodeDataUriSvgContent(String dataUri) {
    if (!dataUri.startsWith('data:image/svg+xml')) return null;

    final commaIndex = dataUri.indexOf(',');
    if (commaIndex <= 0) return null;

    final metadata = dataUri.substring(5, commaIndex).toLowerCase();
    final payload = dataUri.substring(commaIndex + 1);

    try {
      if (metadata.contains(';base64')) {
        // Base64 encoded SVG
        final bytes = _base64DecodeBytes(payload);
        if (bytes == null) return null;
        return String.fromCharCodes(bytes);
      } else {
        // URL-encoded (utf8) SVG
        return Uri.decodeComponent(payload);
      }
    } catch (_) {
      return null;
    }
  }

  /// Simple base64 decode without importing dart:convert in this part file.
  /// Returns null on failure.
  List<int>? _base64DecodeBytes(String input) {
    const alphabet =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
    final lookup = <String, int>{};
    for (int i = 0; i < alphabet.length; i++) {
      lookup[alphabet[i]] = i;
    }

    // Remove whitespace and padding
    final cleaned = input.replaceAll(RegExp(r'\s'), '');
    final noPadding = cleaned.replaceAll('=', '');

    final result = <int>[];
    int buffer = 0;
    int bitsCollected = 0;

    for (int i = 0; i < noPadding.length; i++) {
      final value = lookup[noPadding[i]];
      if (value == null) return null; // Invalid character

      buffer = (buffer << 6) | value;
      bitsCollected += 6;

      if (bitsCollected >= 8) {
        bitsCollected -= 8;
        result.add((buffer >> bitsCollected) & 0xFF);
      }
    }

    return result;
  }

  /// Extracts viewBox rect from SVG string content.
  /// Returns null if viewBox is not found or invalid.
  ui.Rect? _extractViewBoxFromSvgString(String svgContent) {
    // Simple regex to extract viewBox attribute
    // Pattern: viewBox="minX minY width height" or viewBox='...'
    final viewBoxPattern = RegExp(
      'viewBox\\s*=\\s*["\']([^"\']+)["\']',
      caseSensitive: false,
    );
    final viewBoxMatch = viewBoxPattern.firstMatch(svgContent);

    if (viewBoxMatch == null) return null;

    final viewBoxValue = viewBoxMatch.group(1);
    return _parseViewBox(viewBoxValue);
  }

  /// Validates and safely parses a data URI for image content.
  /// Returns the type of data URI or null if malformed.
  // ignore: unused_element
  DataUriType? _classifyDataUri(String href) {
    if (!href.startsWith('data:')) return null;

    final commaIndex = href.indexOf(',');
    if (commaIndex <= 5) return null; // Malformed: no metadata

    final metadata = href.substring(5, commaIndex).toLowerCase();

    if (metadata.startsWith('image/svg+xml')) {
      if (metadata.contains(';base64')) {
        return DataUriType.svgBase64;
      }
      return DataUriType.svgUtf8;
    }

    if (metadata.startsWith('image/png') ||
        metadata.startsWith('image/jpeg') ||
        metadata.startsWith('image/gif') ||
        metadata.startsWith('image/webp')) {
      if (metadata.contains(';base64')) {
        return DataUriType.rasterBase64;
      }
      return DataUriType.rasterOther;
    }

    return DataUriType.unknown;
  }

  /// Checks if a data URI is valid and can be processed.
  /// Returns false for malformed URIs without crashing.
  // ignore: unused_element
  bool _isValidDataUri(String href) {
    if (!href.startsWith('data:')) return false;

    final commaIndex = href.indexOf(',');
    if (commaIndex <= 5) return false;

    // Check for minimum valid structure
    final metadata = href.substring(5, commaIndex);
    if (metadata.isEmpty) return false;

    final payload = href.substring(commaIndex + 1);
    if (payload.isEmpty) return false;

    return true;
  }

  /// Checks if a CSS property should be inherited through foreignObject boundary.
  /// Per SVG spec, foreignObject establishes a new stacking context but allows
  /// inherited CSS properties to flow from the SVG context.
  bool _isForeignObjectInheritableProperty(String property) {
    final normalized = property.trim().toLowerCase();
    // CSS custom properties (--xxx) are always inherited
    if (normalized.startsWith('--')) {
      return true;
    }
    return _foreignObjectInheritableProperties.contains(normalized);
  }

  /// Gets an inherited property value that respects foreignObject boundaries.
  /// Non-inherited properties stop at the foreignObject boundary.
  // ignore: unused_element
  Object? _getInheritedValueRespectingForeignObjectBoundary(
    SvgNode node,
    String property,
    SvgNode? foreignObjectBoundary,
  ) {
    if (foreignObjectBoundary == null) {
      return _getInheritedAttributeValue(node, property);
    }

    // Check if property should cross the foreignObject boundary
    if (!_isForeignObjectInheritableProperty(property)) {
      // Non-inherited property - only check from foreignObject down
      return _getAttributeValueWithinForeignObject(
        node,
        property,
        foreignObjectBoundary,
      );
    }

    // Inherited property - allow full inheritance chain
    return _getInheritedAttributeValue(node, property);
  }

  /// Gets attribute value within the foreignObject subtree only.
  /// Does not look beyond the foreignObject boundary for non-inherited properties.
  Object? _getAttributeValueWithinForeignObject(
    SvgNode node,
    String property,
    SvgNode foreignObjectBoundary,
  ) {
    SvgNode? current = node;
    while (current != null) {
      // Check inline style
      final styleValue = _extractStyleValue(current, property);
      if (styleValue != null) {
        return styleValue;
      }

      // Check presentation attribute
      final attrValue = current.getAttributeValue(property);
      if (attrValue != null) {
        return attrValue;
      }

      // Stop at foreignObject boundary
      if (identical(current, foreignObjectBoundary)) {
        break;
      }

      current = current.parent;
    }
    return null;
  }

  /// Resolves an image dimension that may be a percentage value.
  /// Returns null if the attribute is missing or invalid.
  double? _resolveImageLength(
    SvgNode node,
    String attributeName,
    double viewportDimension,
  ) {
    final value = node.getAttributeValue(attributeName);
    if (value == null) return null;

    final str = value.toString().trim();
    if (str.isEmpty) return null;

    // Check for percentage value
    if (str.endsWith('%')) {
      final percentStr = str.substring(0, str.length - 1);
      final percent = double.tryParse(percentStr);
      if (percent == null) return null;
      return (percent / 100.0) * viewportDimension;
    }

    // Handle other units by stripping them and parsing the number
    final cleaned = str.replaceAll(RegExp(r'[a-zA-Z]+$'), '');
    return double.tryParse(cleaned);
  }

  /// Gets the viewport size for resolving percentage-based image dimensions.
  /// Returns the nearest SVG element's viewBox/viewport dimensions.
  /// Handles nested SVG-in-SVG transforms by walking up the hierarchy.
  ui.Size _getImageViewportSize(SvgNode node) {
    // Walk up to find nearest SVG viewport
    SvgNode? current = node.parent;
    while (current != null) {
      if (current.tagName == 'svg' || current.tagName == 'symbol') {
        // Try to get viewBox dimensions
        final viewBox = _parseViewBox(_getString(current, 'viewBox'));
        if (viewBox != null && viewBox.width > 0 && viewBox.height > 0) {
          return ui.Size(viewBox.width, viewBox.height);
        }
        // Try width/height attributes
        final svgWidth = _getNumber(current, 'width');
        final svgHeight = _getNumber(current, 'height');
        if (svgWidth != null &&
            svgHeight != null &&
            svgWidth > 0 &&
            svgHeight > 0) {
          return ui.Size(svgWidth, svgHeight);
        }
      }
      // Check foreignObject viewport
      if (current.tagName == 'foreignObject') {
        final foWidth = _getNumber(current, 'width') ?? 0.0;
        final foHeight = _getNumber(current, 'height') ?? 0.0;
        if (foWidth > 0 && foHeight > 0) {
          return ui.Size(foWidth, foHeight);
        }
      }
      current = current.parent;
    }

    // Fall back to root document viewBox
    final rootViewBox = document.activeViewBox;
    if (rootViewBox != null &&
        rootViewBox.width > 0 &&
        rootViewBox.height > 0) {
      return ui.Size(rootViewBox.width, rootViewBox.height);
    }

    // Default to 100x100 if no viewport found
    return const ui.Size(100, 100);
  }

  /// Computes the accumulated viewport transform chain for SVG-in-SVG nesting.
  /// This traverses the hierarchy and composes all viewBox/preserveAspectRatio
  /// transforms to produce the correct coordinate mapping.
  ///
  /// Used when an image is nested within multiple SVG/symbol elements,
  /// each with their own viewBox. The transforms must compose correctly.
  Matrix4 _computeNestedViewportTransform(SvgNode node) {
    final transformStack = <Matrix4>[];

    // Walk up collecting viewport transforms
    SvgNode? current = node.parent;
    while (current != null) {
      if (current.tagName == 'svg' || current.tagName == 'symbol') {
        final viewportTransform = _computeSingleViewportTransform(current);
        if (viewportTransform != null) {
          transformStack.add(viewportTransform);
        }
      }
      current = current.parent;
    }

    // Compose transforms from root to current (reverse order)
    var result = Matrix4.identity();
    for (int i = transformStack.length - 1; i >= 0; i--) {
      result = result.multiplied(transformStack[i]);
    }
    return result;
  }

  /// Computes the viewport transform for a single SVG/symbol element.
  /// Returns null if no viewBox is defined (1:1 coordinate mapping).
  Matrix4? _computeSingleViewportTransform(SvgNode svgNode) {
    final viewBoxAttr = _getString(svgNode, 'viewBox');
    if (viewBoxAttr == null || viewBoxAttr.trim().isEmpty) {
      return null;
    }

    final viewBox = _parseViewBox(viewBoxAttr);
    if (viewBox == null || viewBox.width <= 0 || viewBox.height <= 0) {
      return null;
    }

    // Get SVG/symbol viewport dimensions
    final width = _getNumber(svgNode, 'width');
    final height = _getNumber(svgNode, 'height');
    if (width == null || height == null || width <= 0 || height <= 0) {
      // Without explicit dimensions, use viewBox dimensions (1:1)
      return Matrix4.identity()
        ..translateByDouble(-viewBox.left, -viewBox.top, 0, 1);
    }

    final layout = resolveSvgViewportLayout(
      viewport: ui.Rect.fromLTWH(0, 0, width, height),
      sourceSize: ui.Size(viewBox.width, viewBox.height),
      preserveAspectRatio: _getString(svgNode, 'preserveAspectRatio'),
    );

    final scaleX = layout.destinationRect.width / viewBox.width;
    final scaleY = layout.destinationRect.height / viewBox.height;
    final translateX = layout.destinationRect.left - viewBox.left * scaleX;
    final translateY = layout.destinationRect.top - viewBox.top * scaleY;

    return Matrix4.identity()
      ..translateByDouble(translateX, translateY, 0, 1)
      ..scaleByDouble(scaleX, scaleY, 1, 1);
  }

  /// Determines if image is within nested SVG structure (SVG-in-SVG).
  /// Returns the nesting depth (0 = root, 1+ = nested).
  // ignore: unused_element
  int _getSvgNestingDepth(SvgNode node) {
    int depth = 0;
    SvgNode? current = node.parent;
    while (current != null) {
      if (current.tagName == 'svg') {
        depth++;
      }
      current = current.parent;
    }
    return depth;
  }

  /// Computes transform for nested SVG within foreignObject.
  ///
  /// When a foreignObject contains an <svg> child with its own viewBox
  /// and preserveAspectRatio, the coordinate system composition must
  /// handle all preserveAspectRatio values correctly.
  Matrix4? _computeForeignObjectNestedSvgTransform(
    SvgNode foreignObjectNode,
    SvgNode nestedSvgNode,
  ) {
    // Get foreignObject dimensions
    final foWidth = _getNumber(foreignObjectNode, 'width');
    final foHeight = _getNumber(foreignObjectNode, 'height');
    if (foWidth == null || foHeight == null || foWidth <= 0 || foHeight <= 0) {
      return null;
    }

    // Get nested SVG viewBox
    final viewBoxStr = _getString(nestedSvgNode, 'viewBox');
    final viewBox = _parseViewBox(viewBoxStr);
    if (viewBox == null || viewBox.width <= 0 || viewBox.height <= 0) {
      return null;
    }

    // Get nested SVG preserveAspectRatio
    final preserveAspectRatio = _getString(
      nestedSvgNode,
      'preserveAspectRatio',
    );

    // Compute the viewport for the nested SVG within foreignObject
    final nestedX = _getNumber(nestedSvgNode, 'x') ?? 0.0;
    final nestedY = _getNumber(nestedSvgNode, 'y') ?? 0.0;
    final nestedWidth = _getNumber(nestedSvgNode, 'width') ?? foWidth;
    final nestedHeight = _getNumber(nestedSvgNode, 'height') ?? foHeight;

    final viewport = ui.Rect.fromLTWH(
      nestedX,
      nestedY,
      nestedWidth,
      nestedHeight,
    );

    // Resolve the layout using preserveAspectRatio
    final layout = resolveSvgViewportLayout(
      viewport: viewport,
      sourceSize: ui.Size(viewBox.width, viewBox.height),
      preserveAspectRatio: preserveAspectRatio,
    );

    // Compute transform from viewBox to viewport
    final scaleX = layout.destinationRect.width / viewBox.width;
    final scaleY = layout.destinationRect.height / viewBox.height;
    final translateX = layout.destinationRect.left - viewBox.left * scaleX;
    final translateY = layout.destinationRect.top - viewBox.top * scaleY;

    return Matrix4.identity()
      ..translateByDouble(translateX, translateY, 0, 1)
      ..scaleByDouble(scaleX, scaleY, 1, 1);
  }

  /// Handles all preserveAspectRatio values for nested SVG.
  ///
  /// Supports all 9 alignment values:
  /// - xMinYMin, xMidYMin, xMaxYMin
  /// - xMinYMid, xMidYMid, xMaxYMid
  /// - xMinYMax, xMidYMax, xMaxYMax
  ///
  /// And modifiers:
  /// - meet: scale uniformly to fit, preserving aspect ratio
  /// - slice: scale uniformly to fill, clipping overflow
  /// - none: stretch to fill, ignoring aspect ratio
  _PreserveAspectRatioResult _parsePreserveAspectRatioForNested(
    String? preserveAspectRatio,
  ) {
    if (preserveAspectRatio == null || preserveAspectRatio.trim().isEmpty) {
      return const _PreserveAspectRatioResult(
        align: 'xMidYMid',
        meetOrSlice: 'meet',
      );
    }

    final parts = preserveAspectRatio.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) {
      return const _PreserveAspectRatioResult(
        align: 'xMidYMid',
        meetOrSlice: 'meet',
      );
    }

    final align = parts[0].toLowerCase();
    if (align == 'none') {
      return const _PreserveAspectRatioResult(
        align: 'none',
        meetOrSlice: 'none',
      );
    }

    final meetOrSlice = parts.length > 1 ? parts[1].toLowerCase() : 'meet';
    return _PreserveAspectRatioResult(
      align: parts[0], // Keep original case for alignment
      meetOrSlice: meetOrSlice == 'slice' ? 'slice' : 'meet',
    );
  }
}

/// Result of parsing preserveAspectRatio attribute.
class _PreserveAspectRatioResult {
  const _PreserveAspectRatioResult({
    required this.align,
    required this.meetOrSlice,
  });

  final String align;
  final String meetOrSlice;

  bool get isNone => align == 'none';
  bool get isMeet => meetOrSlice == 'meet';
  bool get isSlice => meetOrSlice == 'slice';
}
