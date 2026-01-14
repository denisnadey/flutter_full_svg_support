import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'dart:ui' as ui;

import '../widgets/animation_theme.dart';
import '../widgets/path_morphing_widget.dart';
import '../widgets/metrics_widget.dart';
import '../widgets/smil_path_morphing_widget.dart';
import '../widgets/smil_animate_motion_widget.dart';
import '../widgets/smil_syncbase_widget.dart';
import '../widgets/smil_event_timing_widget.dart';
import '../animated_svg_demo.dart';

/// Unified examples page with tabs and FPS monitor
class UnifiedExamplesPage extends StatefulWidget {
  const UnifiedExamplesPage({super.key});

  @override
  State<UnifiedExamplesPage> createState() => _UnifiedExamplesPageState();
}

class _UnifiedExamplesPageState extends State<UnifiedExamplesPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _showFPS = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 8, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'SMIL Animation Examples',
          style: TextStyle(fontSize: isMobile ? 18 : null),
        ),
        actions: [
          // FPS Toggle
          IconButton(
            icon: Icon(_showFPS ? Icons.speed : Icons.speed_outlined),
            tooltip: _showFPS ? 'Hide FPS' : 'Show FPS',
            onPressed: () {
              setState(() {
                _showFPS = !_showFPS;
              });
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelPadding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16),
            indicatorSize: TabBarIndicatorSize.label,
            tabs: [
              Tab(
                icon: Icon(Icons.animation, size: isMobile ? 20 : 24),
                text: isMobile ? 'SMIL' : 'SMIL Animations',
                height: 48,
              ),
              Tab(
                icon: Icon(Icons.auto_fix_high, size: isMobile ? 20 : 24),
                text: isMobile ? 'Morph' : 'Path Morphing',
                height: 48,
              ),
              Tab(
                icon: Icon(Icons.transform, size: isMobile ? 20 : 24),
                text: 'SMIL Path',
                height: 48,
              ),
              Tab(
                icon: Icon(Icons.directions, size: isMobile ? 20 : 24),
                text: 'Motion',
                height: 48,
              ),
              Tab(
                icon: Icon(Icons.sync, size: isMobile ? 20 : 24),
                text: 'Syncbase',
                height: 48,
              ),
              Tab(
                icon: Icon(Icons.touch_app, size: isMobile ? 20 : 24),
                text: 'Events',
                height: 48,
              ),
              Tab(
                icon: Icon(Icons.touch_app, size: isMobile ? 20 : 24),
                text: 'Events',
                height: 48,
              ),
              Tab(
                icon: Icon(Icons.show_chart, size: isMobile ? 20 : 24),
                text: isMobile ? 'Stats' : 'Metrics',
                height: 48,
              ),
              Tab(
                icon: Icon(Icons.format_shapes, size: isMobile ? 20 : 24),
                text: 'Custom',
                height: 48,
              ),
            ],
          ),
        ),
      ),
      body: Stack(
        children: [
          TabBarView(
            controller: _tabController,
            children: [
              _SMILExamplesTab(showFPS: _showFPS),
              _PathMorphingTab(showFPS: _showFPS),
              _SMILPathMorphingTab(showFPS: _showFPS),
              _AnimateMotionTab(showFPS: _showFPS),
              _SyncbaseTab(showFPS: _showFPS),
              _EventTimingTab(showFPS: _showFPS),
              _MetricsTab(showFPS: _showFPS),
              _CustomTab(showFPS: _showFPS),
            ],
          ),
          if (_showFPS) Positioned(top: 8, right: 8, child: const FPSMonitor()),
        ],
      ),
    );
  }
}

/// FPS Monitor Widget
class FPSMonitor extends StatefulWidget {
  const FPSMonitor({super.key});

  @override
  State<FPSMonitor> createState() => _FPSMonitorState();
}

class _FPSMonitorState extends State<FPSMonitor> {
  final List<double> _fpsHistory = [];
  Duration _lastFrameTime = Duration.zero;
  int _frameCount = 0;

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addPostFrameCallback(_onFrame);
  }

  void _onFrame(Duration timestamp) {
    if (!mounted) return;

    if (_lastFrameTime != Duration.zero) {
      final delta = timestamp - _lastFrameTime;
      if (delta.inMicroseconds > 0) {
        final fps = 1000000 / delta.inMicroseconds;
        setState(() {
          _fpsHistory.add(fps);
          if (_fpsHistory.length > 60) {
            _fpsHistory.removeAt(0);
          }
          _frameCount++;
        });
      }
    }
    _lastFrameTime = timestamp;
    SchedulerBinding.instance.addPostFrameCallback(_onFrame);
  }

  @override
  Widget build(BuildContext context) {
    final avgFPS = _fpsHistory.isEmpty
        ? 0.0
        : _fpsHistory.reduce((a, b) => a + b) / _fpsHistory.length;

    Color fpsColor;
    if (avgFPS >= 55) {
      fpsColor = Colors.green;
    } else if (avgFPS >= 30) {
      fpsColor = Colors.orange;
    } else {
      fpsColor = Colors.red;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AnimationTheme.spacingMedium,
        vertical: AnimationTheme.spacingSmall,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(AnimationTheme.radiusSmall),
        border: Border.all(color: fpsColor, width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.speed, color: fpsColor, size: 16),
              const SizedBox(width: AnimationTheme.spacingSmall),
              Text(
                '${avgFPS.toStringAsFixed(1)} FPS',
                style: TextStyle(
                  color: fpsColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: 120,
            height: 30,
            child: CustomPaint(
              painter: _FPSGraphPainter(_fpsHistory, fpsColor),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Frame: $_frameCount',
            style: const TextStyle(color: Colors.white70, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _FPSGraphPainter extends CustomPainter {
  _FPSGraphPainter(this.history, this.color);

  final List<double> history;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (history.isEmpty) return;

    final paint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;

    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final path = ui.Path();
    final linePath = ui.Path();

    final maxFPS = 60.0;
    final stepX = size.width / (history.length - 1).clamp(1, double.infinity);

    for (int i = 0; i < history.length; i++) {
      final x = i * stepX;
      final y =
          size.height -
          (history[i] / maxFPS * size.height).clamp(0, size.height);

      if (i == 0) {
        path.moveTo(x, size.height);
        path.lineTo(x, y);
        linePath.moveTo(x, y);
      } else {
        path.lineTo(x, y);
        linePath.lineTo(x, y);
      }
    }

    path.lineTo(size.width, size.height);
    path.close();

    canvas.drawPath(path, paint);
    canvas.drawPath(linePath, linePaint);

    // Draw 60 FPS line
    final targetLinePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(0, 0), Offset(size.width, 0), targetLinePaint);
  }

  @override
  bool shouldRepaint(_FPSGraphPainter oldDelegate) => true;
}

/// SMIL Animations Tab
class _SMILExamplesTab extends StatelessWidget {
  const _SMILExamplesTab({required this.showFPS});

  final bool showFPS;

  @override
  Widget build(BuildContext context) {
    return const DemoHomePage();
  }
}

/// Path Morphing Tab
class _PathMorphingTab extends StatelessWidget {
  const _PathMorphingTab({required this.showFPS});

  final bool showFPS;

  @override
  Widget build(BuildContext context) {
    return const PathMorphingWidget();
  }
}

/// SMIL Path Morphing Tab
class _SMILPathMorphingTab extends StatelessWidget {
  const _SMILPathMorphingTab({required this.showFPS});

  final bool showFPS;

  @override
  Widget build(BuildContext context) {
    return const SMILPathMorphingWidget();
  }
}

/// AnimateMotion Tab
class _AnimateMotionTab extends StatelessWidget {
  const _AnimateMotionTab({required this.showFPS});

  final bool showFPS;

  @override
  Widget build(BuildContext context) {
    return const SMILAnimateMotionWidget();
  }
}

/// Syncbase Timing Tab
class _SyncbaseTab extends StatelessWidget {
  const _SyncbaseTab({required this.showFPS});

  final bool showFPS;

  @override
  Widget build(BuildContext context) {
    return const SMILSyncbaseWidget();
  }
}

/// Event Timing Tab
class _EventTimingTab extends StatelessWidget {
  const _EventTimingTab({required this.showFPS});

  final bool showFPS;

  @override
  Widget build(BuildContext context) {
    return const SMILEventTimingWidget();
  }
}

/// Metrics Tab
class _MetricsTab extends StatelessWidget {
  const _MetricsTab({required this.showFPS});

  final bool showFPS;

  @override
  Widget build(BuildContext context) {
    return const MetricsWidget();
  }
}

/// Custom Tab
class _CustomTab extends StatelessWidget {
  const _CustomTab({required this.showFPS});

  final bool showFPS;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.psychology, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'Custom Examples',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            'Add your own animations here',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}
