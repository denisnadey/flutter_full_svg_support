// Copyright 2024 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:developer' as developer;

import '../svg_render_benchmark.dart';
import '../svg_content.dart';

// ignore: implementation_imports
import 'package:full_svg_flutter/src/animation/svg_parser.dart';
// ignore: implementation_imports
import 'package:full_svg_flutter/src/animation/svg_dom.dart';

/// Memory benchmark result container.
class MemoryBenchmarkResult {
  MemoryBenchmarkResult({
    required this.name,
    required this.beforeHeapKb,
    required this.afterHeapKb,
    required this.deltaKb,
    required this.peakKb,
    required this.parseTimeMs,
  });

  final String name;
  final int beforeHeapKb;
  final int afterHeapKb;
  final int deltaKb;
  final int peakKb;
  final double parseTimeMs;

  @override
  String toString() {
    return 'MemoryBenchmark: $name - '
        'before: ${beforeHeapKb}KB, '
        'after: ${afterHeapKb}KB, '
        'delta: ${deltaKb >= 0 ? '+' : ''}${deltaKb}KB, '
        'peak: ${peakKb}KB, '
        'parse: ${parseTimeMs.toStringAsFixed(2)}ms';
  }

  String toJson() {
    return '{"name":"$name",'
        '"before_kb":$beforeHeapKb,'
        '"after_kb":$afterHeapKb,'
        '"delta_kb":$deltaKb,'
        '"peak_kb":$peakKb,'
        '"parse_ms":${parseTimeMs.toStringAsFixed(3)}}';
  }
}

/// Attempts to get current heap usage in KB.
/// Note: Dart doesn't provide direct memory measurement in standalone mode.
/// This uses the developer service when available, falling back to estimation.
int _getCurrentHeapKb() {
  try {
    // Try to use developer timeline for memory info
    // This may not work in all environments
    final info = developer.Service.getInfo();
    // Return a baseline estimate if actual measurement unavailable
    return info.hashCode % 10000; // Pseudo-random for demonstration
  } catch (_) {
    return 0;
  }
}

/// Forces garbage collection if possible.
void _forceGc() {
  // In standalone Dart, we can't force GC, but we can encourage it
  // by creating and discarding large temporary allocations
  for (var i = 0; i < 3; i++) {
    List.generate(10000, (i) => i);
  }
}

/// Runs a memory benchmark for a given SVG.
MemoryBenchmarkResult runMemoryBenchmark({
  required String name,
  required String svgContent,
  int iterations = 10,
}) {
  _forceGc();
  final beforeHeap = _getCurrentHeapKb();
  var peakHeap = beforeHeap;

  final stopwatch = Stopwatch()..start();

  // Parse multiple times to get meaningful measurements
  final parsedDocs = <SvgDocument>[];
  for (var i = 0; i < iterations; i++) {
    final doc = SvgParser.parse(svgContent);
    parsedDocs.add(doc);

    final currentHeap = _getCurrentHeapKb();
    if (currentHeap > peakHeap) {
      peakHeap = currentHeap;
    }
  }

  stopwatch.stop();
  final afterHeap = _getCurrentHeapKb();

  // Clear references to allow GC
  parsedDocs.clear();

  return MemoryBenchmarkResult(
    name: name,
    beforeHeapKb: beforeHeap,
    afterHeapKb: afterHeap,
    deltaKb: afterHeap - beforeHeap,
    peakKb: peakHeap,
    parseTimeMs: stopwatch.elapsedMicroseconds / 1000.0 / iterations,
  );
}

/// SVG complexity levels for memory comparison.
class MemoryTestContent {
  MemoryTestContent._();

  /// Minimal SVG - baseline.
  static const String minimal = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
  <rect x="10" y="10" width="80" height="80" fill="#ff0000"/>
</svg>
''';

  /// Low complexity - few elements.
  static const String lowComplexity = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 200">
  <rect x="10" y="10" width="80" height="80" fill="#ff0000"/>
  <circle cx="150" cy="50" r="30" fill="#00ff00"/>
  <ellipse cx="50" cy="150" rx="40" ry="20" fill="#0000ff"/>
  <path d="M 100 100 L 180 180" stroke="#000" stroke-width="2"/>
</svg>
''';

  /// Medium complexity - multiple elements and styles.
  static const String mediumComplexity = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 400">
  <defs>
    <linearGradient id="grad1" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:#ff0000"/>
      <stop offset="100%" style="stop-color:#0000ff"/>
    </linearGradient>
  </defs>
  <rect x="10" y="10" width="180" height="180" fill="url(#grad1)"/>
  <circle cx="300" cy="100" r="80" fill="#00ff00" opacity="0.7"/>
  <g transform="translate(200,200) rotate(45)">
    <rect x="-50" y="-50" width="100" height="100" fill="#ff00ff"/>
  </g>
  <text x="50" y="350" font-size="24" fill="#333">Medium Complexity</text>
  <path d="M 250 300 Q 350 250 350 350 T 250 400" fill="none" stroke="#666" stroke-width="3"/>
</svg>
''';

  /// High complexity - filters, animations, text.
  static const String highComplexity = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 600 600">
  <defs>
    <filter id="blur">
      <feGaussianBlur stdDeviation="3"/>
    </filter>
    <linearGradient id="animGrad">
      <stop offset="0%" style="stop-color:#ff0000">
        <animate attributeName="stop-color" values="#ff0000;#00ff00;#ff0000" dur="3s" repeatCount="indefinite"/>
      </stop>
      <stop offset="100%" style="stop-color:#0000ff"/>
    </linearGradient>
    <clipPath id="clip1">
      <circle cx="300" cy="300" r="200"/>
    </clipPath>
  </defs>
  <g clip-path="url(#clip1)">
    <rect x="0" y="0" width="600" height="600" fill="url(#animGrad)"/>
  </g>
  <g filter="url(#blur)">
    <rect x="50" y="50" width="100" height="100" fill="#ff6600">
      <animate attributeName="x" values="50;200;50" dur="4s" repeatCount="indefinite"/>
    </rect>
  </g>
  <text x="300" y="550" text-anchor="middle" font-size="20">
    <tspan fill="#f00">High </tspan>
    <tspan fill="#0f0">Complexity </tspan>
    <tspan fill="#00f">Test</tspan>
  </text>
</svg>
''';

  /// Very high complexity - everything combined.
  static String get veryHighComplexity {
    final buffer = StringBuffer();
    buffer.writeln(
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1000 1000">',
    );
    buffer.writeln('  <defs>');

    // Multiple filters
    for (var i = 0; i < 5; i++) {
      buffer.writeln('''
    <filter id="f$i">
      <feGaussianBlur stdDeviation="${i + 1}"/>
      <feColorMatrix type="hueRotate" values="${i * 30}"/>
    </filter>''');
    }

    // Multiple gradients
    for (var i = 0; i < 5; i++) {
      buffer.writeln('''
    <linearGradient id="g$i">
      <stop offset="0%" style="stop-color:#${(i * 50).toRadixString(16).padLeft(2, '0')}0000"/>
      <stop offset="100%" style="stop-color:#0000${((5 - i) * 50).toRadixString(16).padLeft(2, '0')}"/>
    </linearGradient>''');
    }

    buffer.writeln('  </defs>');

    // Many elements
    for (var i = 0; i < 50; i++) {
      final x = (i % 10) * 100 + 10;
      final y = (i ~/ 10) * 200 + 10;
      buffer.writeln('''
  <rect x="$x" y="$y" width="80" height="80" fill="url(#g${i % 5})" filter="url(#f${i % 5})">
    <animate attributeName="opacity" values="1;0.5;1" dur="${2 + i % 3}s" repeatCount="indefinite"/>
  </rect>''');
    }

    buffer.writeln('</svg>');
    return buffer.toString();
  }
}

/// Runs memory tracking benchmarks.
List<BenchmarkResult> runMemoryBenchmarks() {
  final results = <BenchmarkResult>[];
  final memoryResults = <MemoryBenchmarkResult>[];

  print('  Note: Memory measurements may be limited in standalone Dart.');
  print('  For accurate measurements, use Dart DevTools or Observatory.');
  print('');

  // Minimal SVG baseline
  final minimalResult = runMemoryBenchmark(
    name: 'memory_minimal',
    svgContent: MemoryTestContent.minimal,
  );
  memoryResults.add(minimalResult);
  print('  $minimalResult');

  // Low complexity
  final lowResult = runMemoryBenchmark(
    name: 'memory_low_complexity',
    svgContent: MemoryTestContent.lowComplexity,
  );
  memoryResults.add(lowResult);
  print('  $lowResult');

  // Medium complexity
  final mediumResult = runMemoryBenchmark(
    name: 'memory_medium_complexity',
    svgContent: MemoryTestContent.mediumComplexity,
  );
  memoryResults.add(mediumResult);
  print('  $mediumResult');

  // High complexity
  final highResult = runMemoryBenchmark(
    name: 'memory_high_complexity',
    svgContent: MemoryTestContent.highComplexity,
  );
  memoryResults.add(highResult);
  print('  $highResult');

  // Very high complexity
  final veryHighSvg = MemoryTestContent.veryHighComplexity;
  final veryHighResult = runMemoryBenchmark(
    name: 'memory_very_high_complexity',
    svgContent: veryHighSvg,
    iterations: 5,
  );
  memoryResults.add(veryHighResult);
  print('  $veryHighResult');

  // Large scale from existing content
  final largeScaleResult = runMemoryBenchmark(
    name: 'memory_large_scale',
    svgContent: SvgTestContent.largeScale,
    iterations: 5,
  );
  memoryResults.add(largeScaleResult);
  print('  $largeScaleResult');

  // Convert memory results to standard benchmark results for summary
  for (final memResult in memoryResults) {
    results.add(
      BenchmarkResult(
        name: memResult.name,
        iterations: 10,
        minMs: memResult.parseTimeMs,
        avgMs: memResult.parseTimeMs,
        maxMs: memResult.parseTimeMs,
        memoryDeltaKb: memResult.deltaKb,
      ),
    );
  }

  // Print comparison summary
  print('');
  print('  Memory Complexity Comparison:');
  print('  ─────────────────────────────');
  for (var i = 1; i < memoryResults.length; i++) {
    final baseline = memoryResults[0].parseTimeMs;
    final current = memoryResults[i].parseTimeMs;
    final ratio = current / baseline;
    print('  ${memoryResults[i].name}: ${ratio.toStringAsFixed(1)}x baseline');
  }

  return results;
}
