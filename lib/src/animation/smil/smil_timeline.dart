import 'package:flutter/foundation.dart';

import '../svg_dom.dart';
import 'smil_animation.dart';
import 'timing_condition.dart';

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
    _initializeEventBasedAnimations(); // Initialize event-based animations
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
          const Duration(days: 365 * 100),
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

  /// Активировать анимацию по событию
  void _activateAnimationByEvent(
    SmilAnimation anim,
    String eventType,
    String? elementId,
    Duration eventTime,
  ) {
    // Найти соответствующее EventCondition в begin условиях
    EventCondition? matchingCondition;
    for (final condition in anim.beginConditions) {
      if (condition is EventCondition) {
        if (condition.eventType == eventType &&
            (condition.targetId == null || condition.targetId == elementId)) {
          matchingCondition = condition;
          break;
        }
      }
    }

    if (matchingCondition == null) {
      return;
    }

    // Вычисляем время начала с учётом offset
    final startTime = eventTime + matchingCondition.offset;

    // Обновляем resolved begin time в карте И в анимации
    _resolvedBeginTimes[anim] = startTime;
    anim.setResolvedBeginTime(startTime);

    // Обновляем анимацию с новым временем начала
    anim.updateForTime(_currentTime);
  }

  /// Получить ключ события для карты
  String _getEventKey(String? elementId, String eventType) {
    return elementId != null ? '$elementId:$eventType' : ':$eventType';
  }

  /// Обновить все анимации для текущего времени
  void _updateAnimations(Duration time) {
    // Отслеживаем предыдущие состояния анимаций для определения переходов
    final previousStates = <SmilAnimation, bool>{};
    for (final animation in animations) {
      previousStates[animation] = animation.isActive;
    }

    // Обновляем все анимации
    for (final animation in animations) {
      animation.updateForTime(time);
    }

    // Проверяем, не закончились ли анимации, чтобы триггерить syncbase события
    for (final animation in animations) {
      final wasActive = previousStates[animation] ?? false;
      final isActive = animation.isActive;

      // Если анимация закончилась (была активна, теперь неактивна)
      if (wasActive && !isActive && time >= animation.getEffectiveEndTime()) {
        // ignore: avoid_print
        print('DEBUG: Animation ended: id=${animation.id}, time=$time');
        _triggerSyncbaseEvent(animation, 'end', time);
      }

      // Если анимация началась (не была активна, теперь активна)
      if (!wasActive && isActive) {
        // ignore: avoid_print
        print('DEBUG: Animation started: id=${animation.id}, time=$time');
        _triggerSyncbaseEvent(animation, 'begin', time);
      }
    }
  }

  /// Триггерить syncbase событие (begin или end) для зависимых анимаций
  void _triggerSyncbaseEvent(
    SmilAnimation sourceAnim,
    String eventType,
    Duration time,
  ) {
    // ignore: avoid_print
    print(
      'DEBUG _triggerSyncbaseEvent: sourceAnim=${sourceAnim.id}, eventType=$eventType, time=$time',
    );

    // Найти все анимации, зависящие от этого события
    final dependents = _dependents[sourceAnim];
    if (dependents == null || dependents.isEmpty) {
      // ignore: avoid_print
      print('  No dependents');
      return;
    }

    // ignore: avoid_print
    print('  Found ${dependents.length} dependents');

    // Преобразовать строку в SyncbaseType
    SyncbaseType? syncType;
    if (eventType == 'begin') {
      syncType = SyncbaseType.begin;
    } else if (eventType == 'end') {
      syncType = SyncbaseType.end;
    } else if (eventType == 'repeat') {
      syncType = SyncbaseType.repeat;
    }

    if (syncType == null) {
      // ignore: avoid_print
      print('  Invalid syncType');
      return;
    }

    for (final dependent in dependents) {
      // Проверить, есть ли у зависимой анимации syncbase условие на это событие
      for (final condition in dependent.beginConditions) {
        if (condition is SyncbaseCondition) {
          // ignore: avoid_print
          print(
            '  DEBUG: Checking condition: animId=${condition.animationId}, type=${condition.type}, matches=${condition.animationId == sourceAnim.id && condition.type == syncType}',
          );
          if (condition.animationId == sourceAnim.id &&
              condition.type == syncType) {
            // ignore: avoid_print
            print('  DEBUG: MATCHED! Setting resolvedBeginTime');
            // Вычислить время начала с учётом offset
            final resolvedTime = time + condition.offset;
            dependent.setResolvedBeginTime(resolvedTime);

            // Сразу обновить зависимую анимацию с текущим временем
            dependent.updateForTime(_currentTime);
          }
        }
      }
    }
  }

  /// Построить граф зависимостей для syncbase timing и event-based timing
  void _buildDependencyGraph() {
    // Создать карту ID -> анимация
    for (final anim in animations) {
      if (anim.id != null) {
        _animationById[anim.id!] = anim;
      }
    }

    // Найти все syncbase зависимости и event listeners
    for (final anim in animations) {
      // Обработать syncbase conditions
      for (final condition in anim.beginConditions) {
        if (condition is SyncbaseCondition) {
          final sourceAnim = _animationById[condition.animationId];
          if (sourceAnim != null) {
            _dependents.putIfAbsent(sourceAnim, () => []).add(anim);
          }
        } else if (condition is EventCondition) {
          // Регистрируем event listener
          final eventKey = _getEventKey(
            condition.targetId,
            condition.eventType,
          );
          _eventListeners.putIfAbsent(eventKey, () => []).add(anim);
        }
      }

      for (final condition in anim.endConditions) {
        if (condition is SyncbaseCondition) {
          final sourceAnim = _animationById[condition.animationId];
          if (sourceAnim != null) {
            _dependents.putIfAbsent(sourceAnim, () => []).add(anim);
          }
        }
        // Note: end conditions with events are less common, but could be supported
      }
    }
  }

  /// Инициализировать event-based анимации
  /// Устанавливает их begin time в "infinity", чтобы они не начинались автоматически
  void _initializeEventBasedAnimations() {
    for (final anim in animations) {
      // Проверяем, есть ли ТОЛЬКО event conditions в begin
      final hasOnlyEventConditions =
          anim.beginConditions.isNotEmpty &&
          anim.beginConditions.every(
            (c) => c is EventCondition || c is IndefiniteCondition,
          );

      if (hasOnlyEventConditions) {
        // Устанавливаем begin time в "infinity"
        anim.setResolvedBeginTime(const Duration(days: 365 * 100));
      }
    }
  }

  /// Разрешить syncbase условия для анимации
  Duration? _resolveSyncbaseCondition(SyncbaseCondition condition) {
    final sourceAnim = _animationById[condition.animationId];
    if (sourceAnim == null) {
      return null; // Referenced animation not found
    }

    Duration? baseTime;

    switch (condition.type) {
      case SyncbaseType.begin:
        // Используем resolved begin time если есть, иначе простой begin
        baseTime = _resolvedBeginTimes[sourceAnim] ?? sourceAnim.begin;
        break;

      case SyncbaseType.end:
        // begin + duration * repeatCount
        final beginTime = _resolvedBeginTimes[sourceAnim] ?? sourceAnim.begin;
        final duration = sourceAnim.dur;
        final repeats = sourceAnim.repeatCount.isInfinite
            ? 1
            : sourceAnim.repeatCount;
        baseTime = beginTime + (duration * repeats);
        break;

      case SyncbaseType.repeat:
        // begin + duration * repeatIndex
        if (condition.repeatIndex != null) {
          final beginTime = _resolvedBeginTimes[sourceAnim] ?? sourceAnim.begin;
          final duration = sourceAnim.dur;
          baseTime = beginTime + (duration * condition.repeatIndex!);
        } else {
          // repeat without index - trigger on every repeat
          // For now, use first repeat
          final beginTime = _resolvedBeginTimes[sourceAnim] ?? sourceAnim.begin;
          baseTime = beginTime + sourceAnim.dur;
        }
        break;
    }

    if (baseTime == null) return null;

    return baseTime + condition.offset;
  }

  /// Разрешить все timing условия и вычислить эффективные begin times
  void _resolveTimingConditions() {
    // Проход по всем анимациям для разрешения syncbase dependencies
    // Используем топологическую сортировку для правильного порядка
    final resolved = <SmilAnimation>{};
    final processing = <SmilAnimation>{};

    void resolveAnimation(SmilAnimation anim) {
      if (resolved.contains(anim)) return;
      if (processing.contains(anim)) {
        // Circular dependency detected - use simple begin
        _resolvedBeginTimes[anim] = anim.begin;
        return;
      }

      processing.add(anim);

      // Find earliest resolved time from all begin conditions
      Duration? earliestTime;

      for (final condition in anim.beginConditions) {
        Duration? conditionTime;

        if (condition is OffsetCondition) {
          conditionTime = condition.offset;
        } else if (condition is SyncbaseCondition) {
          // Resolve dependency first
          final sourceAnim = _animationById[condition.animationId];
          if (sourceAnim != null) {
            resolveAnimation(sourceAnim);
          }
          conditionTime = _resolveSyncbaseCondition(condition);
        }

        if (conditionTime != null) {
          if (earliestTime == null || conditionTime < earliestTime) {
            earliestTime = conditionTime;
          }
        }
      }

      // Use resolved time or fallback to simple begin
      // НО: не перезаписываем infinity begin times для event-based анимаций
      final hasOnlyEventConditions =
          anim.beginConditions.isNotEmpty &&
          anim.beginConditions.every(
            (c) => c is EventCondition || c is IndefiniteCondition,
          );

      if (hasOnlyEventConditions) {
        // Оставляем infinity begin time, установленный в _initializeEventBasedAnimations
        _resolvedBeginTimes[anim] = const Duration(days: 365 * 100);
      } else {
        _resolvedBeginTimes[anim] = earliestTime ?? anim.begin;
      }

      processing.remove(anim);
      resolved.add(anim);
    }

    // Resolve all animations
    for (final anim in animations) {
      resolveAnimation(anim);
    }

    // Apply resolved times to animations
    for (final anim in animations) {
      final resolvedTime = _resolvedBeginTimes[anim];
      if (resolvedTime != null) {
        anim.setResolvedBeginTime(resolvedTime);
      }
    }
  }

  /// Получить список активных анимаций в текущий момент
  List<SmilAnimation> getActiveAnimations() {
    return animations.where((anim) => anim.isActive).toList();
  }

  /// Проверить, есть ли хотя бы одна активная анимация
  bool hasActiveAnimations() {
    return animations.any((anim) => anim.isActive);
  }

  /// Вычислить общую длительность всех анимаций
  static Duration _computeTotalDuration(List<SmilAnimation> animations) {
    if (animations.isEmpty) {
      return Duration.zero;
    }

    Duration max = Duration.zero;

    for (final anim in animations) {
      final end = anim.getEffectiveEndTime();
      if (!end.isNegative && end != const Duration(days: 365 * 100)) {
        // Игнорируем "бесконечные" анимации
        if (end > max) {
          max = end;
        }
      }
    }

    // Если все анимации бесконечные, вернём разумное значение по умолчанию
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
    if (totalDuration == Duration.zero) return 0.0;
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
