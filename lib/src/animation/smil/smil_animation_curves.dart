part of 'smil_animation.dart';

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

  // Вспомогательные функции для вычисления полинома
  double _bezierX(double t) {
    return _bezierA(x1, x2) * t * t * t +
        _bezierB(x1, x2) * t * t +
        _bezierC(x1) * t;
  }

  double _bezierY(double t) {
    return _bezierA(y1, y2) * t * t * t +
        _bezierB(y1, y2) * t * t +
        _bezierC(y1) * t;
  }

  double _bezierXDerivative(double t) {
    return 3 * _bezierA(x1, x2) * t * t +
        2 * _bezierB(x1, x2) * t +
        _bezierC(x1);
  }

  double _bezierA(double p1, double p2) => 1.0 - 3.0 * p2 + 3.0 * p1;
  double _bezierB(double p1, double p2) => 3.0 * p2 - 6.0 * p1;
  double _bezierC(double p1) => 3.0 * p1;

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

/// Дискретная функция времени (аналог CSS steps())
@immutable
class StepTiming {
  /// Создаёт ступенчатую функцию
  const StepTiming({required this.steps, this.stepAtStart = false});

  /// Количество шагов
  final int steps;

  /// Делать ли шаг в самом начале интервала
  final bool stepAtStart;

  /// Вычислить значение ступенчатой функции для t ∈ [0, 1]
  double transform(double t) {
    if (t >= 1.0) return 1.0;
    if (t <= 0.0) return 0.0;

    if (stepAtStart) {
      return (t * steps).floor() / steps + (1.0 / steps);
    } else {
      return (t * steps).floor() / steps;
    }
  }
}
