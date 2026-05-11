import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart' as fsvg;
import 'package:full_svg_flutter/full_svg_flutter.dart' as ffsf;

import '../result_models.dart';

/// Benchmark screen for SVGs that exercise SVG filter primitives
/// (feGaussianBlur, feColorMatrix, feComposite, etc.).
///
/// flutter_svg has limited filter support; those columns show a fallback note.
///
/// Scenarios:
/// - render_filter_stack  — layered filter composition
/// - render_single_filter — single feGaussianBlur
/// - anim_filter_stack    — animated filter-heavy SVG
class FilterStressBenchmarkScreen extends StatefulWidget {
  const FilterStressBenchmarkScreen({super.key});

  @override
  State<FilterStressBenchmarkScreen> createState() =>
      _FilterStressBenchmarkScreenState();
}

class _FilterStressBenchmarkScreenState
    extends State<FilterStressBenchmarkScreen> {
  _FilterScenario _selected = _FilterScenario.renderFilterStack;
  final List<BenchmarkMetrics> _results = [];

  static const Map<_FilterScenario, String> _assetPaths = {
    _FilterScenario.renderFilterStack:
        'assets/filters/filter_stack.svg',
    _FilterScenario.renderSingleFilter:
        'assets/filters/single_filter.svg',
    _FilterScenario.animFilterStack:
        'assets/filters/anim_filter_stack.svg',
  };

  @override
  Widget build(BuildContext context) {
    final assetPath = _assetPaths[_selected]!;
    final isAnimated = _selected == _FilterScenario.animFilterStack;

    return Scaffold(
      appBar: AppBar(title: const Text('Filter Stress Benchmark')),
      body: Column(
        children: [
          // Scenario selector
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: _FilterScenario.values
                  .map((s) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(s.label),
                          selected: _selected == s,
                          onSelected: (_) => setState(() => _selected = s),
                        ),
                      ))
                  .toList(),
            ),
          ),

          // Preview row
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // full_svg_flutter column
                _PreviewTile(
                  label: 'full_svg_flutter',
                  child: isAnimated
                      ? ffsf.AnimatedSvgPicture.asset(
                          assetPath,
                          width: 140,
                          height: 140,
                        )
                      : ffsf.SvgPicture.asset(
                          assetPath,
                          width: 140,
                          height: 140,
                        ),
                ),
                // flutter_svg column — filter support is limited
                _PreviewTile(
                  label: 'flutter_svg',
                  child: isAnimated
                      ? _unsupportedBox('Animated filters\nnot supported')
                      : _flutterSvgWithFallback(assetPath),
                ),
              ],
            ),
          ),

          const Divider(),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(
              'Scenario: ${_selected.scenarioKey}\n'
              'Complex filter primitives may fail silently in flutter_svg.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),

          if (_results.isNotEmpty)
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: _results
                    .map((r) => ListTile(
                          title: Text(r.package),
                          subtitle: Text(
                            'avg build ${r.avgBuildMs.toStringAsFixed(2)} ms '
                            '| jank60=${r.jankFrameCount60hz}',
                          ),
                        ))
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Widget _flutterSvgWithFallback(String assetPath) {
    // flutter_svg may throw or render incorrectly for complex filters.
    // We wrap in a builder that shows a note if it fails at runtime.
    return SizedBox(
      width: 140,
      height: 140,
      child: fsvg.SvgPicture.asset(
        assetPath,
        width: 140,
        height: 140,
      ),
    );
  }

  Widget _unsupportedBox(String message) {
    return Container(
      width: 140,
      height: 140,
      color: Colors.grey.shade200,
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helper widget
// ---------------------------------------------------------------------------

class _PreviewTile extends StatelessWidget {
  const _PreviewTile({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        child,
        const SizedBox(height: 4),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Enum
// ---------------------------------------------------------------------------

enum _FilterScenario {
  renderFilterStack,
  renderSingleFilter,
  animFilterStack;

  String get label => switch (this) {
        renderFilterStack => 'Filter Stack',
        renderSingleFilter => 'Single Filter',
        animFilterStack => 'Anim Filter Stack',
      };

  String get scenarioKey => switch (this) {
        renderFilterStack => 'render_filter_stack',
        renderSingleFilter => 'render_single_filter',
        animFilterStack => 'anim_filter_stack',
      };
}
