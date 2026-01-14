import 'dart:math' as math;
import 'dart:ui' as ui;

import '../svg_dom.dart';

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
    if (from == null || to == null) return -1.0;

    // Для путей нужно парсить и сравнивать длины
    // Это сложнее, пока возвращаем -1 (не поддерживается)
    // В Blink SVGAnimatedPathAnimator тоже возвращает -1 с FIXME
    return -1.0;
  }
}

/// Вычислитель расстояния для transform анимаций
/// Использует Euclidean distance между точками для motion
class TransformDistanceCalculator extends DistanceCalculator {
  @override
  double distance(Object? from, Object? to) {
    if (from == null || to == null) return -1.0;

    // Для transform это сложно, так как нужно разбирать разные типы
    // (translate, rotate, scale, skew)
    // Пока возвращаем -1, как в некоторых случаях в Blink
    return -1.0;
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
