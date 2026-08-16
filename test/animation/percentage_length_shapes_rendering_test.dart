import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:full_svg_flutter/src/animation/animated_svg_picture.dart';

Future<Uint8List> _renderSvgPixels(
  WidgetTester tester,
  String svg, {
  required int width,
  required int height,
}) async {
  final repaintBoundaryKey = GlobalKey();
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: RepaintBoundary(
          key: repaintBoundaryKey,
          child: SizedBox(
            width: width.toDouble(),
            height: height.toDouble(),
            child: AnimatedSvgPicture.string(svg),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));

  final pixels = await tester.runAsync<Uint8List?>(() async {
    final boundary =
        repaintBoundaryKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
    if (boundary == null) return null;

    final image = await boundary.toImage(pixelRatio: 1.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    return byteData?.buffer.asUint8List();
  });

  expect(pixels, isNotNull);
  return pixels!;
}

List<int> _pixelAt(Uint8List pixels, int width, int x, int y) {
  final offset = ((y * width) + x) * 4;
  return pixels.sublist(offset, offset + 4);
}

void main() {
  testWidgets('renders percentage circle, ellipse, and line lengths', (
    tester,
  ) async {
    const svg = '''
<svg width="40" height="20" viewBox="0 0 40 20"
    xmlns="http://www.w3.org/2000/svg">
  <circle cx="25%" cy="25%" r="25%" fill="#FF0000"/>
  <ellipse cx="75%" cy="75%" rx="20%" ry="20%" fill="#00FF00"/>
  <line x1="25%" y1="75%" x2="75%" y2="75%"
      stroke="#0000FF" stroke-width="2"/>
</svg>''';

    final pixels = await _renderSvgPixels(tester, svg, width: 40, height: 20);

    final circleCenter = _pixelAt(pixels, 40, 10, 5);
    expect(circleCenter[0], greaterThan(200));
    expect(circleCenter[3], greaterThan(200));

    // A radius of 25% uses the normalized diagonal (about 7.9), not the
    // horizontal viewport width (10) or raw number 25.
    expect(_pixelAt(pixels, 40, 19, 5)[3], lessThan(32));

    final ellipseCenter = _pixelAt(pixels, 40, 30, 15);
    expect(ellipseCenter[1], greaterThan(200));
    expect(ellipseCenter[3], greaterThan(200));
    expect(_pixelAt(pixels, 40, 30, 9)[3], lessThan(32));

    final lineCenter = _pixelAt(pixels, 40, 20, 15);
    expect(lineCenter[2], greaterThan(200));
    expect(lineCenter[3], greaterThan(200));
  });

  testWidgets('uses percentage shape geometry for object bounding box clips', (
    tester,
  ) async {
    const svg = '''
<svg width="40" height="20" viewBox="0 0 40 20"
    xmlns="http://www.w3.org/2000/svg">
  <defs>
    <clipPath id="circleBounds" clipPathUnits="objectBoundingBox">
      <rect width="1" height="1"/>
    </clipPath>
    <clipPath id="ellipseBounds" clipPathUnits="objectBoundingBox">
      <rect width="1" height="1"/>
    </clipPath>
  </defs>
  <circle cx="75%" cy="25%" r="10%" fill="#FF0000"
      clip-path="url(#circleBounds)"/>
  <ellipse cx="25%" cy="75%" rx="10%" ry="10%" fill="#00FF00"
      clip-path="url(#ellipseBounds)"/>
</svg>''';

    final pixels = await _renderSvgPixels(tester, svg, width: 40, height: 20);

    expect(_pixelAt(pixels, 40, 30, 5)[0], greaterThan(200));
    expect(_pixelAt(pixels, 40, 10, 15)[1], greaterThan(200));
  });

  testWidgets('renders percentage rect corner radii against the viewport', (
    tester,
  ) async {
    const svg = '''
<svg width="200" height="100" viewBox="0 0 200 100"
    xmlns="http://www.w3.org/2000/svg">
  <rect x="25%" width="50%" height="100%" rx="25%" ry="25%"
      fill="#FF0000"/>
</svg>''';

    final pixels = await _renderSvgPixels(tester, svg, width: 200, height: 100);

    expect(_pixelAt(pixels, 200, 100, 50)[3], greaterThan(200));
    // With rx=50 and ry=25, this point is outside the top-left corner arc.
    // Treating rx="25%" as the raw number 25 would incorrectly fill it.
    expect(_pixelAt(pixels, 200, 58, 10)[3], lessThan(32));
  });

  testWidgets('uses percentage rect geometry inside clip paths', (
    tester,
  ) async {
    const svg = '''
<svg width="200" height="100" viewBox="0 0 200 100"
    xmlns="http://www.w3.org/2000/svg">
  <defs>
    <clipPath id="viewportClip">
      <rect x="25%" y="25%" width="25%" height="50%"/>
    </clipPath>
  </defs>
  <rect width="200" height="100" fill="#FF0000"
      clip-path="url(#viewportClip)"/>
</svg>''';

    final pixels = await _renderSvgPixels(tester, svg, width: 200, height: 100);

    expect(_pixelAt(pixels, 200, 75, 50)[3], greaterThan(200));
    expect(_pixelAt(pixels, 200, 35, 50)[3], lessThan(32));
  });

  testWidgets('uses percentage image geometry in clip paths', (tester) async {
    const svg = '''
<svg width="200" height="100" viewBox="0 0 200 100"
    xmlns="http://www.w3.org/2000/svg">
  <defs>
    <clipPath id="imageClip">
      <image x="25%" y="25%" width="25%" height="50%"
          href="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScLwzAAAAABJRU5ErkJggg=="/>
    </clipPath>
  </defs>
  <rect width="200" height="100" fill="#FF0000"
      clip-path="url(#imageClip)"/>
</svg>''';

    final pixels = await _renderSvgPixels(tester, svg, width: 200, height: 100);

    expect(_pixelAt(pixels, 200, 75, 50)[3], greaterThan(200));
    expect(_pixelAt(pixels, 200, 35, 50)[3], lessThan(32));
  });

  testWidgets('uses percentage foreignObject geometry in clip paths', (
    tester,
  ) async {
    const svg = '''
<svg width="200" height="100" viewBox="0 0 200 100"
    xmlns="http://www.w3.org/2000/svg">
  <defs>
    <clipPath id="foreignObjectClip">
      <foreignObject x="25%" y="25%" width="25%" height="50%">
        <div xmlns="http://www.w3.org/1999/xhtml"></div>
      </foreignObject>
    </clipPath>
  </defs>
  <rect width="200" height="100" fill="#FF0000"
      clip-path="url(#foreignObjectClip)"/>
</svg>''';

    final pixels = await _renderSvgPixels(tester, svg, width: 200, height: 100);

    expect(_pixelAt(pixels, 200, 75, 50)[3], greaterThan(200));
    expect(_pixelAt(pixels, 200, 35, 50)[3], lessThan(32));
  });
}
