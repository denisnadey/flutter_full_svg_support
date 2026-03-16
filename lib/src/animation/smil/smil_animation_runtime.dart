part of 'smil_animation.dart';

extension SmilAnimationRuntimeExtension on SmilAnimation {
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

    final completedWholeIterations = elapsedMicros ~/ durMicros;
    final remainderMicros = elapsedMicros % durMicros;

    late final int iterationIndex;
    late final int completedRepeats;
    late final double baseT;

    if (remainderMicros == 0) {
      iterationIndex = completedWholeIterations > 0
          ? completedWholeIterations - 1
          : 0;
      completedRepeats = iterationIndex;
      baseT = 1.0;
    } else {
      iterationIndex = completedWholeIterations;
      completedRepeats = completedWholeIterations;
      baseT = remainderMicros / durMicros;
    }

    return _AnimationProgress(
      t: _resolveDirectedProgress(baseT, iterationIndex),
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
