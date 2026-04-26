import 'dart:math' as math;
import 'dart:ui' as ui;

import '../svg_dom.dart';
import '../svg_transform.dart';
import 'motion_path.dart';

/// Abstract class for computing the distance between values.
/// Used for calcMode="paced" to generate keyTimes
abstract class DistanceCalculator {
  /// Compute the distance between two values.
  /// Returns a non-negative number, or -1 if the distance cannot be computed
  double distance(Object? from, Object? to);
}

/// Distance calculator for numeric values
class NumericDistanceCalculator extends DistanceCalculator {
  @override
  double distance(Object? from, Object? to) {
    if (from == null || to == null) return -1.0;

    final fromNum = _toDouble(from);
    final toNum = _toDouble(to);

    if (fromNum == null || toNum == null) return -1.0;

    // Simple absolute difference, as in Blink SVGAnimatedNumberAnimator
    return (toNum - fromNum).abs();
  }

  double? _toDouble(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) {
      // Parse the string, stripping units of measurement
      final cleaned = value.trim().replaceAll(RegExp(r'[a-zA-Z%]+$'), '');
      return double.tryParse(cleaned);
    }
    return null;
  }
}

/// Distance calculator for colors.
/// Uses Euclidean distance in RGB space, as in Blink
class ColorDistanceCalculator extends DistanceCalculator {
  @override
  double distance(Object? from, Object? to) {
    if (from == null || to == null) return -1.0;

    final fromColor = _toColor(from);
    final toColor = _toColor(to);

    if (fromColor == null || toColor == null) return -1.0;

    // Euclidean distance in RGB space
    // As in Blink ColorDistance::distance()
    // Use .r, .g, .b instead of deprecated .red, .green, .blue
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
    // For strings, parsing may be needed, but values are usually already parsed
    return null;
  }
}

/// Distance calculator for lengths (accounting for units of measurement).
/// Converts lengths to pixels, as in Blink SVGAnimatedLengthAnimator
class LengthDistanceCalculator extends DistanceCalculator {
  @override
  double distance(Object? from, Object? to) {
    if (from == null || to == null) return -1.0;

    final fromNum = _toDouble(from);
    final toNum = _toDouble(to);

    if (fromNum == null || toNum == null) return -1.0;

    // For lengths, use the absolute difference.
    // In Blink, SVGLength is converted to pixels via SVGLengthContext,
    // but for simplicity we use numeric values for now
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

/// Distance calculator for paths (path morphing).
/// Uses path length via PathMetrics
class PathDistanceCalculator extends DistanceCalculator {
  @override
  double distance(Object? from, Object? to) {
    final fromPath = _toPath(from);
    final toPath = _toPath(to);
    if (fromPath == null || toPath == null) {
      return -1.0;
    }

    // Estimate the distance as the sum of:
    // 1) |length(from) - length(to)|
    // 2) average displacement of corresponding points along the path.
    // This gives a stable metric for paced keyTimes without heavy geometry.
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

/// Distance calculator for transform animations.
/// Uses Euclidean distance between points for motion
class TransformDistanceCalculator extends DistanceCalculator {
  @override
  double distance(Object? from, Object? to) {
    final fromDecomp = _toDecomposition(from);
    final toDecomp = _toDecomposition(to);
    if (fromDecomp == null || toDecomp == null) {
      return -1.0;
    }

    // Normalized Euclidean metric over decomposition components.
    // Angles are converted to degrees and scale is amplified by a factor
    // so that the contribution of scale/rotate is not lost relative to translate.
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

/// Factory for creating the appropriate distance calculator
class DistanceCalculatorFactory {
  /// Create a calculator for the given attribute type
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
        // For points, use numeric distance
        return NumericDistanceCalculator();

      case SvgAttributeType.string:
      case SvgAttributeType.url:
      case SvgAttributeType.list:
        // For strings and other types, use numeric as fallback
        return NumericDistanceCalculator();
    }
  }
}
