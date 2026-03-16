part of 'path_data.dart';

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
