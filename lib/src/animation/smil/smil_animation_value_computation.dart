part of 'smil_animation.dart';

extension SmilAnimationValueComputationExtension on SmilAnimation {
  Object? _computeDiscreteValue(double t) {
    if (values != null && values!.isNotEmpty) {
      if (keyTimes != null) {
        // Find the corresponding keyframe
        for (int i = 0; i < keyTimes!.length - 1; i++) {
          if (t >= keyTimes![i] && t < keyTimes![i + 1]) {
            return values![i];
          }
        }
        // Last value
        return values!.last;
      }
      // Without keyTimes - uniform distribution
      final segmentCount = values!.length;
      final index = (t * segmentCount).floor().clamp(0, values!.length - 1);
      return values![index];
    }

    // from/to - return from until t=1.0, then to
    return t >= 1.0 ? (to ?? from) : from;
  }

  /// Compute value for values-based animation
  Object? _computeValuesBasedValue(double t) {
    if (values!.length == 1) {
      return values![0];
    }

    // Determine which keyframe interval we are in
    int fromIndex = 0;
    int toIndex = 1;
    double segmentProgress = t;

    // Use paced keyTimes if available, otherwise use regular keyTimes
    final effectiveKeyTimes = _pacedKeyTimes ?? keyTimes;

    if (effectiveKeyTimes != null) {
      // With explicit keyTimes (or generated ones for paced)
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
      // Without keyTimes - uniform distribution
      final segmentCount = values!.length - 1;
      final segmentIndex = (t * segmentCount).floor().clamp(
        0,
        segmentCount - 1,
      );
      fromIndex = segmentIndex;
      toIndex = segmentIndex + 1;
      segmentProgress = (t * segmentCount) - segmentIndex;
    }

    // Apply easing if keySplines or keySteps are present
    if (calcMode == SmilCalcMode.spline && keySplines != null) {
      final spline = keySplines![fromIndex];
      segmentProgress = spline.transform(segmentProgress);
    } else if (keySteps != null && fromIndex < keySteps!.length) {
      final step = keySteps![fromIndex];
      segmentProgress = step.transform(segmentProgress);
    }

    // Interpolate between values
    return _interpolate(values![fromIndex], values![toIndex], segmentProgress);
  }

  /// Compute value for simple from/to/by animation
  Object? _computeSimpleValue(double t) {
    Object? fromValue = from;
    Object? toValue = to;

    // If from is absent, use the base attribute value
    if (fromValue == null) {
      final attr = targetNode.getAttribute(attributeName);
      fromValue = attr?.baseValue;
    }

    // If by is present instead of to, compute to
    if (toValue == null && by != null && fromValue != null) {
      toValue = _addValues(fromValue, by!);
    }

    if (fromValue == null || toValue == null) {
      return toValue ?? fromValue;
    }

    return _interpolate(fromValue, toValue, t);
  }

  /// Compute value for animateMotion.
  /// [completedRepeats] is used for accumulate="sum" support
  Object? _computeMotionValue(double t, {int completedRepeats = 0}) {
    // from contains path data, to contains rotate mode
    final pathData = from as String?;
    if (pathData == null || pathData.trim().isEmpty) {
      return null;
    }

    try {
      // Create a MotionPath (can be cached in the future)
      final motionPath = MotionPath(pathData);

      // values contains keyPoints if they are present
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

      // Get the point on the path
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

      // Build the transform string
      final rotateMode = to as String?;
      final translatePart = 'translate($posX, $posY)';

      if (rotateMode == null || rotateMode.isEmpty) {
        return translatePart;
      }

      if (rotateMode == 'auto') {
        // Rotate along the path tangent
        final angleDegrees = MotionPath.radiansToDegrees(point.angle);
        return '$translatePart rotate($angleDegrees)';
      }

      if (rotateMode == 'auto-reverse') {
        // Rotate along the tangent + 180°
        final angleDegrees = MotionPath.radiansToDegrees(point.angle) + 180;
        return '$translatePart rotate($angleDegrees)';
      }

      // Fixed angle in degrees
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

    // Build the transform string
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

  /// Interpolate between two values.
  ///
  /// Uses Interpolators for typed interpolation
  @protected
  Object? _interpolate(Object from, Object to, double t) {
    return Interpolators.interpolate(from, to, t, attributeType);
  }

  /// Add two values together (for by)
  @protected
  Object? _addValues(Object base, Object delta) {
    return Interpolators.add(base, delta, attributeType);
  }

  /// Apply accumulate="sum" — add the final value * number of completed repeats
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

    // Get the final animation value (at the end of one iteration, t=1.0)
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

  /// Compute the final animation value (t=1.0) for accumulate support
  /// This returns the "to" value or last values entry - the final value
  /// that gets accumulated on each repeat cycle.
  @protected
  Object? _computeFinalValue() {
    // For values-based: the last value
    if (values != null && values!.isNotEmpty) {
      return values!.last;
    }
    // For from/to: the to value
    return to ?? from;
  }

  /// Apply additive="sum" — add to the base value of the element
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

    if (additive == SmilAdditiveMode.replace) {
      return animValue;
    }

    // additive="sum" - add to the static base value.
    // Used for single-animation case (no sandwich model involvement).
    final baseAttr = targetNode.getAttribute(attributeName);
    final baseValue = baseAttr?.baseValue;

    if (baseValue == null) {
      return animValue;
    }

    return Interpolators.add(baseValue, animValue, attributeType);
  }

  /// Apply additive with an explicit accumulated base value.
  ///
  /// Used by the sandwich model so that replace+sum chains accumulate
  /// correctly: replace resets the running total, sum adds to it.
  Object? applyAdditiveWithBase(Object? rawValue, Object? currentBase) {
    if (rawValue == null) return currentBase;
    if (additive == SmilAdditiveMode.replace) return rawValue;
    // additive == sum
    if (currentBase == null) {
      // Fall back to static base if no sandwich base has been set yet.
      final baseAttr = targetNode.getAttribute(attributeName);
      final base = baseAttr?.baseValue;
      if (base == null) return rawValue;
      return Interpolators.add(base, rawValue, attributeType);
    }
    return Interpolators.add(currentBase, rawValue, attributeType);
  }

  /// Update the animation state for the given global time
}
