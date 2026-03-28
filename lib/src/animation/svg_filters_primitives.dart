part of 'svg_filters.dart';

/// feConvolveMatrix primitive
///
/// Baseline-поддержка хранит параметры свертки для parity-аудита и графа.
/// До полноценной растерной реализации примитив ведет себя как pass-through.
class SvgConvolveMatrixFilter extends SvgFilter {
  /// Размер ядра свертки.
  final int orderX;
  final int orderY;

  /// Матрица свертки.
  final List<double> kernelMatrix;

  /// Нормализация и смещение результата.
  final double divisor;
  final double bias;

  /// Позиция целевого элемента ядра.
  final int targetX;
  final int targetY;

  /// Поведение на границе.
  final SvgConvolveEdgeMode edgeMode;

  /// Размер единицы ядра в user space (опционально).
  final double? kernelUnitLengthX;
  final double? kernelUnitLengthY;

  /// Сохранять альфу входа.
  final bool preserveAlpha;

  SvgConvolveMatrixFilter({
    required super.id,
    required this.orderX,
    required this.orderY,
    required this.kernelMatrix,
    required this.divisor,
    required this.bias,
    required this.targetX,
    required this.targetY,
    required this.edgeMode,
    this.kernelUnitLengthX,
    this.kernelUnitLengthY,
    this.preserveAlpha = false,
    super.input,
    super.resultName,
  }) : super(type: SvgFilterType.convolveMatrix);

  @override
  ui.ImageFilter? apply() => null;
}
