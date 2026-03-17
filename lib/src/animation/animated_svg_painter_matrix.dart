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
        // 3D transforms - project to 2D
        case SvgTransformType.translate3d:
          final tx = item.values.isNotEmpty ? item.values[0] : 0.0;
          final ty = item.values.length > 1 ? item.values[1] : 0.0;
          // Z translation ignored in 2D
          final translation3d = Matrix4.identity()
            ..setEntry(0, 3, tx)
            ..setEntry(1, 3, ty);
          matrix.multiply(translation3d);
          break;
        case SvgTransformType.translateZ:
          // Z-only translation has no effect in 2D
          break;
        case SvgTransformType.scale3d:
          final sx = item.values.isNotEmpty ? item.values[0] : 1.0;
          final sy = item.values.length > 1 ? item.values[1] : 1.0;
          // Z scale ignored in 2D
          final scale3d = Matrix4.identity()
            ..setEntry(0, 0, sx)
            ..setEntry(1, 1, sy);
          matrix.multiply(scale3d);
          break;
        case SvgTransformType.scaleZ:
          // Z-only scale has no effect in 2D
          break;
        case SvgTransformType.rotateX:
          // X rotation produces perspective effect - extract 2D projection
          final angleX = item.values.isNotEmpty ? item.values[0] : 0.0;
          final radiansX = angleX * math.pi / 180.0;
          final matrix3dX = Matrix4x4.rotationX(radiansX);
          final extracted2dX = matrix3dX.extract2DMatrix();
          final projectedX = Matrix4.identity()
            ..setEntry(0, 0, extracted2dX[0])
            ..setEntry(1, 0, extracted2dX[1])
            ..setEntry(0, 1, extracted2dX[2])
            ..setEntry(1, 1, extracted2dX[3])
            ..setEntry(0, 3, extracted2dX[4])
            ..setEntry(1, 3, extracted2dX[5]);
          matrix.multiply(projectedX);
          break;
        case SvgTransformType.rotateY:
          // Y rotation produces perspective effect - extract 2D projection
          final angleY = item.values.isNotEmpty ? item.values[0] : 0.0;
          final radiansY = angleY * math.pi / 180.0;
          final matrix3dY = Matrix4x4.rotationY(radiansY);
          final extracted2dY = matrix3dY.extract2DMatrix();
          final projectedY = Matrix4.identity()
            ..setEntry(0, 0, extracted2dY[0])
            ..setEntry(1, 0, extracted2dY[1])
            ..setEntry(0, 1, extracted2dY[2])
            ..setEntry(1, 1, extracted2dY[3])
            ..setEntry(0, 3, extracted2dY[4])
            ..setEntry(1, 3, extracted2dY[5]);
          matrix.multiply(projectedY);
          break;
        case SvgTransformType.rotateZ:
          // Same as regular rotate
          final angleZ = item.values.isNotEmpty ? item.values[0] : 0.0;
          final radiansZ = angleZ * math.pi / 180.0;
          matrix.rotateZ(radiansZ);
          break;
        case SvgTransformType.rotate3d:
          // rotate3d(x, y, z, angle)
          if (item.values.length >= 4) {
            final axisX = item.values[0];
            final axisY = item.values[1];
            final axisZ = item.values[2];
            final angle3d = item.values[3] * math.pi / 180.0;
            final matrix3d = Matrix4x4.rotation3d(axisX, axisY, axisZ, angle3d);
            final extracted2d = matrix3d.extract2DMatrix();
            final projected3d = Matrix4.identity()
              ..setEntry(0, 0, extracted2d[0])
              ..setEntry(1, 0, extracted2d[1])
              ..setEntry(0, 1, extracted2d[2])
              ..setEntry(1, 1, extracted2d[3])
              ..setEntry(0, 3, extracted2d[4])
              ..setEntry(1, 3, extracted2d[5]);
            matrix.multiply(projected3d);
          }
          break;
        case SvgTransformType.perspective:
          // Perspective has no direct effect in 2D without 3D context
          break;
        case SvgTransformType.matrix3d:
          // Extract 2D affine subset from 4x4 matrix
          if (item.values.length >= 16) {
            final matrix4x4 = Matrix4x4.fromMatrix3d(item.values);
            final extracted = matrix4x4.extract2DMatrix();
            final projected = Matrix4.identity()
              ..setEntry(0, 0, extracted[0])
              ..setEntry(1, 0, extracted[1])
              ..setEntry(0, 1, extracted[2])
              ..setEntry(1, 1, extracted[3])
              ..setEntry(0, 3, extracted[4])
              ..setEntry(1, 3, extracted[5]);
            matrix.multiply(projected);
          }
          break;
      }
    }

    return matrix;
  }
}
