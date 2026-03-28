import 'package:flutter/foundation.dart';

import '../svg_dom.dart';
import 'distance_calculator.dart';
import 'interpolators.dart';
import 'motion_path.dart';
import 'timing_condition.dart';

part 'smil_animation_value_computation.dart';
part 'smil_animation_runtime.dart';
part 'smil_animation_curves.dart';

/// Тип SMIL анимации
enum SmilAnimationType {
  /// <animate> - анимация атрибута
  animate,

  /// <animateTransform> - анимация трансформации
  animateTransform,

  /// <animateMotion> - анимация движения по пути
  animateMotion,

  /// <set> - одномоментная установка значения
  set,

  /// <animateColor> - анимация цвета (deprecated, но может встречаться)
  animateColor,
}

/// Режим вычисления промежуточных значений
enum SmilCalcMode {
  /// Линейная интерполяция между значениями
  linear,

  /// Дискретная (ступенчатая) - без интерполяции
  discrete,

  /// Равномерная скорость (paced) - автоматическая настройка keyTimes
  paced,

  /// Сплайновая интерполяция с использованием keySplines
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

/// Режим добавления (additive)
enum SmilAdditiveMode {
  /// Заменить базовое значение
  replace,

  /// Добавить к базовому значению
  sum,
}

/// Направление проигрывания повторов (CSS animation-direction compatibility)
enum SmilPlaybackDirection {
  /// Каждая итерация проигрывается от 0 до 1
  normal,

  /// Каждая итерация проигрывается от 1 до 0
  reverse,

  /// Чередование: 1-я итерация normal, 2-я reverse, ...
  alternate,

  /// Чередование: 1-я итерация reverse, 2-я normal, ...
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
    // Валидация
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

      // Генерируем keyTimes для paced mode, если они не заданы явно
      // Реализация основана на Blink SVGAnimationElement::calculateKeyTimesForCalcModePaced()
      if (calcMode == SmilCalcMode.paced &&
          keyTimes == null &&
          values != null &&
          values!.length >= 2) {
        _pacedKeyTimes = _generatePacedKeyTimes();
      }
    }
  }

  /// Генерирует keyTimes для calcMode="paced" на основе расстояний между значениями
  /// Реализация основана на Blink SVGAnimationElement::calculateKeyTimesForCalcModePaced()
  List<double>? _generatePacedKeyTimes() {
    if (values == null || values!.length < 2) return null;

    final calculator = DistanceCalculatorFactory.create(attributeType);
    final keyTimesForPaced = <double>[0.0];
    double totalDistance = 0.0;
    final distances = <double>[];

    // Вычисляем расстояния между последовательными значениями
    for (int i = 0; i < values!.length - 1; i++) {
      final distance = calculator.distance(values![i], values![i + 1]);
      if (distance < 0) {
        // Если расстояние не может быть вычислено, возвращаем null
        // Это означает, что paced mode не поддерживается для этого типа
        return null;
      }
      totalDistance += distance;
      distances.add(distance);
    }

    // Если totalDistance равен нулю, все значения одинаковые
    if (totalDistance == 0.0) {
      // Равномерное распределение
      final step = 1.0 / (values!.length - 1);
      for (int i = 1; i < values!.length; i++) {
        keyTimesForPaced.add(i * step);
      }
      keyTimesForPaced[values!.length - 1] = 1.0;
      return keyTimesForPaced;
    }

    // Нормализуем расстояния в keyTimes
    // Алгоритм из Blink: keyTimesForPaced[n] = keyTimesForPaced[n-1] + distances[n] / totalDistance
    double cumulative = 0.0;
    for (int i = 0; i < distances.length; i++) {
      cumulative += distances[i] / totalDistance;
      keyTimesForPaced.add(cumulative);
    }

    // Последний keyTime всегда 1.0
    keyTimesForPaced[values!.length - 1] = 1.0;

    return keyTimesForPaced;
  }

  /// ID анимации (из атрибута xml:id или id)
  /// Используется для syncbase timing
  final String? id;

  /// Тип анимации
  final SmilAnimationType type;

  /// Целевой узел, к которому применяется анимация
  final SvgNode targetNode;

  /// Имя анимируемого атрибута
  final String attributeName;

  /// Тип атрибута (для корректной интерполяции)
  final SvgAttributeType attributeType;

  /// Тип трансформации для animateTransform (translate, rotate, scale, etc.)
  final String? transformType;

  // === Значения анимации ===

  /// Начальное значение (from)
  final Object? from;

  /// Конечное значение (to)
  final Object? to;

  /// Относительное изменение (by)
  final Object? by;

  /// Список ключевых значений (values) для keyframe анимации
  final List<Object>? values;

  /// Временные метки для values (от 0.0 до 1.0)
  final List<double>? keyTimes;

  /// Сгенерированные keyTimes для paced mode (если calcMode == paced и keyTimes не заданы)
  List<double>? _pacedKeyTimes;

  /// Контрольные точки кубических кривых Безье для spline интерполяции
  /// Каждый элемент представляет кривую между двумя соседними keyframes
  final List<CubicBezier>? keySplines;

  /// Шаги для дискретной интерполяции (CSS steps())
  /// Содержится по одному на каждый интервал между соседними keyframes
  final List<StepTiming>? keySteps;

  // === Тайминг ===

  /// Длительность одной итерации анимации
  final Duration dur;

  /// Время начала анимации
  final Duration begin;

  /// Время окончания анимации (если null, зависит от repeatCount/repeatDur)
  final Duration? end;

  /// Количество повторений (double.infinity для indefinite)
  final double repeatCount;

  /// Общая длительность повторений
  final Duration? repeatDur;

  /// Minimum active duration constraint (per SMIL spec)
  /// If specified, the active duration is extended to at least this value.
  /// During the extended period, fill behavior applies.
  final Duration? min;

  /// Maximum active duration constraint (per SMIL spec)
  /// If specified, the active duration is truncated to at most this value.
  /// Per SMIL: when min > max, min takes precedence.
  final Duration? max;

  /// Условия начала анимации (parsed from begin attribute)
  final List<TimingCondition> beginConditions;

  /// Условия окончания анимации (parsed from end attribute)
  final List<TimingCondition> endConditions;

  // === Поведение ===

  /// Режим заполнения после окончания
  final SmilFillMode fillMode;

  /// Режим вычисления промежуточных значений
  final SmilCalcMode calcMode;

  /// Направление проигрывания итераций (используется для CSS animation-direction)
  final SmilPlaybackDirection playbackDirection;

  /// Режим добавления к базовому значению
  final SmilAdditiveMode additive;

  /// Accumulate values between iterations
  final bool accumulate;

  /// Whether the animation is paused (CSS animation-play-state)
  final bool isPaused;

  /// Document order index for animation sandwich model priority resolution
  /// Per SVG SMIL spec, later animations (higher index) have higher priority
  final int documentOrder;

  // === Runtime state ===

  /// Активна ли анимация в данный момент
  bool _isActive = false;

  /// Текущая итерация
  int _currentIteration = 0;

  /// Локальное время внутри текущей итерации
  Duration _localTime = Duration.zero;

  /// Последнее вычисленное значение
  Object? _lastValue;

  /// Resolved begin time from syncbase conditions (overrides `begin` if set)
  Duration? _resolvedBeginTime;

  /// Активна ли анимация
  bool get isActive => _isActive;

  /// Текущая итерация
  int get currentIteration => _currentIteration;

  /// Локальное время
  Duration get localTime => _localTime;
  Duration getEffectiveBeginTime() {
    return _resolvedBeginTime ?? begin;
  }

  /// Set resolved begin time (used by SvgTimeline for syncbase timing)
  void setResolvedBeginTime(Duration time) {
    _resolvedBeginTime = time;
  }

  /// Вычислить эффективное конечное время анимации
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

  /// Вычислить значение анимации в момент времени t ∈ [0, 1] внутри итерации
  ///
  /// Параметр [t] представляет прогресс внутри одной итерации анимации.
  /// Учитывает calcMode для выбора метода интерполяции.
  /// [completedRepeats] - количество завершённых повторений (для accumulate)
  Object? computeValue(double t, {int completedRepeats = 0}) {
    // Для animateMotion используем специальную логику
    if (type == SmilAnimationType.animateMotion) {
      // animateMotion обычно не использует additive (он всегда суммирует трансформации)
      // Но применяем accumulate если нужно
      final motionValue = _computeMotionValue(
        t,
        completedRepeats: completedRepeats,
      );
      // Для motion accumulate применяется внутри _computeMotionValue через keyPoints
      return motionValue;
    }

    // For <set> elements, always return the 'to' value during the active period
    // Per SMIL spec: <set> provides a simple means of setting the value of an
    // attribute for a specified duration. It does not interpolate.
    if (type == SmilAnimationType.set) {
      // <set> simply sets the attribute to 'to' value
      final setValue = to;
      // Применяем additive="sum" (добавляем к базовому значению)
      return _applyAdditive(setValue);
    }

    // Для discrete calcMode - без интерполяции
    if (calcMode == SmilCalcMode.discrete) {
      final animValue = _computeDiscreteValue(t);

      // Применяем accumulate="sum"
      final accumulatedValue = _applyAccumulate(animValue, completedRepeats);

      // Применяем additive="sum"
      return _applyAdditive(accumulatedValue);
    }

    // Для values-based анимации
    if (values != null && values!.isNotEmpty) {
      final animValue = _computeValuesBasedValue(t);

      // Применяем accumulate="sum" (если есть завершённые повторения)
      final accumulatedValue = _applyAccumulate(animValue, completedRepeats);

      // Применяем additive="sum" (добавляем к базовому значению)
      return _applyAdditive(accumulatedValue);
    }

    // Для from/to/by анимации
    final animValue = _computeSimpleValue(t);

    // Применяем accumulate="sum" (если есть завершённые повторения)
    final accumulatedValue = _applyAccumulate(animValue, completedRepeats);

    // Применяем additive="sum" (добавляем к базовому значению)
    return _applyAdditive(accumulatedValue);
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

  /// Применить значение к атрибуту
  /// Сбросить состояние анимации в начальное
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
