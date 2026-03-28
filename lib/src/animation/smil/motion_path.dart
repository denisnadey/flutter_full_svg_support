import 'dart:math' as math;
import 'dart:ui';

import '../path_data.dart';
import '../path_parser.dart';

/// Результат вычисления позиции на пути движения
class MotionPathPoint {
  const MotionPathPoint({required this.position, required this.angle});

  /// Позиция точки на пути
  final Offset position;

  /// Угол касательной в данной точке (в радианах)
  /// Используется для rotate="auto"
  final double angle;
}

/// Класс для вычисления позиции и ориентации элемента вдоль SVG пути
///
/// Используется для реализации SMIL <animateMotion>
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

  /// Флаттер Path для измерений
  late Path _path;

  /// Общая длина пути
  late double _totalLength;

  /// Длины сегментов пути (кумулятивные)
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

  /// Распарсить SVG path data
  void _parsePath(String pathData) {
    try {
      final parser = PathParser();
      _commands = parser.parse(pathData);

      // Конвертируем команды в Flutter Path
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
      // Если парсинг не удался, создаём пустой путь
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

  /// Применить команду к Flutter Path
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

  /// Вычислить длины сегментов пути
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

  /// Получить точку на пути в момент времени t ∈ [0, 1]
  ///
  /// Параметр [t] представляет прогресс вдоль пути (0 = начало, 1 = конец)
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

    // Ограничиваем t
    final clampedT = t.clamp(0.0, 1.0);

    // Вычисляем абсолютное расстояние вдоль пути
    final distance = _totalLength * clampedT;

    // Получаем PathMetrics каждый раз заново (PathMetrics - это итератор)
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
        // Точка находится в этом сегменте
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

    // Если не нашли (например, из-за округления), возвращаем конечную точку
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

  /// Получить точку на пути используя keyPoints
  ///
  /// KeyPoints позволяют контролировать скорость движения вдоль пути.
  /// Каждый элемент keyPoints соответствует значению в values и указывает
  /// позицию на пути (от 0 до 1).
  MotionPathPoint getPointWithKeyPoints(
    double t,
    List<double> keyPoints,
    List<double>? keyTimes,
  ) {
    if (keyPoints.isEmpty || keyPoints.length < 2) {
      return getPointAtTime(t);
    }

    // Определяем между какими keyTimes мы находимся
    int fromIndex = 0;
    int toIndex = 1;
    double segmentProgress = t;

    if (keyTimes != null && keyTimes.length == keyPoints.length) {
      // С явными keyTimes
      // Сначала проверим граничные случаи
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
      // Без keyTimes - равномерное распределение
      final segmentCount = keyPoints.length - 1;

      // Граничные случаи
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

    // Интерполируем keyPoints
    final fromKeyPoint = keyPoints[fromIndex];
    final toKeyPoint = keyPoints[toIndex];
    final interpolatedKeyPoint =
        fromKeyPoint + (toKeyPoint - fromKeyPoint) * segmentProgress;

    // Получаем точку на пути для интерполированного keyPoint
    return getPointAtTime(interpolatedKeyPoint);
  }

  /// Общая длина пути
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

  /// Преобразовать угол в градусы (для transform rotate)
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
