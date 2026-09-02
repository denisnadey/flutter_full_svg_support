import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:full_svg_flutter/src/animation/animated_svg_picture.dart';
import 'package:full_svg_flutter/src/animation/smil/smil_animation.dart';
import 'package:full_svg_flutter/src/animation/smil/smil_parser.dart';
import 'package:full_svg_flutter/src/animation/svg_parser.dart';

/// Animated percentages on the *own* region attributes of `<filter>` and of a
/// `<mask maskUnits="userSpaceOnUse">`.
///
/// * `<filter x y width height>` under `filterUnits="objectBoundingBox"` (the
///   default) are bounding-box fractions, like the objectBoundingBox mask
///   region; under `filterUnits="userSpaceOnUse"` they are viewport-relative
///   lengths. Previously the filter region was parsed once from the XML and
///   ignored animation entirely.
/// * `<mask x y width height>` under `maskUnits="userSpaceOnUse"` are
///   viewport-relative lengths; previously an animated `50%` was stripped to
///   the number 50.
///
/// Fixtures use `viewBox="0 0 200 100"` rendered at 200×100, `dur="2s"`, and
/// `autoPlay: false` with the time set through `initialTime`.
class _Mounted {
  const _Mounted({required this.pixels, required this.tap});

  final Uint8List pixels;
  final Future<String?> Function(Offset) tap;
}

Future<_Mounted> _mount(
  WidgetTester tester,
  String svg, {
  required Duration initialTime,
}) async {
  final repaintBoundaryKey = GlobalKey();
  final traceEvents = <SvgTraceEvent>[];
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: RepaintBoundary(
            key: repaintBoundaryKey,
            child: SizedBox(
              width: 200,
              height: 100,
              child: AnimatedSvgPicture.string(
                svg,
                autoPlay: false,
                initialTime: initialTime,
                onTrace: traceEvents.add,
                onLinkTap: (_) {},
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();

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

  Future<String?> tap(Offset documentOffset) async {
    final pictureTopLeft = tester.getTopLeft(find.byType(AnimatedSvgPicture));
    traceEvents.clear();
    await tester.tapAt(pictureTopLeft + documentOffset);
    await tester.pump();
    final tapTrace = traceEvents.lastWhere(
      (event) => event.category == 'event' && event.message == 'Tap detected',
    );
    return tapTrace.data['targetId'] as String?;
  }

  return _Mounted(pixels: pixels!, tap: tap);
}

const _width = 200;
const _height = 100;

bool _isRed(Uint8List pixels, int x, int y) {
  final offset = ((y * _width) + x) * 4;
  return pixels[offset] > 200 &&
      pixels[offset + 1] < 100 &&
      pixels[offset + 2] < 100 &&
      pixels[offset + 3] > 200;
}

int? _firstRedColumn(Uint8List pixels) {
  for (var x = 0; x < _width; x++) {
    for (var y = 0; y < _height; y++) {
      if (_isRed(pixels, x, y)) return x;
    }
  }
  return null;
}

int? _lastRedColumn(Uint8List pixels) {
  for (var x = _width - 1; x >= 0; x--) {
    for (var y = 0; y < _height; y++) {
      if (_isRed(pixels, x, y)) return x;
    }
  }
  return null;
}

int? _firstRedRow(Uint8List pixels) {
  for (var y = 0; y < _height; y++) {
    for (var x = 0; x < _width; x++) {
      if (_isRed(pixels, x, y)) return y;
    }
  }
  return null;
}

const _oneSecond = Duration(seconds: 1);
const _threeHalves = Duration(milliseconds: 1500);

/// A flood filter paints red over its whole filter region, so the visible red
/// area is exactly the region applied to the blue target.
String _filterSvg({required String filterAttrs, required String animation}) {
  return '''
<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <filter id="f" $filterAttrs>
      <feFlood flood-color="red"/>
      $animation
    </filter>
  </defs>
  <rect id="target" width="200" height="100" fill="blue" filter="url(#f)"/>
</svg>''';
}

String _maskSvg({required String maskAttrs, required String animation}) {
  return '''
<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <mask id="m" maskUnits="userSpaceOnUse" maskContentUnits="userSpaceOnUse"
          $maskAttrs>
      <rect width="200" height="100" fill="white"/>
      $animation
    </mask>
  </defs>
  <rect id="target" width="200" height="100" fill="red" mask="url(#m)"/>
</svg>''';
}

void main() {
  group('SMIL classification for filter and userSpaceOnUse mask regions', () {
    test('filter region under default filterUnits is objectBoundingBox', () {
      final document = SvgParser.parse('''
        <svg viewBox="0 0 200 100">
          <defs>
            <filter id="f">
              <animate attributeName="x" from="0%" to="100%" dur="2s"/>
            </filter>
          </defs>
        </svg>
      ''');
      final animation = SmilParser.parseAnimations(document).single;
      expect(
        animation.percentageSemantics,
        SmilPercentageSemantics.objectBoundingBox,
      );
    });

    test('filter region under userSpaceOnUse is a viewport length', () {
      final document = SvgParser.parse('''
        <svg viewBox="0 0 200 100">
          <defs>
            <filter id="f" filterUnits="userSpaceOnUse">
              <animate attributeName="width" from="0%" to="100%" dur="2s"/>
            </filter>
          </defs>
        </svg>
      ''');
      final animation = SmilParser.parseAnimations(document).single;
      expect(
        animation.percentageSemantics,
        SmilPercentageSemantics.horizontalLength,
      );
    });

    test('mask region under userSpaceOnUse is a viewport length', () {
      final document = SvgParser.parse('''
        <svg viewBox="0 0 200 100">
          <defs>
            <mask id="m" maskUnits="userSpaceOnUse">
              <animate attributeName="y" from="0%" to="100%" dur="2s"/>
            </mask>
          </defs>
        </svg>
      ''');
      final animation = SmilParser.parseAnimations(document).single;
      expect(
        animation.percentageSemantics,
        SmilPercentageSemantics.verticalLength,
      );
    });

    test('filter primitive subregions keep numeric behavior', () {
      final document = SvgParser.parse('''
        <svg viewBox="0 0 200 100">
          <defs>
            <filter id="f">
              <feFlood flood-color="red">
                <animate attributeName="x" from="0%" to="50%" dur="2s"/>
              </feFlood>
            </filter>
          </defs>
        </svg>
      ''');
      final animation = SmilParser.parseAnimations(document).single;
      expect(animation.percentageSemantics, SmilPercentageSemantics.none);
    });
  });

  group('filter region, filterUnits objectBoundingBox', () {
    testWidgets('animated x resolves as a bbox fraction', (tester) async {
      final mounted = await _mount(
        tester,
        _filterSvg(
          filterAttrs: 'x="0" y="0" width="1" height="1"',
          animation:
              '<animate attributeName="x" from="0%" to="100%" dur="2s"/>',
        ),
        initialTime: _oneSecond,
      );
      expect(_firstRedColumn(mounted.pixels), closeTo(100, 1.5));
    });

    testWidgets('animated y resolves as a bbox fraction', (tester) async {
      final mounted = await _mount(
        tester,
        _filterSvg(
          filterAttrs: 'x="0" y="0" width="1" height="1"',
          animation:
              '<animate attributeName="y" from="0%" to="100%" dur="2s"/>',
        ),
        initialTime: _oneSecond,
      );
      expect(_firstRedRow(mounted.pixels), closeTo(50, 1.5));
    });

    testWidgets('animated width resolves as a bbox fraction', (tester) async {
      final mounted = await _mount(
        tester,
        _filterSvg(
          filterAttrs: 'x="0" y="0" width="1" height="1"',
          animation:
              '<animate attributeName="width" from="100%" to="0%" dur="2s"/>',
        ),
        initialTime: _oneSecond,
      );
      expect(_lastRedColumn(mounted.pixels), closeTo(99, 1.5));
    });

    testWidgets('set percentage value resolves as a bbox fraction', (
      tester,
    ) async {
      final mounted = await _mount(
        tester,
        _filterSvg(
          filterAttrs: 'x="0" y="0" width="1" height="1"',
          animation: '<set attributeName="x" to="50%" begin="0s" dur="2s"/>',
        ),
        initialTime: _oneSecond,
      );
      expect(_firstRedColumn(mounted.pixels), closeTo(100, 1.5));
    });

    testWidgets('discrete percentage values resolve as bbox fractions', (
      tester,
    ) async {
      final mounted = await _mount(
        tester,
        _filterSvg(
          filterAttrs: 'x="0" y="0" width="1" height="1"',
          animation:
              '<animate attributeName="x" values="0%;50%" calcMode="discrete" dur="2s"/>',
        ),
        initialTime: _threeHalves,
      );
      expect(_firstRedColumn(mounted.pixels), closeTo(100, 1.5));
    });
  });

  group('filter region, filterUnits userSpaceOnUse', () {
    testWidgets('animated x resolves against the viewport', (tester) async {
      // 50% of the 200-wide viewport is 100 user units.
      final mounted = await _mount(
        tester,
        _filterSvg(
          filterAttrs:
              'filterUnits="userSpaceOnUse" x="0" y="0" width="200" height="100"',
          animation:
              '<animate attributeName="x" from="0%" to="100%" dur="2s"/>',
        ),
        initialTime: _oneSecond,
      );
      expect(_firstRedColumn(mounted.pixels), closeTo(100, 1.5));
    });

    testWidgets('animated width resolves against the viewport', (tester) async {
      final mounted = await _mount(
        tester,
        _filterSvg(
          filterAttrs:
              'filterUnits="userSpaceOnUse" x="0" y="0" width="200" height="100"',
          animation:
              '<animate attributeName="width" from="100%" to="0%" dur="2s"/>',
        ),
        initialTime: _oneSecond,
      );
      expect(_lastRedColumn(mounted.pixels), closeTo(99, 1.5));
    });

    testWidgets('set percentage value resolves against the viewport', (
      tester,
    ) async {
      final mounted = await _mount(
        tester,
        _filterSvg(
          filterAttrs:
              'filterUnits="userSpaceOnUse" x="0" y="0" width="200" height="100"',
          animation: '<set attributeName="x" to="50%" begin="0s" dur="2s"/>',
        ),
        initialTime: _oneSecond,
      );
      expect(_firstRedColumn(mounted.pixels), closeTo(100, 1.5));
    });
  });

  group('mask region, maskUnits userSpaceOnUse', () {
    testWidgets('animated x resolves against the viewport', (tester) async {
      // A stripped numeric midpoint would be 50 user units (column 50).
      final mounted = await _mount(
        tester,
        _maskSvg(
          maskAttrs: 'x="0" y="0" width="200" height="100"',
          animation:
              '<animate attributeName="x" from="0%" to="100%" dur="2s"/>',
        ),
        initialTime: _oneSecond,
      );
      expect(_firstRedColumn(mounted.pixels), closeTo(100, 1.5));
    });

    testWidgets('animated width resolves against the viewport', (tester) async {
      final mounted = await _mount(
        tester,
        _maskSvg(
          maskAttrs: 'x="0" y="0" width="200" height="100"',
          animation:
              '<animate attributeName="width" from="100%" to="0%" dur="2s"/>',
        ),
        initialTime: _oneSecond,
      );
      expect(_lastRedColumn(mounted.pixels), closeTo(99, 1.5));
    });

    testWidgets('animated y resolves against the viewport', (tester) async {
      final mounted = await _mount(
        tester,
        _maskSvg(
          maskAttrs: 'x="0" y="0" width="200" height="100"',
          animation:
              '<animate attributeName="y" from="0%" to="100%" dur="2s"/>',
        ),
        initialTime: _oneSecond,
      );
      expect(_firstRedRow(mounted.pixels), closeTo(50, 1.5));
    });

    testWidgets('set percentage value resolves against the viewport', (
      tester,
    ) async {
      final mounted = await _mount(
        tester,
        _maskSvg(
          maskAttrs: 'x="0" y="0" width="200" height="100"',
          animation: '<set attributeName="x" to="50%" begin="0s" dur="2s"/>',
        ),
        initialTime: _oneSecond,
      );
      expect(_firstRedColumn(mounted.pixels), closeTo(100, 1.5));
    });

    testWidgets('numeric animation keeps its prior behavior', (tester) async {
      final mounted = await _mount(
        tester,
        _maskSvg(
          maskAttrs: 'x="0" y="0" width="200" height="100"',
          animation: '<animate attributeName="x" from="0" to="100" dur="2s"/>',
        ),
        initialTime: _oneSecond,
      );
      expect(_firstRedColumn(mounted.pixels), closeTo(50, 1.5));
    });

    testWidgets('hit testing uses the animated region', (tester) async {
      final mounted = await _mount(
        tester,
        _maskSvg(
          maskAttrs: 'x="0" y="0" width="200" height="100"',
          animation:
              '<animate attributeName="x" from="0%" to="100%" dur="2s"/>',
        ),
        initialTime: _oneSecond,
      );
      expect(await mounted.tap(const Offset(150, 50)), 'target');
      expect(await mounted.tap(const Offset(50, 50)), isNull);
    });
  });
}
