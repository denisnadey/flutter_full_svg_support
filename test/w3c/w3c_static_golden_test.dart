@Tags(['golden', 'w3c'])
library w3c_static_golden_test;

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'w3c_manifest.dart';
import 'w3c_render_utils.dart';

const String _manifestPath =
    'test/w3c/manifest/w3c_static_accepted_manifest.json';
const String _diffRoot = 'test/w3c/artifacts/diff';

bool get _isRunEnabled => Platform.environment['RUN_W3C_STATIC'] == '1';
bool get _isDebug => Platform.environment['W3C_DEBUG'] == '1';
String get _debugRoot => 'test/w3c/artifacts/debug';

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

          final renderedPng = await _withStageTimeout(
            'capture',
            const Duration(seconds: 90),
            () => captureSvgFromFile(tester, entry.svgPath),
          );
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
          if (resultOrNull == null) {
            throw StateError('Compare stage returned null for ${entry.name}');
          }
          final result = resultOrNull;

          final diffPath = '$_diffRoot/${entry.name}.png';
          final diffFile = File(diffPath);
          if (diffFile.existsSync()) {
            diffFile.deleteSync();
          }
          writeDiffIfAvailable(diffImage: result.diffImage, diffPath: diffPath);

          expect(
            result.passed(kW3cSimilarityThreshold),
            isTrue,
            reason:
                '${entry.name}: similarity '
                '${result.similarity.toStringAsFixed(4)} '
                'below threshold $kW3cSimilarityThreshold. '
                'Diff: $diffPath',
          );
        },
        timeout: Timeout(Duration(seconds: _caseTimeoutSeconds)),
      );
    }
  });
}
