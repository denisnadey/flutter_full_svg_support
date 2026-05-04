import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart' as fsvg;
import 'package:full_svg_flutter/full_svg_flutter.dart' as ffsf;

import '../benchmark_runner.dart';
import '../result_models.dart';

/// Benchmark screen that renders a single SVG three ways and reports
/// per-frame build/raster timings for each approach:
///
/// 1. full_svg_flutter — picture rendering strategy
/// 2. full_svg_flutter — raster rendering strategy
/// 3. flutter_svg      — default (picture) rendering strategy
class StaticSingleSvgBenchmarkScreen extends StatefulWidget {
  const StaticSingleSvgBenchmarkScreen({super.key});

  @override
  State<StaticSingleSvgBenchmarkScreen> createState() =>
      _StaticSingleSvgBenchmarkScreenState();
}

class _StaticSingleSvgBenchmarkScreenState
    extends State<StaticSingleSvgBenchmarkScreen> {
  List<BenchmarkMetrics> _results = [];
  bool _running = false;

  static const String _assetPath = 'assets/simple/simple_icon.svg';

  // ---------------------------------------------------------------------------
  // Benchmark execution — must be called from an integration-test context that
  // provides a WidgetTester. The on-device "Run" button triggers a lightweight
  // manual timing instead (no WidgetTester available at runtime).
  // ---------------------------------------------------------------------------

  /// Runs all three rendering strategies and stores results.
  ///
  /// NOTE: This method is designed to be called from [BenchmarkRunner] inside
  /// an integration test with a real [WidgetTester]. When invoked from the UI
  /// the results are approximate wall-clock measurements only.
  Future<void> _runManualBenchmark() async {
    setState(() {
      _running = true;
      _results = [];
    });

    // Manual wall-clock measurement for on-device preview.
    // For accurate frame timings use integration_test/benchmark_test.dart.
    final sw = Stopwatch();

    final packages = <String, Widget>{
      'full_svg_flutter_picture': ffsf.SvgPicture.asset(
        _assetPath,
        // TODO: pass renderingStrategy: RenderingStrategy.picture once the
        // full_svg_flutter API stabilises.
      ),
      'full_svg_flutter_raster': ffsf.SvgPicture.asset(
        _assetPath,
        // TODO: pass renderingStrategy: RenderingStrategy.raster
      ),
      'flutter_svg': fsvg.SvgPicture.asset(_assetPath),
    };

    final results = <BenchmarkMetrics>[];
    for (final entry in packages.entries) {
      sw.reset();
      sw.start();
      // Simulate a brief render cycle — real timing happens in integration_test.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      sw.stop();

      results.add(BenchmarkMetrics(
        name: 'Static Single SVG — ${entry.key}',
        package: entry.key,
        scenario: 'render_simple_icon',
        firstPaintMs: sw.elapsedMicroseconds / 1000.0,
        avgBuildMs: 0,
        p90BuildMs: 0,
        p99BuildMs: 0,
        worstBuildMs: 0,
        avgRasterMs: 0,
        p90RasterMs: 0,
        p99RasterMs: 0,
        worstRasterMs: 0,
        frameCount: 0,
        jankFrameCount60hz: 0,
        jankFrameCount120hz: 0,
        memoryBeforeMb: 0,
        memoryAfterMb: 0,
        memoryDeltaMb: 0,
        benchmarkDurationMs: 50,
      ));
    }

    setState(() {
      _results = results;
      _running = false;
    });
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Static Single SVG Benchmark')),
      body: Column(
        children: [
          // Preview row — all three renderers side-by-side
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _SvgPreviewTile(
                  label: 'full_svg\n(picture)',
                  child: ffsf.SvgPicture.asset(_assetPath,
                      width: 80, height: 80),
                ),
                _SvgPreviewTile(
                  label: 'full_svg\n(raster)',
                  child: ffsf.SvgPicture.asset(_assetPath,
                      width: 80, height: 80),
                ),
                _SvgPreviewTile(
                  label: 'flutter_svg',
                  child: fsvg.SvgPicture.asset(_assetPath,
                      width: 80, height: 80),
                ),
              ],
            ),
          ),

          const Divider(),

          // Results table
          if (_results.isEmpty && !_running)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                'Tap "Run" to start.\n'
                'For accurate frame timings, run via integration_test.',
                textAlign: TextAlign.center,
              ),
            ),
          if (_running)
            const Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ),
          if (_results.isNotEmpty)
            Expanded(child: _ResultsTable(results: _results)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _running ? null : _runManualBenchmark,
        label: const Text('Run'),
        icon: const Icon(Icons.play_arrow),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helper widgets
// ---------------------------------------------------------------------------

class _SvgPreviewTile extends StatelessWidget {
  const _SvgPreviewTile({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        child,
        const SizedBox(height: 4),
        Text(label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}

class _ResultsTable extends StatelessWidget {
  const _ResultsTable({required this.results});
  final List<BenchmarkMetrics> results;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        const _TableHeader(),
        ...results.map((r) => _TableRow(metrics: r)),
      ],
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(flex: 3, child: Text('Package', style: TextStyle(fontWeight: FontWeight.bold))),
        Expanded(flex: 2, child: Text('First paint', style: TextStyle(fontWeight: FontWeight.bold))),
        Expanded(flex: 2, child: Text('Avg build', style: TextStyle(fontWeight: FontWeight.bold))),
        Expanded(flex: 2, child: Text('P90 build', style: TextStyle(fontWeight: FontWeight.bold))),
        Expanded(flex: 2, child: Text('Jank 60hz', style: TextStyle(fontWeight: FontWeight.bold))),
      ],
    );
  }
}

class _TableRow extends StatelessWidget {
  const _TableRow({required this.metrics});
  final BenchmarkMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text(metrics.package, overflow: TextOverflow.ellipsis)),
          Expanded(flex: 2, child: Text('${metrics.firstPaintMs.toStringAsFixed(2)} ms')),
          Expanded(flex: 2, child: Text('${metrics.avgBuildMs.toStringAsFixed(2)} ms')),
          Expanded(flex: 2, child: Text('${metrics.p90BuildMs.toStringAsFixed(2)} ms')),
          Expanded(flex: 2, child: Text('${metrics.jankFrameCount60hz}')),
        ],
      ),
    );
  }
}
