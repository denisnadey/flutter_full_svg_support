part of 'smil_timeline.dart';

/// Информация о состоянии таймлайна
@immutable
class TimelineInfo {
  /// Создаёт информацию о таймлайне
  const TimelineInfo({
    required this.currentTime,
    required this.totalDuration,
    required this.totalAnimations,
    required this.activeAnimations,
    required this.playbackRate,
  });

  /// Текущее время
  final Duration currentTime;

  /// Общая длительность
  final Duration totalDuration;

  /// Общее количество анимаций
  final int totalAnimations;

  /// Количество активных анимаций
  final int activeAnimations;

  /// Скорость воспроизведения
  final double playbackRate;

  /// Прогресс воспроизведения (0.0 - 1.0)
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
