import 'package:flutter/foundation.dart';

import '../svg_dom.dart';
import 'smil_animation.dart';
import 'timing_condition.dart';

part 'smil_timeline_info.dart';
part 'smil_timeline_runtime.dart';
part 'smil_timeline_syncbase.dart';

const Duration _kTimelineInfinity = Duration(days: 365 * 100);

/// Timeline for managing SMIL animations
///
/// Responsible for:
/// - Advancing time (tick/seek)
/// - Activating/deactivating animations
/// - Computing total duration
/// - Syncbase dependency tracking
class SvgTimeline {
  /// Creates a timeline with the given animations
  SvgTimeline({required this.animations, required this.rootNode}) {
    _buildDependencyGraph();
    _initializeEventBasedAnimations();
    _resolveTimingConditions();
    _totalDuration = _computeTotalDuration(
      animations,
    ); // Computed AFTER resolving syncbase
  }

  /// List of all SMIL animations in the document
  final List<SmilAnimation> animations;

  /// Root node of the document
  final SvgNode rootNode;

  /// Current document time
  Duration _currentTime = Duration.zero;

  /// Total duration of all animations
  late final Duration _totalDuration;

  /// Playback rate (1.0 = normal, 2.0 = x2, 0.5 = slow)
  double _playbackRate = 1.0;

  /// Map of animation ID -> animation for fast syncbase dependency lookups
  final Map<String, SmilAnimation> _animationById = {};

  /// Map of animation -> list of animations that depend on it (for syncbase)
  final Map<SmilAnimation, List<SmilAnimation>> _dependents = {};

  /// Resolved begin times for animations with syncbase conditions
  final Map<SmilAnimation, Duration> _resolvedBeginTimes = {};

  /// Map of animations waiting for events: eventKey -> list of animations
  /// eventKey format: "elementId:eventType" or ":eventType" for document-level events
  final Map<String, List<SmilAnimation>> _eventListeners = {};

  /// Map of event times: eventKey -> time of the event
  final Map<String, Duration> _eventTimes = {};

  /// Get the current time
  Duration get currentTime => _currentTime;

  /// Get the total duration
  Duration get totalDuration => _totalDuration;

  /// Get the playback rate
  double get playbackRate => _playbackRate;

  /// Set the playback rate
  set playbackRate(double value) {
    if (value <= 0) {
      throw ArgumentError('Playback rate must be positive');
    }
    _playbackRate = value;
  }

  /// Advance time by delta
  ///
  /// Takes playbackRate into account when computing the effective time delta
  void tick(Duration delta) {
    final effectiveDelta = delta * _playbackRate;
    _currentTime += effectiveDelta;
    _updateAnimations(_currentTime);
  }

  /// Seek to a specific time
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

  /// Reset the timeline to the beginning
  void reset() {
    _currentTime = Duration.zero;
    _eventTimes.clear(); // Clear event records
    _resolvedBeginTimes.clear(); // Clear resolved begin times

    // First set infinity begin times for event-based animations
    for (final anim in animations) {
      // Clear resolved begin times for event-based animations
      final hasEventConditions = anim.beginConditions.any(
        (c) => c is EventCondition,
      );
      if (hasEventConditions) {
        anim.setResolvedBeginTime(
          _kTimelineInfinity,
        ); // "Infinity" - never start
      }
    }

    // Then reset the state of all animations
    for (final anim in animations) {
      anim.reset();
    }

    // Do NOT call _updateAnimations here to avoid re-activation
    // Animations will be updated on the next tick() or triggerEvent()
  }

  /// Trigger an event for an element
  ///
  /// [elementId] - ID of the SVG element, or null for document-level events
  /// [eventType] - event type (click, mouseover, mouseout, focus, blur)
  ///
  /// Example:
  /// ```dart
  /// timeline.triggerEvent('myRect', 'click'); // element clicked
  /// timeline.triggerEvent(null, 'click'); // click on document
  /// ```
  void triggerEvent(String? elementId, String eventType) {
    final eventKey = _getEventKey(elementId, eventType);
    final eventTime = _currentTime;

    // Store the event time
    _eventTimes[eventKey] = eventTime;

    // Find all animations waiting for this event
    final listeners = _eventListeners[eventKey];
    if (listeners == null || listeners.isEmpty) {
      return;
    }

    // Activate animations taking offset into account
    for (final anim in listeners) {
      _activateAnimationByEvent(anim, eventType, elementId, eventTime);
    }

    // Update rendering
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

  /// Get the list of currently active animations
  List<SmilAnimation> getActiveAnimations() {
    return animations.where((anim) => anim.isActive).toList();
  }

  /// Check whether there is at least one active animation
  bool hasActiveAnimations() {
    return animations.any((anim) => anim.isActive);
  }

  /// Check whether there are animations waiting for events (click, mouseover, etc.)
  /// Used to determine whether a ticker is needed when autoPlay=false
  bool hasEventBasedAnimations() {
    return _eventListeners.isNotEmpty;
  }

  /// Compute the total duration of all animations
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

    // If all animations are finite, return a reasonable default value
    return max == Duration.zero ? const Duration(seconds: 10) : max;
  }

  /// Get information about the animation state
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
