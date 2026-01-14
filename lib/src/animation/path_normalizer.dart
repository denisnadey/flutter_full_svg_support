/// Path normalization for SVG path morphing and interpolation.
///
/// Normalizes paths to make them compatible for smooth interpolation:
/// - Converts all commands to absolute coordinates
/// - Converts all curves to cubic bezier
/// - Ensures both paths have the same number of commands
library;

import 'dart:math' as math;
import 'path_data.dart';

/// Normalizes SVG paths for morphing/interpolation.
///
/// Takes two paths and transforms them so they:
/// 1. Have all absolute coordinates
/// 2. Have the same number of commands
/// 3. Use only MoveTo, CubicBezier, and ClosePath commands
class PathNormalizer {
  PathNormalizer();

  /// Normalize a single path to absolute coordinates and cubic beziers.
  ///
  /// Returns a list of PathCommands using only:
  /// - MoveToCommand (absolute)
  /// - CubicBezierCommand (absolute)
  /// - ClosePathCommand
  List<PathCommand> normalizeSingle(List<PathCommand> commands) {
    if (commands.isEmpty) return [];

    final normalized = <PathCommand>[];
    double currentX = 0;
    double currentY = 0;
    double subpathStartX = 0;
    double subpathStartY = 0;
    PathCommand? previousCommand;

    for (final cmd in commands) {
      // Convert to absolute first
      final absoluteCmd = cmd.toAbsolute(currentX, currentY);

      if (absoluteCmd is MoveToCommand) {
        normalized.add(absoluteCmd);
        currentX = absoluteCmd.x;
        currentY = absoluteCmd.y;
        subpathStartX = currentX;
        subpathStartY = currentY;
      } else if (absoluteCmd is LineToCommand) {
        // Convert LineTo to CubicBezier (straight line)
        normalized.add(_lineToCubic(currentX, currentY, absoluteCmd));
        currentX = absoluteCmd.x;
        currentY = absoluteCmd.y;
      } else if (absoluteCmd is HorizontalLineToCommand) {
        // Convert H to L, then to C
        final lineTo = absoluteCmd.toLineTo(currentY);
        final absLine = lineTo.toAbsolute(currentX, currentY) as LineToCommand;
        normalized.add(_lineToCubic(currentX, currentY, absLine));
        currentX = absLine.x;
        currentY = absLine.y;
      } else if (absoluteCmd is VerticalLineToCommand) {
        // Convert V to L, then to C
        final lineTo = absoluteCmd.toLineTo(currentX);
        final absLine = lineTo.toAbsolute(currentX, currentY) as LineToCommand;
        normalized.add(_lineToCubic(currentX, currentY, absLine));
        currentX = absLine.x;
        currentY = absLine.y;
      } else if (absoluteCmd is CubicBezierCommand) {
        normalized.add(absoluteCmd);
        currentX = absoluteCmd.x;
        currentY = absoluteCmd.y;
      } else if (absoluteCmd is SmoothCubicBezierCommand) {
        final cubic = absoluteCmd.toCubicBezier(
          currentX: currentX,
          currentY: currentY,
          previousCommand: previousCommand,
        );
        final absCubic =
            cubic.toAbsolute(currentX, currentY) as CubicBezierCommand;
        normalized.add(absCubic);
        currentX = absCubic.x;
        currentY = absCubic.y;
      } else if (absoluteCmd is QuadraticBezierCommand) {
        final cubic = absoluteCmd.toCubicBezier(currentX, currentY);
        final absCubic =
            cubic.toAbsolute(currentX, currentY) as CubicBezierCommand;
        normalized.add(absCubic);
        currentX = absCubic.x;
        currentY = absCubic.y;
      } else if (absoluteCmd is SmoothQuadraticBezierCommand) {
        final quad = absoluteCmd.toQuadraticBezier(
          currentX: currentX,
          currentY: currentY,
          previousCommand: previousCommand,
        );
        final absQuad =
            quad.toAbsolute(currentX, currentY) as QuadraticBezierCommand;
        final cubic = absQuad.toCubicBezier(currentX, currentY);
        final absCubic =
            cubic.toAbsolute(currentX, currentY) as CubicBezierCommand;
        normalized.add(absCubic);
        currentX = absCubic.x;
        currentY = absCubic.y;
      } else if (absoluteCmd is ArcCommand) {
        // Convert arc to cubic bezier approximation
        final cubics = _arcToCubics(currentX, currentY, absoluteCmd);
        normalized.addAll(cubics);
        if (cubics.isNotEmpty) {
          final last = cubics.last;
          currentX = last.x;
          currentY = last.y;
        }
      } else if (absoluteCmd is ClosePathCommand) {
        // Add line from current point to subpath start, then close
        if (currentX != subpathStartX || currentY != subpathStartY) {
          normalized.add(
            _lineToCubic(
              currentX,
              currentY,
              LineToCommand(x: subpathStartX, y: subpathStartY),
            ),
          );
        }
        normalized.add(const ClosePathCommand());
        currentX = subpathStartX;
        currentY = subpathStartY;
      }

      previousCommand = absoluteCmd;
    }

    return normalized;
  }

  /// Normalize two paths to be compatible for interpolation.
  ///
  /// Returns a [NormalizedPathPair] containing both paths with:
  /// - Same number of commands
  /// - Same command types at each index
  /// - All absolute coordinates
  NormalizedPathPair normalize(
    List<PathCommand> path1,
    List<PathCommand> path2,
  ) {
    final norm1 = normalizeSingle(path1);
    final norm2 = normalizeSingle(path2);

    // If paths have different command counts, we need to align them
    if (norm1.length != norm2.length) {
      return _alignPaths(norm1, norm2);
    }

    return NormalizedPathPair(from: norm1, to: norm2);
  }

  /// Align two paths to have the same number of commands by subdividing.
  NormalizedPathPair _alignPaths(
    List<PathCommand> path1,
    List<PathCommand> path2,
  ) {
    // Simple strategy: pad the shorter path with degenerate (zero-length) curves
    final longer = path1.length > path2.length ? path1 : path2;
    final shorter = path1.length > path2.length ? path2 : path1;
    final difference = longer.length - shorter.length;

    if (difference == 0) {
      return NormalizedPathPair(
        from: path1.length > path2.length ? path1 : path2,
        to: path1.length > path2.length ? path2 : path1,
      );
    }

    // Create padded version of shorter path
    final padded = List<PathCommand>.from(shorter);

    // Find a good place to insert padding (after MoveTo, before ClosePath)
    int insertIndex = 1; // After first MoveTo
    for (int i = 0; i < shorter.length; i++) {
      if (shorter[i] is! ClosePathCommand) {
        insertIndex = i + 1;
      } else {
        break;
      }
    }

    // Get position for degenerate curves
    double x = 0, y = 0;
    if (insertIndex > 0 && insertIndex <= shorter.length) {
      final prevCmd = shorter[insertIndex - 1];
      if (prevCmd is MoveToCommand) {
        x = prevCmd.x;
        y = prevCmd.y;
      } else if (prevCmd is CubicBezierCommand) {
        x = prevCmd.x;
        y = prevCmd.y;
      }
    }

    // Insert degenerate curves (point to itself)
    for (int i = 0; i < difference; i++) {
      padded.insert(
        insertIndex,
        CubicBezierCommand(
          x1: x,
          y1: y,
          x2: x,
          y2: y,
          x: x,
          y: y,
          isRelative: false,
        ),
      );
    }

    return NormalizedPathPair(
      from: path1.length > path2.length ? longer : padded,
      to: path1.length > path2.length ? padded : longer,
    );
  }

  /// Convert a LineTo command to a CubicBezier (straight line).
  CubicBezierCommand _lineToCubic(
    double currentX,
    double currentY,
    LineToCommand line,
  ) {
    // Control points are 1/3 and 2/3 along the line
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
    // Handle degenerate cases
    if (arc.rx == 0 || arc.ry == 0) {
      return [
        _lineToCubic(currentX, currentY, LineToCommand(x: arc.x, y: arc.y)),
      ];
    }

    // If start and end points are the same, no arc
    if (currentX == arc.x && currentY == arc.y) {
      return [];
    }

    // Normalize radii
    double rx = arc.rx.abs();
    double ry = arc.ry.abs();

    // Convert rotation angle to radians
    final phi = arc.rotation * math.pi / 180.0;
    final cosPhi = math.cos(phi);
    final sinPhi = math.sin(phi);

    // Compute center point
    final dx = (currentX - arc.x) / 2.0;
    final dy = (currentY - arc.y) / 2.0;

    final x1p = cosPhi * dx + sinPhi * dy;
    final y1p = -sinPhi * dx + cosPhi * dy;

    // Correct radii if needed
    final lambda = (x1p * x1p) / (rx * rx) + (y1p * y1p) / (ry * ry);
    if (lambda > 1) {
      rx *= math.sqrt(lambda);
      ry *= math.sqrt(lambda);
    }

    // Compute center
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

    // Compute angles
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

    // Split arc into segments (max 90 degrees each)
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

      // First control point
      final q1x = cosTheta - sinTheta * alpha;
      final q1y = sinTheta + cosTheta * alpha;

      // Second control point
      final q2x = cosThetaNext + sinThetaNext * alpha;
      final q2y = sinThetaNext - cosThetaNext * alpha;

      // Transform back to original coordinate system
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
}

/// Result of normalizing two paths for interpolation.
class NormalizedPathPair {
  const NormalizedPathPair({required this.from, required this.to});

  final List<PathCommand> from;
  final List<PathCommand> to;

  /// Check if normalization was successful (same length, compatible commands).
  bool get isValid {
    if (from.length != to.length) return false;

    for (int i = 0; i < from.length; i++) {
      if (from[i].runtimeType != to[i].runtimeType) {
        return false;
      }
    }

    return true;
  }
}
