/// Versioned, JSON-safe protocol shared by the FullSVG runtime bridge and
/// its Flutter DevTools companion extension.
library;

/// Protocol method names and common response keys.
abstract final class FullSvgDebugProtocol {
  static const int version = 1;
  static const String namespace = 'ext.full_svg_flutter';

  static const String getProtocolVersion = '$namespace.getProtocolVersion';
  static const String getInstances = '$namespace.getInstances';
  static const String getInstance = '$namespace.getInstance';
  static const String getTree = '$namespace.getTree';
  static const String getNode = '$namespace.getNode';
  static const String play = '$namespace.play';
  static const String pause = '$namespace.pause';
  static const String seek = '$namespace.seek';
  static const String setPlaybackRate = '$namespace.setPlaybackRate';
  static const String highlightNode = '$namespace.highlightNode';
  static const String clearHighlight = '$namespace.clearHighlight';
  static const String getStats = '$namespace.getStats';

  static const List<String> methods = <String>[
    getProtocolVersion,
    getInstances,
    getInstance,
    getTree,
    getNode,
    play,
    pause,
    seek,
    setPlaybackRate,
    highlightNode,
    clearHighlight,
    getStats,
  ];
}

/// Machine-readable error codes returned by the runtime bridge.
abstract final class FullSvgDebugErrorCode {
  static const String invalidRequest = 'invalid_request';
  static const String invalidParameter = 'invalid_parameter';
  static const String instanceNotFound = 'instance_not_found';
  static const String nodeNotFound = 'node_not_found';
  static const String animationUnavailable = 'animation_unavailable';
  static const String internalError = 'internal_error';
  static const String unsupportedMethod = 'unsupported_method';
}

Map<String, Object?> fullSvgDebugSuccess([Map<String, Object?>? body]) =>
    <String, Object?>{
      'ok': true,
      'protocolVersion': FullSvgDebugProtocol.version,
      ...?body,
    };

Map<String, Object?> fullSvgDebugFailure({
  required String code,
  required String message,
  Map<String, Object?>? details,
}) => <String, Object?>{
  'ok': false,
  'protocolVersion': FullSvgDebugProtocol.version,
  'error': <String, Object?>{
    'code': code,
    'message': message,
    if (details != null) 'details': details,
  },
};

/// Lightweight row shown in the live-instance list.
class SvgDebugInstanceSummary {
  const SvgDebugInstanceSummary({
    required this.instanceId,
    required this.sourceType,
    required this.sourceLabel,
    required this.width,
    required this.height,
    required this.animated,
    required this.playing,
    required this.currentTimeMs,
    required this.durationMs,
    required this.playbackRate,
    required this.nodeCount,
    required this.animationCount,
    required this.hasJavaScript,
    required this.hasFilters,
    required this.hasMasks,
    required this.hasClipPaths,
  });

  factory SvgDebugInstanceSummary.fromJson(Map<String, Object?> json) {
    return SvgDebugInstanceSummary(
      instanceId: json['instanceId']! as String,
      sourceType: json['sourceType'] as String?,
      sourceLabel: json['sourceLabel'] as String?,
      width: (json['width'] as num?)?.toDouble(),
      height: (json['height'] as num?)?.toDouble(),
      animated: json['animated']! as bool,
      playing: json['playing']! as bool,
      currentTimeMs: (json['currentTimeMs'] as num?)?.toInt(),
      durationMs: (json['durationMs'] as num?)?.toInt(),
      playbackRate: (json['playbackRate']! as num).toDouble(),
      nodeCount: (json['nodeCount']! as num).toInt(),
      animationCount: (json['animationCount']! as num).toInt(),
      hasJavaScript: json['hasJavaScript']! as bool,
      hasFilters: json['hasFilters']! as bool,
      hasMasks: json['hasMasks']! as bool,
      hasClipPaths: json['hasClipPaths']! as bool,
    );
  }

  final String instanceId;
  final String? sourceType;
  final String? sourceLabel;
  final double? width;
  final double? height;
  final bool animated;
  final bool playing;
  final int? currentTimeMs;
  final int? durationMs;
  final double playbackRate;
  final int nodeCount;
  final int animationCount;
  final bool hasJavaScript;
  final bool hasFilters;
  final bool hasMasks;
  final bool hasClipPaths;

  Map<String, Object?> toJson() => <String, Object?>{
    'instanceId': instanceId,
    'sourceType': sourceType,
    'sourceLabel': sourceLabel,
    'width': width,
    'height': height,
    'animated': animated,
    'playing': playing,
    'currentTimeMs': currentTimeMs,
    'durationMs': durationMs,
    'playbackRate': playbackRate,
    'nodeCount': nodeCount,
    'animationCount': animationCount,
    'hasJavaScript': hasJavaScript,
    'hasFilters': hasFilters,
    'hasMasks': hasMasks,
    'hasClipPaths': hasClipPaths,
  };
}

/// Lazy tree row. Attributes are intentionally omitted.
class SvgDebugNodeSummary {
  const SvgDebugNodeSummary({
    required this.nodeId,
    required this.tagName,
    required this.svgId,
    required this.classes,
    required this.childCount,
    required this.animated,
  });

  factory SvgDebugNodeSummary.fromJson(Map<String, Object?> json) {
    return SvgDebugNodeSummary(
      nodeId: json['nodeId']! as String,
      tagName: json['tagName']! as String,
      svgId: json['svgId'] as String?,
      classes: (json['classes']! as List<Object?>).cast<String>(),
      childCount: (json['childCount']! as num).toInt(),
      animated: json['animated']! as bool,
    );
  }

  final String nodeId;
  final String tagName;
  final String? svgId;
  final List<String> classes;
  final int childCount;
  final bool animated;

  Map<String, Object?> toJson() => <String, Object?>{
    'nodeId': nodeId,
    'tagName': tagName,
    'svgId': svgId,
    'classes': classes,
    'childCount': childCount,
    'animated': animated,
  };
}

class SvgDebugAttribute {
  const SvgDebugAttribute({
    required this.name,
    required this.rawValue,
    required this.resolvedValue,
    required this.animated,
  });

  factory SvgDebugAttribute.fromJson(Map<String, Object?> json) {
    return SvgDebugAttribute(
      name: json['name']! as String,
      rawValue: json['rawValue'] as String?,
      resolvedValue: json['resolvedValue']! as String,
      animated: json['animated']! as bool,
    );
  }

  final String name;
  final String? rawValue;
  final String resolvedValue;
  final bool animated;

  Map<String, Object?> toJson() => <String, Object?>{
    'name': name,
    'rawValue': rawValue,
    'resolvedValue': resolvedValue,
    'animated': animated,
  };
}

class SvgDebugAnimationDescriptor {
  const SvgDebugAnimationDescriptor({
    required this.type,
    required this.attributeName,
    required this.durationMs,
    required this.beginMs,
    required this.repeatCount,
    required this.active,
  });

  factory SvgDebugAnimationDescriptor.fromJson(Map<String, Object?> json) {
    return SvgDebugAnimationDescriptor(
      type: json['type']! as String,
      attributeName: json['attributeName']! as String,
      durationMs: (json['durationMs']! as num).toInt(),
      beginMs: (json['beginMs']! as num).toInt(),
      repeatCount: json['repeatCount']! as String,
      active: json['active']! as bool,
    );
  }

  final String type;
  final String attributeName;
  final int durationMs;
  final int beginMs;
  final String repeatCount;
  final bool active;

  Map<String, Object?> toJson() => <String, Object?>{
    'type': type,
    'attributeName': attributeName,
    'durationMs': durationMs,
    'beginMs': beginMs,
    'repeatCount': repeatCount,
    'active': active,
  };
}

class SvgDebugNodeDetails {
  const SvgDebugNodeDetails({
    required this.summary,
    required this.attributes,
    required this.animations,
  });

  factory SvgDebugNodeDetails.fromJson(Map<String, Object?> json) {
    return SvgDebugNodeDetails(
      summary: SvgDebugNodeSummary.fromJson(
        (json['summary']! as Map<Object?, Object?>).cast<String, Object?>(),
      ),
      attributes: (json['attributes']! as List<Object?>)
          .map(
            (item) => SvgDebugAttribute.fromJson(
              (item! as Map<Object?, Object?>).cast<String, Object?>(),
            ),
          )
          .toList(growable: false),
      animations: (json['animations']! as List<Object?>)
          .map(
            (item) => SvgDebugAnimationDescriptor.fromJson(
              (item! as Map<Object?, Object?>).cast<String, Object?>(),
            ),
          )
          .toList(growable: false),
    );
  }

  final SvgDebugNodeSummary summary;
  final List<SvgDebugAttribute> attributes;
  final List<SvgDebugAnimationDescriptor> animations;

  Map<String, Object?> toJson() => <String, Object?>{
    'summary': summary.toJson(),
    'attributes': attributes.map((value) => value.toJson()).toList(),
    'animations': animations.map((value) => value.toJson()).toList(),
  };
}

class SvgDebugStats {
  const SvgDebugStats({
    required this.domNodes,
    required this.animationCount,
    required this.activeAnimationCount,
    required this.filterPrimitiveCount,
    required this.maskCount,
    required this.gradientCount,
    required this.clipPathCount,
    required this.javaScriptEnabled,
    required this.currentTimeMs,
    required this.durationMs,
  });

  factory SvgDebugStats.fromJson(Map<String, Object?> json) {
    return SvgDebugStats(
      domNodes: (json['domNodes']! as num).toInt(),
      animationCount: (json['animationCount']! as num).toInt(),
      activeAnimationCount: (json['activeAnimationCount']! as num).toInt(),
      filterPrimitiveCount: (json['filterPrimitiveCount']! as num).toInt(),
      maskCount: (json['maskCount']! as num).toInt(),
      gradientCount: (json['gradientCount']! as num).toInt(),
      clipPathCount: (json['clipPathCount']! as num).toInt(),
      javaScriptEnabled: json['javaScriptEnabled']! as bool,
      currentTimeMs: (json['currentTimeMs'] as num?)?.toInt(),
      durationMs: (json['durationMs'] as num?)?.toInt(),
    );
  }

  final int domNodes;
  final int animationCount;
  final int activeAnimationCount;
  final int filterPrimitiveCount;
  final int maskCount;
  final int gradientCount;
  final int clipPathCount;
  final bool javaScriptEnabled;
  final int? currentTimeMs;
  final int? durationMs;

  Map<String, Object?> toJson() => <String, Object?>{
    'domNodes': domNodes,
    'animationCount': animationCount,
    'activeAnimationCount': activeAnimationCount,
    'filterPrimitiveCount': filterPrimitiveCount,
    'maskCount': maskCount,
    'gradientCount': gradientCount,
    'clipPathCount': clipPathCount,
    'javaScriptEnabled': javaScriptEnabled,
    'currentTimeMs': currentTimeMs,
    'durationMs': durationMs,
  };
}
