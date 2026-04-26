// ignore_for_file: avoid_print
// Copyright 2024 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '../svg_render_benchmark.dart';
import '../svg_content.dart';

// ignore: implementation_imports
import 'package:full_svg_flutter/src/animation/svg_parser.dart';

/// Runs dash pattern benchmarks.
///
/// These benchmarks are particularly important for verifying that dash pattern
/// computation completes in bounded time (relates to infinite loop fixes).
List<BenchmarkResult> runDashPatternBenchmarks() {
  final results = <BenchmarkResult>[];

  // Parse SVG with various dash patterns
  results.add(
    runBenchmark(
      name: 'dash_parse_patterns',
      setup: () {},
      benchmark: () {
        SvgParser.parse(SvgTestContent.dashPatterns);
      },
      teardown: () {},
    ),
  );
  print('  ${results.last}');

  // Parse SVG with many dashed elements
  const manyDashedSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 500 500">
  <line x1="10" y1="10" x2="490" y2="10" stroke="#000" stroke-width="1" stroke-dasharray="2,2"/>
  <line x1="10" y1="20" x2="490" y2="20" stroke="#000" stroke-width="1" stroke-dasharray="4,2"/>
  <line x1="10" y1="30" x2="490" y2="30" stroke="#000" stroke-width="1" stroke-dasharray="6,2"/>
  <line x1="10" y1="40" x2="490" y2="40" stroke="#000" stroke-width="1" stroke-dasharray="8,2"/>
  <line x1="10" y1="50" x2="490" y2="50" stroke="#000" stroke-width="1" stroke-dasharray="10,2"/>
  <line x1="10" y1="60" x2="490" y2="60" stroke="#000" stroke-width="2" stroke-dasharray="5,5"/>
  <line x1="10" y1="70" x2="490" y2="70" stroke="#000" stroke-width="2" stroke-dasharray="10,5"/>
  <line x1="10" y1="80" x2="490" y2="80" stroke="#000" stroke-width="2" stroke-dasharray="15,5"/>
  <line x1="10" y1="90" x2="490" y2="90" stroke="#000" stroke-width="2" stroke-dasharray="20,5"/>
  <line x1="10" y1="100" x2="490" y2="100" stroke="#000" stroke-width="2" stroke-dasharray="25,5"/>
  <rect x="10" y="120" width="100" height="50" stroke="#f00" fill="none" stroke-dasharray="5,5"/>
  <rect x="120" y="120" width="100" height="50" stroke="#0f0" fill="none" stroke-dasharray="10,5,5,5"/>
  <rect x="230" y="120" width="100" height="50" stroke="#00f" fill="none" stroke-dasharray="15,5,5,5,5,5"/>
  <rect x="340" y="120" width="100" height="50" stroke="#ff0" fill="none" stroke-dasharray="20,10"/>
  <circle cx="60" cy="220" r="40" stroke="#f0f" fill="none" stroke-dasharray="5,5"/>
  <circle cx="160" cy="220" r="40" stroke="#0ff" fill="none" stroke-dasharray="10,5"/>
  <circle cx="260" cy="220" r="40" stroke="#f00" fill="none" stroke-dasharray="15,5,5,5"/>
  <circle cx="360" cy="220" r="40" stroke="#0f0" fill="none" stroke-dasharray="20,10,5,10"/>
  <circle cx="460" cy="220" r="40" stroke="#00f" fill="none" stroke-dasharray="3,3,3,3,3,3"/>
  <path d="M 10 300 Q 125 250 250 300 T 490 300" stroke="#666" fill="none" stroke-dasharray="10,5"/>
  <path d="M 10 350 C 60 300 120 400 170 350 S 290 250 340 350 S 440 450 490 350" 
        stroke="#999" fill="none" stroke-dasharray="15,5,5,5"/>
  <ellipse cx="100" cy="420" rx="80" ry="40" stroke="#333" fill="none" stroke-dasharray="8,4"/>
  <ellipse cx="300" cy="420" rx="80" ry="40" stroke="#333" fill="none" stroke-dasharray="12,4,4,4"/>
  <polygon points="440,380 480,460 400,460" stroke="#000" fill="none" stroke-dasharray="5,5"/>
</svg>
''';

  results.add(
    runBenchmark(
      name: 'dash_parse_many',
      setup: () {},
      benchmark: () {
        SvgParser.parse(manyDashedSvg);
      },
      teardown: () {},
    ),
  );
  print('  ${results.last}');

  // Parse SVG with edge case dash patterns (very small values)
  const edgeCaseDashSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 200">
  <line x1="10" y1="10" x2="190" y2="10" stroke="#000" stroke-width="1" stroke-dasharray="0.5,0.5"/>
  <line x1="10" y1="25" x2="190" y2="25" stroke="#000" stroke-width="1" stroke-dasharray="0.1,0.1"/>
  <line x1="10" y1="40" x2="190" y2="40" stroke="#000" stroke-width="1" stroke-dasharray="1,0.1"/>
  <line x1="10" y1="55" x2="190" y2="55" stroke="#000" stroke-width="1" stroke-dasharray="0.01,0.01"/>
  <line x1="10" y1="70" x2="190" y2="70" stroke="#000" stroke-width="2" stroke-dasharray="100,50"/>
  <line x1="10" y1="85" x2="190" y2="85" stroke="#000" stroke-width="2" stroke-dasharray="50,25,10,5"/>
  <rect x="10" y="100" width="180" height="40" stroke="#f00" fill="none" stroke-dasharray="0.5,0.25"/>
  <circle cx="100" cy="170" r="25" stroke="#00f" fill="none" stroke-dasharray="2,1,0.5,0.25"/>
</svg>
''';

  results.add(
    runBenchmark(
      name: 'dash_parse_edge_cases',
      setup: () {},
      benchmark: () {
        SvgParser.parse(edgeCaseDashSvg);
      },
      teardown: () {},
    ),
  );
  print('  ${results.last}');

  // Parse SVG with stroke-dashoffset
  const dashOffsetSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 200">
  <line x1="10" y1="10" x2="190" y2="10" stroke="#000" stroke-dasharray="10,5" stroke-dashoffset="0"/>
  <line x1="10" y1="25" x2="190" y2="25" stroke="#000" stroke-dasharray="10,5" stroke-dashoffset="5"/>
  <line x1="10" y1="40" x2="190" y2="40" stroke="#000" stroke-dasharray="10,5" stroke-dashoffset="10"/>
  <line x1="10" y1="55" x2="190" y2="55" stroke="#000" stroke-dasharray="10,5" stroke-dashoffset="15"/>
  <line x1="10" y1="70" x2="190" y2="70" stroke="#000" stroke-dasharray="10,5" stroke-dashoffset="-5"/>
  <line x1="10" y1="85" x2="190" y2="85" stroke="#000" stroke-dasharray="10,5" stroke-dashoffset="-10"/>
  <circle cx="50" cy="130" r="30" stroke="#f00" fill="none" stroke-dasharray="10,5" stroke-dashoffset="25%"/>
  <circle cx="150" cy="130" r="30" stroke="#00f" fill="none" stroke-dasharray="10,5" stroke-dashoffset="50%"/>
  <path d="M 10 180 Q 100 140 190 180" stroke="#0f0" fill="none" 
        stroke-dasharray="15,10,5,10" stroke-dashoffset="20"/>
</svg>
''';

  results.add(
    runBenchmark(
      name: 'dash_parse_offset',
      setup: () {},
      benchmark: () {
        SvgParser.parse(dashOffsetSvg);
      },
      teardown: () {},
    ),
  );
  print('  ${results.last}');

  // Stress test with very long paths and dash patterns
  final longPathBuffer = StringBuffer();
  longPathBuffer.writeln(
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1000 500">',
  );
  // Create a very long path
  longPathBuffer.write('  <path d="M 0 250');
  for (var x = 10; x <= 1000; x += 10) {
    final y = 250 + (x % 100 < 50 ? -50 : 50);
    longPathBuffer.write(' L $x $y');
  }
  longPathBuffer.writeln(
    '" stroke="#000" fill="none" stroke-dasharray="5,3,2,3"/>',
  );

  // Add more complex paths
  for (var i = 0; i < 10; i++) {
    final y1 = 50 + i * 40;
    final y2 = 70 + i * 40;
    longPathBuffer.writeln(
      '  <path d="M 0 $y1 Q 250 $y2 500 $y1 T 1000 $y1" '
      'stroke="#${(i * 25).toRadixString(16).padLeft(2, '0')}${((10 - i) * 25).toRadixString(16).padLeft(2, '0')}ff" '
      'fill="none" stroke-dasharray="${5 + i},${3 + i}"/>',
    );
  }
  longPathBuffer.writeln('</svg>');
  final longPathSvg = longPathBuffer.toString();

  results.add(
    runBenchmark(
      name: 'dash_parse_long_path',
      setup: () {},
      benchmark: () {
        SvgParser.parse(longPathSvg);
      },
      teardown: () {},
    ),
  );
  print('  ${results.last}');

  // Verify bounded time completion (important regression test)
  // This test ensures that dash pattern processing doesn't hang
  const boundedTimeSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
  <line x1="0" y1="50" x2="100" y2="50" stroke="#000" stroke-dasharray="0.001,0.001"/>
  <circle cx="50" cy="50" r="45" stroke="#f00" fill="none" stroke-dasharray="0.01,0.01"/>
  <rect x="5" y="5" width="90" height="90" stroke="#00f" fill="none" stroke-dasharray="0.1,0.05"/>
</svg>
''';

  final stopwatch = Stopwatch()..start();
  results.add(
    runBenchmark(
      name: 'dash_bounded_time',
      setup: () {},
      benchmark: () {
        SvgParser.parse(boundedTimeSvg);
      },
      teardown: () {},
      iterations: 10, // Fewer iterations for this test
    ),
  );
  stopwatch.stop();
  print('  ${results.last}');

  // Verify it completed in reasonable time (< 5 seconds for 10 iterations)
  if (stopwatch.elapsedMilliseconds > 5000) {
    print('  WARNING: Dash pattern processing may have performance issues!');
  }

  return results;
}
