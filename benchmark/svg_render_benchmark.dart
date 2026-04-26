// ignore_for_file: avoid_print
// Copyright 2024 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// SVG Rendering Performance Benchmarks
//
// This benchmark suite establishes baseline performance metrics for SVG
// rendering operations to enable regression detection and cache tuning.
//
// Run with: flutter test benchmark/svg_render_benchmark.dart
//
// For JSON output:
// flutter test benchmark/svg_render_benchmark.dart --dart-define=JSON_OUTPUT=true

import 'benchmark_config.dart';
import 'benchmarks/parse_benchmark.dart';
import 'benchmarks/filter_benchmark.dart';
import 'benchmarks/animation_benchmark.dart';
import 'benchmarks/text_benchmark.dart';
import 'benchmarks/dash_pattern_benchmark.dart';
import 'benchmarks/filter_chain_benchmark.dart';
import 'benchmarks/text_render_benchmark.dart';
import 'benchmarks/animation_render_benchmark.dart';
import 'benchmarks/combined_worst_case_benchmark.dart';
import 'benchmarks/memory_benchmark.dart';

/// Benchmark result container.
class BenchmarkResult {
  BenchmarkResult({
    required this.name,
    required this.iterations,
    required this.minMs,
    required this.avgMs,
    required this.maxMs,
    this.memoryDeltaKb,
  });

  final String name;
  final int iterations;
  final double minMs;
  final double avgMs;
  final double maxMs;
  final int? memoryDeltaKb;

  @override
  String toString() {
    final memoryInfo = memoryDeltaKb != null
        ? ' | memory: ${memoryDeltaKb}KB'
        : '';
    return 'Benchmark: $name - min: ${minMs.toStringAsFixed(3)}ms, '
        'avg: ${avgMs.toStringAsFixed(3)}ms, max: ${maxMs.toStringAsFixed(3)}ms '
        '($iterations iterations)$memoryInfo';
  }

  /// Machine-parseable format for CI integration.
  String toJson() {
    return '{"name":"$name","iterations":$iterations,'
        '"min_ms":${minMs.toStringAsFixed(3)},'
        '"avg_ms":${avgMs.toStringAsFixed(3)},'
        '"max_ms":${maxMs.toStringAsFixed(3)}'
        '${memoryDeltaKb != null ? ',"memory_kb":$memoryDeltaKb' : ''}}';
  }
}

/// Runs a benchmark function multiple times and collects statistics.
BenchmarkResult runBenchmark({
  required String name,
  required void Function() setup,
  required void Function() benchmark,
  required void Function() teardown,
  int warmupIterations = BenchmarkConfig.warmupIterations,
  int iterations = BenchmarkConfig.iterations,
}) {
  // Setup
  setup();

  // Warmup runs (not measured)
  for (var i = 0; i < warmupIterations; i++) {
    benchmark();
  }

  // Measured runs
  final times = <double>[];
  final stopwatch = Stopwatch();

  for (var i = 0; i < iterations; i++) {
    stopwatch.reset();
    stopwatch.start();
    benchmark();
    stopwatch.stop();
    times.add(stopwatch.elapsedMicroseconds / 1000.0);
  }

  // Teardown
  teardown();

  // Calculate statistics
  times.sort();
  final minMs = times.first;
  final maxMs = times.last;
  final avgMs = times.reduce((a, b) => a + b) / times.length;

  return BenchmarkResult(
    name: name,
    iterations: iterations,
    minMs: minMs,
    avgMs: avgMs,
    maxMs: maxMs,
  );
}

/// Runs a benchmark with memory tracking.
BenchmarkResult runBenchmarkWithMemory({
  required String name,
  required void Function() setup,
  required void Function() benchmark,
  required void Function() teardown,
  int warmupIterations = BenchmarkConfig.warmupIterations,
  int iterations = BenchmarkConfig.iterations,
}) {
  final result = runBenchmark(
    name: name,
    setup: setup,
    benchmark: benchmark,
    teardown: teardown,
    warmupIterations: warmupIterations,
    iterations: iterations,
  );

  // Note: Dart doesn't provide direct memory measurement in standalone mode.
  // Memory tracking would require running in a profiler or using VM service.
  return result;
}

void main() {
  final jsonOutput = const bool.fromEnvironment('JSON_OUTPUT');
  final results = <BenchmarkResult>[];

  print('═══════════════════════════════════════════════════════════════════');
  print('                SVG Rendering Performance Benchmarks');
  print('═══════════════════════════════════════════════════════════════════');
  print('');
  print('Configuration:');
  print('  Warmup iterations: ${BenchmarkConfig.warmupIterations}');
  print('  Measured iterations: ${BenchmarkConfig.iterations}');
  print('');

  // Run all benchmark suites
  print('───────────────────────────────────────────────────────────────────');
  print('1. SVG Parsing Benchmarks');
  print('───────────────────────────────────────────────────────────────────');
  results.addAll(runParseBenchmarks());
  print('');

  print('───────────────────────────────────────────────────────────────────');
  print('2. Filter Chain Benchmarks');
  print('───────────────────────────────────────────────────────────────────');
  results.addAll(runFilterBenchmarks());
  print('');

  print('───────────────────────────────────────────────────────────────────');
  print('3. Animation Processing Benchmarks');
  print('───────────────────────────────────────────────────────────────────');
  results.addAll(runAnimationBenchmarks());
  print('');

  print('───────────────────────────────────────────────────────────────────');
  print('4. Text Layout Benchmarks');
  print('───────────────────────────────────────────────────────────────────');
  results.addAll(runTextBenchmarks());
  print('');

  print('───────────────────────────────────────────────────────────────────');
  print('5. Dash Pattern Benchmarks');
  print('───────────────────────────────────────────────────────────────────');
  results.addAll(runDashPatternBenchmarks());
  print('');

  print('───────────────────────────────────────────────────────────────────');
  print('6. Filter Chain Benchmarks');
  print('───────────────────────────────────────────────────────────────────');
  results.addAll(runFilterChainBenchmarks());
  print('');

  print('───────────────────────────────────────────────────────────────────');
  print('7. Text Render Benchmarks');
  print('───────────────────────────────────────────────────────────────────');
  results.addAll(runTextRenderBenchmarks());
  print('');

  print('───────────────────────────────────────────────────────────────────');
  print('8. Animation Render Benchmarks');
  print('───────────────────────────────────────────────────────────────────');
  results.addAll(runAnimationRenderBenchmarks());
  print('');

  print('───────────────────────────────────────────────────────────────────');
  print('9. Combined Worst-Case Benchmarks');
  print('───────────────────────────────────────────────────────────────────');
  results.addAll(runCombinedWorstCaseBenchmarks());
  print('');

  print('───────────────────────────────────────────────────────────────────');
  print('10. Memory Benchmarks');
  print('───────────────────────────────────────────────────────────────────');
  results.addAll(runMemoryBenchmarks());
  print('');

  // Summary
  print('═══════════════════════════════════════════════════════════════════');
  print('                           Summary');
  print('═══════════════════════════════════════════════════════════════════');

  for (final result in results) {
    print(result);
  }

  // JSON output for CI
  if (jsonOutput) {
    print('');
    print(
      '───────────────────────────────────────────────────────────────────',
    );
    print('JSON Output:');
    print(
      '───────────────────────────────────────────────────────────────────',
    );
    print('[${results.map((r) => r.toJson()).join(',')}]');
  }

  print('');
  print('Benchmarks completed successfully.');
}
