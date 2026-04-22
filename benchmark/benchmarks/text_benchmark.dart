// Copyright 2024 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '../svg_render_benchmark.dart';
import '../svg_content.dart';

// ignore: implementation_imports
import 'package:full_svg_flutter/src/animation/svg_parser.dart';

/// Runs text layout benchmarks.
///
/// These benchmarks measure text element parsing.
/// Full text layout benchmarks require Flutter's text rendering engine
/// and are tested in the widget benchmark.
List<BenchmarkResult> runTextBenchmarks() {
  final results = <BenchmarkResult>[];

  // Parse text-heavy SVG
  results.add(
    runBenchmark(
      name: 'text_parse_heavy',
      setup: () {},
      benchmark: () {
        SvgParser.parse(SvgTestContent.textHeavy);
      },
      teardown: () {},
    ),
  );
  print('  ${results.last}');

  // Parse SVG with various text styles
  const styledTextSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 400">
  <text x="10" y="30" font-size="24" font-weight="100" fill="#000">Thin</text>
  <text x="10" y="60" font-size="24" font-weight="200" fill="#000">Extra Light</text>
  <text x="10" y="90" font-size="24" font-weight="300" fill="#000">Light</text>
  <text x="10" y="120" font-size="24" font-weight="400" fill="#000">Normal</text>
  <text x="10" y="150" font-size="24" font-weight="500" fill="#000">Medium</text>
  <text x="10" y="180" font-size="24" font-weight="600" fill="#000">Semi Bold</text>
  <text x="10" y="210" font-size="24" font-weight="700" fill="#000">Bold</text>
  <text x="10" y="240" font-size="24" font-weight="800" fill="#000">Extra Bold</text>
  <text x="10" y="270" font-size="24" font-weight="900" fill="#000">Black</text>
  <text x="200" y="30" font-size="20" font-style="normal" fill="#333">Normal Style</text>
  <text x="200" y="60" font-size="20" font-style="italic" fill="#333">Italic Style</text>
  <text x="200" y="90" font-size="20" font-style="oblique" fill="#333">Oblique Style</text>
  <text x="200" y="120" font-size="20" text-decoration="underline" fill="#333">Underlined</text>
  <text x="200" y="150" font-size="20" text-decoration="line-through" fill="#333">Strikethrough</text>
  <text x="200" y="180" font-size="20" text-decoration="overline" fill="#333">Overline</text>
  <text x="200" y="220" font-size="16" letter-spacing="0.5em" fill="#333">Wide Spacing</text>
  <text x="200" y="250" font-size="16" letter-spacing="-0.05em" fill="#333">Tight Spacing</text>
  <text x="200" y="280" font-size="16" word-spacing="1em" fill="#333">Word Spacing Test</text>
</svg>
''';

  results.add(
    runBenchmark(
      name: 'text_parse_styled',
      setup: () {},
      benchmark: () {
        SvgParser.parse(styledTextSvg);
      },
      teardown: () {},
    ),
  );
  print('  ${results.last}');

  // Parse SVG with tspans
  const tspanTextSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 300">
  <text x="10" y="30" font-size="16">
    <tspan fill="#ff0000">Red</tspan>
    <tspan fill="#00ff00" dx="10">Green</tspan>
    <tspan fill="#0000ff" dx="10">Blue</tspan>
  </text>
  <text x="10" y="60" font-size="16">
    <tspan x="10" dy="0">Line 1</tspan>
    <tspan x="10" dy="20">Line 2</tspan>
    <tspan x="10" dy="20">Line 3</tspan>
    <tspan x="10" dy="20">Line 4</tspan>
    <tspan x="10" dy="20">Line 5</tspan>
  </text>
  <text x="10" y="180" font-size="14">
    <tspan font-weight="bold">Bold</tspan>
    <tspan font-style="italic"> Italic</tspan>
    <tspan text-decoration="underline"> Underline</tspan>
    <tspan baseline-shift="super" font-size="10">super</tspan>
    <tspan baseline-shift="sub" font-size="10">sub</tspan>
  </text>
  <text x="10" y="220" font-size="16" fill="#000">
    <tspan>First </tspan>
    <tspan rotate="15 30 45 60">ABCD</tspan>
    <tspan> Last</tspan>
  </text>
  <text x="10" y="260" font-size="14">
    <tspan x="10 20 30 40 50 60 70 80 90">POSITIONS</tspan>
  </text>
</svg>
''';

  results.add(
    runBenchmark(
      name: 'text_parse_tspan',
      setup: () {},
      benchmark: () {
        SvgParser.parse(tspanTextSvg);
      },
      teardown: () {},
    ),
  );
  print('  ${results.last}');

  // Parse SVG with textPath
  const textPathSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 200">
  <defs>
    <path id="curve1" d="M 10 100 Q 100 20 200 100 T 390 100"/>
    <path id="curve2" d="M 10 150 C 50 50 150 150 200 100 S 350 50 390 150"/>
    <path id="arc1" d="M 200 50 A 80 80 0 1 1 200 170 A 80 80 0 1 1 200 50"/>
  </defs>
  <text font-size="14" fill="#333">
    <textPath href="#curve1">Text flowing along a quadratic curve path</textPath>
  </text>
  <text font-size="12" fill="#666">
    <textPath href="#curve2" startOffset="10%">Cubic bezier curve text path</textPath>
  </text>
  <text font-size="16" fill="#000">
    <textPath href="#arc1" startOffset="25%">Circular arc text • Circular arc text</textPath>
  </text>
</svg>
''';

  results.add(
    runBenchmark(
      name: 'text_parse_textpath',
      setup: () {},
      benchmark: () {
        SvgParser.parse(textPathSvg);
      },
      teardown: () {},
    ),
  );
  print('  ${results.last}');

  // Parse large text content
  final largeTextBuffer = StringBuffer();
  largeTextBuffer.writeln(
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 800 1200">',
  );
  for (var i = 0; i < 50; i++) {
    final y = 20 + i * 22;
    largeTextBuffer.writeln(
      '  <text x="10" y="$y" font-size="14" fill="#333">'
      'Line $i: Lorem ipsum dolor sit amet, consectetur adipiscing elit.</text>',
    );
  }
  largeTextBuffer.writeln('</svg>');
  final largeTextSvg = largeTextBuffer.toString();

  results.add(
    runBenchmark(
      name: 'text_parse_large',
      setup: () {},
      benchmark: () {
        SvgParser.parse(largeTextSvg);
      },
      teardown: () {},
    ),
  );
  print('  ${results.last}');

  return results;
}
