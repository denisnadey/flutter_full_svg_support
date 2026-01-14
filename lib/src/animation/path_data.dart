/// Path command data structures for SVG path parsing and manipulation.
///
/// This library provides classes to represent SVG path commands
/// in a structured way for animation and interpolation.
library;

/// Base class for all SVG path commands.
abstract class PathCommand {
  const PathCommand();

  /// The command type (M, L, C, Q, A, Z, etc.)
  String get type;

  /// Whether this is a relative command (lowercase letter)
  bool get isRelative;

  /// Convert this command to absolute coordinates
  PathCommand toAbsolute(double currentX, double currentY);

  /// Convert this command to a list of parameters
  List<double> get params;
}

/// MoveTo command (M/m)
class MoveToCommand extends PathCommand {
  const MoveToCommand({
    required this.x,
    required this.y,
    this.isRelative = false,
  });

  final double x;
  final double y;

  @override
  final bool isRelative;

  @override
  String get type => isRelative ? 'm' : 'M';

  @override
  List<double> get params => [x, y];

  @override
  PathCommand toAbsolute(double currentX, double currentY) {
    if (!isRelative) return this;
    return MoveToCommand(x: currentX + x, y: currentY + y, isRelative: false);
  }

  @override
  String toString() => '$type$x,$y';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MoveToCommand &&
          x == other.x &&
          y == other.y &&
          isRelative == other.isRelative;

  @override
  int get hashCode => Object.hash(x, y, isRelative);
}

/// LineTo command (L/l)
class LineToCommand extends PathCommand {
  const LineToCommand({
    required this.x,
    required this.y,
    this.isRelative = false,
  });

  final double x;
  final double y;

  @override
  final bool isRelative;

  @override
  String get type => isRelative ? 'l' : 'L';

  @override
  List<double> get params => [x, y];

  @override
  PathCommand toAbsolute(double currentX, double currentY) {
    if (!isRelative) return this;
    return LineToCommand(x: currentX + x, y: currentY + y, isRelative: false);
  }

  @override
  String toString() => '$type$x,$y';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LineToCommand &&
          x == other.x &&
          y == other.y &&
          isRelative == other.isRelative;

  @override
  int get hashCode => Object.hash(x, y, isRelative);
}

/// Horizontal LineTo command (H/h)
class HorizontalLineToCommand extends PathCommand {
  const HorizontalLineToCommand({required this.x, this.isRelative = false});

  final double x;

  @override
  final bool isRelative;

  @override
  String get type => isRelative ? 'h' : 'H';

  @override
  List<double> get params => [x];

  @override
  PathCommand toAbsolute(double currentX, double currentY) {
    if (!isRelative) return this;
    return HorizontalLineToCommand(x: currentX + x, isRelative: false);
  }

  /// Convert to standard LineTo command
  LineToCommand toLineTo(double currentY) {
    return LineToCommand(x: x, y: currentY, isRelative: isRelative);
  }

  @override
  String toString() => '$type$x';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HorizontalLineToCommand &&
          x == other.x &&
          isRelative == other.isRelative;

  @override
  int get hashCode => Object.hash(x, isRelative);
}

/// Vertical LineTo command (V/v)
class VerticalLineToCommand extends PathCommand {
  const VerticalLineToCommand({required this.y, this.isRelative = false});

  final double y;

  @override
  final bool isRelative;

  @override
  String get type => isRelative ? 'v' : 'V';

  @override
  List<double> get params => [y];

  @override
  PathCommand toAbsolute(double currentX, double currentY) {
    if (!isRelative) return this;
    return VerticalLineToCommand(y: currentY + y, isRelative: false);
  }

  /// Convert to standard LineTo command
  LineToCommand toLineTo(double currentX) {
    return LineToCommand(x: currentX, y: y, isRelative: isRelative);
  }

  @override
  String toString() => '$type$y';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VerticalLineToCommand &&
          y == other.y &&
          isRelative == other.isRelative;

  @override
  int get hashCode => Object.hash(y, isRelative);
}

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

/// Arc command (A/a)
class ArcCommand extends PathCommand {
  const ArcCommand({
    required this.rx,
    required this.ry,
    required this.rotation,
    required this.largeArc,
    required this.sweep,
    required this.x,
    required this.y,
    this.isRelative = false,
  });

  final double rx, ry; // Radii
  final double rotation; // X-axis rotation in degrees
  final bool largeArc; // Large arc flag
  final bool sweep; // Sweep flag
  final double x, y; // End point

  @override
  final bool isRelative;

  @override
  String get type => isRelative ? 'a' : 'A';

  @override
  List<double> get params => [
    rx,
    ry,
    rotation,
    largeArc ? 1 : 0,
    sweep ? 1 : 0,
    x,
    y,
  ];

  @override
  PathCommand toAbsolute(double currentX, double currentY) {
    if (!isRelative) return this;
    return ArcCommand(
      rx: rx,
      ry: ry,
      rotation: rotation,
      largeArc: largeArc,
      sweep: sweep,
      x: currentX + x,
      y: currentY + y,
      isRelative: false,
    );
  }

  @override
  String toString() =>
      '$type$rx,$ry $rotation ${largeArc ? 1 : 0},${sweep ? 1 : 0} $x,$y';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ArcCommand &&
          rx == other.rx &&
          ry == other.ry &&
          rotation == other.rotation &&
          largeArc == other.largeArc &&
          sweep == other.sweep &&
          x == other.x &&
          y == other.y &&
          isRelative == other.isRelative;

  @override
  int get hashCode =>
      Object.hash(rx, ry, rotation, largeArc, sweep, x, y, isRelative);
}

/// ClosePath command (Z/z)
class ClosePathCommand extends PathCommand {
  const ClosePathCommand();

  @override
  bool get isRelative => false; // Z and z are equivalent

  @override
  String get type => 'Z';

  @override
  List<double> get params => [];

  @override
  PathCommand toAbsolute(double currentX, double currentY) => this;

  @override
  String toString() => 'Z';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ClosePathCommand;

  @override
  int get hashCode => 0;
}
