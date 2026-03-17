part of 'animated_svg_picture.dart';

extension _AnimatedSvgPictureStateTransformExtension
    on _AnimatedSvgPictureState {
  void _applyForeignObjectChildTransform(Matrix4 matrix, SvgNode node) {
    if (node.tagName != 'foreignObject') {
      return;
    }
    final width = _getNumber(node, 'width') ?? 0.0;
    final height = _getNumber(node, 'height') ?? 0.0;
    if (width <= 0 || height <= 0) {
      return;
    }
    final x = _getNumber(node, 'x') ?? 0.0;
    final y = _getNumber(node, 'y') ?? 0.0;
    matrix.translateByDouble(x, y, 0, 1);
  }

  /// Applies nested SVG viewport transform within foreignObject for hit-testing.
  void _applyNestedSvgTransformInForeignObject(
    Matrix4 matrix,
    SvgNode svgNode,
    SvgNode foreignObjectNode,
  ) {
    if (svgNode.tagName != 'svg') {
      return;
    }
    if (foreignObjectNode.tagName != 'foreignObject') {
      return;
    }

    // Get foreignObject viewport dimensions
    final foWidth = _getNumber(foreignObjectNode, 'width') ?? 0.0;
    final foHeight = _getNumber(foreignObjectNode, 'height') ?? 0.0;
    if (foWidth <= 0 || foHeight <= 0) {
      return;
    }

    // Get nested SVG attributes
    final svgX = _getNumber(svgNode, 'x') ?? 0.0;
    final svgY = _getNumber(svgNode, 'y') ?? 0.0;
    var svgWidth = _getNumber(svgNode, 'width');
    var svgHeight = _getNumber(svgNode, 'height');

    // Default width/height to 100% of foreignObject viewport
    svgWidth ??= foWidth;
    svgHeight ??= foHeight;

    if (svgWidth <= 0 || svgHeight <= 0) {
      return;
    }

    // Translate to SVG position
    if (svgX != 0 || svgY != 0) {
      matrix.translateByDouble(svgX, svgY, 0, 1);
    }

    // Apply viewBox transform if present
    final viewBoxAttr = svgNode.getAttributeValue('viewBox')?.toString();
    if (viewBoxAttr != null && viewBoxAttr.trim().isNotEmpty) {
      final viewBox = _parseViewBoxRect(viewBoxAttr);
      if (viewBox != null && viewBox.width > 0 && viewBox.height > 0) {
        final layout = resolveSvgViewportLayout(
          viewport: Rect.fromLTWH(0, 0, svgWidth, svgHeight),
          sourceSize: Size(viewBox.width, viewBox.height),
          preserveAspectRatio:
              svgNode.getAttributeValue('preserveAspectRatio')?.toString(),
        );

        // Compute viewBox to viewport transform
        final scaleX = layout.destinationRect.width / viewBox.width;
        final scaleY = layout.destinationRect.height / viewBox.height;
        final translateX = layout.destinationRect.left - viewBox.left * scaleX;
        final translateY = layout.destinationRect.top - viewBox.top * scaleY;

        matrix.translateByDouble(translateX, translateY, 0, 1);
        matrix.scaleByDouble(scaleX, scaleY, 1, 1);
      }
    }
  }

  Rect? _parseViewBoxRect(String viewBoxStr) {
    final parts = viewBoxStr.trim().split(RegExp(r'[\s,]+'));
    if (parts.length < 4) return null;
    final minX = double.tryParse(parts[0]);
    final minY = double.tryParse(parts[1]);
    final width = double.tryParse(parts[2]);
    final height = double.tryParse(parts[3]);
    if (minX == null || minY == null || width == null || height == null) {
      return null;
    }
    return Rect.fromLTWH(minX, minY, width, height);
  }

  void _applyNodeTransform(Matrix4 matrix, SvgNode node) {
    final transformAttr = node.getAttributeValue('transform')?.toString();
    if (transformAttr == null || transformAttr.isEmpty) return;

    final transforms = SvgTransform.parse(transformAttr);
    for (final transform in transforms) {
      switch (transform.type) {
        case SvgTransformType.translate:
          final tx = transform.values.isNotEmpty ? transform.values[0] : 0.0;
          final ty = transform.values.length > 1 ? transform.values[1] : 0.0;
          matrix.translateByDouble(tx, ty, 0, 1);
          break;
        case SvgTransformType.scale:
          final sx = transform.values.isNotEmpty ? transform.values[0] : 1.0;
          final sy = transform.values.length > 1 ? transform.values[1] : sx;
          matrix.scaleByDouble(sx, sy, 1, 1);
          break;
        case SvgTransformType.rotate:
          final angle = transform.values.isNotEmpty ? transform.values[0] : 0.0;
          final radians = angle * math.pi / 180.0;
          if (transform.values.length >= 3) {
            final cx = transform.values[1];
            final cy = transform.values[2];
            matrix
              ..translateByDouble(cx, cy, 0, 1)
              ..rotateZ(radians)
              ..translateByDouble(-cx, -cy, 0, 1);
          } else {
            matrix.rotateZ(radians);
          }
          break;
        case SvgTransformType.skewX:
          final angle = transform.values.isNotEmpty ? transform.values[0] : 0.0;
          final skew = Matrix4.identity()
            ..setEntry(0, 1, math.tan(angle * math.pi / 180.0));
          matrix.multiply(skew);
          break;
        case SvgTransformType.skewY:
          final angle = transform.values.isNotEmpty ? transform.values[0] : 0.0;
          final skew = Matrix4.identity()
            ..setEntry(1, 0, math.tan(angle * math.pi / 180.0));
          matrix.multiply(skew);
          break;
        case SvgTransformType.matrix:
          if (transform.values.length >= 6) {
            final a = transform.values[0];
            final b = transform.values[1];
            final c = transform.values[2];
            final d = transform.values[3];
            final e = transform.values[4];
            final f = transform.values[5];
            final custom = Matrix4.identity()
              ..setEntry(0, 0, a)
              ..setEntry(1, 0, b)
              ..setEntry(0, 1, c)
              ..setEntry(1, 1, d)
              ..setEntry(0, 3, e)
              ..setEntry(1, 3, f);
            matrix.multiply(custom);
          }
          break;
        // 3D transforms - project to 2D
        case SvgTransformType.translate3d:
          final tx3d = transform.values.isNotEmpty ? transform.values[0] : 0.0;
          final ty3d = transform.values.length > 1 ? transform.values[1] : 0.0;
          // Z translation ignored in 2D
          matrix.translateByDouble(tx3d, ty3d, 0, 1);
          break;
        case SvgTransformType.translateZ:
          // Z-only translation has no effect in 2D
          break;
        case SvgTransformType.scale3d:
          final sx3d = transform.values.isNotEmpty ? transform.values[0] : 1.0;
          final sy3d = transform.values.length > 1 ? transform.values[1] : 1.0;
          // Z scale ignored in 2D
          matrix.scaleByDouble(sx3d, sy3d, 1, 1);
          break;
        case SvgTransformType.scaleZ:
          // Z-only scale has no effect in 2D
          break;
        case SvgTransformType.rotateX:
          // X rotation produces perspective effect - extract 2D projection
          final angleX = transform.values.isNotEmpty ? transform.values[0] : 0.0;
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
          final angleY = transform.values.isNotEmpty ? transform.values[0] : 0.0;
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
          final angleZ = transform.values.isNotEmpty ? transform.values[0] : 0.0;
          final radiansZ = angleZ * math.pi / 180.0;
          matrix.rotateZ(radiansZ);
          break;
        case SvgTransformType.rotate3d:
          // rotate3d(x, y, z, angle)
          if (transform.values.length >= 4) {
            final axisX = transform.values[0];
            final axisY = transform.values[1];
            final axisZ = transform.values[2];
            final angle3d = transform.values[3] * math.pi / 180.0;
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
          if (transform.values.length >= 16) {
            final matrix4x4 = Matrix4x4.fromMatrix3d(transform.values);
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
  }
}
