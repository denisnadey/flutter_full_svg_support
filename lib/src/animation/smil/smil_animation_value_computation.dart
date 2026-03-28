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
  /// [completedRepeats] is used for accumulate="sum" support
  Object? _computeMotionValue(double t, {int completedRepeats = 0}) {
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

      // Handle discrete calcMode with keyPoints - waypoint jumping
      if (calcMode == SmilCalcMode.discrete &&
          keyPoints != null &&
          keyPoints.isNotEmpty &&
          keyTimes != null) {
        // For discrete mode, jump to keyPoint values without interpolation
        return _computeDiscreteMotionValue(
          t,
          motionPath,
          keyPoints,
          keyTimes!,
          completedRepeats,
        );
      }

      // Apply easing from keySplines if using spline calcMode
      double easedT = t;
      if (calcMode == SmilCalcMode.spline &&
          keySplines != null &&
          keySplines!.isNotEmpty) {
        // For motion with keyPoints, apply spline to the segment progress
        if (keyPoints != null && keyPoints.isNotEmpty && keyTimes != null) {
          easedT = _applyMotionSpline(t, keyPoints, keyTimes!, keySplines!);
        } else {
          // Simple spline application for whole path
          easedT = keySplines!.first.transform(t);
        }
      }

      // Получаем точку на пути
      final point = keyPoints != null && keyPoints.isNotEmpty
          ? motionPath.getPointWithKeyPoints(easedT, keyPoints, keyTimes)
          : motionPath.getPointAtTime(easedT);

      // Calculate position with accumulate="sum" support
      double posX = point.position.dx;
      double posY = point.position.dy;

      // Handle accumulate="sum" - add end position * completedRepeats
      if (accumulate && completedRepeats > 0) {
        final endPos = motionPath.getEndPosition();
        posX += endPos.dx * completedRepeats;
        posY += endPos.dy * completedRepeats;
      }

      // Формируем transform строку
      final rotateMode = to as String?;
      final translatePart = 'translate($posX, $posY)';

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

  /// Compute discrete motion value with keyPoints - jump to waypoints
  /// Per SMIL spec: discrete mode jumps between keyPoint values without interpolation
  Object? _computeDiscreteMotionValue(
    double t,
    MotionPath motionPath,
    List<double> keyPoints,
    List<double> keyTimes,
    int completedRepeats,
  ) {
    // Find which keyPoint we're at based on t and keyTimes
    int index = 0;
    for (int i = 0; i < keyTimes.length - 1; i++) {
      if (t >= keyTimes[i] && t < keyTimes[i + 1]) {
        index = i;
        break;
      }
    }
    // At t=1.0, use last keyPoint
    if (t >= 1.0) {
      index = keyPoints.length - 1;
    }

    // Get the exact keyPoint position (no interpolation for discrete)
    final keyPoint = keyPoints[index];
    final point = motionPath.getPointAtTime(keyPoint);

    // Calculate position with accumulate="sum" support
    double posX = point.position.dx;
    double posY = point.position.dy;

    if (accumulate && completedRepeats > 0) {
      final endPos = motionPath.getEndPosition();
      posX += endPos.dx * completedRepeats;
      posY += endPos.dy * completedRepeats;
    }

    // Формируем transform строку
    final rotateMode = to as String?;
    final translatePart = 'translate($posX, $posY)';

    if (rotateMode == null || rotateMode.isEmpty) {
      return translatePart;
    }

    if (rotateMode == 'auto') {
      final angleDegrees = MotionPath.radiansToDegrees(point.angle);
      return '$translatePart rotate($angleDegrees)';
    }

    if (rotateMode == 'auto-reverse') {
      final angleDegrees = MotionPath.radiansToDegrees(point.angle) + 180;
      return '$translatePart rotate($angleDegrees)';
    }

    return '$translatePart rotate($rotateMode)';
  }

  /// Apply keySplines easing to motion with keyPoints/keyTimes
  double _applyMotionSpline(
    double t,
    List<double> keyPoints,
    List<double> keyTimes,
    List<CubicBezier> splines,
  ) {
    // Find which segment we're in
    for (int i = 0; i < keyTimes.length - 1; i++) {
      if (t >= keyTimes[i] && t <= keyTimes[i + 1]) {
        final segmentStart = keyTimes[i];
        final segmentEnd = keyTimes[i + 1];
        final segmentDuration = segmentEnd - segmentStart;

        if (segmentDuration <= 0) continue;

        // Calculate local progress within segment
        var localT = (t - segmentStart) / segmentDuration;

        // Apply spline easing if available for this segment
        if (i < splines.length) {
          localT = splines[i].transform(localT);
        }

        // Convert back to global progress
        return segmentStart + localT * segmentDuration;
      }
    }
    return t;
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
  /// Per SMIL spec: accumulate="sum" means that each repeat cycle adds to the
  /// result of the previous cycle. The accumulated value is:
  /// accumulatedValue = animValue + (finalValue * completedRepeats)
  ///
  /// When combined with additive="sum", the total effect is:
  /// result = baseValue + accumulatedValue
  ///
  /// For nested additive animations, each animation's accumulation is independent,
  /// and they stack according to document order per the sandwich model.
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

    // Per SMIL spec, accumulate="sum" adds the final value of the simple
    // duration for each completed repeat cycle.
    // Formula: animValue + (finalValue * completedRepeats)
    //
    // This is implemented by iteratively adding finalValue for efficiency
    // and to support non-numeric types that implement addition
    Object accumulated = animValue;
    for (int i = 0; i < completedRepeats; i++) {
      final result = Interpolators.add(accumulated, finalValue, attributeType);
      if (result == null) break;
      accumulated = result;
    }

    return accumulated;
  }

  /// Вычислить финальное значение анимации (t=1.0) для accumulate support
  /// This returns the "to" value or last values entry - the final value
  /// that gets accumulated on each repeat cycle.
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
  /// Per SMIL spec: additive="sum" means the animation value is added to
  /// the underlying value of the target attribute.
  ///
  /// When multiple additive animations target the same attribute:
  /// - They stack in document order per the animation sandwich model
  /// - Each animation adds its computed value (including accumulate) to the
  ///   result of the previous animation in the sandwich
  ///
  /// For nested additive animations, the total effect is:
  /// result = baseValue + anim1AccumulatedValue + anim2AccumulatedValue + ...
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
    // For nested additive animations, this will be called multiple times
    // with the accumulated result being stored in the attribute
    return Interpolators.add(baseValue, animValueNonNull, attributeType);
  }

  /// Обновить состояние анимации для заданного глобального времени
}
