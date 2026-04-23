@Tags(['golden', 'w3c'])
library w3c_static_golden_test;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:full_svg_flutter/src/animation/animated_svg_picture.dart';

import 'w3c_manifest.dart';
import 'w3c_render_utils.dart';

const String _manifestPath =
    'test/w3c/manifest/w3c_static_accepted_manifest.json';
const String _diffRoot = 'test/w3c/artifacts/diff';

bool get _isRunEnabled => Platform.environment['RUN_W3C_STATIC'] == '1';
bool get _isDebug => Platform.environment['W3C_DEBUG'] == '1';
bool get _isTraceEnabled =>
    Platform.environment['W3C_TRACE'] == '1' ||
    Platform.environment['W3C_TRACE_PROFILE'] != null;
bool get _isTraceFailOnly => Platform.environment['W3C_TRACE_FAIL_ONLY'] == '1';
String get _debugRoot => 'test/w3c/artifacts/debug';
String get _traceRoot =>
    Platform.environment['W3C_TRACE_ROOT'] ?? 'test/w3c/artifacts/trace';

String get _traceProfile {
  final raw = Platform.environment['W3C_TRACE_PROFILE']?.trim().toLowerCase();
  switch (raw) {
    case 'basic':
    case 'detailed':
    case 'forensic':
      return raw!;
    default:
      return 'detailed';
  }
}

final String _traceRunId = _buildTraceRunId();

int get _caseTimeoutSeconds {
  final raw = Platform.environment['W3C_CASE_TIMEOUT_SECS'];
  if (raw == null || raw.isEmpty) {
    return 120;
  }
  final parsed = int.tryParse(raw);
  if (parsed == null || parsed <= 0) {
    return 120;
  }
  return parsed;
}

int? get _limit {
  final raw = Platform.environment['W3C_LIMIT'];
  if (raw == null || raw.isEmpty) {
    return null;
  }
  return int.tryParse(raw);
}

String? get _nameFilter {
  final raw = Platform.environment['W3C_NAME_FILTER'];
  if (raw == null || raw.trim().isEmpty) {
    return null;
  }
  return raw.trim();
}

void _debugLog(String message) {
  if (_isDebug) {
    // ignore: avoid_print
    print('[w3c-debug] $message');
  }
}

void _writeDebugImage(String path, List<int> bytes) {
  final file = File(path);
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(bytes, flush: true);
  _debugLog('debug-image: $path');
}

Future<T> _withStageTimeout<T>(
  String stage,
  Duration timeout,
  Future<T> Function() action,
) async {
  try {
    _debugLog('stage-start: $stage');
    final result = await action().timeout(timeout);
    _debugLog('stage-done: $stage');
    return result;
  } on TimeoutException catch (error) {
    throw TimeoutException('Stage "$stage" timed out after $timeout: $error');
  }
}

String _buildTraceRunId() {
  final explicit = Platform.environment['W3C_TRACE_RUN_ID'];
  if (explicit != null && explicit.trim().isNotEmpty) {
    return explicit.trim();
  }
  final now = DateTime.now().toUtc();
  final y = now.year.toString().padLeft(4, '0');
  final m = now.month.toString().padLeft(2, '0');
  final d = now.day.toString().padLeft(2, '0');
  final h = now.hour.toString().padLeft(2, '0');
  final min = now.minute.toString().padLeft(2, '0');
  final s = now.second.toString().padLeft(2, '0');
  final ms = now.millisecond.toString().padLeft(3, '0');
  return 'run-${y}${m}${d}-${h}${min}${s}-${ms}';
}

class _CaseTraceCollector {
  _CaseTraceCollector({required this.profile, required this.enabled});

  final String profile;
  final bool enabled;

  final DateTime _startedAt = DateTime.now().toUtc();
  final List<Map<String, Object?>> _events = <Map<String, Object?>>[];
  final Map<String, Stopwatch> _stagesInFlight = <String, Stopwatch>{};
  final Map<String, int> _stageDurationsMs = <String, int>{};

  bool get traceFrameTicks => enabled && profile == 'forensic';

  DateTime get startedAt => _startedAt;

  List<Map<String, Object?>> get events => _events;

  Map<String, int> get stageDurationsMs => _stageDurationsMs;

  void stageStart(String stage) {
    if (!enabled) {
      return;
    }
    _stagesInFlight[stage] = Stopwatch()..start();
  }

  void stageDone(String stage) {
    if (!enabled) {
      return;
    }
    final sw = _stagesInFlight.remove(stage);
    if (sw == null) {
      return;
    }
    sw.stop();
    _stageDurationsMs[stage] = sw.elapsedMilliseconds;
  }

  void onTraceEvent(SvgTraceEvent event) {
    if (!enabled || !_shouldKeepEvent(event)) {
      return;
    }

    final includePayload = profile != 'basic';
    final includeStack = profile == 'forensic';

    _events.add(<String, Object?>{
      'timestamp': event.timestamp.toUtc().toIso8601String(),
      'level': event.level.name,
      'category': event.category,
      'message': event.message,
      'data': includePayload
          ? _toJsonSafe(event.data)
          : const <String, Object?>{},
      'error': event.error?.toString(),
      'stackTrace': includeStack ? event.stackTrace?.toString() : null,
    });
  }

  bool _shouldKeepEvent(SvgTraceEvent event) {
    if (profile == 'forensic') {
      return true;
    }
    if (profile == 'detailed') {
      return event.level != SvgTraceLevel.debug;
    }

    if (event.level == SvgTraceLevel.warning ||
        event.level == SvgTraceLevel.error) {
      return true;
    }
    if (event.level == SvgTraceLevel.debug) {
      return false;
    }
    return event.category == 'init' || event.category == 'image';
  }
}

Object? _toJsonSafe(Object? value) {
  if (value == null || value is num || value is bool || value is String) {
    return value;
  }
  if (value is DateTime) {
    return value.toUtc().toIso8601String();
  }
  if (value is Duration) {
    return value.inMicroseconds;
  }
  if (value is Map) {
    final out = <String, Object?>{};
    for (final entry in value.entries) {
      out[entry.key.toString()] = _toJsonSafe(entry.value);
    }
    return out;
  }
  if (value is Iterable) {
    return value.map(_toJsonSafe).toList(growable: false);
  }
  return value.toString();
}

void _writeTraceArtifacts({
  required W3cManifestEntry entry,
  required _CaseTraceCollector collector,
  required bool passed,
  required double? similarity,
  required String diffPath,
  required W3cCompareConfig compareConfig,
  Object? failureError,
  StackTrace? failureStack,
}) {
  if (!collector.enabled) {
    return;
  }
  if (_isTraceFailOnly && passed && failureError == null) {
    return;
  }

  final caseDir = Directory('$_traceRoot/$_traceRunId/${entry.name}');
  caseDir.createSync(recursive: true);

  final traceFile = File('${caseDir.path}/trace.jsonl');
  final tracePayload = collector.events.map(jsonEncode).join('\n');
  traceFile.writeAsStringSync(
    tracePayload.isEmpty ? '' : '$tracePayload\n',
    flush: true,
  );

  final eventCountByCategory = <String, int>{};
  for (final event in collector.events) {
    final category = event['category']?.toString() ?? 'unknown';
    eventCountByCategory[category] = (eventCountByCategory[category] ?? 0) + 1;
  }

  final summary = <String, Object?>{
    'runId': _traceRunId,
    'profile': collector.profile,
    'caseName': entry.name,
    'svgPath': entry.svgPath,
    'referencePngPath': entry.pngPath,
    'startedAt': collector.startedAt.toIso8601String(),
    'finishedAt': DateTime.now().toUtc().toIso8601String(),
    'passed': passed,
    'similarity': similarity,
    'similarityThreshold': kW3cSimilarityThreshold,
    'perPixelThreshold': compareConfig.effectivePerPixelThreshold,
    'ignoreRegionCount': compareConfig.ignoreRegionCount,
    'usesIgnoreMasking': compareConfig.usesIgnoreMasking,
    'diffPath': diffPath,
    'stageDurationsMs': collector.stageDurationsMs,
    'eventCount': collector.events.length,
    'eventCountByCategory': eventCountByCategory,
    'failureError': failureError?.toString(),
    'failureStack': collector.profile == 'forensic'
        ? failureStack?.toString()
        : null,
  };
  final summaryFile = File('${caseDir.path}/summary.json');
  summaryFile.writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(summary),
    flush: true,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('W3C static manifest exists', () {
    final file = File(_manifestPath);
    expect(
      file.existsSync(),
      isTrue,
      reason: 'Missing manifest at $_manifestPath',
    );
  });

  final manifest = loadW3cManifest(_manifestPath);
  final allEntries = manifest.entries;
  final filteredEntries = _nameFilter == null
      ? allEntries
      : allEntries
            .where((entry) => entry.name.contains(_nameFilter!))
            .toList(growable: false);
  final selectedEntries = _limit == null
      ? filteredEntries
      : filteredEntries.take(_limit!).toList(growable: false);

  group('W3C static visual comparison', () {
    if (!_isRunEnabled) {
      test('skipped by default', () {
        expect(
          true,
          isTrue,
          reason: 'Set RUN_W3C_STATIC=1 to run W3C static visual comparisons.',
        );
      });
      return;
    }

    test('manifest has entries', () {
      expect(allEntries.isNotEmpty, isTrue);
    });

    test('selected entries are not empty', () {
      expect(
        selectedEntries.isNotEmpty,
        isTrue,
        reason:
            'No selected W3C entries. Check W3C_NAME_FILTER or manifest content.',
      );
    });

    for (final entry in selectedEntries) {
      testWidgets(
        'W3C ${entry.name}',
        (tester) async {
          _debugLog('case-start: ${entry.name}');
          final traceCollector = _CaseTraceCollector(
            profile: _traceProfile,
            enabled: _isTraceEnabled,
          );
          final compareConfig = resolveW3cCompareConfig(caseName: entry.name);

          dynamic result;
          Object? failureError;
          StackTrace? failureStack;
          final diffPath = '$_diffRoot/${entry.name}.png';

          try {
            traceCollector.stageStart('capture');
            final captureBackgroundColor =
                await tester.runAsync(
                  () => resolveW3cCaptureBackgroundColor(
                    referencePngPath: entry.pngPath,
                  ),
                ) ??
                Colors.transparent;
            final renderedPng = await _withStageTimeout(
              'capture',
              const Duration(seconds: 90),
              () => captureSvgFromFile(
                tester,
                entry.svgPath,
                canvasBackgroundColor: captureBackgroundColor,
                onTraceEvent: traceCollector.onTraceEvent,
                traceFrameTicks: traceCollector.traceFrameTicks,
              ),
            );
            traceCollector.stageDone('capture');

            if (_isDebug) {
              _writeDebugImage(
                '$_debugRoot/${entry.name}.rendered.png',
                renderedPng,
              );
              final referenceFile = File(entry.pngPath);
              if (referenceFile.existsSync()) {
                _writeDebugImage(
                  '$_debugRoot/${entry.name}.reference.png',
                  referenceFile.readAsBytesSync(),
                );
              }
            }
            traceCollector.stageStart('compare');
            final resultOrNull = await _withStageTimeout(
              'compare',
              const Duration(seconds: 20),
              () => tester.runAsync(
                () => compareWithReferencePng(
                  renderedPng: renderedPng,
                  referencePngPath: entry.pngPath,
                  caseName: entry.name,
                ),
              ),
            );
            traceCollector.stageDone('compare');
            if (resultOrNull == null) {
              throw StateError('Compare stage returned null for ${entry.name}');
            }
            result = resultOrNull;

            final diffFile = File(diffPath);
            if (diffFile.existsSync()) {
              diffFile.deleteSync();
            }
            writeDiffIfAvailable(
              diffImage: result.diffImage,
              diffPath: diffPath,
            );

            expect(
              result.passed(kW3cSimilarityThreshold),
              isTrue,
              reason:
                  '${entry.name}: similarity '
                  '${result.similarity.toStringAsFixed(4)} '
                  'below threshold $kW3cSimilarityThreshold. '
                  '${result.message != null ? 'Compare: ${result.message}. ' : ''}'
                  'Diff: $diffPath',
            );
          } catch (error, stackTrace) {
            failureError = error;
            failureStack = stackTrace;
            rethrow;
          } finally {
            _writeTraceArtifacts(
              entry: entry,
              collector: traceCollector,
              passed: result?.passed(kW3cSimilarityThreshold) ?? false,
              similarity: result?.similarity,
              diffPath: diffPath,
              compareConfig: compareConfig,
              failureError: failureError,
              failureStack: failureStack,
            );
          }
        },
        timeout: Timeout(Duration(seconds: _caseTimeoutSeconds)),
      );
    }
  });
}
