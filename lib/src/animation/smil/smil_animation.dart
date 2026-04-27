import 'package:flutter/foundation.dart';

import '../svg_dom.dart';
import 'distance_calculator.dart';
import 'interpolators.dart';
import 'motion_path.dart';
import 'timing_condition.dart';

part 'smil_animation_value_computation.dart';
part 'smil_animation_runtime.dart';
part 'smil_animation_curves.dart';

/// SMIL animation type
enum SmilAnimationType {
  /// `<animate>` - attribute animation
  animate,

  /// `<animateTransform>` - transform animation
  animateTransform,

  /// `<animateMotion>` - motion along a path animation
  animateMotion,

  /// `<set>` - instantaneous value assignment
  set,

  /// `<animateColor>` - color animation (deprecated, but may be encountered)
  animateColor,
}

/// Intermediate value calculation mode
enum SmilCalcMode {
  /// Linear interpolation between values
  linear,

  /// Discrete (step-based) - no interpolation
  discrete,

  /// Uniform speed (paced) - automatic keyTimes adjustment
  paced,

  /// Spline interpolation using keySplines
  spline,
}

/// Fill mode for CSS animation (extends SMIL with backwards/both)
enum SmilFillMode {
  /// Retain final value after animation (freeze)
  freeze,

  /// Return to base value after animation (remove)
  remove,

  /// Apply first keyframe values during delay (CSS backwards)
  backwards,

  /// Both freeze and backwards (CSS both)
  both,
}

/// Additive mode
enum SmilAdditiveMode {
  /// Replace the base value
  replace,

  /// Add to the base value
  sum,
}

/// Playback direction for repeats (CSS animation-direction compatibility)
enum SmilPlaybackDirection {
  /// Each iteration plays from 0 to 1
  normal,

  /// Each iteration plays from 1 to 0
  reverse,

  /// Alternating: 1st iteration normal, 2nd reverse, ...
  alternate,

  /// Alternating: 1st iteration reverse, 2nd normal, ...
  alternateReverse,
}

/// Base class for SMIL animation
class SmilAnimation {
  /// Creates a SMIL animation
  SmilAnimation({
    this.id,
    required this.type,
    required this.targetNode,
    required this.attributeName,
    required this.attributeType,
    this.transformType,
    this.from,
    this.to,
    this.by,
    this.values,
    this.keyTimes,
    this.keySplines,
    this.keySteps,
    required this.dur,
    this.begin = Duration.zero,
    this.end,
    this.repeatCount = 1.0,
    this.repeatDur,
    this.min,
    this.max,
    this.fillMode = SmilFillMode.remove,
    this.calcMode = SmilCalcMode.linear,
    this.playbackDirection = SmilPlaybackDirection.normal,
    this.additive = SmilAdditiveMode.replace,
    this.accumulate = false,
    this.beginConditions = const [],
    this.endConditions = const [],
    this.isPaused = false,
    this.documentOrder = 0,
  }) {
    // Validation
    if (values != null) {
      if (keyTimes != null && keyTimes!.length != values!.length) {
        throw ArgumentError('keyTimes length must match values length');
      }
      if (calcMode == SmilCalcMode.spline) {
        if (keySplines == null || keySplines!.length != values!.length - 1) {
          throw ArgumentError(
            'For spline mode, keySplines length must be values.length - 1',
          );
        }
      }

      // Generate keyTimes for paced mode if not explicitly specified.
      // Implementation based on Blink SVGAnimationElement::calculateKeyTimesForCalcModePaced()
      if (calcMode == SmilCalcMode.paced &&
          keyTimes == null &&
          values != null &&
          values!.length >= 2) {
        _pacedKeyTimes = _generatePacedKeyTimes();
      }
    }
  }

  /// Generates keyTimes for calcMode="paced" based on distances between values.
  /// Implementation based on Blink SVGAnimationElement::calculateKeyTimesForCalcModePaced()
  List<double>? _generatePacedKeyTimes() {
    if (values == null || values!.length < 2) return null;

    final calculator = DistanceCalculatorFactory.create(attributeType);
    final keyTimesForPaced = <double>[0.0];
    double totalDistance = 0.0;
    final distances = <double>[];

    // Compute distances between consecutive values
    for (int i = 0; i < values!.length - 1; i++) {
      final distance = calculator.distance(values![i], values![i + 1]);
      if (distance < 0) {
        // If the distance cannot be computed, return null.
        // This means paced mode is not supported for this type
        return null;
      }
      totalDistance += distance;
      distances.add(distance);
    }

    // If totalDistance is zero, all values are identical
    if (totalDistance == 0.0) {
      // Uniform distribution
      final step = 1.0 / (values!.length - 1);
      for (int i = 1; i < values!.length; i++) {
        keyTimesForPaced.add(i * step);
      }
      keyTimesForPaced[values!.length - 1] = 1.0;
      return keyTimesForPaced;
    }

    // Normalize distances into keyTimes.
    // Algorithm from Blink: keyTimesForPaced[n] = keyTimesForPaced[n-1] + distances[n] / totalDistance
    double cumulative = 0.0;
    for (int i = 0; i < distances.length; i++) {
      cumulative += distances[i] / totalDistance;
      keyTimesForPaced.add(cumulative);
    }

    // The last keyTime is always 1.0
    keyTimesForPaced[values!.length - 1] = 1.0;

    return keyTimesForPaced;
  }

  /// Animation ID (from xml:id or id attribute).
  /// Used for syncbase timing
  final String? id;

  /// Animation type
  final SmilAnimationType type;

  /// Target node to which the animation is applied
  final SvgNode targetNode;

  /// Name of the animated attribute
  final String attributeName;

  /// Attribute type (for correct interpolation)
  final SvgAttributeType attributeType;

  /// Transform type for animateTransform (translate, rotate, scale, etc.)
  final String? transformType;

  // === Animation values ===

  /// Initial value (from)
  final Object? from;

  /// Final value (to)
  final Object? to;

  /// Relative change (by)
  final Object? by;

  /// List of keyframe values (values) for keyframe animation
  final List<Object>? values;

  /// Timestamps for values (from 0.0 to 1.0)
  final List<double>? keyTimes;

  /// Generated keyTimes for paced mode (if calcMode == paced and keyTimes are not specified)
  List<double>? _pacedKeyTimes;

  /// Control points of cubic Bezier curves for spline interpolation.
  /// Each element represents a curve between two adjacent keyframes
  final List<CubicBezier>? keySplines;

  /// Steps for discrete interpolation (CSS steps()).
  /// One entry per interval between adjacent keyframes
  final List<StepTiming>? keySteps;

  // === Timing ===

  /// Duration of one animation iteration
  final Duration dur;

  /// Animation start time
  final Duration begin;

  /// Animation end time (if null, depends on repeatCount/repeatDur)
  final Duration? end;

  /// Number of repetitions (double.infinity for indefinite)
  final double repeatCount;

  /// Total repeat duration
  final Duration? repeatDur;

  /// Minimum active duration constraint (per SMIL spec)
  /// If specified, the active duration is extended to at least this value.
  /// During the extended period, fill behavior applies.
  final Duration? min;

  /// Maximum active duration constraint (per SMIL spec)
  /// If specified, the active duration is truncated to at most this value.
  /// Per SMIL: when min > max, min takes precedence.
  final Duration? max;

  /// Animation begin conditions (parsed from begin attribute)
  final List<TimingCondition> beginConditions;

  /// Animation end conditions (parsed from end attribute)
  final List<TimingCondition> endConditions;

  // === Behavior ===

  /// Fill mode after animation ends
  final SmilFillMode fillMode;

  /// Intermediate value calculation mode
  final SmilCalcMode calcMode;

  /// Playback direction for iterations (used for CSS animation-direction)
  final SmilPlaybackDirection playbackDirection;

  /// Mode for adding to the base value
  final SmilAdditiveMode additive;

  /// Accumulate values between iterations
  final bool accumulate;

  /// Whether the animation is paused (CSS animation-play-state)
  final bool isPaused;

  /// Document order index for animation sandwich model priority resolution
  /// Per SVG SMIL spec, later animations (higher index) have higher priority
  final int documentOrder;

  // === Runtime state ===

  /// Whether the animation is currently active
  bool _isActive = false;

  /// Current iteration
  int _currentIteration = 0;

  /// Local time within the current iteration
  Duration _localTime = Duration.zero;

  /// Last computed value
  Object? _lastValue;

  /// Resolved begin time from syncbase conditions (overrides `begin` if set)
  Duration? _resolvedBeginTime;

  /// Whether the animation is active
  bool get isActive => _isActive;

  /// Current iteration
  int get currentIteration => _currentIteration;

  /// Local time
  Duration get localTime => _localTime;
  Duration getEffectiveBeginTime() {
    return _resolvedBeginTime ?? begin;
  }

  /// Set resolved begin time (used by SvgTimeline for syncbase timing)
  void setResolvedBeginTime(Duration time) {
    _resolvedBeginTime = time;
  }

  /// Compute the effective end time of the animation
  /// Per SVG/SMIL spec: when both repeatCount and repeatDur are specified,
  /// the active duration is min(repeatCount * dur, repeatDur).
  /// When one is indefinite, the other determines the duration.
  /// When end attribute is specified, it also constrains the active duration.
  Duration getEffectiveEndTime() {
    final effectiveBegin = getEffectiveBeginTime();

    // Calculate active duration per SMIL spec
    final activeDuration = _computeActiveDuration();
    return effectiveBegin + activeDuration;
  }

  /// Compute the simple duration (duration of one iteration)
  /// Per SMIL spec: if dur is 0 or unspecified, simple duration is 0
  Duration get simpleDuration {
    if (dur.inMicroseconds <= 0) {
      return Duration.zero;
    }
    return dur;
  }

  /// Compute the active duration according to SMIL spec rules:
  /// 1. Compute repeat duration from repeatCount and repeatDur
  /// 2. Consider end attribute if specified
  /// 3. Apply min/max constraints
  ///
  /// Formula: activeDur = max(min, min(computedActiveDur, max))
  /// When min > max, min takes precedence (per SMIL spec)
  Duration _computeActiveDuration() {
    // Handle zero/instant duration
    if (dur.inMicroseconds <= 0) {
      // Per SMIL spec, zero duration means instant animation
      return _applyMinMaxConstraints(Duration.zero);
    }

    // Step 1: Compute repeat duration
    final Duration repeatDuration;
    final repeatCountDuration = repeatCount.isInfinite
        ? null
        : _multiplyDuration(dur, repeatCount);

    final repeatDurDuration = repeatDur;

    // Both specified - take minimum
    if (repeatCountDuration != null && repeatDurDuration != null) {
      repeatDuration = repeatCountDuration < repeatDurDuration
          ? repeatCountDuration
          : repeatDurDuration;
    } else if (repeatDurDuration != null) {
      // Only repeatDur specified (repeatCount is indefinite)
      repeatDuration = repeatDurDuration;
    } else if (repeatCountDuration != null) {
      // Only repeatCount specified (repeatDur is null)
      repeatDuration = repeatCountDuration;
    } else {
      // Both indefinite
      repeatDuration = const Duration(days: 365 * 100); // "infinity"
    }

    // Step 2: Consider end attribute
    // Per SMIL spec: activeDur = min(repeatDur, max(end - begin, 0))
    // when both end and repeatDur are specified
    Duration computedActiveDur = repeatDuration;

    if (end != null) {
      final effectiveBegin = getEffectiveBeginTime();
      final endOffset = end! - effectiveBegin;
      final endBasedDuration = endOffset.isNegative ? Duration.zero : endOffset;

      // Take minimum of repeat duration and end-based duration
      if (endBasedDuration < computedActiveDur) {
        computedActiveDur = endBasedDuration;
      }
    }

    // Step 3: Apply min/max constraints
    return _applyMinMaxConstraints(computedActiveDur);
  }

  /// Apply min/max timing constraints per SMIL spec:
  /// result = max(min, min(activeDur, max))
  /// When min > max, min takes precedence.
  Duration _applyMinMaxConstraints(Duration activeDur) {
    Duration result = activeDur;

    // Apply max constraint first
    if (max != null && result > max!) {
      result = max!;
    }

    // Apply min constraint (takes precedence over max per SMIL spec)
    if (min != null && result < min!) {
      result = min!;
    }

    return result;
  }

  /// Multiply a Duration by a double with high precision
  /// Uses microseconds to maintain precision for fractional repeatCount
  static Duration _multiplyDuration(Duration dur, double multiplier) {
    if (multiplier.isInfinite || multiplier.isNaN) {
      return const Duration(days: 365 * 100); // "infinity"
    }
    // Use double math and round to avoid precision loss
    final micros = dur.inMicroseconds * multiplier;
    return Duration(microseconds: micros.round());
  }

  /// Compute the animation value at time t ∈ [0, 1] within an iteration.
  ///
  /// The parameter [t] represents progress within one animation iteration.
  /// Respects calcMode when choosing the interpolation method.
  /// [completedRepeats] - the number of completed repetitions (for accumulate)
  Object? computeValue(double t, {int completedRepeats = 0}) {
    final raw = computeRawValue(t, completedRepeats: completedRepeats);
    return _applyAdditive(raw);
  }

  /// Compute the raw animated value without applying additive stacking.
  ///
  /// Used by the sandwich model so it can control how additive chaining works
  /// across multiple animations targeting the same attribute.
  Object? computeRawValue(double t, {int completedRepeats = 0}) {
    // For animateMotion, use special logic
    if (type == SmilAnimationType.animateMotion) {
      return _computeMotionValue(t, completedRepeats: completedRepeats);
    }

    // For <set> elements, always return the 'to' value during the active period
    if (type == SmilAnimationType.set) {
      return to;
    }

    // For discrete calcMode - no interpolation
    if (calcMode == SmilCalcMode.discrete) {
      final animValue = _computeDiscreteValue(t);
      return _applyAccumulate(animValue, completedRepeats);
    }

    // For values-based animation
    if (values != null && values!.isNotEmpty) {
      final animValue = _computeValuesBasedValue(t);
      return _applyAccumulate(animValue, completedRepeats);
    }

    // For from/to/by animation
    final animValue = _computeSimpleValue(t);
    return _applyAccumulate(animValue, completedRepeats);
  }

  void updateForTime(Duration globalTime) {
    // If animation is paused, don't update
    if (isPaused) {
      return;
    }

    final effectiveBegin = getEffectiveBeginTime();
    final effectiveEnd = getEffectiveEndTime();
    final durMicros = dur.inMicroseconds;

    // Guard against zero/invalid duration
    if (durMicros <= 0) {
      // Per SMIL spec, zero duration means instant animation
      // Just apply the final value if within active period
      if (globalTime >= effectiveBegin && globalTime < effectiveEnd) {
        _isActive = true;
        _lastValue = computeValue(1.0, completedRepeats: 0);
        if (_lastValue != null) {
          _applyValue(_lastValue!);
        }
      } else {
        _isActive = false;
        if (fillMode == SmilFillMode.freeze || fillMode == SmilFillMode.both) {
          _lastValue = computeValue(1.0, completedRepeats: 0);
          if (_lastValue != null) {
            _applyValue(_lastValue!);
          }
        } else {
          _clearValue();
        }
      }
      return;
    }

    // Handle negative delay - start animation partway through
    // A negative begin means we need to compute as if time already passed
    final adjustedTime = globalTime;
    final hasNegativeDelay = effectiveBegin.isNegative;

    // Before animation start time
    if (adjustedTime < effectiveBegin) {
      // Animation hasn't started yet
      if (_isActive) {
        _isActive = false;
      }

      // For backwards/both fill mode, apply initial keyframe values during delay
      if (fillMode == SmilFillMode.backwards || fillMode == SmilFillMode.both) {
        final initialT = _resolveDirectedProgress(0.0, 0);
        final initialValue = computeValue(initialT, completedRepeats: 0);
        if (initialValue != null) {
          _applyValue(initialValue);
        }
      } else {
        _clearValue();
      }
      return;
    }

    // After animation end time
    if (adjustedTime >= effectiveEnd) {
      if (_isActive) {
        _isActive = false;
      }

      // Apply fill mode at end
      if (fillMode == SmilFillMode.freeze || fillMode == SmilFillMode.both) {
        final finalProgress = _computeProgressAtEnd(
          effectiveBegin: effectiveBegin,
          effectiveEnd: effectiveEnd,
        );
        final finalValue = computeValue(
          finalProgress.t,
          completedRepeats: finalProgress.completedRepeats,
        );
        if (finalValue != null) {
          _applyValue(finalValue);
        }
      } else {
        _clearValue();
      }
      return;
    }

    // Animation is active
    _isActive = true;

    // Compute local time and iteration
    var timeSinceBegin = adjustedTime - effectiveBegin;

    // For negative delays, the elapsed time at t=0 is already |negativeDelay|
    if (hasNegativeDelay) {
      timeSinceBegin = adjustedTime + effectiveBegin.abs();
    }

    final elapsedMicros = timeSinceBegin.inMicroseconds;

    // Check if we're in the min-extended period (past repeat duration but still active)
    // This happens when min extends the active duration beyond the repeat iterations
    final repeatDuration = _computeRepeatDuration();
    if (timeSinceBegin >= repeatDuration) {
      // We're in the min-extended period - apply fill behavior
      _currentIteration = repeatCount.isFinite
          ? repeatCount.toInt()
          : elapsedMicros ~/ durMicros;
      _localTime = dur; // At end of iteration
      final finalT = _resolveDirectedProgress(1.0, _currentIteration - 1);
      _lastValue = computeValue(
        finalT,
        completedRepeats: _currentIteration - 1,
      );
      if (_lastValue != null) {
        _applyValue(_lastValue!);
      }
      return;
    }

    _currentIteration = elapsedMicros ~/ durMicros;
    final iterationMicros = elapsedMicros % durMicros;
    _localTime = Duration(microseconds: iterationMicros);

    // Progress within iteration (0.0 - 1.0)
    // Use high-precision calculation with proper boundary handling
    double baseT = iterationMicros / durMicros;

    // Handle boundary precision: if very close to 1.0, snap to exact 1.0
    // This prevents floating-point drift like 0.999999... or 1.000001...
    const epsilon = 1e-10;
    if (baseT > 1.0 - epsilon) {
      baseT = 1.0;
    } else if (baseT < epsilon) {
      baseT = 0.0;
    }

    final t = _resolveDirectedProgress(baseT, _currentIteration);

    // Compute value with completed repetitions
    _lastValue = computeValue(t, completedRepeats: _currentIteration);

    // Apply value
    if (_lastValue != null) {
      _applyValue(_lastValue!);
    }
  }

  /// Compute the repeat duration (before min/max and end constraints)
  /// This is used to determine if we're in the min-extended period
  Duration _computeRepeatDuration() {
    if (dur.inMicroseconds <= 0) {
      return Duration.zero;
    }

    final repeatCountDuration = repeatCount.isInfinite
        ? null
        : _multiplyDuration(dur, repeatCount);

    final repeatDurDuration = repeatDur;

    if (repeatCountDuration != null && repeatDurDuration != null) {
      return repeatCountDuration < repeatDurDuration
          ? repeatCountDuration
          : repeatDurDuration;
    } else if (repeatDurDuration != null) {
      return repeatDurDuration;
    } else if (repeatCountDuration != null) {
      return repeatCountDuration;
    } else {
      return const Duration(days: 365 * 100);
    }
  }

  /// Apply the value to the attribute.
  /// Reset animation state to initial
  void reset() {
    _isActive = false;
    _currentIteration = 0;
    _localTime = Duration.zero;
    _lastValue = null;
    _clearValue();
  }

  @override
  String toString() {
    return 'SmilAnimation('
        'type: $type, '
        'attribute: $attributeName, '
        'dur: $dur, '
        'active: $_isActive'
        ')';
  }
}
