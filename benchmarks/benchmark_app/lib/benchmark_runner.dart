import 'metrics_collector.dart';
import 'result_models.dart';

/// Orchestrates warm-up and measurement phases for a single benchmark scenario.
///
/// Designed to be called from `integration_test` via a pump callback so that
/// `flutter_test` is never imported into production `lib/` code.
///
/// ### Algorithm
/// 1. Caller pumps the initial widget (outside this class).
/// 2. Warm up: pump via [pumpFrame] for [warmupDuration].
/// 3. TODO: snapshot memory before (dart:developer Service.getVM).
/// 4. Start [MetricsCollector], pump for [measureDuration], stop collector.
/// 5. TODO: snapshot memory after.
/// 6. Return [BenchmarkMetrics].
class BenchmarkRunner {
  /// Runs a single scenario.
  ///
  /// [pumpFrame] must call `tester.pump(duration)` and return its future — this
  /// keeps `flutter_test` out of `lib/` while still driving the render loop.
  static Future<BenchmarkMetrics> runScenario({
    required String name,
    required String package,
    required String scenario,
    required Future<void> Function(Duration) pumpFrame,
    Duration warmupDuration = const Duration(seconds: 2),
    Duration measureDuration = const Duration(seconds: 5),
  }) async {
    const tick = Duration(milliseconds: 16);

    // -------------------------------------------------------------------------
    // 1. Warm-up phase
    // -------------------------------------------------------------------------
    final warmupEnd = DateTime.now().add(warmupDuration);
    while (DateTime.now().isBefore(warmupEnd)) {
      await pumpFrame(tick);
    }

    // -------------------------------------------------------------------------
    // 2. Memory snapshot before
    // -------------------------------------------------------------------------
    // TODO: read heap via dart:developer Service.getVM().isolates[0].heapUsage
    //       and convert bytes to MB.
    const double memoryBeforeMb = 0.0;

    // -------------------------------------------------------------------------
    // 3. Measure phase
    // -------------------------------------------------------------------------
    final collector = MetricsCollector();
    collector.reset();
    collector.start();

    final measureStart = DateTime.now();
    final firstFrameStopwatch = Stopwatch()..start();
    await pumpFrame(tick); // first measured frame
    firstFrameStopwatch.stop();
    final firstPaintMs = firstFrameStopwatch.elapsedMicroseconds / 1000.0;

    final measureEnd = measureStart.add(measureDuration);
    while (DateTime.now().isBefore(measureEnd)) {
      await pumpFrame(tick);
    }

    collector.stop();
    final actualDurationMs = DateTime.now().difference(measureStart).inMilliseconds;

    // -------------------------------------------------------------------------
    // 4. Memory snapshot after
    // -------------------------------------------------------------------------
    // TODO: read heap via dart:developer Service.getVM().isolates[0].heapUsage
    const double memoryAfterMb = 0.0;

    // -------------------------------------------------------------------------
    // 5. Build result
    // -------------------------------------------------------------------------
    return collector.collect(
      name: name,
      package: package,
      scenario: scenario,
      firstPaintMs: firstPaintMs,
      memoryBeforeMb: memoryBeforeMb,
      memoryAfterMb: memoryAfterMb,
      benchmarkDurationMs: actualDurationMs,
    );
  }
}
