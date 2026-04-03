import 'package:flutter/foundation.dart';

import '../svg_dom.dart';
import 'smil_animation.dart';
import 'timing_condition.dart';

part 'smil_timeline_info.dart';
part 'smil_timeline_runtime.dart';
part 'smil_timeline_syncbase.dart';

const Duration _kTimelineInfinity = Duration(days: 365 * 100);

/// Таймлайн для управления SMIL анимациями
///
/// Отвечает за:
/// - Обновление времени (tick/seek)
/// - Активацию/деактивацию анимаций
/// - Вычисление общей длительности
/// - Syncbase dependency tracking
class SvgTimeline {
  /// Создаёт таймлайн с заданными анимациями
  SvgTimeline({required this.animations, required this.rootNode}) {
    _buildDependencyGraph();
    _initializeEventBasedAnimations();
    _resolveTimingConditions();
    _totalDuration = _computeTotalDuration(
      animations,
    ); // Вычисляем ПОСЛЕ разрешения syncbase
  }

  /// Список всех SMIL анимаций в документе
  final List<SmilAnimation> animations;

  /// Корневой узел документа
  final SvgNode rootNode;

  /// Текущее время документа
  Duration _currentTime = Duration.zero;

  /// Общая длительность всех анимаций
  late final Duration _totalDuration;

  /// Скорость воспроизведения (1.0 = нормальная, 2.0 = x2, 0.5 = замедленно)
  double _playbackRate = 1.0;

  /// Карта ID анимации -> анимация для быстрого поиска syncbase зависимостей
  final Map<String, SmilAnimation> _animationById = {};

  /// Карта анимации -> список зависимых от неё анимаций (для syncbase)
  final Map<SmilAnimation, List<SmilAnimation>> _dependents = {};

  /// Resolved begin times для анимаций с syncbase conditions
  final Map<SmilAnimation, Duration> _resolvedBeginTimes = {};

  /// Карта анимаций, ожидающих события: eventKey -> список анимаций
  /// eventKey format: "elementId:eventType" или ":eventType" для document-level events
  final Map<String, List<SmilAnimation>> _eventListeners = {};

  /// Карта времени, когда произошло событие: eventKey -> время события
  final Map<String, Duration> _eventTimes = {};

  /// Получить текущее время
  Duration get currentTime => _currentTime;

  /// Получить общую длительность
  Duration get totalDuration => _totalDuration;

  /// Получить скорость воспроизведения
  double get playbackRate => _playbackRate;

  /// Установить скорость воспроизведения
  set playbackRate(double value) {
    if (value <= 0) {
      throw ArgumentError('Playback rate must be positive');
    }
    _playbackRate = value;
  }

  /// Продвинуть время на delta
  ///
  /// Учитывает playbackRate при вычислении эффективного изменения времени
  void tick(Duration delta) {
    final effectiveDelta = delta * _playbackRate;
    _currentTime += effectiveDelta;
    _updateAnimations(_currentTime);
  }

  /// Перейти к конкретному времени
  void seek(Duration time) {
    if (time < Duration.zero) {
      _currentTime = Duration.zero;
    } else if (time > _totalDuration) {
      _currentTime = _totalDuration;
    } else {
      _currentTime = time;
    }
    _updateAnimations(_currentTime);
  }

  /// Сбросить таймлайн в начало
  void reset() {
    _currentTime = Duration.zero;
    _eventTimes.clear(); // Очистить записи о событиях
    _resolvedBeginTimes.clear(); // Очистить resolved begin times

    // Сначала установить infinity begin times для event-based анимаций
    for (final anim in animations) {
      // Очистить resolved begin times для event-based анимаций
      final hasEventConditions = anim.beginConditions.any(
        (c) => c is EventCondition,
      );
      if (hasEventConditions) {
        anim.setResolvedBeginTime(
          _kTimelineInfinity,
        ); // "Infinity" - never start
      }
    }

    // Затем сбросить состояние всех анимаций
    for (final anim in animations) {
      anim.reset();
    }

    // НЕ вызываем _updateAnimations здесь, чтобы избежать повторной активации
    // Анимации будут обновлены при следующем tick() или triggerEvent()
  }

  /// Триггерить событие для элемента
  ///
  /// [elementId] - ID элемента SVG или null для document-level событий
  /// [eventType] - тип события (click, mouseover, mouseout, focus, blur)
  ///
  /// Пример:
  /// ```dart
  /// timeline.triggerEvent('myRect', 'click'); // элемент кликнут
  /// timeline.triggerEvent(null, 'click'); // клик на документ
  /// ```
  void triggerEvent(String? elementId, String eventType) {
    final eventKey = _getEventKey(elementId, eventType);
    final eventTime = _currentTime;

    // Сохраняем время события
    _eventTimes[eventKey] = eventTime;

    // Находим все анимации, ожидающие это событие
    final listeners = _eventListeners[eventKey];
    if (listeners == null || listeners.isEmpty) {
      return;
    }

    // Активируем анимации с учётом offset
    for (final anim in listeners) {
      _activateAnimationByEvent(anim, eventType, elementId, eventTime);
    }

    // Обновляем отрисовку
    _updateAnimations(_currentTime);
  }

  void _activateAnimationByEvent(
    SmilAnimation anim,
    String eventType,
    String? elementId,
    Duration eventTime,
  ) {
    _activateAnimationByEventImpl(this, anim, eventType, elementId, eventTime);
  }

  String _getEventKey(String? elementId, String eventType) {
    return _getEventKeyImpl(elementId, eventType);
  }

  void _updateAnimations(Duration time) {
    _updateAnimationsImpl(this, time);
  }

  void _triggerSyncbaseEvent(
    SmilAnimation sourceAnim,
    String eventType,
    Duration time,
  ) {
    _triggerSyncbaseEventImpl(this, sourceAnim, eventType, time);
  }

  /// Trigger a repeat event for syncbase timing
  /// Per SMIL spec, repeat(n) fires when the nth repeat begins
  void _triggerRepeatEvent(
    SmilAnimation sourceAnim,
    int repeatIndex,
    Duration time,
  ) {
    _triggerRepeatEventImpl(this, sourceAnim, repeatIndex, time);
  }

  void _buildDependencyGraph() {
    _buildDependencyGraphImpl(this);
  }

  void _initializeEventBasedAnimations() {
    _initializeEventBasedAnimationsImpl(this);
  }

  Duration? _resolveSyncbaseCondition(SyncbaseCondition condition) {
    return _resolveSyncbaseConditionImpl(this, condition);
  }

  void _resolveTimingConditions() {
    _resolveTimingConditionsImpl(this);
  }

  /// Получить список активных анимаций в текущий момент
  List<SmilAnimation> getActiveAnimations() {
    return animations.where((anim) => anim.isActive).toList();
  }

  /// Проверить, есть ли хотя бы одна активная анимация
  bool hasActiveAnimations() {
    return animations.any((anim) => anim.isActive);
  }

  /// Проверить, есть ли анимации, ожидающие событий (click, mouseover, etc.)
  /// Используется для определения необходимости тикера при autoPlay=false
  bool hasEventBasedAnimations() {
    return _eventListeners.isNotEmpty;
  }

  /// Вычислить общую длительность всех анимаций
  static Duration _computeTotalDuration(List<SmilAnimation> animations) {
    if (animations.isEmpty) {
      return Duration.zero;
    }

    Duration max = Duration.zero;
    bool hasInfinite = false;

    for (final anim in animations) {
      final end = anim.getEffectiveEndTime();
      if (!end.isNegative && end == _kTimelineInfinity) {
        // Track infinite animations so seek() is not clamped
        hasInfinite = true;
      } else if (!end.isNegative && end > max) {
        max = end;
      }
    }

    // If any animation is infinite, timeline extends indefinitely
    // so that seek() can reach any time without clamping.
    if (hasInfinite) {
      return _kTimelineInfinity;
    }

    // Если все анимации конечные, вернём разумное значение по умолчанию
    return max == Duration.zero ? const Duration(seconds: 10) : max;
  }

  /// Получить информацию о состоянии анимаций
  TimelineInfo getInfo() {
    final activeCount = animations.where((a) => a.isActive).length;

    return TimelineInfo(
      currentTime: _currentTime,
      totalDuration: _totalDuration,
      totalAnimations: animations.length,
      activeAnimations: activeCount,
      playbackRate: _playbackRate,
    );
  }

  @override
  String toString() {
    final info = getInfo();
    return 'SvgTimeline('
        'time: ${info.currentTime.inMilliseconds}ms / ${info.totalDuration.inMilliseconds}ms, '
        'active: ${info.activeAnimations}/${info.totalAnimations}, '
        'rate: ${info.playbackRate}x'
        ')';
  }
}
