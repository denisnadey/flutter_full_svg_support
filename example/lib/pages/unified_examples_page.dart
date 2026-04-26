import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'dart:ui' as ui;

import '../widgets/path_morphing_widget.dart';
import '../widgets/metrics_widget.dart';
import '../widgets/smil_path_morphing_widget.dart';
import '../widgets/smil_animate_motion_widget.dart';
import '../widgets/smil_syncbase_widget.dart';
import '../widgets/smil_event_timing_widget.dart';
import '../animated_svg_demo.dart';

/// Tab item data class
class _TabItem {
  final IconData icon;
  final String label;
  final String shortLabel;
  final String description;

  const _TabItem({
    required this.icon,
    required this.label,
    required this.shortLabel,
    required this.description,
  });
}

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

  static const _tabs = [
    _TabItem(
      icon: Icons.animation,
      label: 'SMIL Animations',
      shortLabel: 'SMIL',
      description: 'Basic SMIL animation examples',
    ),
    _TabItem(
      icon: Icons.auto_fix_high,
      label: 'Path Morphing',
      shortLabel: 'Morph',
      description: 'Shape interpolation demos',
    ),
    _TabItem(
      icon: Icons.transform,
      label: 'SMIL Path',
      shortLabel: 'Path',
      description: 'Path-based animations',
    ),
    _TabItem(
      icon: Icons.moving,
      label: 'Motion Path',
      shortLabel: 'Motion',
      description: 'animateMotion examples',
    ),
    _TabItem(
      icon: Icons.sync_alt,
      label: 'Syncbase',
      shortLabel: 'Sync',
      description: 'Synchronized animations',
    ),
    _TabItem(
      icon: Icons.touch_app,
      label: 'Events',
      shortLabel: 'Events',
      description: 'Event-triggered animations',
    ),
    _TabItem(
      icon: Icons.analytics_outlined,
      label: 'Metrics',
      shortLabel: 'Stats',
      description: 'Performance metrics',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Animation Gallery',
          style: TextStyle(
            fontSize: isMobile ? 18 : 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        actions: [
          // FPS Toggle
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: _showFPS
                  ? theme.colorScheme.primaryContainer
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              icon: Icon(
                _showFPS ? Icons.speed : Icons.speed_outlined,
                color: _showFPS ? theme.colorScheme.primary : null,
              ),
              tooltip: _showFPS ? 'Hide FPS Monitor' : 'Show FPS Monitor',
              onPressed: () => setState(() => _showFPS = !_showFPS),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isDark
                      ? theme.colorScheme.outline.withValues(alpha: 0.3)
                      : theme.colorScheme.outline.withValues(alpha: 0.2),
                ),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelPadding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 12),
              indicatorSize: TabBarIndicatorSize.tab,
              indicatorWeight: 3,
              dividerColor: Colors.transparent,
              tabs: _tabs.map((tab) => _buildTab(tab, isMobile)).toList(),
            ),
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
            ],
          ),
          if (_showFPS) const Positioned(top: 8, right: 8, child: FPSMonitor()),
        ],
      ),
    );
  }

  Widget _buildTab(_TabItem tab, bool isMobile) {
    return Tab(
      height: 56,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(tab.icon, size: isMobile ? 18 : 20),
          const SizedBox(width: 8),
          Text(
            isMobile ? tab.shortLabel : tab.label,
            style: TextStyle(
              fontSize: isMobile ? 12 : 13,
              fontWeight: FontWeight.w500,
            ),
          ),
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
    String fpsStatus;
    if (avgFPS >= 55) {
      fpsColor = Colors.green;
      fpsStatus = 'Excellent';
    } else if (avgFPS >= 30) {
      fpsColor = Colors.orange;
      fpsStatus = 'Good';
    } else {
      fpsColor = Colors.red;
      fpsStatus = 'Low';
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: fpsColor.withValues(alpha: 0.6), width: 2),
        boxShadow: [
          BoxShadow(
            color: fpsColor.withValues(alpha: 0.3),
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // FPS Header
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: fpsColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(Icons.speed, color: fpsColor, size: 14),
              ),
              const SizedBox(width: 8),
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
          const SizedBox(height: 8),
          // FPS Graph
          SizedBox(
            width: 120,
            height: 32,
            child: CustomPaint(
              painter: _FPSGraphPainter(_fpsHistory, fpsColor),
            ),
          ),
          const SizedBox(height: 6),
          // Status row
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: fpsColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                fpsStatus,
                style: TextStyle(
                  color: fpsColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Frame: $_frameCount',
                style: const TextStyle(color: Colors.white54, fontSize: 9),
              ),
            ],
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
      ..color = color.withValues(alpha: 0.2)
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
      ..color = Colors.white.withValues(alpha: 0.2)
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
