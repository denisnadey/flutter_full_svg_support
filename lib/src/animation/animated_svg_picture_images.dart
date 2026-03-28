part of 'animated_svg_picture.dart';

/// Allowed image MIME types for data URI validation.
/// Only these MIME types are processed; others are rejected for security.
const Set<String> _allowedImageMimeTypes = {
  'image/png',
  'image/jpeg',
  'image/jpg',
  'image/gif',
  'image/webp',
  'image/svg+xml',
  'image/bmp',
  'image/x-icon',
};

extension _AnimatedSvgPictureStateImagesExtension on _AnimatedSvgPictureState {
  void _scheduleImagePreload() {
    final hrefs = <String>{};
    _collectImageHrefs(_document.root, hrefs);
    if (hrefs.isEmpty) {
      return;
    }

    final generation = _imageLoadGeneration;
    _pendingImageHrefs
      ..clear()
      ..addAll(hrefs);

    _trace(
      category: 'image',
      message: 'Image preload scheduled',
      data: <String, Object?>{'count': hrefs.length},
    );

    for (final href in hrefs) {
      unawaited(_resolveImageByHref(href, generation));
    }
  }

  void _collectImageHrefs(SvgNode node, Set<String> hrefs) {
    if (node.tagName == 'image') {
      final href = _extractImageHref(node);
      if (href != null) {
        hrefs.add(href);
      }
    }
    for (final child in node.children) {
      _collectImageHrefs(child, hrefs);
    }
  }

  String? _extractImageHref(SvgNode node) {
    final raw =
        node.getAttributeValue('href') ?? node.getAttributeValue('xlink:href');
    if (raw == null) {
      return null;
    }
    final href = raw.toString().trim();
    return href.isEmpty ? null : href;
  }

  /// Checks if an href refers to an SVG file.
  /// Returns true for .svg file extension or image/svg+xml MIME type in data URIs.
  bool _isSvgImageHref(String href) {
    // Check file extension
    final lowerHref = href.toLowerCase();
    if (lowerHref.endsWith('.svg')) {
      return true;
    }

    // Check data URI MIME type
    if (href.startsWith('data:')) {
      final commaIndex = href.indexOf(',');
      if (commaIndex > 5) {
        final metadata = href.substring(5, commaIndex).toLowerCase();
        return metadata.startsWith('image/svg+xml');
      }
    }

    return false;
  }

  Future<void> _resolveImageByHref(String href, int generation) async {
    try {
      // Detect SVG-as-image references before attempting to decode
      if (_isSvgImageHref(href)) {
        _trace(
          category: 'image',
          level: SvgTraceLevel.warning,
          message: 'Recursive SVG rendering is not yet supported',
          data: <String, Object?>{'href': href},
        );
        return;
      }

      final bytes = await _loadImageBytes(href);
      if (bytes == null || bytes.isEmpty) {
        _trace(
          category: 'image',
          level: SvgTraceLevel.warning,
          message: 'Image source is not supported or failed to load',
          data: <String, Object?>{'href': href},
        );
        return;
      }

      final codec = await ui.instantiateImageCodec(bytes);
      try {
        final frame = await codec.getNextFrame();
        final image = frame.image;
        if (!mounted || generation != _imageLoadGeneration) {
          image.dispose();
          return;
        }

        // Guard against invalid image dimensions
        if (image.width <= 0 || image.height <= 0) {
          image.dispose();
          _trace(
            category: 'image',
            level: SvgTraceLevel.warning,
            message: 'Image has invalid dimensions',
            data: <String, Object?>{
              'href': href,
              'width': image.width,
              'height': image.height,
            },
          );
          return;
        }

        final previous = _imagesByHref[href];
        if (!identical(previous, image)) {
          previous?.dispose();
        }
        _imagesByHref[href] = image;

        _trace(
          category: 'image',
          message: 'Image decoded',
          data: <String, Object?>{
            'href': href,
            'width': image.width,
            'height': image.height,
          },
        );

        _markNeedsRepaint();
      } finally {
        codec.dispose();
      }
    } catch (error, stackTrace) {
      _trace(
        category: 'image',
        level: SvgTraceLevel.warning,
        message: 'Failed to decode image source',
        data: <String, Object?>{'href': href},
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      if (generation == _imageLoadGeneration) {
        _pendingImageHrefs.remove(href);
      }
    }
  }

  Future<Uint8List?> _loadImageBytes(String href) async {
    if (href.startsWith('data:')) {
      return _decodeDataUriBytes(href);
    }

    final uri = Uri.tryParse(href);
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      try {
        final data = await NetworkAssetBundle(uri).load(uri.toString());
        final bytes = data.buffer.asUint8List();
        // Guard against empty network response
        return bytes.isNotEmpty ? bytes : null;
      } catch (_) {
        // Network error - return null to trigger graceful fallback
        return null;
      }
    }

    try {
      final data = await rootBundle.load(href);
      final bytes = data.buffer.asUint8List();
      // Guard against empty asset
      return bytes.isNotEmpty ? bytes : null;
    } catch (_) {
      // Asset not found - return null to trigger graceful fallback
      return null;
    }
  }

  Uint8List? _decodeDataUriBytes(String href) {
    final commaIndex = href.indexOf(',');
    if (commaIndex <= 5) {
      return null;
    }

    final metadata = href.substring(5, commaIndex).toLowerCase();
    final payload = href.substring(commaIndex + 1);

    // Validate MIME type - only allow image types for security
    final mimeType = _extractMimeType(metadata);
    if (mimeType != null && !_allowedImageMimeTypes.contains(mimeType)) {
      _trace(
        category: 'image',
        level: SvgTraceLevel.warning,
        message: 'Rejected non-image MIME type in data URI',
        data: <String, Object?>{'mimeType': mimeType},
      );
      return null;
    }

    // Empty payload check
    if (payload.isEmpty) {
      return null;
    }

    try {
      if (metadata.contains(';base64')) {
        return Uint8List.fromList(base64.decode(payload));
      }
      final decoded = Uri.decodeComponent(payload);
      return Uint8List.fromList(decoded.codeUnits);
    } catch (_) {
      return null;
    }
  }

  /// Extracts the MIME type from data URI metadata.
  /// Returns null if no valid MIME type found.
  String? _extractMimeType(String metadata) {
    // Metadata format: "mime/type" or "mime/type;base64" or "mime/type;charset=utf-8"
    // Strip any parameters (;base64, ;charset=, etc.)
    final semicolonIndex = metadata.indexOf(';');
    final mimeType = semicolonIndex > 0
        ? metadata.substring(0, semicolonIndex).trim()
        : metadata.trim();

    // Validate it looks like a MIME type (contains /)
    if (mimeType.isEmpty || !mimeType.contains('/')) {
      return null;
    }

    return mimeType;
  }

  void _disposeResolvedImages() {
    for (final image in _imagesByHref.values) {
      image.dispose();
    }
    _imagesByHref.clear();
    _pendingImageHrefs.clear();
  }
}
