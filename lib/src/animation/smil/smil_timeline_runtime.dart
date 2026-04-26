part of 'smil_timeline.dart';

void _activateAnimationByEventImpl(
  SvgTimeline timeline,
  SmilAnimation anim,
  String eventType,
  String? elementId,
  Duration eventTime,
) {
  // Find the matching EventCondition in the begin conditions
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

  // Compute the start time taking offset into account
  final startTime = eventTime + matchingCondition.offset;

  // Update resolved begin time in the map AND in the animation
  timeline._resolvedBeginTimes[anim] = startTime;
  anim.setResolvedBeginTime(startTime);

  // Update the animation with the new start time
  anim.updateForTime(timeline._currentTime);
}

String _getEventKeyImpl(String? elementId, String eventType) {
  return elementId != null ? '$elementId:$eventType' : ':$eventType';
}

/// Dispatches a DOM animation event (beginEvent, endEvent, repeatEvent).
/// These events can be used for timing by other animations or external listeners.
void _dispatchAnimationDOMEvent(
  SvgTimeline timeline,
  SmilAnimation animation,
  String eventType,
  Duration time,
) {
  // Register the event time for event-based animations
  final animId = animation.id;
  if (animId != null && animId.isNotEmpty) {
    final eventKey = _getEventKeyImpl(animId, eventType);
    timeline._eventTimes[eventKey] = time;

    // Find and activate any animations waiting for this DOM event
    final listeners = timeline._eventListeners[eventKey];
    if (listeners != null && listeners.isNotEmpty) {
      for (final listener in listeners) {
        _activateAnimationByEventImpl(
          timeline,
          listener,
          eventType,
          animId,
          time,
        );
      }
    }
  }
}

void _updateAnimationsImpl(SvgTimeline timeline, Duration time) {
  // Track previous states and iterations for detecting transitions and repeats
  final previousStates = <SmilAnimation, bool>{};
  final previousIterations = <SmilAnimation, int>{};
  for (final animation in timeline.animations) {
    previousStates[animation] = animation.isActive;
    previousIterations[animation] = animation.currentIteration;
  }

  // Update all animations
  for (final animation in timeline.animations) {
    animation.updateForTime(time);
  }

  // Implement SVG animation sandwich model:
  // When multiple animations target the same attribute on the same element,
  // later animations (higher document order) have higher priority.
  // For additive="sum" animations, they stack in document order.
  _applyAnimationSandwichModel(timeline);

  // Check for state transitions and repeat events
  for (final animation in timeline.animations) {
    final wasActive = previousStates[animation] ?? false;
    final isActive = animation.isActive;
    final prevIteration = previousIterations[animation] ?? 0;
    final currIteration = animation.currentIteration;

    // If the animation ended (was active, now inactive)
    if (wasActive && !isActive && time >= animation.getEffectiveEndTime()) {
      timeline._triggerSyncbaseEvent(animation, 'end', time);
      // Also dispatch endEvent as DOM event for external listeners
      _dispatchAnimationDOMEvent(timeline, animation, 'endEvent', time);
    }

    // If the animation started (was not active, now active)
    if (!wasActive && isActive) {
      timeline._triggerSyncbaseEvent(animation, 'begin', time);
      // Also dispatch beginEvent as DOM event for external listeners
      _dispatchAnimationDOMEvent(timeline, animation, 'beginEvent', time);
    }

    // Trigger repeat events when entering a new iteration
    // Per SMIL spec, repeat(n) fires when the nth repeat begins (0-indexed)
    if (isActive && currIteration > prevIteration) {
      // Fire repeat event for each iteration transition
      for (int i = prevIteration + 1; i <= currIteration; i++) {
        timeline._triggerRepeatEvent(animation, i, time);
      }
    }
  }
}

/// Apply the SVG animation sandwich model for priority resolution.
/// Per SMIL spec:
/// - Later animations (higher document order) override earlier ones
/// - Additive animations stack with the base value and other additive animations
/// - The "last wins" rule applies for non-additive animations
void _applyAnimationSandwichModel(SvgTimeline timeline) {
  // Group active animations by target element and attribute
  final animationsByTarget = <(SvgNode, String), List<SmilAnimation>>{};

  for (final anim in timeline.animations) {
    if (!anim.isActive) continue;

    final key = (anim.targetNode, anim.attributeName);
    animationsByTarget.putIfAbsent(key, () => []).add(anim);
  }

  // For each group with multiple animations, apply sandwich model
  for (final entry in animationsByTarget.entries) {
    final animations = entry.value;
    if (animations.length <= 1) continue;

    // Sort by document order (index in the original list preserves document order)
    animations.sort(
      (a, b) => timeline.animations
          .indexOf(a)
          .compareTo(timeline.animations.indexOf(b)),
    );

    // Apply the SVG animation sandwich model in document order.
    //
    // additive="replace" resets the running accumulated value.
    // additive="sum" adds the raw computed value to the running accumulation.
    // This correctly handles replace+sum chains used in animateTransform.
    Object? accumulated;
    AnimatableSvgAttribute? targetAttr;
    for (final anim in animations) {
      final t = anim.localTime.inMicroseconds / anim.dur.inMicroseconds;
      final raw = anim.computeRawValue(
        t,
        completedRepeats: anim.currentIteration,
      );
      accumulated = anim.applyAdditiveWithBase(raw, accumulated);
      targetAttr = anim.targetNode.getAttribute(anim.attributeName);
    }
    if (accumulated != null && targetAttr != null) {
      targetAttr.setAnimatedValue(accumulated);
    }
  }
}
