import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

/// Тип SVG фильтра
enum SvgFilterType {
  /// Gaussian blur - размытие
  gaussianBlur,

  /// Offset - смещение результата
  offset,

  /// Flood - заливка сплошным цветом
  flood,

  /// Blend - смешивание с подложкой
  blend,

  /// Composite - композиция с подложкой
  composite,

  /// Merge - объединение нескольких входов (feMerge/feMergeNode)
  merge,

  /// Drop shadow - тень
  dropShadow,

  /// Color matrix - цветовые трансформации
  colorMatrix,
}

/// Один проход отрисовки фильтра для source-графики.
///
/// Animated painter может рендерить элемент в несколько проходов
/// (например для `feDropShadow` и `feMerge`).
class SvgFilterPaintPass {
  const SvgFilterPaintPass({
    this.imageFilter,
    this.colorFilter,
    this.blendMode,
    this.offset = ui.Offset.zero,
  });

  static const SvgFilterPaintPass identity = SvgFilterPaintPass();

  final ui.ImageFilter? imageFilter;
  final ui.ColorFilter? colorFilter;
  final ui.BlendMode? blendMode;
  final ui.Offset offset;

  SvgFilterPaintPass copyWith({
    ui.ImageFilter? imageFilter,
    ui.ColorFilter? colorFilter,
    ui.BlendMode? blendMode,
    ui.Offset? offset,
  }) {
    return SvgFilterPaintPass(
      imageFilter: imageFilter ?? this.imageFilter,
      colorFilter: colorFilter ?? this.colorFilter,
      blendMode: blendMode ?? this.blendMode,
      offset: offset ?? this.offset,
    );
  }
}

/// Offset фильтр
///
/// Смещает входное изображение на dx/dy.
class SvgOffsetFilter extends SvgFilter {
  /// Смещение по X
  final double dx;

  /// Смещение по Y
  final double dy;

  SvgOffsetFilter({
    required super.id,
    required this.dx,
    required this.dy,
    super.input,
    super.resultName,
  }) : super(type: SvgFilterType.offset);

  @override
  ui.ImageFilter? apply() {
    // Matrix4 в column-major формате: translation в ячейках [12], [13].
    final matrix = Float64List.fromList(<double>[
      1,
      0,
      0,
      0,
      0,
      1,
      0,
      0,
      0,
      0,
      1,
      0,
      dx,
      dy,
      0,
      1,
    ]);
    return ui.ImageFilter.matrix(matrix);
  }
}

/// Тип цветовой матрицы для feColorMatrix
enum SvgColorMatrixType {
  /// Матрица 5x4 (20 значений)
  matrix,

  /// Насыщенность (1 значение: 0-1)
  saturate,

  /// Hue rotate (1 значение: градусы)
  hueRotate,

  /// Luminance to alpha (нет значений)
  luminanceToAlpha,
}

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

/// Gaussian Blur фильтр
///
/// Использует ImageFilter.blur для размытия
class SvgGaussianBlurFilter extends SvgFilter {
  /// Стандартное отклонение по X (размытие по горизонтали)
  final double stdDeviationX;

  /// Стандартное отклонение по Y (размытие по вертикали)
  final double stdDeviationY;

  SvgGaussianBlurFilter({
    required super.id,
    required this.stdDeviationX,
    required this.stdDeviationY,
    super.input,
    super.resultName,
  }) : super(type: SvgFilterType.gaussianBlur);

  @override
  ui.ImageFilter? apply() {
    // Flutter ImageFilter.blur использует sigma (стандартное отклонение)
    // В SVG stdDeviation = sigma
    return ui.ImageFilter.blur(sigmaX: stdDeviationX, sigmaY: stdDeviationY);
  }
}

/// Drop Shadow фильтр
///
/// Создает тень от объекта
class SvgDropShadowFilter extends SvgFilter {
  /// Смещение по X
  final double dx;

  /// Смещение по Y
  final double dy;

  /// Стандартное отклонение по X (размытие тени)
  final double stdDeviationX;

  /// Стандартное отклонение по Y (размытие тени)
  final double stdDeviationY;

  /// Цвет тени
  final ui.Color? floodColor;

  /// Прозрачность тени (0..1)
  final double floodOpacity;

  SvgDropShadowFilter({
    required super.id,
    required this.dx,
    required this.dy,
    required this.stdDeviationX,
    required this.stdDeviationY,
    this.floodColor,
    this.floodOpacity = 1.0,
    super.input,
    super.resultName,
  }) : super(type: SvgFilterType.dropShadow);

  @override
  ui.ImageFilter? apply() {
    return ui.ImageFilter.blur(sigmaX: stdDeviationX, sigmaY: stdDeviationY);
  }

  /// Получить offset для применения через transform
  ui.Offset get offset => ui.Offset(dx, dy);

  /// Эффективный цвет тени с учётом flood-opacity.
  ui.Color get effectiveShadowColor {
    final base = floodColor ?? const ui.Color(0xFF000000);
    final opacity = floodOpacity.clamp(0.0, 1.0);
    return base.withValues(alpha: base.a * opacity);
  }

  /// Совместимость со старым API (среднее по осям).
  double get stdDeviation => (stdDeviationX + stdDeviationY) / 2.0;
}

/// Color Matrix фильтр
///
/// Применяет цветовые трансформации
class SvgColorMatrixFilter extends SvgFilter {
  /// Тип трансформации
  final SvgColorMatrixType matrixType;

  /// Значения для матрицы (зависят от типа)
  final List<double> values;

  SvgColorMatrixFilter({
    required super.id,
    required this.matrixType,
    required this.values,
    super.input,
    super.resultName,
  }) : super(type: SvgFilterType.colorMatrix);

  @override
  ui.ImageFilter? apply() {
    switch (matrixType) {
      case SvgColorMatrixType.matrix:
        if (values.length == 20) {
          // Матрица 5x4 для RGBA
          // Преобразуем в ColorFilter.matrix (4x5 матрица в Flutter)
          return ui.ColorFilter.matrix(_convertSvgMatrixToFlutter(values));
        }
        return null;

      case SvgColorMatrixType.saturate:
        if (values.isNotEmpty) {
          // Насыщенность (0 = grayscale, 1 = normal)
          return ui.ColorFilter.matrix(_saturateMatrix(values[0]));
        }
        return null;

      case SvgColorMatrixType.hueRotate:
        if (values.isNotEmpty) {
          // Hue rotation в градусах
          return ui.ColorFilter.matrix(_hueRotateMatrix(values[0]));
        }
        return null;

      case SvgColorMatrixType.luminanceToAlpha:
        // Luminance to alpha - специальная матрица
        return ui.ColorFilter.matrix(_luminanceToAlphaMatrix());
    }
  }

  /// Конвертирует SVG матрицу 5x4 (20 значений) в Flutter матрицу 4x5 (20 значений)
  ///
  /// SVG формат: строка за строкой (R, G, B, A, 1 для каждой строки)
  /// Flutter формат: столбец за столбцом (RGBA + offset)
  List<double> _convertSvgMatrixToFlutter(List<double> svgMatrix) {
    // SVG matrix (5x4):
    // [Rr Rg Rb Ra Rk]
    // [Gr Gg Gb Ga Gk]
    // [Br Bg Bb Ba Bk]
    // [Ar Ag Ab Aa Ak]
    //
    // Flutter matrix (4x5):
    // [Rr Gr Br Ar] - red column
    // [Rg Gg Bg Ag] - green column
    // [Rb Gb Bb Ab] - blue column
    // [Ra Ga Ba Aa] - alpha column
    // [Rk Gk Bk Ak] - offset row

    final result = <double>[];

    // Red column: Rr, Gr, Br, Ar
    result.addAll([svgMatrix[0], svgMatrix[5], svgMatrix[10], svgMatrix[15]]);

    // Green column: Rg, Gg, Bg, Ag
    result.addAll([svgMatrix[1], svgMatrix[6], svgMatrix[11], svgMatrix[16]]);

    // Blue column: Rb, Gb, Bb, Ab
    result.addAll([svgMatrix[2], svgMatrix[7], svgMatrix[12], svgMatrix[17]]);

    // Alpha column: Ra, Ga, Ba, Aa
    result.addAll([svgMatrix[3], svgMatrix[8], svgMatrix[13], svgMatrix[18]]);

    // Offset row: Rk, Gk, Bk, Ak (умножаем на 255 так как Flutter работает в [0-1], а SVG в [0-255])
    result.addAll([
      svgMatrix[4] / 255.0,
      svgMatrix[9] / 255.0,
      svgMatrix[14] / 255.0,
      svgMatrix[19] / 255.0,
    ]);

    return result;
  }

  /// Создает матрицу для насыщенности (saturate)
  List<double> _saturateMatrix(double s) {
    // SVG saturate matrix formula
    final r = 0.2126 + 0.7874 * s;
    final g = 0.7152 + 0.2848 * s;
    final b = 0.0722 + 0.9278 * s;

    return [
      r, 0, 0, 0, 0, // Red row
      0, g, 0, 0, 0, // Green row
      0, 0, b, 0, 0, // Blue row
      0, 0, 0, 1, 0, // Alpha row
    ];
  }

  /// Создает матрицу для hue rotation (поворот оттенка)
  List<double> _hueRotateMatrix(double degrees) {
    // Конвертируем градусы в радианы
    final radians = degrees * 3.141592653589793 / 180.0;
    final cos = math.cos(radians);
    final sin = math.sin(radians);

    // Hue rotation matrix
    return [
      0.213 + cos * 0.787 + sin * -0.213, // Rr
      0.715 + cos * -0.715 + sin * -0.715, // Rg
      0.072 + cos * -0.072 + sin * 0.928, // Rb
      0, 0, // Ra, Rk

      0.213 + cos * -0.213 + sin * 0.143, // Gr
      0.715 + cos * 0.285 + sin * 0.140, // Gg
      0.072 + cos * -0.072 + sin * -0.283, // Gb
      0, 0, // Ga, Gk

      0.213 + cos * -0.213 + sin * -0.787, // Br
      0.715 + cos * -0.715 + sin * 0.715, // Bg
      0.072 + cos * 0.928 + sin * 0.072, // Bb
      0, 0, // Ba, Bk

      0, 0, 0, 1, 0, // Alpha row
    ];
  }

  /// Создает матрицу для luminance to alpha
  List<double> _luminanceToAlphaMatrix() {
    // Luminance weights: 0.2126 * R + 0.7152 * G + 0.0722 * B
    return [
      0, 0, 0, 0, 0, // Red row
      0, 0, 0, 0, 0, // Green row
      0, 0, 0, 0, 0, // Blue row
      0.2126, 0.7152, 0.0722, 0, 0, // Alpha row
    ];
  }
}

/// Коллекция фильтров в SVG документе
class SvgFilters {
  /// Карта ID фильтра -> список примитивов в порядке объявления.
  final Map<String, List<SvgFilter>> _filters = {};

  /// Добавить фильтр
  void add(SvgFilter filter) {
    _filters.putIfAbsent(filter.id, () => <SvgFilter>[]).add(filter);
  }

  /// Получить последний примитив фильтра по ID (совместимость с legacy API).
  SvgFilter? getById(String id) {
    final list = _filters[id];
    if (list == null || list.isEmpty) {
      return null;
    }
    return list.last;
  }

  /// Получить все примитивы фильтра по ID в порядке объявления.
  List<SvgFilter> getAllById(String id) {
    final list = _filters[id];
    if (list == null) {
      return const <SvgFilter>[];
    }
    return List<SvgFilter>.unmodifiable(list);
  }

  /// Проверить наличие фильтра
  bool hasFilter(String id) {
    final list = _filters[id];
    return list != null && list.isNotEmpty;
  }

  /// Разрешает фильтр в один или несколько paint-проходов.
  ///
  /// Для `feDropShadow` и `feMerge` возвращает multi-pass результат,
  /// чтобы painter мог рендерить исходник и производные результаты по отдельности.
  List<SvgFilterPaintPass> resolvePaintPasses(String id) {
    final list = _filters[id];
    if (list == null || list.isEmpty) {
      return const <SvgFilterPaintPass>[SvgFilterPaintPass.identity];
    }

    const sourceGraphic = <SvgFilterPaintPass>[SvgFilterPaintPass.identity];
    final sourceAlpha = <SvgFilterPaintPass>[
      const SvgFilterPaintPass(
        colorFilter: ui.ColorFilter.mode(
          ui.Color(0xFFFFFFFF),
          ui.BlendMode.srcIn,
        ),
      ),
    ];

    final namedResults = <String, List<SvgFilterPaintPass>>{};
    var previous = <SvgFilterPaintPass>[...sourceGraphic];

    for (final primitive in list) {
      List<SvgFilterPaintPass> output;
      switch (primitive.type) {
        case SvgFilterType.gaussianBlur:
          final blur = primitive as SvgGaussianBlurFilter;
          final input = _resolveInputPasses(
            requestedInput: blur.input,
            previous: previous,
            namedResults: namedResults,
            sourceGraphic: sourceGraphic,
            sourceAlpha: sourceAlpha,
          );
          final blurFilter = blur.apply();
          output = input
              .map(
                (pass) => pass.copyWith(
                  imageFilter: _composeImageFilter(
                    blurFilter,
                    pass.imageFilter,
                  ),
                ),
              )
              .toList(growable: false);

        case SvgFilterType.offset:
          final offset = primitive as SvgOffsetFilter;
          final input = _resolveInputPasses(
            requestedInput: offset.input,
            previous: previous,
            namedResults: namedResults,
            sourceGraphic: sourceGraphic,
            sourceAlpha: sourceAlpha,
          );
          output = input
              .map(
                (pass) => pass.copyWith(
                  offset: pass.offset + ui.Offset(offset.dx, offset.dy),
                ),
              )
              .toList(growable: false);

        case SvgFilterType.flood:
          final flood = primitive as SvgFloodFilter;
          output = <SvgFilterPaintPass>[
            SvgFilterPaintPass(
              colorFilter: ui.ColorFilter.mode(
                flood.effectiveColor,
                ui.BlendMode.src,
              ),
            ),
          ];

        case SvgFilterType.blend:
          final blend = primitive as SvgBlendFilter;
          final input = _resolveInputPasses(
            requestedInput: blend.input,
            previous: previous,
            namedResults: namedResults,
            sourceGraphic: sourceGraphic,
            sourceAlpha: sourceAlpha,
          );
          output = input
              .map((pass) => pass.copyWith(blendMode: blend.mode))
              .toList(growable: false);

        case SvgFilterType.composite:
          final composite = primitive as SvgCompositeFilter;
          final input = _resolveInputPasses(
            requestedInput: composite.input,
            previous: previous,
            namedResults: namedResults,
            sourceGraphic: sourceGraphic,
            sourceAlpha: sourceAlpha,
          );
          if (composite.mode == null) {
            output = input;
          } else {
            output = input
                .map((pass) => pass.copyWith(blendMode: composite.mode))
                .toList(growable: false);
          }

        case SvgFilterType.merge:
          final merge = primitive as SvgMergeFilter;
          final merged = <SvgFilterPaintPass>[];
          if (merge.nodeInputs.isEmpty) {
            merged.addAll(previous);
          } else {
            for (final nodeInput in merge.nodeInputs) {
              merged.addAll(
                _resolveInputPasses(
                  requestedInput: nodeInput,
                  previous: previous,
                  namedResults: namedResults,
                  sourceGraphic: sourceGraphic,
                  sourceAlpha: sourceAlpha,
                ),
              );
            }
          }
          output = merged.isEmpty ? previous : merged;

        case SvgFilterType.dropShadow:
          final shadow = primitive as SvgDropShadowFilter;
          final input = _resolveInputPasses(
            requestedInput: shadow.input,
            previous: previous,
            namedResults: namedResults,
            sourceGraphic: sourceGraphic,
            sourceAlpha: sourceAlpha,
          );
          final shadowFilter = shadow.apply();
          final shadowPasses = input
              .map(
                (pass) => SvgFilterPaintPass(
                  imageFilter: _composeImageFilter(
                    shadowFilter,
                    pass.imageFilter,
                  ),
                  colorFilter: ui.ColorFilter.mode(
                    shadow.effectiveShadowColor,
                    ui.BlendMode.srcIn,
                  ),
                  blendMode: ui.BlendMode.srcOver,
                  offset: pass.offset + shadow.offset,
                ),
              )
              .toList(growable: false);
          output = <SvgFilterPaintPass>[...shadowPasses, ...input];

        case SvgFilterType.colorMatrix:
          final colorMatrix = primitive as SvgColorMatrixFilter;
          final input = _resolveInputPasses(
            requestedInput: colorMatrix.input,
            previous: previous,
            namedResults: namedResults,
            sourceGraphic: sourceGraphic,
            sourceAlpha: sourceAlpha,
          );
          final colorFilter = colorMatrix.colorFilter();
          if (colorFilter == null) {
            output = input;
          } else {
            output = input
                .map((pass) => pass.copyWith(colorFilter: colorFilter))
                .toList(growable: false);
          }
      }

      previous = output;
      final resultName = primitive.resultName?.trim();
      if (resultName != null && resultName.isNotEmpty) {
        namedResults[resultName] = output
            .map(
              (pass) => SvgFilterPaintPass(
                imageFilter: pass.imageFilter,
                colorFilter: pass.colorFilter,
                blendMode: pass.blendMode,
                offset: pass.offset,
              ),
            )
            .toList(growable: false);
      }
    }

    if (previous.isEmpty) {
      return const <SvgFilterPaintPass>[SvgFilterPaintPass.identity];
    }
    return previous;
  }

  List<SvgFilterPaintPass> _resolveInputPasses({
    required String? requestedInput,
    required List<SvgFilterPaintPass> previous,
    required Map<String, List<SvgFilterPaintPass>> namedResults,
    required List<SvgFilterPaintPass> sourceGraphic,
    required List<SvgFilterPaintPass> sourceAlpha,
  }) {
    final normalized = requestedInput?.trim();
    if (normalized == null || normalized.isEmpty) {
      return previous.isEmpty
          ? <SvgFilterPaintPass>[...sourceGraphic]
          : previous;
    }

    switch (normalized) {
      case 'SourceGraphic':
        return <SvgFilterPaintPass>[...sourceGraphic];
      case 'SourceAlpha':
        return <SvgFilterPaintPass>[...sourceAlpha];
      case 'BackgroundImage':
      case 'BackgroundAlpha':
      case 'FillPaint':
      case 'StrokePaint':
        return <SvgFilterPaintPass>[...sourceGraphic];
      default:
        final named = namedResults[normalized];
        if (named != null && named.isNotEmpty) {
          return <SvgFilterPaintPass>[...named];
        }
        return previous.isEmpty
            ? <SvgFilterPaintPass>[...sourceGraphic]
            : previous;
    }
  }

  ui.ImageFilter? _composeImageFilter(
    ui.ImageFilter? outer,
    ui.ImageFilter? inner,
  ) {
    if (outer == null) return inner;
    if (inner == null) return outer;
    return ui.ImageFilter.compose(outer: outer, inner: inner);
  }

  /// Скомпоновать ImageFilter цепочку для filter id.
  ui.ImageFilter? resolveImageFilter(String id) {
    final passes = resolvePaintPasses(id);
    for (final pass in passes) {
      if (pass.imageFilter != null) {
        return pass.imageFilter;
      }
    }
    return null;
  }

  /// Получить итоговый ColorFilter для цепочки (последний цветовой примитив).
  ui.ColorFilter? resolveColorFilter(String id) {
    final passes = resolvePaintPasses(id);
    ui.ColorFilter? result;
    for (final pass in passes) {
      final colorFilter = pass.colorFilter;
      if (colorFilter != null) {
        result = colorFilter;
      }
    }
    return result;
  }

  /// Получить итоговый blend mode для цепочки (последний режим композиции).
  ui.BlendMode? resolveBlendMode(String id) {
    final passes = resolvePaintPasses(id);
    ui.BlendMode? result;
    for (final pass in passes) {
      final mode = pass.blendMode;
      if (mode != null) {
        result = mode;
      }
    }
    return result;
  }

  /// Получить все фильтры (flattened).
  List<SvgFilter> get all =>
      _filters.values.expand((filters) => filters).toList(growable: false);
}
