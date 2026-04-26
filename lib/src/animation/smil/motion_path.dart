import 'dart:math' as math;
import 'dart:ui';

import '../path_data.dart';
import '../path_parser.dart';

/// Result of computing a position on the motion path
class MotionPathPoint {
  const MotionPathPoint({required this.position, required this.angle});

  /// Position of the point on the path
  final Offset position;

  /// Tangent angle at this point (in radians).
  /// Used for rotate="auto"
  final double angle;
}

/// Class for computing the position and orientation of an element along an SVG path.
///
/// Used to implement SMIL <animateMotion>
class MotionPath {
  MotionPath(String pathData) {
    _parsePath(pathData);
    _computeSegmentLengths();
    _detectClosedPath();
  }

  /// Factory constructor for creating path from two coordinate points
  /// Used for from/to/by linear motion
  factory MotionPath.fromPoints(Offset from, Offset to) {
    final pathData = 'M${from.dx},${from.dy} L${to.dx},${to.dy}';
    return MotionPath(pathData);
  }

  /// Factory constructor for creating path from a list of coordinate points
  /// Used for values attribute with coordinate pairs
  factory MotionPath.fromPointList(List<Offset> points) {
    if (points.isEmpty) {
      return MotionPath('');
    }
    if (points.length == 1) {
      return MotionPath('M${points[0].dx},${points[0].dy}');
    }
    final buffer = StringBuffer('M${points[0].dx},${points[0].dy}');
    for (int i = 1; i < points.length; i++) {
      buffer.write(' L${points[i].dx},${points[i].dy}');
    }
    return MotionPath(buffer.toString());
  }

  /// Flutter Path for measurements
  late Path _path;

  /// Total path length
  late double _totalLength;

  /// Path segment lengths (cumulative)
  late List<double> _cumulativeLengths;

  /// Parsed commands for boundary tangent calculations
  late List<PathCommand> _commands;

  /// Whether this is a closed path (ends at or very near start point)
  bool _isClosed = false;

  /// Start position of the path
  Offset? _startPosition;

  /// End position of the path
  Offset? _endPosition;

  /// Tolerance for float comparison when detecting closed paths
  /// Per Blink: use epsilon comparison for floating point equality
  static const double _closedPathTolerance = 0.001;

  /// Parse SVG path data
  void _parsePath(String pathData) {
    try {
      final parser = PathParser();
      _commands = parser.parse(pathData);

      // Convert commands to a Flutter Path
      _path = Path();
      double currentX = 0, currentY = 0;
      double subpathStartX = 0, subpathStartY = 0;
      PathCommand? prevCommand;

      for (final command in _commands) {
        _applyCommand(
          command,
          currentX,
          currentY,
          subpathStartX,
          subpathStartY,
          prevCommand,
        );
        // Track current position for relative commands
        final newPos = _getCommandEndPoint(
          command,
          currentX,
          currentY,
          subpathStartX,
          subpathStartY,
        );
        currentX = newPos.dx;
        currentY = newPos.dy;
        if (command is MoveToCommand) {
          subpathStartX = currentX;
          subpathStartY = currentY;
        } else if (command is ClosePathCommand) {
          currentX = subpathStartX;
          currentY = subpathStartY;
        }
        prevCommand = command;
      }
    } catch (e) {
      // If parsing failed, create an empty path
      _path = Path();
      _commands = [];
    }
  }

  /// Get the end point of a command
  Offset _getCommandEndPoint(
    PathCommand command,
    double currentX,
    double currentY,
    double subpathStartX,
    double subpathStartY,
  ) {
    if (command is MoveToCommand) {
      return command.isRelative
          ? Offset(currentX + command.x, currentY + command.y)
          : Offset(command.x, command.y);
    } else if (command is LineToCommand) {
      return command.isRelative
          ? Offset(currentX + command.x, currentY + command.y)
          : Offset(command.x, command.y);
    } else if (command is HorizontalLineToCommand) {
      return Offset(
        command.isRelative ? currentX + command.x : command.x,
        currentY,
      );
    } else if (command is VerticalLineToCommand) {
      return Offset(
        currentX,
        command.isRelative ? currentY + command.y : command.y,
      );
    } else if (command is CubicBezierCommand) {
      return command.isRelative
          ? Offset(currentX + command.x, currentY + command.y)
          : Offset(command.x, command.y);
    } else if (command is SmoothCubicBezierCommand) {
      return command.isRelative
          ? Offset(currentX + command.x, currentY + command.y)
          : Offset(command.x, command.y);
    } else if (command is QuadraticBezierCommand) {
      return command.isRelative
          ? Offset(currentX + command.x, currentY + command.y)
          : Offset(command.x, command.y);
    } else if (command is SmoothQuadraticBezierCommand) {
      return command.isRelative
          ? Offset(currentX + command.x, currentY + command.y)
          : Offset(command.x, command.y);
    } else if (command is ArcCommand) {
      return command.isRelative
          ? Offset(currentX + command.x, currentY + command.y)
          : Offset(command.x, command.y);
    } else if (command is ClosePathCommand) {
      return Offset(subpathStartX, subpathStartY);
    }
    return Offset(currentX, currentY);
  }

  /// Apply a command to the Flutter Path
  void _applyCommand(
    PathCommand command,
    double currentX,
    double currentY,
    double subpathStartX,
    double subpathStartY,
    PathCommand? prevCommand,
  ) {
    if (command is MoveToCommand) {
      final x = command.isRelative ? currentX + command.x : command.x;
      final y = command.isRelative ? currentY + command.y : command.y;
      _path.moveTo(x, y);
    } else if (command is LineToCommand) {
      final x = command.isRelative ? currentX + command.x : command.x;
      final y = command.isRelative ? currentY + command.y : command.y;
      _path.lineTo(x, y);
    } else if (command is HorizontalLineToCommand) {
      final x = command.isRelative ? currentX + command.x : command.x;
      _path.lineTo(x, currentY);
    } else if (command is VerticalLineToCommand) {
      final y = command.isRelative ? currentY + command.y : command.y;
      _path.lineTo(currentX, y);
    } else if (command is CubicBezierCommand) {
      final absCmd = command.isRelative
          ? command.toAbsolute(currentX, currentY) as CubicBezierCommand
          : command;
      _path.cubicTo(
        absCmd.x1,
        absCmd.y1,
        absCmd.x2,
        absCmd.y2,
        absCmd.x,
        absCmd.y,
      );
    } else if (command is SmoothCubicBezierCommand) {
      final cubic = command.toCubicBezier(
        currentX: currentX,
        currentY: currentY,
        previousCommand: prevCommand,
      );
      final absCmd = cubic.isRelative
          ? cubic.toAbsolute(currentX, currentY) as CubicBezierCommand
          : cubic;
      _path.cubicTo(
        absCmd.x1,
        absCmd.y1,
        absCmd.x2,
        absCmd.y2,
        absCmd.x,
        absCmd.y,
      );
    } else if (command is QuadraticBezierCommand) {
      final absCmd = command.isRelative
          ? command.toAbsolute(currentX, currentY) as QuadraticBezierCommand
          : command;
      _path.quadraticBezierTo(absCmd.x1, absCmd.y1, absCmd.x, absCmd.y);
    } else if (command is SmoothQuadraticBezierCommand) {
      final quad = command.toQuadraticBezier(
        currentX: currentX,
        currentY: currentY,
        previousCommand: prevCommand,
      );
      final absCmd = quad.isRelative
          ? quad.toAbsolute(currentX, currentY) as QuadraticBezierCommand
          : quad;
      _path.quadraticBezierTo(absCmd.x1, absCmd.y1, absCmd.x, absCmd.y);
    } else if (command is ArcCommand) {
      // Convert arc to a Flutter path using arcToPoint
      _applyArcCommand(command, currentX, currentY);
    } else if (command is ClosePathCommand) {
      _path.close();
    }
  }

  /// Apply arc command to Flutter path
  void _applyArcCommand(ArcCommand arc, double currentX, double currentY) {
    final endX = arc.isRelative ? currentX + arc.x : arc.x;
    final endY = arc.isRelative ? currentY + arc.y : arc.y;

    // Handle degenerate arcs (zero radii or same start/end)
    if (arc.rx == 0 || arc.ry == 0) {
      _path.lineTo(endX, endY);
      return;
    }

    if (currentX == endX && currentY == endY) {
      return; // Nothing to draw
    }

    _path.arcToPoint(
      Offset(endX, endY),
      radius: Radius.elliptical(arc.rx.abs(), arc.ry.abs()),
      rotation: arc.rotation,
      largeArc: arc.largeArc,
      clockwise: arc.sweep,
    );
  }

  /// Compute path segment lengths
  void _computeSegmentLengths() {
    final pathMetrics = _path.computeMetrics();
    final metrics = pathMetrics.toList();

    if (metrics.isEmpty) {
      _totalLength = 0;
      _cumulativeLengths = [0];
      return;
    }

    _totalLength = 0;
    _cumulativeLengths = [0];

    for (final metric in metrics) {
      _totalLength += metric.length;
      _cumulativeLengths.add(_totalLength);
    }
  }

  /// Detect if this is a closed path by checking if end point matches start
  /// Uses epsilon comparison for floating point equality per Blink behavior
  void _detectClosedPath() {
    if (_commands.isEmpty) {
      _isClosed = false;
      return;
    }

    // Find start position (first MoveTo command)
    double startX = 0, startY = 0;
    double currentX = 0, currentY = 0;

    for (final command in _commands) {
      if (command is MoveToCommand) {
        if (_startPosition == null) {
          startX = command.isRelative ? currentX + command.x : command.x;
          startY = command.isRelative ? currentY + command.y : command.y;
          _startPosition = Offset(startX, startY);
        }
        currentX = command.isRelative ? currentX + command.x : command.x;
        currentY = command.isRelative ? currentY + command.y : command.y;
      } else if (command is ClosePathCommand) {
        currentX = startX;
        currentY = startY;
        _isClosed = true;
      } else {
        final endPoint = _getCommandEndPoint(
          command,
          currentX,
          currentY,
          startX,
          startY,
        );
        currentX = endPoint.dx;
        currentY = endPoint.dy;
      }
    }

    _endPosition = Offset(currentX, currentY);

    // Check if end position is very close to start position (epsilon comparison)
    if (!_isClosed && _startPosition != null) {
      final distance = (_endPosition! - _startPosition!).distance;
      _isClosed = distance < _closedPathTolerance;
    }
  }

  /// Whether this path is closed (either explicitly or by coincident endpoints)
  bool get isClosed => _isClosed;

  /// Check if two points are coincident within tolerance
  static bool arePointsCoincident(
    Offset a,
    Offset b, {
    double tolerance = _closedPathTolerance,
  }) {
    return (a - b).distance < tolerance;
  }

  /// Get the point on the path at time t ∈ [0, 1]
  ///
  /// The parameter [t] represents progress along the path (0 = start, 1 = end)
  /// [useAverageTangent] - whether to average tangents at segment boundaries
  MotionPathPoint getPointAtTime(double t, {bool useAverageTangent = true}) {
    // Handle zero-length path - return start position if available
    if (_totalLength == 0 || _totalLength < _closedPathTolerance) {
      // For zero-length paths, return the start position with zero angle
      if (_startPosition != null) {
        return MotionPathPoint(position: _startPosition!, angle: 0);
      }
      return const MotionPathPoint(position: Offset.zero, angle: 0);
    }

    // Clamp t
    final clampedT = t.clamp(0.0, 1.0);

    // Compute the absolute distance along the path
    final distance = _totalLength * clampedT;

    // Recompute PathMetrics each time (PathMetrics is an iterator)
    final pathMetrics = _path.computeMetrics();
    final metrics = pathMetrics.toList();

    if (metrics.isEmpty) {
      if (_startPosition != null) {
        return MotionPathPoint(position: _startPosition!, angle: 0);
      }
      return const MotionPathPoint(position: Offset.zero, angle: 0);
    }

    double accumulatedLength = 0;
    int metricIndex = 0;

    for (final metric in metrics) {
      if (distance <= accumulatedLength + metric.length) {
        // The point is in this segment
        final localDistance = distance - accumulatedLength;
        final tangent = metric.getTangentForOffset(localDistance);

        if (tangent != null) {
          double angle = tangent.angle;

          // Handle degenerate case: zero-length segment
          if (metric.length < 0.001 && metrics.length > 1) {
            // Try to get angle from adjacent segment
            angle = _getAngleFromAdjacentSegment(metrics, metricIndex);
          }

          // Handle path discontinuity (moveTo) at start of segment
          if (localDistance < 0.001 && metricIndex > 0) {
            // Check if this is a discontinuity by comparing end of prev
            // segment with start of current
            final prevEnd = metrics[metricIndex - 1].getTangentForOffset(
              metrics[metricIndex - 1].length,
            );
            final currStart = metric.getTangentForOffset(0);
            if (prevEnd != null && currStart != null) {
              final dist = (prevEnd.position - currStart.position).distance;
              // If there's a gap, this is a moveTo - use current segment's angle
              if (dist > 0.1) {
                // Discontinuity detected - use angle from current segment only
                final forwardTangent = metric.getTangentForOffset(
                  math.min(0.1, metric.length),
                );
                if (forwardTangent != null) {
                  angle = forwardTangent.angle;
                }
              }
            }
          }

          // Average tangents at segment boundaries
          if (useAverageTangent) {
            angle = _getAveragedAngle(
              metrics,
              metricIndex,
              localDistance,
              metric.length,
              angle,
            );
          }

          return MotionPathPoint(position: tangent.position, angle: angle);
        }
      }
      accumulatedLength += metric.length;
      metricIndex++;
    }

    // If not found (e.g., due to rounding), return the last point
    final lastMetric = metrics.last;
    final tangent = lastMetric.getTangentForOffset(lastMetric.length);

    return MotionPathPoint(
      position: tangent?.position ?? Offset.zero,
      angle: tangent?.angle ?? 0,
    );
  }

  /// Get angle from adjacent segment for degenerate (zero-length) segments
  double _getAngleFromAdjacentSegment(List<PathMetric> metrics, int index) {
    // Try next segment first
    if (index + 1 < metrics.length && metrics[index + 1].length > 0.001) {
      final nextTangent = metrics[index + 1].getTangentForOffset(0);
      if (nextTangent != null) return nextTangent.angle;
    }
    // Try previous segment
    if (index > 0 && metrics[index - 1].length > 0.001) {
      final prevTangent = metrics[index - 1].getTangentForOffset(
        metrics[index - 1].length,
      );
      if (prevTangent != null) return prevTangent.angle;
    }
    return 0;
  }

  /// Average tangent angles at segment boundaries for smooth rotation
  /// This implements Blink's behavior at path segment junctions
  double _getAveragedAngle(
    List<PathMetric> metrics,
    int metricIndex,
    double localDistance,
    double segmentLength,
    double currentAngle,
  ) {
    const boundaryThreshold = 0.01; // Within 1% of boundary

    // Check if we're at the start of a segment (junction with previous)
    if (localDistance < segmentLength * boundaryThreshold && metricIndex > 0) {
      final prevMetric = metrics[metricIndex - 1];
      final prevTangent = prevMetric.getTangentForOffset(prevMetric.length);
      if (prevTangent != null) {
        return _averageAngles(prevTangent.angle, currentAngle);
      }
    }

    // Check if we're at the end of a segment (junction with next)
    if (localDistance > segmentLength * (1 - boundaryThreshold) &&
        metricIndex + 1 < metrics.length) {
      final nextMetric = metrics[metricIndex + 1];
      final nextTangent = nextMetric.getTangentForOffset(0);
      if (nextTangent != null) {
        return _averageAngles(currentAngle, nextTangent.angle);
      }
    }

    return currentAngle;
  }

  /// Average two angles, handling the wrap-around at ±π
  double _averageAngles(double angle1, double angle2) {
    // Normalize angles to [-π, π]
    angle1 = _normalizeAngle(angle1);
    angle2 = _normalizeAngle(angle2);

    // Handle wrap-around: if angles are on opposite sides of ±π, adjust
    if ((angle1 - angle2).abs() > math.pi) {
      if (angle1 < 0) {
        angle1 += 2 * math.pi;
      } else {
        angle2 += 2 * math.pi;
      }
    }

    return _normalizeAngle((angle1 + angle2) / 2);
  }

  /// Normalize angle to [-π, π]
  double _normalizeAngle(double angle) {
    while (angle > math.pi) {
      angle -= 2 * math.pi;
    }
    while (angle < -math.pi) {
      angle += 2 * math.pi;
    }
    return angle;
  }

  /// Get the point on the path using keyPoints.
  ///
  /// KeyPoints allow controlling the speed of movement along the path.
  /// Each element of keyPoints corresponds to a value in values and specifies
  /// a position on the path (from 0 to 1).
  MotionPathPoint getPointWithKeyPoints(
    double t,
    List<double> keyPoints,
    List<double>? keyTimes,
  ) {
    if (keyPoints.isEmpty || keyPoints.length < 2) {
      return getPointAtTime(t);
    }

    // Determine which keyTimes interval we are in
    int fromIndex = 0;
    int toIndex = 1;
    double segmentProgress = t;

    if (keyTimes != null && keyTimes.length == keyPoints.length) {
      // With explicit keyTimes
      // First check boundary cases
      if (t <= keyTimes.first) {
        return getPointAtTime(keyPoints.first);
      }
      if (t >= keyTimes.last) {
        return getPointAtTime(keyPoints.last);
      }

      for (int i = 0; i < keyTimes.length - 1; i++) {
        if (t >= keyTimes[i] && t <= keyTimes[i + 1]) {
          fromIndex = i;
          toIndex = i + 1;
          final segmentStart = keyTimes[i];
          final segmentEnd = keyTimes[i + 1];
          segmentProgress = segmentEnd > segmentStart
              ? (t - segmentStart) / (segmentEnd - segmentStart)
              : 0.0;
          break;
        }
      }
    } else {
      // Without keyTimes - uniform distribution
      final segmentCount = keyPoints.length - 1;

      // Boundary cases
      if (t <= 0.0) {
        return getPointAtTime(keyPoints.first);
      }
      if (t >= 1.0) {
        return getPointAtTime(keyPoints.last);
      }

      final segmentIndex = (t * segmentCount).floor().clamp(
        0,
        segmentCount - 1,
      );
      fromIndex = segmentIndex;
      toIndex = segmentIndex + 1;
      segmentProgress = (t * segmentCount) - segmentIndex;
    }

    // Interpolate keyPoints
    final fromKeyPoint = keyPoints[fromIndex];
    final toKeyPoint = keyPoints[toIndex];
    final interpolatedKeyPoint =
        fromKeyPoint + (toKeyPoint - fromKeyPoint) * segmentProgress;

    // Get the point on the path for the interpolated keyPoint
    return getPointAtTime(interpolatedKeyPoint);
  }

  /// Total path length
  double get totalLength => _totalLength;

  /// Get list of segment lengths for paced calcMode distance calculation
  List<double> getSegmentLengths() {
    final pathMetrics = _path.computeMetrics();
    return pathMetrics.map((m) => m.length).toList();
  }

  /// Get the final position on the path (for accumulate support)
  Offset getEndPosition() {
    if (_totalLength == 0) return Offset.zero;
    final point = getPointAtTime(1.0);
    return point.position;
  }

  /// Convert an angle to degrees (for transform rotate)
  static double radiansToDegrees(double radians) {
    return radians * 180.0 / math.pi;
  }

  /// Parse a coordinate pair string "x,y" or "x y" into Offset
  static Offset? parseCoordinatePair(String value) {
    final cleaned = value.trim();
    if (cleaned.isEmpty) return null;

    // Split by comma or whitespace
    final parts = cleaned.split(RegExp(r'[,\s]+'));
    if (parts.length < 2) return null;

    final x = double.tryParse(parts[0]);
    final y = double.tryParse(parts[1]);
    if (x == null || y == null) return null;

    return Offset(x, y);
  }

  /// Parse a list of coordinate pairs from values string
  /// Format: "x1,y1;x2,y2;..." or "x1 y1;x2 y2;..."
  static List<Offset> parseCoordinatePairs(String values) {
    final result = <Offset>[];
    final pairs = values
        .split(';')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty);

    for (final pair in pairs) {
      final offset = parseCoordinatePair(pair);
      if (offset != null) {
        result.add(offset);
      }
    }

    return result;
  }
}
