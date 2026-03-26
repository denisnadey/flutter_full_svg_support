part of 'smil_timeline.dart';

void _triggerSyncbaseEventImpl(
  SvgTimeline timeline,
  SmilAnimation sourceAnim,
  String eventType,
  Duration time,
) {
  // Найти все анимации, зависящие от этого события
  final dependents = timeline._dependents[sourceAnim];
  if (dependents == null || dependents.isEmpty) {
    return;
  }

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
    return;
  }

  for (final dependent in dependents) {
    // Проверить, есть ли у зависимой анимации syncbase условие на это событие
    for (final condition in dependent.beginConditions) {
      if (condition is SyncbaseCondition) {
        if (condition.animationId == sourceAnim.id &&
            condition.type == syncType) {
          // Вычислить время начала с учётом offset
          final resolvedTime = time + condition.offset;
          dependent.setResolvedBeginTime(resolvedTime);

          // Сразу обновить зависимую анимацию с текущим временем
          dependent.updateForTime(timeline._currentTime);
        }
      }
    }
  }
}

/// Trigger repeat event for syncbase timing
/// Per SMIL spec, id.repeat(n) fires when animation enters the nth repeat cycle
void _triggerRepeatEventImpl(
  SvgTimeline timeline,
  SmilAnimation sourceAnim,
  int repeatIndex,
  Duration time,
) {
  final dependents = timeline._dependents[sourceAnim];
  if (dependents == null || dependents.isEmpty) {
    return;
  }

  for (final dependent in dependents) {
    for (final condition in dependent.beginConditions) {
      if (condition is SyncbaseCondition &&
          condition.animationId == sourceAnim.id &&
          condition.type == SyncbaseType.repeat) {
        // Check if this specific repeat index matches
        // repeatIndex == null means trigger on all repeats
        // repeatIndex == n means trigger only on nth repeat
        if (condition.repeatIndex == null ||
            condition.repeatIndex == repeatIndex) {
          // Calculate resolved time: current time + offset
          final resolvedTime = time + condition.offset;
          dependent.setResolvedBeginTime(resolvedTime);
          dependent.updateForTime(timeline._currentTime);
        }
      }
    }
  }
}

void _buildDependencyGraphImpl(SvgTimeline timeline) {
  // Создать карту ID -> анимация
  for (final anim in timeline.animations) {
    if (anim.id != null) {
      timeline._animationById[anim.id!] = anim;
    }
  }

  // Найти все syncbase зависимости и event listeners
  for (final anim in timeline.animations) {
    // Обработать syncbase conditions
    for (final condition in anim.beginConditions) {
      if (condition is SyncbaseCondition) {
        final sourceAnim = timeline._animationById[condition.animationId];
        if (sourceAnim != null) {
          timeline._dependents.putIfAbsent(sourceAnim, () => []).add(anim);
        }
      } else if (condition is EventCondition) {
        // Регистрируем event listener
        final eventKey = timeline._getEventKey(
          condition.targetId,
          condition.eventType,
        );
        timeline._eventListeners.putIfAbsent(eventKey, () => []).add(anim);
      }
    }

    for (final condition in anim.endConditions) {
      if (condition is SyncbaseCondition) {
        final sourceAnim = timeline._animationById[condition.animationId];
        if (sourceAnim != null) {
          timeline._dependents.putIfAbsent(sourceAnim, () => []).add(anim);
        }
      }
      // Note: end conditions with events are less common, but could be supported
    }
  }
}

void _initializeEventBasedAnimationsImpl(SvgTimeline timeline) {
  for (final anim in timeline.animations) {
    // Проверяем, есть ли ТОЛЬКО event conditions в begin
    final hasOnlyEventConditions =
        anim.beginConditions.isNotEmpty &&
        anim.beginConditions.every(
          (c) => c is EventCondition || c is IndefiniteCondition,
        );

    if (hasOnlyEventConditions) {
      // Устанавливаем begin time в "infinity"
      anim.setResolvedBeginTime(_kTimelineInfinity);
    }
  }
}

Duration? _resolveSyncbaseConditionImpl(
  SvgTimeline timeline,
  SyncbaseCondition condition,
) {
  final sourceAnim = timeline._animationById[condition.animationId];
  if (sourceAnim == null) {
    return null; // Referenced animation not found
  }

  Duration? baseTime;

  switch (condition.type) {
    case SyncbaseType.begin:
      // Используем resolved begin time если есть, иначе простой begin
      baseTime = timeline._resolvedBeginTimes[sourceAnim] ?? sourceAnim.begin;
      break;

    case SyncbaseType.end:
      // begin + duration * repeatCount
      final beginTime =
          timeline._resolvedBeginTimes[sourceAnim] ?? sourceAnim.begin;
      final duration = sourceAnim.dur;
      final repeats = sourceAnim.repeatCount.isInfinite
          ? 1
          : sourceAnim.repeatCount;
      baseTime = beginTime + (duration * repeats);
      break;

    case SyncbaseType.repeat:
      // begin + duration * repeatIndex
      if (condition.repeatIndex != null) {
        final beginTime =
            timeline._resolvedBeginTimes[sourceAnim] ?? sourceAnim.begin;
        final duration = sourceAnim.dur;
        baseTime = beginTime + (duration * condition.repeatIndex!);
      } else {
        // repeat without index - trigger on every repeat
        // For now, use first repeat
        final beginTime =
            timeline._resolvedBeginTimes[sourceAnim] ?? sourceAnim.begin;
        baseTime = beginTime + sourceAnim.dur;
      }
      break;
  }
  return baseTime + condition.offset;
}

void _resolveTimingConditionsImpl(SvgTimeline timeline) {
  // Проход по всем анимациям для разрешения syncbase dependencies
  // Используем топологическую сортировку для правильного порядка
  final resolved = <SmilAnimation>{};
  final processing = <SmilAnimation>{};

  void resolveAnimation(SmilAnimation anim) {
    if (resolved.contains(anim)) {
      return;
    }
    if (processing.contains(anim)) {
      // Circular dependency detected - use simple begin
      timeline._resolvedBeginTimes[anim] = anim.begin;
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
        final sourceAnim = timeline._animationById[condition.animationId];
        if (sourceAnim != null) {
          resolveAnimation(sourceAnim);
        }
        conditionTime = timeline._resolveSyncbaseCondition(condition);
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
      timeline._resolvedBeginTimes[anim] = _kTimelineInfinity;
    } else {
      timeline._resolvedBeginTimes[anim] = earliestTime ?? anim.begin;
    }

    processing.remove(anim);
    resolved.add(anim);
  }

  // Resolve all animations
  for (final anim in timeline.animations) {
    resolveAnimation(anim);
  }

  // Apply resolved times to animations
  for (final anim in timeline.animations) {
    final resolvedTime = timeline._resolvedBeginTimes[anim];
    if (resolvedTime != null) {
      anim.setResolvedBeginTime(resolvedTime);
    }
  }
}
