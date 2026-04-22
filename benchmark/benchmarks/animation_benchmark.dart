// Copyright 2024 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '../svg_render_benchmark.dart';
import '../svg_content.dart';

// ignore: implementation_imports
import 'package:full_svg_flutter/src/animation/svg_parser.dart';
// ignore: implementation_imports
import 'package:full_svg_flutter/src/animation/svg_dom.dart';
// ignore: implementation_imports
import 'package:full_svg_flutter/src/animation/smil/smil_parser.dart';
// ignore: implementation_imports
import 'package:full_svg_flutter/src/animation/smil/smil_animation.dart';
// ignore: implementation_imports
import 'package:full_svg_flutter/src/animation/smil/smil_timeline.dart';

/// Runs animation processing benchmarks.
///
/// These benchmarks measure SMIL animation parsing and timeline setup.
List<BenchmarkResult> runAnimationBenchmarks() {
  final results = <BenchmarkResult>[];

  // Parse animation SVG
  late SvgDocument animDoc;
  results.add(
    runBenchmark(
      name: 'animation_parse_smil',
      setup: () {},
      benchmark: () {
        animDoc = SvgParser.parse(SvgTestContent.animation);
      },
      teardown: () {},
    ),
  );
  print('  ${results.last}');

  // Parse SMIL animations from document
  late List<SmilAnimation> animations;
  results.add(
    runBenchmark(
      name: 'animation_parse_smil_elements',
      setup: () {
        animDoc = SvgParser.parse(SvgTestContent.animation);
      },
      benchmark: () {
        animations = SmilParser.parseAnimations(animDoc);
      },
      teardown: () {},
    ),
  );
  print('  ${results.last}');

  // Create timeline from animations
  results.add(
    runBenchmark(
      name: 'animation_create_timeline',
      setup: () {
        animDoc = SvgParser.parse(SvgTestContent.animation);
        animations = SmilParser.parseAnimations(animDoc);
      },
      benchmark: () {
        final _ = SvgTimeline(animations: animations, rootNode: animDoc.root);
      },
      teardown: () {},
    ),
  );
  print('  ${results.last}');

  // Benchmark complex animation SVG with many animations
  const complexAnimationSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 300 300">
  <rect id="r1" x="10" y="10" width="20" height="20" fill="#f00">
    <animate attributeName="x" from="10" to="270" dur="3s" repeatCount="indefinite"/>
    <animate attributeName="y" from="10" to="270" dur="4s" repeatCount="indefinite"/>
    <animate attributeName="width" values="20;40;20" dur="1s" repeatCount="indefinite"/>
    <animate attributeName="height" values="20;40;20" dur="1.5s" repeatCount="indefinite"/>
    <animate attributeName="fill" values="#f00;#0f0;#00f;#f00" dur="2s" repeatCount="indefinite"/>
    <animate attributeName="opacity" values="1;0.5;1" dur="2.5s" repeatCount="indefinite"/>
  </rect>
  <circle id="c1" cx="150" cy="150" r="30" fill="#0f0">
    <animate attributeName="cx" values="50;250;50" dur="3s" repeatCount="indefinite"/>
    <animate attributeName="cy" values="50;250;50" dur="4s" repeatCount="indefinite"/>
    <animate attributeName="r" values="30;50;30" dur="2s" repeatCount="indefinite"/>
    <animate attributeName="fill-opacity" values="1;0.3;1" dur="1.5s" repeatCount="indefinite"/>
  </circle>
  <g id="g1">
    <animateTransform attributeName="transform" type="rotate" 
      from="0 150 150" to="360 150 150" dur="5s" repeatCount="indefinite"/>
    <animateTransform attributeName="transform" type="scale" 
      values="1;1.2;1" dur="2s" repeatCount="indefinite" additive="sum"/>
    <rect x="130" y="130" width="40" height="40" fill="#00f"/>
    <circle cx="150" cy="150" r="15" fill="#ff0"/>
  </g>
  <path id="p1" d="M 20 280 L 50 250 L 80 280" stroke="#f0f" fill="none" stroke-width="3">
    <animate attributeName="d" 
      values="M 20 280 L 50 250 L 80 280;M 20 260 L 50 290 L 80 260;M 20 280 L 50 250 L 80 280"
      dur="2s" repeatCount="indefinite"/>
    <animate attributeName="stroke-width" values="3;6;3" dur="1s" repeatCount="indefinite"/>
  </path>
  <ellipse id="e1" cx="250" cy="50" rx="30" ry="20" fill="#0ff">
    <animate attributeName="rx" values="30;45;30" dur="2s" repeatCount="indefinite"/>
    <animate attributeName="ry" values="20;35;20" dur="2.5s" repeatCount="indefinite"/>
  </ellipse>
</svg>
''';

  results.add(
    runBenchmark(
      name: 'animation_parse_complex',
      setup: () {},
      benchmark: () {
        SvgParser.parse(complexAnimationSvg);
      },
      teardown: () {},
    ),
  );
  print('  ${results.last}');

  // Benchmark timeline tick simulation
  late SvgTimeline timeline;
  results.add(
    runBenchmark(
      name: 'animation_timeline_tick',
      setup: () {
        final doc = SvgParser.parse(complexAnimationSvg);
        animations = SmilParser.parseAnimations(doc);
        timeline = SvgTimeline(animations: animations, rootNode: doc.root);
      },
      benchmark: () {
        // Simulate ticking through multiple time points
        for (var t = 0; t < 100; t++) {
          timeline.seek(Duration(milliseconds: t * 16)); // ~60fps
        }
      },
      teardown: () {},
    ),
  );
  print('  ${results.last}');

  // Benchmark CSS animation parsing
  const cssAnimationSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 200">
  <style>
    @keyframes spin {
      from { transform: rotate(0deg); }
      to { transform: rotate(360deg); }
    }
    @keyframes pulse {
      0%, 100% { opacity: 1; }
      50% { opacity: 0.5; }
    }
    @keyframes colorChange {
      0% { fill: #ff0000; }
      33% { fill: #00ff00; }
      66% { fill: #0000ff; }
      100% { fill: #ff0000; }
    }
    .spinner { animation: spin 2s linear infinite; }
    .pulser { animation: pulse 1s ease-in-out infinite; }
    .colorful { animation: colorChange 3s ease infinite; }
  </style>
  <g class="spinner" transform-origin="100 100">
    <rect x="80" y="80" width="40" height="40" class="colorful"/>
  </g>
  <circle cx="50" cy="150" r="20" class="pulser" fill="#ff6600"/>
  <circle cx="150" cy="150" r="20" class="pulser colorful"/>
</svg>
''';

  results.add(
    runBenchmark(
      name: 'animation_parse_css_keyframes',
      setup: () {},
      benchmark: () {
        SvgParser.parse(cssAnimationSvg);
      },
      teardown: () {},
    ),
  );
  print('  ${results.last}');

  return results;
}
