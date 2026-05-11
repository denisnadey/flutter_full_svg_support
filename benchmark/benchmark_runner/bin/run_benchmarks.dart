// ignore_for_file: avoid_print

/// Entry point for the pure-Dart parser microbenchmark suite.
///
/// Run with:
///   dart run bin/run_benchmarks.dart
///
/// Output:
///   - A comparison table printed to stdout
///   - A timestamped JSON result file at `../results/parser/<timestamp>.json`
library;

import 'dart:convert';
import 'dart:io';

import 'package:full_svg_flutter_benchmark_runner/benchmarks/parse_benchmarks.dart';

void main() async {
  print('');
  print('═' * 80);
  print(' full_svg_flutter vs flutter_svg — Parser Microbenchmarks');
  print(' ${DateTime.now().toUtc().toIso8601String()}');
  print('═' * 80);
  print('');

  // ---------------------------------------------------------------------------
  // Run all benchmarks and collect scores
  // ---------------------------------------------------------------------------

  final pairs = buildBenchmarkPairs();
  final rows = <_ResultRow>[];

  for (final pair in pairs) {
    stdout.write('  Running ${pair.scenario} [full_svg_flutter] ... ');
    stdout.flush();
    // BenchmarkBase.measure() returns score in microseconds/iteration.
    final fullScore = pair.fullSvg.measure();
    stdout.writeln('${fullScore.toStringAsFixed(2)} µs');

    double? flutterScore;
    if (pair.flutterSvg != null) {
      stdout.write('  Running ${pair.scenario} [flutter_svg]      ... ');
      stdout.flush();
      flutterScore = pair.flutterSvg!.measure();
      stdout.writeln('${flutterScore.toStringAsFixed(2)} µs');
    } else {
      stdout.writeln('  Running ${pair.scenario} [flutter_svg]      ... N/A (not supported)');
    }

    rows.add(_ResultRow(
      scenario: pair.scenario,
      fullSvgUs: fullScore,
      flutterSvgUs: flutterScore,
    ));
  }

  // ---------------------------------------------------------------------------
  // Print comparison table
  // ---------------------------------------------------------------------------

  print('');
  print(_tableHeader());
  print(_tableDivider());

  for (final row in rows) {
    print(row.tableRow());
  }

  print(_tableDivider());
  print('');
  print('Scores: µs/iteration. Lower is faster.');
  print('Ratio: flutter_svg / full_svg_flutter. >1.0 means full_svg_flutter is faster.');
  print('N/A: feature not supported by that package.');
  print('');

  // ---------------------------------------------------------------------------
  // Write JSON results
  // ---------------------------------------------------------------------------

  // TODO: CPU usage sampling is not available via pure Dart APIs.
  //       For CPU profiling, use flutter DevTools or dart:developer.

  final timestamp = DateTime.now()
      .toUtc()
      .toIso8601String()
      .replaceAll(':', '-')
      .replaceAll('.', '-');

  final resultsDir = Directory('../results/parser');
  if (!resultsDir.existsSync()) resultsDir.createSync(recursive: true);

  final outputPath = '../results/parser/$timestamp.json';
  final jsonPayload = {
    'timestamp': DateTime.now().toUtc().toIso8601String(),
    'dartVersion': Platform.version,
    'operatingSystem': Platform.operatingSystem,
    // TODO: read RSS memory via dart:developer Service.getVM().isolates[0].pauseOnExit
    //       and include peak heap usage for each benchmark run.
    'benchmarks': rows.map((r) => r.toJson()).toList(),
  };

  final file = File(outputPath);
  await file.writeAsString(
    const JsonEncoder.withIndent('  ').convert(jsonPayload),
  );

  print('Results written to: ${file.absolute.path}');
}

// ---------------------------------------------------------------------------
// Table formatting helpers
// ---------------------------------------------------------------------------

const int _colScenario = 36;
const int _colScore = 18;
const int _colRatio = 10;

String _tableHeader() {
  return '${'Scenario'.padRight(_colScenario)}'
      '${'full_svg_flutter (µs)'.padLeft(_colScore)}'
      '${'flutter_svg (µs)'.padLeft(_colScore)}'
      '${'ratio'.padLeft(_colRatio)}';
}

String _tableDivider() => '─' * (_colScenario + _colScore * 2 + _colRatio);

// ---------------------------------------------------------------------------
// Result row
// ---------------------------------------------------------------------------

class _ResultRow {
  _ResultRow({
    required this.scenario,
    required this.fullSvgUs,
    required this.flutterSvgUs,
  });

  final String scenario;
  final double fullSvgUs;
  final double? flutterSvgUs;

  double? get ratio =>
      flutterSvgUs != null && fullSvgUs > 0 ? flutterSvgUs! / fullSvgUs : null;

  String tableRow() {
    final ratioStr = ratio != null ? ratio!.toStringAsFixed(2) : 'N/A';
    final flutterStr = flutterSvgUs != null
        ? flutterSvgUs!.toStringAsFixed(2)
        : 'N/A (unsupported)';

    return '${scenario.padRight(_colScenario)}'
        '${fullSvgUs.toStringAsFixed(2).padLeft(_colScore)}'
        '${flutterStr.padLeft(_colScore)}'
        '${ratioStr.padLeft(_colRatio)}';
  }

  Map<String, dynamic> toJson() => {
        'scenario': scenario,
        'full_svg_flutter_us': fullSvgUs,
        'flutter_svg_us': flutterSvgUs,
        'ratio': ratio,
        'notes': flutterSvgUs == null
            ? 'flutter_svg does not support this feature'
            : null,
      };
}
