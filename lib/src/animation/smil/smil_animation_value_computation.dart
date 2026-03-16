part of 'smil_animation.dart';

extension SmilAnimationValueComputationExtension on SmilAnimation {
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

    // Используем paced keyTimes если они есть, иначе обычные keyTimes
    final effectiveKeyTimes = _pacedKeyTimes ?? keyTimes;

    if (effectiveKeyTimes != null) {
      // С явными keyTimes (или сгенерированными для paced)
      for (int i = 0; i < effectiveKeyTimes.length - 1; i++) {
        if (t >= effectiveKeyTimes[i] && t <= effectiveKeyTimes[i + 1]) {
          fromIndex = i;
          toIndex = i + 1;
          final segmentStart = effectiveKeyTimes[i];
          final segmentEnd = effectiveKeyTimes[i + 1];
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

    // Применяем easing если есть keySplines или keySteps
    if (calcMode == SmilCalcMode.spline && keySplines != null) {
      final spline = keySplines![fromIndex];
      segmentProgress = spline.transform(segmentProgress);
    } else if (keySteps != null && fromIndex < keySteps!.length) {
      final step = keySteps![fromIndex];
      segmentProgress = step.transform(segmentProgress);
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

  /// Применить accumulate="sum" - добавить финальное значение * количество повторений
  /// Реализация основана на Blink SVGAnimationElement::animateAdditiveNumber()
  @protected
  Object? _applyAccumulate(Object? animValue, int completedRepeats) {
    if (!accumulate || completedRepeats == 0 || animValue == null) {
      return animValue;
    }

    // Получаем финальное значение анимации (в конце одной итерации, t=1.0)
    final finalValue = _computeFinalValue();

    if (finalValue == null) {
      return animValue;
    }

    // Для accumulate="sum" добавляем финальное значение * количество завершённых повторений
    // Как в Blink: number += toAtEndOfDurationNumber * repeatCount
    Object accumulated = animValue;
    for (int i = 0; i < completedRepeats; i++) {
      final result = Interpolators.add(accumulated, finalValue, attributeType);
      if (result == null) break;
      accumulated = result;
    }

    return accumulated;
  }

  /// Вычислить финальное значение анимации (t=1.0)
  @protected
  Object? _computeFinalValue() {
    // Для values-based: последнее значение
    if (values != null && values!.isNotEmpty) {
      return values!.last;
    }
    // Для from/to: значение to
    return to ?? from;
  }

  /// Применить additive="sum" - добавить к базовому значению элемента
  /// Реализация основана на Blink SVGAnimationElement::animateAdditiveNumber()
  @protected
  Object? _applyAdditive(Object? animValue) {
    if (animValue == null) return null;

    // animValue уже не null здесь
    final animValueNonNull = animValue;

    // Если additive="replace" или это ToAnimation, просто возвращаем значение
    // В нашей реализации пока нет явного ToAnimation, но можно проверить
    if (additive == SmilAdditiveMode.replace) {
      return animValueNonNull;
    }

    // additive="sum" - добавляем к базовому значению
    // Получаем базовое значение из targetNode
    final baseAttr = targetNode.getAttribute(attributeName);
    final baseValue = baseAttr?.baseValue;

    if (baseValue == null) {
      // Если базового значения нет, возвращаем animValue
      return animValueNonNull;
    }

    // Добавляем animValue к baseValue
    return Interpolators.add(baseValue, animValueNonNull, attributeType);
  }

  /// Обновить состояние анимации для заданного глобального времени
}
