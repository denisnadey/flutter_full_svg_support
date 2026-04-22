import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:full_svg_flutter/src/animation/animated_svg_picture.dart';
import 'package:flutter_test/flutter_test.dart';

({int r, int g, int b, int a}) _sampleRgba(
  Uint8List rgba,
  int width,
  int x,
  int y,
) {
  final offset = (y * width + x) * 4;
  return (
    r: rgba[offset],
    g: rgba[offset + 1],
    b: rgba[offset + 2],
    a: rgba[offset + 3],
  );
}

void main() {
  testWidgets('nested svg viewBox syntax variants render in separate viewports', (
    tester,
  ) async {
    const shape =
        'M20,20 Q180,20 180,180 Q20,180 20,20 Z '
        'M20,180 Q20,20 180,20 Q180,180 20,180 Z '
        'M100,40 L160,100 100,160 40,100 Z';

    const svg =
        '''
      <svg viewBox="0 0 480 360" xmlns="http://www.w3.org/2000/svg">
        <g fill="lightblue" stroke="black">
          <svg x="35" y="50" width="100" height="100" viewBox="0 0 200 200" overflow="visible">
            <path fill-rule="evenodd" d="$shape"/>
          </svg>
          <svg x="190" y="50" width="100" height="100" viewBox="0,0,200,200" overflow="visible">
            <path fill-rule="evenodd" d="$shape"/>
          </svg>
          <svg x="345" y="50" width="100" height="100" viewBox="0,0,   200, 200" overflow="visible">
            <path fill-rule="evenodd" d="$shape"/>
          </svg>
        </g>
      </svg>
    ''';

    final key = GlobalKey();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: RepaintBoundary(
            key: key,
            child: AnimatedSvgPicture.string(
              svg,
              width: 480,
              height: 360,
              fit: BoxFit.fill,
              autoPlay: false,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final raw = await tester.runAsync<Uint8List?>(() async {
      final boundary =
          key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        return null;
      }
      final image = await boundary.toImage(pixelRatio: 1.0);
      final byteData = await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      image.dispose();
      return byteData?.buffer.asUint8List();
    });

    expect(raw, isNotNull);
    final rgba = raw!;

    // Centers of the three nested SVG viewports must all contain light-blue fill.
    const centers = <({int x, int y})>[
      (x: 85, y: 100),
      (x: 240, y: 100),
      (x: 395, y: 100),
    ];
    for (final center in centers) {
      final pixel = _sampleRgba(rgba, 480, center.x, center.y);
      expect(pixel.a, greaterThan(200));
      expect(pixel.g, greaterThan(130));
      expect(pixel.b, greaterThan(150));
      expect(pixel.r, greaterThan(120));
    }
  });
}
