part of 'smil_animation.dart';

/// Cubic Bezier curve for keySplines
@immutable
class CubicBezier {
  /// Creates a cubic Bezier curve
  const CubicBezier(this.x1, this.y1, this.x2, this.y2);

  /// Control point 1 - X
  final double x1;

  /// Control point 1 - Y
  final double y1;

  /// Control point 2 - X
  final double x2;

  /// Control point 2 - Y
  final double y2;

  /// Compute the curve value for t ∈ [0, 1].
  ///
  /// Uses Newton's approximation method for solving
  double transform(double t) {
    // For the linear curve (0 0 1 1) - optimization
    if (x1 == 0 && y1 == 0 && x2 == 1 && y2 == 1) {
      return t;
    }

    // Newton's method for finding X given t
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

  // Helper functions for computing the polynomial
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

/// Discrete timing function (analogous to CSS steps())
@immutable
class StepTiming {
  /// Creates a step timing function
  const StepTiming({required this.steps, this.stepAtStart = false});

  /// Number of steps
  final int steps;

  /// Whether to take the step at the very beginning of the interval
  final bool stepAtStart;

  /// Compute the step timing function value for t ∈ [0, 1]
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
