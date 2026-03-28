// Copyright 2024 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '../svg_render_benchmark.dart';

// ignore: implementation_imports
import 'package:flutter_svg/src/animation/svg_parser.dart';

/// Complex filter chain SVG content for benchmarks.
class FilterChainContent {
  FilterChainContent._();

  /// Complex filter chain with blur + color-matrix + composite.
  static const String complexChain = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 400">
  <defs>
    <filter id="ultraComplex" x="-50%" y="-50%" width="200%" height="200%">
      <!-- Multi-stage blur pipeline -->
      <feGaussianBlur in="SourceGraphic" stdDeviation="2" result="blur1"/>
      <feGaussianBlur in="blur1" stdDeviation="4" result="blur2"/>
      <feGaussianBlur in="blur2" stdDeviation="8" result="blur3"/>
      
      <!-- Color manipulation chain -->
      <feColorMatrix in="blur3" type="saturate" values="2" result="saturated"/>
      <feColorMatrix in="saturated" type="hueRotate" values="45" result="hueShift"/>
      <feColorMatrix in="hueShift" type="matrix" result="colorMatrix"
        values="1.5 0 0 0 -0.1
                0 1.2 0 0 0
                0 0 0.8 0 0.1
                0 0 0 1 0"/>
      
      <!-- Composite operations -->
      <feOffset in="SourceAlpha" dx="4" dy="4" result="shadow"/>
      <feGaussianBlur in="shadow" stdDeviation="3" result="shadowBlur"/>
      <feFlood flood-color="#000000" flood-opacity="0.5" result="shadowColor"/>
      <feComposite in="shadowColor" in2="shadowBlur" operator="in" result="shadowFinal"/>
      
      <!-- Merge everything -->
      <feMerge>
        <feMergeNode in="shadowFinal"/>
        <feMergeNode in="colorMatrix"/>
        <feMergeNode in="SourceGraphic"/>
      </feMerge>
    </filter>
    
    <filter id="glowEffect" x="-100%" y="-100%" width="300%" height="300%">
      <feGaussianBlur in="SourceAlpha" stdDeviation="10" result="glow"/>
      <feColorMatrix in="glow" type="matrix" result="colorGlow"
        values="0 0 0 0 1
                0 0 0 0 0.5
                0 0 0 0 0
                0 0 0 1 0"/>
      <feMerge>
        <feMergeNode in="colorGlow"/>
        <feMergeNode in="colorGlow"/>
        <feMergeNode in="SourceGraphic"/>
      </feMerge>
    </filter>
    
    <filter id="emboss">
      <feConvolveMatrix kernelMatrix="
        -2 -1 0
        -1  1 1
         0  1 2" result="embossed"/>
      <feComposite in="embossed" in2="SourceGraphic" operator="arithmetic" 
        k1="0.5" k2="0.5" k3="0" k4="0"/>
    </filter>
    
    <filter id="displacement">
      <feTurbulence type="turbulence" baseFrequency="0.02" numOctaves="3" result="noise"/>
      <feDisplacementMap in="SourceGraphic" in2="noise" scale="15" 
        xChannelSelector="R" yChannelSelector="G"/>
    </filter>
  </defs>
  
  <rect x="20" y="20" width="150" height="150" fill="#ff6600" filter="url(#ultraComplex)"/>
  <circle cx="300" cy="100" r="60" fill="#00ff66" filter="url(#glowEffect)"/>
  <rect x="20" y="220" width="150" height="150" fill="#6600ff" filter="url(#emboss)"/>
  <circle cx="300" cy="300" r="60" fill="#ff0066" filter="url(#displacement)"/>
  
  <path d="M 150 200 Q 200 100 250 200 T 350 200" 
    stroke="#0066ff" fill="none" stroke-width="8" filter="url(#ultraComplex)"/>
</svg>
''';

  /// Nested filter chains with multiple levels.
  static const String nestedChain = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 500 500">
  <defs>
    <filter id="innerFilter">
      <feGaussianBlur stdDeviation="2" result="innerBlur"/>
      <feColorMatrix in="innerBlur" type="saturate" values="1.5"/>
    </filter>
    
    <filter id="outerFilter">
      <feGaussianBlur stdDeviation="4" result="outerBlur"/>
      <feOffset in="outerBlur" dx="5" dy="5" result="outerOffset"/>
      <feMerge>
        <feMergeNode in="outerOffset"/>
        <feMergeNode in="SourceGraphic"/>
      </feMerge>
    </filter>
    
    <filter id="finalFilter">
      <feGaussianBlur stdDeviation="1" result="finalBlur"/>
      <feColorMatrix in="finalBlur" type="hueRotate" values="90" result="hue"/>
      <feBlend in="hue" in2="SourceGraphic" mode="overlay"/>
    </filter>
  </defs>
  
  <g filter="url(#finalFilter)">
    <g filter="url(#outerFilter)">
      <g filter="url(#innerFilter)">
        <rect x="100" y="100" width="100" height="100" fill="#ff0000"/>
        <circle cx="200" cy="200" r="50" fill="#00ff00"/>
      </g>
      <rect x="250" y="100" width="100" height="100" fill="#0000ff"/>
    </g>
    <circle cx="400" cy="200" r="60" fill="#ff00ff"/>
  </g>
  
  <g filter="url(#outerFilter)">
    <rect x="100" y="300" width="300" height="100" fill="#ffff00"/>
    <text x="150" y="360" font-size="32" fill="#000">Filtered Text</text>
  </g>
</svg>
''';

  /// High filter count stress test.
  static String get manyFilters {
    final buffer = StringBuffer();
    buffer.writeln(
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1000 1000">',
    );
    buffer.writeln('  <defs>');

    // Generate many unique filters
    for (var i = 0; i < 20; i++) {
      final blurAmount = 1 + i * 0.5;
      buffer.writeln('''
    <filter id="filter$i">
      <feGaussianBlur stdDeviation="$blurAmount" result="blur"/>
      <feColorMatrix in="blur" type="hueRotate" values="${i * 18}"/>
    </filter>''');
    }

    buffer.writeln('  </defs>');

    // Apply each filter to elements
    for (var i = 0; i < 20; i++) {
      final x = (i % 5) * 200 + 10;
      final y = (i ~/ 5) * 250 + 10;
      buffer.writeln(
        '  <rect x="$x" y="$y" width="180" height="180" fill="#${(i * 12).toRadixString(16).padLeft(2, '0')}6699" filter="url(#filter$i)"/>',
      );
    }

    buffer.writeln('</svg>');
    return buffer.toString();
  }
}

/// Runs filter chain benchmarks.
///
/// These benchmarks focus on complex filter chain parsing and setup.
List<BenchmarkResult> runFilterChainBenchmarks() {
  final results = <BenchmarkResult>[];

  // Complex filter chain benchmark
  results.add(
    runBenchmark(
      name: 'filter_chain_complex',
      setup: () {},
      benchmark: () {
        SvgParser.parse(FilterChainContent.complexChain);
      },
      teardown: () {},
    ),
  );
  print('  ${results.last}');

  // Nested filter chain benchmark
  results.add(
    runBenchmark(
      name: 'filter_chain_nested',
      setup: () {},
      benchmark: () {
        SvgParser.parse(FilterChainContent.nestedChain);
      },
      teardown: () {},
    ),
  );
  print('  ${results.last}');

  // Many filters stress test
  final manyFiltersSvg = FilterChainContent.manyFilters;
  results.add(
    runBenchmark(
      name: 'filter_chain_many',
      setup: () {},
      benchmark: () {
        SvgParser.parse(manyFiltersSvg);
      },
      teardown: () {},
    ),
  );
  print('  ${results.last}');

  return results;
}
