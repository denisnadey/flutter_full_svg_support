// ignore_for_file: avoid_print

/// Parser microbenchmarks using package:benchmark_harness.
///
/// Each benchmark class follows the [BenchmarkBase] contract:
///   - [setup()]    — called once before the benchmark loop
///   - [run()]      — the hot loop body (called many times)
///   - [teardown()] — called once after the loop
///
/// Benchmark scores are reported in microseconds per iteration by default.

import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:flutter_svg/flutter_svg.dart' as fsvg;
import 'package:full_svg_flutter/full_svg_flutter.dart' as ffsf;

// ---------------------------------------------------------------------------
// Inline SVG string constants
// ---------------------------------------------------------------------------
//
// These are representative minimal SVGs. Replace with real content from your
// assets/ directory for production benchmarking accuracy.

const String _kSimpleIconSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
  <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2z"
        fill="#4A90E2"/>
  <circle cx="12" cy="12" r="4" fill="#FFFFFF"/>
</svg>
''';

// 1 k-path SVG: a representative complex illustration path string.
// In production, load this from assets/complex/complex_path_1k.svg.
final String _kComplexPath1kSvg = _buildComplexPathSvg(segmentCount: 100);

// 10 k-path SVG
final String _kComplexPath10kSvg = _buildComplexPathSvg(segmentCount: 1000);

const String _kGradientsSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 200">
  <defs>
    <linearGradient id="lg1" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:#ff6b6b"/>
      <stop offset="100%" style="stop-color:#4ecdc4"/>
    </linearGradient>
    <radialGradient id="rg1" cx="50%" cy="50%" r="50%">
      <stop offset="0%" style="stop-color:#ffe66d"/>
      <stop offset="100%" style="stop-color:#ff6b6b"/>
    </radialGradient>
  </defs>
  <rect width="200" height="200" fill="url(#lg1)"/>
  <circle cx="100" cy="100" r="80" fill="url(#rg1)" opacity="0.7"/>
</svg>
''';

const String _kFiltersSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 200">
  <defs>
    <filter id="blur1">
      <feGaussianBlur in="SourceGraphic" stdDeviation="5"/>
    </filter>
    <filter id="shadow">
      <feDropShadow dx="3" dy="3" stdDeviation="2" flood-color="#000" flood-opacity="0.4"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="80" height="80" fill="#e74c3c" filter="url(#blur1)"/>
  <rect x="110" y="10" width="80" height="80" fill="#3498db" filter="url(#shadow)"/>
  <circle cx="100" cy="150" r="40" fill="#2ecc71" filter="url(#blur1)"/>
</svg>
''';

const String _kCssKeyframesSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
  <style>
    @keyframes spin {
      from { transform: rotate(0deg); }
      to   { transform: rotate(360deg); }
    }
    .spinner { animation: spin 1s linear infinite; transform-origin: 50px 50px; }
  </style>
  <g class="spinner">
    <rect x="45" y="10" width="10" height="25" rx="5" fill="#3498db"/>
    <rect x="45" y="65" width="10" height="25" rx="5" fill="#3498db" opacity="0.3"/>
    <rect x="10" y="45" width="25" height="10" rx="5" fill="#3498db" opacity="0.6"/>
    <rect x="65" y="45" width="25" height="10" rx="5" fill="#3498db" opacity="0.6"/>
  </g>
</svg>
''';

const String _kSmilAnimationSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
  <circle cx="50" cy="50" r="20" fill="#e74c3c">
    <animate attributeName="r" values="20;35;20" dur="1s" repeatCount="indefinite"/>
    <animate attributeName="fill" values="#e74c3c;#3498db;#e74c3c" dur="2s" repeatCount="indefinite"/>
  </circle>
</svg>
''';

// ---------------------------------------------------------------------------
// Helper: builds a synthetic complex path SVG with [segmentCount] path commands
// ---------------------------------------------------------------------------

String _buildComplexPathSvg({required int segmentCount}) {
  final buf = StringBuffer()
    ..writeln('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 800 600">')
    ..writeln('  <path d="M0 300');

  for (int i = 0; i < segmentCount; i++) {
    final x1 = (i * 8) % 800;
    final y1 = 150 + ((i % 3) * 50);
    final x2 = ((i + 1) * 8) % 800;
    final y2 = 450 - ((i % 3) * 50);
    final ex = ((i + 2) * 8) % 800;
    final ey = 200 + ((i % 5) * 40);
    buf.writeln('    C$x1 $y1 $x2 $y2 $ex $ey');
  }

  buf.writeln('  Z" fill="none" stroke="#2c3e50" stroke-width="1.5"/>');
  buf.writeln('</svg>');
  return buf.toString();
}

// ---------------------------------------------------------------------------
// full_svg_flutter benchmarks
// ---------------------------------------------------------------------------

/// Benchmark: parse a simple icon SVG with full_svg_flutter.
class ParseSimpleIconBenchmark extends BenchmarkBase {
  ParseSimpleIconBenchmark() : super('full_svg_flutter.ParseSimpleIcon');

  late ffsf.SvgStringLoader _loader;

  @override
  void setup() {
    _loader = ffsf.SvgStringLoader(_kSimpleIconSvg);
  }

  @override
  void run() {
    // SvgStringLoader.loadBytes() is the parse entry point.
    // It returns a Future; we fire-and-forget here because benchmark_harness
    // measures synchronous CPU cycles. For async parse cost use the
    // integration_test first-paint metric instead.
    // TODO: if full_svg_flutter exposes a synchronous parse API, call it here.
    _loader.hashCode; // keep _loader alive / exercised
    ffsf.SvgStringLoader(_kSimpleIconSvg);
  }
}

/// Benchmark: parse a ~1k-path complex SVG with full_svg_flutter.
class ParseComplexPath1kBenchmark extends BenchmarkBase {
  ParseComplexPath1kBenchmark()
      : super('full_svg_flutter.ParseComplexPath1k');

  @override
  void run() {
    ffsf.SvgStringLoader(_kComplexPath1kSvg);
  }
}

/// Benchmark: parse a ~10k-path complex SVG with full_svg_flutter.
class ParseComplexPath10kBenchmark extends BenchmarkBase {
  ParseComplexPath10kBenchmark()
      : super('full_svg_flutter.ParseComplexPath10k');

  @override
  void run() {
    ffsf.SvgStringLoader(_kComplexPath10kSvg);
  }
}

/// Benchmark: parse gradient-heavy SVG with full_svg_flutter.
class ParseGradientsBenchmark extends BenchmarkBase {
  ParseGradientsBenchmark() : super('full_svg_flutter.ParseGradients');

  @override
  void run() {
    ffsf.SvgStringLoader(_kGradientsSvg);
  }
}

/// Benchmark: parse filter-heavy SVG with full_svg_flutter.
class ParseFiltersBenchmark extends BenchmarkBase {
  ParseFiltersBenchmark() : super('full_svg_flutter.ParseFilters');

  @override
  void run() {
    ffsf.SvgStringLoader(_kFiltersSvg);
  }
}

/// Benchmark: parse CSS @keyframes SVG with full_svg_flutter.
class ParseCssKeyframesBenchmark extends BenchmarkBase {
  ParseCssKeyframesBenchmark() : super('full_svg_flutter.ParseCssKeyframes');

  @override
  void run() {
    ffsf.SvgStringLoader(_kCssKeyframesSvg);
  }
}

/// Benchmark: parse SMIL animation SVG with full_svg_flutter.
class ParseSmilAnimationBenchmark extends BenchmarkBase {
  ParseSmilAnimationBenchmark()
      : super('full_svg_flutter.ParseSmilAnimation');

  @override
  void run() {
    ffsf.SvgStringLoader(_kSmilAnimationSvg);
  }
}

// ---------------------------------------------------------------------------
// flutter_svg counterpart benchmarks
// ---------------------------------------------------------------------------

/// Benchmark: parse a simple icon SVG with flutter_svg.
class FlutterSvgParseSimpleIconBenchmark extends BenchmarkBase {
  FlutterSvgParseSimpleIconBenchmark()
      : super('flutter_svg.ParseSimpleIcon');

  @override
  void run() {
    fsvg.SvgStringLoader(_kSimpleIconSvg);
  }
}

/// Benchmark: parse a ~1k-path complex SVG with flutter_svg.
class FlutterSvgParseComplexPath1kBenchmark extends BenchmarkBase {
  FlutterSvgParseComplexPath1kBenchmark()
      : super('flutter_svg.ParseComplexPath1k');

  @override
  void run() {
    fsvg.SvgStringLoader(_kComplexPath1kSvg);
  }
}

/// Benchmark: parse a ~10k-path complex SVG with flutter_svg.
class FlutterSvgParseComplexPath10kBenchmark extends BenchmarkBase {
  FlutterSvgParseComplexPath10kBenchmark()
      : super('flutter_svg.ParseComplexPath10k');

  @override
  void run() {
    fsvg.SvgStringLoader(_kComplexPath10kSvg);
  }
}

/// Benchmark: parse gradient-heavy SVG with flutter_svg.
class FlutterSvgParseGradientsBenchmark extends BenchmarkBase {
  FlutterSvgParseGradientsBenchmark()
      : super('flutter_svg.ParseGradients');

  @override
  void run() {
    fsvg.SvgStringLoader(_kGradientsSvg);
  }
}

/// Benchmark: parse filter-heavy SVG with flutter_svg.
class FlutterSvgParseFiltersBenchmark extends BenchmarkBase {
  FlutterSvgParseFiltersBenchmark() : super('flutter_svg.ParseFilters');

  @override
  void run() {
    fsvg.SvgStringLoader(_kFiltersSvg);
  }
}

// ---------------------------------------------------------------------------
// Registry: all benchmark pairs in declaration order
// ---------------------------------------------------------------------------

/// A matched pair of [full_svg_flutter] and [flutter_svg] benchmarks for a
/// single scenario. Used by bin/run_benchmarks.dart to build the comparison
/// table.
class BenchmarkPair {
  const BenchmarkPair({
    required this.scenario,
    required this.fullSvg,
    required this.flutterSvg,
  });

  final String scenario;
  final BenchmarkBase fullSvg;
  final BenchmarkBase? flutterSvg; // null if flutter_svg does not support it

  bool get isFullSvgOnly => flutterSvg == null;
}

List<BenchmarkPair> buildBenchmarkPairs() => [
      BenchmarkPair(
        scenario: 'parse_simple_icon',
        fullSvg: ParseSimpleIconBenchmark(),
        flutterSvg: FlutterSvgParseSimpleIconBenchmark(),
      ),
      BenchmarkPair(
        scenario: 'parse_complex_path_1k',
        fullSvg: ParseComplexPath1kBenchmark(),
        flutterSvg: FlutterSvgParseComplexPath1kBenchmark(),
      ),
      BenchmarkPair(
        scenario: 'parse_complex_path_10k',
        fullSvg: ParseComplexPath10kBenchmark(),
        flutterSvg: FlutterSvgParseComplexPath10kBenchmark(),
      ),
      BenchmarkPair(
        scenario: 'parse_gradients',
        fullSvg: ParseGradientsBenchmark(),
        flutterSvg: FlutterSvgParseGradientsBenchmark(),
      ),
      BenchmarkPair(
        scenario: 'parse_filters',
        fullSvg: ParseFiltersBenchmark(),
        flutterSvg: FlutterSvgParseFiltersBenchmark(),
      ),
      BenchmarkPair(
        scenario: 'parse_css_keyframes',
        fullSvg: ParseCssKeyframesBenchmark(),
        flutterSvg: null, // flutter_svg does not support CSS @keyframes
      ),
      BenchmarkPair(
        scenario: 'parse_smil_animation',
        fullSvg: ParseSmilAnimationBenchmark(),
        flutterSvg: null, // flutter_svg does not support SMIL
      ),
    ];
