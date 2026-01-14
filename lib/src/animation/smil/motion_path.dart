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
  }

  /// Флаттер Path для измерений
  late Path _path;

  /// Общая длина пути
  late double _totalLength;

  /// Длины сегментов пути (кумулятивные)
  late List<double> _cumulativeLengths;

  /// Распарсить SVG path data
  void _parsePath(String pathData) {
    try {
      final parser = PathParser();
      final commands = parser.parse(pathData);

      // Конвертируем команды в Flutter Path
      _path = Path();
      for (final command in commands) {
        _applyCommand(command);
      }
    } catch (e) {
      // Если парсинг не удался, создаём пустой путь
      _path = Path();
    }
  }

  /// Применить команду к Flutter Path
  void _applyCommand(PathCommand command) {
    if (command is MoveToCommand) {
      _path.moveTo(command.x, command.y);
    } else if (command is LineToCommand) {
      _path.lineTo(command.x, command.y);
    } else if (command is CubicBezierCommand) {
      _path.cubicTo(
        command.x1,
        command.y1,
        command.x2,
        command.y2,
        command.x,
        command.y,
      );
    } else if (command is QuadraticBezierCommand) {
      _path.quadraticBezierTo(command.x1, command.y1, command.x, command.y);
    } else if (command is ClosePathCommand) {
      _path.close();
    }
    // Для других команд (Arc и т.д.) можно добавить поддержку позже
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

  /// Получить точку на пути в момент времени t ∈ [0, 1]
  ///
  /// Параметр [t] представляет прогресс вдоль пути (0 = начало, 1 = конец)
  MotionPathPoint getPointAtTime(double t) {
    if (_totalLength == 0) {
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
      return const MotionPathPoint(position: Offset.zero, angle: 0);
    }

    double accumulatedLength = 0;

    for (final metric in metrics) {
      if (distance <= accumulatedLength + metric.length) {
        // Точка находится в этом сегменте
        final localDistance = distance - accumulatedLength;
        final tangent = metric.getTangentForOffset(localDistance);

        if (tangent != null) {
          return MotionPathPoint(
            position: tangent.position,
            angle: tangent.angle,
          );
        }
      }
      accumulatedLength += metric.length;
    }

    // Если не нашли (например, из-за округления), возвращаем конечную точку
    final lastMetric = metrics.last;
    final tangent = lastMetric.getTangentForOffset(lastMetric.length);

    return MotionPathPoint(
      position: tangent?.position ?? Offset.zero,
      angle: tangent?.angle ?? 0,
    );
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

  /// Преобразовать угол в градусы (для transform rotate)
  static double radiansToDegrees(double radians) {
    return radians * 180.0 / math.pi;
  }
}
