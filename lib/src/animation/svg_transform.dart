import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import 'transform_3d.dart';

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

  // 3D transform types

  /// translate3d(x, y, z)
  translate3d,

  /// translateZ(z)
  translateZ,

  /// scale3d(x, y, z)
  scale3d,

  /// scaleZ(z)
  scaleZ,

  /// rotateX(angle)
  rotateX,

  /// rotateY(angle)
  rotateY,

  /// rotateZ(angle) - alias for rotate
  rotateZ,

  /// rotate3d(x, y, z, angle)
  rotate3d,

  /// perspective(length)
  perspective,

  /// matrix3d - 4x4 matrix (16 values)
  matrix3d,
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
  /// - 3D transforms: translate3d, translateZ, rotateX, rotateY, rotateZ,
  ///   rotate3d, scale3d, scaleZ, perspective, matrix3d
  static List<SvgTransform> parse(String transformString) {
    final transforms = <SvgTransform>[];
    // Updated regex to include 3D transform functions
    final regex = RegExp(
      r'(translate3d|translatez|translate|rotate3d|rotatex|rotatey|rotatez|rotate|scale3d|scalez|scale|skewX|skewY|matrix3d|matrix|perspective)\s*\(\s*([^)]+)\s*\)',
      caseSensitive: false,
    );

    for (final match in regex.allMatches(transformString)) {
      final type = match.group(1)!.toLowerCase();
      final valuesStr = match.group(2)!;
      final values = valuesStr
          .split(RegExp(r'[\s,]+'))
          .where((s) => s.isNotEmpty)
          .map((s) => _parseValueWithUnit(s))
          .toList();

      final transformType = switch (type) {
        'translate' => SvgTransformType.translate,
        'rotate' => SvgTransformType.rotate,
        'scale' => SvgTransformType.scale,
        'skewx' => SvgTransformType.skewX,
        'skewy' => SvgTransformType.skewY,
        'matrix' => SvgTransformType.matrix,
        // 3D transform types
        'translate3d' => SvgTransformType.translate3d,
        'translatez' => SvgTransformType.translateZ,
        'scale3d' => SvgTransformType.scale3d,
        'scalez' => SvgTransformType.scaleZ,
        'rotatex' => SvgTransformType.rotateX,
        'rotatey' => SvgTransformType.rotateY,
        'rotatez' => SvgTransformType.rotateZ,
        'rotate3d' => SvgTransformType.rotate3d,
        'perspective' => SvgTransformType.perspective,
        'matrix3d' => SvgTransformType.matrix3d,
        _ => null,
      };

      if (transformType != null) {
        transforms.add(SvgTransform(type: transformType, values: values));
      }
    }

    return transforms;
  }

  /// Parses a value that may include units (deg, rad, px, em, etc.)
  static double _parseValueWithUnit(String s) {
    final trimmed = s.trim().toLowerCase();

    // Handle angle units first
    if (trimmed.endsWith('deg')) {
      return double.tryParse(trimmed.substring(0, trimmed.length - 3)) ?? 0.0;
    } else if (trimmed.endsWith('rad')) {
      final rad =
          double.tryParse(trimmed.substring(0, trimmed.length - 3)) ?? 0.0;
      return rad * 180.0 / math.pi; // Convert to degrees
    } else if (trimmed.endsWith('turn')) {
      final turn =
          double.tryParse(trimmed.substring(0, trimmed.length - 4)) ?? 0.0;
      return turn * 360.0; // Convert to degrees
    } else if (trimmed.endsWith('grad')) {
      final grad =
          double.tryParse(trimmed.substring(0, trimmed.length - 4)) ?? 0.0;
      return grad * 0.9; // Convert to degrees
    }

    // Handle length units for translate functions
    // Map of unit suffixes to their pixel conversion factors
    // Base assumptions: 16px = 1em = 1rem, 96dpi for absolute units
    // Sorted by length descending to avoid 'em' matching 'rem'
    const lengthUnits = <String, double>{
      'rem': 16.0, // Must come before 'em'
      'em': 16.0,
      'px': 1.0,
      'ex': 8.0,
      'ch': 8.0,
      'cm': 37.795,
      'mm': 3.7795,
      'in': 96.0,
      'pt': 1.333,
      'pc': 16.0,
    };

    for (final entry in lengthUnits.entries) {
      if (trimmed.endsWith(entry.key)) {
        final numStr = trimmed.substring(0, trimmed.length - entry.key.length);
        final num = double.tryParse(numStr) ?? 0.0;
        return num * entry.value;
      }
    }

    // Handle percentage (for transforms, just parse the number as-is)
    if (trimmed.endsWith('%')) {
      return double.tryParse(trimmed.substring(0, trimmed.length - 1)) ?? 0.0;
    }

    return double.tryParse(trimmed) ?? 0.0;
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
/// для более плавной интерполяции между различными трансформациями.
/// Uses QR decomposition for proper handling of arbitrary 2D matrices.
@immutable
class TransformDecomposition {
  const TransformDecomposition({
    required this.translateX,
    required this.translateY,
    required this.rotation,
    required this.scaleX,
    required this.scaleY,
    required this.skewX,
    this.skewY = 0.0,
  });

  /// Identity transform decomposition.
  static const identity = TransformDecomposition(
    translateX: 0.0,
    translateY: 0.0,
    rotation: 0.0,
    scaleX: 1.0,
    scaleY: 1.0,
    skewX: 0.0,
    skewY: 0.0,
  );

  final double translateX;
  final double translateY;
  final double rotation; // в радианах
  final double scaleX;
  final double scaleY;
  final double skewX; // в радианах
  final double skewY; // в радианах

  /// Создаёт декомпозицию из списка трансформаций
  factory TransformDecomposition.fromTransforms(List<SvgTransform> transforms) {
    double tx = 0.0, ty = 0.0;
    double rotation = 0.0;
    double sx = 1.0, sy = 1.0;
    double skewX = 0.0;
    double skewY = 0.0;

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
          skewY += transform.values.isNotEmpty
              ? transform.values[0] * math.pi / 180.0
              : 0.0;
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
        // 3D transforms - project to 2D for decomposition
        case SvgTransformType.translate3d:
          tx += transform.values.isNotEmpty ? transform.values[0] : 0.0;
          ty += transform.values.length > 1 ? transform.values[1] : 0.0;
          // Z translation is ignored in 2D projection
          break;
        case SvgTransformType.translateZ:
          // Z-only translation has no effect in 2D without perspective
          break;
        case SvgTransformType.scale3d:
          sx *= transform.values.isNotEmpty ? transform.values[0] : 1.0;
          sy *= transform.values.length > 1 ? transform.values[1] : 1.0;
          // Z scale is ignored in 2D projection
          break;
        case SvgTransformType.scaleZ:
          // Z-only scale has no effect in 2D without perspective
          break;
        case SvgTransformType.rotateX:
        case SvgTransformType.rotateY:
          // X/Y rotations produce perspective effects
          // For decomposition, we extract the projected 2D transform
          final angle = transform.values.isNotEmpty
              ? transform.values[0] * math.pi / 180.0
              : 0.0;
          final matrix = transform.type == SvgTransformType.rotateX
              ? Matrix4x4.rotationX(angle)
              : Matrix4x4.rotationY(angle);
          final extracted = matrix.extract2DMatrix();
          final matrixDecomp = _decomposeMatrix(extracted);
          rotation += matrixDecomp.rotation;
          sx *= matrixDecomp.scaleX;
          sy *= matrixDecomp.scaleY;
          skewX += matrixDecomp.skewX;
          break;
        case SvgTransformType.rotateZ:
          // Same as regular rotate
          rotation += transform.values.isNotEmpty
              ? transform.values[0] * math.pi / 180.0
              : 0.0;
          break;
        case SvgTransformType.rotate3d:
          // rotate3d(x, y, z, angle)
          if (transform.values.length >= 4) {
            final axisX = transform.values[0];
            final axisY = transform.values[1];
            final axisZ = transform.values[2];
            final angle = transform.values[3] * math.pi / 180.0;
            final matrix = Matrix4x4.rotation3d(axisX, axisY, axisZ, angle);
            final extracted = matrix.extract2DMatrix();
            final matrixDecomp = _decomposeMatrix(extracted);
            rotation += matrixDecomp.rotation;
            sx *= matrixDecomp.scaleX;
            sy *= matrixDecomp.scaleY;
            skewX += matrixDecomp.skewX;
          }
          break;
        case SvgTransformType.perspective:
          // Perspective doesn't affect decomposition directly
          break;
        case SvgTransformType.matrix3d:
          // Extract 2D portion of 4x4 matrix
          if (transform.values.length >= 16) {
            final matrix = Matrix4x4.fromMatrix3d(transform.values);
            final extracted = matrix.extract2DMatrix();
            final matrixDecomp = _decomposeMatrix(extracted);
            tx += matrixDecomp.translateX;
            ty += matrixDecomp.translateY;
            rotation += matrixDecomp.rotation;
            sx *= matrixDecomp.scaleX;
            sy *= matrixDecomp.scaleY;
            skewX += matrixDecomp.skewX;
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
      skewY: skewY,
    );
  }

  /// Интерполирует между двумя декомпозициями
  TransformDecomposition lerp(TransformDecomposition other, double t) {
    // Handle rotation interpolation via shortest path
    var fromRotation = rotation;
    var toRotation = other.rotation;
    final rotationDiff = toRotation - fromRotation;
    // If rotation difference is > pi, take the shorter path
    if (rotationDiff > math.pi) {
      fromRotation += 2 * math.pi;
    } else if (rotationDiff < -math.pi) {
      toRotation += 2 * math.pi;
    }

    return TransformDecomposition(
      translateX: ui.lerpDouble(translateX, other.translateX, t)!,
      translateY: ui.lerpDouble(translateY, other.translateY, t)!,
      rotation: ui.lerpDouble(fromRotation, toRotation, t)!,
      scaleX: ui.lerpDouble(scaleX, other.scaleX, t)!,
      scaleY: ui.lerpDouble(scaleY, other.scaleY, t)!,
      skewX: ui.lerpDouble(skewX, other.skewX, t)!,
      skewY: ui.lerpDouble(skewY, other.skewY, t)!,
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

    if (skewY != 0.0) {
      result.add(
        SvgTransform(
          type: SvgTransformType.skewY,
          values: [skewY * 180.0 / math.pi],
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
        'skewX: ${skewX * 180 / math.pi}°, '
        'skewY: ${skewY * 180 / math.pi}°)';
  }

  /// Decomposes a 2D matrix into translation, rotation, scale, and skew.
  /// Uses QR decomposition with improved handling of degenerate matrices.
  static TransformDecomposition _decomposeMatrix(List<double> values) {
    if (values.length < 6) {
      return TransformDecomposition.identity;
    }

    final a0 = values[0];
    final b0 = values[1];
    final c0 = values[2];
    final d0 = values[3];
    final tx = values[4];
    final ty = values[5];
    const epsilon = 1e-12;

    // Check for degenerate matrix (zero determinant)
    final determinant = a0 * d0 - b0 * c0;
    if (determinant.abs() < epsilon) {
      // Degenerate matrix - return identity-like transform with translation
      return TransformDecomposition(
        translateX: tx,
        translateY: ty,
        rotation: 0.0,
        scaleX: 0.0,
        scaleY: 0.0,
        skewX: 0.0,
        skewY: 0.0,
      );
    }

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
        skewY: 0.0,
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

    final det = a * d - b * c;
    if (det < 0) {
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
      skewY: 0.0, // skewY is not extracted from matrix decomposition
    );
  }
}
