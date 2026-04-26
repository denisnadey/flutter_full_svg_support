part of 'smil_timeline.dart';

/// Information about the timeline state
@immutable
class TimelineInfo {
  /// Creates timeline information
  const TimelineInfo({
    required this.currentTime,
    required this.totalDuration,
    required this.totalAnimations,
    required this.activeAnimations,
    required this.playbackRate,
  });

  /// Current time
  final Duration currentTime;

  /// Total duration
  final Duration totalDuration;

  /// Total number of animations
  final int totalAnimations;

  /// Number of active animations
  final int activeAnimations;

  /// Playback rate
  final double playbackRate;

  /// Playback progress (0.0 - 1.0)
  double get progress {
    if (totalDuration == Duration.zero) {
      return 0.0;
    }
    return (currentTime.inMicroseconds / totalDuration.inMicroseconds).clamp(
      0.0,
      1.0,
    );
  }

  @override
  String toString() {
    return 'TimelineInfo('
        'progress: ${(progress * 100).toStringAsFixed(1)}%, '
        'active: $activeAnimations/$totalAnimations'
        ')';
  }
}
