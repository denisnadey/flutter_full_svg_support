// Copyright 2024 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '../svg_render_benchmark.dart';

// ignore: implementation_imports
import 'package:flutter_svg/src/animation/svg_parser.dart';
// ignore: implementation_imports
import 'package:flutter_svg/src/animation/smil/smil_parser.dart';
// ignore: implementation_imports
import 'package:flutter_svg/src/animation/smil/smil_animation.dart';
// ignore: implementation_imports
import 'package:flutter_svg/src/animation/smil/smil_timeline.dart';

/// Animation render SVG content for benchmarks with multiple simultaneous animations.
class AnimationRenderContent {
  AnimationRenderContent._();

  /// Multiple simultaneous SMIL animations running at once.
  static const String simultaneousAnimations = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 600 600">
  <!-- Element with many simultaneous property animations -->
  <rect id="multiProp" x="50" y="50" width="100" height="100" fill="#ff0000">
    <animate attributeName="x" values="50;200;350;200;50" dur="4s" repeatCount="indefinite"/>
    <animate attributeName="y" values="50;100;50;100;50" dur="3s" repeatCount="indefinite"/>
    <animate attributeName="width" values="100;150;100;80;100" dur="2.5s" repeatCount="indefinite"/>
    <animate attributeName="height" values="100;80;120;100;100" dur="2s" repeatCount="indefinite"/>
    <animate attributeName="fill" values="#ff0000;#00ff00;#0000ff;#ffff00;#ff0000" dur="5s" repeatCount="indefinite"/>
    <animate attributeName="opacity" values="1;0.5;1;0.7;1" dur="3.5s" repeatCount="indefinite"/>
    <animate attributeName="rx" values="0;20;50;20;0" dur="4s" repeatCount="indefinite"/>
  </rect>
  
  <!-- Multiple circles with staggered animations -->
  <circle id="c1" cx="100" cy="300" r="30" fill="#ff6600">
    <animate attributeName="cx" values="100;500;100" dur="3s" repeatCount="indefinite"/>
    <animate attributeName="r" values="30;50;30" dur="1.5s" repeatCount="indefinite"/>
  </circle>
  <circle id="c2" cx="150" cy="350" r="25" fill="#ff9900">
    <animate attributeName="cx" values="150;450;150" dur="3.2s" repeatCount="indefinite" begin="0.3s"/>
    <animate attributeName="r" values="25;40;25" dur="1.6s" repeatCount="indefinite"/>
  </circle>
  <circle id="c3" cx="200" cy="400" r="20" fill="#ffcc00">
    <animate attributeName="cx" values="200;400;200" dur="3.4s" repeatCount="indefinite" begin="0.6s"/>
    <animate attributeName="r" values="20;35;20" dur="1.7s" repeatCount="indefinite"/>
  </circle>
  <circle id="c4" cx="250" cy="450" r="15" fill="#ffff00">
    <animate attributeName="cx" values="250;350;250" dur="3.6s" repeatCount="indefinite" begin="0.9s"/>
    <animate attributeName="r" values="15;30;15" dur="1.8s" repeatCount="indefinite"/>
  </circle>
  
  <!-- Transform animations -->
  <g id="transformGroup">
    <animateTransform attributeName="transform" type="translate" 
      values="0,0;100,0;100,100;0,100;0,0" dur="6s" repeatCount="indefinite"/>
    <animateTransform attributeName="transform" type="rotate" 
      values="0 300 300;180 300 300;360 300 300" dur="4s" repeatCount="indefinite" additive="sum"/>
    <animateTransform attributeName="transform" type="scale" 
      values="1;1.2;0.8;1" dur="3s" repeatCount="indefinite" additive="sum"/>
    <rect x="270" y="270" width="60" height="60" fill="#0066ff"/>
  </g>
  
  <!-- Path morphing animations -->
  <path id="morphPath" fill="#00cc66" d="M 450 50 L 550 50 L 550 150 L 450 150 Z">
    <animate attributeName="d" dur="4s" repeatCount="indefinite"
      values="M 450 50 L 550 50 L 550 150 L 450 150 Z;
              M 475 25 L 575 75 L 525 175 L 425 125 Z;
              M 500 10 L 590 100 L 500 190 L 410 100 Z;
              M 475 25 L 575 75 L 525 175 L 425 125 Z;
              M 450 50 L 550 50 L 550 150 L 450 150 Z"/>
  </path>
  
  <!-- Stroke animations -->
  <path id="strokeAnim" d="M 50 550 Q 300 450 550 550" fill="none" stroke="#9900ff" stroke-width="4">
    <animate attributeName="stroke-width" values="4;12;4" dur="2s" repeatCount="indefinite"/>
    <animate attributeName="stroke-dasharray" values="0,1000;500,0;0,1000" dur="5s" repeatCount="indefinite"/>
    <animate attributeName="stroke-dashoffset" values="0;-200;0" dur="3s" repeatCount="indefinite"/>
  </path>
  
  <!-- Animated gradient reference -->
  <defs>
    <linearGradient id="animGrad" x1="0%" y1="0%" x2="100%" y2="0%">
      <stop offset="0%" style="stop-color:#ff0000">
        <animate attributeName="stop-color" values="#ff0000;#00ff00;#0000ff;#ff0000" dur="4s" repeatCount="indefinite"/>
      </stop>
      <stop offset="100%" style="stop-color:#0000ff">
        <animate attributeName="stop-color" values="#0000ff;#ff0000;#00ff00;#0000ff" dur="4s" repeatCount="indefinite"/>
      </stop>
    </linearGradient>
  </defs>
  <rect x="450" y="200" width="100" height="100" fill="url(#animGrad)"/>
</svg>
''';

  /// High animation count stress test.
  static String get manyAnimations {
    final buffer = StringBuffer();
    buffer.writeln(
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1000 1000">',
    );

    // Generate many animated elements
    for (var i = 0; i < 25; i++) {
      final x = (i % 5) * 200 + 20;
      final y = (i ~/ 5) * 200 + 20;
      final dur = 2 + (i % 5) * 0.5;
      final delay = i * 0.1;

      buffer.writeln('''
  <rect id="r$i" x="$x" y="$y" width="80" height="80" fill="#${(i * 10).toRadixString(16).padLeft(2, '0')}88ff">
    <animate attributeName="x" values="$x;${x + 50};$x" dur="${dur}s" repeatCount="indefinite" begin="${delay}s"/>
    <animate attributeName="y" values="$y;${y + 30};$y" dur="${dur * 0.8}s" repeatCount="indefinite"/>
    <animate attributeName="fill-opacity" values="1;0.3;1" dur="${dur * 1.2}s" repeatCount="indefinite"/>
    <animateTransform attributeName="transform" type="rotate" 
      values="0 ${x + 40} ${y + 40};45 ${x + 40} ${y + 40};0 ${x + 40} ${y + 40}" dur="${dur * 1.5}s" repeatCount="indefinite"/>
  </rect>''');
    }

    buffer.writeln('</svg>');
    return buffer.toString();
  }

  /// Complex timing and synchronization.
  static const String complexTiming = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 500 500">
  <rect id="trigger" x="50" y="50" width="50" height="50" fill="#ff0000">
    <animate id="anim1" attributeName="x" values="50;200;50" dur="2s" fill="freeze"/>
  </rect>
  
  <circle id="dependent1" cx="300" cy="75" r="25" fill="#00ff00">
    <animate attributeName="r" begin="anim1.end" values="25;50;25" dur="1s" fill="freeze"/>
    <animate id="anim2" attributeName="fill" begin="anim1.end" values="#00ff00;#ffff00" dur="1s" fill="freeze"/>
  </circle>
  
  <rect id="dependent2" x="50" y="150" width="50" height="50" fill="#0000ff">
    <animate attributeName="width" begin="anim2.end" values="50;150;50" dur="1.5s"/>
    <animate attributeName="height" begin="anim2.end" values="50;150;50" dur="1.5s"/>
  </rect>
  
  <g id="repeatGroup">
    <animate attributeName="opacity" begin="0s;repeatGroup.click" values="1;0.3;1" dur="0.5s"/>
    <circle cx="150" cy="300" r="40" fill="#ff00ff"/>
    <text x="150" y="305" text-anchor="middle" font-size="14">Click</text>
  </g>
  
  <!-- Keyframe splines -->
  <rect x="250" y="250" width="50" height="50" fill="#00cccc">
    <animate attributeName="x" values="250;400;250" dur="3s" 
      keyTimes="0;0.7;1" keySplines="0.5 0 0.5 1; 0.5 0 0.5 1" calcMode="spline" repeatCount="indefinite"/>
  </rect>
  
  <!-- Discrete animation -->
  <rect x="50" y="350" width="80" height="80" fill="#ff6600">
    <animate attributeName="fill" values="#ff6600;#6600ff;#00ff66;#ff0066;#ff6600" 
      dur="2s" calcMode="discrete" repeatCount="indefinite"/>
  </rect>
  
  <!-- Paced animation -->
  <circle cx="400" cy="400" r="30" fill="#cc00cc">
    <animate attributeName="cx" values="400;300;450;350;400" dur="4s" calcMode="paced" repeatCount="indefinite"/>
    <animate attributeName="cy" values="400;450;350;400;400" dur="4s" calcMode="paced" repeatCount="indefinite"/>
  </circle>
</svg>
''';
}

/// Runs animation render benchmarks.
///
/// These benchmarks focus on multiple simultaneous SMIL animations.
List<BenchmarkResult> runAnimationRenderBenchmarks() {
  final results = <BenchmarkResult>[];

  // Simultaneous animations parse benchmark
  results.add(
    runBenchmark(
      name: 'animation_render_simultaneous_parse',
      setup: () {},
      benchmark: () {
        SvgParser.parse(AnimationRenderContent.simultaneousAnimations);
      },
      teardown: () {},
    ),
  );
  print('  ${results.last}');

  // Simultaneous animations timeline benchmark
  late List<SmilAnimation> animations;
  results.add(
    runBenchmark(
      name: 'animation_render_simultaneous_timeline',
      setup: () {
        final doc = SvgParser.parse(
          AnimationRenderContent.simultaneousAnimations,
        );
        animations = SmilParser.parseAnimations(doc);
      },
      benchmark: () {
        final doc = SvgParser.parse(
          AnimationRenderContent.simultaneousAnimations,
        );
        final timeline = SvgTimeline(
          animations: animations,
          rootNode: doc.root,
        );
        // Tick through animation frames
        for (var t = 0; t < 60; t++) {
          timeline.seek(Duration(milliseconds: t * 16));
        }
      },
      teardown: () {},
    ),
  );
  print('  ${results.last}');

  // Many animations stress test
  final manyAnimSvg = AnimationRenderContent.manyAnimations;
  results.add(
    runBenchmark(
      name: 'animation_render_many_parse',
      setup: () {},
      benchmark: () {
        SvgParser.parse(manyAnimSvg);
      },
      teardown: () {},
    ),
  );
  print('  ${results.last}');

  // Complex timing benchmark
  results.add(
    runBenchmark(
      name: 'animation_render_complex_timing',
      setup: () {},
      benchmark: () {
        SvgParser.parse(AnimationRenderContent.complexTiming);
      },
      teardown: () {},
    ),
  );
  print('  ${results.last}');

  // High-frequency tick simulation
  results.add(
    runBenchmark(
      name: 'animation_render_high_freq_tick',
      setup: () {
        final doc = SvgParser.parse(
          AnimationRenderContent.simultaneousAnimations,
        );
        animations = SmilParser.parseAnimations(doc);
      },
      benchmark: () {
        final doc = SvgParser.parse(
          AnimationRenderContent.simultaneousAnimations,
        );
        final timeline = SvgTimeline(
          animations: animations,
          rootNode: doc.root,
        );
        // Simulate high frequency updates (120fps equivalent)
        for (var t = 0; t < 120; t++) {
          timeline.seek(Duration(milliseconds: t * 8));
        }
      },
      teardown: () {},
    ),
  );
  print('  ${results.last}');

  return results;
}
