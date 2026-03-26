part of 'smil_parser.dart';

/// Распарсить <animateMotion> элемент
SmilAnimation? _parseAnimateMotion(
  SvgNode animNode,
  SvgNode targetNode,
  SvgDocument document,
) {
  try {
    // Парсим ID анимации (для syncbase timing)
    final id = animNode.id;

    // Determine the animation mode: path, values with coordinates, or from/to/by
    // Priority: path/mpath > values (coordinates) > from/to/by
    String? pathData;
    String? fromCoordinate;
    String? toCoordinate;
    String? byCoordinate;

    // Try to get path data first
    pathData = _resolveAnimateMotionPathData(animNode, document);

    // If no path, check for values attribute with coordinate pairs
    if (pathData == null || pathData.trim().isEmpty) {
      final valuesStr = animNode.getAttributeValue('values') as String?;
      if (valuesStr != null && valuesStr.trim().isNotEmpty) {
        // Parse values as coordinate pairs (e.g., "0,0;100,100;200,50")
        final coords = MotionPath.parseCoordinatePairs(valuesStr);
        if (coords.isNotEmpty) {
          // Create implicit path from coordinates
          if (coords.length >= 2) {
            final buffer = StringBuffer('M${coords[0].dx},${coords[0].dy}');
            for (int i = 1; i < coords.length; i++) {
              buffer.write(' L${coords[i].dx},${coords[i].dy}');
            }
            pathData = buffer.toString();
          } else if (coords.length == 1) {
            pathData = 'M${coords[0].dx},${coords[0].dy}';
          }
        }
      }
    }

    // If still no path, check for from/to/by coordinates
    if (pathData == null || pathData.trim().isEmpty) {
      fromCoordinate = animNode.getAttributeValue('from')?.toString();
      toCoordinate = animNode.getAttributeValue('to')?.toString();
      byCoordinate = animNode.getAttributeValue('by')?.toString();

      final fromOffset = fromCoordinate != null
          ? MotionPath.parseCoordinatePair(fromCoordinate)
          : null;
      final toOffset = toCoordinate != null
          ? MotionPath.parseCoordinatePair(toCoordinate)
          : null;
      final byOffset = byCoordinate != null
          ? MotionPath.parseCoordinatePair(byCoordinate)
          : null;

      // Construct path from from/to/by
      if (fromOffset != null || toOffset != null || byOffset != null) {
        final startPoint = fromOffset ?? Offset.zero;
        Offset endPoint;

        if (toOffset != null) {
          endPoint = toOffset;
        } else if (byOffset != null) {
          endPoint = Offset(
            startPoint.dx + byOffset.dx,
            startPoint.dy + byOffset.dy,
          );
        } else {
          // Only from specified, use from as start and stay there
          endPoint = startPoint;
        }

        pathData =
            'M${startPoint.dx},${startPoint.dy} L${endPoint.dx},${endPoint.dy}';
      }
    }

    // If still no valid path, animation is invalid
    if (pathData == null || pathData.trim().isEmpty) {
      return null;
    }

    // Парсим тайминг
    final dur = _parseDuration(animNode.getAttributeValue('dur'));
    if (dur == null) {
      return null;
    }

    // Парсим begin/end как timing conditions (поддержка syncbase)
    var begin = Duration.zero;
    List<TimingCondition> beginConditions = [];
    final beginAttr = animNode.getAttributeValue('begin')?.toString();
    if (beginAttr != null) {
      beginConditions = TimingParser.parse(beginAttr);
      if (beginConditions.length == 1 &&
          beginConditions.first is OffsetCondition) {
        begin = (beginConditions.first as OffsetCondition).offset;
        beginConditions = [];
      }
    }

    Duration? end;
    List<TimingCondition> endConditions = [];
    final endAttr = animNode.getAttributeValue('end')?.toString();
    if (endAttr != null) {
      endConditions = TimingParser.parse(endAttr);
      if (endConditions.length == 1 && endConditions.first is OffsetCondition) {
        end = (endConditions.first as OffsetCondition).offset;
        endConditions = [];
      }
    }

    // Парсим repeatCount
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

    // Парсим режимы
    final fillMode = _parseFillMode(
      animNode.getAttributeValue('fill')?.toString(),
    );
    final calcMode = _parseCalcMode(
      animNode.getAttributeValue('calcMode')?.toString(),
    );

    // Parse accumulate (for motion this affects position accumulation)
    final accumulate =
        animNode.getAttributeValue('accumulate')?.toString() == 'sum';

    // Парсим rotate атрибут
    final rotateStr = animNode.getAttributeValue('rotate')?.toString();
    String? rotateMode;
    if (rotateStr != null) {
      rotateMode = rotateStr.trim();
      // Может быть "auto", "auto-reverse", или угол в градусах (например "45")
    }

    // Парсим keyPoints
    List<double>? keyPoints;
    final keyPointsStr = animNode.getAttributeValue('keyPoints') as String?;
    if (keyPointsStr != null) {
      keyPoints = _parseKeyTimes(keyPointsStr); // Тот же формат что keyTimes
    }

    // Парсим keyTimes
    List<double>? keyTimes;
    final keyTimesStr = animNode.getAttributeValue('keyTimes') as String?;
    if (keyTimesStr != null) {
      keyTimes = _parseKeyTimes(keyTimesStr);
    }

    // Parse keySplines for spline calcMode
    List<CubicBezier>? keySplines;
    final keySplinesStr = animNode.getAttributeValue('keySplines') as String?;
    if (keySplinesStr != null && calcMode == SmilCalcMode.spline) {
      keySplines = _parseKeySplines(keySplinesStr);
    }

    // For paced calcMode, keyPoints and keyTimes should be ignored (per SVG spec)
    if (calcMode == SmilCalcMode.paced) {
      keyPoints = null;
      keyTimes = null;
    }

    // Создаём SmilAnimation для animateMotion
    // Используем специальное значение для from/to - сам path
    return SmilAnimation(
      id: id,
      type: SmilAnimationType.animateMotion,
      targetNode: targetNode,
      attributeName:
          'transform', // Use 'transform' so renderer picks up the value
      attributeType: SvgAttributeType.transform,
      from: pathData, // Path data хранится в from
      to: rotateMode, // Rotate mode хранится в to
      values: keyPoints?.map((kp) => kp as Object).toList(),
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
      additive: SmilAdditiveMode.sum, // Motion всегда аддитивен
      accumulate: accumulate,
    );
  } catch (_) {
    return null;
  }
}

String? _resolveAnimateMotionPathData(SvgNode animNode, SvgDocument document) {
  final inlinePath = animNode.getAttributeValue('path')?.toString();
  if (inlinePath != null && inlinePath.trim().isNotEmpty) {
    return inlinePath.trim();
  }

  SvgNode? mpath;
  for (final child in animNode.children) {
    if (child.tagName == 'mpath') {
      mpath = child;
      break;
    }
  }
  if (mpath == null) {
    return null;
  }

  final hrefValue =
      mpath.getAttributeValue('href')?.toString() ??
      mpath.getAttributeValue('xlink:href')?.toString();
  final referencedId = _extractHrefId(hrefValue);
  if (referencedId == null) {
    return null;
  }

  final referencedNode = document.getElementById(referencedId);
  if (referencedNode == null) {
    return null;
  }

  // Handle <switch> element - evaluate conditions and select correct child
  if (referencedNode.tagName == 'switch') {
    final selectedPath = _evaluateSwitchAndGetPath(referencedNode, document);
    return selectedPath;
  }

  if (referencedNode.tagName != 'path') {
    return null;
  }

  final referencedPath = referencedNode.getAttributeValue('d')?.toString();
  if (referencedPath == null || referencedPath.trim().isEmpty) {
    return null;
  }
  return referencedPath.trim();
}

/// Evaluate a <switch> element and return the path data of the first matching child.
/// Per SVG spec, the <switch> element evaluates requiredFeatures, requiredExtensions,
/// and systemLanguage attributes on each child and renders the first child where
/// all specified attributes evaluate to true.
String? _evaluateSwitchAndGetPath(SvgNode switchNode, SvgDocument document) {
  for (final child in switchNode.children) {
    // Evaluate conditional processing attributes
    if (_evaluateConditionalAttributes(child, document)) {
      // This child passes the conditional test
      if (child.tagName == 'path') {
        final pathData = child.getAttributeValue('d')?.toString();
        if (pathData != null && pathData.trim().isNotEmpty) {
          return pathData.trim();
        }
      }
      // If the matching child is a group or another element containing a path,
      // recursively search for the first path
      final nestedPath = _findFirstPathInSubtree(child);
      if (nestedPath != null) {
        return nestedPath;
      }
    }
  }
  return null;
}

/// Evaluate conditional processing attributes on a node.
/// Returns true if the element should be processed, false if it should be skipped.
bool _evaluateConditionalAttributes(SvgNode node, SvgDocument document) {
  // Check requiredFeatures
  final requiredFeatures =
      node.getAttributeValue('requiredFeatures')?.toString();
  if (requiredFeatures != null && requiredFeatures.isNotEmpty) {
    if (!_evaluateRequiredFeatures(requiredFeatures)) {
      return false;
    }
  }

  // Check systemLanguage
  final systemLanguage = node.getAttributeValue('systemLanguage')?.toString();
  if (systemLanguage != null && systemLanguage.isNotEmpty) {
    if (!_evaluateSystemLanguage(systemLanguage, document)) {
      return false;
    }
  }

  // Check requiredExtensions - we don't support any extensions
  final requiredExtensions =
      node.getAttributeValue('requiredExtensions')?.toString();
  if (requiredExtensions != null && requiredExtensions.isNotEmpty) {
    // We don't support any extensions, so if any are required, return false
    return false;
  }

  return true;
}

/// Evaluate requiredFeatures attribute.
/// Returns true if all specified features are supported.
bool _evaluateRequiredFeatures(String features) {
  // SVG 1.1 feature strings that we support
  const supportedFeatures = <String>{
    'http://www.w3.org/TR/SVG11/feature#BasicStructure',
    'http://www.w3.org/TR/SVG11/feature#Shape',
    'http://www.w3.org/TR/SVG11/feature#BasicText',
    'http://www.w3.org/TR/SVG11/feature#BasicPaintAttribute',
    'http://www.w3.org/TR/SVG11/feature#BasicGraphicsAttribute',
    'http://www.w3.org/TR/SVG11/feature#Gradient',
    'http://www.w3.org/TR/SVG11/feature#Pattern',
    'http://www.w3.org/TR/SVG11/feature#Clip',
    'http://www.w3.org/TR/SVG11/feature#Mask',
    'http://www.w3.org/TR/SVG11/feature#Filter',
    'http://www.w3.org/TR/SVG11/feature#Animation',
    'http://www.w3.org/TR/SVG11/feature#AnimationEventsAttribute',
  };

  final featureList = features
      .split(RegExp(r'\s+'))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty);

  for (final feature in featureList) {
    if (!supportedFeatures.contains(feature)) {
      return false;
    }
  }
  return true;
}

/// Evaluate systemLanguage attribute.
/// Returns true if the user's language matches any of the specified languages.
bool _evaluateSystemLanguage(String languages, SvgDocument document) {
  // Get user's preferred language from document's xml:lang attribute or default to 'en'
  // Per SVG spec, systemLanguage compares against the user agent's language preferences
  String? docLang;
  final xmlLang = document.root.getAttributeValue('xml:lang')?.toString();
  final lang = document.root.getAttributeValue('lang')?.toString();
  docLang = xmlLang ?? lang;
  
  final userLanguage = docLang ?? 'en';
  final userLangPrefix = userLanguage.split('-').first.toLowerCase();

  final languageList = languages
      .split(',')
      .map((s) => s.trim().toLowerCase())
      .where((s) => s.isNotEmpty);

  for (final lang in languageList) {
    // Check for exact match or prefix match (e.g., 'en' matches 'en-US')
    final langPrefix = lang.split('-').first;
    if (lang == userLanguage.toLowerCase() || langPrefix == userLangPrefix) {
      return true;
    }
  }
  return false;
}

/// Find the first path element in a subtree.
String? _findFirstPathInSubtree(SvgNode node) {
  if (node.tagName == 'path') {
    final pathData = node.getAttributeValue('d')?.toString();
    if (pathData != null && pathData.trim().isNotEmpty) {
      return pathData.trim();
    }
  }

  for (final child in node.children) {
    final result = _findFirstPathInSubtree(child);
    if (result != null) {
      return result;
    }
  }
  return null;
}

String? _extractHrefId(String? href) {
  if (href == null) {
    return null;
  }
  final trimmed = href.trim();
  if (trimmed.isEmpty) {
    return null;
  }

  if (trimmed.startsWith('#') && trimmed.length > 1) {
    return trimmed.substring(1);
  }

  final urlMatch = RegExp(r'url\(#([^)]+)\)').firstMatch(trimmed);
  if (urlMatch != null) {
    return urlMatch.group(1);
  }

  return null;
}
