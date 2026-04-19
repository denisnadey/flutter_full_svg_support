part of 'svg_parser.dart';

/// Парсит feGaussianBlur элемент
SvgGaussianBlurFilter _parseGaussianBlur(XmlElement element, String filterId) {
  final stdDeviationStr = element.getAttribute('stdDeviation') ?? '0';
  final stdDeviation = _parseNumberOptionalNumber(stdDeviationStr);
  final input = _normalizeFilterInput(element.getAttribute('in'));
  final resultName = _normalizeFilterResult(element.getAttribute('result'));
  final edgeMode = _parseConvolveEdgeMode(element.getAttribute('edgeMode'));

  return SvgGaussianBlurFilter(
    id: filterId,
    stdDeviationX: stdDeviation.$1,
    stdDeviationY: stdDeviation.$2,
    edgeMode: edgeMode,
    input: input,
    resultName: resultName,
  );
}

/// Парсит feMorphology элемент
SvgMorphologyFilter _parseMorphology(XmlElement element, String filterId) {
  final operatorRaw = element.getAttribute('operator')?.trim().toLowerCase();
  final operatorType = operatorRaw == 'dilate'
      ? SvgMorphologyOperator.dilate
      : SvgMorphologyOperator.erode;
  final radiusRaw = element.getAttribute('radius') ?? '0';
  final radius = _parseNumberOptionalNumber(radiusRaw);
  final input = _normalizeFilterInput(element.getAttribute('in'));
  final resultName = _normalizeFilterResult(element.getAttribute('result'));
  final edgeMode = _parseConvolveEdgeMode(element.getAttribute('edgeMode'));

  return SvgMorphologyFilter(
    id: filterId,
    operatorType: operatorType,
    radiusX: radius.$1,
    radiusY: radius.$2,
    edgeMode: edgeMode,
    input: input,
    resultName: resultName,
  );
}

/// Парсит feDisplacementMap элемент
SvgDisplacementMapFilter _parseDisplacementMap(
  XmlElement element,
  String filterId,
) {
  final scale = _parseNumber(element.getAttribute('scale') ?? '0');
  final xChannelSelector = _parseChannelSelector(
    element.getAttribute('xChannelSelector') ?? 'A',
  );
  final yChannelSelector = _parseChannelSelector(
    element.getAttribute('yChannelSelector') ?? 'A',
  );

  return SvgDisplacementMapFilter(
    id: filterId,
    scale: scale,
    xChannelSelector: xChannelSelector,
    yChannelSelector: yChannelSelector,
    input: _normalizeFilterInput(element.getAttribute('in')),
    input2: _normalizeFilterInput(element.getAttribute('in2')),
    resultName: _normalizeFilterResult(element.getAttribute('result')),
  );
}

/// Парсит feImage элемент
SvgFeImageFilter _parseFeImage(XmlElement element, String filterId) {
  final rawX = element.getAttribute('x')?.trim();
  final rawY = element.getAttribute('y')?.trim();
  final rawWidth = element.getAttribute('width')?.trim();
  final rawHeight = element.getAttribute('height')?.trim();
  final rawHref =
      element.getAttribute('href') ?? element.getAttribute('xlink:href');
  final href = rawHref?.trim();

  return SvgFeImageFilter(
    id: filterId,
    href: (href == null || href.isEmpty) ? null : href,
    x: _parseNumber(rawX ?? '0'),
    y: _parseNumber(rawY ?? '0'),
    width: _parseNumber(rawWidth ?? '0'),
    height: _parseNumber(rawHeight ?? '0'),
    xRaw: (rawX == null || rawX.isEmpty) ? null : rawX,
    yRaw: (rawY == null || rawY.isEmpty) ? null : rawY,
    widthRaw: (rawWidth == null || rawWidth.isEmpty) ? null : rawWidth,
    heightRaw: (rawHeight == null || rawHeight.isEmpty) ? null : rawHeight,
    preserveAspectRatio: _normalizeFilterResult(
      element.getAttribute('preserveAspectRatio'),
    ),
    input: _normalizeFilterInput(element.getAttribute('in')),
    resultName: _normalizeFilterResult(element.getAttribute('result')),
  );
}

/// Парсит feConvolveMatrix элемент
SvgConvolveMatrixFilter _parseConvolveMatrix(
  XmlElement element,
  String filterId,
) {
  final order = _parseNumberOptionalNumber(
    element.getAttribute('order') ?? '3',
  );
  final orderX = order.$1.round().clamp(1, 64).toInt();
  final orderY = order.$2.round().clamp(1, 64).toInt();

  final kernelMatrix = (element.getAttribute('kernelMatrix') ?? '')
      .split(RegExp(r'[\s,]+'))
      .map((part) => double.tryParse(part.trim()))
      .whereType<double>()
      .toList(growable: false);

  final divisorAttr = element.getAttribute('divisor');
  double divisor;
  if (divisorAttr == null || divisorAttr.trim().isEmpty) {
    final kernelSum = kernelMatrix.fold<double>(
      0.0,
      (sum, value) => sum + value,
    );
    divisor = kernelSum == 0.0 ? 1.0 : kernelSum;
  } else {
    divisor = _parseNumber(divisorAttr);
    if (divisor == 0.0) {
      divisor = 1.0;
    }
  }

  final bias = _parseNumber(element.getAttribute('bias') ?? '0');
  final targetXDefault = orderX ~/ 2;
  final targetYDefault = orderY ~/ 2;
  final targetX = _parseIntWithDefault(
    element.getAttribute('targetX'),
    targetXDefault,
  ).clamp(0, orderX - 1);
  final targetY = _parseIntWithDefault(
    element.getAttribute('targetY'),
    targetYDefault,
  ).clamp(0, orderY - 1);

  final kernelUnitLengthRaw = element.getAttribute('kernelUnitLength');
  double? kernelUnitLengthX;
  double? kernelUnitLengthY;
  if (kernelUnitLengthRaw != null && kernelUnitLengthRaw.trim().isNotEmpty) {
    final kernelUnitLength = _parseNumberOptionalNumber(kernelUnitLengthRaw);
    if (kernelUnitLength.$1 > 0 && kernelUnitLength.$2 > 0) {
      kernelUnitLengthX = kernelUnitLength.$1;
      kernelUnitLengthY = kernelUnitLength.$2;
    }
  }

  return SvgConvolveMatrixFilter(
    id: filterId,
    orderX: orderX,
    orderY: orderY,
    kernelMatrix: kernelMatrix,
    divisor: divisor,
    bias: bias,
    targetX: targetX.toInt(),
    targetY: targetY.toInt(),
    edgeMode: _parseConvolveEdgeMode(element.getAttribute('edgeMode')),
    kernelUnitLengthX: kernelUnitLengthX,
    kernelUnitLengthY: kernelUnitLengthY,
    preserveAlpha: _parseSvgBoolean(element.getAttribute('preserveAlpha')),
    input: _normalizeFilterInput(element.getAttribute('in')),
    resultName: _normalizeFilterResult(element.getAttribute('result')),
  );
}

/// Парсит feTurbulence элемент
SvgTurbulenceFilter _parseTurbulence(XmlElement element, String filterId) {
  final baseFrequency = _parseNumberOptionalNumber(
    element.getAttribute('baseFrequency') ?? '0',
  );

  return SvgTurbulenceFilter(
    id: filterId,
    baseFrequencyX: math.max(0.0, baseFrequency.$1),
    baseFrequencyY: math.max(0.0, baseFrequency.$2),
    numOctaves: _parseIntWithDefault(
      element.getAttribute('numOctaves'),
      1,
    ).clamp(1, 64).toInt(),
    seed: _parseNumber(element.getAttribute('seed') ?? '0'),
    stitchTiles: _parseTurbulenceStitchTiles(
      element.getAttribute('stitchTiles'),
    ),
    noiseType: _parseTurbulenceType(element.getAttribute('type')),
    input: _normalizeFilterInput(element.getAttribute('in')),
    resultName: _normalizeFilterResult(element.getAttribute('result')),
  );
}

/// Парсит feComponentTransfer элемент
SvgComponentTransferFilter _parseComponentTransfer(
  XmlElement element,
  String filterId,
) {
  SvgComponentTransferFunction? funcR;
  SvgComponentTransferFunction? funcG;
  SvgComponentTransferFunction? funcB;
  SvgComponentTransferFunction? funcA;

  for (final child in element.childElements) {
    switch (child.name.local) {
      case 'feFuncR':
        funcR = _parseComponentTransferFunction(child);
      case 'feFuncG':
        funcG = _parseComponentTransferFunction(child);
      case 'feFuncB':
        funcB = _parseComponentTransferFunction(child);
      case 'feFuncA':
        funcA = _parseComponentTransferFunction(child);
    }
  }

  return SvgComponentTransferFilter(
    id: filterId,
    funcR: funcR,
    funcG: funcG,
    funcB: funcB,
    funcA: funcA,
    input: _normalizeFilterInput(element.getAttribute('in')),
    resultName: _normalizeFilterResult(element.getAttribute('result')),
  );
}

SvgComponentTransferFunction _parseComponentTransferFunction(
  XmlElement element,
) {
  final tableValues = (element.getAttribute('tableValues') ?? '')
      .split(RegExp(r'[\s,]+'))
      .map((part) => double.tryParse(part.trim()))
      .whereType<double>()
      .toList(growable: false);

  return SvgComponentTransferFunction(
    type: _parseComponentTransferType(element.getAttribute('type')),
    tableValues: tableValues,
    slope: _parseNumber(element.getAttribute('slope') ?? '1'),
    intercept: _parseNumber(element.getAttribute('intercept') ?? '0'),
    amplitude: _parseNumber(element.getAttribute('amplitude') ?? '1'),
    exponent: _parseNumber(element.getAttribute('exponent') ?? '1'),
    offset: _parseNumber(element.getAttribute('offset') ?? '0'),
  );
}
