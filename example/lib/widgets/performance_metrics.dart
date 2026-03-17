import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Виджет для отображения метрик производительности в реальном времени
class PerformanceMetrics extends StatefulWidget {
  const PerformanceMetrics({
    super.key,
    required this.child,
    this.showOverlay = true,
  });

  final Widget child;
  final bool showOverlay;

  @override
  State<PerformanceMetrics> createState() => _PerformanceMetricsState();
}

class _PerformanceMetricsState extends State<PerformanceMetrics> {
  double _fps = 0.0;
  double _frameTime = 0.0;
  int _frameCount = 0;
  DateTime _lastTime = DateTime.now();
  final List<double> _frameTimes = [];
  static const int _maxSamples = 60;

  Timer? _updateTimer;

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addPostFrameCallback(_onFrame);
    _updateTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }

  void _onFrame(Duration timestamp) {
    if (!mounted) return;

    final now = DateTime.now();
    final elapsed = now.difference(_lastTime);

    if (elapsed.inMilliseconds > 0) {
      _frameCount++;

      // Вычисляем время одного кадра
      final frameTime = elapsed.inMicroseconds / 1000.0; // в миллисекундах
      _frameTimes.add(frameTime);

      // Ограничиваем количество сэмплов
      if (_frameTimes.length > _maxSamples) {
        _frameTimes.removeAt(0);
      }

      // Вычисляем средний FPS по последним кадрам
      if (_frameTimes.isNotEmpty) {
        final avgFrameTime =
            _frameTimes.reduce((a, b) => a + b) / _frameTimes.length;
        _fps = 1000.0 / avgFrameTime;
        _frameTime = avgFrameTime;
      }

      _lastTime = now;
    }

    // Продолжаем отслеживание
    SchedulerBinding.instance.addPostFrameCallback(_onFrame);
  }

  Color _getFpsColor(double fps) {
    if (fps >= 55) return Colors.green;
    if (fps >= 30) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.showOverlay) {
      return widget.child;
    }

    return Stack(
      children: [
        widget.child,
        Positioned(
          top: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _getFpsColor(_fps).withValues(alpha: 0.5),
                width: 2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.speed, color: _getFpsColor(_fps), size: 16),
                    const SizedBox(width: 4),
                    Text(
                      'FPS',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _fps.toStringAsFixed(1),
                  style: TextStyle(
                    color: _getFpsColor(_fps),
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    fontFeatures: const [ui.FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${_frameTime.toStringAsFixed(2)} ms',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 11,
                    fontFeatures: const [ui.FontFeature.tabularFigures()],
                  ),
                ),
                Text(
                  'Frames: $_frameCount',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 10,
                    fontFeatures: const [ui.FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Детальная панель метрик
class DetailedMetricsPanel extends StatelessWidget {
  const DetailedMetricsPanel({
    super.key,
    required this.fps,
    required this.frameTime,
    required this.frameCount,
    this.animationTime,
    this.totalDuration,
    this.progress,
    this.playbackRate,
    this.isPlaying,
  });

  final double fps;
  final double frameTime;
  final int frameCount;
  final Duration? animationTime;
  final Duration? totalDuration;
  final double? progress;
  final double? playbackRate;
  final bool? isPlaying;

  Color _getFpsColor(double fps) {
    if (fps >= 55) return Colors.green;
    if (fps >= 30) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Performance Metrics',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const Divider(height: 24),
            _buildMetricRow(
              'FPS',
              fps.toStringAsFixed(1),
              _getFpsColor(fps),
              Icons.speed,
            ),
            const SizedBox(height: 8),
            _buildMetricRow(
              'Frame Time',
              '${frameTime.toStringAsFixed(2)} ms',
              frameTime < 16.67 ? Colors.green : Colors.orange,
              Icons.timer,
            ),
            const SizedBox(height: 8),
            _buildMetricRow(
              'Frame Count',
              frameCount.toString(),
              Colors.blue,
              Icons.countertops,
            ),
            if (animationTime != null) ...[
              const Divider(height: 24),
              _buildMetricRow(
                'Animation Time',
                _formatDuration(animationTime!),
                Colors.purple,
                Icons.access_time,
              ),
            ],
            if (totalDuration != null) ...[
              const SizedBox(height: 8),
              _buildMetricRow(
                'Total Duration',
                _formatDuration(totalDuration!),
                Colors.indigo,
                Icons.schedule,
              ),
            ],
            if (progress != null) ...[
              const SizedBox(height: 8),
              _buildMetricRow(
                'Progress',
                '${(progress! * 100).toStringAsFixed(1)}%',
                Colors.teal,
                Icons.percent,
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.grey[300],
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.teal),
              ),
            ],
            if (playbackRate != null) ...[
              const SizedBox(height: 8),
              _buildMetricRow(
                'Playback Rate',
                '${playbackRate!.toStringAsFixed(2)}x',
                Colors.cyan,
                Icons.fast_forward,
              ),
            ],
            if (isPlaying != null) ...[
              const SizedBox(height: 8),
              _buildMetricRow(
                'Status',
                isPlaying! ? 'Playing' : 'Paused',
                isPlaying! ? Colors.green : Colors.grey,
                isPlaying! ? Icons.play_arrow : Icons.pause,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMetricRow(
    String label,
    String value,
    Color color,
    IconData icon,
  ) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(fontSize: 14, color: Colors.grey[700]),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
            fontFeatures: const [ui.FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    final seconds = duration.inMilliseconds / 1000.0;
    return '${seconds.toStringAsFixed(2)}s';
  }
}
