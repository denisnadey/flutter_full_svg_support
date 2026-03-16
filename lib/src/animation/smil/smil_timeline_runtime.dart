part of 'smil_timeline.dart';

void _activateAnimationByEventImpl(
  SvgTimeline timeline,
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
  timeline._resolvedBeginTimes[anim] = startTime;
  anim.setResolvedBeginTime(startTime);

  // Обновляем анимацию с новым временем начала
  anim.updateForTime(timeline._currentTime);
}

String _getEventKeyImpl(String? elementId, String eventType) {
  return elementId != null ? '$elementId:$eventType' : ':$eventType';
}

void _updateAnimationsImpl(SvgTimeline timeline, Duration time) {
  // Отслеживаем предыдущие состояния анимаций для определения переходов
  final previousStates = <SmilAnimation, bool>{};
  for (final animation in timeline.animations) {
    previousStates[animation] = animation.isActive;
  }

  // Обновляем все анимации
  for (final animation in timeline.animations) {
    animation.updateForTime(time);
  }

  // Проверяем, не закончились ли анимации, чтобы триггерить syncbase события
  for (final animation in timeline.animations) {
    final wasActive = previousStates[animation] ?? false;
    final isActive = animation.isActive;

    // Если анимация закончилась (была активна, теперь неактивна)
    if (wasActive && !isActive && time >= animation.getEffectiveEndTime()) {
      timeline._triggerSyncbaseEvent(animation, 'end', time);
    }

    // Если анимация началась (не была активна, теперь активна)
    if (!wasActive && isActive) {
      timeline._triggerSyncbaseEvent(animation, 'begin', time);
    }
  }
}
