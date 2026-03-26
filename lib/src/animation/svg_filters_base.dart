part of 'svg_filters.dart';

/// Базовый класс для SVG фильтра
abstract class SvgFilter {
  /// ID фильтра
  final String id;

  /// Тип фильтра
  final SvgFilterType type;

  /// Primitive input (`in` attribute).
  final String? input;

  /// Optional secondary input (`in2` attribute).
  final String? input2;

  /// Named primitive result (`result` attribute).
  final String? resultName;

  SvgFilter({
    required this.id,
    required this.type,
    this.input,
    this.input2,
    this.resultName,
  });

  /// Применить фильтр к изображению
  /// Возвращает ImageFilter для использования в Flutter Canvas
  ui.ImageFilter? apply();

  /// Опциональный ColorFilter (если фильтр влияет на цвет напрямую).
  ui.ColorFilter? colorFilter() => null;

  /// Опциональный blend mode (если фильтр задаёт композицию).
  ui.BlendMode? blendMode() => null;
}

/// feFlood: закрашивает результат сплошным цветом.
class SvgFloodFilter extends SvgFilter {
  /// Цвет заливки.
  final ui.Color floodColor;

  /// Прозрачность flood (0..1).
  final double floodOpacity;

  SvgFloodFilter({
    required super.id,
    required this.floodColor,
    required this.floodOpacity,
    super.resultName,
  }) : super(type: SvgFilterType.flood);

  ui.Color get _effectiveColor {
    final opacity = floodOpacity.clamp(0.0, 1.0);
    return floodColor.withValues(alpha: floodColor.a * opacity);
  }

  ui.Color get effectiveColor => _effectiveColor;

  @override
  ui.ImageFilter? apply() {
    return ui.ColorFilter.mode(_effectiveColor, ui.BlendMode.src);
  }

  @override
  ui.ColorFilter? colorFilter() {
    return ui.ColorFilter.mode(_effectiveColor, ui.BlendMode.src);
  }
}

/// feBlend: приближенно задаёт режим смешивания слоя.
class SvgBlendFilter extends SvgFilter {
  /// Режим смешивания.
  final ui.BlendMode mode;

  SvgBlendFilter({
    required super.id,
    required this.mode,
    super.input,
    super.input2,
    super.resultName,
  }) : super(type: SvgFilterType.blend);

  @override
  ui.ImageFilter? apply() => null;

  @override
  ui.BlendMode? blendMode() => mode;
}

/// feComposite: приближенно задаёт режим композиции слоя.
class SvgCompositeFilter extends SvgFilter {
  /// Оператор композиции из SVG (over/in/out/atop/xor/lighter/arithmetic).
  final String operatorType;

  /// Соответствующий Flutter BlendMode (если есть приближение).
  final ui.BlendMode? mode;

  /// Параметры arithmetic (если заданы).
  final double k1;
  final double k2;
  final double k3;
  final double k4;

  SvgCompositeFilter({
    required super.id,
    required this.operatorType,
    required this.mode,
    this.k1 = 0.0,
    this.k2 = 0.0,
    this.k3 = 0.0,
    this.k4 = 0.0,
    super.input,
    super.input2,
    super.resultName,
  }) : super(type: SvgFilterType.composite);

  @override
  ui.ImageFilter? apply() => null;

  @override
  ui.BlendMode? blendMode() => mode;
}

/// feMerge: объединяет несколько входов в один результат.
///
/// В текущем baseline-пайплайне хранит структуру примитива, но не выполняет
/// полноценную графовую композицию входов.
class SvgMergeFilter extends SvgFilter {
  /// Список входов из дочерних `<feMergeNode in="...">`.
  final List<String?> nodeInputs;

  SvgMergeFilter({
    required super.id,
    required this.nodeInputs,
    super.resultName,
  }) : super(type: SvgFilterType.merge);

  /// Количество merge-node в примитиве.
  int get nodeCount => nodeInputs.length;

  @override
  ui.ImageFilter? apply() => null;
}

/// feTile: baseline-pass-through примитив.
///
/// Tiles the input image to fill the filter primitive subregion.
/// Supports subregion specification (x, y, width, height) and proper
/// tile boundary wrapping per SVG spec.
class SvgTileFilter extends SvgFilter {
  /// Primitive subregion x coordinate.
  final double x;

  /// Primitive subregion y coordinate.
  final double y;

  /// Primitive subregion width.
  final double width;

  /// Primitive subregion height.
  final double height;

  SvgTileFilter({
    required super.id,
    this.x = 0.0,
    this.y = 0.0,
    this.width = 0.0,
    this.height = 0.0,
    super.input,
    super.resultName,
  }) : super(type: SvgFilterType.tile);

  /// Whether this tile filter has a non-standard subregion specified.
  bool get hasSubregion => width > 0 && height > 0;

  @override
  ui.ImageFilter? apply() => null;
}

/// Utility class for performing tile operations on image data.
///
/// Implements the SVG feTile algorithm for tiling input images
/// to fill the filter primitive subregion.
class TileProcessor {
  const TileProcessor._();

  /// Tiles the input pixel data to fill the specified output dimensions.
  ///
  /// [inputPixels] - Source RGBA pixel data (4 bytes per pixel).
  /// [inputWidth] - Input image width in pixels.
  /// [inputHeight] - Input image height in pixels.
  /// [outputWidth] - Output tile region width in pixels.
  /// [outputHeight] - Output tile region height in pixels.
  /// [tileX] - X offset of the tile origin within the output.
  /// [tileY] - Y offset of the tile origin within the output.
  /// [tileWidth] - Width of the tile region (0 = use inputWidth).
  /// [tileHeight] - Height of the tile region (0 = use inputHeight).
  ///
  /// Per SVG spec, feTile tiles the input image to fill the filter primitive
  /// subregion. The input's own subregion defines the tile size. Tile origin
  /// aligns with the filter region origin.
  ///
  /// Returns new RGBA pixel data with tiling applied.
  static Uint8List applyTiling({
    required Uint8List inputPixels,
    required int inputWidth,
    required int inputHeight,
    required int outputWidth,
    required int outputHeight,
    int tileX = 0,
    int tileY = 0,
    int tileWidth = 0,
    int tileHeight = 0,
  }) {
    // Handle empty output case
    if (outputWidth <= 0 || outputHeight <= 0) {
      return Uint8List(0);
    }

    final outputSize = outputWidth * outputHeight * 4;

    // Handle empty input: produce transparent black output per SVG spec
    if (inputWidth <= 0 ||
        inputHeight <= 0 ||
        inputPixels.isEmpty ||
        inputPixels.length < inputWidth * inputHeight * 4) {
      return Uint8List(outputSize);
    }

    // Use input dimensions if tile dimensions not specified
    // The tile size is defined by the input's subregion
    final tw = tileWidth > 0 ? tileWidth : inputWidth;
    final th = tileHeight > 0 ? tileHeight : inputHeight;

    final result = Uint8List(outputSize);

    for (int y = 0; y < outputHeight; y++) {
      for (int x = 0; x < outputWidth; x++) {
        // Calculate source coordinates with tiling
        // Tile origin aligns with filter region origin (offset by tileX/tileY)
        var srcX = ((x - tileX) % tw);
        var srcY = ((y - tileY) % th);
        if (srcX < 0) srcX += tw;
        if (srcY < 0) srcY += th;

        // Handle non-unit tile regions where tile size differs from input size
        // If tile region is larger than input, areas outside input are transparent
        if (srcX >= inputWidth || srcY >= inputHeight) {
          // Outside input image - use transparent black
          final dstIndex = (y * outputWidth + x) * 4;
          result[dstIndex] = 0;
          result[dstIndex + 1] = 0;
          result[dstIndex + 2] = 0;
          result[dstIndex + 3] = 0;
          continue;
        }

        // Copy pixel from input
        final srcIndex = (srcY * inputWidth + srcX) * 4;
        final dstIndex = (y * outputWidth + x) * 4;
        result[dstIndex] = inputPixels[srcIndex];
        result[dstIndex + 1] = inputPixels[srcIndex + 1];
        result[dstIndex + 2] = inputPixels[srcIndex + 2];
        result[dstIndex + 3] = inputPixels[srcIndex + 3];
      }
    }

    return result;
  }
}

/// Extended paint pass that includes tile parameters for subregion support.
///
/// When [tileFilter] specifies a subregion, the painter should apply
/// tiling with proper boundary handling.
class SvgTilePaintPass extends SvgFilterPaintPass {
  const SvgTilePaintPass({
    super.imageFilter,
    super.colorFilter,
    super.blendMode,
    super.offset,
    super.paintFill,
    super.paintStroke,
    required this.tileFilter,
  });

  /// The tile filter parameters to apply.
  final SvgTileFilter tileFilter;

  @override
  SvgFilterPaintPass copyWith({
    ui.ImageFilter? imageFilter,
    ui.ColorFilter? colorFilter,
    ui.BlendMode? blendMode,
    ui.Offset? offset,
    bool? paintFill,
    bool? paintStroke,
  }) {
    return SvgTilePaintPass(
      imageFilter: imageFilter ?? this.imageFilter,
      colorFilter: colorFilter ?? this.colorFilter,
      blendMode: blendMode ?? this.blendMode,
      offset: offset ?? this.offset,
      paintFill: paintFill ?? this.paintFill,
      paintStroke: paintStroke ?? this.paintStroke,
      tileFilter: tileFilter,
    );
  }
}

/// Парсит feBlend mode в Flutter BlendMode.
ui.BlendMode parseSvgBlendMode(String? rawMode) {
  switch ((rawMode ?? 'normal').trim().toLowerCase()) {
    case 'multiply':
      return ui.BlendMode.multiply;
    case 'screen':
      return ui.BlendMode.screen;
    case 'darken':
      return ui.BlendMode.darken;
    case 'lighten':
      return ui.BlendMode.lighten;
    case 'overlay':
      return ui.BlendMode.overlay;
    case 'color-dodge':
      return ui.BlendMode.colorDodge;
    case 'color-burn':
      return ui.BlendMode.colorBurn;
    case 'hard-light':
      return ui.BlendMode.hardLight;
    case 'soft-light':
      return ui.BlendMode.softLight;
    case 'difference':
      return ui.BlendMode.difference;
    case 'exclusion':
      return ui.BlendMode.exclusion;
    case 'hue':
      return ui.BlendMode.hue;
    case 'saturation':
      return ui.BlendMode.saturation;
    case 'color':
      return ui.BlendMode.color;
    case 'luminosity':
      return ui.BlendMode.luminosity;
    case 'normal':
    default:
      return ui.BlendMode.srcOver;
  }
}

/// Парсит feComposite operator в Flutter BlendMode.
///
/// Для `arithmetic` возвращает null (в текущем пайплайне нет точного аналога).
ui.BlendMode? parseSvgCompositeOperator(String? rawOperator) {
  switch ((rawOperator ?? 'over').trim().toLowerCase()) {
    case 'over':
      return ui.BlendMode.srcOver;
    case 'in':
      return ui.BlendMode.srcIn;
    case 'out':
      return ui.BlendMode.srcOut;
    case 'atop':
      return ui.BlendMode.srcATop;
    case 'xor':
      return ui.BlendMode.xor;
    case 'lighter':
      return ui.BlendMode.plus;
    case 'arithmetic':
      return null;
    default:
      return ui.BlendMode.srcOver;
  }
}
