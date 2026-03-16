part of 'path_data.dart';

/// Cubic Bezier curve command (C/c)
class CubicBezierCommand extends PathCommand {
  const CubicBezierCommand({
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
    required this.x,
    required this.y,
    this.isRelative = false,
  });

  final double x1, y1; // First control point
  final double x2, y2; // Second control point
  final double x, y; // End point

  @override
  final bool isRelative;

  @override
  String get type => isRelative ? 'c' : 'C';

  @override
  List<double> get params => [x1, y1, x2, y2, x, y];

  @override
  PathCommand toAbsolute(double currentX, double currentY) {
    if (!isRelative) return this;
    return CubicBezierCommand(
      x1: currentX + x1,
      y1: currentY + y1,
      x2: currentX + x2,
      y2: currentY + y2,
      x: currentX + x,
      y: currentY + y,
      isRelative: false,
    );
  }

  @override
  String toString() => '$type$x1,$y1 $x2,$y2 $x,$y';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CubicBezierCommand &&
          x1 == other.x1 &&
          y1 == other.y1 &&
          x2 == other.x2 &&
          y2 == other.y2 &&
          x == other.x &&
          y == other.y &&
          isRelative == other.isRelative;

  @override
  int get hashCode => Object.hash(x1, y1, x2, y2, x, y, isRelative);
}

/// Smooth Cubic Bezier curve command (S/s)
class SmoothCubicBezierCommand extends PathCommand {
  const SmoothCubicBezierCommand({
    required this.x2,
    required this.y2,
    required this.x,
    required this.y,
    this.isRelative = false,
  });

  final double x2, y2; // Second control point
  final double x, y; // End point

  @override
  final bool isRelative;

  @override
  String get type => isRelative ? 's' : 'S';

  @override
  List<double> get params => [x2, y2, x, y];

  @override
  PathCommand toAbsolute(double currentX, double currentY) {
    if (!isRelative) return this;
    return SmoothCubicBezierCommand(
      x2: currentX + x2,
      y2: currentY + y2,
      x: currentX + x,
      y: currentY + y,
      isRelative: false,
    );
  }

  /// Convert to standard CubicBezier command
  /// Requires the previous command to calculate the reflected control point
  CubicBezierCommand toCubicBezier({
    required double currentX,
    required double currentY,
    PathCommand? previousCommand,
  }) {
    double x1 = currentX;
    double y1 = currentY;

    // If previous command was a cubic bezier, reflect its second control point
    if (previousCommand is CubicBezierCommand) {
      x1 = 2 * currentX - previousCommand.x2;
      y1 = 2 * currentY - previousCommand.y2;
    } else if (previousCommand is SmoothCubicBezierCommand) {
      x1 = 2 * currentX - previousCommand.x2;
      y1 = 2 * currentY - previousCommand.y2;
    }

    return CubicBezierCommand(
      x1: x1,
      y1: y1,
      x2: x2,
      y2: y2,
      x: x,
      y: y,
      isRelative: isRelative,
    );
  }

  @override
  String toString() => '$type$x2,$y2 $x,$y';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SmoothCubicBezierCommand &&
          x2 == other.x2 &&
          y2 == other.y2 &&
          x == other.x &&
          y == other.y &&
          isRelative == other.isRelative;

  @override
  int get hashCode => Object.hash(x2, y2, x, y, isRelative);
}

/// Quadratic Bezier curve command (Q/q)
class QuadraticBezierCommand extends PathCommand {
  const QuadraticBezierCommand({
    required this.x1,
    required this.y1,
    required this.x,
    required this.y,
    this.isRelative = false,
  });

  final double x1, y1; // Control point
  final double x, y; // End point

  @override
  final bool isRelative;

  @override
  String get type => isRelative ? 'q' : 'Q';

  @override
  List<double> get params => [x1, y1, x, y];

  @override
  PathCommand toAbsolute(double currentX, double currentY) {
    if (!isRelative) return this;
    return QuadraticBezierCommand(
      x1: currentX + x1,
      y1: currentY + y1,
      x: currentX + x,
      y: currentY + y,
      isRelative: false,
    );
  }

  /// Convert quadratic bezier to cubic bezier
  /// Formula: CP1 = QP0 + 2/3 * (QP1 - QP0)
  ///          CP2 = QP2 + 2/3 * (QP1 - QP2)
  CubicBezierCommand toCubicBezier(double currentX, double currentY) {
    final cp1x = currentX + 2.0 / 3.0 * (x1 - currentX);
    final cp1y = currentY + 2.0 / 3.0 * (y1 - currentY);
    final cp2x = x + 2.0 / 3.0 * (x1 - x);
    final cp2y = y + 2.0 / 3.0 * (y1 - y);

    return CubicBezierCommand(
      x1: cp1x,
      y1: cp1y,
      x2: cp2x,
      y2: cp2y,
      x: x,
      y: y,
      isRelative: isRelative,
    );
  }

  @override
  String toString() => '$type$x1,$y1 $x,$y';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QuadraticBezierCommand &&
          x1 == other.x1 &&
          y1 == other.y1 &&
          x == other.x &&
          y == other.y &&
          isRelative == other.isRelative;

  @override
  int get hashCode => Object.hash(x1, y1, x, y, isRelative);
}

/// Smooth Quadratic Bezier curve command (T/t)
class SmoothQuadraticBezierCommand extends PathCommand {
  const SmoothQuadraticBezierCommand({
    required this.x,
    required this.y,
    this.isRelative = false,
  });

  final double x, y; // End point

  @override
  final bool isRelative;

  @override
  String get type => isRelative ? 't' : 'T';

  @override
  List<double> get params => [x, y];

  @override
  PathCommand toAbsolute(double currentX, double currentY) {
    if (!isRelative) return this;
    return SmoothQuadraticBezierCommand(
      x: currentX + x,
      y: currentY + y,
      isRelative: false,
    );
  }

  /// Convert to standard QuadraticBezier command
  QuadraticBezierCommand toQuadraticBezier({
    required double currentX,
    required double currentY,
    PathCommand? previousCommand,
  }) {
    double x1 = currentX;
    double y1 = currentY;

    // If previous was quadratic, reflect its control point
    if (previousCommand is QuadraticBezierCommand) {
      x1 = 2 * currentX - previousCommand.x1;
      y1 = 2 * currentY - previousCommand.y1;
    } else if (previousCommand is SmoothQuadraticBezierCommand) {
      // Need to reconstruct the control point from previous T command
      // This is a simplified approach - current point is used
      x1 = currentX;
      y1 = currentY;
    }

    return QuadraticBezierCommand(
      x1: x1,
      y1: y1,
      x: x,
      y: y,
      isRelative: isRelative,
    );
  }

  @override
  String toString() => '$type$x,$y';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SmoothQuadraticBezierCommand &&
          x == other.x &&
          y == other.y &&
          isRelative == other.isRelative;

  @override
  int get hashCode => Object.hash(x, y, isRelative);
}
