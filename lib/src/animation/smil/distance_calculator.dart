import 'dart:math' as math;
import 'dart:ui' as ui;

import '../svg_dom.dart';
import '../svg_transform.dart';
import 'motion_path.dart';

/// Абстрактный класс для вычисления расстояния между значениями
/// Используется для calcMode="paced" для генерации keyTimes
abstract class DistanceCalculator {
  /// Вычислить расстояние между двумя значениями
  /// Возвращает неотрицательное число или -1 если расстояние не может быть вычислено
  double distance(Object? from, Object? to);
}

/// Вычислитель расстояния для числовых значений
class NumericDistanceCalculator extends DistanceCalculator {
  @override
  double distance(Object? from, Object? to) {
    if (from == null || to == null) return -1.0;

    final fromNum = _toDouble(from);
    final toNum = _toDouble(to);

    if (fromNum == null || toNum == null) return -1.0;

    // Просто абсолютная разница, как в Blink SVGAnimatedNumberAnimator
    return (toNum - fromNum).abs();
  }

  double? _toDouble(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) {
      // Парсим строку, убирая единицы измерения
      final cleaned = value.trim().replaceAll(RegExp(r'[a-zA-Z%]+$'), '');
      return double.tryParse(cleaned);
    }
    return null;
  }
}

/// Вычислитель расстояния для цветов
/// Использует Euclidean distance в RGB пространстве, как в Blink
class ColorDistanceCalculator extends DistanceCalculator {
  @override
  double distance(Object? from, Object? to) {
    if (from == null || to == null) return -1.0;

    final fromColor = _toColor(from);
    final toColor = _toColor(to);

    if (fromColor == null || toColor == null) return -1.0;

    // Euclidean distance в RGB пространстве
    // Как в Blink ColorDistance::distance()
    // Используем .r, .g, .b вместо deprecated .red, .green, .blue
    final fromR = (fromColor.r * 255.0).round().clamp(0, 255);
    final fromG = (fromColor.g * 255.0).round().clamp(0, 255);
    final fromB = (fromColor.b * 255.0).round().clamp(0, 255);
    final toR = (toColor.r * 255.0).round().clamp(0, 255);
    final toG = (toColor.g * 255.0).round().clamp(0, 255);
    final toB = (toColor.b * 255.0).round().clamp(0, 255);
    
    final dr = toR - fromR;
    final dg = toG - fromG;
    final db = toB - fromB;

    return math.sqrt(dr * dr + dg * dg + db * db);
  }

  ui.Color? _toColor(Object? value) {
    if (value is ui.Color) return value;
    // Для строк может потребоваться парсинг, но обычно значения уже парсятся
    return null;
  }
}

/// Вычислитель расстояния для длин (с учетом единиц измерения)
/// Конвертирует длины в пиксели, как в Blink SVGAnimatedLengthAnimator
class LengthDistanceCalculator extends DistanceCalculator {
  @override
  double distance(Object? from, Object? to) {
    if (from == null || to == null) return -1.0;

    final fromNum = _toDouble(from);
    final toNum = _toDouble(to);

    if (fromNum == null || toNum == null) return -1.0;

    // Для длин используем абсолютную разницу
    // В Blink SVGLength конвертируется в пиксели через SVGLengthContext,
    // но для упрощения пока используем числовые значения
    return (toNum - fromNum).abs();
  }

  double? _toDouble(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) {
      final cleaned = value.trim().replaceAll(RegExp(r'[a-zA-Z%]+$'), '');
      return double.tryParse(cleaned);
    }
    return null;
  }
}

/// Вычислитель расстояния для путей (path morphing)
/// Использует длину пути через PathMetrics
class PathDistanceCalculator extends DistanceCalculator {
  @override
  double distance(Object? from, Object? to) {
    final fromPath = _toPath(from);
    final toPath = _toPath(to);
    if (fromPath == null || toPath == null) {
      return -1.0;
    }

    // Оцениваем расстояние как сумму:
    // 1) |длина(from) - длина(to)|
    // 2) среднее смещение соответствующих точек вдоль пути.
    // Это даёт стабильную метрику для paced keyTimes без тяжёлой геометрии.
    final lengthDelta = (fromPath.totalLength - toPath.totalLength).abs();
    const sampleCount = 24;
    var sampledDelta = 0.0;
    for (int i = 0; i <= sampleCount; i++) {
      final t = i / sampleCount;
      final p1 = fromPath.getPointAtTime(t).position;
      final p2 = toPath.getPointAtTime(t).position;
      sampledDelta += (p2 - p1).distance;
    }
    return lengthDelta + sampledDelta / (sampleCount + 1);
  }

  MotionPath? _toPath(Object? value) {
    if (value == null) {
      return null;
    }
    final raw = value.toString().trim();
    if (raw.isEmpty) {
      return null;
    }
    try {
      return MotionPath(raw);
    } catch (_) {
      return null;
    }
  }
}

/// Вычислитель расстояния для transform анимаций
/// Использует Euclidean distance между точками для motion
class TransformDistanceCalculator extends DistanceCalculator {
  @override
  double distance(Object? from, Object? to) {
    final fromDecomp = _toDecomposition(from);
    final toDecomp = _toDecomposition(to);
    if (fromDecomp == null || toDecomp == null) {
      return -1.0;
    }

    // Нормализованная евклидова метрика по компонентам декомпозиции.
    // Углы переводим в градусы, масштаб усиливаем коэффициентом,
    // чтобы вклад scale/rotate не терялся относительно translate.
    final dTranslateX = toDecomp.translateX - fromDecomp.translateX;
    final dTranslateY = toDecomp.translateY - fromDecomp.translateY;
    final dRotationDeg =
        (toDecomp.rotation - fromDecomp.rotation).abs() * 180.0 / math.pi;
    final dSkewDeg =
        (toDecomp.skewX - fromDecomp.skewX).abs() * 180.0 / math.pi;
    final dScaleX = (toDecomp.scaleX - fromDecomp.scaleX) * 100.0;
    final dScaleY = (toDecomp.scaleY - fromDecomp.scaleY) * 100.0;

    return math.sqrt(
      dTranslateX * dTranslateX +
          dTranslateY * dTranslateY +
          dRotationDeg * dRotationDeg +
          dSkewDeg * dSkewDeg +
          dScaleX * dScaleX +
          dScaleY * dScaleY,
    );
  }

  TransformDecomposition? _toDecomposition(Object? value) {
    if (value == null) {
      return null;
    }
    final raw = value.toString().trim();
    if (raw.isEmpty) {
      return const TransformDecomposition(
        translateX: 0.0,
        translateY: 0.0,
        rotation: 0.0,
        scaleX: 1.0,
        scaleY: 1.0,
        skewX: 0.0,
      );
    }
    try {
      final transforms = SvgTransform.parse(raw);
      return TransformDecomposition.fromTransforms(transforms);
    } catch (_) {
      return null;
    }
  }
}

/// Фабрика для создания подходящего калькулятора расстояний
class DistanceCalculatorFactory {
  /// Создать калькулятор для заданного типа атрибута
  static DistanceCalculator create(SvgAttributeType attributeType) {
    switch (attributeType) {
      case SvgAttributeType.number:
      case SvgAttributeType.length:
        return NumericDistanceCalculator();

      case SvgAttributeType.color:
        return ColorDistanceCalculator();

      case SvgAttributeType.path:
        return PathDistanceCalculator();

      case SvgAttributeType.transform:
        return TransformDistanceCalculator();

      case SvgAttributeType.points:
        // Для points используем numeric distance
        return NumericDistanceCalculator();

      case SvgAttributeType.string:
      case SvgAttributeType.url:
      case SvgAttributeType.list:
        // Для строк и других типов используем numeric как fallback
        return NumericDistanceCalculator();
    }
  }
}
