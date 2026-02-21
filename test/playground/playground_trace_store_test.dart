import 'package:flutter_svg/src/animation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../example/lib/playground/playground_models.dart';
import '../../example/lib/playground/playground_trace_store.dart';

void main() {
  group('PlaygroundTraceStore', () {
    test('caps logs by maxEntries and keeps newest first', () {
      final store = PlaygroundTraceStore(maxEntries: 2);

      store.appendLog(
        level: SvgTraceLevel.info,
        category: 'a',
        message: 'log-1',
      );
      store.appendLog(
        level: SvgTraceLevel.info,
        category: 'a',
        message: 'log-2',
      );
      store.appendLog(
        level: SvgTraceLevel.info,
        category: 'a',
        message: 'log-3',
      );

      expect(store.logs.length, 2);
      expect(store.logs[0].message, 'log-3');
      expect(store.logs[1].message, 'log-2');
    });

    test('deduplicates runtime issues', () {
      final store = PlaygroundTraceStore();
      const issue = PlaygroundIssue(
        code: 'runtime.example',
        severity: PlaygroundIssueSeverity.error,
        category: 'runtime',
        title: 'Runtime issue',
        details: 'Same issue',
      );

      store.appendRuntimeIssue(issue);
      store.appendRuntimeIssue(issue);

      expect(store.runtimeIssues.length, 1);
    });

    test('appendTraceEvent stores runtime issues for errors', () {
      final store = PlaygroundTraceStore();

      store.appendTraceEvent(
        SvgTraceEvent(
          timestamp: DateTime(2026, 1, 1),
          level: SvgTraceLevel.error,
          category: 'init',
          message: 'Initialization failed',
          error: StateError('boom'),
        ),
      );

      expect(store.logs.length, 1);
      expect(store.runtimeIssues.length, 1);
      expect(store.runtimeIssues.first.code, 'runtime.error');
      expect(store.runtimeIssues.first.category, 'runtime');
    });

    test('restore replaces snapshot and respects max entries', () {
      final store = PlaygroundTraceStore(maxEntries: 2);

      final logs = <PlaygroundLogEntry>[
        PlaygroundLogEntry(
          timestamp: DateTime(2026, 1, 1, 0, 0, 3),
          level: SvgTraceLevel.info,
          category: 'run',
          message: 'log-3',
          data: const <String, Object?>{},
          error: null,
          stackTrace: null,
        ),
        PlaygroundLogEntry(
          timestamp: DateTime(2026, 1, 1, 0, 0, 2),
          level: SvgTraceLevel.info,
          category: 'run',
          message: 'log-2',
          data: const <String, Object?>{},
          error: null,
          stackTrace: null,
        ),
        PlaygroundLogEntry(
          timestamp: DateTime(2026, 1, 1, 0, 0, 1),
          level: SvgTraceLevel.info,
          category: 'run',
          message: 'log-1',
          data: const <String, Object?>{},
          error: null,
          stackTrace: null,
        ),
      ];

      const issues = <PlaygroundIssue>[
        PlaygroundIssue(
          code: 'runtime.one',
          severity: PlaygroundIssueSeverity.error,
          category: 'runtime',
          title: 'Issue one',
          details: 'Issue details',
        ),
      ];

      store.restore(logs: logs, runtimeIssues: issues);

      expect(store.logs.length, 2);
      expect(store.logs.first.message, 'log-3');
      expect(store.runtimeIssues.length, 1);
      expect(store.runtimeIssues.first.code, 'runtime.one');
    });
  });
}
