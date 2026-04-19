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
    _collectFeImageHrefs(hrefs);
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

  void _collectFeImageHrefs(Set<String> hrefs) {
    final filters = _document.filters;
    if (filters == null) {
      return;
    }
    for (final primitive in filters.all) {
      if ('${primitive.runtimeType}' != 'SvgFeImageFilter') {
        continue;
      }
      final href = (primitive as dynamic).href?.toString().trim();
      if (href == null || href.isEmpty || href.startsWith('#')) {
        continue;
      }
      hrefs.add(href);
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

  String? _extractFilterIdFromNode(SvgNode node) {
    final rawFilter = node.getAttributeValue('filter')?.toString().trim();
    if (rawFilter == null || rawFilter.isEmpty) {
      return null;
    }

    final match = RegExp(r'url\(([^)]+)\)').firstMatch(rawFilter);
    if (match == null) {
      return null;
    }

    var ref = match.group(1)?.trim();
    if (ref == null || ref.isEmpty) {
      return null;
    }

    if ((ref.startsWith('"') && ref.endsWith('"')) ||
        (ref.startsWith("'") && ref.endsWith("'"))) {
      ref = ref.substring(1, ref.length - 1).trim();
    }
    if (ref.startsWith('#')) {
      ref = ref.substring(1);
    }

    return ref.isEmpty ? null : ref;
  }

  List<_ConvolveImageRequest> _collectConvolveRequestsForHref(String href) {
    final filters = _document.filters;
    if (filters == null) {
      return const <_ConvolveImageRequest>[];
    }

    final requests = <_ConvolveImageRequest>[];
    final seenRequestKeys = <String>{};

    void visit(SvgNode node) {
      if (node.tagName == 'image') {
        final imageHref = _extractImageHref(node);
        if (imageHref == href) {
          final filterId = _extractFilterIdFromNode(node);
          final targetWidth = _parsePositivePixelLength(
            node.getAttributeValue('width')?.toString(),
          );
          final targetHeight = _parsePositivePixelLength(
            node.getAttributeValue('height')?.toString(),
          );
          final requestKey =
              '$filterId|${targetWidth ?? 'auto'}x${targetHeight ?? 'auto'}';

          if (filterId != null && seenRequestKeys.add(requestKey)) {
            final passes = filters.resolvePaintPasses(filterId);
            if (passes.length == 1 &&
                passes.single is SvgConvolveMatrixPaintPass) {
              final pass = passes.single as SvgConvolveMatrixPaintPass;
              requests.add(
                _ConvolveImageRequest(
                  filterId: filterId,
                  convolveFilter: pass.convolveFilter,
                  targetWidth: targetWidth,
                  targetHeight: targetHeight,
                ),
              );
            }
          }
        }
      }

      for (final child in node.children) {
        visit(child);
      }
    }

    visit(_document.root);
    return requests;
  }

  int? _parsePositivePixelLength(String? raw) {
    if (raw == null) {
      return null;
    }
    final normalized = raw.trim();
    if (normalized.isEmpty || normalized.endsWith('%')) {
      return null;
    }

    final numeric = normalized.replaceAll(RegExp(r'[a-zA-Z]+$'), '');
    final value = double.tryParse(numeric);
    if (value == null || value <= 0) {
      return null;
    }
    return value.round();
  }

  Future<ui.Image> _resampleImage(ui.Image image, int width, int height) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final paint = ui.Paint()..filterQuality = ui.FilterQuality.medium;
    canvas.drawImageRect(
      image,
      ui.Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      paint,
    );
    final picture = recorder.endRecording();
    return picture.toImage(width, height);
  }

  Future<ui.Image?> _decodeRgbaImage(
    Uint8List rgbaPixels,
    int width,
    int height,
  ) {
    final completer = Completer<ui.Image?>();
    try {
      ui.decodeImageFromPixels(
        rgbaPixels,
        width,
        height,
        ui.PixelFormat.rgba8888,
        (ui.Image image) {
          completer.complete(image);
        },
        rowBytes: width * 4,
      );
    } catch (_) {
      completer.complete(null);
    }
    return completer.future;
  }

  Future<void> _precomputeConvolveVariantsForHref(
    String href,
    ui.Image image,
    int generation,
  ) async {
    final requests = _collectConvolveRequestsForHref(href);
    if (requests.isEmpty) {
      return;
    }

    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (!mounted || generation != _imageLoadGeneration || byteData == null) {
      return;
    }

    final width = image.width;
    final height = image.height;

    for (final request in requests) {
      ui.Image convolutionInputImage = image;
      if (request.targetWidth != null &&
          request.targetHeight != null &&
          request.targetWidth! > 0 &&
          request.targetHeight! > 0 &&
          (request.targetWidth != width || request.targetHeight != height)) {
        convolutionInputImage = await _resampleImage(
          image,
          request.targetWidth!,
          request.targetHeight!,
        );
      }

      final inputByteData = await convolutionInputImage.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      if (!mounted ||
          generation != _imageLoadGeneration ||
          inputByteData == null) {
        if (!identical(convolutionInputImage, image)) {
          convolutionInputImage.dispose();
        }
        return;
      }

      final inputWidth = convolutionInputImage.width;
      final inputHeight = convolutionInputImage.height;
      final inputPixels = inputByteData.buffer.asUint8List();

      final convolvedPixels = ConvolveMatrixProcessor.applyConvolution(
        pixels: inputPixels,
        width: inputWidth,
        height: inputHeight,
        kernel: request.convolveFilter.kernelMatrix,
        orderX: request.convolveFilter.orderX,
        orderY: request.convolveFilter.orderY,
        targetX: request.convolveFilter.targetX,
        targetY: request.convolveFilter.targetY,
        divisor: request.convolveFilter.divisor,
        bias: request.convolveFilter.bias,
        edgeMode: request.convolveFilter.edgeMode,
        preserveAlpha: request.convolveFilter.preserveAlpha,
        kernelUnitLengthX: request.convolveFilter.kernelUnitLengthX,
        kernelUnitLengthY: request.convolveFilter.kernelUnitLengthY,
      );

      var maxRgb = 0;
      var nonZeroRgb = 0;
      for (int i = 0; i < convolvedPixels.length; i += 4) {
        final r = convolvedPixels[i];
        final g = convolvedPixels[i + 1];
        final b = convolvedPixels[i + 2];
        if (r > maxRgb) maxRgb = r;
        if (g > maxRgb) maxRgb = g;
        if (b > maxRgb) maxRgb = b;
        if (r != 0 || g != 0 || b != 0) {
          nonZeroRgb++;
        }
      }

      final convolvedImage = await _decodeRgbaImage(
        convolvedPixels,
        inputWidth,
        inputHeight,
      );
      if (!identical(convolutionInputImage, image)) {
        convolutionInputImage.dispose();
      }
      if (convolvedImage == null) {
        continue;
      }
      if (!mounted || generation != _imageLoadGeneration) {
        convolvedImage.dispose();
        return;
      }

      final key = '$href|${request.filterId}|${inputWidth}x${inputHeight}';
      final previous = _convolvedImagesByFilterKey[key];
      if (!identical(previous, convolvedImage)) {
        previous?.dispose();
      }
      _convolvedImagesByFilterKey[key] = convolvedImage;

      _trace(
        category: 'image',
        message: 'Convolved image variant decoded',
        data: <String, Object?>{
          'href': href,
          'filterId': request.filterId,
          'targetWidth': inputWidth,
          'targetHeight': inputHeight,
          'maxRgb': maxRgb,
          'nonZeroRgbPixels': nonZeroRgb,
          'width': convolvedImage.width,
          'height': convolvedImage.height,
        },
      );
    }
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

        await _precomputeConvolveVariantsForHref(href, image, generation);

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

    for (final image in _convolvedImagesByFilterKey.values) {
      image.dispose();
    }
    _convolvedImagesByFilterKey.clear();

    _pendingImageHrefs.clear();
  }
}

class _ConvolveImageRequest {
  const _ConvolveImageRequest({
    required this.filterId,
    required this.convolveFilter,
    this.targetWidth,
    this.targetHeight,
  });

  final String filterId;
  final SvgConvolveMatrixFilter convolveFilter;
  final int? targetWidth;
  final int? targetHeight;
}
