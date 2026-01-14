import 'package:flutter/foundation.dart';

import '../svg_dom.dart';
import 'interpolators.dart';
import 'motion_path.dart';
import 'timing_condition.dart';

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

/// Режим заполнения после окончания анимации
enum SmilFillMode {
  /// Сохранить последнее значение (freeze)
  freeze,

  /// Вернуться к базовому значению (remove)
  remove,
}

/// Режим добавления (additive)
enum SmilAdditiveMode {
  /// Заменить базовое значение
  replace,

  /// Добавить к базовому значению
  sum,
}

/// Базовый класс для SMIL анимации
class SmilAnimation {
  /// Создаёт SMIL анимацию
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
    required this.dur,
    this.begin = Duration.zero,
    this.end,
    this.repeatCount = 1.0,
    this.repeatDur,
    this.fillMode = SmilFillMode.remove,
    this.calcMode = SmilCalcMode.linear,
    this.additive = SmilAdditiveMode.replace,
    this.accumulate = false,
    this.beginConditions = const [],
    this.endConditions = const [],
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
    }
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

  /// Контрольные точки кубических кривых Безье для spline интерполяции
  /// Каждый элемент представляет кривую между двумя соседними keyframes
  final List<CubicBezier>? keySplines;

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

  /// Условия начала анимации (parsed from begin attribute)
  final List<TimingCondition> beginConditions;

  /// Условия окончания анимации (parsed from end attribute)
  final List<TimingCondition> endConditions;

  // === Поведение ===

  /// Режим заполнения после окончания
  final SmilFillMode fillMode;

  /// Режим вычисления промежуточных значений
  final SmilCalcMode calcMode;

  /// Режим добавления к базовому значению
  final SmilAdditiveMode additive;

  /// Накапливать ли значения между итерациями
  final bool accumulate;

  // === Runtime состояние ===

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

  /// Get effective begin time (resolved from syncbase conditions if available)
  Duration getEffectiveBeginTime() {
    return _resolvedBeginTime ?? begin;
  }

  /// Set resolved begin time (used by SvgTimeline for syncbase timing)
  void setResolvedBeginTime(Duration time) {
    _resolvedBeginTime = time;
  }

  /// Вычислить эффективное конечное время анимации
  Duration getEffectiveEndTime() {
    final effectiveBegin = getEffectiveBeginTime();

    if (end != null) {
      return end!;
    }

    if (repeatDur != null) {
      return effectiveBegin + repeatDur!;
    }

    if (repeatCount.isInfinite) {
      return const Duration(days: 365 * 100); // "бесконечность"
    }

    return effectiveBegin + dur * repeatCount;
  }

  /// Вычислить значение анимации в момент времени t ∈ [0, 1] внутри итерации
  ///
  /// Параметр [t] представляет прогресс внутри одной итерации анимации.
  /// Учитывает calcMode для выбора метода интерполяции.
  Object? computeValue(double t) {
    // Для animateMotion используем специальную логику
    if (type == SmilAnimationType.animateMotion) {
      return _computeMotionValue(t);
    }

    // Для discrete calcMode - без интерполяции
    if (calcMode == SmilCalcMode.discrete) {
      return _computeDiscreteValue(t);
    }

    // Для values-based анимации
    if (values != null && values!.isNotEmpty) {
      return _computeValuesBasedValue(t);
    }

    // Для from/to/by анимации
    return _computeSimpleValue(t);
  }

  /// Вычислить дискретное значение (без интерполяции)
  Object? _computeDiscreteValue(double t) {
    if (values != null && values!.isNotEmpty) {
      if (keyTimes != null) {
        // Найти соответствующий keyframe
        for (int i = 0; i < keyTimes!.length - 1; i++) {
          if (t >= keyTimes![i] && t < keyTimes![i + 1]) {
            return values![i];
          }
        }
        // Последнее значение
        return values!.last;
      }
      // Без keyTimes - равномерное распределение
      final segmentCount = values!.length;
      final index = (t * segmentCount).floor().clamp(0, values!.length - 1);
      return values![index];
    }

    // from/to - возвращаем from до t=1.0, потом to
    return t >= 1.0 ? (to ?? from) : from;
  }

  /// Вычислить значение для values-based анимации
  Object? _computeValuesBasedValue(double t) {
    if (values!.length == 1) {
      return values![0];
    }

    // Определяем между какими keyframes мы находимся
    int fromIndex = 0;
    int toIndex = 1;
    double segmentProgress = t;

    if (keyTimes != null) {
      // С явными keyTimes
      for (int i = 0; i < keyTimes!.length - 1; i++) {
        if (t >= keyTimes![i] && t <= keyTimes![i + 1]) {
          fromIndex = i;
          toIndex = i + 1;
          final segmentStart = keyTimes![i];
          final segmentEnd = keyTimes![i + 1];
          segmentProgress = segmentEnd > segmentStart
              ? (t - segmentStart) / (segmentEnd - segmentStart)
              : 0.0;
          break;
        }
      }
    } else {
      // Без keyTimes - равномерное распределение
      final segmentCount = values!.length - 1;
      final segmentIndex = (t * segmentCount).floor().clamp(
        0,
        segmentCount - 1,
      );
      fromIndex = segmentIndex;
      toIndex = segmentIndex + 1;
      segmentProgress = (t * segmentCount) - segmentIndex;
    }

    // Применяем easing если есть keySplines
    if (calcMode == SmilCalcMode.spline && keySplines != null) {
      final spline = keySplines![fromIndex];
      segmentProgress = spline.transform(segmentProgress);
    }

    // Интерполируем между значениями
    return _interpolate(values![fromIndex], values![toIndex], segmentProgress);
  }

  /// Вычислить значение для простой from/to/by анимации
  Object? _computeSimpleValue(double t) {
    Object? fromValue = from;
    Object? toValue = to;

    // Если нет from, используем базовое значение атрибута
    if (fromValue == null) {
      final attr = targetNode.getAttribute(attributeName);
      fromValue = attr?.baseValue;
    }

    // Если есть by вместо to, вычисляем to
    if (toValue == null && by != null && fromValue != null) {
      toValue = _addValues(fromValue, by!);
    }

    if (fromValue == null || toValue == null) {
      return toValue ?? fromValue;
    }

    return _interpolate(fromValue, toValue, t);
  }

  /// Вычислить значение для animateMotion
  Object? _computeMotionValue(double t) {
    // from содержит path data, to содержит rotate mode
    final pathData = from as String?;
    if (pathData == null || pathData.trim().isEmpty) {
      return null;
    }

    try {
      // Создаём MotionPath (можно кешировать в будущем)
      final motionPath = MotionPath(pathData);

      // values содержит keyPoints если они есть
      final keyPoints = values?.map((v) => v as double).toList();

      // Получаем точку на пути
      final point = keyPoints != null && keyPoints.isNotEmpty
          ? motionPath.getPointWithKeyPoints(t, keyPoints, keyTimes)
          : motionPath.getPointAtTime(t);

      // Формируем transform строку
      final rotateMode = to as String?;
      final translatePart =
          'translate(${point.position.dx}, ${point.position.dy})';

      if (rotateMode == null || rotateMode.isEmpty) {
        return translatePart;
      }

      if (rotateMode == 'auto') {
        // Поворачиваем по касательной к пути
        final angleDegrees = MotionPath.radiansToDegrees(point.angle);
        return '$translatePart rotate($angleDegrees)';
      }

      if (rotateMode == 'auto-reverse') {
        // Поворачиваем по касательной + 180°
        final angleDegrees = MotionPath.radiansToDegrees(point.angle) + 180;
        return '$translatePart rotate($angleDegrees)';
      }

      // Фиксированный угол в градусах
      return '$translatePart rotate($rotateMode)';
    } catch (e) {
      return null;
    }
  }

  /// Интерполировать между двумя значениями
  ///
  /// Использует Interpolators для типизированной интерполяции
  @protected
  Object? _interpolate(Object from, Object to, double t) {
    return Interpolators.interpolate(from, to, t, attributeType);
  }

  /// Сложить два значения (для by)
  @protected
  Object? _addValues(Object base, Object delta) {
    return Interpolators.add(base, delta, attributeType);
  }

  /// Обновить состояние анимации для заданного глобального времени
  void updateForTime(Duration globalTime) {
    final effectiveBegin = getEffectiveBeginTime();
    final effectiveEnd = getEffectiveEndTime();

    // Проверяем, находимся ли мы в активном временном окне
    if (globalTime < effectiveBegin) {
      // Анимация ещё не началась
      if (_isActive) {
        _isActive = false;
        _clearValue();
      }
      return;
    }

    if (globalTime >= effectiveEnd) {
      // Анимация закончилась
      if (_isActive) {
        _isActive = false;
      }

      // Применяем fill mode
      if (fillMode == SmilFillMode.freeze) {
        // Вычисляем финальное значение (t=1.0)
        final finalValue = computeValue(1.0);
        if (finalValue != null) {
          _applyValue(finalValue);
        }
      } else {
        // Убираем анимированное значение
        _clearValue();
      }
      return;
    }

    // Анимация активна
    _isActive = true;

    // Вычисляем локальное время и итерацию
    final timeSinceBegin = globalTime - effectiveBegin;
    final durMicros = dur.inMicroseconds;

    if (durMicros > 0) {
      _currentIteration = timeSinceBegin.inMicroseconds ~/ durMicros;
      final iterationMicros = timeSinceBegin.inMicroseconds % durMicros;
      _localTime = Duration(microseconds: iterationMicros);

      // Прогресс внутри итерации (0.0 - 1.0)
      final t = iterationMicros / durMicros;

      // Вычисляем значение
      _lastValue = computeValue(t);

      // Применяем значение
      if (_lastValue != null) {
        _applyValue(_lastValue!);
      }
    }
  }

  /// Применить значение к атрибуту
  void _applyValue(Object value) {
    final attr = targetNode.getAttribute(attributeName);
    if (attr != null) {
      attr.setAnimatedValue(value);
    } else {
      // Если атрибута нет, создаем его
      // Это происходит для animateTransform когда у элемента изначально нет transform
      targetNode.setAttribute(attributeName, value, type: attributeType);
      final newAttr = targetNode.getAttribute(attributeName);
      if (newAttr != null) {
        newAttr.setAnimatedValue(value);
      }
    }
  }

  /// Убрать анимированное значение
  void _clearValue() {
    final attr = targetNode.getAttribute(attributeName);
    if (attr != null) {
      attr.clearAnimation();
    }
  }

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

/// Кубическая кривая Безье для keySplines
@immutable
class CubicBezier {
  /// Создаёт кубическую кривую Безье
  const CubicBezier(this.x1, this.y1, this.x2, this.y2);

  /// Контрольная точка 1 - X
  final double x1;

  /// Контрольная точка 1 - Y
  final double y1;

  /// Контрольная точка 2 - X
  final double x2;

  /// Контрольная точка 2 - Y
  final double y2;

  /// Вычислить значение кривой для t ∈ [0, 1]
  ///
  /// Использует приближённый метод Ньютона для решения
  double transform(double t) {
    // Для линейной кривой (0 0 1 1) - оптимизация
    if (x1 == 0 && y1 == 0 && x2 == 1 && y2 == 1) {
      return t;
    }

    // Метод Ньютона для поиска X по t
    double x = t;
    for (int i = 0; i < 8; i++) {
      final curveX = _bezierX(x);
      final diff = curveX - t;
      if (diff.abs() < 1e-6) break;

      final derivative = _bezierXDerivative(x);
      if (derivative.abs() < 1e-6) break;

      x -= diff / derivative;
    }

    return _bezierY(x);
  }

  /// Вычислить X координату кривой Безье
  double _bezierX(double t) {
    final t2 = t * t;
    final t3 = t2 * t;
    final mt = 1 - t;
    final mt2 = mt * mt;

    return 3 * mt2 * t * x1 + 3 * mt * t2 * x2 + t3;
  }

  /// Вычислить Y координату кривой Безье
  double _bezierY(double t) {
    final t2 = t * t;
    final t3 = t2 * t;
    final mt = 1 - t;
    final mt2 = mt * mt;

    return 3 * mt2 * t * y1 + 3 * mt * t2 * y2 + t3;
  }

  /// Производная X по t
  double _bezierXDerivative(double t) {
    final mt = 1 - t;
    return 3 * mt * mt * x1 + 6 * mt * t * (x2 - x1) + 3 * t * t * (1 - x2);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CubicBezier &&
          x1 == other.x1 &&
          y1 == other.y1 &&
          x2 == other.x2 &&
          y2 == other.y2;

  @override
  int get hashCode => Object.hash(x1, y1, x2, y2);

  @override
  String toString() => 'CubicBezier($x1, $y1, $x2, $y2)';
}
