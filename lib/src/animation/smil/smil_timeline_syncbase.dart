part of 'smil_timeline.dart';

/// Maximum number of resolution passes to prevent infinite loops
const int _kMaxResolutionPasses = 10;

/// Represents a resolved syncbase time with metadata for tiebreaking
class _ResolvedTiming {
  final Duration time;
  final int documentOrder;
  final bool isResolved;

  const _ResolvedTiming({
    required this.time,
    required this.documentOrder,
    required this.isResolved,
  });

  /// Compare for tiebreaking: earlier time wins, then lower document order
  int compareTo(_ResolvedTiming other) {
    final timeCompare = time.compareTo(other.time);
    if (timeCompare != 0) return timeCompare;
    // Document order tiebreaker: earlier in document = lower priority number
    return documentOrder.compareTo(other.documentOrder);
  }
}

void _triggerSyncbaseEventImpl(
  SvgTimeline timeline,
  SmilAnimation sourceAnim,
  String eventType,
  Duration time,
) {
  // Find all animations dependent on this event
  final dependents = timeline._dependents[sourceAnim];
  if (dependents == null || dependents.isEmpty) {
    return;
  }

  // Convert string to SyncbaseType
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
    // Check if dependent animation has a syncbase condition for this event
    for (final condition in dependent.beginConditions) {
      if (condition is SyncbaseCondition) {
        if (condition.animationId == sourceAnim.id &&
            condition.type == syncType) {
          // Calculate begin time with offset
          final resolvedTime = time + condition.offset;
          dependent.setResolvedBeginTime(resolvedTime);

          // Immediately update the dependent animation with current time
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
  // Build the ID -> animation map
  for (final anim in timeline.animations) {
    if (anim.id != null) {
      timeline._animationById[anim.id!] = anim;
    }
  }

  // Find all syncbase dependencies and event listeners
  for (final anim in timeline.animations) {
    // Process syncbase conditions
    for (final condition in anim.beginConditions) {
      if (condition is SyncbaseCondition) {
        final sourceAnim = timeline._animationById[condition.animationId];
        if (sourceAnim != null) {
          timeline._dependents.putIfAbsent(sourceAnim, () => []).add(anim);
        }
      } else if (condition is EventCondition) {
        // Register event listener
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
    // Check whether begin contains ONLY event conditions
    final hasOnlyEventConditions =
        anim.beginConditions.isNotEmpty &&
        anim.beginConditions.every(
          (c) => c is EventCondition || c is IndefiniteCondition,
        );

    if (hasOnlyEventConditions) {
      // Set begin time to "infinity"
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
      // Use resolved begin time if available, otherwise use the simple begin
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
  // Multi-pass syncbase resolution with circular dependency detection
  // This handles:
  // 1. Forward references (B references C where C is defined after B)
  // 2. Chain dependencies (A -> B -> C)
  // 3. Circular dependencies (A -> B -> A, gracefully broken)
  // 4. Document order tiebreaking for simultaneous begin times

  // Track which animations have fully resolved begin times
  final fullyResolved = <SmilAnimation>{};

  // Track animations in circular dependency chains to break them gracefully
  final circularDependencies = <SmilAnimation>{};

  // Detect circular dependencies using DFS with path tracking
  void detectCircularDependencies() {
    final visited = <SmilAnimation>{};
    final inStack = <SmilAnimation>{};

    void dfs(SmilAnimation anim) {
      if (circularDependencies.contains(anim)) return;
      if (inStack.contains(anim)) {
        // Circular dependency detected
        circularDependencies.add(anim);
        return;
      }
      if (visited.contains(anim)) return;

      visited.add(anim);
      inStack.add(anim);

      // Check all syncbase dependencies
      for (final condition in anim.beginConditions) {
        if (condition is SyncbaseCondition) {
          final sourceAnim = timeline._animationById[condition.animationId];
          if (sourceAnim != null) {
            dfs(sourceAnim);
          }
        }
      }

      inStack.remove(anim);
    }

    for (final anim in timeline.animations) {
      dfs(anim);
    }
  }

  // Check if an animation has only event/indefinite conditions
  bool hasOnlyEventConditions(SmilAnimation anim) {
    return anim.beginConditions.isNotEmpty &&
        anim.beginConditions.every(
          (c) => c is EventCondition || c is IndefiniteCondition,
        );
  }

  // Check if all syncbase dependencies are resolved
  bool canResolve(SmilAnimation anim) {
    // Animations with empty beginConditions use their default begin time
    if (anim.beginConditions.isEmpty) return true;

    // Event-only animations are always "resolved" to infinity
    if (hasOnlyEventConditions(anim)) return true;

    // Check if we have at least one resolvable condition
    for (final condition in anim.beginConditions) {
      if (condition is OffsetCondition) {
        return true; // Offset conditions are always resolvable
      }
      if (condition is SyncbaseCondition) {
        final sourceAnim = timeline._animationById[condition.animationId];
        // Can resolve if:
        // 1. Source animation not found (will use fallback)
        // 2. Source animation is fully resolved
        // 3. Source animation is in a circular dependency (will be broken)
        if (sourceAnim == null ||
            fullyResolved.contains(sourceAnim) ||
            circularDependencies.contains(sourceAnim)) {
          return true;
        }
      }
    }

    return false;
  }

  // Resolve a single animation's begin time
  Duration? resolveBeginTime(SmilAnimation anim) {
    if (hasOnlyEventConditions(anim)) {
      return _kTimelineInfinity;
    }

    // Collect all resolved times from conditions for tiebreaking
    final resolvedTimings = <_ResolvedTiming>[];

    for (final condition in anim.beginConditions) {
      Duration? conditionTime;

      if (condition is OffsetCondition) {
        conditionTime = condition.offset;
      } else if (condition is SyncbaseCondition) {
        final sourceAnim = timeline._animationById[condition.animationId];
        if (sourceAnim != null) {
          // Check if source is in a circular dependency
          if (circularDependencies.contains(sourceAnim) &&
              !fullyResolved.contains(sourceAnim)) {
            // Break circular dependency: use source's simple begin time
            conditionTime = sourceAnim.begin + condition.offset;
          } else {
            conditionTime = timeline._resolveSyncbaseCondition(condition);
          }
        }
      }

      if (conditionTime != null) {
        resolvedTimings.add(
          _ResolvedTiming(
            time: conditionTime,
            documentOrder: anim.documentOrder,
            isResolved: true,
          ),
        );
      }
    }

    if (resolvedTimings.isEmpty) {
      return anim.begin; // Fallback to simple begin
    }

    // Find earliest time, using document order as tiebreaker
    resolvedTimings.sort((a, b) => a.compareTo(b));
    return resolvedTimings.first.time;
  }

  // First, detect circular dependencies
  detectCircularDependencies();

  if (circularDependencies.isNotEmpty) {
    debugPrint(
      'SMIL timing: Detected ${circularDependencies.length} animation(s) '
      'in circular dependency chains. Breaking cycles gracefully.',
    );
  }

  // Multi-pass resolution: iterate until stable or max passes reached
  int passCount = 0;
  bool madeProgress = true;

  while (madeProgress && passCount < _kMaxResolutionPasses) {
    madeProgress = false;
    passCount++;

    for (final anim in timeline.animations) {
      if (fullyResolved.contains(anim)) continue;

      if (canResolve(anim)) {
        final resolvedTime = resolveBeginTime(anim);
        if (resolvedTime != null) {
          timeline._resolvedBeginTimes[anim] = resolvedTime;
          fullyResolved.add(anim);
          madeProgress = true;
        }
      }
    }
  }

  // Handle any remaining unresolved animations
  final unresolved = timeline.animations
      .where((anim) => !fullyResolved.contains(anim))
      .toList();

  if (unresolved.isNotEmpty) {
    debugPrint(
      'SMIL timing: After $_kMaxResolutionPasses passes, '
      '${unresolved.length} animation(s) still have unresolved begin times. '
      'Treating as indefinite.',
    );

    for (final anim in unresolved) {
      // Treat unresolved as indefinite
      timeline._resolvedBeginTimes[anim] = _kTimelineInfinity;
      fullyResolved.add(anim);
    }
  }

  // Apply resolved times to animations, sorted by document order for consistency
  final sortedAnimations = List<SmilAnimation>.from(timeline.animations)
    ..sort((a, b) => a.documentOrder.compareTo(b.documentOrder));

  for (final anim in sortedAnimations) {
    final resolvedTime = timeline._resolvedBeginTimes[anim];
    if (resolvedTime != null) {
      anim.setResolvedBeginTime(resolvedTime);
    }
  }
}
