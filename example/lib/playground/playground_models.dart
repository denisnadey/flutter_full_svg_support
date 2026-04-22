import 'dart:convert';

import 'package:full_svg_flutter/src/animation.dart';

/// Severity for playground diagnostics.
enum PlaygroundIssueSeverity {
  info,
  warning,
  error;

  static PlaygroundIssueSeverity fromName(String? name) {
    switch (name) {
      case 'info':
        return PlaygroundIssueSeverity.info;
      case 'warning':
        return PlaygroundIssueSeverity.warning;
      case 'error':
      default:
        return PlaygroundIssueSeverity.error;
    }
  }

  SvgTraceLevel toTraceLevel() {
    switch (this) {
      case PlaygroundIssueSeverity.info:
        return SvgTraceLevel.info;
      case PlaygroundIssueSeverity.warning:
        return SvgTraceLevel.warning;
      case PlaygroundIssueSeverity.error:
        return SvgTraceLevel.error;
    }
  }
}

/// Structured diagnostic issue produced by static/runtime analysis.
class PlaygroundIssue {
  const PlaygroundIssue({
    required this.code,
    required this.severity,
    required this.category,
    required this.title,
    required this.details,
    this.nodeId,
    this.tag,
  });

  final String code;
  final PlaygroundIssueSeverity severity;
  final String category;
  final String title;
  final String details;
  final String? nodeId;
  final String? tag;

  factory PlaygroundIssue.fromJson(Map<String, Object?> json) {
    return PlaygroundIssue(
      code: _asString(json['code']) ?? 'unknown',
      severity: PlaygroundIssueSeverity.fromName(_asString(json['severity'])),
      category: _asString(json['category']) ?? 'unknown',
      title: _asString(json['title']) ?? 'Unknown issue',
      details: _asString(json['details']) ?? '',
      nodeId: _asNullableString(json['nodeId']),
      tag: _asNullableString(json['tag']),
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'code': code,
      'severity': severity.name,
      'category': category,
      'title': title,
      'details': details,
      'nodeId': nodeId,
      'tag': tag,
    };
  }
}

/// Unified report for a single playground run.
class PlaygroundReport {
  const PlaygroundReport({
    required this.parseSuccess,
    required this.canRender,
    required this.parseError,
    required this.parseTimeMs,
    required this.rootTag,
    required this.hasViewBox,
    required this.hasAnimationMarkers,
    required this.animationCount,
    required this.eventConditionCount,
    required this.missingEventTargets,
    required this.usedTags,
    required this.unsupportedTags,
    required this.unsupportedFilterPrimitives,
    required this.brokenReferences,
    required this.issues,
    this.diagnosticVersion = 'v1',
  });

  factory PlaygroundReport.empty(PlaygroundIssue issue) {
    return PlaygroundReport(
      parseSuccess: false,
      canRender: false,
      parseError: issue.details,
      parseTimeMs: 0,
      rootTag: null,
      hasViewBox: false,
      hasAnimationMarkers: false,
      animationCount: 0,
      eventConditionCount: 0,
      missingEventTargets: const <String>{},
      usedTags: const <String>{},
      unsupportedTags: const <String>{},
      unsupportedFilterPrimitives: const <String>{},
      brokenReferences: const <String>{},
      issues: <PlaygroundIssue>[issue],
    );
  }

  final String diagnosticVersion;
  final bool parseSuccess;
  final bool canRender;
  final String? parseError;
  final int parseTimeMs;
  final String? rootTag;
  final bool hasViewBox;
  final bool hasAnimationMarkers;
  final int animationCount;
  final int eventConditionCount;
  final Set<String> missingEventTargets;
  final Set<String> usedTags;
  final Set<String> unsupportedTags;
  final Set<String> unsupportedFilterPrimitives;
  final Set<String> brokenReferences;
  final List<PlaygroundIssue> issues;

  factory PlaygroundReport.fromJson(Map<String, Object?> json) {
    final rawIssues = json['issues'];
    final parsedIssues = <PlaygroundIssue>[];
    if (rawIssues is Iterable) {
      for (final raw in rawIssues) {
        if (raw is Map) {
          parsedIssues.add(PlaygroundIssue.fromJson(_toStringKeyMap(raw)));
        }
      }
    }

    return PlaygroundReport(
      diagnosticVersion: _asString(json['diagnosticVersion']) ?? 'v1',
      parseSuccess: _asBool(json['parseSuccess']),
      canRender: _asBool(json['canRender']),
      parseError: _asNullableString(json['parseError']),
      parseTimeMs: _asInt(json['parseTimeMs']),
      rootTag: _asNullableString(json['rootTag']),
      hasViewBox: _asBool(json['hasViewBox']),
      hasAnimationMarkers: _asBool(json['hasAnimationMarkers']),
      animationCount: _asInt(json['animationCount']),
      eventConditionCount: _asInt(json['eventConditionCount']),
      missingEventTargets: _asStringSet(json['missingEventTargets']),
      usedTags: _asStringSet(json['usedTags']),
      unsupportedTags: _asStringSet(json['unsupportedTags']),
      unsupportedFilterPrimitives: _asStringSet(
        json['unsupportedFilterPrimitives'],
      ),
      brokenReferences: _asStringSet(json['brokenReferences']),
      issues: parsedIssues,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'diagnosticVersion': diagnosticVersion,
      'parseSuccess': parseSuccess,
      'canRender': canRender,
      'parseError': parseError,
      'parseTimeMs': parseTimeMs,
      'rootTag': rootTag,
      'hasViewBox': hasViewBox,
      'hasAnimationMarkers': hasAnimationMarkers,
      'animationCount': animationCount,
      'eventConditionCount': eventConditionCount,
      'missingEventTargets': missingEventTargets.toList()..sort(),
      'usedTags': usedTags.toList()..sort(),
      'unsupportedTags': unsupportedTags.toList()..sort(),
      'unsupportedFilterPrimitives': unsupportedFilterPrimitives.toList()
        ..sort(),
      'brokenReferences': brokenReferences.toList()..sort(),
      'issues': issues.map((issue) => issue.toJson()).toList(growable: false),
    };
  }

  String toPrettyJson() {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(toJson());
  }
}

/// Runtime trace event snapshot kept by playground.
class PlaygroundLogEntry {
  const PlaygroundLogEntry({
    required this.timestamp,
    required this.level,
    required this.category,
    required this.message,
    required this.data,
    required this.error,
    required this.stackTrace,
  });

  final DateTime timestamp;
  final SvgTraceLevel level;
  final String category;
  final String message;
  final Map<String, Object?> data;
  final String? error;
  final String? stackTrace;

  factory PlaygroundLogEntry.fromJson(Map<String, Object?> json) {
    final rawData = json['data'];
    final parsedData = rawData is Map
        ? _toStringKeyMap(rawData)
        : <String, Object?>{};

    return PlaygroundLogEntry(
      timestamp: _parseDateTime(json['timestamp']) ?? DateTime.now(),
      level: _traceLevelFromName(_asString(json['level'])),
      category: _asString(json['category']) ?? 'unknown',
      message: _asString(json['message']) ?? '',
      data: parsedData,
      error: _asNullableString(json['error']),
      stackTrace: _asNullableString(json['stackTrace']),
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'timestamp': timestamp.toIso8601String(),
      'level': level.name,
      'category': category,
      'message': message,
      'data': data,
      'error': error,
      'stackTrace': stackTrace,
    };
  }
}

String? _asString(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is String) {
    return value;
  }
  return value.toString();
}

String? _asNullableString(Object? value) {
  final str = _asString(value);
  if (str == null || str.isEmpty || str == 'null') {
    return null;
  }
  return str;
}

bool _asBool(Object? value) {
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  if (value is String) {
    return value.toLowerCase() == 'true';
  }
  return false;
}

int _asInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value) ?? 0;
  }
  return 0;
}

DateTime? _parseDateTime(Object? value) {
  final raw = _asString(value);
  if (raw == null || raw.isEmpty) {
    return null;
  }
  return DateTime.tryParse(raw);
}

Set<String> _asStringSet(Object? value) {
  if (value is! Iterable) {
    return const <String>{};
  }
  final result = <String>{};
  for (final item in value) {
    final str = _asString(item);
    if (str != null && str.isNotEmpty) {
      result.add(str);
    }
  }
  return result;
}

Map<String, Object?> _toStringKeyMap(Map<dynamic, dynamic> value) {
  final map = <String, Object?>{};
  for (final entry in value.entries) {
    map[entry.key.toString()] = entry.value;
  }
  return map;
}

SvgTraceLevel _traceLevelFromName(String? name) {
  switch (name) {
    case 'debug':
      return SvgTraceLevel.debug;
    case 'info':
      return SvgTraceLevel.info;
    case 'warning':
      return SvgTraceLevel.warning;
    case 'error':
    default:
      return SvgTraceLevel.error;
  }
}
