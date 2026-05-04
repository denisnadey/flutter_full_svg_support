import 'dart:async';
import 'dart:ui' show FrameTiming;

import 'package:flutter/material.dart';

/// Low-overhead frame-timing HUD.
///
/// Design constraints:
///   - Must NOT itself measurably affect FPS of the scene it overlays.
///   - Repaints at most twice per second (refresh tick = 500 ms).
///   - Wrapped in [RepaintBoundary] so its repaints don't invalidate the
///     surrounding widget tree.
///   - Reads from [WidgetsBinding.addTimingsCallback], which fires off the
///     UI thread on the platform thread — no extra hot work in build().
///
/// Toggleable via the [visible] flag. Verbose mode adds p99 build / raster /
/// jank stats; basic mode shows only the headline FPS number.
class FpsHud extends StatefulWidget {
  const FpsHud({
    super.key,
    this.visible = true,
    this.verbose = true,
    this.windowFrames = 120,
    this.label,
  });

  final bool visible;
  final bool verbose;

  /// Sliding window size for percentile / jank computations.
  /// Default 120 frames ≈ 2 seconds at 60 Hz, 1 second at 120 Hz.
  final int windowFrames;

  /// Optional caption ("full_svg_flutter — release", etc.).
  final String? label;

  @override
  State<FpsHud> createState() => _FpsHudState();
}

class _FpsHudState extends State<FpsHud> {
  final List<FrameTiming> _recent = [];
  Timer? _ticker;

  double _fps = 0;
  double _avgTotal = 0;
  double _p99Build = 0;
  double _p99Raster = 0;
  int _jank60 = 0;
  int _jank120 = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addTimingsCallback(_onTimings);
    _ticker = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) => _refresh(),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeTimingsCallback(_onTimings);
    _ticker?.cancel();
    super.dispose();
  }

  void _onTimings(List<FrameTiming> timings) {
    _recent.addAll(timings);
    final overflow = _recent.length - widget.windowFrames;
    if (overflow > 0) {
      _recent.removeRange(0, overflow);
    }
  }

  void _refresh() {
    if (!mounted || _recent.isEmpty) return;

    final builds = <double>[];
    final rasters = <double>[];
    final totals = <double>[];
    for (final t in _recent) {
      final b = t.buildDuration.inMicroseconds / 1000.0;
      final r = t.rasterDuration.inMicroseconds / 1000.0;
      builds.add(b);
      rasters.add(r);
      totals.add(b + r);
    }
    builds.sort();
    rasters.sort();

    final avgTotal = totals.reduce((a, b) => a + b) / totals.length;
    final fps = avgTotal > 0 ? 1000.0 / avgTotal : 0.0;

    int p99idx(int n) => (n * 0.99).clamp(0, n - 1).toInt();

    setState(() {
      _fps = fps;
      _avgTotal = avgTotal;
      _p99Build = builds[p99idx(builds.length)];
      _p99Raster = rasters[p99idx(rasters.length)];
      _jank60 = builds.where((d) => d > 16.67).length;
      _jank120 = builds.where((d) => d > 8.33).length;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.visible) return const SizedBox.shrink();

    final fpsColor = _fps >= 55
        ? const Color(0xFF7FFF7F)
        : _fps >= 40
            ? const Color(0xFFFFCF00)
            : const Color(0xFFFF5050);

    return RepaintBoundary(
      child: IgnorePointer(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.white24),
          ),
          child: DefaultTextStyle(
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 11,
              color: Colors.white,
              height: 1.45,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.label != null)
                  Text(
                    widget.label!,
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 10,
                      letterSpacing: 0.5,
                    ),
                  ),
                Text(
                  'FPS: ${_fps.toStringAsFixed(1)}',
                  style: TextStyle(
                    color: fpsColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                if (widget.verbose) ...[
                  Text('avg frame  ${_avgTotal.toStringAsFixed(1)} ms'),
                  Text('p99 build  ${_p99Build.toStringAsFixed(1)} ms'),
                  Text('p99 raster ${_p99Raster.toStringAsFixed(1)} ms'),
                  Text('jank/60Hz  $_jank60'),
                  Text('jank/120Hz $_jank120'),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
