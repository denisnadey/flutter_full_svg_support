import 'dart:collection';

import 'package:full_svg_flutter/src/animation.dart';

import 'playground_models.dart';

/// In-memory storage for runtime traces and runtime issues in playground.
class PlaygroundTraceStore {
  PlaygroundTraceStore({this.maxEntries = 600});

  final int maxEntries;

  final List<PlaygroundLogEntry> _logs = <PlaygroundLogEntry>[];
  final List<PlaygroundIssue> _runtimeIssues = <PlaygroundIssue>[];

  UnmodifiableListView<PlaygroundLogEntry> get logs =>
      UnmodifiableListView<PlaygroundLogEntry>(_logs);

  UnmodifiableListView<PlaygroundIssue> get runtimeIssues =>
      UnmodifiableListView<PlaygroundIssue>(_runtimeIssues);

  void clear() {
    _logs.clear();
    _runtimeIssues.clear();
  }

  void clearRuntimeIssues() {
    _runtimeIssues.clear();
  }

  void restore({
    required List<PlaygroundLogEntry> logs,
    required List<PlaygroundIssue> runtimeIssues,
  }) {
    _logs
      ..clear()
      ..addAll(logs.take(maxEntries));
    _runtimeIssues
      ..clear()
      ..addAll(runtimeIssues);
  }

  void appendLog({
    required SvgTraceLevel level,
    required String category,
    required String message,
    Map<String, Object?> data = const <String, Object?>{},
    Object? error,
    StackTrace? stackTrace,
  }) {
    _logs.insert(
      0,
      PlaygroundLogEntry(
        timestamp: DateTime.now(),
        level: level,
        category: category,
        message: message,
        data: data,
        error: error?.toString(),
        stackTrace: stackTrace?.toString(),
      ),
    );

    if (_logs.length > maxEntries) {
      _logs.removeRange(maxEntries, _logs.length);
    }
  }

  void appendRuntimeIssue(PlaygroundIssue issue) {
    final exists = _runtimeIssues.any(
      (current) =>
          current.code == issue.code &&
          current.title == issue.title &&
          current.details == issue.details &&
          current.nodeId == issue.nodeId &&
          current.tag == issue.tag,
    );
    if (exists) {
      return;
    }
    _runtimeIssues.insert(0, issue);
  }

  void appendTraceEvent(SvgTraceEvent event) {
    appendLog(
      level: event.level,
      category: event.category,
      message: event.message,
      data: event.data,
      error: event.error,
      stackTrace: event.stackTrace,
    );

    if (event.level != SvgTraceLevel.error) {
      return;
    }

    appendRuntimeIssue(
      PlaygroundIssue(
        code: 'runtime.error',
        severity: PlaygroundIssueSeverity.error,
        category: 'runtime',
        title: 'Runtime error (${event.category})',
        details: event.error?.toString() ?? event.message,
        nodeId: event.data['targetId']?.toString(),
      ),
    );
  }
}
