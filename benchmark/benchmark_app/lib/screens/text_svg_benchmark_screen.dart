import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart' as fsvg;
import 'package:full_svg_flutter/full_svg_flutter.dart' as ffsf;

import '../result_models.dart';

/// Benchmark screen for SVGs containing text elements.
///
/// Scenarios:
/// - render_text_path    — text on a curved path (textPath element)
/// - render_complex_text — multi-style, multi-language text block
class TextSvgBenchmarkScreen extends StatefulWidget {
  const TextSvgBenchmarkScreen({super.key});

  @override
  State<TextSvgBenchmarkScreen> createState() =>
      _TextSvgBenchmarkScreenState();
}

class _TextSvgBenchmarkScreenState extends State<TextSvgBenchmarkScreen> {
  _TextScenario _selected = _TextScenario.textPath;
  List<BenchmarkMetrics> _results = [];

  static const Map<_TextScenario, String> _assetPaths = {
    _TextScenario.textPath: 'assets/text/text_path.svg',
    _TextScenario.complexText: 'assets/text/complex_text.svg',
  };

  @override
  Widget build(BuildContext context) {
    final assetPath = _assetPaths[_selected]!;

    return Scaffold(
      appBar: AppBar(title: const Text('Text SVG Benchmark')),
      body: Column(
        children: [
          // Scenario picker
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: _TextScenario.values
                  .map((s) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ChoiceChip(
                          label: Text(s.label),
                          selected: _selected == s,
                          onSelected: (_) => setState(() => _selected = s),
                        ),
                      ))
                  .toList(),
            ),
          ),

          // Preview row — full_svg_flutter vs flutter_svg
          Expanded(
            child: Row(
              children: [
                // full_svg_flutter
                Expanded(
                  child: _PackageTile(
                    packageLabel: 'full_svg_flutter',
                    child: ffsf.SvgPicture.asset(
                      assetPath,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                // flutter_svg — text support varies
                Expanded(
                  child: _PackageTile(
                    packageLabel: 'flutter_svg',
                    child: fsvg.SvgPicture.asset(
                      assetPath,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(),

          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              'Scenario: ${_selected.scenarioKey}\n'
              'For frame timings run integration_test/benchmark_test.dart',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),

          if (_results.isNotEmpty)
            Container(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _results
                    .map((r) => Text(
                          '${r.package}: avg ${r.avgBuildMs.toStringAsFixed(2)} ms',
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
// Helper widget
// ---------------------------------------------------------------------------

class _PackageTile extends StatelessWidget {
  const _PackageTile({required this.packageLabel, required this.child});
  final String packageLabel;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: child,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            packageLabel,
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Enum
// ---------------------------------------------------------------------------

enum _TextScenario {
  textPath,
  complexText;

  String get label => switch (this) {
        textPath => 'Text on Path',
        complexText => 'Complex Text',
      };

  String get scenarioKey => switch (this) {
        textPath => 'render_text_path',
        complexText => 'render_complex_text',
      };
}
