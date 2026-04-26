// ignore_for_file: avoid_print
// Copyright 2024 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '../svg_render_benchmark.dart';
import '../svg_content.dart';

// ignore: implementation_imports
import 'package:full_svg_flutter/src/animation/svg_parser.dart';
// ignore: implementation_imports
import 'package:full_svg_flutter/src/animation/svg_dom.dart';

/// Runs filter chain benchmarks.
///
/// These benchmarks measure filter parsing and filter chain setup time.
/// Actual filter application requires a canvas context which is tested
/// in the widget benchmark.
List<BenchmarkResult> runFilterBenchmarks() {
  final results = <BenchmarkResult>[];

  // Parse filter-heavy SVG
  late SvgDocument filterDoc;
  results.add(
    runBenchmark(
      name: 'filter_parse_complex_chain',
      setup: () {},
      benchmark: () {
        filterDoc = SvgParser.parse(SvgTestContent.filterChain);
      },
      teardown: () {},
    ),
  );
  print('  ${results.last}');

  // Access filters from parsed document
  results.add(
    runBenchmark(
      name: 'filter_access_definitions',
      setup: () {
        filterDoc = SvgParser.parse(SvgTestContent.filterChain);
      },
      benchmark: () {
        // Access filter definitions - parsing and accessing the document structure
        // ignore: unused_local_variable
        final filters = filterDoc.filters;
        // ignore: unused_local_variable
        final root = filterDoc.root;
        // ignore: unused_local_variable
        final viewBox = filterDoc.viewBox;
      },
      teardown: () {},
    ),
  );
  print('  ${results.last}');

  // Benchmark parsing SVG with multiple filter types
  const multiFilterSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 200">
  <defs>
    <filter id="blur">
      <feGaussianBlur stdDeviation="5"/>
    </filter>
    <filter id="colorShift">
      <feColorMatrix type="hueRotate" values="90"/>
    </filter>
    <filter id="saturate">
      <feColorMatrix type="saturate" values="2"/>
    </filter>
    <filter id="invert">
      <feComponentTransfer>
        <feFuncR type="table" tableValues="1 0"/>
        <feFuncG type="table" tableValues="1 0"/>
        <feFuncB type="table" tableValues="1 0"/>
      </feComponentTransfer>
    </filter>
    <filter id="composite">
      <feGaussianBlur in="SourceGraphic" stdDeviation="2" result="blur"/>
      <feComposite in="SourceGraphic" in2="blur" operator="atop"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="40" height="40" fill="#f00" filter="url(#blur)"/>
  <rect x="60" y="10" width="40" height="40" fill="#0f0" filter="url(#colorShift)"/>
  <rect x="110" y="10" width="40" height="40" fill="#00f" filter="url(#saturate)"/>
  <rect x="10" y="60" width="40" height="40" fill="#ff0" filter="url(#invert)"/>
  <rect x="60" y="60" width="40" height="40" fill="#0ff" filter="url(#composite)"/>
</svg>
''';

  results.add(
    runBenchmark(
      name: 'filter_parse_multiple_types',
      setup: () {},
      benchmark: () {
        SvgParser.parse(multiFilterSvg);
      },
      teardown: () {},
    ),
  );
  print('  ${results.last}');

  // Benchmark filter chain with turbulence (computationally expensive)
  const turbulenceFilterSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 200">
  <defs>
    <filter id="turbulence">
      <feTurbulence type="fractalNoise" baseFrequency="0.05" numOctaves="3" result="noise"/>
      <feDisplacementMap in="SourceGraphic" in2="noise" scale="20" xChannelSelector="R" yChannelSelector="G"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="180" height="180" fill="#3366ff" filter="url(#turbulence)"/>
</svg>
''';

  results.add(
    runBenchmark(
      name: 'filter_parse_turbulence',
      setup: () {},
      benchmark: () {
        SvgParser.parse(turbulenceFilterSvg);
      },
      teardown: () {},
    ),
  );
  print('  ${results.last}');

  // Benchmark lighting filter (another expensive primitive)
  const lightingFilterSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 200">
  <defs>
    <filter id="lighting">
      <feDiffuseLighting in="SourceGraphic" surfaceScale="5" diffuseConstant="1" result="light">
        <fePointLight x="100" y="100" z="200"/>
      </feDiffuseLighting>
      <feComposite in="SourceGraphic" in2="light" operator="arithmetic" k1="1" k2="0" k3="0" k4="0"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="180" height="180" fill="#888" filter="url(#lighting)"/>
</svg>
''';

  results.add(
    runBenchmark(
      name: 'filter_parse_lighting',
      setup: () {},
      benchmark: () {
        SvgParser.parse(lightingFilterSvg);
      },
      teardown: () {},
    ),
  );
  print('  ${results.last}');

  return results;
}
