import 'dart:ui' show FrameTiming;

import 'package:flutter/widgets.dart' show WidgetsBinding;

import 'result_models.dart';

/// Collects frame timing data via [WidgetsBinding.addTimingsCallback].
///
/// Usage:
/// ```dart
/// final collector = MetricsCollector();
/// collector.start();
/// // ... pump frames ...
/// final metrics = collector.collect(name: 'My test', package: 'flutter_svg', scenario: 'render_simple');
/// collector.stop();
/// ```
class MetricsCollector {
  final List<FrameTiming> _timings = [];
  late void Function(List<FrameTiming>) _callback;
  bool _running = false;

  /// Registers the frame timing callback with [WidgetsBinding].
  void start() {
    if (_running) return;
    _callback = (List<FrameTiming> timings) {
      _timings.addAll(timings);
    };
    WidgetsBinding.instance.addTimingsCallback(_callback);
    _running = true;
  }

  /// Removes the callback from [WidgetsBinding].
  void stop() {
    if (!_running) return;
    WidgetsBinding.instance.removeTimingsCallback(_callback);
    _running = false;
  }

  /// Clears all collected timings without stopping the callback.
  void reset() {
    _timings.clear();
  }

  /// Computes [BenchmarkMetrics] from the collected [FrameTiming] data.
  ///
  /// [firstPaintMs] is passed in from the caller because it must be measured
  /// externally (wall-clock from pump to first rendered frame).
  BenchmarkMetrics collect({
    required String name,
    required String package,
    required String scenario,
    double firstPaintMs = 0.0,
    double memoryBeforeMb = 0.0,
    double memoryAfterMb = 0.0,
    int benchmarkDurationMs = 0,
  }) {
    final buildDurations = _timings
        .map((t) => t.buildDuration.inMicroseconds / 1000.0)
        .toList()
      ..sort();

    final rasterDurations = _timings
        .map((t) => t.rasterDuration.inMicroseconds / 1000.0)
        .toList()
      ..sort();

    final frameCount = _timings.length;

    return BenchmarkMetrics(
      name: name,
      package: package,
      scenario: scenario,
      firstPaintMs: firstPaintMs,
      avgBuildMs: _average(buildDurations),
      p90BuildMs: _percentile(buildDurations, 90),
      p99BuildMs: _percentile(buildDurations, 99),
      worstBuildMs: buildDurations.isEmpty ? 0.0 : buildDurations.last,
      avgRasterMs: _average(rasterDurations),
      p90RasterMs: _percentile(rasterDurations, 90),
      p99RasterMs: _percentile(rasterDurations, 99),
      worstRasterMs: rasterDurations.isEmpty ? 0.0 : rasterDurations.last,
      frameCount: frameCount,
      // 60 Hz budget: 16.67 ms per frame
      jankFrameCount60hz: buildDurations.where((d) => d > 16.67).length,
      // 120 Hz budget: 8.33 ms per frame
      jankFrameCount120hz: buildDurations.where((d) => d > 8.33).length,
      memoryBeforeMb: memoryBeforeMb,
      memoryAfterMb: memoryAfterMb,
      memoryDeltaMb: memoryAfterMb - memoryBeforeMb,
      benchmarkDurationMs: benchmarkDurationMs,
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Returns the arithmetic mean of [values], or 0 if empty.
  static double _average(List<double> values) {
    if (values.isEmpty) return 0.0;
    final sum = values.fold(0.0, (a, b) => a + b);
    return sum / values.length;
  }

  /// Returns the [p]-th percentile from a *sorted* list.
  ///
  /// Uses the nearest-rank method. Returns 0 if [sorted] is empty.
  static double _percentile(List<double> sorted, int p) {
    if (sorted.isEmpty) return 0.0;
    if (sorted.length == 1) return sorted.first;
    final rank = (p / 100.0 * sorted.length).ceil().clamp(1, sorted.length);
    return sorted[rank - 1];
  }
}
