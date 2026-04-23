// Copyright 2024 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Image comparison utility for golden testing.
///
/// This library provides pixel-by-pixel comparison of PNG images
/// for comparing Flutter-rendered SVGs against browser golden references.
library image_compare;

import 'dart:typed_data';
import 'dart:ui' as ui;

const int _kNearTransparentAlpha = 8;

/// Result of comparing two images pixel-by-pixel.
class ImageCompareResult {
  /// Creates an image comparison result.
  const ImageCompareResult({
    required this.similarity,
    required this.totalPixels,
    required this.differentPixels,
    required this.matchingPixels,
    this.diffImage,
    this.message,
    this.imageAWidth,
    this.imageAHeight,
    this.imageBWidth,
    this.imageBHeight,
  });

  /// Creates a failed result with an error message.
  const ImageCompareResult.failed(String errorMessage)
    : similarity = 0.0,
      totalPixels = 0,
      differentPixels = 0,
      matchingPixels = 0,
      diffImage = null,
      message = errorMessage,
      imageAWidth = null,
      imageAHeight = null,
      imageBWidth = null,
      imageBHeight = null;

  /// Similarity ratio from 0.0 to 1.0 (1.0 = identical).
  final double similarity;

  /// Total number of pixels compared.
  final int totalPixels;

  /// Number of pixels that differ.
  final int differentPixels;

  /// Number of pixels that match.
  final int matchingPixels;

  /// PNG bytes of diff visualization (if generateDiff was true).
  /// - Matching pixels: semi-transparent original
  /// - Different pixels: bright red overlay
  final Uint8List? diffImage;

  /// Error or informational message.
  final String? message;

  /// Width of image A (for reference).
  final int? imageAWidth;

  /// Height of image A (for reference).
  final int? imageAHeight;

  /// Width of image B (for reference).
  final int? imageBWidth;

  /// Height of image B (for reference).
  final int? imageBHeight;

  /// Returns true if similarity meets or exceeds the threshold.
  bool passed(double threshold) => similarity >= threshold;

  /// Returns a human-readable summary of the comparison.
  String toSummary() {
    if (message != null && totalPixels == 0) {
      return 'FAILED: $message';
    }
    final percentage = (similarity * 100).toStringAsFixed(2);
    return '$percentage% similar ($matchingPixels matching, '
        '$differentPixels different out of $totalPixels total pixels)';
  }

  @override
  String toString() => 'ImageCompareResult($toSummary())';
}

@pragma('vm:prefer-inline')
int _premultiply8(int channel, int alpha) => (channel * alpha + 127) ~/ 255;

@pragma('vm:prefer-inline')
bool _pixelChannelsMatchAlphaAware({
  required int rA,
  required int gA,
  required int bA,
  required int aA,
  required int rB,
  required int gB,
  required int bB,
  required int aB,
  required int threshold,
}) {
  final aDiff = (aA - aB).abs();

  // Transparent RGB payload is encoder-dependent and not visible.
  if (aA <= _kNearTransparentAlpha && aB <= _kNearTransparentAlpha) {
    return aDiff <= threshold;
  }

  // Compare in premultiplied color space so semi-transparent anti-aliased
  // edges are judged by visible color contribution.
  final pRA = _premultiply8(rA, aA);
  final pGA = _premultiply8(gA, aA);
  final pBA = _premultiply8(bA, aA);
  final pRB = _premultiply8(rB, aB);
  final pGB = _premultiply8(gB, aB);
  final pBB = _premultiply8(bB, aB);

  return (pRA - pRB).abs() <= threshold &&
      (pGA - pGB).abs() <= threshold &&
      (pBA - pBB).abs() <= threshold &&
      aDiff <= threshold;
}

/// Compares two PNG images pixel-by-pixel.
///
/// [imageA] and [imageB] are PNG bytes to compare.
/// [perPixelThreshold] is the allowed per-channel difference (0.0 to 1.0).
/// Default 0.05 allows 5% difference (~12 out of 255) to account for anti-aliasing.
/// [generateDiff] when true, creates a visual diff image.
///
/// Returns [ImageCompareResult] with similarity metrics and optional diff image.
Future<ImageCompareResult> compareImages({
  required Uint8List imageA,
  required Uint8List imageB,
  double perPixelThreshold = 0.05,
  bool generateDiff = true,
}) async {
  // Validate inputs
  if (imageA.isEmpty) {
    return const ImageCompareResult.failed('Image A is empty');
  }
  if (imageB.isEmpty) {
    return const ImageCompareResult.failed('Image B is empty');
  }

  // Decode images to ui.Image
  final ui.Image? decodedA = await _decodeImage(imageA);
  if (decodedA == null) {
    return const ImageCompareResult.failed('Failed to decode image A');
  }

  final ui.Image? decodedB = await _decodeImage(imageB);
  if (decodedB == null) {
    decodedA.dispose();
    return const ImageCompareResult.failed('Failed to decode image B');
  }

  try {
    // Check dimensions
    final widthA = decodedA.width;
    final heightA = decodedA.height;
    final widthB = decodedB.width;
    final heightB = decodedB.height;

    if (widthA != widthB || heightA != heightB) {
      return ImageCompareResult.failed(
        'Dimension mismatch: Image A is ${widthA}x$heightA, '
        'Image B is ${widthB}x$heightB. '
        'Images must have identical dimensions for comparison.',
      );
    }

    // Convert to raw RGBA bytes
    final ByteData? bytesA = await decodedA.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );
    final ByteData? bytesB = await decodedB.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );

    if (bytesA == null || bytesB == null) {
      return const ImageCompareResult.failed(
        'Failed to convert images to RGBA byte data',
      );
    }

    final pixelsA = bytesA.buffer.asUint8List();
    final pixelsB = bytesB.buffer.asUint8List();

    // Calculate threshold as absolute value (0-255)
    final int threshold = (perPixelThreshold * 255).round();

    // Compare pixels
    final totalPixels = widthA * heightA;
    int matchingPixels = 0;
    int differentPixels = 0;

    // Prepare diff image buffer if needed
    Uint8List? diffPixels;
    if (generateDiff) {
      diffPixels = Uint8List(pixelsA.length);
    }

    for (int i = 0; i < pixelsA.length; i += 4) {
      final rA = pixelsA[i];
      final gA = pixelsA[i + 1];
      final bA = pixelsA[i + 2];
      final aA = pixelsA[i + 3];

      final rB = pixelsB[i];
      final gB = pixelsB[i + 1];
      final bB = pixelsB[i + 2];
      final aB = pixelsB[i + 3];

      final isMatch = _pixelChannelsMatchAlphaAware(
        rA: rA,
        gA: gA,
        bA: bA,
        aA: aA,
        rB: rB,
        gB: gB,
        bB: bB,
        aB: aB,
        threshold: threshold,
      );

      if (isMatch) {
        matchingPixels++;
        if (diffPixels != null) {
          // Matching pixel: semi-transparent original (green tint)
          diffPixels[i] = (rA * 0.5 + 0 * 0.5).round(); // R
          diffPixels[i + 1] = (gA * 0.5 + 128 * 0.5).round(); // G (green tint)
          diffPixels[i + 2] = (bA * 0.5 + 0 * 0.5).round(); // B
          diffPixels[i + 3] = 128; // Semi-transparent
        }
      } else {
        differentPixels++;
        if (diffPixels != null) {
          // Different pixel: bright red overlay
          diffPixels[i] = 255; // R
          diffPixels[i + 1] = 0; // G
          diffPixels[i + 2] = 0; // B
          diffPixels[i + 3] = 255; // Fully opaque
        }
      }
    }

    // Calculate similarity
    final similarity = totalPixels > 0 ? matchingPixels / totalPixels : 0.0;

    // Generate diff image PNG if requested
    Uint8List? diffImagePng;
    if (generateDiff && diffPixels != null) {
      diffImagePng = await _encodeRgbaToPng(diffPixels, widthA, heightA);
    }

    return ImageCompareResult(
      similarity: similarity,
      totalPixels: totalPixels,
      differentPixels: differentPixels,
      matchingPixels: matchingPixels,
      diffImage: diffImagePng,
      imageAWidth: widthA,
      imageAHeight: heightA,
      imageBWidth: widthB,
      imageBHeight: heightB,
    );
  } finally {
    // Dispose decoded images
    decodedA.dispose();
    decodedB.dispose();
  }
}

/// Decodes PNG bytes to ui.Image.
Future<ui.Image?> _decodeImage(Uint8List pngBytes) async {
  try {
    final codec = await ui.instantiateImageCodec(pngBytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    codec.dispose();
    return image;
  } catch (e) {
    return null;
  }
}

/// Encodes raw RGBA pixels to PNG format.
Future<Uint8List?> _encodeRgbaToPng(
  Uint8List rgbaPixels,
  int width,
  int height,
) async {
  try {
    // Create a ui.Image from raw pixels using decodeImageFromPixels
    final completer = _ImageCompleter();

    ui.decodeImageFromPixels(
      rgbaPixels,
      width,
      height,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );

    final image = await completer.future;
    if (image == null) {
      return null;
    }

    try {
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  } catch (e) {
    return null;
  }
}

/// Helper completer for async image decoding.
class _ImageCompleter {
  ui.Image? _image;
  bool _completed = false;
  final List<void Function()> _callbacks = [];

  void complete(ui.Image image) {
    _image = image;
    _completed = true;
    for (final callback in _callbacks) {
      callback();
    }
    _callbacks.clear();
  }

  Future<ui.Image?> get future async {
    if (_completed) {
      return _image;
    }

    await Future<void>.delayed(Duration.zero);

    // Poll for completion with timeout (max 5 seconds instead of 10)
    // This prevents indefinite hangs during golden tests
    for (int i = 0; i < 500; i++) {
      if (_completed) {
        return _image;
      }
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }

    // Return null after timeout to fail fast rather than hang
    return _image;
  }
}

/// Compares raw RGBA pixel data directly (without PNG encoding/decoding).
///
/// This is faster when you already have raw pixel data from Flutter's
/// RepaintBoundary.toImage().
///
/// [pixelsA] and [pixelsB] must be raw RGBA byte arrays (4 bytes per pixel).
/// [width] and [height] are the image dimensions.
/// [perPixelThreshold] is the allowed per-channel difference (0.0 to 1.0).
ImageCompareResult compareRawPixels({
  required Uint8List pixelsA,
  required Uint8List pixelsB,
  required int width,
  required int height,
  double perPixelThreshold = 0.05,
}) {
  // Validate inputs
  final expectedLength = width * height * 4;
  if (pixelsA.length != expectedLength) {
    return ImageCompareResult.failed(
      'Pixels A length mismatch: expected $expectedLength, got ${pixelsA.length}',
    );
  }
  if (pixelsB.length != expectedLength) {
    return ImageCompareResult.failed(
      'Pixels B length mismatch: expected $expectedLength, got ${pixelsB.length}',
    );
  }

  // Calculate threshold as absolute value (0-255)
  final int threshold = (perPixelThreshold * 255).round();

  // Compare pixels
  final totalPixels = width * height;
  int matchingPixels = 0;
  int differentPixels = 0;

  for (int i = 0; i < pixelsA.length; i += 4) {
    final rA = pixelsA[i];
    final gA = pixelsA[i + 1];
    final bA = pixelsA[i + 2];
    final aA = pixelsA[i + 3];

    final rB = pixelsB[i];
    final gB = pixelsB[i + 1];
    final bB = pixelsB[i + 2];
    final aB = pixelsB[i + 3];

    final isMatch = _pixelChannelsMatchAlphaAware(
      rA: rA,
      gA: gA,
      bA: bA,
      aA: aA,
      rB: rB,
      gB: gB,
      bB: bB,
      aB: aB,
      threshold: threshold,
    );

    if (isMatch) {
      matchingPixels++;
    } else {
      differentPixels++;
    }
  }

  // Calculate similarity
  final similarity = totalPixels > 0 ? matchingPixels / totalPixels : 0.0;

  return ImageCompareResult(
    similarity: similarity,
    totalPixels: totalPixels,
    differentPixels: differentPixels,
    matchingPixels: matchingPixels,
    imageAWidth: width,
    imageAHeight: height,
    imageBWidth: width,
    imageBHeight: height,
  );
}
