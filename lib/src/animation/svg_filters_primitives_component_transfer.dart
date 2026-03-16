part of 'svg_filters.dart';

/// Параметры одной channel-функции (`feFuncR/G/B/A`) для feComponentTransfer.
class SvgComponentTransferFunction {
  const SvgComponentTransferFunction({
    required this.type,
    this.tableValues = const <double>[],
    this.slope = 1.0,
    this.intercept = 0.0,
    this.amplitude = 1.0,
    this.exponent = 1.0,
    this.offset = 0.0,
  });

  final SvgComponentTransferType type;
  final List<double> tableValues;
  final double slope;
  final double intercept;
  final double amplitude;
  final double exponent;
  final double offset;
}

/// feComponentTransfer primitive
///
/// Baseline-поддержка хранит структуру channel-функций для parity-аудита.
/// До полноценного color-apply примитив ведет себя как pass-through.
class SvgComponentTransferFilter extends SvgFilter {
  final SvgComponentTransferFunction? funcR;
  final SvgComponentTransferFunction? funcG;
  final SvgComponentTransferFunction? funcB;
  final SvgComponentTransferFunction? funcA;

  SvgComponentTransferFilter({
    required super.id,
    this.funcR,
    this.funcG,
    this.funcB,
    this.funcA,
    super.input,
    super.resultName,
  }) : super(type: SvgFilterType.componentTransfer);

  @override
  ui.ImageFilter? apply() => null;
}
