part of 'path_normalizer.dart';

/// Convert a LineTo command to a CubicBezier (straight line).
CubicBezierCommand _lineToCubic(
  double currentX,
  double currentY,
  LineToCommand line,
) {
  // Control points are 1/3 and 2/3 along the line.
  final dx = line.x - currentX;
  final dy = line.y - currentY;

  return CubicBezierCommand(
    x1: currentX + dx / 3,
    y1: currentY + dy / 3,
    x2: currentX + 2 * dx / 3,
    y2: currentY + 2 * dy / 3,
    x: line.x,
    y: line.y,
    isRelative: false,
  );
}

/// Convert an Arc to cubic bezier approximation.
///
/// Uses up to 4 cubic bezier curves to approximate an elliptical arc.
List<CubicBezierCommand> _arcToCubics(
  double currentX,
  double currentY,
  ArcCommand arc,
) {
  // Handle degenerate cases.
  if (arc.rx == 0 || arc.ry == 0) {
    return [
      _lineToCubic(currentX, currentY, LineToCommand(x: arc.x, y: arc.y)),
    ];
  }

  // If start and end points are the same, no arc.
  if (currentX == arc.x && currentY == arc.y) {
    return [];
  }

  // Normalize radii.
  double rx = arc.rx.abs();
  double ry = arc.ry.abs();

  // Convert rotation angle to radians.
  final phi = arc.rotation * math.pi / 180.0;
  final cosPhi = math.cos(phi);
  final sinPhi = math.sin(phi);

  // Compute center point.
  final dx = (currentX - arc.x) / 2.0;
  final dy = (currentY - arc.y) / 2.0;

  final x1p = cosPhi * dx + sinPhi * dy;
  final y1p = -sinPhi * dx + cosPhi * dy;

  // Correct radii if needed.
  final lambda = (x1p * x1p) / (rx * rx) + (y1p * y1p) / (ry * ry);
  if (lambda > 1) {
    rx *= math.sqrt(lambda);
    ry *= math.sqrt(lambda);
  }

  // Compute center.
  final sign = (arc.largeArc == arc.sweep) ? -1.0 : 1.0;
  final sq =
      ((rx * rx * ry * ry) - (rx * rx * y1p * y1p) - (ry * ry * x1p * x1p)) /
      ((rx * rx * y1p * y1p) + (ry * ry * x1p * x1p));
  final sq2 = sq < 0 ? 0.0 : sq;
  final coef = sign * math.sqrt(sq2);

  final cxp = coef * rx * y1p / ry;
  final cyp = -coef * ry * x1p / rx;

  final cx = cosPhi * cxp - sinPhi * cyp + (currentX + arc.x) / 2.0;
  final cy = sinPhi * cxp + cosPhi * cyp + (currentY + arc.y) / 2.0;

  // Compute angles.
  double angle(double ux, double uy, double vx, double vy) {
    final dot = ux * vx + uy * vy;
    final mod = math.sqrt((ux * ux + uy * uy) * (vx * vx + vy * vy));
    double rad = math.acos(dot / mod);
    if (ux * vy - uy * vx < 0.0) rad = -rad;
    return rad;
  }

  final theta1 = angle(1.0, 0.0, (x1p - cxp) / rx, (y1p - cyp) / ry);
  double dtheta = angle(
    (x1p - cxp) / rx,
    (y1p - cyp) / ry,
    (-x1p - cxp) / rx,
    (-y1p - cyp) / ry,
  );

  if (arc.sweep && dtheta < 0) {
    dtheta += 2 * math.pi;
  } else if (!arc.sweep && dtheta > 0) {
    dtheta -= 2 * math.pi;
  }

  // Split arc into segments (max 90 degrees each).
  final segments = (dtheta.abs() / (math.pi / 2.0)).ceil();
  final delta = dtheta / segments;
  final alpha =
      math.sin(delta) *
      (math.sqrt(4 + 3 * math.tan(delta / 2) * math.tan(delta / 2)) - 1) /
      3;

  final result = <CubicBezierCommand>[];

  for (int i = 0; i < segments; i++) {
    final theta = theta1 + i * delta;
    final thetaNext = theta + delta;

    final cosTheta = math.cos(theta);
    final sinTheta = math.sin(theta);
    final cosThetaNext = math.cos(thetaNext);
    final sinThetaNext = math.sin(thetaNext);

    // First control point.
    final q1x = cosTheta - sinTheta * alpha;
    final q1y = sinTheta + cosTheta * alpha;

    // Second control point.
    final q2x = cosThetaNext + sinThetaNext * alpha;
    final q2y = sinThetaNext - cosThetaNext * alpha;

    // Transform back to original coordinate system.
    final cp1x = cosPhi * rx * q1x - sinPhi * ry * q1y + cx;
    final cp1y = sinPhi * rx * q1x + cosPhi * ry * q1y + cy;

    final cp2x = cosPhi * rx * q2x - sinPhi * ry * q2y + cx;
    final cp2y = sinPhi * rx * q2x + cosPhi * ry * q2y + cy;

    final endX = cosPhi * rx * cosThetaNext - sinPhi * ry * sinThetaNext + cx;
    final endY = sinPhi * rx * cosThetaNext + cosPhi * ry * sinThetaNext + cy;

    result.add(
      CubicBezierCommand(
        x1: cp1x,
        y1: cp1y,
        x2: cp2x,
        y2: cp2y,
        x: endX,
        y: endY,
        isRelative: false,
      ),
    );
  }

  return result;
}
