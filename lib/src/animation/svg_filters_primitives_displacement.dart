part of 'svg_filters.dart';

/// Displacement map фильтр
///
/// Uses pixels from in2 to spatially displace the image from in.
/// Supports scale animation and edge pixel handling per SVG spec.
class SvgDisplacementMapFilter extends SvgFilter {
  /// Масштаб смещения.
  final double scale;

  /// Канал для X-компоненты смещения.
  final SvgChannelSelector xChannelSelector;

  /// Канал для Y-компоненты смещения.
  final SvgChannelSelector yChannelSelector;

  /// Edge mode for handling displaced coordinates outside input bounds.
  /// This controls what happens when displacement maps pixels outside the image.
  final SvgDisplacementEdgeMode edgeMode;

  SvgDisplacementMapFilter({
    required super.id,
    required this.scale,
    required this.xChannelSelector,
    required this.yChannelSelector,
    this.edgeMode = SvgDisplacementEdgeMode.none,
    super.input,
    super.input2,
    super.resultName,
  }) : super(type: SvgFilterType.displacementMap);

  @override
  ui.ImageFilter? apply() => null;
}

/// Edge mode for feDisplacementMap.
/// Controls what happens when displaced coordinates fall outside the input image.
enum SvgDisplacementEdgeMode {
  /// Pixels outside are transparent black (0,0,0,0) - default per SVG spec
  none,

  /// Clamp to edge pixels
  clamp,

  /// Wrap around (tile)
  wrap,
}

/// Utility class for performing displacement map operations on image data.
///
/// Implements the SVG feDisplacementMap algorithm for pixel-level displacement
/// with support for edge handling modes.
class DisplacementMapProcessor {
  const DisplacementMapProcessor._();

  /// Applies displacement map to RGBA pixel data.
  ///
  /// [inputPixels] - Source RGBA pixel data (4 bytes per pixel).
  /// [mapPixels] - Displacement map RGBA pixel data.
  /// [width] - Image width in pixels.
  /// [height] - Image height in pixels.
  /// [scale] - Displacement scale factor.
  /// [xChannel] - Channel selector for X displacement.
  /// [yChannel] - Channel selector for Y displacement.
  /// [edgeMode] - How to handle pixels outside image bounds.
  /// [useBilinear] - If true, use bilinear interpolation for subpixel precision.
  ///
  /// Returns new RGBA pixel data with displacement applied.
  static Uint8List applyDisplacement({
    required Uint8List inputPixels,
    required Uint8List mapPixels,
    required int width,
    required int height,
    required double scale,
    required SvgChannelSelector xChannel,
    required SvgChannelSelector yChannel,
    required SvgDisplacementEdgeMode edgeMode,
    bool useBilinear = true,
  }) {
    if (width <= 0 || height <= 0) {
      return inputPixels;
    }
    if (inputPixels.length != mapPixels.length) {
      return inputPixels;
    }

    final result = Uint8List(inputPixels.length);

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final mapIndex = (y * width + x) * 4;

        // Get displacement values from map channels (0-255 -> 0-1)
        final xDisp = _getChannelValue(mapPixels, mapIndex, xChannel) / 255.0;
        final yDisp = _getChannelValue(mapPixels, mapIndex, yChannel) / 255.0;

        // Calculate displaced source coordinates
        // Per SVG spec: P'(x,y) = P(x + scale*(XC(x,y) - 0.5), y + scale*(YC(x,y) - 0.5))
        final srcX = x + scale * (xDisp - 0.5);
        final srcY = y + scale * (yDisp - 0.5);

        // Get source pixel using bilinear interpolation or nearest-neighbor
        final srcPixel = useBilinear
            ? _getPixelBilinear(
                inputPixels,
                width,
                height,
                srcX,
                srcY,
                edgeMode,
              )
            : _getPixelWithEdgeMode(
                inputPixels,
                width,
                height,
                srcX.round(),
                srcY.round(),
                edgeMode,
              );

        // Write result pixel
        final dstIndex = (y * width + x) * 4;
        result[dstIndex] = srcPixel[0];
        result[dstIndex + 1] = srcPixel[1];
        result[dstIndex + 2] = srcPixel[2];
        result[dstIndex + 3] = srcPixel[3];
      }
    }

    return result;
  }

  /// Gets interpolated pixel value using bilinear interpolation.
  ///
  /// When the displacement map produces non-integer coordinates, this
  /// interpolates between the 4 nearest pixels for smooth results.
  static List<int> _getPixelBilinear(
    Uint8List pixels,
    int width,
    int height,
    double x,
    double y,
    SvgDisplacementEdgeMode edgeMode,
  ) {
    // Get integer and fractional parts
    final x0 = x.floor();
    final y0 = y.floor();
    final x1 = x0 + 1;
    final y1 = y0 + 1;
    final fx = x - x0;
    final fy = y - y0;

    // Get the 4 corner pixels
    final p00 = _getPixelWithEdgeMode(pixels, width, height, x0, y0, edgeMode);
    final p10 = _getPixelWithEdgeMode(pixels, width, height, x1, y0, edgeMode);
    final p01 = _getPixelWithEdgeMode(pixels, width, height, x0, y1, edgeMode);
    final p11 = _getPixelWithEdgeMode(pixels, width, height, x1, y1, edgeMode);

    // Bilinear interpolation for each channel
    final ifx = 1.0 - fx;
    final ify = 1.0 - fy;

    final r =
        (p00[0] * ifx * ify +
                p10[0] * fx * ify +
                p01[0] * ifx * fy +
                p11[0] * fx * fy)
            .round()
            .clamp(0, 255);
    final g =
        (p00[1] * ifx * ify +
                p10[1] * fx * ify +
                p01[1] * ifx * fy +
                p11[1] * fx * fy)
            .round()
            .clamp(0, 255);
    final b =
        (p00[2] * ifx * ify +
                p10[2] * fx * ify +
                p01[2] * ifx * fy +
                p11[2] * fx * fy)
            .round()
            .clamp(0, 255);
    final a =
        (p00[3] * ifx * ify +
                p10[3] * fx * ify +
                p01[3] * ifx * fy +
                p11[3] * fx * fy)
            .round()
            .clamp(0, 255);

    return <int>[r, g, b, a];
  }

  /// Gets channel value from pixel data.
  static int _getChannelValue(
    Uint8List pixels,
    int index,
    SvgChannelSelector channel,
  ) {
    switch (channel) {
      case SvgChannelSelector.r:
        return pixels[index];
      case SvgChannelSelector.g:
        return pixels[index + 1];
      case SvgChannelSelector.b:
        return pixels[index + 2];
      case SvgChannelSelector.a:
        return pixels[index + 3];
    }
  }

  /// Gets pixel RGBA values with edge mode handling.
  static List<int> _getPixelWithEdgeMode(
    Uint8List pixels,
    int width,
    int height,
    int x,
    int y,
    SvgDisplacementEdgeMode edgeMode,
  ) {
    switch (edgeMode) {
      case SvgDisplacementEdgeMode.clamp:
        // Clamp coordinates to valid range
        final clampedX = x.clamp(0, width - 1);
        final clampedY = y.clamp(0, height - 1);
        final index = (clampedY * width + clampedX) * 4;
        return <int>[
          pixels[index],
          pixels[index + 1],
          pixels[index + 2],
          pixels[index + 3],
        ];

      case SvgDisplacementEdgeMode.wrap:
        // Wrap coordinates around
        var wrappedX = x % width;
        var wrappedY = y % height;
        if (wrappedX < 0) wrappedX += width;
        if (wrappedY < 0) wrappedY += height;
        final index = (wrappedY * width + wrappedX) * 4;
        return <int>[
          pixels[index],
          pixels[index + 1],
          pixels[index + 2],
          pixels[index + 3],
        ];

      case SvgDisplacementEdgeMode.none:
        // Return transparent black for out-of-bounds (SVG default)
        if (x < 0 || x >= width || y < 0 || y >= height) {
          return const <int>[0, 0, 0, 0];
        }
        final index = (y * width + x) * 4;
        return <int>[
          pixels[index],
          pixels[index + 1],
          pixels[index + 2],
          pixels[index + 3],
        ];
    }
  }
}

/// Extended paint pass that includes displacement map parameters.
///
/// When [displacementFilter] is non-null, the painter should apply
/// displacement with proper edge handling.
class SvgDisplacementMapPaintPass extends SvgFilterPaintPass {
  const SvgDisplacementMapPaintPass({
    super.imageFilter,
    super.colorFilter,
    super.blendMode,
    super.offset,
    super.paintFill,
    super.paintStroke,
    required this.displacementFilter,
  });

  /// The displacement filter parameters to apply.
  final SvgDisplacementMapFilter displacementFilter;

  @override
  SvgFilterPaintPass copyWith({
    ui.ImageFilter? imageFilter,
    ui.ColorFilter? colorFilter,
    ui.BlendMode? blendMode,
    ui.Offset? offset,
    bool? paintFill,
    bool? paintStroke,
  }) {
    return SvgDisplacementMapPaintPass(
      imageFilter: imageFilter ?? this.imageFilter,
      colorFilter: colorFilter ?? this.colorFilter,
      blendMode: blendMode ?? this.blendMode,
      offset: offset ?? this.offset,
      paintFill: paintFill ?? this.paintFill,
      paintStroke: paintStroke ?? this.paintStroke,
      displacementFilter: displacementFilter,
    );
  }
}
