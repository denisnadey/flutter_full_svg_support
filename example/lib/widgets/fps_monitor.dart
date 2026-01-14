import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'dart:ui' as ui;

/// FPS Monitor Widget
class FPSMonitor extends StatefulWidget {
  const FPSMonitor({super.key});

  @override
  State<FPSMonitor> createState() => _FPSMonitorState();
}

class _FPSMonitorState extends State<FPSMonitor> {
  final List<double> _fpsHistory = [];
  Duration _lastFrameTime = Duration.zero;

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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(8),
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
          SizedBox(
            width: 120,
            height: 30,
            child: CustomPaint(
              painter: _FPSGraphPainter(_fpsHistory, fpsColor),
            ),
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

    // Draw 60 FPS target line
    final targetLinePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(0, 0), Offset(size.width, 0), targetLinePaint);
  }

  @override
  bool shouldRepaint(_FPSGraphPainter oldDelegate) => true;
}
