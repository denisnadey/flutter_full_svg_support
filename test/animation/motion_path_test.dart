import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_svg/src/animation/smil/motion_path.dart';

void main() {
  group('MotionPath', () {
    test('simple line path at t=0', () {
      final path = MotionPath('M0,0 L100,0');
      final point = path.getPointAtTime(0.0);

      expect(point.position.dx, closeTo(0, 0.1));
      expect(point.position.dy, closeTo(0, 0.1));
    });

    test('simple line path at t=0.5', () {
      final path = MotionPath('M0,0 L100,0');
      final point = path.getPointAtTime(0.5);

      expect(point.position.dx, closeTo(50, 1));
      expect(point.position.dy, closeTo(0, 0.1));
    });

    test('simple line path at t=1', () {
      final path = MotionPath('M0,0 L100,0');
      final point = path.getPointAtTime(1.0);

      expect(point.position.dx, closeTo(100, 0.1));
      expect(point.position.dy, closeTo(0, 0.1));
    });

    test('horizontal line has angle 0', () {
      final path = MotionPath('M0,0 L100,0');
      final point = path.getPointAtTime(0.5);

      // Горизонтальная линия вправо должна иметь угол 0 радиан
      expect(point.angle, closeTo(0, 0.01));
    });

    test('vertical line down has angle -π/2', () {
      final path = MotionPath('M0,0 L0,100');
      final point = path.getPointAtTime(0.5);

      // Вертикальная линия вниз в системе координат Flutter имеет угол -π/2
      expect(point.angle, closeTo(-math.pi / 2, 0.01));
    });

    test('diagonal line has correct angle', () {
      final path = MotionPath('M0,0 L100,100');
      final point = path.getPointAtTime(0.5);

      // Диагональная линия вправо-вниз имеет отрицательный угол
      expect(point.angle.abs(), greaterThan(0));
    });

    test('curved path interpolation', () {
      // Кубическая кривая Безье
      final path = MotionPath('M0,0 C50,0 50,100 100,100');
      final point = path.getPointAtTime(0.5);

      // Проверяем, что точка находится где-то в середине кривой
      expect(point.position.dx, greaterThan(20));
      expect(point.position.dx, lessThan(80));
      expect(point.position.dy, greaterThan(20));
      expect(point.position.dy, lessThan(80));
    });

    test('clamps t to [0, 1]', () {
      final path = MotionPath('M0,0 L100,0');

      final pointNegative = path.getPointAtTime(-1.0);
      expect(pointNegative.position.dx, closeTo(0, 0.1));

      final pointOver = path.getPointAtTime(2.0);
      expect(pointOver.position.dx, closeTo(100, 0.1));
    });

    test('empty path returns zero position', () {
      final path = MotionPath('');
      final point = path.getPointAtTime(0.5);

      expect(point.position, equals(Offset.zero));
      expect(point.angle, equals(0));
    });

    test('complex path with multiple segments', () {
      final path = MotionPath('M0,0 L50,0 L50,50 L0,50 Z');
      final totalLength = path.totalLength;

      // Квадрат периметром 200
      expect(totalLength, closeTo(200, 1));

      // Точка в середине должна быть на правой стороне квадрата
      final midPoint = path.getPointAtTime(0.5);
      expect(midPoint.position.dx, closeTo(50, 5));
      expect(midPoint.position.dy, greaterThan(0));
    });

    test('totalLength returns correct value', () {
      final path = MotionPath('M0,0 L100,0');
      expect(path.totalLength, closeTo(100, 0.1));
    });

    test('radiansToDegrees converts correctly', () {
      expect(MotionPath.radiansToDegrees(0), closeTo(0, 0.01));
      expect(MotionPath.radiansToDegrees(math.pi), closeTo(180, 0.01));
      expect(MotionPath.radiansToDegrees(math.pi / 2), closeTo(90, 0.01));
      expect(MotionPath.radiansToDegrees(2 * math.pi), closeTo(360, 0.01));
    });

    group('keyPoints', () {
      test('basic keyPoints usage', () {
        final path = MotionPath('M0,0 L100,0');
        // keyPoints указывают позиции на пути: начало и конец
        final keyPoints = [0.0, 1.0];

        final point = path.getPointWithKeyPoints(0.5, keyPoints, null);
        // При t=0.5 между keyPoints[0]=0.0 и keyPoints[1]=1.0
        // должны быть на середине пути
        expect(point.position.dx, closeTo(50, 1));
      });

      test('keyPoints with non-linear distribution', () {
        final path = MotionPath('M0,0 L100,0');
        // Объект быстро движется в первой половине (0→0.8),
        // затем медленно во второй (0.8→1.0)
        final keyPoints = [0.0, 0.8, 1.0];

        // При t=0.5 (середина времени) интерполируем между
        // keyPoints[1]=0.8 и keyPoints[2]=1.0
        final point = path.getPointWithKeyPoints(0.5, keyPoints, null);
        expect(point.position.dx, greaterThan(70)); // За 80% пути
      });

      test('keyPoints with keyTimes', () {
        final path = MotionPath('M0,0 L100,0');
        final keyPoints = [0.0, 0.5, 1.0];
        final keyTimes = [0.0, 0.3, 1.0]; // Неравномерное время

        // При t=0.3 находимся на keyPoints[1]=0.5 (50% пути)
        final point = path.getPointWithKeyPoints(0.3, keyPoints, keyTimes);
        expect(point.position.dx, closeTo(50, 5));
      });

      test('keyPoints with single point falls back to normal', () {
        final path = MotionPath('M0,0 L100,0');
        final keyPoints = [0.5];

        // С одним keyPoint должны использовать обычный getPointAtTime
        final point = path.getPointWithKeyPoints(0.5, keyPoints, null);
        expect(point.position.dx, closeTo(50, 1));
      });

      test('keyPoints interpolation at boundaries', () {
        final path = MotionPath('M0,0 L100,0');
        final keyPoints = [0.0, 0.5, 1.0];

        // При t=0 должны быть в начале
        final startPoint = path.getPointWithKeyPoints(0.0, keyPoints, null);
        expect(startPoint.position.dx, closeTo(0, 0.1));

        // При t=1 должны быть в конце
        final endPoint = path.getPointWithKeyPoints(1.0, keyPoints, null);
        expect(endPoint.position.dx, closeTo(100, 0.1));
      });
    });

    test('invalid path data handles gracefully', () {
      final path = MotionPath('invalid path data');
      final point = path.getPointAtTime(0.5);

      // Должен вернуть безопасное значение (нулевую позицию)
      expect(point.position, equals(Offset.zero));
      expect(path.totalLength, equals(0));
    });

    test('path with moveTo commands', () {
      // Путь с несколькими disconnected сегментами
      final path = MotionPath('M0,0 L50,0 M100,0 L150,0');
      final totalLength = path.totalLength;

      // Два сегмента длиной 50 каждый
      expect(totalLength, closeTo(100, 1));
    });
  });
}
