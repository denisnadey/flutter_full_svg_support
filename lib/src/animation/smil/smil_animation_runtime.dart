part of 'smil_animation.dart';

extension SmilAnimationRuntimeExtension on SmilAnimation {
  void _applyValue(Object value) {
    final attr = targetNode.getAttribute(attributeName);
    if (attr != null) {
      attr.setAnimatedValue(value);
    } else {
      // If the attribute doesn't exist, create it.
      // This happens for animateTransform and animateMotion when the
      // element initially has no transform.
      //
      // CRITICAL: we must seed the new attribute with an *identity* base
      // value, NOT the computed [value]. Otherwise a subsequent tick
      // running under additive="sum" (the SMIL default for animateMotion)
      // will compute `add(baseValue, newValue)` and the formerly-correct
      // [value] becomes a phantom static offset that gets pre-pended to
      // every later transform. The visible effect is the animated element
      // sliding off by exactly the starting-point coordinates.
      final identityBase = _identityBaseValueFor(attributeType, value);
      targetNode.setAttribute(attributeName, identityBase,
          type: attributeType);
      final newAttr = targetNode.getAttribute(attributeName);
      if (newAttr != null) {
        newAttr.setAnimatedValue(value);
      }
    }
  }

  /// Returns a neutral identity baseValue for [type] so additive="sum"
  /// chains don't accidentally accumulate the first-written animated value
  /// as a static offset. See [_applyValue].
  Object _identityBaseValueFor(SvgAttributeType type, Object fallback) {
    switch (type) {
      case SvgAttributeType.transform:
        return '';
      case SvgAttributeType.number:
      case SvgAttributeType.length:
        return 0;
      case SvgAttributeType.list:
      case SvgAttributeType.points:
        return const <double>[];
      default:
        // For attribute types we don't have a sensible identity for
        // (colors, strings, paths, …), keep the existing behavior — it
        // was correct in practice for everything except additive=sum.
        return fallback;
    }
  }

  /// Clear the animated value
  void _clearValue() {
    final attr = targetNode.getAttribute(attributeName);
    if (attr != null) {
      attr.clearAnimation();
    }
  }

  double _resolveDirectedProgress(double t, int iterationIndex) {
    final shouldReverse = switch (playbackDirection) {
      SmilPlaybackDirection.normal => false,
      SmilPlaybackDirection.reverse => true,
      SmilPlaybackDirection.alternate => iterationIndex.isOdd,
      SmilPlaybackDirection.alternateReverse => iterationIndex.isEven,
    };

    return shouldReverse ? 1.0 - t : t;
  }

  _AnimationProgress _computeProgressAtEnd({
    required Duration effectiveBegin,
    required Duration effectiveEnd,
  }) {
    final durMicros = dur.inMicroseconds;
    if (durMicros <= 0) {
      return _AnimationProgress(
        t: _resolveDirectedProgress(1.0, 0),
        completedRepeats: 0,
      );
    }

    final elapsedMicros = (effectiveEnd - effectiveBegin).inMicroseconds;
    if (elapsedMicros <= 0) {
      return _AnimationProgress(
        t: _resolveDirectedProgress(0.0, 0),
        completedRepeats: 0,
      );
    }

    // For fractional repeatCount, calculate exact progress
    // Using high-precision math to avoid floating-point drift
    if (repeatCount.isFinite && repeatCount > 0) {
      final expectedMicros = (durMicros * repeatCount).round();

      // Check if we're at exactly the end of the repeat cycle
      // Use epsilon comparison to handle floating-point precision
      const epsilonMicros = 1; // 1 microsecond tolerance
      if ((elapsedMicros - expectedMicros).abs() <= epsilonMicros) {
        // Exactly at end - use exact fractional part
        final fractionalPart = repeatCount - repeatCount.truncate();
        if (fractionalPart > 0) {
          // Fractional repeatCount: end at fractional point
          final completedWholeIterations = repeatCount.truncate();
          return _AnimationProgress(
            t: _resolveDirectedProgress(
              fractionalPart,
              completedWholeIterations,
            ),
            completedRepeats: completedWholeIterations,
          );
        } else {
          // Whole number repeatCount: end at t=1.0 of last iteration
          final completedIterations = repeatCount.toInt();
          return _AnimationProgress(
            t: _resolveDirectedProgress(1.0, completedIterations - 1),
            completedRepeats: completedIterations - 1,
          );
        }
      }
    }

    // General case: compute iteration and progress
    final completedWholeIterations = elapsedMicros ~/ durMicros;
    final remainderMicros = elapsedMicros % durMicros;

    late final int iterationIndex;
    late final int completedRepeats;
    late final double baseT;

    if (remainderMicros == 0 && completedWholeIterations > 0) {
      // Exactly at iteration boundary
      iterationIndex = completedWholeIterations - 1;
      completedRepeats = iterationIndex;
      baseT = 1.0;
    } else {
      iterationIndex = completedWholeIterations;
      completedRepeats = completedWholeIterations;
      baseT = remainderMicros / durMicros;
    }

    // Apply epsilon correction for boundary values
    double correctedT = baseT;
    const epsilon = 1e-10;
    if (correctedT > 1.0 - epsilon) {
      correctedT = 1.0;
    } else if (correctedT < epsilon) {
      correctedT = 0.0;
    }

    return _AnimationProgress(
      t: _resolveDirectedProgress(correctedT, iterationIndex),
      completedRepeats: completedRepeats,
    );
  }
}

@immutable
class _AnimationProgress {
  const _AnimationProgress({required this.t, required this.completedRepeats});

  final double t;
  final int completedRepeats;
}
