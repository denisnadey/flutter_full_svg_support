part of 'animated_svg_picture.dart';

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

  Future<void> _resolveImageByHref(String href, int generation) async {
    try {
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
      final data = await NetworkAssetBundle(uri).load(uri.toString());
      return data.buffer.asUint8List();
    }

    final data = await rootBundle.load(href);
    return data.buffer.asUint8List();
  }

  Uint8List? _decodeDataUriBytes(String href) {
    final commaIndex = href.indexOf(',');
    if (commaIndex <= 5) {
      return null;
    }

    final metadata = href.substring(5, commaIndex).toLowerCase();
    final payload = href.substring(commaIndex + 1);

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

  void _disposeResolvedImages() {
    for (final image in _imagesByHref.values) {
      image.dispose();
    }
    _imagesByHref.clear();
    _pendingImageHrefs.clear();
  }
}
