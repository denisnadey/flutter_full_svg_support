// Copyright 2024 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '../svg_render_benchmark.dart';
import '../svg_content.dart';

// Import SVG parser for parsing benchmarks
// ignore: implementation_imports
import 'package:flutter_svg/src/animation/svg_parser.dart';

/// Runs SVG parsing benchmarks.
List<BenchmarkResult> runParseBenchmarks() {
  final results = <BenchmarkResult>[];

  // Simple SVG parsing
  results.add(_benchmarkParse('parse_simple', SvgTestContent.simple));
  print('  ${results.last}');

  // Gradient SVG parsing
  results.add(_benchmarkParse('parse_gradients', SvgTestContent.gradients));
  print('  ${results.last}');

  // Filter chain parsing
  results.add(
    _benchmarkParse('parse_filter_chain', SvgTestContent.filterChain),
  );
  print('  ${results.last}');

  // Animation SVG parsing
  results.add(_benchmarkParse('parse_animation', SvgTestContent.animation));
  print('  ${results.last}');

  // Text-heavy SVG parsing
  results.add(_benchmarkParse('parse_text_heavy', SvgTestContent.textHeavy));
  print('  ${results.last}');

  // Dash patterns parsing
  results.add(
    _benchmarkParse('parse_dash_patterns', SvgTestContent.dashPatterns),
  );
  print('  ${results.last}');

  // Nested groups parsing
  results.add(_benchmarkParse('parse_nested', SvgTestContent.nested));
  print('  ${results.last}');

  // Clipping parsing
  results.add(_benchmarkParse('parse_clipping', SvgTestContent.clipping));
  print('  ${results.last}');

  // Large-scale SVG parsing
  final largeSvg = SvgTestContent.largeScale;
  results.add(_benchmarkParse('parse_large_scale', largeSvg));
  print('  ${results.last}');

  // Repeated parsing (measures caching effectiveness at parse level)
  late dynamic parsedDoc;
  results.add(
    runBenchmark(
      name: 'parse_repeated_access',
      setup: () {
        parsedDoc = SvgParser.parse(SvgTestContent.simple);
      },
      benchmark: () {
        // Access various parts of the parsed document
        // ignore: unused_local_variable
        final viewBox = parsedDoc.viewBox;
        // ignore: unused_local_variable
        final root = parsedDoc.root;
      },
      teardown: () {},
    ),
  );
  print('  ${results.last}');

  return results;
}

BenchmarkResult _benchmarkParse(String name, String svgContent) {
  return runBenchmark(
    name: name,
    setup: () {},
    benchmark: () {
      SvgParser.parse(svgContent);
    },
    teardown: () {},
  );
}
