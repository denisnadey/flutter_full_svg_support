part of 'svg_parser.dart';

/// Парсит feDiffuseLighting элемент
SvgDiffuseLightingFilter _parseDiffuseLighting(
  XmlElement element,
  String filterId,
) {
  final kernelUnitLength = _parseLightingKernelUnitLength(element);

  return SvgDiffuseLightingFilter(
    id: filterId,
    x: _parseNumber(element.getAttribute('x') ?? '0'),
    y: _parseNumber(element.getAttribute('y') ?? '0'),
    width: _parseNumber(element.getAttribute('width') ?? '0'),
    height: _parseNumber(element.getAttribute('height') ?? '0'),
    surfaceScale: _parseNumber(element.getAttribute('surfaceScale') ?? '1'),
    diffuseConstant: _parseNumber(
      element.getAttribute('diffuseConstant') ?? '1',
    ),
    kernelUnitLengthX: kernelUnitLength.$1,
    kernelUnitLengthY: kernelUnitLength.$2,
    lightingColor: _parseLightingColor(element),
    lightSource: _parseLightingLightSource(element),
    input: _normalizeFilterInput(element.getAttribute('in')),
    resultName: _normalizeFilterResult(element.getAttribute('result')),
  );
}

/// Парсит feSpecularLighting элемент
SvgSpecularLightingFilter _parseSpecularLighting(
  XmlElement element,
  String filterId,
) {
  final kernelUnitLength = _parseLightingKernelUnitLength(element);

  return SvgSpecularLightingFilter(
    id: filterId,
    x: _parseNumber(element.getAttribute('x') ?? '0'),
    y: _parseNumber(element.getAttribute('y') ?? '0'),
    width: _parseNumber(element.getAttribute('width') ?? '0'),
    height: _parseNumber(element.getAttribute('height') ?? '0'),
    surfaceScale: _parseNumber(element.getAttribute('surfaceScale') ?? '1'),
    specularConstant: _parseNumber(
      element.getAttribute('specularConstant') ?? '1',
    ),
    specularExponent: _parseNumber(
      element.getAttribute('specularExponent') ?? '1',
    ).clamp(1.0, 128.0).toDouble(),
    kernelUnitLengthX: kernelUnitLength.$1,
    kernelUnitLengthY: kernelUnitLength.$2,
    lightingColor: _parseLightingColor(element),
    lightSource: _parseLightingLightSource(element),
    input: _normalizeFilterInput(element.getAttribute('in')),
    resultName: _normalizeFilterResult(element.getAttribute('result')),
  );
}

/// Парсит feDropShadow элемент
SvgDropShadowFilter _parseDropShadow(XmlElement element, String filterId) {
  final styleDeclarations = _parseInlineStyleDeclarations(
    element.getAttribute('style'),
  );
  final dx = _parseNumber(
    _getFilterPrimitiveAttributeOrStyleValue(
          element,
          attributeNames: const <String>['dx'],
          styleNames: const <String>['dx'],
          styleDeclarations: styleDeclarations,
        ) ??
        '2',
  );
  final dy = _parseNumber(
    _getFilterPrimitiveAttributeOrStyleValue(
          element,
          attributeNames: const <String>['dy'],
          styleNames: const <String>['dy'],
          styleDeclarations: styleDeclarations,
        ) ??
        '2',
  );
  final stdDeviationStr =
      _getFilterPrimitiveAttributeOrStyleValue(
        element,
        attributeNames: const <String>['stdDeviation'],
        styleNames: const <String>['stddeviation', 'std-deviation'],
        styleDeclarations: styleDeclarations,
      ) ??
      '2';
  final stdDeviation = _parseNumberOptionalNumber(stdDeviationStr);
  final input = _normalizeFilterInput(element.getAttribute('in'));
  final resultName = _normalizeFilterResult(element.getAttribute('result'));

  // Парсим flood-color
  final floodColorStr =
      _getFilterPrimitiveAttributeOrStyleValue(
        element,
        attributeNames: const <String>['flood-color', 'floodColor'],
        styleNames: const <String>['flood-color', 'floodcolor'],
        styleDeclarations: styleDeclarations,
      ) ??
      'black';
  final parsedColor = _parseColor(floodColorStr);
  final color = parsedColor is ui.Color ? parsedColor : null;
  final floodOpacity = _parseNumber(
    _getFilterPrimitiveAttributeOrStyleValue(
          element,
          attributeNames: const <String>['flood-opacity', 'floodOpacity'],
          styleNames: const <String>['flood-opacity', 'floodopacity'],
          styleDeclarations: styleDeclarations,
        ) ??
        '1',
  ).clamp(0.0, 1.0);

  return SvgDropShadowFilter(
    id: filterId,
    dx: dx,
    dy: dy,
    stdDeviationX: stdDeviation.$1,
    stdDeviationY: stdDeviation.$2,
    floodColor: color,
    floodOpacity: floodOpacity,
    input: input,
    resultName: resultName,
  );
}

/// Парсит feOffset элемент
SvgOffsetFilter _parseOffset(XmlElement element, String filterId) {
  final dx = _parseNumber(element.getAttribute('dx') ?? '0');
  final dy = _parseNumber(element.getAttribute('dy') ?? '0');
  final input = _normalizeFilterInput(element.getAttribute('in'));
  final resultName = _normalizeFilterResult(element.getAttribute('result'));

  return SvgOffsetFilter(
    id: filterId,
    dx: dx,
    dy: dy,
    input: input,
    resultName: resultName,
  );
}

/// Парсит feFlood элемент
SvgFloodFilter _parseFlood(XmlElement element, String filterId) {
  final styleDeclarations = _parseInlineStyleDeclarations(
    element.getAttribute('style'),
  );
  final floodColorStr =
      _getFilterPrimitiveAttributeOrStyleValue(
        element,
        attributeNames: const <String>['flood-color', 'floodColor'],
        styleNames: const <String>['flood-color', 'floodcolor'],
        styleDeclarations: styleDeclarations,
      ) ??
      'black';
  final parsedColor = _parseColor(floodColorStr);
  final floodColor = parsedColor is ui.Color
      ? parsedColor
      : const ui.Color(0xFF000000);
  final floodOpacity = _parseNumber(
    _getFilterPrimitiveAttributeOrStyleValue(
          element,
          attributeNames: const <String>['flood-opacity', 'floodOpacity'],
          styleNames: const <String>['flood-opacity', 'floodopacity'],
          styleDeclarations: styleDeclarations,
        ) ??
        '1',
  );

  return SvgFloodFilter(
    id: filterId,
    floodColor: floodColor,
    floodOpacity: floodOpacity.clamp(0.0, 1.0),
    resultName: _normalizeFilterResult(element.getAttribute('result')),
  );
}

/// Парсит feBlend элемент
SvgBlendFilter _parseBlend(XmlElement element, String filterId) {
  final mode = parseSvgBlendMode(element.getAttribute('mode'));
  return SvgBlendFilter(
    id: filterId,
    mode: mode,
    input: _normalizeFilterInput(element.getAttribute('in')),
    input2: _normalizeFilterInput(element.getAttribute('in2')),
    resultName: _normalizeFilterResult(element.getAttribute('result')),
  );
}

/// Парсит feComposite элемент
SvgCompositeFilter _parseComposite(XmlElement element, String filterId) {
  final operatorType = element.getAttribute('operator') ?? 'over';
  final mode = parseSvgCompositeOperator(operatorType);

  return SvgCompositeFilter(
    id: filterId,
    operatorType: operatorType,
    mode: mode,
    k1: _parseNumber(element.getAttribute('k1') ?? '0'),
    k2: _parseNumber(element.getAttribute('k2') ?? '0'),
    k3: _parseNumber(element.getAttribute('k3') ?? '0'),
    k4: _parseNumber(element.getAttribute('k4') ?? '0'),
    input: _normalizeFilterInput(element.getAttribute('in')),
    input2: _normalizeFilterInput(element.getAttribute('in2')),
    resultName: _normalizeFilterResult(element.getAttribute('result')),
  );
}

/// Парсит feColorMatrix элемент
SvgColorMatrixFilter _parseColorMatrix(XmlElement element, String filterId) {
  final typeStr = element.getAttribute('type') ?? 'matrix';
  final valuesStr = element.getAttribute('values') ?? '';

  SvgColorMatrixType matrixType;
  switch (typeStr.toLowerCase()) {
    case 'saturate':
      matrixType = SvgColorMatrixType.saturate;
      break;
    case 'huerotate':
    case 'hueRotate':
      matrixType = SvgColorMatrixType.hueRotate;
      break;
    case 'luminancetoalpha':
    case 'luminanceToAlpha':
      matrixType = SvgColorMatrixType.luminanceToAlpha;
      break;
    case 'matrix':
    default:
      matrixType = SvgColorMatrixType.matrix;
      break;
  }

  // Парсим values
  final values = valuesStr
      .split(RegExp(r'[\s,]+'))
      .map((s) => double.tryParse(s.trim()))
      .whereType<double>()
      .toList();

  return SvgColorMatrixFilter(
    id: filterId,
    matrixType: matrixType,
    values: values,
    input: _normalizeFilterInput(element.getAttribute('in')),
    resultName: _normalizeFilterResult(element.getAttribute('result')),
  );
}

/// Парсит feMerge элемент и его дочерние feMergeNode.
SvgMergeFilter _parseMerge(XmlElement element, String filterId) {
  final nodeInputs = <String?>[];

  for (final child in element.childElements) {
    if (child.name.local != 'feMergeNode') {
      continue;
    }
    final inAttr = child.getAttribute('in');
    final normalized = inAttr?.trim();
    nodeInputs.add(
      normalized == null || normalized.isEmpty ? null : normalized,
    );
  }

  return SvgMergeFilter(
    id: filterId,
    nodeInputs: nodeInputs,
    resultName: _normalizeFilterResult(element.getAttribute('result')),
  );
}

/// Парсит feTile элемент.
SvgTileFilter _parseTile(XmlElement element, String filterId) {
  return SvgTileFilter(
    id: filterId,
    input: _normalizeFilterInput(element.getAttribute('in')),
    resultName: _normalizeFilterResult(element.getAttribute('result')),
  );
}
