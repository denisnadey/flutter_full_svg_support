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
    final generation = _imageLoadGeneration;
    final sourceLightingRequests = _collectSourceLightingRequests();
    if (hrefs.isEmpty) {
      final displacementRequests = _collectDisplacementRequests();
      final precomputeCount =
          displacementRequests.length + sourceLightingRequests.length;
      if (precomputeCount > 0) {
        _trace(
          category: 'image',
          message: 'Image preload scheduled',
          data: <String, Object?>{'count': precomputeCount},
        );
      }
      if (sourceLightingRequests.isNotEmpty) {
        _trace(
          category: 'image',
          message: 'Lighting preload scheduled',
          data: <String, Object?>{'count': sourceLightingRequests.length},
        );
      }
      unawaited(() async {
        await _precomputeSourceLightingVariants(generation);
        await _precomputeDisplacementVariants(generation);
        if (mounted && generation == _imageLoadGeneration) {
          _markNeedsRepaint();
        }
      }());
      return;
    }

    _pendingImageHrefs
      ..clear()
      ..addAll(hrefs);

    final scheduledCount = hrefs.length + sourceLightingRequests.length;

    _trace(
      category: 'image',
      message: 'Image preload scheduled',
      data: <String, Object?>{'count': scheduledCount},
    );

    if (sourceLightingRequests.isNotEmpty) {
      _trace(
        category: 'image',
        message: 'Lighting preload scheduled',
        data: <String, Object?>{'count': sourceLightingRequests.length},
      );
      unawaited(() async {
        await _precomputeSourceLightingVariants(generation);
        if (mounted && generation == _imageLoadGeneration) {
          _markNeedsRepaint();
        }
      }());
    }

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

  List<_LightingImageRequest> _collectLightingRequestsForHref(String href) {
    final filters = _document.filters;
    if (filters == null) {
      return const <_LightingImageRequest>[];
    }

    final requests = <_LightingImageRequest>[];
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

          if (filterId != null) {
            final passes = filters.resolvePaintPasses(filterId);
            if (passes.length == 1) {
              final pass = passes.single;
              if (pass is SvgDiffuseLightingPaintPass) {
                final requestKey =
                    '$filterId|${targetWidth ?? 'auto'}x${targetHeight ?? 'auto'}|diffuse';
                if (seenRequestKeys.add(requestKey)) {
                  requests.add(
                    _LightingImageRequest.diffuse(
                      filterId: filterId,
                      diffusePass: pass,
                      targetWidth: targetWidth,
                      targetHeight: targetHeight,
                    ),
                  );
                }
              } else if (pass is SvgSpecularLightingPaintPass) {
                final requestKey =
                    '$filterId|${targetWidth ?? 'auto'}x${targetHeight ?? 'auto'}|specular';
                if (seenRequestKeys.add(requestKey)) {
                  requests.add(
                    _LightingImageRequest.specular(
                      filterId: filterId,
                      specularPass: pass,
                      targetWidth: targetWidth,
                      targetHeight: targetHeight,
                    ),
                  );
                }
              }
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

  List<_LightingImageRequest> _collectSourceLightingRequests() {
    final filters = _document.filters;
    if (filters == null) {
      return const <_LightingImageRequest>[];
    }

    final requests = <_LightingImageRequest>[];
    final seenRequestKeys = <String>{};

    void visit(SvgNode node) {
      final filterId = _extractFilterIdFromNode(node);
      if (filterId != null && node.tagName != 'image') {
        final passes = filters.resolvePaintPasses(filterId);
        for (final pass in passes) {
          if (pass is SvgDiffuseLightingPaintPass) {
            final requestKey = '$filterId|diffuse|${node.id ?? node.tagName}';
            if (seenRequestKeys.add(requestKey)) {
              requests.add(
                _LightingImageRequest.sourceDiffuse(
                  filterId: filterId,
                  sourceNode: node,
                  diffusePass: pass,
                ),
              );
            }
          } else if (pass is SvgSpecularLightingPaintPass) {
            final requestKey = '$filterId|specular|${node.id ?? node.tagName}';
            if (seenRequestKeys.add(requestKey)) {
              requests.add(
                _LightingImageRequest.sourceSpecular(
                  filterId: filterId,
                  sourceNode: node,
                  specularPass: pass,
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

  List<_DisplacementImageRequest> _collectDisplacementRequests() {
    final filters = _document.filters;
    if (filters == null) {
      return const <_DisplacementImageRequest>[];
    }

    final requests = <_DisplacementImageRequest>[];
    final seenRequestKeys = <String>{};

    void visit(SvgNode node) {
      final filterId = _extractFilterIdFromNode(node);
      if (filterId != null) {
        final targetWidth = _parsePositivePixelLength(
          node.getAttributeValue('width')?.toString(),
        );
        final targetHeight = _parsePositivePixelLength(
          node.getAttributeValue('height')?.toString(),
        );

        if (targetWidth != null && targetHeight != null) {
          final primitives = filters.getAllById(filterId);
          if (primitives.length == 1 &&
              primitives.single is SvgDisplacementMapFilter) {
            final primitive = primitives.single as SvgDisplacementMapFilter;
            final textureSource = _resolveDisplacementBuiltInInput(
              primitive.input,
              defaultToSourceGraphic: true,
            );
            final mapSource = _resolveDisplacementBuiltInInput(
              primitive.input2,
              defaultToSourceGraphic: false,
            );
            if (textureSource != null &&
                mapSource != null &&
                textureSource != _DisplacementInputSource.href &&
                mapSource != _DisplacementInputSource.href) {
              final requestKey =
                  '$filterId|${targetWidth}x${targetHeight}|${textureSource.name}|${mapSource.name}|${node.id ?? node.tagName}';
              if (seenRequestKeys.add(requestKey)) {
                requests.add(
                  _DisplacementImageRequest.sourceBased(
                    filterId: filterId,
                    targetWidth: targetWidth,
                    targetHeight: targetHeight,
                    sourceNode: node,
                    textureSource: textureSource,
                    mapSource: mapSource,
                    displacementFilter: primitive,
                  ),
                );
              }
            }
          }

          final passes = filters.resolvePaintPasses(filterId);
          if (passes.length == 1 &&
              passes.single is SvgDisplacementMapPaintPass) {
            final pass = passes.single as SvgDisplacementMapPaintPass;
            final textureHref = pass.textureHref?.trim();
            final mapHref = pass.mapHref?.trim();
            if (textureHref != null &&
                textureHref.isNotEmpty &&
                mapHref != null &&
                mapHref.isNotEmpty) {
              final requestKey =
                  '$filterId|${targetWidth}x${targetHeight}|$textureHref|$mapHref';
              if (seenRequestKeys.add(requestKey)) {
                requests.add(
                  _DisplacementImageRequest.hrefBased(
                    filterId: filterId,
                    targetWidth: targetWidth,
                    targetHeight: targetHeight,
                    textureHref: textureHref,
                    mapHref: mapHref,
                    displacementFilter: pass.displacementFilter,
                  ),
                );
              }
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

  _DisplacementInputSource? _resolveDisplacementBuiltInInput(
    String? rawInput, {
    required bool defaultToSourceGraphic,
  }) {
    final normalized = rawInput?.trim();
    if (normalized == null || normalized.isEmpty) {
      return defaultToSourceGraphic
          ? _DisplacementInputSource.sourceGraphic
          : null;
    }

    final lower = normalized.toLowerCase();
    if (lower == 'sourcegraphic') {
      return _DisplacementInputSource.sourceGraphic;
    }
    if (lower == 'sourcealpha') {
      return _DisplacementInputSource.sourceAlpha;
    }

    return _DisplacementInputSource.href;
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
    final paint = ui.Paint()..filterQuality = ui.FilterQuality.none;
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
        useLinearRgb: true,
      );

      var maxRgb = 0;
      var nonZeroRgb = 0;
      var maxAlpha = 0;
      var nonZeroAlpha = 0;
      for (int i = 0; i < convolvedPixels.length; i += 4) {
        final r = convolvedPixels[i];
        final g = convolvedPixels[i + 1];
        final b = convolvedPixels[i + 2];
        final a = convolvedPixels[i + 3];
        if (r > maxRgb) maxRgb = r;
        if (g > maxRgb) maxRgb = g;
        if (b > maxRgb) maxRgb = b;
        if (a > maxAlpha) maxAlpha = a;
        if (r != 0 || g != 0 || b != 0) {
          nonZeroRgb++;
        }
        if (a != 0) {
          nonZeroAlpha++;
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
          'hrefLength': href.length,
          'filterId': request.filterId,
          'preserveAlpha': request.convolveFilter.preserveAlpha,
          'targetWidth': inputWidth,
          'targetHeight': inputHeight,
          'maxRgb': maxRgb,
          'nonZeroRgbPixels': nonZeroRgb,
          'maxAlpha': maxAlpha,
          'nonZeroAlphaPixels': nonZeroAlpha,
          'width': convolvedImage.width,
          'height': convolvedImage.height,
        },
      );
    }
  }

  Future<void> _precomputeLightingVariantsForHref(
    String href,
    ui.Image image,
    int generation,
  ) async {
    final requests = _collectLightingRequestsForHref(href);
    if (requests.isEmpty) {
      return;
    }

    for (final request in requests) {
      ui.Image lightingInputImage = image;
      if (request.targetWidth != null &&
          request.targetHeight != null &&
          request.targetWidth! > 0 &&
          request.targetHeight! > 0 &&
          (request.targetWidth != image.width ||
              request.targetHeight != image.height)) {
        lightingInputImage = await _resampleImage(
          image,
          request.targetWidth!,
          request.targetHeight!,
        );
      }

      final inputByteData = await lightingInputImage.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      if (!mounted ||
          generation != _imageLoadGeneration ||
          inputByteData == null) {
        if (!identical(lightingInputImage, image)) {
          lightingInputImage.dispose();
        }
        return;
      }

      final inputWidth = lightingInputImage.width;
      final inputHeight = lightingInputImage.height;
      final inputPixels = inputByteData.buffer.asUint8List();

      final processor = request.createProcessor(
        objectBoundingBoxWidth: inputWidth.toDouble(),
        objectBoundingBoxHeight: inputHeight.toDouble(),
      );
      if (processor == null) {
        if (!identical(lightingInputImage, image)) {
          lightingInputImage.dispose();
        }
        continue;
      }

      final outputPixels = switch (request.kind) {
        _LightingVariantKind.diffuse => processor.processDiffuse(
          inputPixels,
          inputWidth,
          inputHeight,
          request.diffusePass!.diffuseConstant,
        ),
        _LightingVariantKind.specular => processor.processSpecular(
          inputPixels,
          inputWidth,
          inputHeight,
          request.specularPass!.specularConstant,
          request.specularPass!.specularExponent,
        ),
      };

      final outputImage = await _decodeRgbaImage(
        outputPixels,
        inputWidth,
        inputHeight,
      );
      if (!identical(lightingInputImage, image)) {
        lightingInputImage.dispose();
      }
      if (outputImage == null) {
        continue;
      }
      if (!mounted || generation != _imageLoadGeneration) {
        outputImage.dispose();
        return;
      }

      final key =
          '$href|${request.filterId}|${inputWidth}x${inputHeight}|${request.kindName}';
      final previous = _lightingImagesByFilterKey[key];
      if (!identical(previous, outputImage)) {
        previous?.dispose();
      }
      _lightingImagesByFilterKey[key] = outputImage;

      _trace(
        category: 'image',
        message: 'Lighting image variant decoded',
        data: <String, Object?>{
          'filterId': request.filterId,
          'kind': request.kindName,
          'targetWidth': inputWidth,
          'targetHeight': inputHeight,
          'width': outputImage.width,
          'height': outputImage.height,
        },
      );
    }
  }

  Future<void> _precomputeSourceLightingVariants(int generation) async {
    final requests = _collectSourceLightingRequests();
    if (requests.isEmpty) {
      return;
    }

    for (final request in requests) {
      final sourceNode = request.sourceNode;
      if (sourceNode == null) {
        continue;
      }
      final rawNodeTransform = sourceNode
          .getAttributeValue('transform')
          ?.toString();
      final hasNodeLocalTransform =
          rawNodeTransform != null && rawNodeTransform.trim().isNotEmpty;

      final boundsPainter = AnimatedSvgPainter(
        document: _document,
        backgroundColor: widget.backgroundColor,
        imagesByHref: _imagesByHref,
        convolvedImagesByFilterKey: _convolvedImagesByFilterKey,
        lightingImagesByFilterKey: _lightingImagesByFilterKey,
        displacementImagesByFilterKey: const <String, ui.Image>{},
        animationTime: _timeline == null
            ? null
            : _timeline!.currentTime.inMicroseconds /
                  Duration.microsecondsPerSecond,
        hasAnimations: _hasAnimations,
      );
      final nodeBounds = _measureNodeBoundsInDocumentSpace(
        boundsPainter,
        sourceNode,
      );
      if (nodeBounds.width <= 0 || nodeBounds.height <= 0) {
        continue;
      }

      final captureRect =
          _document.filters
              ?.getFilterRegion(request.filterId)
              .computeRect(nodeBounds) ??
          nodeBounds;
      final captureWidth = captureRect.width.round();
      final captureHeight = captureRect.height.round();
      if (captureWidth <= 0 || captureHeight <= 0) {
        continue;
      }

      final sourceImage = await _rasterizeNodeSourceGraphic(
        sourceNode,
        captureWidth,
        captureHeight,
        captureRect: captureRect,
      );
      if (sourceImage == null) {
        continue;
      }

      final inputByteData = await sourceImage.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      if (!mounted || generation != _imageLoadGeneration) {
        sourceImage.dispose();
        return;
      }
      if (inputByteData == null) {
        sourceImage.dispose();
        continue;
      }

      var inputPixels = inputByteData.buffer.asUint8List();
      if (request.usesSourceAlphaInput) {
        inputPixels = _toSourceAlphaPixels(inputPixels);
      }

      final processor = request.createProcessor(
        objectBoundingBoxWidth: nodeBounds.width,
        objectBoundingBoxHeight: nodeBounds.height,
        objectBoundingBoxX: hasNodeLocalTransform ? null : nodeBounds.left,
        objectBoundingBoxY: hasNodeLocalTransform ? null : nodeBounds.top,
        surfaceOriginX: hasNodeLocalTransform ? 0.0 : captureRect.left,
        surfaceOriginY: hasNodeLocalTransform ? 0.0 : captureRect.top,
      );
      if (processor == null) {
        sourceImage.dispose();
        continue;
      }

      final outputPixels = switch (request.kind) {
        _LightingVariantKind.diffuse => processor.processDiffuse(
          inputPixels,
          sourceImage.width,
          sourceImage.height,
          request.diffusePass!.diffuseConstant,
        ),
        _LightingVariantKind.specular => processor.processSpecular(
          inputPixels,
          sourceImage.width,
          sourceImage.height,
          request.specularPass!.specularConstant,
          request.specularPass!.specularExponent,
        ),
      };

      final outputImage = await _decodeRgbaImage(
        outputPixels,
        sourceImage.width,
        sourceImage.height,
      );
      sourceImage.dispose();
      if (outputImage == null) {
        continue;
      }
      if (!mounted || generation != _imageLoadGeneration) {
        outputImage.dispose();
        return;
      }

      final key =
          '${request.filterId}|${outputImage.width}x${outputImage.height}|${request.kindName}';
      final previous = _lightingImagesByFilterKey[key];
      if (!identical(previous, outputImage)) {
        previous?.dispose();
      }
      _lightingImagesByFilterKey[key] = outputImage;

      _trace(
        category: 'image',
        message: 'Lighting image variant decoded',
        data: <String, Object?>{
          'filterId': request.filterId,
          'kind': request.kindName,
          'targetWidth': outputImage.width,
          'targetHeight': outputImage.height,
          'sourceBased': true,
        },
      );
      _trace(
        category: 'image',
        message: 'Image decoded',
        data: <String, Object?>{
          'href': key,
          'width': outputImage.width,
          'height': outputImage.height,
          'sourceBased': true,
        },
      );
    }
  }

  Future<void> _precomputeDisplacementVariants(int generation) async {
    final requests = _collectDisplacementRequests();
    if (requests.isEmpty) {
      return;
    }

    for (final request in requests) {
      ui.Image? textureImage;
      ui.Image? mapImage;
      ui.Image? sourceImage;

      if (request.isHrefBased) {
        textureImage = _imagesByHref[request.textureHref!];
        mapImage = _imagesByHref[request.mapHref!];
        if (textureImage == null || mapImage == null) {
          continue;
        }
      } else {
        final sourceNode = request.sourceNode;
        if (sourceNode == null) {
          continue;
        }

        final boundsPainter = AnimatedSvgPainter(
          document: _document,
          backgroundColor: widget.backgroundColor,
          imagesByHref: _imagesByHref,
          convolvedImagesByFilterKey: _convolvedImagesByFilterKey,
          lightingImagesByFilterKey: _lightingImagesByFilterKey,
          displacementImagesByFilterKey: const <String, ui.Image>{},
          animationTime: _timeline == null
              ? null
              : _timeline!.currentTime.inMicroseconds /
                    Duration.microsecondsPerSecond,
          hasAnimations: _hasAnimations,
        );
        final nodeBounds = _measureNodeBoundsInDocumentSpace(
          boundsPainter,
          sourceNode,
        );
        if (nodeBounds.width <= 0 || nodeBounds.height <= 0) {
          continue;
        }
        final captureRect =
            _document.filters
                ?.getFilterRegion(request.filterId)
                .computeRect(nodeBounds) ??
            nodeBounds;
        final captureWidth = captureRect.width.round();
        final captureHeight = captureRect.height.round();
        if (captureWidth <= 0 || captureHeight <= 0) {
          continue;
        }

        sourceImage = await _rasterizeNodeSourceGraphic(
          sourceNode,
          captureWidth,
          captureHeight,
          captureRect: captureRect,
        );
        if (sourceImage == null) {
          continue;
        }
        textureImage = sourceImage;
        mapImage = sourceImage;
      }

      final targetWidth = request.isHrefBased
          ? request.targetWidth
          : textureImage.width;
      final targetHeight = request.isHrefBased
          ? request.targetHeight
          : textureImage.height;

      var textureInput = textureImage;
      if (textureImage.width != targetWidth ||
          textureImage.height != targetHeight) {
        textureInput = await _resampleImage(
          textureImage,
          targetWidth,
          targetHeight,
        );
      }

      var mapInput = mapImage;
      if (mapImage.width != targetWidth || mapImage.height != targetHeight) {
        mapInput = await _resampleImage(mapImage, targetWidth, targetHeight);
      }

      final textureByteData = await textureInput.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      final mapByteData = await mapInput.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );

      if (!mounted ||
          generation != _imageLoadGeneration ||
          textureByteData == null ||
          mapByteData == null) {
        if (!identical(textureInput, textureImage)) {
          textureInput.dispose();
        }
        if (!identical(mapInput, mapImage)) {
          mapInput.dispose();
        }
        sourceImage?.dispose();
        return;
      }

      var texturePixels = textureByteData.buffer.asUint8List();
      var mapPixels = mapByteData.buffer.asUint8List();

      if (request.textureSource == _DisplacementInputSource.sourceAlpha) {
        texturePixels = _toSourceAlphaPixels(texturePixels);
      }
      if (request.mapSource == _DisplacementInputSource.sourceAlpha) {
        mapPixels = _toSourceAlphaPixels(mapPixels);
      }

      final displacedPixels = DisplacementMapProcessor.applyDisplacement(
        inputPixels: texturePixels,
        mapPixels: mapPixels,
        width: targetWidth,
        height: targetHeight,
        scale: request.displacementFilter.scale,
        xChannel: request.displacementFilter.xChannelSelector,
        yChannel: request.displacementFilter.yChannelSelector,
        edgeMode: request.displacementFilter.edgeMode,
      );

      final displacedImage = await _decodeRgbaImage(
        displacedPixels,
        targetWidth,
        targetHeight,
      );

      if (!identical(textureInput, textureImage)) {
        textureInput.dispose();
      }
      if (!identical(mapInput, mapImage)) {
        mapInput.dispose();
      }
      sourceImage?.dispose();

      if (displacedImage == null) {
        continue;
      }
      if (!mounted || generation != _imageLoadGeneration) {
        displacedImage.dispose();
        return;
      }

      final key =
          '${request.filterId}|${displacedImage.width}x${displacedImage.height}';
      final previous = _displacementImagesByFilterKey[key];
      if (!identical(previous, displacedImage)) {
        previous?.dispose();
      }
      _displacementImagesByFilterKey[key] = displacedImage;

      if (!request.isHrefBased) {
        _trace(
          category: 'image',
          message: 'Image decoded',
          data: <String, Object?>{
            'href': key,
            'width': displacedImage.width,
            'height': displacedImage.height,
          },
        );
      }

      _trace(
        category: 'image',
        message: 'Displacement image variant decoded',
        data: <String, Object?>{
          'filterId': request.filterId,
          'targetWidth': targetWidth,
          'targetHeight': targetHeight,
          'textureSource': request.textureSource.name,
          'mapSource': request.mapSource.name,
          'textureHrefLength': request.textureHref?.length,
          'mapHrefLength': request.mapHref?.length,
          'width': displacedImage.width,
          'height': displacedImage.height,
        },
      );
    }
  }

  Uint8List _toSourceAlphaPixels(Uint8List rgbaPixels) {
    final result = Uint8List(rgbaPixels.length);
    for (int i = 0; i + 3 < rgbaPixels.length; i += 4) {
      final a = rgbaPixels[i + 3];
      result[i] = a;
      result[i + 1] = a;
      result[i + 2] = a;
      result[i + 3] = a;
    }
    return result;
  }

  Future<ui.Image?> _rasterizeNodeSourceGraphic(
    SvgNode node,
    int targetWidth,
    int targetHeight, {
    ui.Rect? captureRect,
  }) async {
    if (targetWidth <= 0 || targetHeight <= 0) {
      return null;
    }

    final painter = AnimatedSvgPainter(
      document: _document,
      backgroundColor: widget.backgroundColor,
      imagesByHref: _imagesByHref,
      convolvedImagesByFilterKey: _convolvedImagesByFilterKey,
      lightingImagesByFilterKey: _lightingImagesByFilterKey,
      displacementImagesByFilterKey: const <String, ui.Image>{},
      animationTime: _timeline == null
          ? null
          : _timeline!.currentTime.inMicroseconds /
                Duration.microsecondsPerSecond,
      hasAnimations: _hasAnimations,
    );

    final nodeBounds = painter.measureNodeBounds(node);
    if (nodeBounds.width <= 0 || nodeBounds.height <= 0) {
      return null;
    }
    final effectiveCaptureRect = captureRect ?? nodeBounds;

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);

    canvas.translate(-effectiveCaptureRect.left, -effectiveCaptureRect.top);
    painter.paintNodeForRaster(canvas, node, ignoreFilter: true);

    final picture = recorder.endRecording();
    try {
      return await picture.toImage(targetWidth, targetHeight);
    } catch (_) {
      return null;
    } finally {
      picture.dispose();
    }
  }

  ui.Rect _measureNodeBoundsInDocumentSpace(
    AnimatedSvgPainter painter,
    SvgNode node,
  ) {
    final localBounds = painter.measureNodeBounds(node);
    if (localBounds.width <= 0 || localBounds.height <= 0) {
      return localBounds;
    }

    final matrix = _identityAffineMatrix();
    _appendNodeTransformToAffine(matrix, node);

    return _transformRectWithAffine(localBounds, matrix);
  }

  List<double> _identityAffineMatrix() => <double>[1, 0, 0, 1, 0, 0];

  void _appendNodeTransformToAffine(List<double> matrix, SvgNode node) {
    final raw = node.getAttributeValue('transform')?.toString();
    if (raw == null || raw.trim().isEmpty) {
      return;
    }

    final transforms = SvgTransform.parse(raw);
    for (final transform in transforms) {
      switch (transform.type) {
        case SvgTransformType.translate:
          final tx = transform.values.isNotEmpty ? transform.values[0] : 0.0;
          final ty = transform.values.length > 1 ? transform.values[1] : 0.0;
          _multiplyAffine(matrix, <double>[1, 0, 0, 1, tx, ty]);
          break;
        case SvgTransformType.scale:
          final sx = transform.values.isNotEmpty ? transform.values[0] : 1.0;
          final sy = transform.values.length > 1 ? transform.values[1] : sx;
          _multiplyAffine(matrix, <double>[sx, 0, 0, sy, 0, 0]);
          break;
        case SvgTransformType.rotate:
          final angle = transform.values.isNotEmpty ? transform.values[0] : 0.0;
          final radians = angle * math.pi / 180.0;
          final cosA = math.cos(radians);
          final sinA = math.sin(radians);
          if (transform.values.length >= 3) {
            final cx = transform.values[1];
            final cy = transform.values[2];
            _multiplyAffine(matrix, <double>[1, 0, 0, 1, cx, cy]);
            _multiplyAffine(matrix, <double>[cosA, sinA, -sinA, cosA, 0, 0]);
            _multiplyAffine(matrix, <double>[1, 0, 0, 1, -cx, -cy]);
          } else {
            _multiplyAffine(matrix, <double>[cosA, sinA, -sinA, cosA, 0, 0]);
          }
          break;
        case SvgTransformType.skewX:
          final angle = transform.values.isNotEmpty ? transform.values[0] : 0.0;
          _multiplyAffine(matrix, <double>[
            1,
            0,
            math.tan(angle * math.pi / 180.0),
            1,
            0,
            0,
          ]);
          break;
        case SvgTransformType.skewY:
          final angle = transform.values.isNotEmpty ? transform.values[0] : 0.0;
          _multiplyAffine(matrix, <double>[
            1,
            math.tan(angle * math.pi / 180.0),
            0,
            1,
            0,
            0,
          ]);
          break;
        case SvgTransformType.matrix:
          if (transform.values.length >= 6) {
            _multiplyAffine(matrix, <double>[
              transform.values[0],
              transform.values[1],
              transform.values[2],
              transform.values[3],
              transform.values[4],
              transform.values[5],
            ]);
          }
          break;
        default:
          break;
      }
    }
  }

  void _multiplyAffine(List<double> current, List<double> next) {
    final a = current[0] * next[0] + current[2] * next[1];
    final b = current[1] * next[0] + current[3] * next[1];
    final c = current[0] * next[2] + current[2] * next[3];
    final d = current[1] * next[2] + current[3] * next[3];
    final e = current[0] * next[4] + current[2] * next[5] + current[4];
    final f = current[1] * next[4] + current[3] * next[5] + current[5];
    current[0] = a;
    current[1] = b;
    current[2] = c;
    current[3] = d;
    current[4] = e;
    current[5] = f;
  }

  ui.Rect _transformRectWithAffine(ui.Rect rect, List<double> matrix) {
    final p1 = _transformPointWithAffine(rect.left, rect.top, matrix);
    final p2 = _transformPointWithAffine(rect.right, rect.top, matrix);
    final p3 = _transformPointWithAffine(rect.left, rect.bottom, matrix);
    final p4 = _transformPointWithAffine(rect.right, rect.bottom, matrix);

    final minX = math.min(math.min(p1.dx, p2.dx), math.min(p3.dx, p4.dx));
    final maxX = math.max(math.max(p1.dx, p2.dx), math.max(p3.dx, p4.dx));
    final minY = math.min(math.min(p1.dy, p2.dy), math.min(p3.dy, p4.dy));
    final maxY = math.max(math.max(p1.dy, p2.dy), math.max(p3.dy, p4.dy));

    return ui.Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  ui.Offset _transformPointWithAffine(double x, double y, List<double> matrix) {
    return ui.Offset(
      matrix[0] * x + matrix[2] * y + matrix[4],
      matrix[1] * x + matrix[3] * y + matrix[5],
    );
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

      ui.Image? image;
      if (_isSvgImageHref(href)) {
        image = await _decodeSvgImageAsRaster(bytes);
      } else {
        final codec = await ui.instantiateImageCodec(bytes);
        try {
          final frame = await codec.getNextFrame();
          image = frame.image;
        } finally {
          codec.dispose();
        }
      }

      if (image == null) {
        _trace(
          category: 'image',
          level: SvgTraceLevel.warning,
          message: 'Image source is not supported or failed to load',
          data: <String, Object?>{'href': href},
        );
        return;
      }

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
      await _precomputeLightingVariantsForHref(href, image, generation);
      await _precomputeDisplacementVariants(generation);

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

  Future<ui.Image?> _decodeSvgImageAsRaster(Uint8List bytes) async {
    String svgSource;
    try {
      svgSource = utf8.decode(bytes, allowMalformed: true);
    } catch (_) {
      return null;
    }

    final nestedDocument = SvgParser.parse(svgSource);
    if (nestedDocument.root.tagName != 'svg') {
      return null;
    }

    final rasterSize = _resolveNestedSvgRasterSize(nestedDocument.root);
    final targetWidth = rasterSize.width.round().clamp(1, 4096);
    final targetHeight = rasterSize.height.round().clamp(1, 4096);

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final painter = AnimatedSvgPainter(
      document: nestedDocument,
      backgroundColor: null,
      imagesByHref: _imagesByHref,
      convolvedImagesByFilterKey: const <String, ui.Image>{},
      lightingImagesByFilterKey: const <String, ui.Image>{},
      displacementImagesByFilterKey: const <String, ui.Image>{},
      animationTime: null,
      hasAnimations: false,
    );
    painter.paint(
      canvas,
      ui.Size(targetWidth.toDouble(), targetHeight.toDouble()),
    );

    final picture = recorder.endRecording();
    try {
      return await picture.toImage(targetWidth, targetHeight);
    } catch (_) {
      return null;
    } finally {
      picture.dispose();
    }
  }

  ui.Size _resolveNestedSvgRasterSize(SvgNode rootSvgNode) {
    final widthAttr = rootSvgNode.getAttributeValue('width')?.toString();
    final heightAttr = rootSvgNode.getAttributeValue('height')?.toString();
    final parsedWidth = _parsePositivePixelLength(widthAttr)?.toDouble();
    final parsedHeight = _parsePositivePixelLength(heightAttr)?.toDouble();
    final viewBoxAttr = rootSvgNode.getAttributeValue('viewBox')?.toString();
    final viewBox = viewBoxAttr == null ? null : _parseViewBoxRect(viewBoxAttr);

    final width = (parsedWidth ?? viewBox?.width ?? 300.0)
        .clamp(1.0, 4096.0)
        .toDouble();
    final height = (parsedHeight ?? viewBox?.height ?? 150.0)
        .clamp(1.0, 4096.0)
        .toDouble();

    return ui.Size(width, height);
  }

  Future<Uint8List?> _loadImageBytes(String href) async {
    final imageLoader = widget.imageLoader;
    if (imageLoader != null) {
      try {
        final customBytes = await imageLoader(href);
        if (customBytes != null && customBytes.isNotEmpty) {
          return customBytes;
        }
      } catch (error, stackTrace) {
        _trace(
          category: 'image',
          level: SvgTraceLevel.warning,
          message: 'Custom image loader failed',
          data: <String, Object?>{'href': href},
          error: error,
          stackTrace: stackTrace,
        );
      }
    }

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

    for (final image in _lightingImagesByFilterKey.values) {
      image.dispose();
    }
    _lightingImagesByFilterKey.clear();

    for (final image in _displacementImagesByFilterKey.values) {
      image.dispose();
    }
    _displacementImagesByFilterKey.clear();

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

enum _LightingVariantKind { diffuse, specular }

class _LightingImageRequest {
  const _LightingImageRequest.diffuse({
    required this.filterId,
    required SvgDiffuseLightingPaintPass diffusePass,
    this.targetWidth,
    this.targetHeight,
  }) : kind = _LightingVariantKind.diffuse,
       diffusePass = diffusePass,
       specularPass = null,
       sourceNode = null;

  const _LightingImageRequest.specular({
    required this.filterId,
    required SvgSpecularLightingPaintPass specularPass,
    this.targetWidth,
    this.targetHeight,
  }) : kind = _LightingVariantKind.specular,
       diffusePass = null,
       specularPass = specularPass,
       sourceNode = null;

  const _LightingImageRequest.sourceDiffuse({
    required this.filterId,
    required this.sourceNode,
    required SvgDiffuseLightingPaintPass diffusePass,
  }) : kind = _LightingVariantKind.diffuse,
       diffusePass = diffusePass,
       specularPass = null,
       targetWidth = null,
       targetHeight = null;

  const _LightingImageRequest.sourceSpecular({
    required this.filterId,
    required this.sourceNode,
    required SvgSpecularLightingPaintPass specularPass,
  }) : kind = _LightingVariantKind.specular,
       diffusePass = null,
       specularPass = specularPass,
       targetWidth = null,
       targetHeight = null;

  final String filterId;
  final _LightingVariantKind kind;
  final SvgDiffuseLightingPaintPass? diffusePass;
  final SvgSpecularLightingPaintPass? specularPass;
  final int? targetWidth;
  final int? targetHeight;
  final SvgNode? sourceNode;

  String get kindName =>
      kind == _LightingVariantKind.diffuse ? 'diffuse' : 'specular';

  bool get usesSourceAlphaInput {
    final raw = switch (kind) {
      _LightingVariantKind.diffuse => diffusePass?.lightingFilter.input,
      _LightingVariantKind.specular => specularPass?.lightingFilter.input,
    };
    return raw?.trim().toLowerCase() == 'sourcealpha';
  }

  LightingProcessor? createProcessor({
    double? objectBoundingBoxWidth,
    double? objectBoundingBoxHeight,
    double? objectBoundingBoxX,
    double? objectBoundingBoxY,
    double surfaceOriginX = 0.0,
    double surfaceOriginY = 0.0,
  }) {
    if (kind == _LightingVariantKind.diffuse) {
      return diffusePass?.createProcessor(
        objectBoundingBoxWidth: objectBoundingBoxWidth,
        objectBoundingBoxHeight: objectBoundingBoxHeight,
        objectBoundingBoxX: objectBoundingBoxX,
        objectBoundingBoxY: objectBoundingBoxY,
        surfaceOriginX: surfaceOriginX,
        surfaceOriginY: surfaceOriginY,
      );
    }
    final base = specularPass?.createProcessor(
      objectBoundingBoxWidth: objectBoundingBoxWidth,
      objectBoundingBoxHeight: objectBoundingBoxHeight,
      objectBoundingBoxX: objectBoundingBoxX,
      objectBoundingBoxY: objectBoundingBoxY,
      surfaceOriginX: surfaceOriginX,
      surfaceOriginY: surfaceOriginY,
    );
    return base;
  }
}

class _DisplacementImageRequest {
  const _DisplacementImageRequest.hrefBased({
    required this.filterId,
    required this.targetWidth,
    required this.targetHeight,
    required this.textureHref,
    required this.mapHref,
    required this.displacementFilter,
  }) : sourceNode = null,
       textureSource = _DisplacementInputSource.href,
       mapSource = _DisplacementInputSource.href;

  const _DisplacementImageRequest.sourceBased({
    required this.filterId,
    required this.targetWidth,
    required this.targetHeight,
    required this.sourceNode,
    required this.textureSource,
    required this.mapSource,
    required this.displacementFilter,
  }) : textureHref = null,
       mapHref = null;

  final String filterId;
  final int targetWidth;
  final int targetHeight;
  final String? textureHref;
  final String? mapHref;
  final SvgNode? sourceNode;
  final _DisplacementInputSource textureSource;
  final _DisplacementInputSource mapSource;
  final SvgDisplacementMapFilter displacementFilter;

  bool get isHrefBased =>
      textureSource == _DisplacementInputSource.href &&
      mapSource == _DisplacementInputSource.href;
}

enum _DisplacementInputSource { href, sourceGraphic, sourceAlpha }
