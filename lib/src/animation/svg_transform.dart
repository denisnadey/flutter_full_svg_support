import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

/// Тип SVG трансформации
enum SvgTransformType {
  /// translate(x [y])
  translate,

  /// rotate(angle [cx cy])
  rotate,

  /// scale(x [y])
  scale,

  /// skewX(angle)
  skewX,

  /// skewY(angle)
  skewY,

  /// matrix(a b c d e f)
  matrix,
}

/// Представление SVG transform attribute
///
/// Поддерживает парсинг и интерполяцию различных типов трансформаций:
/// - translate(x, y)
/// - rotate(angle, cx, cy)
/// - scale(x, y)
/// - skewX(angle)
/// - skewY(angle)
/// - matrix(a, b, c, d, e, f)
@immutable
class SvgTransform {
  /// Создаёт трансформацию заданного типа
  const SvgTransform({required this.type, required this.values});

  /// Тип трансформации
  final SvgTransformType type;

  /// Числовые значения трансформации
  /// - translate: [tx, ty] (ty опционален, по умолчанию 0)
  /// - rotate: [angle, cx, cy] (cx, cy опциональны, по умолчанию 0)
  /// - scale: [sx, sy] (sy опционален, по умолчанию равен sx)
  /// - skewX/skewY: [angle]
  /// - matrix: [a, b, c, d, e, f]
  final List<double> values;

  /// Парсит SVG transform строку в список трансформаций
  ///
  /// Поддерживает:
  /// - translate(10, 20)
  /// - rotate(45)
  /// - rotate(45, 50, 50) - с центром вращения
  /// - scale(2)
  /// - scale(2, 3)
  /// - matrix(1, 0, 0, 1, 0, 0)
  /// - Комбинации: "translate(10, 20) rotate(45)"
  static List<SvgTransform> parse(String transformString) {
    final transforms = <SvgTransform>[];
    final regex = RegExp(
      r'(translate|rotate|scale|skewX|skewY|matrix)\s*\(\s*([^)]+)\s*\)',
      caseSensitive: false,
    );

    for (final match in regex.allMatches(transformString)) {
      final type = match.group(1)!.toLowerCase();
      final valuesStr = match.group(2)!;
      final values = valuesStr
          .split(RegExp(r'[\s,]+'))
          .where((s) => s.isNotEmpty)
          .map((s) => double.tryParse(s) ?? 0.0)
          .toList();

      final transformType = switch (type) {
        'translate' => SvgTransformType.translate,
        'rotate' => SvgTransformType.rotate,
        'scale' => SvgTransformType.scale,
        'skewx' => SvgTransformType.skewX,
        'skewy' => SvgTransformType.skewY,
        'matrix' => SvgTransformType.matrix,
        _ => null,
      };

      if (transformType != null) {
        transforms.add(SvgTransform(type: transformType, values: values));
      }
    }

    return transforms;
  }

  /// Конвертирует трансформацию в Matrix4
  ui.Offset toMatrix4() {
    // Для простоты возвращаем offset для translate
    // Полная реализация Matrix4 будет добавлена при необходимости
    if (type == SvgTransformType.translate) {
      return ui.Offset(
        values.isNotEmpty ? values[0] : 0.0,
        values.length > 1 ? values[1] : 0.0,
      );
    }
    return ui.Offset.zero;
  }

  /// Возвращает строковое представление для отладки
  @override
  String toString() {
    final name = type.toString().split('.').last;
    return 'SvgTransform.$name(${values.join(', ')})';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SvgTransform &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          listEquals(values, other.values);

  @override
  int get hashCode => Object.hash(type, Object.hashAll(values));
}

/// Декомпозиция матрицы трансформации для интерполяции
///
/// Разбивает matrix на компоненты: translate, rotate, scale, skew
/// для более плавной интерполяции между различными трансформациями
@immutable
class TransformDecomposition {
  const TransformDecomposition({
    required this.translateX,
    required this.translateY,
    required this.rotation,
    required this.scaleX,
    required this.scaleY,
    required this.skewX,
  });

  final double translateX;
  final double translateY;
  final double rotation; // в радианах
  final double scaleX;
  final double scaleY;
  final double skewX; // в радианах

  /// Создаёт декомпозицию из списка трансформаций
  factory TransformDecomposition.fromTransforms(List<SvgTransform> transforms) {
    double tx = 0.0, ty = 0.0;
    double rotation = 0.0;
    double sx = 1.0, sy = 1.0;
    double skewX = 0.0;

    for (final transform in transforms) {
      switch (transform.type) {
        case SvgTransformType.translate:
          tx += transform.values.isNotEmpty ? transform.values[0] : 0.0;
          ty += transform.values.length > 1 ? transform.values[1] : 0.0;
        case SvgTransformType.rotate:
          rotation += transform.values.isNotEmpty
              ? transform.values[0] * math.pi / 180.0
              : 0.0;
        case SvgTransformType.scale:
          sx *= transform.values.isNotEmpty ? transform.values[0] : 1.0;
          sy *= transform.values.length > 1
              ? transform.values[1]
              : (transform.values.isNotEmpty ? transform.values[0] : 1.0);
        case SvgTransformType.skewX:
          skewX += transform.values.isNotEmpty
              ? transform.values[0] * math.pi / 180.0
              : 0.0;
        case SvgTransformType.skewY:
          // Пока поддерживаем только skewX в декомпозиции.
          break;
        case SvgTransformType.matrix:
          if (transform.values.length >= 6) {
            final matrixDecomposition = _decomposeMatrix(transform.values);
            tx += matrixDecomposition.translateX;
            ty += matrixDecomposition.translateY;
            rotation += matrixDecomposition.rotation;
            sx *= matrixDecomposition.scaleX;
            sy *= matrixDecomposition.scaleY;
            skewX += matrixDecomposition.skewX;
          }
          break;
      }
    }

    return TransformDecomposition(
      translateX: tx,
      translateY: ty,
      rotation: rotation,
      scaleX: sx,
      scaleY: sy,
      skewX: skewX,
    );
  }

  /// Интерполирует между двумя декомпозициями
  TransformDecomposition lerp(TransformDecomposition other, double t) {
    return TransformDecomposition(
      translateX: ui.lerpDouble(translateX, other.translateX, t)!,
      translateY: ui.lerpDouble(translateY, other.translateY, t)!,
      rotation: ui.lerpDouble(rotation, other.rotation, t)!,
      scaleX: ui.lerpDouble(scaleX, other.scaleX, t)!,
      scaleY: ui.lerpDouble(scaleY, other.scaleY, t)!,
      skewX: ui.lerpDouble(skewX, other.skewX, t)!,
    );
  }

  /// Преобразует обратно в список трансформаций
  List<SvgTransform> toTransforms() {
    final result = <SvgTransform>[];

    if (translateX != 0.0 || translateY != 0.0) {
      result.add(
        SvgTransform(
          type: SvgTransformType.translate,
          values: [translateX, translateY],
        ),
      );
    }

    if (rotation != 0.0) {
      result.add(
        SvgTransform(
          type: SvgTransformType.rotate,
          values: [rotation * 180.0 / math.pi],
        ),
      );
    }

    if (scaleX != 1.0 || scaleY != 1.0) {
      result.add(
        SvgTransform(type: SvgTransformType.scale, values: [scaleX, scaleY]),
      );
    }

    if (skewX != 0.0) {
      result.add(
        SvgTransform(
          type: SvgTransformType.skewX,
          values: [skewX * 180.0 / math.pi],
        ),
      );
    }

    return result;
  }

  @override
  String toString() {
    return 'TransformDecomposition('
        'translate: ($translateX, $translateY), '
        'rotation: ${rotation * 180 / math.pi}°, '
        'scale: ($scaleX, $scaleY), '
        'skewX: ${skewX * 180 / math.pi}°)';
  }

  static TransformDecomposition _decomposeMatrix(List<double> values) {
    final a0 = values[0];
    final b0 = values[1];
    final c0 = values[2];
    final d0 = values[3];
    final tx = values[4];
    final ty = values[5];
    const epsilon = 1e-12;

    var a = a0;
    var b = b0;
    var c = c0;
    var d = d0;

    final scaleXRaw = math.sqrt(a * a + b * b);
    if (scaleXRaw <= epsilon) {
      final scaleYFallback = math.sqrt(c * c + d * d);
      final rotationFallback = scaleYFallback <= epsilon
          ? 0.0
          : math.atan2(-c, d);
      return TransformDecomposition(
        translateX: tx,
        translateY: ty,
        rotation: rotationFallback,
        scaleX: 0.0,
        scaleY: scaleYFallback,
        skewX: 0.0,
      );
    }

    var scaleX = scaleXRaw;
    a /= scaleX;
    b /= scaleX;

    var skew = a * c + b * d;
    c -= a * skew;
    d -= b * skew;

    var scaleY = math.sqrt(c * c + d * d);
    if (scaleY > epsilon) {
      c /= scaleY;
      d /= scaleY;
      skew /= scaleY;
    } else {
      scaleY = 0.0;
      skew = 0.0;
    }

    final determinant = a * d - b * c;
    if (determinant < 0) {
      scaleX = -scaleX;
      skew = -skew;
      a = -a;
      b = -b;
    }

    final rotation = math.atan2(b, a);
    final skewX = math.atan(skew);

    return TransformDecomposition(
      translateX: tx,
      translateY: ty,
      rotation: rotation,
      scaleX: scaleX,
      scaleY: scaleY,
      skewX: skewX,
    );
  }
}
