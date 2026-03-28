// Copyright 2024 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '../svg_render_benchmark.dart';

// ignore: implementation_imports
import 'package:flutter_svg/src/animation/svg_parser.dart';

/// Complex text layout SVG content for benchmarks.
class TextRenderContent {
  TextRenderContent._();

  /// Complex text with nested tspan elements.
  static const String nestedTspan = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 600 400">
  <text x="10" y="30" font-size="18">
    <tspan fill="#ff0000" font-weight="bold">Bold Red </tspan>
    <tspan fill="#00ff00" font-style="italic">Italic Green </tspan>
    <tspan fill="#0000ff" text-decoration="underline">Underlined Blue</tspan>
  </text>
  
  <text x="10" y="70" font-size="16">
    <tspan x="10" dy="0">First Line - Normal</tspan>
    <tspan x="10" dy="25">Second Line - <tspan font-weight="bold">with bold</tspan></tspan>
    <tspan x="10" dy="25">Third Line - <tspan fill="#ff6600">with <tspan font-size="20">nested</tspan> colors</tspan></tspan>
    <tspan x="10" dy="25">Fourth Line - <tspan baseline-shift="super" font-size="12">super</tspan> and <tspan baseline-shift="sub" font-size="12">sub</tspan></tspan>
    <tspan x="10" dy="25">Fifth Line - <tspan letter-spacing="0.5em">W I D E</tspan></tspan>
  </text>
  
  <text x="10" y="220" font-size="14">
    <tspan>Mixed </tspan>
    <tspan font-family="Georgia" font-size="18" fill="#333">fonts </tspan>
    <tspan font-family="Courier" font-size="12" fill="#666">and </tspan>
    <tspan font-family="Arial" font-size="16" font-weight="900" fill="#000">weights</tspan>
  </text>
  
  <text x="10" y="260" font-size="16">
    <tspan rotate="0 5 10 15 20 25 30">ROTATED</tspan>
    <tspan dx="20">Normal</tspan>
    <tspan rotate="30 30 30 30 30 30 30 30 30 30">CONSISTENT</tspan>
  </text>
  
  <text x="10" y="300" font-size="14">
    <tspan x="10 25 40 55 70 85 100 115 130 145">POSITIONED</tspan>
  </text>
  
  <text x="10" y="340" font-size="16">
    <tspan>Deep: </tspan>
    <tspan fill="#f00">Level 1 <tspan fill="#0f0">Level 2 <tspan fill="#00f">Level 3 <tspan fill="#f0f">Level 4</tspan></tspan></tspan></tspan>
  </text>
  
  <text x="10" y="380" font-size="12">
    <tspan dx="0" dy="0">A</tspan>
    <tspan dx="5" dy="5">B</tspan>
    <tspan dx="5" dy="-5">C</tspan>
    <tspan dx="5" dy="5">D</tspan>
    <tspan dx="5" dy="-5">E</tspan>
    <tspan dx="5" dy="5">F</tspan>
    <tspan dx="5" dy="-5">G</tspan>
    <tspan dx="5" dy="5">H</tspan>
  </text>
</svg>
''';

  /// Text on path (textPath) benchmark content.
  static const String textPath = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 600 500">
  <defs>
    <path id="wavePath" d="M 10 100 Q 75 50 150 100 T 300 100 T 450 100 T 590 100"/>
    <path id="circlePath" d="M 150 250 A 100 100 0 1 1 150 251 Z"/>
    <path id="spiralPath" d="M 450 250 Q 480 220 500 250 Q 520 280 490 300 Q 460 320 440 290 Q 420 260 450 240 Q 480 220 510 250"/>
    <path id="bezierPath" d="M 10 400 C 100 300 200 500 300 400 S 500 300 590 400"/>
    <path id="zigzagPath" d="M 10 450 L 60 420 L 110 480 L 160 420 L 210 480 L 260 420 L 310 480 L 360 420 L 410 480 L 460 420 L 510 480 L 560 420 L 590 450"/>
  </defs>
  
  <text font-size="14" fill="#333">
    <textPath href="#wavePath">
      This text flows along a wavy quadratic bezier path with T commands
    </textPath>
  </text>
  
  <text font-size="12" fill="#0066cc">
    <textPath href="#circlePath" startOffset="0%">
      Circular text that wraps around • Circular text that wraps around • Circular text
    </textPath>
  </text>
  
  <text font-size="10" fill="#cc6600">
    <textPath href="#spiralPath">
      Spiral Path Text
    </textPath>
  </text>
  
  <text font-size="16" fill="#006633">
    <textPath href="#bezierPath" startOffset="10%">
      Smooth cubic bezier curve with S commands
    </textPath>
  </text>
  
  <text font-size="11" fill="#660066">
    <textPath href="#zigzagPath">
      Zigzag polyline path with alternating up and down movements
    </textPath>
  </text>
  
  <text font-size="14" fill="#333">
    <textPath href="#wavePath" startOffset="50%">
      <tspan fill="#ff0000">Red </tspan>
      <tspan fill="#00ff00">Green </tspan>
      <tspan fill="#0000ff">Blue</tspan>
    </textPath>
  </text>
</svg>
''';

  /// Per-character positioning benchmark.
  static const String perCharacter = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 800 600">
  <!-- Per-character x positioning -->
  <text y="30" font-size="20" fill="#000">
    <tspan x="10 35 60 85 110 135 160 185 210 235 260 285 310 335 360 385 410 435 460">INDIVIDUAL-POSITIONS</tspan>
  </text>
  
  <!-- Per-character y positioning -->
  <text x="10" font-size="18" fill="#333">
    <tspan y="60 65 70 75 80 75 70 65 60 65 70 75 80">WAVE-VERTICAL</tspan>
  </text>
  
  <!-- Per-character rotation -->
  <text x="10" y="120" font-size="24" fill="#666">
    <tspan rotate="0 10 20 30 40 50 60 70 80 90 100 110 120">ROTATING-CHARS</tspan>
  </text>
  
  <!-- Combined positioning and rotation -->
  <text font-size="20" fill="#000">
    <tspan x="10 40 70 100 130 160 190 220 250 280" 
           y="170 175 180 175 170 175 180 175 170 175"
           rotate="0 5 10 15 20 15 10 5 0 -5">COMBINED!!</tspan>
  </text>
  
  <!-- Many individual positioned characters -->
  <text y="230" font-size="14" fill="#444">
    <tspan x="10 18 26 34 42 50 58 66 74 82 90 98 106 114 122 130 138 146 154 162 170 178 186 194 202 210 218 226 234 242 250 258 266 274 282 290 298 306 314 322 330 338 346 354 362 370 378 386 394 402">ABCDEFGHIJKLMNOPQRSTUVWXYZABCDEFGHIJKLMNOPQRSTUVWX</tspan>
  </text>
  
  <!-- dx/dy offsets -->
  <text x="10" y="280" font-size="16" fill="#000">
    <tspan>Start</tspan>
    <tspan dx="5 10 15 10 5">→→→→→</tspan>
    <tspan dy="-5 -10 -15 -10 -5">↑↑↑↑↑</tspan>
    <tspan dx="5 10 15 10 5" dy="5 10 15 10 5">↘↘↘↘↘</tspan>
  </text>
  
  <!-- Scattered characters -->
  <text font-size="24" fill="#cc0000">
    <tspan x="50 150 250 350 450 550 650 750"
           y="350 380 330 400 340 390 360 370">SCATTERED</tspan>
  </text>
  
  <!-- Dense character cloud -->
  <text font-size="10" fill="#0066cc">
    <tspan x="10 12 14 16 18 20 22 24 26 28 30 32 34 36 38 40 42 44 46 48 50 52 54 56 58 60 62 64 66 68 70 72 74 76 78 80"
           y="420 425 422 428 420 426 423 427 421 425 422 428 420 426 423 427 421 425 422 428 420 426 423 427 421 425 422 428 420 426 423 427 421 425 422 428">AAAABBBBCCCCDDDDEEEEFFFFGGGGHHHHIIII</tspan>
  </text>
  
  <!-- Overlapping characters -->
  <text font-size="48" fill="#ff6600" opacity="0.3">
    <tspan x="200 210 220 230 240">OOOOO</tspan>
  </text>
  
  <text y="550" font-size="12" fill="#333">
    <tspan x="10 22 34 46 58 70 82 94 106 118 130 142 154 166 178 190 202 214 226 238 250 262 274 286 298 310 322 334 346 358 370 382 394 406 418 430 442 454 466 478 490 502 514 526 538 550 562 574 586 598 610 622 634 646 658 670 682 694 706 718 730 742 754 766 778">THEQUICKBROWNFOXJUMPSOVERTHELAZYDOG0123456789THEQUICKBROWNFOXJUMPS</tspan>
  </text>
</svg>
''';

  /// Large text document simulation.
  static String get largeDocument {
    final buffer = StringBuffer();
    buffer.writeln(
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 800 2000">',
    );

    var y = 30;
    for (var paragraph = 0; paragraph < 20; paragraph++) {
      buffer.writeln('  <text x="20" y="$y" font-size="14" fill="#333">');
      for (var line = 0; line < 5; line++) {
        final lineY = y + line * 18;
        buffer.writeln(
          '    <tspan x="20" y="$lineY">Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor.</tspan>',
        );
      }
      buffer.writeln('  </text>');
      y += 100;
    }

    buffer.writeln('</svg>');
    return buffer.toString();
  }
}

/// Runs text rendering benchmarks.
///
/// These benchmarks focus on complex text layout parsing.
List<BenchmarkResult> runTextRenderBenchmarks() {
  final results = <BenchmarkResult>[];

  // Nested tspan benchmark
  results.add(
    runBenchmark(
      name: 'text_render_nested_tspan',
      setup: () {},
      benchmark: () {
        SvgParser.parse(TextRenderContent.nestedTspan);
      },
      teardown: () {},
    ),
  );
  print('  ${results.last}');

  // TextPath benchmark
  results.add(
    runBenchmark(
      name: 'text_render_textpath',
      setup: () {},
      benchmark: () {
        SvgParser.parse(TextRenderContent.textPath);
      },
      teardown: () {},
    ),
  );
  print('  ${results.last}');

  // Per-character positioning benchmark
  results.add(
    runBenchmark(
      name: 'text_render_per_character',
      setup: () {},
      benchmark: () {
        SvgParser.parse(TextRenderContent.perCharacter);
      },
      teardown: () {},
    ),
  );
  print('  ${results.last}');

  // Large document benchmark
  final largeDoc = TextRenderContent.largeDocument;
  results.add(
    runBenchmark(
      name: 'text_render_large_document',
      setup: () {},
      benchmark: () {
        SvgParser.parse(largeDoc);
      },
      teardown: () {},
    ),
  );
  print('  ${results.last}');

  return results;
}
