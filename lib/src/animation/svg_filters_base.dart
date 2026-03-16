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
/// В текущем пайплайне не выполняет растеризованное тайлинг-повторение, но
/// сохраняет граф зависимостей `in/result` и передаёт вход дальше по цепочке.
class SvgTileFilter extends SvgFilter {
  SvgTileFilter({required super.id, super.input, super.resultName})
    : super(type: SvgFilterType.tile);

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
