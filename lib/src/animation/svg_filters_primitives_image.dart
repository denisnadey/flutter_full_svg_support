part of 'svg_filters.dart';

/// feImage primitive
///
/// Renders referenced images (internal elements, external URLs, or data URIs)
/// into the filter pipeline. Supports:
/// - Internal element references (#elementId)
/// - Data URIs (data:image/png;base64,...)
/// - External URLs (http://, https://)
/// - Asset references
///
/// On load failure, produces a transparent image of the filter region size.
class SvgFeImageFilter extends SvgFilter {
  /// URL/IRI of the image source.
  /// Can be:
  /// - Element reference: #myElement
  /// - Data URI: data:image/png;base64,...
  /// - External URL: http://example.com/image.png
  /// - Asset path: assets/images/image.png
  final String? href;

  /// Geometry of the filter primitive subregion.
  ///
  /// Parsed numeric values are kept for backward compatibility, but painter
  /// should prefer raw values to preserve percentage semantics.
  final double x;
  final double y;
  final double width;
  final double height;

  /// Raw geometry attributes as written in SVG (`10`, `20%`, etc.).
  final String? xRaw;
  final String? yRaw;
  final String? widthRaw;
  final String? heightRaw;

  /// preserveAspectRatio attribute for image fitting.
  final String? preserveAspectRatio;

  SvgFeImageFilter({
    required super.id,
    this.href,
    this.x = 0.0,
    this.y = 0.0,
    this.width = 0.0,
    this.height = 0.0,
    this.xRaw,
    this.yRaw,
    this.widthRaw,
    this.heightRaw,
    this.preserveAspectRatio,
    super.input,
    super.resultName,
  }) : super(type: SvgFilterType.image);

  @override
  ui.ImageFilter? apply() => null;

  /// Whether this feImage references an SVG element by ID.
  bool get isElementReference {
    final h = href;
    return h != null && h.startsWith('#');
  }

  /// Get the referenced element ID if this is an element reference.
  String? get referencedElementId {
    final h = href;
    if (h == null || !h.startsWith('#')) return null;
    return h.substring(1);
  }

  /// Whether this feImage references a data URI.
  bool get isDataUri {
    final h = href;
    return h != null && h.startsWith('data:');
  }

  /// Whether this feImage references an external URL.
  bool get isExternalUrl {
    final h = href;
    if (h == null) return false;
    return h.startsWith('http://') || h.startsWith('https://');
  }

  /// Whether this feImage references an external image (data URI or URL).
  bool get isExternalImage {
    final h = href;
    return h != null && !h.startsWith('#');
  }

  /// Get the primitive subregion for rendering.
  ui.Rect get subregion => ui.Rect.fromLTWH(x, y, width, height);
}

/// Utility class for handling feImage external resources.
///
/// Provides helpers for loading and rendering external images in filter chains.
class FeImageLoader {
  const FeImageLoader._();

  /// Creates a transparent RGBA pixel buffer of the given size.
  ///
  /// Used as fallback when image loading fails per SVG spec.
  static Uint8List createTransparentBuffer(int width, int height) {
    if (width <= 0 || height <= 0) return Uint8List(0);
    return Uint8List(width * height * 4); // All zeros = transparent
  }

  /// Validates if an href is a supported image format.
  ///
  /// Supports:
  /// - PNG, JPEG, GIF, WebP, BMP
  /// - SVG (nested SVG warning)
  static bool isSupportedImageFormat(String href) {
    final lower = href.toLowerCase();

    // Check data URI MIME types
    if (lower.startsWith('data:')) {
      return lower.startsWith('data:image/');
    }

    // Check file extensions
    if (lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.bmp') ||
        lower.endsWith('.svg')) {
      return true;
    }

    // For URLs without extension, assume supported
    return lower.startsWith('http://') || lower.startsWith('https://');
  }

  /// Checks if the href refers to an SVG file (potential recursion).
  static bool isSvgImage(String href) {
    final lower = href.toLowerCase();
    if (lower.endsWith('.svg')) return true;
    if (lower.startsWith('data:image/svg+xml')) return true;
    return false;
  }
}
