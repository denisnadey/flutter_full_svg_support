import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart' as fsvg;
import 'package:full_svg_flutter/full_svg_flutter.dart' as ffsf;

import '../result_models.dart';

/// Scroll-stress benchmark: a [ListView] of 200 SVG tiles that are scrolled
/// programmatically to stress-test decode-on-scroll performance.
///
/// Scenario: scroll_200_svg_items
class ScrollStressBenchmarkScreen extends StatefulWidget {
  const ScrollStressBenchmarkScreen({super.key});

  @override
  State<ScrollStressBenchmarkScreen> createState() =>
      _ScrollStressBenchmarkScreenState();
}

class _ScrollStressBenchmarkScreenState
    extends State<ScrollStressBenchmarkScreen> {
  final ScrollController _scrollController = ScrollController();
  _Package _activePackage = _Package.fullSvgPicture;
  bool _isScrolling = false;
  List<BenchmarkMetrics> _results = [];

  static const int _itemCount = 200;
  static const String _iconPath = 'assets/simple/simple_icon.svg';

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Widget _buildItem(int index) {
    switch (_activePackage) {
      case _Package.fullSvgPicture:
        return ffsf.SvgPicture.asset(_iconPath, width: 48, height: 48);
      case _Package.fullSvgRaster:
        // TODO: pass renderingStrategy: RenderingStrategy.raster
        return ffsf.SvgPicture.asset(_iconPath, width: 48, height: 48);
      case _Package.flutterSvg:
        return fsvg.SvgPicture.asset(_iconPath, width: 48, height: 48);
    }
  }

  /// Programmatically scrolls the list from top to bottom and back.
  ///
  /// In integration_test mode the [BenchmarkRunner] drives the scroll via
  /// [WidgetTester.drag]. This manual path gives an on-device preview.
  Future<void> _runScrollBenchmark() async {
    if (_isScrolling) return;
    setState(() => _isScrolling = true);

    const scrollDuration = Duration(milliseconds: 3000);

    // Scroll to bottom
    await _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: scrollDuration,
      curve: Curves.linear,
    );

    // Scroll back to top
    await _scrollController.animateTo(
      0,
      duration: scrollDuration,
      curve: Curves.linear,
    );

    // NOTE: Real frame timing metrics require integration_test.
    // TODO: integrate MetricsCollector here when running under test harness.

    setState(() => _isScrolling = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scroll Stress Benchmark')),
      body: Column(
        children: [
          // Package selector
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                const Text('Package: '),
                DropdownButton<_Package>(
                  value: _activePackage,
                  onChanged: (v) => setState(() => _activePackage = v!),
                  items: _Package.values
                      .map((p) => DropdownMenuItem(
                          value: p, child: Text(p.label)))
                      .toList(),
                ),
                const Spacer(),
                if (_isScrolling)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              'Scenario: scroll_200_svg_items — $_itemCount items, auto-scroll x2',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: 4),

          // List
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: _itemCount,
              itemBuilder: (_, index) => ListTile(
                leading: _buildItem(index),
                title: Text('SVG item ${index + 1}'),
                subtitle: Text('path: $_iconPath'),
              ),
            ),
          ),

          // Results summary
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isScrolling ? null : _runScrollBenchmark,
        label: const Text('Scroll'),
        icon: const Icon(Icons.swap_vert),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Enum
// ---------------------------------------------------------------------------

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
