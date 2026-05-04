import 'package:flutter/material.dart';
import 'package:full_svg_flutter/full_svg_flutter.dart' as ffsf;

import '../result_models.dart';

/// Benchmark screen for SMIL / CSS-animation SVGs.
///
/// flutter_svg does NOT support SMIL animations, CSS @keyframes, path
/// morphing, or advanced filters — those columns show a static note.
///
/// Scenarios:
/// - anim_spinner_smil
/// - anim_dash_heartbeat
/// - anim_path_morph
/// - anim_transform_matrix
/// - anim_motion_path
/// - anim_css_keyframes
class AnimatedSvgBenchmarkScreen extends StatefulWidget {
  const AnimatedSvgBenchmarkScreen({super.key});

  @override
  State<AnimatedSvgBenchmarkScreen> createState() =>
      _AnimatedSvgBenchmarkScreenState();
}

class _AnimatedSvgBenchmarkScreenState
    extends State<AnimatedSvgBenchmarkScreen> {
  _AnimScenario _selected = _AnimScenario.spinnerSmil;
  ffsf.AnimatedSvgController? _controller;
  List<BenchmarkMetrics> _results = [];

  static const Map<_AnimScenario, String> _assetPaths = {
    _AnimScenario.spinnerSmil: 'assets/animated/spinner_smil.svg',
    _AnimScenario.dashHeartbeat: 'assets/animated/dash_heartbeat.svg',
    _AnimScenario.pathMorph: 'assets/animated/path_morph.svg',
    _AnimScenario.transformMatrix: 'assets/animated/transform_matrix.svg',
    _AnimScenario.motionPath: 'assets/animated/motion_path.svg',
    _AnimScenario.cssKeyframes: 'assets/animated/css_keyframes.svg',
  };

  @override
  void initState() {
    super.initState();
    _controller = ffsf.AnimatedSvgController();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final assetPath = _assetPaths[_selected]!;

    return Scaffold(
      appBar: AppBar(title: const Text('Animated SVG Benchmark')),
      body: Column(
        children: [
          // Scenario picker
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: _AnimScenario.values
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
                _AnimPreviewTile(
                  label: 'full_svg_flutter',
                  child: ffsf.AnimatedSvgPicture.asset(
                    assetPath,
                    controller: _controller,
                    width: 120,
                    height: 120,
                  ),
                ),
                // flutter_svg column — not supported
                _AnimPreviewTile(
                  label: 'flutter_svg',
                  child: Container(
                    width: 120,
                    height: 120,
                    color: Colors.grey.shade200,
                    child: const Center(
                      child: Text(
                        'Not supported',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Playback controls
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.play_arrow),
                onPressed: () => _controller?.resume(),
                tooltip: 'Play',
              ),
              IconButton(
                icon: const Icon(Icons.pause),
                onPressed: () => _controller?.pause(),
                tooltip: 'Pause',
              ),
              IconButton(
                icon: const Icon(Icons.replay),
                onPressed: () => _controller?.seek(Duration.zero),
                tooltip: 'Rewind',
              ),
              const SizedBox(width: 16),
              const Text('Rate:'),
              _RateButton(label: '0.5×', rate: 0.5, controller: _controller),
              _RateButton(label: '1×', rate: 1.0, controller: _controller),
              _RateButton(label: '2×', rate: 2.0, controller: _controller),
            ],
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
}

// ---------------------------------------------------------------------------
// Helper widgets
// ---------------------------------------------------------------------------

class _AnimPreviewTile extends StatelessWidget {
  const _AnimPreviewTile({required this.label, required this.child});
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

class _RateButton extends StatelessWidget {
  const _RateButton({
    required this.label,
    required this.rate,
    required this.controller,
  });
  final String label;
  final double rate;
  final ffsf.AnimatedSvgController? controller;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () => controller?.setPlaybackRate(rate),
      child: Text(label),
    );
  }
}

// ---------------------------------------------------------------------------
// Enum
// ---------------------------------------------------------------------------

enum _AnimScenario {
  spinnerSmil,
  dashHeartbeat,
  pathMorph,
  transformMatrix,
  motionPath,
  cssKeyframes;

  String get label => switch (this) {
        spinnerSmil => 'Spinner SMIL',
        dashHeartbeat => 'Dash Heartbeat',
        pathMorph => 'Path Morph',
        transformMatrix => 'Transform Matrix',
        motionPath => 'Motion Path',
        cssKeyframes => 'CSS Keyframes',
      };

  String get scenarioKey => switch (this) {
        spinnerSmil => 'anim_spinner_smil',
        dashHeartbeat => 'anim_dash_heartbeat',
        pathMorph => 'anim_path_morph',
        transformMatrix => 'anim_transform_matrix',
        motionPath => 'anim_motion_path',
        cssKeyframes => 'anim_css_keyframes',
      };
}
