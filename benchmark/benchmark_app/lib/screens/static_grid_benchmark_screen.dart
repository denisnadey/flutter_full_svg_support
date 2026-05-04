import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart' as fsvg;
import 'package:full_svg_flutter/full_svg_flutter.dart' as ffsf;

import '../result_models.dart';

/// Benchmark screen that renders a grid of SVGs and measures frame performance.
///
/// Scenarios covered:
/// - [grid_100_same_svg_cached]  — 100 tiles showing the same SVG (cache hit test)
/// - [grid_100_unique_svg]       — 100 tiles each showing a different SVG
/// - [grid_500_simple_icons]     — 500 simple icon tiles
class StaticGridBenchmarkScreen extends StatefulWidget {
  const StaticGridBenchmarkScreen({super.key});

  @override
  State<StaticGridBenchmarkScreen> createState() =>
      _StaticGridBenchmarkScreenState();
}

class _StaticGridBenchmarkScreenState
    extends State<StaticGridBenchmarkScreen> {
  _Scenario _activeScenario = _Scenario.grid100SameCached;
  _Package _activePackage = _Package.fullSvgPicture;
  List<BenchmarkMetrics> _results = [];

  // Asset paths used in grids. Adjust once actual SVG files are added.
  static const String _simpleIconPath = 'assets/simple/simple_icon.svg';
  static const String _complexPath = 'assets/complex/complex_path_1k.svg';

  int get _gridCount {
    switch (_activeScenario) {
      case _Scenario.grid100SameCached:
      case _Scenario.grid100Unique:
        return 100;
      case _Scenario.grid500SimpleIcons:
        return 500;
    }
  }

  Widget _buildTile(int index) {
    final String assetPath;
    switch (_activeScenario) {
      case _Scenario.grid100SameCached:
        // All tiles use the same asset — exercises cache.
        assetPath = _simpleIconPath;
      case _Scenario.grid100Unique:
        // Alternate between two assets to simulate variety.
        assetPath = index.isEven ? _simpleIconPath : _complexPath;
      case _Scenario.grid500SimpleIcons:
        assetPath = _simpleIconPath;
    }

    switch (_activePackage) {
      case _Package.fullSvgPicture:
        return ffsf.SvgPicture.asset(assetPath, width: 48, height: 48);
      case _Package.fullSvgRaster:
        // TODO: pass renderingStrategy: RenderingStrategy.raster
        return ffsf.SvgPicture.asset(assetPath, width: 48, height: 48);
      case _Package.flutterSvg:
        return fsvg.SvgPicture.asset(assetPath, width: 48, height: 48);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Static Grid Benchmark')),
      body: Column(
        children: [
          // Controls
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                const Text('Scenario: '),
                DropdownButton<_Scenario>(
                  value: _activeScenario,
                  onChanged: (v) => setState(() => _activeScenario = v!),
                  items: _Scenario.values
                      .map((s) => DropdownMenuItem(value: s, child: Text(s.label)))
                      .toList(),
                ),
                const SizedBox(width: 16),
                const Text('Package: '),
                DropdownButton<_Package>(
                  value: _activePackage,
                  onChanged: (v) => setState(() => _activePackage = v!),
                  items: _Package.values
                      .map((p) => DropdownMenuItem(value: p, child: Text(p.label)))
                      .toList(),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Text(
              'Rendering $_gridCount tiles — '
              'frame timings available in integration_test run.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          // Grid
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 8,
                crossAxisSpacing: 4,
                mainAxisSpacing: 4,
              ),
              itemCount: _gridCount,
              itemBuilder: (_, index) => _buildTile(index),
            ),
          ),
          // Results summary (populated by integration test run)
          if (_results.isNotEmpty)
            Container(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _results
                    .map((r) => Text(
                          '${r.package}: avg ${r.avgBuildMs.toStringAsFixed(2)} ms '
                          '| jank60=${r.jankFrameCount60hz}',
                        ))
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Enums
// ---------------------------------------------------------------------------

enum _Scenario {
  grid100SameCached,
  grid100Unique,
  grid500SimpleIcons;

  String get label => switch (this) {
        grid100SameCached => 'grid_100_same_svg_cached',
        grid100Unique => 'grid_100_unique_svg',
        grid500SimpleIcons => 'grid_500_simple_icons',
      };

  String get scenarioKey => label;
}

enum _Package {
  fullSvgPicture,
  fullSvgRaster,
  flutterSvg;

  String get label => switch (this) {
        fullSvgPicture => 'full_svg_flutter_picture',
        fullSvgRaster => 'full_svg_flutter_raster',
        flutterSvg => 'flutter_svg',
      };
}
