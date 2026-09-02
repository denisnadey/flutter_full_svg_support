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

int _visiblePixelCount(Uint8List pixels) {
  var result = 0;
  for (var index = 3; index < pixels.length; index += 4) {
    if (pixels[index] > 10) result++;
  }
  return result;
}

void main() {
  testWidgets('clipPathUnits objectBoundingBox clips to text object bounds', (
    tester,
  ) async {
    const svg = '''
<svg width="200" height="100" viewBox="0 0 200 100"
    xmlns="http://www.w3.org/2000/svg">
  <defs>
    <clipPath id="clip" clipPathUnits="objectBoundingBox">
      <rect width="1" height="1"/>
    </clipPath>
  </defs>
  <text x="50" y="60" font-size="40" fill="#FF0000"
      clip-path="url(#clip)">HI</text>
</svg>''';

    final pixels = await _renderSvgPixels(tester, svg, width: 200, height: 100);

    // Before #34 the text target had no object bounds, so the objectBoundingBox
    // clip transform was null and the text was clipped out entirely.
    expect(_visiblePixelCount(pixels), greaterThan(10));
  });

  testWidgets('maskUnits objectBoundingBox establishes a text mask region', (
    tester,
  ) async {
    const svg = '''
<svg width="200" height="100" viewBox="0 0 200 100"
    xmlns="http://www.w3.org/2000/svg">
  <defs>
    <mask id="mask" maskUnits="objectBoundingBox"
        maskContentUnits="userSpaceOnUse">
      <rect width="200" height="100" fill="#FFFFFF"/>
    </mask>
  </defs>
  <text x="50" y="60" font-size="40" fill="#00FF00"
      mask="url(#mask)">HI</text>
</svg>''';

    final pixels = await _renderSvgPixels(tester, svg, width: 200, height: 100);

    // Before #34 the mask region had no target bounds, so the text was masked
    // out entirely.
    expect(_visiblePixelCount(pixels), greaterThan(10));
  });

  testWidgets('maskContentUnits objectBoundingBox scales mask to text bounds', (
    tester,
  ) async {
    const svg = '''
<svg width="200" height="100" viewBox="0 0 200 100"
    xmlns="http://www.w3.org/2000/svg">
  <defs>
    <mask id="mask" maskContentUnits="objectBoundingBox">
      <rect width="1" height="1" fill="#FFFFFF"/>
    </mask>
  </defs>
  <text x="50" y="60" font-size="40" fill="#0000FF"
      mask="url(#mask)">HI</text>
</svg>''';

    final pixels = await _renderSvgPixels(tester, svg, width: 200, height: 100);

    // Before #34 the mask content transform had no target bounds, so the
    // 1x1 objectBoundingBox content rect stayed in user space and masked the
    // text out.
    expect(_visiblePixelCount(pixels), greaterThan(10));
  });

  testWidgets('positioned tspan contributes to text object bounds', (
    tester,
  ) async {
    const svg = '''
<svg width="200" height="100" viewBox="0 0 200 100"
    xmlns="http://www.w3.org/2000/svg">
  <defs>
    <clipPath id="clip" clipPathUnits="objectBoundingBox">
      <rect width="1" height="1"/>
    </clipPath>
  </defs>
  <text x="10" y="60" font-size="40" fill="#FF00FF"
      clip-path="url(#clip)">
    <tspan x="50" dy="10">TS</tspan>
  </text>
</svg>''';

    final pixels = await _renderSvgPixels(tester, svg, width: 200, height: 100);

    // The text target's object bounds must include its positioned tspan
    // content, or the clip transform has no basis and blanks the text.
    expect(_visiblePixelCount(pixels), greaterThan(10));
  });

  testWidgets('text-anchor placement participates in text object bounds', (
    tester,
  ) async {
    const svg = '''
<svg width="200" height="100" viewBox="0 0 200 100"
    xmlns="http://www.w3.org/2000/svg">
  <defs>
    <clipPath id="clip" clipPathUnits="objectBoundingBox">
      <rect width="1" height="1"/>
    </clipPath>
  </defs>
  <text x="100" y="60" font-size="40" text-anchor="middle"
      fill="#00FFFF" clip-path="url(#clip)">M</text>
</svg>''';

    final pixels = await _renderSvgPixels(tester, svg, width: 200, height: 100);

    // The middle anchor centers the glyph on x=100; object bounds must honor
    // that placement rather than blanking the text.
    expect(_visiblePixelCount(pixels), greaterThan(10));
  });
}
