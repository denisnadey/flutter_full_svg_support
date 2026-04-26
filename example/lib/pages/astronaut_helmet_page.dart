// ignore_for_file: implementation_imports
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:full_svg_flutter/src/animation.dart';

/// Page for visual verification of astronaut helmet SVG animation.
/// Demonstrates:
/// - stroke-dashoffset animation
/// - stop-color CSS animation on gradient stops
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
      return _buildErrorWidget();
    }
    if (_svgString == null) {
      return _buildLoadingWidget();
    }
    return AnimatedSvgPicture.string(
      _svgString!,
      controller: _controller,
      playbackRate: _playbackRate,
      fit: BoxFit.contain,
    );
  }

  Widget _buildLoadingWidget() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.tealAccent.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const CircularProgressIndicator(
            color: Colors.tealAccent,
            strokeWidth: 3,
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Loading animation...',
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.redAccent.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.error_outline,
              color: Colors.redAccent,
              size: 48,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Failed to load SVG',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _loadError ?? 'Unknown error',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () {
              setState(() {
                _loadError = null;
                _svgString = null;
              });
              _loadSvg();
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.tealAccent.shade700,
              foregroundColor: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111827),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.tealAccent.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.rocket_launch,
                size: 18,
                color: Colors.tealAccent,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Astronaut Helmet',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // SVG viewer with gradient background
          Expanded(
            flex: 3,
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.2,
                  colors: [Color(0xFF1a2040), Color(0xFF0A0E1A)],
                ),
              ),
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(isMobile ? 16 : 32),
                  child: _buildViewer(),
                ),
              ),
            ),
          ),

          // Controls panel
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF111827),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            padding: EdgeInsets.symmetric(
              vertical: isMobile ? 16 : 20,
              horizontal: isMobile ? 16 : 32,
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle indicator
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Main playback controls
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Reset button
                      _buildControlButton(
                        icon: Icons.replay,
                        label: 'Reset',
                        onTap: () {
                          _controller.restart();
                          setState(() => _isPlaying = true);
                        },
                        isMobile: isMobile,
                      ),
                      SizedBox(width: isMobile ? 16 : 24),

                      // Play/Pause main button
                      _buildPlayPauseButton(isMobile),
                      SizedBox(width: isMobile ? 16 : 24),

                      // Speed control
                      _buildSpeedSelector(isMobile),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Feature badges
                  const Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      _FeatureBadge('stroke-dashoffset', Colors.cyanAccent),
                      _FeatureBadge('stop-color', Colors.purpleAccent),
                      _FeatureBadge('per-kf timing', Colors.greenAccent),
                      _FeatureBadge('transform', Colors.orangeAccent),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isMobile,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 12 : 16,
            vertical: isMobile ? 10 : 12,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF1F2937),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white70, size: isMobile ? 20 : 24),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: isMobile ? 10 : 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlayPauseButton(bool isMobile) {
    final size = isMobile ? 56.0 : 64.0;
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.tealAccent.withValues(alpha: 0.4),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Material(
        color: Colors.tealAccent.shade400,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: () {
            setState(() {
              _isPlaying = !_isPlaying;
              if (_isPlaying) {
                _controller.resume();
              } else {
                _controller.pause();
              }
            });
          },
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(
              _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: Colors.black,
              size: isMobile ? 28 : 32,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSpeedSelector(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 6 : 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2937),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Speed',
            style: TextStyle(
              color: Colors.white54,
              fontSize: isMobile ? 10 : 11,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: _rates.map((rate) {
              final isSelected = _playbackRate == rate;
              return GestureDetector(
                onTap: () {
                  setState(() => _playbackRate = rate);
                  _controller.setPlaybackRate(rate);
                },
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 8 : 10,
                    vertical: isMobile ? 4 : 6,
                  ),
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.tealAccent.shade700
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${rate}x',
                    style: TextStyle(
                      color: isSelected ? Colors.black : Colors.white54,
                      fontSize: isMobile ? 11 : 12,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }).toList(),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
