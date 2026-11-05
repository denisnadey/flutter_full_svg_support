// SVG 2 `context-fill` / `context-stroke` paint values
// (https://www.w3.org/TR/SVG2/painting.html#SpecifyingPaint).
//
// Inside a marker the context element is the shape that references the
// marker; inside `<use>` content it is the `<use>` element. Without a context
// element both keywords behave as `none`.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:full_svg_flutter/src/animation/animated_svg_picture.dart';

const _size = 100.0;

Future<ByteDataPixels> _render(WidgetTester tester, String svg) async {
  final key = GlobalKey();
  await tester.pumpWidget(
    MaterialApp(
      home: Align(
        alignment: Alignment.topLeft,
        child: RepaintBoundary(
          key: key,
          child: ColoredBox(
            color: Colors.white,
            child: AnimatedSvgPicture.string(
              svg,
              width: _size,
              height: _size,
              autoPlay: false,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();

  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final bytes = await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1.0);
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final width = image.width;
    image.dispose();
    return ByteDataPixels(data!, width);
  });
  return bytes!;
}

class ByteDataPixels {
  ByteDataPixels(this.data, this.width);

  final ByteData data;
  final int width;

  Color at(int x, int y) {
    final o = (y * width + x) * 4;
    return Color.fromARGB(
      data.getUint8(o + 3),
      data.getUint8(o),
      data.getUint8(o + 1),
      data.getUint8(o + 2),
    );
  }
}

Matcher _isColor(int r, int g, int b) => predicate<Color>(
  (c) =>
      ((c.r * 255).round() - r).abs() <= 8 &&
      ((c.g * 255).round() - g).abs() <= 8 &&
      ((c.b * 255).round() - b).abs() <= 8,
  'is rgb($r, $g, $b)',
);

/// A square marker (20x20 user units) placed to the right of the line end at
/// (70, 50), so the pixel at (85, 50) belongs to the marker only.
String _markerSvg({
  required String markerChild,
  required String lineAttrs,
  String extra = '',
}) =>
    '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
  <defs>
    <marker id="m" markerUnits="userSpaceOnUse" markerWidth="20"
        markerHeight="20" refX="0" refY="10" orient="0">
      $markerChild
    </marker>
  </defs>
  <path d="M10 50 L70 50" $lineAttrs marker-end="url(#m)"/>
  $extra
</svg>''';

void main() {
  group('context-stroke / context-fill in markers', () {
    testWidgets('fill="context-stroke" takes the referencing stroke', (
      tester,
    ) async {
      final px = await _render(
        tester,
        _markerSvg(
          markerChild: '<rect width="20" height="20" fill="context-stroke"/>',
          lineAttrs: 'stroke="#ff0000" stroke-width="2" fill="none"',
        ),
      );
      expect(px.at(85, 50), _isColor(255, 0, 0));
    });

    testWidgets('fill="context-fill" takes the referencing fill', (
      tester,
    ) async {
      final px = await _render(
        tester,
        _markerSvg(
          markerChild: '<rect width="20" height="20" fill="context-fill"/>',
          lineAttrs: 'stroke="#ff0000" stroke-width="2" fill="#0000ff"',
        ),
      );
      expect(px.at(85, 50), _isColor(0, 0, 255));
    });

    testWidgets('stroke="context-stroke" strokes with the referencing stroke', (
      tester,
    ) async {
      final px = await _render(
        tester,
        _markerSvg(
          markerChild:
              '<rect x="2" y="2" width="16" height="16" fill="none" '
              'stroke="context-stroke" stroke-width="4"/>',
          lineAttrs: 'stroke="#00ff00" stroke-width="2" fill="none"',
        ),
      );
      // Left edge of the marker's stroked square (x = 72 + 2).
      expect(px.at(73, 44), _isColor(0, 255, 0));
      // Square interior stays unpainted.
      expect(px.at(80, 50), _isColor(255, 255, 255));
    });

    testWidgets('one marker follows each referencing shape', (tester) async {
      const svg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
  <defs>
    <marker id="m" markerUnits="userSpaceOnUse" markerWidth="20"
        markerHeight="20" refX="0" refY="10" orient="0">
      <rect width="20" height="20" fill="context-stroke"/>
    </marker>
  </defs>
  <path d="M10 20 L70 20" stroke="#ff0000" marker-end="url(#m)"/>
  <path d="M10 70 L70 70" stroke="#0000ff" marker-end="url(#m)"/>
</svg>''';
      final px = await _render(tester, svg);
      expect(px.at(85, 20), _isColor(255, 0, 0));
      expect(px.at(85, 70), _isColor(0, 0, 255));
    });

    testWidgets('context-stroke resolves currentColor on the context element', (
      tester,
    ) async {
      final px = await _render(
        tester,
        _markerSvg(
          markerChild: '<rect width="20" height="20" fill="context-stroke"/>',
          lineAttrs: 'color="#ff00ff" stroke="currentColor" fill="none"',
        ),
      );
      expect(px.at(85, 50), _isColor(255, 0, 255));
    });

    testWidgets('context-stroke is none when the context has no stroke', (
      tester,
    ) async {
      final px = await _render(
        tester,
        _markerSvg(
          markerChild: '<rect width="20" height="20" fill="context-stroke"/>',
          lineAttrs: 'fill="#0000ff"',
        ),
      );
      expect(px.at(85, 50), _isColor(255, 255, 255));
    });

    testWidgets('inherited context-fill on the marker element applies', (
      tester,
    ) async {
      const svg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
  <defs>
    <marker id="m" markerUnits="userSpaceOnUse" markerWidth="20"
        markerHeight="20" refX="0" refY="10" orient="0" fill="context-stroke">
      <g><rect width="20" height="20"/></g>
    </marker>
  </defs>
  <path d="M10 50 L70 50" stroke="#ff0000" marker-end="url(#m)"/>
</svg>''';
      final px = await _render(tester, svg);
      expect(px.at(85, 50), _isColor(255, 0, 0));
    });
  });

  group('context-fill / context-stroke in <use>', () {
    testWidgets('use content takes the <use> element fill', (tester) async {
      const svg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
  <defs>
    <rect id="r" width="30" height="30" fill="context-fill"/>
  </defs>
  <use href="#r" x="10" y="10" fill="#00ff00"/>
  <use href="#r" x="60" y="60" fill="#0000ff"/>
</svg>''';
      final px = await _render(tester, svg);
      expect(px.at(25, 25), _isColor(0, 255, 0));
      expect(px.at(75, 75), _isColor(0, 0, 255));
    });

    testWidgets('use content takes the <use> element stroke', (tester) async {
      const svg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
  <defs>
    <rect id="r" width="30" height="30" fill="context-stroke"/>
  </defs>
  <use href="#r" x="10" y="10" stroke="#ff0000" stroke-width="0"/>
</svg>''';
      final px = await _render(tester, svg);
      expect(px.at(25, 25), _isColor(255, 0, 0));
    });
  });

  testWidgets('text in <use> content takes the context fill', (tester) async {
    // The FlutterTest font renders every glyph as a solid em box.
    const svg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
  <defs>
    <text id="t" x="0" y="40" font-size="40" fill="context-fill">X</text>
  </defs>
  <use href="#t" x="10" y="10" fill="#0000ff"/>
</svg>''';
    final px = await _render(tester, svg);
    expect(px.at(30, 35), _isColor(0, 0, 255));
  });

  testWidgets('context-fill without a context element paints nothing', (
    tester,
  ) async {
    const svg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
  <rect width="100" height="100" fill="context-fill" stroke="context-stroke"/>
</svg>''';
    final px = await _render(tester, svg);
    expect(px.at(50, 50), _isColor(255, 255, 255));
    expect(px.at(0, 50), _isColor(255, 255, 255));
  });
}
