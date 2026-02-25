import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/src/animation.dart';

/// Страница для визуальной верификации анимации astronaut helmet SVG.
/// Демонстрирует:
/// - stroke-dashoffset анимация
/// - stop-color CSS анимация на gradient stops
/// - Per-keyframe animation-timing-function
/// - Compound CSS transform decomposition (SVGator-style)
class AstronautHelmetPage extends StatefulWidget {
  const AstronautHelmetPage({super.key});

  @override
  State<AstronautHelmetPage> createState() => _AstronautHelmetPageState();
}

class _AstronautHelmetPageState extends State<AstronautHelmetPage> {
  double _playbackRate = 1.0;
  bool _isPlaying = true;
  String? _svgString;
  String? _loadError;
  final AnimatedSvgController _controller = AnimatedSvgController();

  static const _rates = [0.25, 0.5, 1.0, 2.0];

  @override
  void initState() {
    super.initState();
    _loadSvg();
  }

  Future<void> _loadSvg() async {
    try {
      final svg = await rootBundle.loadString('assets/astronaut_helmet.svg');
      if (mounted) setState(() => _svgString = svg);
    } catch (e) {
      if (mounted) setState(() => _loadError = e.toString());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildViewer() {
    if (_loadError != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Failed to load SVG:\n$_loadError',
          style: const TextStyle(color: Colors.redAccent),
          textAlign: TextAlign.center,
        ),
      );
    }
    if (_svgString == null) {
      return const CircularProgressIndicator(color: Colors.tealAccent);
    }
    return AnimatedSvgPicture.string(
      _svgString!,
      controller: _controller,
      playbackRate: _playbackRate,
      fit: BoxFit.contain,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111827),
        foregroundColor: Colors.white,
        title: const Text('Astronaut Helmet Animation'),
      ),
      body: Column(
        children: [
          // SVG viewer
          Expanded(flex: 3, child: Center(child: _buildViewer())),

          // Controls
          Container(
            color: const Color(0xFF111827),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Play / Pause / Reset
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.replay, color: Colors.white),
                      tooltip: 'Reset',
                      onPressed: () {
                        _controller.restart();
                        setState(() => _isPlaying = true);
                      },
                    ),
                    const SizedBox(width: 16),
                    FloatingActionButton(
                      backgroundColor: Colors.tealAccent.shade400,
                      foregroundColor: Colors.black,
                      onPressed: () {
                        setState(() {
                          _isPlaying = !_isPlaying;
                          if (_isPlaying) {
                            _controller.resume();
                          } else {
                            _controller.pause();
                          }
                        });
                      },
                      child: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                    ),
                    const SizedBox(width: 16),
                    // Rate chips
                    for (final r in _rates)
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: ChoiceChip(
                          label: Text('${r}x'),
                          selected: _playbackRate == r,
                          onSelected: (_) {
                            setState(() => _playbackRate = r);
                            _controller.setPlaybackRate(r);
                          },
                          selectedColor: Colors.tealAccent.shade700,
                          labelStyle: TextStyle(
                            color: _playbackRate == r
                                ? Colors.black
                                : Colors.white70,
                            fontSize: 12,
                          ),
                          backgroundColor: const Color(0xFF1F2937),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),

                // Feature badges
                const Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  alignment: WrapAlignment.center,
                  children: [
                    _FeatureBadge('stroke-dashoffset', Colors.cyanAccent),
                    _FeatureBadge('stop-color anim', Colors.purpleAccent),
                    _FeatureBadge('per-kf timing', Colors.greenAccent),
                    _FeatureBadge('compound transform', Colors.orangeAccent),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _FeatureBadge(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
