#!/usr/bin/env dart
// ignore_for_file: avoid_print
// generate_report.dart
//
// Standalone Dart script — no pub dependencies. Uses only dart:io, dart:convert, dart:math.
//
// Reads all *.json result files from results/ (skipping results/example/),
// computes statistics, and generates:
//   reports/report.md
//   reports/index.html
//   reports/summary.csv
//
// Usage:
//   dart run scripts/generate_report.dart [results_dir]
//
// Default results_dir: results/

import 'dart:convert';
import 'dart:io';
import 'dart:math';

// ─────────────────────────────────────────────────────────────────────────────
// Data model
// ─────────────────────────────────────────────────────────────────────────────

class PackageResult {
  final String package;
  final double? firstPaintMs;
  final double? avgBuildMs;
  final double? avgRasterMs;
  final double? p90BuildMs;
  final double? p99BuildMs;
  final int? jankFrameCount;
  final double? memoryDeltaMb;
  final int sampleCount;
  final bool unsupported;
  final String? unsupportedReason;
  final String? note;

  PackageResult({
    required this.package,
    this.firstPaintMs,
    this.avgBuildMs,
    this.avgRasterMs,
    this.p90BuildMs,
    this.p99BuildMs,
    this.jankFrameCount,
    this.memoryDeltaMb,
    required this.sampleCount,
    required this.unsupported,
    this.unsupportedReason,
    this.note,
  });

  factory PackageResult.fromJson(String packageName, Map<String, dynamic> j) {
    return PackageResult(
      package: packageName,
      firstPaintMs: _toDouble(j['first_paint_ms']),
      avgBuildMs: _toDouble(j['avg_build_ms']),
      avgRasterMs: _toDouble(j['avg_raster_ms']),
      p90BuildMs: _toDouble(j['p90_build_ms']),
      p99BuildMs: _toDouble(j['p99_build_ms']),
      jankFrameCount: j['jank_frame_count'] as int?,
      memoryDeltaMb: _toDouble(j['memory_delta_mb']),
      sampleCount: (j['sample_count'] as int?) ?? 0,
      unsupported: (j['unsupported'] as bool?) ?? false,
      unsupportedReason: j['unsupported_reason'] as String?,
      note: j['note'] as String?,
    );
  }

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return null;
  }
}

class ScenarioResult {
  final String scenario;
  final String category;
  final String asset;
  final String cacheState;
  final Map<String, PackageResult> packages;
  // Source file metadata
  String? deviceInfo;
  String? flutterVersion;
  String? dartVersion;
  String? rendererMode;
  String? timestamp;

  ScenarioResult({
    required this.scenario,
    required this.category,
    required this.asset,
    required this.cacheState,
    required this.packages,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Statistics helpers
// ─────────────────────────────────────────────────────────────────────────────

double? median(List<double> values) {
  if (values.isEmpty) return null;
  final sorted = List<double>.from(values)..sort();
  final mid = sorted.length ~/ 2;
  return sorted.length.isOdd
      ? sorted[mid]
      : (sorted[mid - 1] + sorted[mid]) / 2.0;
}

double? average(List<double> values) {
  if (values.isEmpty) return null;
  return values.reduce((a, b) => a + b) / values.length;
}

double? percentile(List<double> values, double p) {
  if (values.isEmpty) return null;
  final sorted = List<double>.from(values)..sort();
  final index = (p / 100.0 * (sorted.length - 1)).round();
  return sorted[index.clamp(0, sorted.length - 1)];
}

String fmt(double? v, {int decimals = 2}) {
  if (v == null) return 'N/A';
  return v.toStringAsFixed(decimals);
}

String fmtMs(double? v) => v == null ? 'N/A' : '${fmt(v)}ms';

// ─────────────────────────────────────────────────────────────────────────────
// File discovery
// ─────────────────────────────────────────────────────────────────────────────

List<File> findResultFiles(Directory resultsDir) {
  final files = <File>[];
  if (!resultsDir.existsSync()) return files;

  for (final entity in resultsDir.listSync(recursive: true)) {
    if (entity is! File) continue;
    if (!entity.path.endsWith('.json')) continue;
    // Skip example directory
    if (entity.path.contains('/example/')) continue;
    files.add(entity);
  }
  return files;
}

// ─────────────────────────────────────────────────────────────────────────────
// JSON parsing
// ─────────────────────────────────────────────────────────────────────────────

List<ScenarioResult> parseResultFile(File file) {
  final raw = file.readAsStringSync();
  final Map<String, dynamic> json;
  try {
    json = jsonDecode(raw) as Map<String, dynamic>;
  } catch (e) {
    stderr.writeln('WARNING: Could not parse ${file.path}: $e');
    return [];
  }

  final deviceInfo = json['device_info'] as String? ?? 'Unknown device';
  final flutterVersion = json['flutter_version'] as String? ?? '?';
  final dartVersion = json['dart_version'] as String? ?? '?';
  final rendererMode = json['renderer_mode'] as String? ?? '?';
  final timestamp = json['timestamp'] as String? ?? '?';

  final rawResults = json['results'];
  if (rawResults is! List) return [];

  final scenarios = <ScenarioResult>[];
  for (final item in rawResults) {
    if (item is! Map<String, dynamic>) continue;

    final packages = <String, PackageResult>{};
    final rawPkgs = item['packages'];
    if (rawPkgs is Map<String, dynamic>) {
      for (final entry in rawPkgs.entries) {
        if (entry.value is Map<String, dynamic>) {
          packages[entry.key] =
              PackageResult.fromJson(entry.key, entry.value as Map<String, dynamic>);
        }
      }
    }

    final scenario = ScenarioResult(
      scenario: item['scenario'] as String? ?? 'unknown',
      category: item['category'] as String? ?? 'unknown',
      asset: item['asset'] as String? ?? '',
      cacheState: item['cache_state'] as String? ?? 'unknown',
      packages: packages,
    )
      ..deviceInfo = deviceInfo
      ..flutterVersion = flutterVersion
      ..dartVersion = dartVersion
      ..rendererMode = rendererMode
      ..timestamp = timestamp;

    scenarios.add(scenario);
  }
  return scenarios;
}

// ─────────────────────────────────────────────────────────────────────────────
// Winner determination
// ─────────────────────────────────────────────────────────────────────────────

String determineWinner(ScenarioResult scenario) {
  String? bestPkg;
  double? bestScore;

  for (final entry in scenario.packages.entries) {
    final pkg = entry.value;
    if (pkg.unsupported) continue;
    // Score: lower p99 build time is better; fall back to avgBuild
    final score = pkg.p99BuildMs ?? pkg.avgBuildMs;
    if (score == null) continue;
    if (bestScore == null || score < bestScore) {
      bestScore = score;
      bestPkg = entry.key;
    }
  }
  return bestPkg ?? 'N/A';
}

// ─────────────────────────────────────────────────────────────────────────────
// Markdown report
// ─────────────────────────────────────────────────────────────────────────────

String buildMarkdownReport(List<ScenarioResult> allScenarios) {
  final buf = StringBuffer();
  final now = DateTime.now().toUtc();

  // Collect unique environment info (from first scenario with data)
  String deviceInfo = 'Unknown';
  String flutterVersion = '?';
  String dartVersion = '?';
  String rendererMode = '?';
  for (final s in allScenarios) {
    if (s.deviceInfo != null && s.deviceInfo != 'Unknown device') {
      deviceInfo = s.deviceInfo!;
      flutterVersion = s.flutterVersion ?? '?';
      dartVersion = s.dartVersion ?? '?';
      rendererMode = s.rendererMode ?? '?';
      break;
    }
  }

  buf.writeln('# full_svg_flutter Benchmark Report');
  buf.writeln();
  buf.writeln('> Generated by `scripts/generate_report.dart` on '
      '${now.toIso8601String().substring(0, 10)}');
  buf.writeln();

  // Environment section
  buf.writeln('## Environment');
  buf.writeln();
  buf.writeln('| Field | Value |');
  buf.writeln('|-------|-------|');
  buf.writeln('| Device | $deviceInfo |');
  buf.writeln('| Flutter | $flutterVersion |');
  buf.writeln('| Dart | $dartVersion |');
  buf.writeln('| Renderer | $rendererMode |');
  buf.writeln('| Report generated | ${now.toIso8601String()} |');
  buf.writeln('| Scenarios | ${allScenarios.length} |');
  buf.writeln();

  // Executive summary table
  buf.writeln('## Executive Summary');
  buf.writeln();
  buf.writeln('All times in milliseconds. '
      '`build` = UI thread time, `p99` = 99th percentile build time.');
  buf.writeln();
  buf.writeln(
      '| Scenario | Category | Cache | full_svg_flutter_picture p99 | full_svg_flutter_raster p99 | flutter_svg p99 | Winner |');
  buf.writeln(
      '|----------|----------|-------|-----------------------------|-----------------------------|-----------------|--------|');

  for (final s in allScenarios) {
    final fsvfP = s.packages['full_svg_flutter_picture'];
    final fsvfR = s.packages['full_svg_flutter_raster'];
    final fsvg = s.packages['flutter_svg'];

    final colP = fsvfP == null
        ? 'N/A'
        : fsvfP.unsupported
            ? '❌ unsupported'
            : fmtMs(fsvfP.p99BuildMs);
    final colR = fsvfR == null
        ? 'N/A'
        : fsvfR.unsupported
            ? '❌ unsupported'
            : fmtMs(fsvfR.p99BuildMs);
    final colF = fsvg == null
        ? 'N/A'
        : fsvg.unsupported
            ? '❌ unsupported'
            : fmtMs(fsvg.p99BuildMs);

    final winner = determineWinner(s);
    buf.writeln(
        '| `${s.scenario}` | ${s.category} | ${s.cacheState} | $colP | $colR | $colF | **$winner** |');
  }
  buf.writeln();

  // Per-category detailed sections
  final categories = allScenarios.map((s) => s.category).toSet().toList()
    ..sort();

  for (final cat in categories) {
    final catScenarios = allScenarios.where((s) => s.category == cat).toList();
    buf.writeln('## Category: ${_capitalize(cat)}');
    buf.writeln();

    for (final s in catScenarios) {
      buf.writeln('### `${s.scenario}`');
      buf.writeln();
      buf.writeln('- **Asset**: `${s.asset}`');
      buf.writeln('- **Cache state**: ${s.cacheState}');
      buf.writeln('- **Winner**: ${determineWinner(s)}');
      buf.writeln();
      buf.writeln(
          '| Package | first_paint | avg_build | avg_raster | p90_build | p99_build | jank_frames | memory_delta |');
      buf.writeln(
          '|---------|-------------|-----------|------------|-----------|-----------|-------------|--------------|');

      for (final entry in s.packages.entries) {
        final pkg = entry.value;
        if (pkg.unsupported) {
          buf.writeln(
              '| `${entry.key}` | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ${pkg.unsupportedReason ?? "unsupported"} |');
        } else {
          buf.writeln(
              '| `${entry.key}` | ${fmtMs(pkg.firstPaintMs)} | ${fmtMs(pkg.avgBuildMs)} | ${fmtMs(pkg.avgRasterMs)} | ${fmtMs(pkg.p90BuildMs)} | ${fmtMs(pkg.p99BuildMs)} | ${pkg.jankFrameCount ?? "N/A"} | ${fmt(pkg.memoryDeltaMb)}MB |');
        }
      }
      if (catScenarios.last != s) buf.writeln();
    }
    buf.writeln();
  }

  // Methodology and raw data links
  buf.writeln('## Methodology');
  buf.writeln();
  buf.writeln(
      'See [methodology.md](../methodology.md) for full measurement approach, '
      'warmup rules, jank definition, thermal throttling guidance, and how to '
      'reproduce these results.');
  buf.writeln();
  buf.writeln('## Raw Data');
  buf.writeln();
  buf.writeln('All raw JSON result files are in `results/` (excluding `results/example/` '
      'which contains placeholder data). See `results/android/`, `results/ios/`, '
      '`results/macos/`.');

  return buf.toString();
}

// ─────────────────────────────────────────────────────────────────────────────
// HTML report
// ─────────────────────────────────────────────────────────────────────────────

String buildHtmlReport(List<ScenarioResult> allScenarios) {
  final now = DateTime.now().toUtc();

  String deviceInfo = 'Unknown';
  String flutterVersion = '?';
  String rendererMode = '?';
  for (final s in allScenarios) {
    if (s.deviceInfo != null && s.deviceInfo != 'Unknown device') {
      deviceInfo = s.deviceInfo!;
      flutterVersion = s.flutterVersion ?? '?';
      rendererMode = s.rendererMode ?? '?';
      break;
    }
  }

  // Build chart data JSON
  final chartLabels = allScenarios.map((s) => s.scenario).toList();
  final chartDataPicture = allScenarios.map((s) {
    final pkg = s.packages['full_svg_flutter_picture'];
    if (pkg == null || pkg.unsupported) return null;
    return pkg.p99BuildMs;
  }).toList();
  final chartDataRaster = allScenarios.map((s) {
    final pkg = s.packages['full_svg_flutter_raster'];
    if (pkg == null || pkg.unsupported) return null;
    return pkg.p99BuildMs;
  }).toList();
  final chartDataFlutterSvg = allScenarios.map((s) {
    final pkg = s.packages['flutter_svg'];
    if (pkg == null || pkg.unsupported) return null;
    return pkg.p99BuildMs;
  }).toList();

  final chartJson = jsonEncode({
    'labels': chartLabels,
    'datasets': [
      {
        'label': 'full_svg_flutter (picture)',
        'data': chartDataPicture,
        'backgroundColor': 'rgba(99,102,241,0.7)',
        'borderColor': 'rgba(99,102,241,1)',
        'borderWidth': 1,
      },
      {
        'label': 'full_svg_flutter (raster)',
        'data': chartDataRaster,
        'backgroundColor': 'rgba(16,185,129,0.7)',
        'borderColor': 'rgba(16,185,129,1)',
        'borderWidth': 1,
      },
      {
        'label': 'flutter_svg',
        'data': chartDataFlutterSvg,
        'backgroundColor': 'rgba(245,158,11,0.7)',
        'borderColor': 'rgba(245,158,11,1)',
        'borderWidth': 1,
      },
    ],
  });

  // Build table rows HTML
  final rowsBuf = StringBuffer();
  for (final s in allScenarios) {
    final winner = determineWinner(s);

    String cellValue(String pkgKey) {
      final pkg = s.packages[pkgKey];
      if (pkg == null) return '<td class="na">N/A</td>';
      if (pkg.unsupported) return '<td class="unsupported">❌ unsupported</td>';
      final v = pkg.p99BuildMs;
      if (v == null) return '<td class="na">N/A</td>';

      // Colour coding: find min/max across this row
      final vals = s.packages.values
          .where((p) => !p.unsupported && p.p99BuildMs != null)
          .map((p) => p.p99BuildMs!)
          .toList();
      if (vals.isEmpty) return '<td>${fmtMs(v)}</td>';
      final minVal = vals.reduce(min);
      final maxVal = vals.reduce(max);
      String cls = '';
      if (v == minVal && minVal != maxVal) cls = ' class="best"';
      if (v == maxVal && minVal != maxVal) cls = ' class="worst"';
      return '<td$cls>${fmtMs(v)}</td>';
    }

    final winnerLabel = winner == 'N/A' ? 'N/A' : '<strong>$winner</strong>';
    rowsBuf.writeln('''
      <tr>
        <td><code>${s.scenario}</code></td>
        <td>${s.category}</td>
        <td>${s.cacheState}</td>
        ${cellValue('full_svg_flutter_picture')}
        ${cellValue('full_svg_flutter_raster')}
        ${cellValue('flutter_svg')}
        <td>$winnerLabel</td>
      </tr>''');
  }

  return '''<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8"/>
  <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
  <title>full_svg_flutter Benchmark Report</title>
  <script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.0/dist/chart.umd.min.js"></script>
  <style>
    :root {
      --bg: #0f0f1a;
      --surface: #1a1a2e;
      --surface2: #16213e;
      --border: #2a2a4a;
      --text: #e2e8f0;
      --text-muted: #94a3b8;
      --accent: #6366f1;
      --best: #10b981;
      --worst: #ef4444;
      --warn: #f59e0b;
    }
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      background: var(--bg);
      color: var(--text);
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', system-ui, sans-serif;
      font-size: 14px;
      line-height: 1.6;
      padding: 0 0 60px;
    }
    header {
      background: var(--surface);
      border-bottom: 1px solid var(--border);
      padding: 24px 32px;
    }
    header h1 { font-size: 22px; color: var(--text); margin-bottom: 6px; }
    header p  { color: var(--text-muted); font-size: 13px; }
    .container { max-width: 1200px; margin: 0 auto; padding: 0 32px; }
    section { margin-top: 36px; }
    h2 { font-size: 16px; font-weight: 600; color: var(--accent);
         border-bottom: 1px solid var(--border); padding-bottom: 8px; margin-bottom: 16px; }
    .meta-grid {
      display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
      gap: 12px; margin-bottom: 8px;
    }
    .meta-card {
      background: var(--surface); border: 1px solid var(--border);
      border-radius: 8px; padding: 14px 16px;
    }
    .meta-card .label { font-size: 11px; color: var(--text-muted); text-transform: uppercase;
                        letter-spacing: 0.06em; margin-bottom: 4px; }
    .meta-card .value { font-size: 15px; font-weight: 600; }
    .note {
      background: var(--surface2); border-left: 3px solid var(--warn);
      border-radius: 4px; padding: 10px 14px; font-size: 12px;
      color: var(--text-muted); margin-bottom: 16px;
    }
    table {
      width: 100%; border-collapse: collapse;
      background: var(--surface); border-radius: 8px; overflow: hidden;
      border: 1px solid var(--border);
    }
    th {
      background: var(--surface2); padding: 10px 12px; text-align: left;
      font-size: 11px; text-transform: uppercase; letter-spacing: 0.05em;
      color: var(--text-muted); border-bottom: 1px solid var(--border);
    }
    td {
      padding: 9px 12px; border-bottom: 1px solid var(--border);
      font-size: 13px; vertical-align: middle;
    }
    tr:last-child td { border-bottom: none; }
    tr:hover td { background: rgba(99,102,241,0.06); }
    td.best  { color: var(--best); font-weight: 600; }
    td.worst { color: var(--worst); }
    td.na    { color: var(--text-muted); font-style: italic; }
    td.unsupported { color: var(--worst); font-size: 12px; }
    code { font-family: 'SF Mono', 'Fira Code', monospace; font-size: 12px;
           background: rgba(99,102,241,0.15); padding: 1px 5px; border-radius: 3px; }
    .chart-container {
      background: var(--surface); border: 1px solid var(--border);
      border-radius: 8px; padding: 20px; margin-bottom: 24px;
    }
    .chart-container canvas { max-height: 380px; }
    footer {
      margin-top: 48px; padding: 16px 32px;
      border-top: 1px solid var(--border);
      font-size: 12px; color: var(--text-muted); text-align: center;
    }
  </style>
</head>
<body>
  <header>
    <h1>full_svg_flutter Benchmark Report</h1>
    <p>Generated by <code>generate_report.dart</code> &mdash;
       ${now.toIso8601String().substring(0, 16)} UTC &mdash;
       raw JSON in <code>results/</code></p>
  </header>

  <div class="container">

    <section>
      <h2>Environment</h2>
      <div class="meta-grid">
        <div class="meta-card">
          <div class="label">Device</div>
          <div class="value">${_escHtml(deviceInfo)}</div>
        </div>
        <div class="meta-card">
          <div class="label">Flutter</div>
          <div class="value">${_escHtml(flutterVersion)}</div>
        </div>
        <div class="meta-card">
          <div class="label">Renderer</div>
          <div class="value">${_escHtml(rendererMode)}</div>
        </div>
        <div class="meta-card">
          <div class="label">Scenarios</div>
          <div class="value">${allScenarios.length}</div>
        </div>
      </div>
    </section>

    <section>
      <h2>p99 Build Time Comparison (ms)</h2>
      <div class="note">
        p99 = 99th percentile UI-thread build time. Lower is better.
        Null/missing bars indicate the feature is not supported by that package.
      </div>
      <div class="chart-container">
        <canvas id="mainChart"></canvas>
      </div>
    </section>

    <section>
      <h2>Summary Table</h2>
      <div class="note">
        Color coding: <span style="color:var(--best)">green = best p99</span>,
        <span style="color:var(--worst)">red = worst p99</span> within each row.
        ❌ = feature not supported by this package.
      </div>
      <table>
        <thead>
          <tr>
            <th>Scenario</th>
            <th>Category</th>
            <th>Cache</th>
            <th>full_svg_flutter (picture) p99</th>
            <th>full_svg_flutter (raster) p99</th>
            <th>flutter_svg p99</th>
            <th>Winner</th>
          </tr>
        </thead>
        <tbody>
          $rowsBuf
        </tbody>
      </table>
    </section>

  </div>

  <footer>
    Generated by <code>generate_report.dart</code> &mdash;
    raw JSON data in <code>results/</code> &mdash;
    see <code>methodology.md</code> for measurement approach
  </footer>

  <script>
    const CHART_DATA = $chartJson;

    const ctx = document.getElementById('mainChart').getContext('2d');
    new Chart(ctx, {
      type: 'bar',
      data: CHART_DATA,
      options: {
        responsive: true,
        plugins: {
          legend: { labels: { color: '#e2e8f0', font: { size: 12 } } },
          tooltip: {
            callbacks: {
              label: ctx => ctx.dataset.label + ': ' +
                (ctx.raw !== null ? ctx.raw.toFixed(2) + ' ms' : 'unsupported')
            }
          }
        },
        scales: {
          x: {
            ticks: { color: '#94a3b8', font: { size: 10 }, maxRotation: 45 },
            grid: { color: 'rgba(255,255,255,0.05)' }
          },
          y: {
            beginAtZero: true,
            title: { display: true, text: 'p99 build time (ms)', color: '#94a3b8' },
            ticks: { color: '#94a3b8' },
            grid: { color: 'rgba(255,255,255,0.05)' }
          }
        }
      }
    });
  </script>
</body>
</html>
''';
}

String _escHtml(String s) =>
    s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');

// ─────────────────────────────────────────────────────────────────────────────
// CSV report
// ─────────────────────────────────────────────────────────────────────────────

String buildCsvReport(List<ScenarioResult> allScenarios) {
  final buf = StringBuffer();
  buf.writeln(
      'scenario,category,asset,cache_state,package,first_paint_ms,avg_build_ms,'
      'avg_raster_ms,p90_build_ms,p99_build_ms,jank_frame_count,memory_delta_mb,'
      'sample_count,unsupported,winner');

  for (final s in allScenarios) {
    final winner = determineWinner(s);
    for (final entry in s.packages.entries) {
      final pkg = entry.value;
      buf.writeln([
        _csvCell(s.scenario),
        _csvCell(s.category),
        _csvCell(s.asset),
        _csvCell(s.cacheState),
        _csvCell(entry.key),
        pkg.firstPaintMs?.toStringAsFixed(3) ?? '',
        pkg.avgBuildMs?.toStringAsFixed(3) ?? '',
        pkg.avgRasterMs?.toStringAsFixed(3) ?? '',
        pkg.p90BuildMs?.toStringAsFixed(3) ?? '',
        pkg.p99BuildMs?.toStringAsFixed(3) ?? '',
        pkg.jankFrameCount?.toString() ?? '',
        pkg.memoryDeltaMb?.toStringAsFixed(2) ?? '',
        pkg.sampleCount.toString(),
        pkg.unsupported ? 'true' : 'false',
        _csvCell(winner),
      ].join(','));
    }
  }
  return buf.toString();
}

String _csvCell(String v) {
  if (v.contains(',') || v.contains('"') || v.contains('\n')) {
    return '"${v.replaceAll('"', '""')}"';
  }
  return v;
}

// ─────────────────────────────────────────────────────────────────────────────
// Main
// ─────────────────────────────────────────────────────────────────────────────

String _capitalize(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

void main(List<String> args) {
  // Resolve paths relative to script location
  final scriptFile = File(Platform.script.toFilePath());
  final projectRoot = scriptFile.parent.parent;

  final resultsDirPath =
      args.isNotEmpty ? args[0] : '${projectRoot.path}/results';
  final resultsDir = Directory(resultsDirPath);
  final reportsDir = Directory('${projectRoot.path}/reports');

  print('==> generate_report.dart');
  print('    Results dir: ${resultsDir.path}');
  print('    Reports dir: ${reportsDir.path}');
  print('');

  if (!resultsDir.existsSync()) {
    stderr.writeln('ERROR: Results directory not found: ${resultsDir.path}');
    exit(1);
  }

  // Discover and parse all result files
  final files = findResultFiles(resultsDir);
  if (files.isEmpty) {
    stderr.writeln('WARNING: No result JSON files found in ${resultsDir.path}');
    stderr.writeln('         (results/example/ is excluded by design)');
    exit(0);
  }
  print('    Found ${files.length} result file(s)');

  final allScenarios = <ScenarioResult>[];
  for (final file in files) {
    print('    Parsing: ${file.path}');
    allScenarios.addAll(parseResultFile(file));
  }

  if (allScenarios.isEmpty) {
    stderr.writeln('WARNING: No scenario results parsed. Check file formats.');
    exit(0);
  }
  print('    Total scenarios: ${allScenarios.length}');
  print('');

  // Ensure reports directory exists
  reportsDir.createSync(recursive: true);

  // Generate report.md
  final mdPath = '${reportsDir.path}/report.md';
  File(mdPath).writeAsStringSync(buildMarkdownReport(allScenarios));
  print('    Generated: $mdPath');

  // Generate index.html
  final htmlPath = '${reportsDir.path}/index.html';
  File(htmlPath).writeAsStringSync(buildHtmlReport(allScenarios));
  print('    Generated: $htmlPath');

  // Generate summary.csv
  final csvPath = '${reportsDir.path}/summary.csv';
  File(csvPath).writeAsStringSync(buildCsvReport(allScenarios));
  print('    Generated: $csvPath');

  print('');
  print('==> Done.');
}
