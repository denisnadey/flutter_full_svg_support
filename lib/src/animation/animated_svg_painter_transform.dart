part of 'animated_svg_painter.dart';

extension AnimatedSvgPainterCanvasTransformExtension on AnimatedSvgPainter {
  void _applyTransform(ui.Canvas canvas, SvgNode node) {
    final transformStr = _getString(node, 'transform');
    if (transformStr == null || transformStr.isEmpty) return;

    // Парсим трансформации
    final transforms = SvgTransform.parse(transformStr);
    if (transforms.isEmpty) return;

    // Применяем каждую трансформацию в порядке объявления
    for (final transform in transforms) {
      switch (transform.type) {
        case SvgTransformType.translate:
          final tx = transform.values.isNotEmpty ? transform.values[0] : 0.0;
          final ty = transform.values.length > 1 ? transform.values[1] : 0.0;
          canvas.translate(tx, ty);

        case SvgTransformType.rotate:
          final angle = transform.values.isNotEmpty ? transform.values[0] : 0.0;
          final cx = transform.values.length > 1 ? transform.values[1] : 0.0;
          final cy = transform.values.length > 2 ? transform.values[2] : 0.0;

          // Rotate with center point
          if (cx != 0.0 || cy != 0.0) {
            canvas.translate(cx, cy);
            canvas.rotate(angle * 3.14159 / 180.0); // degrees to radians
            canvas.translate(-cx, -cy);
          } else {
            canvas.rotate(angle * 3.14159 / 180.0);
          }

        case SvgTransformType.scale:
          final sx = transform.values.isNotEmpty ? transform.values[0] : 1.0;
          final sy = transform.values.length > 1
              ? transform.values[1]
              : sx; // sy defaults to sx
          canvas.scale(sx, sy);

        case SvgTransformType.skewX:
          final angle = transform.values.isNotEmpty ? transform.values[0] : 0.0;
          final radians = angle * 3.14159 / 180.0;
          final tanValue = radians.isFinite ? radians : 0.0;
          // skewX matrix: [1, tan(angle), 0]
          //               [0,     1,      0]
          //               [0,     0,      1]
          final matrix = Matrix4.identity()
            ..setEntry(0, 1, tanValue); // Set skewX component
          canvas.transform(matrix.storage);

        case SvgTransformType.skewY:
          final angle = transform.values.isNotEmpty ? transform.values[0] : 0.0;
          final radians = angle * 3.14159 / 180.0;
          final tanValue = radians.isFinite ? radians : 0.0;
          // skewY matrix: [    1,      0, 0]
          //               [tan(angle), 1, 0]
          //               [    0,      0, 1]
          final matrix = Matrix4.identity()
            ..setEntry(1, 0, tanValue); // Set skewY component
          canvas.transform(matrix.storage);

        case SvgTransformType.matrix:
          if (transform.values.length >= 6) {
            // SVG matrix(a, b, c, d, e, f) maps to:
            // [a  c  e]
            // [b  d  f]
            // [0  0  1]
            final a = transform.values[0];
            final b = transform.values[1];
            final c = transform.values[2];
            final d = transform.values[3];
            final e = transform.values[4];
            final f = transform.values[5];

            final matrix = Matrix4.identity()
              ..setEntry(0, 0, a) // m11
              ..setEntry(1, 0, b) // m21
              ..setEntry(0, 1, c) // m12
              ..setEntry(1, 1, d) // m22
              ..setEntry(0, 3, e) // m14 (translateX)
              ..setEntry(1, 3, f); // m24 (translateY)
            canvas.transform(matrix.storage);
          }
          break;
      }
    }
  }
}
