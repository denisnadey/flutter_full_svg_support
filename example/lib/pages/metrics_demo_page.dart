import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:full_svg_flutter/src/animation/animated_svg_picture.dart';

import '../l10n/app_localizations.dart';
import '../widgets/performance_metrics.dart';

class MetricsDemoPage extends StatefulWidget {
  const MetricsDemoPage({super.key});

  @override
  State<MetricsDemoPage> createState() => _MetricsDemoPageState();
}

class _MetricsDemoPageState extends State<MetricsDemoPage>
    with SingleTickerProviderStateMixin {
  // FPS tracking
  double _fps = 0.0;
  double _frameTime = 0.0;
  int _frameCount = 0;
  DateTime _lastTime = DateTime.now();
  final List<double> _frameTimes = [];
  static const int _maxSamples = 60;

  // Animation tracking
  Duration _animationTime = Duration.zero;
  final Duration _totalDuration = const Duration(seconds: 4);
  double _progress = 0.0;
  double _playbackRate = 1.0;
  bool _isPlaying = true;
  bool _showMetricsOverlay = true;

  Timer? _updateTimer;
  AnimationController? _animationController;

  // SVG примеры
  int _currentExample = 0;
  final List<String> _svgExamples = [
    // Rotation
    '''<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
      <rect x="40" y="40" width="20" height="20" fill="#4CAF50">
        <animateTransform
          attributeName="transform"
          type="rotate"
          from="0 50 50"
          to="360 50 50"
          dur="4s"
          repeatCount="indefinite"/>
      </rect>
    </svg>''',
    // Translation
    '''<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
      <circle cx="10" cy="50" r="8" fill="#2196F3">
        <animate attributeName="cx" from="10" to="90" dur="4s" repeatCount="indefinite"/>
      </circle>
    </svg>''',
    // Scale
    '''<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
      <rect x="40" y="40" width="20" height="20" fill="#FF9800">
        <animateTransform
          attributeName="transform"
          type="scale"
          from="0.5"
          to="2"
          dur="4s"
          repeatCount="indefinite"
          additive="sum"/>
      </rect>
    </svg>''',
    // Combined
    '''<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
      <rect x="40" y="40" width="20" height="20" fill="#E91E63">
        <animateTransform
          attributeName="transform"
          type="rotate"
          from="0 50 50"
          to="360 50 50"
          dur="4s"
          repeatCount="indefinite"/>
        <animate attributeName="opacity" from="0.3" to="1" dur="2s" repeatCount="indefinite"/>
      </rect>
    </svg>''',
  ];

  final List<String> _exampleNames = [
    'Rotation',
    'Translation',
    'Scale',
    'Combined',
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: _totalDuration,
    )..repeat();

    _animationController!.addListener(_updateAnimationMetrics);

    SchedulerBinding.instance.addPostFrameCallback(_onFrame);
    _updateTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    _animationController?.dispose();
    super.dispose();
  }

  void _onFrame(Duration timestamp) {
    if (!mounted) return;

    final now = DateTime.now();
    final elapsed = now.difference(_lastTime);

    if (elapsed.inMilliseconds > 0) {
      _frameCount++;

      final frameTime = elapsed.inMicroseconds / 1000.0;
      _frameTimes.add(frameTime);

      if (_frameTimes.length > _maxSamples) {
        _frameTimes.removeAt(0);
      }

      if (_frameTimes.isNotEmpty) {
        final avgFrameTime =
            _frameTimes.reduce((a, b) => a + b) / _frameTimes.length;
        _fps = 1000.0 / avgFrameTime;
        _frameTime = avgFrameTime;
      }

      _lastTime = now;
    }

    SchedulerBinding.instance.addPostFrameCallback(_onFrame);
  }

  void _updateAnimationMetrics() {
    if (!mounted) return;
    final value = _animationController!.value;
    _animationTime = Duration(
      milliseconds: (value * _totalDuration.inMilliseconds).round(),
    );
    _progress = value;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.metricsTitle),
        actions: [
          IconButton(
            icon: Icon(
              _showMetricsOverlay ? Icons.visibility : Icons.visibility_off,
            ),
            tooltip: 'Toggle metrics overlay',
            onPressed: () {
              setState(() {
                _showMetricsOverlay = !_showMetricsOverlay;
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // SVG Display
          Expanded(
            flex: 2,
            child: PerformanceMetrics(
              showOverlay: _showMetricsOverlay,
              child: Container(
                color: Colors.grey[100],
                child: Center(
                  child: AnimatedSvgPicture.string(
                    key: ValueKey(_currentExample),
                    _svgExamples[_currentExample],
                    width: 300,
                    height: 300,
                    autoPlay: _isPlaying,
                    playbackRate: _playbackRate,
                  ),
                ),
              ),
            ),
          ),

          // Example selector
          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.grey[200],
            child: Row(
              children: [
                const Text('Example: '),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: List.generate(_svgExamples.length, (index) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: ChoiceChip(
                            label: Text(_exampleNames[index]),
                            selected: _currentExample == index,
                            onSelected: (selected) {
                              if (selected) {
                                setState(() {
                                  _currentExample = index;
                                });
                              }
                            },
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Metrics Panel
          Expanded(
            flex: 3,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Detailed Metrics
                  DetailedMetricsPanel(
                    fps: _fps,
                    frameTime: _frameTime,
                    frameCount: _frameCount,
                    animationTime: _animationTime,
                    totalDuration: _totalDuration,
                    progress: _progress,
                    playbackRate: _playbackRate,
                    isPlaying: _isPlaying,
                  ),

                  const SizedBox(height: 16),

                  // Controls
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Controls',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),

                          // Play/Pause
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      _isPlaying = !_isPlaying;
                                      if (_isPlaying) {
                                        _animationController?.repeat();
                                      } else {
                                        _animationController?.stop();
                                      }
                                    });
                                  },
                                  icon: Icon(
                                    _isPlaying ? Icons.pause : Icons.play_arrow,
                                  ),
                                  label: Text(
                                    _isPlaying ? l10n.pause : l10n.play,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      _animationController?.reset();
                                      if (_isPlaying) {
                                        _animationController?.repeat();
                                      }
                                    });
                                  },
                                  icon: const Icon(Icons.restart_alt),
                                  label: Text(l10n.restart),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // Playback Rate
                          Text(
                            '${l10n.playbackRate}: ${_playbackRate.toStringAsFixed(2)}x',
                          ),
                          Slider(
                            value: _playbackRate,
                            min: 0.1,
                            max: 3.0,
                            divisions: 29,
                            label: '${_playbackRate.toStringAsFixed(1)}x',
                            onChanged: (value) {
                              setState(() {
                                _playbackRate = value;
                                _animationController?.duration = Duration(
                                  milliseconds:
                                      (_totalDuration.inMilliseconds /
                                              _playbackRate)
                                          .round(),
                                );
                              });
                            },
                          ),
                        ],
                      ),
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
}
