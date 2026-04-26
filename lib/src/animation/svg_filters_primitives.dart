part of 'svg_filters.dart';

/// feConvolveMatrix primitive
///
/// Baseline support stores convolution parameters for parity audit and graph.
/// Until a full raster implementation is available the primitive behaves as pass-through.
class SvgConvolveMatrixFilter extends SvgFilter {
  /// Convolution kernel size.
  final int orderX;
  final int orderY;

  /// Convolution kernel matrix.
  final List<double> kernelMatrix;

  /// Result normalization and bias.
  final double divisor;
  final double bias;

  /// Target kernel element position.
  final int targetX;
  final int targetY;

  /// Edge handling behavior.
  final SvgConvolveEdgeMode edgeMode;

  /// Kernel unit length in user space (optional).
  final double? kernelUnitLengthX;
  final double? kernelUnitLengthY;

  /// Preserve input alpha.
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
