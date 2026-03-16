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

    // Получаем path из inline path или <mpath href="#...">.
    final pathData = _resolveAnimateMotionPathData(animNode, document);
    if (pathData == null || pathData.trim().isEmpty) {
      return null; // animateMotion без path невалидна
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

    // Создаём SmilAnimation для animateMotion
    // Используем специальное значение для from/to - сам path
    return SmilAnimation(
      id: id,
      type: SmilAnimationType.animateMotion,
      targetNode: targetNode,
      attributeName: 'motion', // Специальное имя для motion
      attributeType: SvgAttributeType.transform,
      from: pathData, // Path data хранится в from
      to: rotateMode, // Rotate mode хранится в to
      values: keyPoints?.map((kp) => kp as Object).toList(),
      keyTimes: keyTimes,
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
      accumulate: false,
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
  if (referencedNode == null || referencedNode.tagName != 'path') {
    return null;
  }

  final referencedPath = referencedNode.getAttributeValue('d')?.toString();
  if (referencedPath == null || referencedPath.trim().isEmpty) {
    return null;
  }
  return referencedPath.trim();
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
