import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:xml/xml.dart';

import 'css_animations.dart';
import 'css_named_colors.dart';
import 'svg_dom.dart';
import 'svg_filters.dart';

/// Парсер SVG XML в DOM-дерево
///
/// Преобразует XML строку в структуру [SvgDocument] с деревом [SvgNode].
/// В отличие от vector_graphics_compiler, сохраняет полную DOM-структуру,
/// включая анимационные элементы (<animate>, <animateTransform>, etc.)
class SvgParser {
  SvgParser._();

  /// Парсит SVG XML строку в документ
  static SvgDocument parse(String svgXml) {
    final document = XmlDocument.parse(svgXml);
    final svgElement = document.findElements('svg').first;

    // Парсим фильтры из <defs><filter>...</filter></defs>
    final filters = _parseFilters(svgElement);

    // Парсим CSS <style> элементы для @keyframes
    final keyframes = _parseStyleElements(svgElement);

    // Парсим CSS правила для селекторов (id, class)
    final selectorRules = _parseSelectorRulesElements(svgElement);

    // Парсим корневой <svg> элемент
    final rootNode = _parseElement(svgElement);

    // Извлекаем viewBox, width, height из корневого элемента
    final viewBox = _parseViewBox(svgElement.getAttribute('viewBox'));
    final width = _parseLength(svgElement.getAttribute('width'));
    final height = _parseLength(svgElement.getAttribute('height'));

    final svgDocument = SvgDocument(
      root: rootNode,
      viewBox: viewBox,
      width: width,
      height: height,
      filters: filters,
      cssKeyframes: keyframes,
      cssSelectorRules: selectorRules,
    );

    return svgDocument;
  }

  /// Парсит фильтры из <defs><filter> элементов
  static SvgFilters _parseFilters(XmlElement svgElement) {
    final filters = SvgFilters();

    // Ищем <defs> элемент
    final defsElements = svgElement.findElements('defs');
    if (defsElements.isEmpty) {
      return filters;
    }

    final defs = defsElements.first;

    // Ищем все <filter> элементы
    for (final filterElement in defs.findElements('filter')) {
      final filterId = filterElement.getAttribute('id');
      if (filterId == null || filterId.isEmpty) {
        continue; // Фильтр без ID не может быть использован
      }

      // Парсим примитивы фильтра (feGaussianBlur, feDropShadow, etc.)
      for (final child in filterElement.childElements) {
        final filter = _parseFilterPrimitive(child, filterId);
        if (filter != null) {
          filters.add(filter);
        }
      }
    }

    return filters;
  }

  /// Парсит примитив фильтра (feGaussianBlur, feDropShadow, feColorMatrix)
  static SvgFilter? _parseFilterPrimitive(XmlElement element, String filterId) {
    final tagName = element.name.local;

    switch (tagName) {
      case 'feGaussianBlur':
        return _parseGaussianBlur(element, filterId);
      case 'feMorphology':
        return _parseMorphology(element, filterId);
      case 'feDisplacementMap':
        return _parseDisplacementMap(element, filterId);
      case 'feImage':
        return _parseFeImage(element, filterId);
      case 'feConvolveMatrix':
        return _parseConvolveMatrix(element, filterId);
      case 'feTurbulence':
        return _parseTurbulence(element, filterId);
      case 'feComponentTransfer':
        return _parseComponentTransfer(element, filterId);
      case 'feDiffuseLighting':
        return _parseDiffuseLighting(element, filterId);
      case 'feSpecularLighting':
        return _parseSpecularLighting(element, filterId);
      case 'feOffset':
        return _parseOffset(element, filterId);
      case 'feFlood':
        return _parseFlood(element, filterId);
      case 'feBlend':
        return _parseBlend(element, filterId);
      case 'feComposite':
        return _parseComposite(element, filterId);
      case 'feMerge':
        return _parseMerge(element, filterId);
      case 'feTile':
        return _parseTile(element, filterId);
      case 'feDropShadow':
        return _parseDropShadow(element, filterId);
      case 'feColorMatrix':
        return _parseColorMatrix(element, filterId);
      default:
        // Другие фильтры пока не поддерживаются
        return null;
    }
  }

  /// Парсит feGaussianBlur элемент
  static SvgGaussianBlurFilter _parseGaussianBlur(
    XmlElement element,
    String filterId,
  ) {
    final stdDeviationStr = element.getAttribute('stdDeviation') ?? '0';
    final stdDeviation = _parseNumberOptionalNumber(stdDeviationStr);
    final input = _normalizeFilterInput(element.getAttribute('in'));
    final resultName = _normalizeFilterResult(element.getAttribute('result'));

    return SvgGaussianBlurFilter(
      id: filterId,
      stdDeviationX: stdDeviation.$1,
      stdDeviationY: stdDeviation.$2,
      input: input,
      resultName: resultName,
    );
  }

  /// Парсит feMorphology элемент
  static SvgMorphologyFilter _parseMorphology(
    XmlElement element,
    String filterId,
  ) {
    final operatorRaw = element.getAttribute('operator')?.trim().toLowerCase();
    final operatorType = operatorRaw == 'dilate'
        ? SvgMorphologyOperator.dilate
        : SvgMorphologyOperator.erode;
    final radiusRaw = element.getAttribute('radius') ?? '0';
    final radius = _parseNumberOptionalNumber(radiusRaw);
    final input = _normalizeFilterInput(element.getAttribute('in'));
    final resultName = _normalizeFilterResult(element.getAttribute('result'));

    return SvgMorphologyFilter(
      id: filterId,
      operatorType: operatorType,
      radiusX: radius.$1,
      radiusY: radius.$2,
      input: input,
      resultName: resultName,
    );
  }

  /// Парсит feDisplacementMap элемент
  static SvgDisplacementMapFilter _parseDisplacementMap(
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
  static SvgFeImageFilter _parseFeImage(XmlElement element, String filterId) {
    final rawHref =
        element.getAttribute('href') ?? element.getAttribute('xlink:href');
    final href = rawHref?.trim();

    return SvgFeImageFilter(
      id: filterId,
      href: (href == null || href.isEmpty) ? null : href,
      x: _parseNumber(element.getAttribute('x') ?? '0'),
      y: _parseNumber(element.getAttribute('y') ?? '0'),
      width: _parseNumber(element.getAttribute('width') ?? '0'),
      height: _parseNumber(element.getAttribute('height') ?? '0'),
      preserveAspectRatio: _normalizeFilterResult(
        element.getAttribute('preserveAspectRatio'),
      ),
      input: _normalizeFilterInput(element.getAttribute('in')),
      resultName: _normalizeFilterResult(element.getAttribute('result')),
    );
  }

  /// Парсит feConvolveMatrix элемент
  static SvgConvolveMatrixFilter _parseConvolveMatrix(
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
  static SvgTurbulenceFilter _parseTurbulence(
    XmlElement element,
    String filterId,
  ) {
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
  static SvgComponentTransferFilter _parseComponentTransfer(
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

  static SvgComponentTransferFunction _parseComponentTransferFunction(
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

  /// Парсит feDiffuseLighting элемент
  static SvgDiffuseLightingFilter _parseDiffuseLighting(
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
  static SvgSpecularLightingFilter _parseSpecularLighting(
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

  static ui.Color _parseLightingColor(XmlElement element) {
    final parsedLightingColor = _parseColor(
      element.getAttribute('lighting-color') ??
          element.getAttribute('lightingColor') ??
          'white',
    );
    return parsedLightingColor is ui.Color
        ? parsedLightingColor
        : const ui.Color(0xFFFFFFFF);
  }

  static SvgLightSource? _parseLightingLightSource(XmlElement element) {
    for (final child in element.childElements) {
      switch (child.name.local) {
        case 'feDistantLight':
          return SvgDistantLightSource(
            azimuth: _parseNumber(child.getAttribute('azimuth') ?? '0'),
            elevation: _parseNumber(child.getAttribute('elevation') ?? '0'),
          );
        case 'fePointLight':
          return SvgPointLightSource(
            x: _parseNumber(child.getAttribute('x') ?? '0'),
            y: _parseNumber(child.getAttribute('y') ?? '0'),
            z: _parseNumber(child.getAttribute('z') ?? '0'),
          );
        case 'feSpotLight':
          return SvgSpotLightSource(
            x: _parseNumber(child.getAttribute('x') ?? '0'),
            y: _parseNumber(child.getAttribute('y') ?? '0'),
            z: _parseNumber(child.getAttribute('z') ?? '0'),
            pointsAtX: _parseNumber(child.getAttribute('pointsAtX') ?? '0'),
            pointsAtY: _parseNumber(child.getAttribute('pointsAtY') ?? '0'),
            pointsAtZ: _parseNumber(child.getAttribute('pointsAtZ') ?? '0'),
            specularExponent: _parseNumber(
              child.getAttribute('specularExponent') ?? '1',
            ).clamp(1.0, 128.0).toDouble(),
            limitingConeAngle: _parseNumber(
              child.getAttribute('limitingConeAngle') ?? '0',
            ),
          );
      }
    }
    return null;
  }

  static (double?, double?) _parseLightingKernelUnitLength(XmlElement element) {
    final raw = element.getAttribute('kernelUnitLength');
    if (raw == null || raw.trim().isEmpty) {
      return (null, null);
    }
    final parsed = _parseNumberOptionalNumber(raw);
    if (parsed.$1 <= 0 || parsed.$2 <= 0) {
      return (null, null);
    }
    return (parsed.$1, parsed.$2);
  }

  /// Парсит feDropShadow элемент
  static SvgDropShadowFilter _parseDropShadow(
    XmlElement element,
    String filterId,
  ) {
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
  static SvgOffsetFilter _parseOffset(XmlElement element, String filterId) {
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
  static SvgFloodFilter _parseFlood(XmlElement element, String filterId) {
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
  static SvgBlendFilter _parseBlend(XmlElement element, String filterId) {
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
  static SvgCompositeFilter _parseComposite(
    XmlElement element,
    String filterId,
  ) {
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
  static SvgColorMatrixFilter _parseColorMatrix(
    XmlElement element,
    String filterId,
  ) {
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
  static SvgMergeFilter _parseMerge(XmlElement element, String filterId) {
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
  static SvgTileFilter _parseTile(XmlElement element, String filterId) {
    return SvgTileFilter(
      id: filterId,
      input: _normalizeFilterInput(element.getAttribute('in')),
      resultName: _normalizeFilterResult(element.getAttribute('result')),
    );
  }

  static String? _normalizeFilterInput(String? raw) {
    final normalized = raw?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  static String? _normalizeFilterResult(String? raw) {
    final normalized = raw?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  static String? _getFilterPrimitiveAttributeOrStyleValue(
    XmlElement element, {
    required List<String> attributeNames,
    required List<String> styleNames,
    required Map<String, String> styleDeclarations,
  }) {
    for (final styleName in styleNames) {
      final styleValue = styleDeclarations[styleName.toLowerCase()]?.trim();
      if (styleValue != null && styleValue.isNotEmpty) {
        return styleValue;
      }
    }

    for (final attributeName in attributeNames) {
      final attributeValue = element.getAttribute(attributeName)?.trim();
      if (attributeValue != null && attributeValue.isNotEmpty) {
        return attributeValue;
      }
    }

    return null;
  }

  static Map<String, String> _parseInlineStyleDeclarations(String? rawStyle) {
    if (rawStyle == null || rawStyle.trim().isEmpty) {
      return const <String, String>{};
    }

    final declarations = <String, String>{};
    for (final entry in rawStyle.split(';')) {
      final separator = entry.indexOf(':');
      if (separator <= 0) {
        continue;
      }
      final key = entry.substring(0, separator).trim().toLowerCase();
      if (key.isEmpty) {
        continue;
      }
      final value = _stripImportantSuffix(entry.substring(separator + 1));
      if (value.isEmpty) {
        continue;
      }
      declarations[key] = value;
    }

    return declarations;
  }

  static String _stripImportantSuffix(String rawValue) {
    final trimmed = rawValue.trim();
    final lowercase = trimmed.toLowerCase();
    final importantIndex = lowercase.lastIndexOf('!important');
    if (importantIndex < 0) {
      return trimmed;
    }
    return trimmed.substring(0, importantIndex).trim();
  }

  static SvgChannelSelector _parseChannelSelector(String raw) {
    switch (raw.trim().toUpperCase()) {
      case 'R':
        return SvgChannelSelector.r;
      case 'G':
        return SvgChannelSelector.g;
      case 'B':
        return SvgChannelSelector.b;
      case 'A':
      default:
        return SvgChannelSelector.a;
    }
  }

  static SvgConvolveEdgeMode _parseConvolveEdgeMode(String? raw) {
    switch (raw?.trim().toLowerCase()) {
      case 'wrap':
        return SvgConvolveEdgeMode.wrap;
      case 'none':
        return SvgConvolveEdgeMode.none;
      case 'duplicate':
      default:
        return SvgConvolveEdgeMode.duplicate;
    }
  }

  static SvgTurbulenceType _parseTurbulenceType(String? raw) {
    switch (raw?.trim().toLowerCase()) {
      case 'fractalnoise':
        return SvgTurbulenceType.fractalNoise;
      case 'turbulence':
      default:
        return SvgTurbulenceType.turbulence;
    }
  }

  static SvgTurbulenceStitchTiles _parseTurbulenceStitchTiles(String? raw) {
    switch (raw?.trim().toLowerCase()) {
      case 'stitch':
        return SvgTurbulenceStitchTiles.stitch;
      case 'nostitch':
      default:
        return SvgTurbulenceStitchTiles.noStitch;
    }
  }

  static SvgComponentTransferType _parseComponentTransferType(String? raw) {
    switch (raw?.trim().toLowerCase()) {
      case 'table':
        return SvgComponentTransferType.table;
      case 'discrete':
        return SvgComponentTransferType.discrete;
      case 'linear':
        return SvgComponentTransferType.linear;
      case 'gamma':
        return SvgComponentTransferType.gamma;
      case 'identity':
      default:
        return SvgComponentTransferType.identity;
    }
  }

  static bool _parseSvgBoolean(String? raw) {
    if (raw == null) {
      return false;
    }
    switch (raw.trim().toLowerCase()) {
      case '1':
      case 'true':
      case 'yes':
        return true;
      default:
        return false;
    }
  }

  static int _parseIntWithDefault(String? raw, int fallback) {
    if (raw == null || raw.trim().isEmpty) {
      return fallback;
    }
    final parsed = double.tryParse(raw.trim());
    if (parsed == null) {
      return fallback;
    }
    return parsed.round();
  }

  /// Парсит CSS <style> элементы и извлекает @keyframes
  static List<CssKeyframes> _parseStyleElements(XmlElement svgElement) {
    final keyframes = <CssKeyframes>[];

    // Ищем все <style> элементы
    final styleElements = svgElement.findElements('style');

    for (final styleElement in styleElements) {
      final cssText = styleElement.innerText;
      if (cssText.isEmpty) continue;

      // Парсим @keyframes из CSS текста
      final parsedKeyframes = CssParser.parseKeyframes(cssText);
      keyframes.addAll(parsedKeyframes);
    }

    return keyframes;
  }

  /// Парсит CSS <style> элементы и извлекает правила для селекторов
  static List<CssSelectorRule> _parseSelectorRulesElements(
    XmlElement svgElement,
  ) {
    final rules = <CssSelectorRule>[];

    final styleElements = svgElement.findElements('style');

    for (final styleElement in styleElements) {
      final cssText = styleElement.innerText;
      if (cssText.isEmpty) continue;

      final parsedRules = CssParser.parseSelectorRules(cssText);
      rules.addAll(parsedRules);
    }

    return rules;
  }

  /// Парсит число или пару чисел (например "5" или "5 10")
  static (double, double) _parseNumberOptionalNumber(String value) {
    final parts = value
        .trim()
        .split(RegExp(r'[\s,]+'))
        .map((s) => double.tryParse(s))
        .whereType<double>()
        .toList();

    if (parts.isEmpty) {
      return (0.0, 0.0);
    } else if (parts.length == 1) {
      return (parts[0], parts[0]);
    } else {
      return (parts[0], parts[1]);
    }
  }

  /// Парсит XML элемент в SvgNode
  static SvgNode _parseElement(XmlElement element) {
    final tagName = element.name.local;
    final id = element.getAttribute('id');
    final className = element.getAttribute('class');

    final node = SvgNode(tagName: tagName, id: id, className: className);

    // Парсим атрибуты
    for (final attr in element.attributes) {
      final attrName = attr.name.local;
      final attrValue = attr.value;

      // Пропускаем специальные атрибуты, которые уже обработаны
      if (attrName == 'id' || attrName == 'class') {
        continue;
      }

      // Определяем тип атрибута и парсим значение
      // Для анимационных элементов fill - это режим заполнения, не цвет
      final isAnimationElement = _isAnimationElement(tagName);
      final attributeType = _inferAttributeType(attrName, isAnimationElement);
      final parsedValue = _parseAttributeValue(attrValue, attributeType);

      node.setAttribute(attrName, parsedValue, type: attributeType);
    }

    // Сохраняем прямой текстовый контент для текстовых узлов.
    if (tagName == 'text' || tagName == 'tspan' || tagName == 'textPath') {
      final directText = _extractDirectText(element);
      if (directText != null) {
        node.setAttribute('__text', directText, type: SvgAttributeType.string);
      }
    }

    // Рекурсивно парсим дочерние элементы
    for (final child in element.childElements) {
      // Пропускаем <style> элементы - они обрабатываются отдельно
      if (child.name.local == 'style') {
        continue; // CSS parsing будет позже
      }
      final childNode = _parseElement(child);
      node.addChild(childNode);
    }

    return node;
  }

  static String? _extractDirectText(XmlElement element) {
    final raw = element.children
        .whereType<XmlText>()
        .map((n) => n.value)
        .join();
    if (raw.trim().isEmpty) {
      return null;
    }
    final normalized = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    return normalized.isEmpty ? null : normalized;
  }

  /// Определяет тип атрибута по его имени
  static SvgAttributeType _inferAttributeType(
    String attributeName, [
    bool isAnimationElement = false,
  ]) {
    // Для анимационных элементов fill/calcMode/etc - это строки, не цвета
    if (isAnimationElement &&
        (attributeName == 'fill' ||
            attributeName == 'calcMode' ||
            attributeName == 'additive' ||
            attributeName == 'accumulate')) {
      return SvgAttributeType.string;
    }

    // Числовые атрибуты
    if (_numericAttributes.contains(attributeName)) {
      return SvgAttributeType.number;
    }

    // Цветовые атрибуты
    if (_colorAttributes.contains(attributeName)) {
      return SvgAttributeType.color;
    }

    // Трансформации
    if (attributeName == 'transform') {
      return SvgAttributeType.transform;
    }

    // Path данные
    if (attributeName == 'd') {
      return SvgAttributeType.path;
    }

    // Points для polygon/polyline
    if (attributeName == 'points') {
      return SvgAttributeType.points;
    }

    // URL ссылки
    if (_urlAttributes.contains(attributeName)) {
      return SvgAttributeType.url;
    }

    // По умолчанию — строка
    return SvgAttributeType.string;
  }

  /// Парсит значение атрибута в соответствующий тип
  static Object _parseAttributeValue(String value, SvgAttributeType type) {
    switch (type) {
      case SvgAttributeType.number:
        return _parseNumber(value);
      case SvgAttributeType.color:
        return _parseColor(value);
      case SvgAttributeType.transform:
      case SvgAttributeType.path:
      case SvgAttributeType.points:
      case SvgAttributeType.string:
      case SvgAttributeType.url:
      case SvgAttributeType.list:
      case SvgAttributeType.length:
        // Пока возвращаем как строку, парсинг будет позже
        return value;
    }
  }

  /// Парсит числовое значение (может содержать единицы измерения)
  static double _parseNumber(String value) {
    // Убираем единицы измерения и пробелы
    final cleaned = value.trim().replaceAll(RegExp(r'[a-zA-Z%]+$'), '');
    return double.tryParse(cleaned) ?? 0.0;
  }

  /// Парсит цвет
  static Object _parseColor(String value) {
    final trimmed = value.trim().toLowerCase();

    // paint servers, e.g. url(#gradientId)
    if (trimmed.startsWith('url(')) {
      return value.trim();
    }

    // Пока возвращаем строку, позже добавим полный парсинг
    // #RGB, #RRGGBB, rgb(), rgba(), named colors, etc.
    if (trimmed == 'none' || trimmed == 'transparent') {
      return ui.Color(0x00000000);
    }

    // Именованные цвета (базовые)
    if (_namedColors.containsKey(trimmed)) {
      return _namedColors[trimmed]!;
    }

    // #RGB/#RGBA/#RRGGBB/#RRGGBBAA
    if (trimmed.startsWith('#')) {
      return _parseHexColor(trimmed);
    }

    // rgb()/rgba()
    final rgbColor = _parseRgbColor(trimmed);
    if (rgbColor != null) {
      return rgbColor;
    }

    // hsl()/hsla()
    final hslColor = _parseHslColor(trimmed);
    if (hslColor != null) {
      return hslColor;
    }

    // Неподдерживаемый формат -> чёрный (baseline fallback)
    return const ui.Color(0xFF000000);
  }

  /// Парсит hex цвет
  static ui.Color _parseHexColor(String hex) {
    var cleaned = hex.substring(1); // убираем #

    // #RGB -> #RRGGBB
    if (cleaned.length == 3) {
      cleaned = cleaned.split('').map((c) => c + c).join();
    }

    // #RGBA -> #RRGGBBAA
    if (cleaned.length == 4) {
      cleaned = cleaned.split('').map((c) => c + c).join();
    }

    // #RRGGBB
    if (cleaned.length == 6) {
      final value = int.tryParse('FF$cleaned', radix: 16);
      return ui.Color(value ?? 0xFF000000);
    }

    // #RRGGBBAA
    if (cleaned.length == 8) {
      final parsed = int.tryParse(cleaned, radix: 16);
      if (parsed == null) {
        return const ui.Color(0xFF000000);
      }

      final r = (parsed >> 24) & 0xFF;
      final g = (parsed >> 16) & 0xFF;
      final b = (parsed >> 8) & 0xFF;
      final a = parsed & 0xFF;
      return ui.Color((a << 24) | (r << 16) | (g << 8) | b);
    }

    return const ui.Color(0xFF000000);
  }

  static ui.Color? _parseRgbColor(String value) {
    final match = RegExp(r'^rgba?\(\s*(.+)\s*\)$').firstMatch(value);
    if (match == null) {
      return null;
    }

    final args = _parseColorFunctionArgs(match.group(1)!);
    if (args.length < 3) {
      return null;
    }

    double alpha = 1.0;
    late final int r;
    late final int g;
    late final int b;

    if (args.contains('/')) {
      final slashIndex = args.indexOf('/');
      if (slashIndex != 3 || args.length != 5) {
        return null;
      }
      r = _parseRgbChannel(args[0]);
      g = _parseRgbChannel(args[1]);
      b = _parseRgbChannel(args[2]);
      alpha = _parseAlpha(args[4]);
    } else {
      if (args.length < 3) {
        return null;
      }
      r = _parseRgbChannel(args[0]);
      g = _parseRgbChannel(args[1]);
      b = _parseRgbChannel(args[2]);
      if (args.length >= 4) {
        alpha = _parseAlpha(args[3]);
      }
    }

    return _colorFromRgba(r, g, b, alpha);
  }

  static ui.Color? _parseHslColor(String value) {
    final match = RegExp(r'^hsla?\(\s*(.+)\s*\)$').firstMatch(value);
    if (match == null) {
      return null;
    }

    final args = _parseColorFunctionArgs(match.group(1)!);
    if (args.length < 3) {
      return null;
    }

    double alpha = 1.0;
    late final double hue;
    late final double saturation;
    late final double lightness;

    if (args.contains('/')) {
      final slashIndex = args.indexOf('/');
      if (slashIndex != 3 || args.length != 5) {
        return null;
      }
      hue = _parseHueDegrees(args[0]);
      saturation = _parseFraction(args[1]);
      lightness = _parseFraction(args[2]);
      alpha = _parseAlpha(args[4]);
    } else {
      hue = _parseHueDegrees(args[0]);
      saturation = _parseFraction(args[1]);
      lightness = _parseFraction(args[2]);
      if (args.length >= 4) {
        alpha = _parseAlpha(args[3]);
      }
    }

    return _hslToColor(hue, saturation, lightness, alpha);
  }

  static List<String> _parseColorFunctionArgs(String input) {
    if (input.contains(',')) {
      return input
          .split(',')
          .map((part) => part.trim())
          .where((part) => part.isNotEmpty)
          .toList();
    }

    return input
        .replaceAll('/', ' / ')
        .split(RegExp(r'\s+'))
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
  }

  static int _parseRgbChannel(String input) {
    final value = input.trim();
    if (value.endsWith('%')) {
      final percent =
          double.tryParse(value.substring(0, value.length - 1)) ?? 0.0;
      final normalized = percent.clamp(0.0, 100.0) / 100.0;
      return (normalized * 255).round();
    }

    final number = double.tryParse(value) ?? 0.0;
    return number.clamp(0.0, 255.0).round();
  }

  static double _parseAlpha(String input) {
    final value = input.trim();
    if (value.endsWith('%')) {
      final percent =
          double.tryParse(value.substring(0, value.length - 1)) ?? 0.0;
      return (percent.clamp(0.0, 100.0) / 100.0).toDouble();
    }

    final alpha = double.tryParse(value) ?? 1.0;
    return alpha.clamp(0.0, 1.0).toDouble();
  }

  static double _parseFraction(String input) {
    final value = input.trim();
    if (value.endsWith('%')) {
      final percent =
          double.tryParse(value.substring(0, value.length - 1)) ?? 0.0;
      return (percent.clamp(0.0, 100.0) / 100.0).toDouble();
    }

    final number = double.tryParse(value) ?? 0.0;
    return number.clamp(0.0, 1.0).toDouble();
  }

  static double _parseHueDegrees(String input) {
    final match = RegExp(
      r'^([+-]?(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?)\s*(deg|rad|turn|grad)?$',
      caseSensitive: false,
    ).firstMatch(input.trim());
    if (match == null) {
      return 0.0;
    }

    final value = double.tryParse(match.group(1) ?? '') ?? 0.0;
    final unit = (match.group(2) ?? 'deg').toLowerCase();
    return switch (unit) {
      'deg' => value,
      'rad' => value * 180.0 / math.pi,
      'turn' => value * 360.0,
      'grad' => value * 0.9,
      _ => value,
    };
  }

  static ui.Color _colorFromRgba(int r, int g, int b, double alpha) {
    final a = (alpha.clamp(0.0, 1.0) * 255).round();
    return ui.Color((a << 24) | (r << 16) | (g << 8) | b);
  }

  static ui.Color _hslToColor(
    double hueDegrees,
    double saturation,
    double lightness,
    double alpha,
  ) {
    final h = ((hueDegrees % 360.0) + 360.0) % 360.0 / 360.0;
    final s = saturation.clamp(0.0, 1.0).toDouble();
    final l = lightness.clamp(0.0, 1.0).toDouble();

    if (s == 0.0) {
      final gray = (l * 255).round();
      return _colorFromRgba(gray, gray, gray, alpha);
    }

    final q = l < 0.5 ? l * (1 + s) : l + s - l * s;
    final p = 2 * l - q;
    final r = _hueToRgb(p, q, h + (1 / 3));
    final g = _hueToRgb(p, q, h);
    final b = _hueToRgb(p, q, h - (1 / 3));
    return _colorFromRgba(
      (r * 255).round(),
      (g * 255).round(),
      (b * 255).round(),
      alpha,
    );
  }

  static double _hueToRgb(double p, double q, double t) {
    var adjusted = t;
    if (adjusted < 0) adjusted += 1;
    if (adjusted > 1) adjusted -= 1;

    if (adjusted < 1 / 6) {
      return p + (q - p) * 6 * adjusted;
    }
    if (adjusted < 1 / 2) {
      return q;
    }
    if (adjusted < 2 / 3) {
      return p + (q - p) * (2 / 3 - adjusted) * 6;
    }
    return p;
  }

  /// Парсит viewBox атрибут
  static ui.Rect? _parseViewBox(String? viewBox) {
    if (viewBox == null || viewBox.isEmpty) {
      return null;
    }

    final parts = viewBox
        .trim()
        .split(RegExp(r'[\s,]+'))
        .map((s) => double.tryParse(s))
        .whereType<double>()
        .toList();

    if (parts.length == 4) {
      return ui.Rect.fromLTWH(parts[0], parts[1], parts[2], parts[3]);
    }

    return null;
  }

  /// Парсит длину (может быть число, px, em, %, etc.)
  static double? _parseLength(String? length) {
    if (length == null || length.isEmpty) {
      return null;
    }

    return _parseNumber(length);
  }

  // Множества известных атрибутов по категориям

  static const Set<String> _numericAttributes = {
    'x',
    'y',
    'cx',
    'cy',
    'r',
    'rx',
    'ry',
    'width',
    'height',
    'x1',
    'y1',
    'x2',
    'y2',
    'opacity',
    'fill-opacity',
    'stroke-opacity',
    'stroke-width',
    'stroke-miterlimit',
    'stroke-dashoffset',
    'font-size',
    'letter-spacing',
    'word-spacing',
    'textLength',
    'offset',
  };

  static const Set<String> _colorAttributes = {
    'fill',
    'stroke',
    'stop-color',
    'flood-color',
    'lighting-color',
  };

  /// Проверяет, является ли элемент анимационным
  static bool _isAnimationElement(String tagName) {
    return tagName == 'animate' ||
        tagName == 'animateTransform' ||
        tagName == 'animateMotion' ||
        tagName == 'set' ||
        tagName == 'animateColor';
  }

  static const Set<String> _urlAttributes = {
    'href',
    'xlink:href',
    'clip-path',
    'mask',
    'filter',
  };

  static const Map<String, ui.Color> _namedColors = cssNamedColors;
}
