import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:ui' show FrameTiming;

import 'package:flutter/widgets.dart';

/// Periodically POSTs frame-timing batches to a local telemetry endpoint.
///
/// Designed for the recording harness in benchmarks/comparison/. Enable by
/// passing the endpoint URL at compile time:
///
///   flutter build macos --release \
///     --dart-define=BENCHMARK_TELEMETRY=http://127.0.0.1:18765/metrics/flutter
///
/// Performance characteristics:
///   - [WidgetsBinding.addTimingsCallback] fires off the UI thread; we just
///     append to an in-memory list (no allocations beyond list growth).
///   - The flush task runs on a [Timer] every [interval]; HTTP POST is non
///     -blocking. A flush is skipped if the previous POST hasn't returned —
///     no overlap, no backlog.
///   - Buffer is bounded by [maxBuffer]; oldest entries are dropped first
///     so a stuck server can never OOM the renderer.
///   - All HTTP failures are silent; telemetry never throws into the UI loop.
class MetricsReporter {
  MetricsReporter({
    required this.endpoint,
    this.label = 'flutter',
    this.interval = const Duration(seconds: 5),
    this.maxBuffer = 5000,
  });

  final String endpoint;
  final String label;
  final Duration interval;
  final int maxBuffer;

  final List<FrameTiming> _buffer = <FrameTiming>[];
  Timer? _ticker;
  bool _flushing = false;

  /// Counter so we can see in stderr how many flushes happen.
  int _flushAttempts = 0;
  int _flushSuccesses = 0;
  int _flushFailures = 0;
  String _lastError = '';

  void start() {
    if (_ticker != null) return;
    WidgetsBinding.instance.addTimingsCallback(_onTimings);
    _ticker = Timer.periodic(interval, (_) => unawaited(_flush()));
    // Stderr message — visible if the app is launched directly via the
    // bundled executable (subprocess.Popen) rather than `open -na`.
    stderr.writeln(
        '[telemetry] MetricsReporter started · endpoint=$endpoint · interval=${interval.inSeconds}s');
    // Also dispatch a "ping" POST immediately so the harness can confirm
    // the endpoint is reachable BEFORE waiting for the first 5-second flush.
    unawaited(_ping());
  }

  Future<void> _ping() async {
    final pingUrl = endpoint.replaceAll('/flutter', '/ping');
    HttpClient? client;
    try {
      client = HttpClient()..connectionTimeout = const Duration(seconds: 2);
      final req = await client.postUrl(Uri.parse(pingUrl));
      req.headers.contentType = ContentType.json;
      req.add(utf8.encode(jsonEncode({
        'label': label,
        'kind': 'ping',
        'pid': pid,
        'timestamp_ms': DateTime.now().millisecondsSinceEpoch,
      })));
      final res = await req.close();
      await res.drain<void>();
      stderr.writeln(
          '[telemetry] ping OK · $pingUrl · status=${res.statusCode}');
    } catch (e) {
      stderr.writeln('[telemetry] ping FAILED · $pingUrl · err=$e');
      developer.log('telemetry ping failed: $e', name: 'metrics_reporter');
    } finally {
      client?.close(force: false);
    }
  }

  void stop() {
    WidgetsBinding.instance.removeTimingsCallback(_onTimings);
    _ticker?.cancel();
    _ticker = null;
  }

  void _onTimings(List<FrameTiming> timings) {
    _buffer.addAll(timings);
    final overflow = _buffer.length - maxBuffer;
    if (overflow > 0) {
      _buffer.removeRange(0, overflow);
    }
  }

  Future<void> _flush() async {
    if (_flushing || _buffer.isEmpty) return;
    _flushing = true;

    // Snapshot atomically — addTimingsCallback runs on the same isolate, so
    // we can copy + clear without a lock as long as no awaits happen between.
    final samples = List<FrameTiming>.unmodifiable(_buffer);
    _buffer.clear();

    final builds = <double>[];
    final rasters = <double>[];
    for (final t in samples) {
      builds.add(t.buildDuration.inMicroseconds / 1000.0);
      rasters.add(t.rasterDuration.inMicroseconds / 1000.0);
    }

    final payload = jsonEncode(<String, dynamic>{
      'label': label,
      'timestamp_ms': DateTime.now().millisecondsSinceEpoch,
      'frame_count': samples.length,
      'builds_ms': builds,
      'rasters_ms': rasters,
    });

    _flushAttempts++;
    HttpClient? client;
    try {
      client = HttpClient()..connectionTimeout = const Duration(seconds: 2);
      final req = await client.postUrl(Uri.parse(endpoint));
      req.headers.contentType = ContentType.json;
      req.add(utf8.encode(payload));
      final res = await req.close();
      await res.drain<void>();
      _flushSuccesses++;
      // Print every 4th success (every 20 seconds) — enough to confirm
      // life-signs without spamming stderr during normal operation.
      if (_flushSuccesses == 1 || _flushSuccesses % 4 == 0) {
        stderr.writeln(
            '[telemetry] flush #$_flushSuccesses ok · ${samples.length} frames');
      }
    } catch (e) {
      _flushFailures++;
      _lastError = e.toString();
      // Always emit on first failure so the harness can correlate.
      if (_flushFailures == 1) {
        stderr.writeln('[telemetry] FIRST flush FAILED · err=$e');
        developer.log('First telemetry flush failed: $e',
            name: 'metrics_reporter');
      }
    } finally {
      client?.close(force: false);
      _flushing = false;
    }
  }
}
