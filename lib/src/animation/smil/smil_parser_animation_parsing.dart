part of 'smil_parser.dart';

/// Parse an animation element
SmilAnimation? _parseAnimationElement(
  SvgNode animNode,
  SvgNode targetNode,
  SvgDocument document,
) {
  try {
    // Determine the animation type
    final type = _parseAnimationType(animNode.tagName);

    // animateMotion uses different logic - it has no attributeName
    if (type == SmilAnimationType.animateMotion) {
      return _parseAnimateMotion(animNode, targetNode, document);
    }

    // Get the name of the animated attribute
    final attributeName =
        animNode.getAttributeValue('attributeName') as String?;
    if (attributeName == null) {
      return null; // Without attributeName the animation is invalid
    }

    // Determine the attribute type
    final attributeType = _inferAttributeType(attributeName, targetNode);

    // For animateTransform, get the transform type (rotate, translate, etc.)
    String? transformType;
    if (type == SmilAnimationType.animateTransform) {
      transformType = animNode
          .getAttributeValue('type')
          ?.toString()
          .toLowerCase();
      if (transformType == null) {
        return null; // animateTransform without type is invalid
      }
    }

    // Parse animation values
    final from = _parseValue(
      animNode.getAttributeValue('from'),
      attributeType,
      transformType: transformType,
    );
    final to = _parseValue(
      animNode.getAttributeValue('to'),
      attributeType,
      transformType: transformType,
    );
    final by = _parseValue(
      animNode.getAttributeValue('by'),
      attributeType,
      transformType: transformType,
    );

    // Parse values and keyTimes
    List<Object>? values;
    List<double>? keyTimes;
    final valuesStr = animNode.getAttributeValue('values') as String?;
    if (valuesStr != null) {
      values = _parseValues(
        valuesStr,
        attributeType,
        transformType: transformType,
      );
    }

    final keyTimesStr = animNode.getAttributeValue('keyTimes') as String?;
    if (keyTimesStr != null) {
      keyTimes = _parseKeyTimes(keyTimesStr);
    }

    // Parse keySplines
    List<CubicBezier>? keySplines;
    final keySplinesStr = animNode.getAttributeValue('keySplines') as String?;
    if (keySplinesStr != null) {
      keySplines = _parseKeySplines(keySplinesStr);
    }

    // Parse animation ID (for syncbase timing)
    final id = animNode.id;

    // Parse timing
    final dur = _parseDuration(animNode.getAttributeValue('dur'));
    if (dur == null) {
      return null; // Without dur the animation is invalid
    }

    // Parse begin/end as timing conditions (syncbase support)
    var begin = Duration.zero;
    List<TimingCondition> beginConditions = [];
    final beginAttr = animNode.getAttributeValue('begin')?.toString();
    if (beginAttr != null) {
      beginConditions = TimingParser.parse(beginAttr);
      // If there is a simple offset condition, use it as begin
      if (beginConditions.length == 1 &&
          beginConditions.first is OffsetCondition) {
        begin = (beginConditions.first as OffsetCondition).offset;
        beginConditions = []; // Conditions are not needed for a simple offset
      }
    }

    Duration? end;
    List<TimingCondition> endConditions = [];
    final endAttr = animNode.getAttributeValue('end')?.toString();
    if (endAttr != null) {
      endConditions = TimingParser.parse(endAttr);
      // If there is a simple offset condition, use it as end
      if (endConditions.length == 1 && endConditions.first is OffsetCondition) {
        end = (endConditions.first as OffsetCondition).offset;
        endConditions = []; // Conditions are not needed for a simple offset
      }
    }

    // Parse repeatCount
    var repeatCount = 1.0;
    final repeatCountStr = animNode.getAttributeValue('repeatCount') as String?;
    if (repeatCountStr != null) {
      if (repeatCountStr == 'indefinite') {
        repeatCount = double.infinity;
      } else {
        repeatCount = double.tryParse(repeatCountStr) ?? 1.0;
      }
    }

    final repeatDur = _parseDuration(animNode.getAttributeValue('repeatDur'));

    // Parse modes - use toString() for safe conversion
    final fillMode = _parseFillMode(
      animNode.getAttributeValue('fill')?.toString(),
    );

    // Parse calcMode - auto-set to discrete for string-type attributes per SMIL spec
    final explicitCalcMode = animNode.getAttributeValue('calcMode')?.toString();
    SmilCalcMode calcMode;
    if (explicitCalcMode != null) {
      // Explicit calcMode specified - use it
      calcMode = _parseCalcMode(explicitCalcMode);
    } else if (_discreteAttributes.contains(attributeName) ||
        attributeType == SvgAttributeType.string ||
        attributeType == SvgAttributeType.url) {
      // Per SMIL spec: string-type attributes must use discrete calcMode
      calcMode = SmilCalcMode.discrete;
    } else {
      calcMode = SmilCalcMode.linear;
    }

    final additive = _parseAdditiveMode(
      animNode.getAttributeValue('additive')?.toString(),
    );
    final accumulate =
        animNode.getAttributeValue('accumulate')?.toString() == 'sum';

    return SmilAnimation(
      id: id,
      type: type,
      targetNode: targetNode,
      attributeName: attributeName,
      attributeType: attributeType,
      transformType: transformType,
      from: from,
      to: to,
      by: by,
      values: values,
      keyTimes: keyTimes,
      keySplines: keySplines,
      dur: dur,
      begin: begin,
      end: end,
      beginConditions: beginConditions,
      endConditions: endConditions,
      repeatCount: repeatCount,
      repeatDur: repeatDur,
      fillMode: fillMode,
      calcMode: calcMode,
      additive: additive,
      accumulate: accumulate,
    );
  } catch (_) {
    // Ignore invalid animations
    return null;
  }
}

/// Determine the animation type by tag name
SmilAnimationType _parseAnimationType(String tagName) {
  switch (tagName) {
    case 'animate':
      return SmilAnimationType.animate;
    case 'animateTransform':
      return SmilAnimationType.animateTransform;
    case 'animateMotion':
      return SmilAnimationType.animateMotion;
    case 'set':
      return SmilAnimationType.set;
    case 'animateColor':
      return SmilAnimationType.animateColor;
    default:
      return SmilAnimationType.animate;
  }
}

/// Determine the attribute type
SvgAttributeType _inferAttributeType(String attributeName, SvgNode targetNode) {
  // feColorMatrix animates its `values` list; this must be interpolated
  // numerically instead of treated as a discrete string.
  if (attributeName == 'values' && targetNode.tagName == 'feColorMatrix') {
    return SvgAttributeType.list;
  }

  // Check known attribute types first — these should always use their canonical
  // type for animation interpolation, regardless of how they're stored on the
  // node (e.g. filter primitive attributes may be stored as strings but need
  // numeric interpolation for smooth animation).
  if (_numberAttributes.contains(attributeName)) {
    return SvgAttributeType.number;
  }
  if (_colorAttributes.contains(attributeName)) {
    return SvgAttributeType.color;
  }
  if (attributeName == 'transform') {
    return SvgAttributeType.transform;
  }
  if (attributeName == 'd') {
    return SvgAttributeType.path;
  }
  if (attributeName == 'points') {
    return SvgAttributeType.points;
  }

  // Fallback: check existing attribute on node for unknown attributes
  final existingAttr = targetNode.getAttribute(attributeName);
  if (existingAttr != null) {
    return existingAttr.type;
  }

  return SvgAttributeType.string;
}

/// Parse a value according to its type
Object? _parseValue(
  Object? value,
  SvgAttributeType type, {
  String? transformType,
}) {
  if (value == null) {
    return null;
  }

  switch (type) {
    case SvgAttributeType.number:
    case SvgAttributeType.length:
      if (value is num) {
        return value.toDouble();
      }
      if (value is String) {
        final cleaned = value.trim().replaceAll(RegExp(r'[a-zA-Z%]+$'), '');
        return double.tryParse(cleaned);
      }
      return null;

    case SvgAttributeType.color:
      // Colors will be parsed by the interpolators
      return value;

    case SvgAttributeType.transform:
      // For animateTransform, wrap values in the transform type
      if (transformType != null) {
        return '$transformType($value)';
      }
      return value;

    default:
      return value;
  }
}

/// Parse the values list
List<Object> _parseValues(
  String valuesStr,
  SvgAttributeType type, {
  String? transformType,
}) {
  // values are separated by semicolons
  final parts = valuesStr
      .split(';')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty);

  final result = <Object>[];
  for (final part in parts) {
    final value = _parseValue(part, type, transformType: transformType);
    if (value != null) {
      result.add(value);
    }
  }

  return result;
}

/// Parse keyTimes
List<double> _parseKeyTimes(String keyTimesStr) {
  // keyTimes are separated by semicolons
  final parts = keyTimesStr
      .split(';')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty);

  final result = <double>[];
  for (final part in parts) {
    final value = double.tryParse(part);
    if (value != null) {
      result.add(value);
    }
  }

  return result;
}

/// Parse keySplines
List<CubicBezier> _parseKeySplines(String keySplinesStr) {
  // keySplines are separated by semicolons
  // Each spline: "x1 y1 x2 y2"
  final parts = keySplinesStr
      .split(';')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty);

  final result = <CubicBezier>[];
  for (final part in parts) {
    final numbers = part
        .split(RegExp(r'[\s,]+'))
        .map((s) => double.tryParse(s))
        .whereType<double>()
        .toList();

    if (numbers.length == 4) {
      result.add(CubicBezier(numbers[0], numbers[1], numbers[2], numbers[3]));
    }
  }

  return result;
}

/// Parse a duration value (dur, begin, end, repeatDur)
Duration? _parseDuration(Object? value) {
  if (value == null) {
    return null;
  }

  final str = value.toString().trim();

  // Formats:
  // - "2s" (seconds)
  // - "500ms" (milliseconds)
  // - "2.5s"
  // - "0:0:2" (hours:minutes:seconds)
  // - "indefinite" (returns null)

  if (str == 'indefinite') {
    return null;
  }

  // Seconds
  if (str.endsWith('s') && !str.endsWith('ms')) {
    final seconds = double.tryParse(str.substring(0, str.length - 1));
    if (seconds != null) {
      return Duration(microseconds: (seconds * 1000000).round());
    }
  }

  // Milliseconds
  if (str.endsWith('ms')) {
    final ms = double.tryParse(str.substring(0, str.length - 2));
    if (ms != null) {
      return Duration(microseconds: (ms * 1000).round());
    }
  }

  // Clock value (hours:minutes:seconds or minutes:seconds)
  if (str.contains(':')) {
    final parts = str.split(':').map((s) => double.tryParse(s)).toList();
    if (parts.every((p) => p != null)) {
      if (parts.length == 2) {
        // minutes:seconds
        return Duration(
          minutes: parts[0]!.toInt(),
          microseconds: (parts[1]! * 1000000).round(),
        );
      }
      if (parts.length == 3) {
        // hours:minutes:seconds
        return Duration(
          hours: parts[0]!.toInt(),
          minutes: parts[1]!.toInt(),
          microseconds: (parts[2]! * 1000000).round(),
        );
      }
    }
  }

  return null;
}

/// Parse fill mode
SmilFillMode _parseFillMode(String? value) {
  final str = value?.toLowerCase().trim();
  if (str == 'freeze') {
    return SmilFillMode.freeze;
  }
  return SmilFillMode.remove;
}

/// Parse calc mode
SmilCalcMode _parseCalcMode(String? value) {
  switch (value?.toLowerCase().trim()) {
    case 'discrete':
      return SmilCalcMode.discrete;
    case 'paced':
      return SmilCalcMode.paced;
    case 'spline':
      return SmilCalcMode.spline;
    default:
      return SmilCalcMode.linear;
  }
}

/// Parse additive mode
SmilAdditiveMode _parseAdditiveMode(String? value) {
  if (value?.toLowerCase().trim() == 'sum') {
    return SmilAdditiveMode.sum;
  }
  return SmilAdditiveMode.replace;
}

// Sets of known attributes
const Set<String> _numberAttributes = {
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
  'stroke-dashoffset',
  'stop-opacity',
  'stroke-miterlimit',
  'font-size',
  'letter-spacing',
  'word-spacing',
  'textLength',
  'offset',
  // Light source attributes (feDistantLight, fePointLight, feSpotLight)
  'azimuth',
  'elevation',
  'z',
  'pointsAtX',
  'pointsAtY',
  'pointsAtZ',
  'specularExponent',
  'limitingConeAngle',
  // Lighting filter attributes
  'surfaceScale',
  'diffuseConstant',
  'specularConstant',
  // Component transfer function attributes (feFuncR/G/B/A)
  'slope',
  'intercept',
  'amplitude',
  'exponent',
  // Note: 'offset' already included above
  // feTurbulence attributes
  'baseFrequency',
  'numOctaves',
  'seed',
  // feDisplacementMap attributes
  'scale',
  // feMorphology attributes
  'radius',
  // Filter primitive attributes that can be animated
  'stdDeviation',
  'dx',
  'dy',
};

const Set<String> _colorAttributes = {
  'fill',
  'stroke',
  'stop-color',
  'flood-color',
  'lighting-color',
};

/// Properties that must always use discrete calcMode per SMIL spec.
/// These are non-interpolatable string-type properties.
/// Reference: Blink SVGAnimateElement.cpp:510-515
const Set<String> _discreteAttributes = {
  'visibility',
  'display',
  'fill-rule',
  'stroke-linecap',
  'stroke-linejoin',
  'pointer-events',
  'clip-rule',
  'text-anchor',
  'dominant-baseline',
  'alignment-baseline',
  // feTurbulence type attribute (turbulence vs fractalNoise)
  'type',
  // feConvolveMatrix edgeMode attribute
  'edgeMode',
  // feTurbulence stitchTiles attribute
  'stitchTiles',
  // feMorphology operator attribute
  'operator',
  // feDisplacementMap channel selectors
  'xChannelSelector',
  'yChannelSelector',
};
