part of 'animated_svg_painter.dart';

extension AnimatedSvgPainterMatrixExtension on AnimatedSvgPainter {
  Float64List? _parseGradientTransformMatrix(Object? value) {
    final matrix = _buildTransformMatrixFromValue(value);
    return matrix?.storage;
  }

  Matrix4? _buildTransformMatrixFromValue(Object? value) {
    final transform = value?.toString();
    if (transform == null || transform.trim().isEmpty) {
      return null;
    }

    final matrix = Matrix4.identity();
    final transforms = SvgTransform.parse(transform);
    if (transforms.isEmpty) {
      return null;
    }

    for (final item in transforms) {
      switch (item.type) {
        case SvgTransformType.translate:
          final tx = item.values.isNotEmpty ? item.values[0] : 0.0;
          final ty = item.values.length > 1 ? item.values[1] : 0.0;
          final translation = Matrix4.identity()
            ..setEntry(0, 3, tx)
            ..setEntry(1, 3, ty);
          matrix.multiply(translation);
          break;
        case SvgTransformType.scale:
          final sx = item.values.isNotEmpty ? item.values[0] : 1.0;
          final sy = item.values.length > 1 ? item.values[1] : sx;
          final scale = Matrix4.identity()
            ..setEntry(0, 0, sx)
            ..setEntry(1, 1, sy);
          matrix.multiply(scale);
          break;
        case SvgTransformType.rotate:
          final angle = item.values.isNotEmpty ? item.values[0] : 0.0;
          final radians = angle * math.pi / 180.0;
          if (item.values.length >= 3) {
            final cx = item.values[1];
            final cy = item.values[2];
            final toCenter = Matrix4.identity()
              ..setEntry(0, 3, cx)
              ..setEntry(1, 3, cy);
            final fromCenter = Matrix4.identity()
              ..setEntry(0, 3, -cx)
              ..setEntry(1, 3, -cy);
            matrix
              ..multiply(toCenter)
              ..rotateZ(radians)
              ..multiply(fromCenter);
          } else {
            matrix.rotateZ(radians);
          }
          break;
        case SvgTransformType.skewX:
          final angle = item.values.isNotEmpty ? item.values[0] : 0.0;
          final skew = Matrix4.identity()
            ..setEntry(0, 1, math.tan(angle * math.pi / 180.0));
          matrix.multiply(skew);
          break;
        case SvgTransformType.skewY:
          final angle = item.values.isNotEmpty ? item.values[0] : 0.0;
          final skew = Matrix4.identity()
            ..setEntry(1, 0, math.tan(angle * math.pi / 180.0));
          matrix.multiply(skew);
          break;
        case SvgTransformType.matrix:
          if (item.values.length >= 6) {
            final custom = Matrix4.identity()
              ..setEntry(0, 0, item.values[0])
              ..setEntry(1, 0, item.values[1])
              ..setEntry(0, 1, item.values[2])
              ..setEntry(1, 1, item.values[3])
              ..setEntry(0, 3, item.values[4])
              ..setEntry(1, 3, item.values[5]);
            matrix.multiply(custom);
          }
          break;
      }
    }

    return matrix;
  }
}
