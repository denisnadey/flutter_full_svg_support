// ignore_for_file: implementation_imports
import 'package:flutter/material.dart';
import 'package:full_svg_flutter/src/animation.dart';

/// Demo page for AnimatedSvgController
///
/// Demonstrates programmatic animation control:
/// - Play/Pause
/// - Seek slider
/// - Playback rate control
/// - Restart
class ControllerDemoPage extends StatefulWidget {
  const ControllerDemoPage({super.key});

  @override
  State<ControllerDemoPage> createState() => _ControllerDemoPageState();
}

class _ControllerDemoPageState extends State<ControllerDemoPage> {
  final _controller = AnimatedSvgController();
  double _seekValue = 0.0;
  final double _animationDuration = 2.0; // 2 seconds

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _playbackRateLabel {
    final rate = _controller.playbackRate;
    if (rate == 0.5) return '0.5x';
    if (rate == 1.0) return '1x';
    if (rate == 1.5) return '1.5x';
    if (rate == 2.0) return '2x';
    return '${rate.toStringAsFixed(1)}x';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AnimatedSvgController Demo'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          // SVG Animation
          Expanded(
            flex: 3,
            child: Center(
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: AnimatedSvgPicture.string(
                  _demoSvg,
                  controller: _controller,
                ),
              ),
            ),
          ),

          // Controls
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Play/Pause button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton.filled(
                        onPressed: () {
                          setState(() {
                            _controller.togglePlayPause();
                          });
                        },
                        icon: Icon(
                          _controller.isPaused ? Icons.play_arrow : Icons.pause,
                        ),
                        iconSize: 32,
                      ),
                      const SizedBox(width: 16),
                      IconButton.outlined(
                        onPressed: () {
                          setState(() {
                            _controller.restart();
                            _seekValue = 0.0;
                          });
                        },
                        icon: const Icon(Icons.replay),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Seek slider
                  Row(
                    children: [
                      const Text('Seek:'),
                      Expanded(
                        child: Slider(
                          value: _seekValue,
                          min: 0,
                          max: _animationDuration,
                          divisions: 20,
                          label: '${_seekValue.toStringAsFixed(1)}s',
                          onChanged: (value) {
                            setState(() {
                              _seekValue = value;
                              _controller.seek(
                                Duration(milliseconds: (value * 1000).toInt()),
                              );
                            });
                          },
                        ),
                      ),
                      Text('${_seekValue.toStringAsFixed(1)}s'),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Playback rate control
                  Row(
                    children: [
                      const Text('Speed:'),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Wrap(
                          spacing: 8,
                          children: [
                            for (final rate in [0.5, 1.0, 1.5, 2.0])
                              ChoiceChip(
                                label: Text('${rate}x'),
                                selected: _controller.playbackRate == rate,
                                onSelected: (selected) {
                                  if (selected) {
                                    setState(() {
                                      _controller.setPlaybackRate(rate);
                                    });
                                  }
                                },
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const Spacer(),

                  // Info
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Controller State:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Status: ${_controller.isPaused ? "Paused" : "Playing"}',
                        ),
                        Text('Speed: $_playbackRateLabel'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static const _demoSvg = '''
<svg viewBox="0 0 200 200" xmlns="http://www.w3.org/2000/svg">
  <!-- Background -->
  <rect width="200" height="200" fill="#f0f0f0"/>
  
  <!-- Moving circle -->
  <circle cx="20" cy="100" r="15" fill="#2196F3">
    <animate attributeName="cx" 
             from="20" to="180" 
             dur="2s" 
             repeatCount="indefinite"/>
  </circle>
  
  <!-- Pulsing circle -->
  <circle cx="100" cy="100" r="10" fill="#FF9800" opacity="0.7">
    <animate attributeName="r" 
             values="10;30;10" 
             dur="2s" 
             repeatCount="indefinite"/>
  </circle>
  
  <!-- Rotating square -->
  <rect x="80" y="30" width="40" height="40" fill="#4CAF50">
    <animateTransform attributeName="transform"
                      type="rotate"
                      from="0 100 50"
                      to="360 100 50"
                      dur="2s"
                      repeatCount="indefinite"/>
  </rect>
  
  <!-- Color changing circle -->
  <circle cx="100" cy="160" r="12">
    <animate attributeName="fill" 
             values="#E91E63;#9C27B0;#3F51B5;#E91E63" 
             dur="2s" 
             repeatCount="indefinite"/>
  </circle>
</svg>
''';
}
