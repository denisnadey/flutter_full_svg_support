part of 'path_interpolation.dart';

/// Interpolate a MoveTo command.
void _interpolateMoveTo(
  Path path,
  MoveToCommand from,
  MoveToCommand to,
  double t,
) {
  final x = lerpDouble(from.x, to.x, t)!;
  final y = lerpDouble(from.y, to.y, t)!;
  path.moveTo(x, y);
}

/// Interpolate a CubicBezier command.
void _interpolateCubicBezier(
  Path path,
  CubicBezierCommand from,
  CubicBezierCommand to,
  double t,
) {
  final x1 = lerpDouble(from.x1, to.x1, t)!;
  final y1 = lerpDouble(from.y1, to.y1, t)!;
  final x2 = lerpDouble(from.x2, to.x2, t)!;
  final y2 = lerpDouble(from.y2, to.y2, t)!;
  final x = lerpDouble(from.x, to.x, t)!;
  final y = lerpDouble(from.y, to.y, t)!;

  path.cubicTo(x1, y1, x2, y2, x, y);
}
