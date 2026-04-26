// ignore_for_file: avoid_print
// Copyright 2024 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '../svg_render_benchmark.dart';

// ignore: implementation_imports
import 'package:full_svg_flutter/src/animation/svg_parser.dart';
// ignore: implementation_imports
import 'package:full_svg_flutter/src/animation/smil/smil_parser.dart';
// ignore: implementation_imports
import 'package:full_svg_flutter/src/animation/smil/smil_timeline.dart';

/// Combined worst-case SVG content combining all complex features.
class CombinedWorstCaseContent {
  CombinedWorstCaseContent._();

  /// Combined SVG with filters, text, gradients, masks, and animations.
  static const String fullCombined = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 800 800">
  <defs>
    <!-- Complex filters -->
    <filter id="megaFilter" x="-50%" y="-50%" width="200%" height="200%">
      <feGaussianBlur in="SourceGraphic" stdDeviation="3" result="blur"/>
      <feColorMatrix in="blur" type="matrix" result="colorMatrix"
        values="1.2 0 0 0 0
                0 1.0 0.2 0 0
                0 0 0.8 0 0.1
                0 0 0 1 0"/>
      <feOffset in="SourceAlpha" dx="4" dy="4" result="shadow"/>
      <feGaussianBlur in="shadow" stdDeviation="4" result="shadowBlur"/>
      <feFlood flood-color="#000" flood-opacity="0.4" result="shadowColor"/>
      <feComposite in="shadowColor" in2="shadowBlur" operator="in" result="shadowFinal"/>
      <feMerge>
        <feMergeNode in="shadowFinal"/>
        <feMergeNode in="colorMatrix"/>
      </feMerge>
    </filter>
    
    <filter id="glowFilter">
      <feGaussianBlur in="SourceAlpha" stdDeviation="8" result="glow"/>
      <feColorMatrix in="glow" type="matrix" result="colorGlow"
        values="0 0 0 0 1
                0 0 0 0 0.5
                0 0 0 0 0
                0 0 0 0.8 0"/>
      <feMerge>
        <feMergeNode in="colorGlow"/>
        <feMergeNode in="SourceGraphic"/>
      </feMerge>
    </filter>
    
    <!-- Complex gradients -->
    <linearGradient id="complexLinear" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:#ff0000">
        <animate attributeName="stop-color" values="#ff0000;#00ff00;#0000ff;#ff0000" dur="6s" repeatCount="indefinite"/>
      </stop>
      <stop offset="25%" style="stop-color:#ff8800"/>
      <stop offset="50%" style="stop-color:#ffff00"/>
      <stop offset="75%" style="stop-color:#88ff00"/>
      <stop offset="100%" style="stop-color:#00ff00">
        <animate attributeName="stop-color" values="#00ff00;#0000ff;#ff0000;#00ff00" dur="6s" repeatCount="indefinite"/>
      </stop>
    </linearGradient>
    
    <radialGradient id="complexRadial" cx="50%" cy="50%" r="50%" fx="25%" fy="25%">
      <stop offset="0%" style="stop-color:#ffffff"/>
      <stop offset="30%" style="stop-color:#ffcccc"/>
      <stop offset="60%" style="stop-color:#ff6666"/>
      <stop offset="100%" style="stop-color:#cc0000"/>
    </radialGradient>
    
    <!-- Complex masks and clip paths -->
    <mask id="complexMask">
      <linearGradient id="maskGrad" x1="0%" y1="0%" x2="100%" y2="0%">
        <stop offset="0%" style="stop-color:white"/>
        <stop offset="50%" style="stop-color:gray"/>
        <stop offset="100%" style="stop-color:black"/>
      </linearGradient>
      <rect x="0" y="0" width="800" height="800" fill="url(#maskGrad)"/>
      <circle cx="400" cy="400" r="200" fill="white"/>
    </mask>
    
    <clipPath id="complexClip">
      <polygon points="400,50 750,400 400,750 50,400"/>
    </clipPath>
    
    <!-- Text path definitions -->
    <path id="textCurve1" d="M 100 150 Q 400 50 700 150"/>
    <path id="textCurve2" d="M 100 700 Q 400 800 700 700"/>
    <path id="circleText" d="M 400 200 A 200 200 0 1 1 400 201 Z"/>
  </defs>
  
  <!-- Filtered and animated shapes -->
  <g filter="url(#megaFilter)">
    <rect id="animRect1" x="50" y="200" width="120" height="120" fill="url(#complexLinear)">
      <animate attributeName="x" values="50;200;50" dur="4s" repeatCount="indefinite"/>
      <animate attributeName="y" values="200;300;200" dur="3s" repeatCount="indefinite"/>
      <animateTransform attributeName="transform" type="rotate" 
        values="0 110 260;180 110 260;360 110 260" dur="6s" repeatCount="indefinite"/>
    </rect>
  </g>
  
  <g filter="url(#glowFilter)">
    <circle id="animCircle1" cx="600" cy="250" r="60" fill="url(#complexRadial)">
      <animate attributeName="r" values="60;90;60" dur="2.5s" repeatCount="indefinite"/>
      <animate attributeName="cx" values="600;650;600" dur="3s" repeatCount="indefinite"/>
    </circle>
  </g>
  
  <!-- Masked content -->
  <g mask="url(#complexMask)">
    <rect x="150" y="350" width="500" height="200" fill="#0066ff"/>
    <circle cx="400" cy="450" r="80" fill="#ff6600"/>
    <text x="400" y="460" text-anchor="middle" font-size="24" fill="#fff">Masked Text</text>
  </g>
  
  <!-- Clipped content with animations -->
  <g clip-path="url(#complexClip)">
    <rect x="0" y="0" width="800" height="800" fill="#eeeeee"/>
    <g id="spinGroup">
      <animateTransform attributeName="transform" type="rotate" 
        values="0 400 400;360 400 400" dur="10s" repeatCount="indefinite"/>
      <line x1="400" y1="100" x2="400" y2="700" stroke="#cc0000" stroke-width="3"/>
      <line x1="100" y1="400" x2="700" y2="400" stroke="#00cc00" stroke-width="3"/>
      <line x1="150" y1="150" x2="650" y2="650" stroke="#0000cc" stroke-width="3"/>
      <line x1="650" y1="150" x2="150" y2="650" stroke="#cc00cc" stroke-width="3"/>
    </g>
  </g>
  
  <!-- Complex text with textPath -->
  <text font-size="18" fill="#333">
    <textPath href="#textCurve1">
      <tspan fill="#ff0000" font-weight="bold">Complex </tspan>
      <tspan fill="#00ff00" font-style="italic">Text Path </tspan>
      <tspan fill="#0000ff" text-decoration="underline">With Styling</tspan>
    </textPath>
  </text>
  
  <text font-size="14" fill="#666">
    <textPath href="#circleText" startOffset="25%">
      Circular text animation test • Circular text animation test • Circular
    </textPath>
  </text>
  
  <!-- Nested tspan with animations -->
  <text x="50" y="620" font-size="16">
    <tspan fill="#ff0000">Nested </tspan>
    <tspan fill="#00ff00">
      <tspan font-weight="bold">Bold </tspan>
      <tspan font-style="italic">Italic </tspan>
    </tspan>
    <tspan fill="#0000ff" baseline-shift="super" font-size="12">Super</tspan>
    <tspan fill="#ff00ff" baseline-shift="sub" font-size="12">Sub</tspan>
    <animate attributeName="opacity" values="1;0.5;1" dur="3s" repeatCount="indefinite"/>
  </text>
  
  <!-- Per-character positioning -->
  <text y="680" font-size="20" fill="#333">
    <tspan x="50 75 100 125 150 175 200 225 250 275 300 325 350 375 400"
           rotate="0 5 10 15 20 15 10 5 0 -5 -10 -15 -10 -5 0">POSITIONED-TEXT</tspan>
  </text>
  
  <!-- Bottom text path -->
  <text font-size="16" fill="#996633">
    <textPath href="#textCurve2" startOffset="10%">
      Bottom curve text with gradient overlay and shadow effects
    </textPath>
  </text>
  
  <!-- Dashed animated paths -->
  <path d="M 50 750 Q 200 700 400 750 T 750 750" 
    fill="none" stroke="#9900ff" stroke-width="4" stroke-dasharray="15,10,5,10">
    <animate attributeName="stroke-dashoffset" values="0;-40;0" dur="2s" repeatCount="indefinite"/>
  </path>
  
  <!-- Additional animated elements -->
  <ellipse cx="650" cy="620" rx="80" ry="40" fill="#00cccc" filter="url(#megaFilter)">
    <animate attributeName="rx" values="80;100;80" dur="2s" repeatCount="indefinite"/>
    <animate attributeName="ry" values="40;60;40" dur="2.5s" repeatCount="indefinite"/>
    <animateTransform attributeName="transform" type="rotate" 
      values="0 650 620;15 650 620;0 650 620;-15 650 620;0 650 620" dur="3s" repeatCount="indefinite"/>
  </ellipse>
</svg>
''';

  /// Generate a scaled version of worst-case SVG.
  static String generateScaled(int elementCount) {
    final buffer = StringBuffer();
    buffer.writeln(
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 2000 2000">',
    );

    // Defs
    buffer.writeln('  <defs>');
    for (var i = 0; i < 5; i++) {
      buffer.writeln('''
    <filter id="filter$i">
      <feGaussianBlur stdDeviation="${i + 1}" result="blur"/>
      <feColorMatrix in="blur" type="hueRotate" values="${i * 30}"/>
    </filter>
    <linearGradient id="grad$i" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:#${(i * 50).toRadixString(16).padLeft(2, '0')}${((5 - i) * 50).toRadixString(16).padLeft(2, '0')}ff"/>
      <stop offset="100%" style="stop-color:#ff${(i * 50).toRadixString(16).padLeft(2, '0')}${((5 - i) * 50).toRadixString(16).padLeft(2, '0')}"/>
    </linearGradient>''');
    }
    buffer.writeln('  </defs>');

    // Elements
    for (var i = 0; i < elementCount; i++) {
      final x = (i % 20) * 100 + 10;
      final y = (i ~/ 20) * 100 + 10;
      final filterIdx = i % 5;
      final gradIdx = i % 5;

      if (i % 3 == 0) {
        buffer.writeln('''
  <rect x="$x" y="$y" width="80" height="80" fill="url(#grad$gradIdx)" filter="url(#filter$filterIdx)">
    <animate attributeName="opacity" values="1;0.5;1" dur="${2 + i % 3}s" repeatCount="indefinite"/>
  </rect>''');
      } else if (i % 3 == 1) {
        buffer.writeln('''
  <circle cx="${x + 40}" cy="${y + 40}" r="35" fill="url(#grad$gradIdx)" filter="url(#filter$filterIdx)">
    <animate attributeName="r" values="35;45;35" dur="${2 + i % 3}s" repeatCount="indefinite"/>
  </circle>''');
      } else {
        buffer.writeln('''
  <text x="$x" y="${y + 50}" font-size="14" fill="#333" filter="url(#filter$filterIdx)">
    <tspan>Text$i</tspan>
    <animate attributeName="opacity" values="1;0.3;1" dur="${2 + i % 3}s" repeatCount="indefinite"/>
  </text>''');
      }
    }

    buffer.writeln('</svg>');
    return buffer.toString();
  }
}

/// Runs combined worst-case benchmarks.
///
/// These benchmarks combine all complex features together.
List<BenchmarkResult> runCombinedWorstCaseBenchmarks() {
  final results = <BenchmarkResult>[];

  // Full combined parse benchmark
  results.add(
    runBenchmark(
      name: 'combined_worst_case_parse',
      setup: () {},
      benchmark: () {
        SvgParser.parse(CombinedWorstCaseContent.fullCombined);
      },
      teardown: () {},
    ),
  );
  print('  ${results.last}');

  // Full combined with timeline
  results.add(
    runBenchmark(
      name: 'combined_worst_case_timeline',
      setup: () {},
      benchmark: () {
        final doc = SvgParser.parse(CombinedWorstCaseContent.fullCombined);
        final animations = SmilParser.parseAnimations(doc);
        final timeline = SvgTimeline(
          animations: animations,
          rootNode: doc.root,
        );
        for (var t = 0; t < 30; t++) {
          timeline.seek(Duration(milliseconds: t * 16));
        }
      },
      teardown: () {},
    ),
  );
  print('  ${results.last}');

  // Scaled medium (50 elements)
  final scaledMedium = CombinedWorstCaseContent.generateScaled(50);
  results.add(
    runBenchmark(
      name: 'combined_scaled_medium_50',
      setup: () {},
      benchmark: () {
        SvgParser.parse(scaledMedium);
      },
      teardown: () {},
    ),
  );
  print('  ${results.last}');

  // Scaled large (100 elements)
  final scaledLarge = CombinedWorstCaseContent.generateScaled(100);
  results.add(
    runBenchmark(
      name: 'combined_scaled_large_100',
      setup: () {},
      benchmark: () {
        SvgParser.parse(scaledLarge);
      },
      teardown: () {},
    ),
  );
  print('  ${results.last}');

  // Scaled stress (200 elements)
  final scaledStress = CombinedWorstCaseContent.generateScaled(200);
  results.add(
    runBenchmark(
      name: 'combined_scaled_stress_200',
      setup: () {},
      benchmark: () {
        SvgParser.parse(scaledStress);
      },
      teardown: () {},
      iterations: 20, // Fewer iterations for heavy benchmark
    ),
  );
  print('  ${results.last}');

  return results;
}
