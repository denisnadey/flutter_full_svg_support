import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:full_svg_flutter/src/animation/animated_svg_picture.dart';
import 'package:full_svg_flutter/src/animation/smil/smil_animation.dart';
import 'package:full_svg_flutter/src/animation/smil/smil_parser.dart';
import 'package:full_svg_flutter/src/animation/svg_length_resolver.dart';
import 'package:full_svg_flutter/src/animation/svg_parser.dart';

/// Regressions for issue #46: animated percentages that reach objectBoundingBox
/// clip and mask consumers keep their percentage semantics through SMIL
/// interpolation instead of being stripped to bare numbers.
///
/// Two different coordinate systems are involved, matching browsers (Blink
/// `SVGLengthContext::resolveLength` only converts percentages to fractions
/// for the *own* attributes of elements with a unit mode):
///
/// * The `<mask>` region attributes (`x`, `y`, `width`, `height`) under
///   `maskUnits="objectBoundingBox"` are fractions of the target bounding box:
///   `50%` is `0.5`.
/// * Geometry *inside* a `clipPath` or `mask` resolves percentages against the
///   nearest SVG viewport even when `clipPathUnits`/`maskContentUnits` are
///   objectBoundingBox; the resulting user-space number is then interpreted in
///   bounding-box units. `0.25%` of a 200-wide viewport is `0.5` bbox units.
///
/// All fixtures use `viewBox="0 0 200 100"` rendered at 200×100, a full-size
/// red target rect, `dur="2s"`, and `autoPlay: false` with the time set through
/// `initialTime`.
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

int? _lastRedRow(Uint8List pixels) {
  for (var y = _height - 1; y >= 0; y--) {
    for (var x = 0; x < _width; x++) {
      if (_isRed(pixels, x, y)) return y;
    }
  }
  return null;
}

const _oneSecond = Duration(seconds: 1);
const _threeHalves = Duration(milliseconds: 1500);

/// `<mask>` whose region is animated; the content covers the whole viewport.
String _maskRegionSvg({required String region, required String animation}) {
  return '''
<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <mask id="m" maskUnits="objectBoundingBox" maskContentUnits="userSpaceOnUse"
          $region>
      <rect width="200" height="100" fill="white"/>
      $animation
    </mask>
  </defs>
  <rect id="target" width="200" height="100" fill="red" mask="url(#m)"/>
</svg>''';
}

const _unitRegion = 'x="0" y="0" width="1" height="1"';

/// `<clipPath clipPathUnits="objectBoundingBox">` with an animated unit rect.
String _clipContentSvg({required String animation}) {
  return '''
<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <clipPath id="c" clipPathUnits="objectBoundingBox">
      <rect width="1" height="1">
        $animation
      </rect>
    </clipPath>
  </defs>
  <rect id="target" width="200" height="100" fill="red" clip-path="url(#c)"/>
</svg>''';
}

/// `<mask maskContentUnits="objectBoundingBox">` with an animated unit rect.
String _maskContentSvg({required String animation}) {
  return '''
<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <mask id="m" maskContentUnits="objectBoundingBox">
      <rect width="1" height="1" fill="white">
        $animation
      </rect>
    </mask>
  </defs>
  <rect id="target" width="200" height="100" fill="red" mask="url(#m)"/>
</svg>''';
}

void main() {
  group(
    'SMIL classification for objectBoundingBox clip and mask consumers',
    () {
      test(
        'mask region coordinates under default maskUnits are bbox fractions',
        () {
          final document = SvgParser.parse('''
        <svg viewBox="0 0 200 100">
          <defs>
            <mask id="m">
              <animate attributeName="x" from="0%" to="100%" dur="2s"/>
            </mask>
          </defs>
        </svg>
      ''');
          final animation = SmilParser.parseAnimations(document).single;
          expect(
            animation.percentageSemantics,
            SmilPercentageSemantics.objectBoundingBox,
          );
          final midpoint = animation.computeValue(0.5);
          expect(midpoint, isA<SvgLengthPercentageValue>());
          final length = midpoint! as SvgLengthPercentageValue;
          expect(length.absolute, 0);
          expect(length.percentage, 50);
          expect(resolveSvgObjectBoundingBoxFraction(midpoint), 0.5);
        },
      );

      test(
        'mask region coordinates under userSpaceOnUse are viewport lengths',
        () {
          final document = SvgParser.parse('''
        <svg viewBox="0 0 200 100">
          <defs>
            <mask id="m" maskUnits="userSpaceOnUse">
              <animate attributeName="x" from="0%" to="100%" dur="2s"/>
            </mask>
          </defs>
        </svg>
      ''');
          final animation = SmilParser.parseAnimations(document).single;
          expect(
            animation.percentageSemantics,
            SmilPercentageSemantics.horizontalLength,
          );
        },
      );

      test('clipPath content keeps viewport-relative percentage semantics', () {
        final document = SvgParser.parse('''
        <svg viewBox="0 0 200 100">
          <defs>
            <clipPath id="c" clipPathUnits="objectBoundingBox">
              <rect width="1" height="1">
                <animate attributeName="x" from="0" to="0.5%" dur="2s"/>
              </rect>
            </clipPath>
          </defs>
        </svg>
      ''');
        final animation = SmilParser.parseAnimations(document).single;
        expect(
          animation.percentageSemantics,
          SmilPercentageSemantics.horizontalLength,
        );
        final midpoint = animation.computeValue(0.5);
        expect(midpoint, isA<SvgLengthPercentageValue>());
        final length = midpoint! as SvgLengthPercentageValue;
        expect(length.absolute, 0);
        expect(length.percentage, closeTo(0.25, 1e-9));
      });

      test('mask content keeps viewport-relative percentage semantics', () {
        final document = SvgParser.parse('''
        <svg viewBox="0 0 200 100">
          <defs>
            <mask id="m" maskContentUnits="objectBoundingBox">
              <rect width="1" height="1">
                <animate attributeName="y" from="0" to="100%" dur="2s"/>
              </rect>
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

      test('pattern and filter content keep numeric behavior', () {
        final document = SvgParser.parse('''
        <svg viewBox="0 0 200 100">
          <defs>
            <pattern id="p" width="10" height="10">
              <rect width="5" height="5">
                <animate attributeName="x" from="0%" to="50%" dur="2s"/>
              </rect>
            </pattern>
            <filter id="f">
              <feOffset dx="1" dy="1">
                <animate attributeName="x" from="0%" to="50%" dur="2s"/>
              </feOffset>
            </filter>
          </defs>
        </svg>
      ''');
        for (final animation in SmilParser.parseAnimations(document)) {
          expect(animation.percentageSemantics, SmilPercentageSemantics.none);
        }
      });

      test('set keeps the raw percentage for objectBoundingBox consumers', () {
        final document = SvgParser.parse('''
        <svg viewBox="0 0 200 100">
          <defs>
            <mask id="m">
              <set attributeName="x" to="50%" begin="0s" dur="2s"/>
            </mask>
          </defs>
        </svg>
      ''');
        final animation = SmilParser.parseAnimations(document).single;
        expect(
          animation.percentageSemantics,
          SmilPercentageSemantics.objectBoundingBox,
        );
        final value = animation.computeValue(0.5);
        expect(value, '50%');
        expect(resolveSvgObjectBoundingBoxFraction(value), 0.5);
      });

      test(
        'resolveSvgObjectBoundingBoxFraction accepts every consumer input',
        () {
          expect(resolveSvgObjectBoundingBoxFraction(0.25), 0.25);
          expect(resolveSvgObjectBoundingBoxFraction('0.25'), 0.25);
          expect(resolveSvgObjectBoundingBoxFraction('25%'), 0.25);
          expect(
            resolveSvgObjectBoundingBoxFraction(
              const SvgLengthPercentageValue(absolute: 0.1, percentage: 20),
            ),
            closeTo(0.3, 1e-9),
          );
          expect(resolveSvgObjectBoundingBoxFraction(null), isNull);
          expect(resolveSvgObjectBoundingBoxFraction('auto'), isNull);
        },
      );
    },
  );

  group('maskUnits objectBoundingBox region', () {
    testWidgets('animated x resolves as a bbox fraction', (tester) async {
      final mounted = await _mount(
        tester,
        _maskRegionSvg(
          region: _unitRegion,
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
        _maskRegionSvg(
          region: _unitRegion,
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
        _maskRegionSvg(
          region: _unitRegion,
          animation:
              '<animate attributeName="width" from="100%" to="0%" dur="2s"/>',
        ),
        initialTime: _oneSecond,
      );
      expect(_lastRedColumn(mounted.pixels), closeTo(99, 1.5));
    });

    testWidgets('animated height resolves as a bbox fraction', (tester) async {
      final mounted = await _mount(
        tester,
        _maskRegionSvg(
          region: _unitRegion,
          animation:
              '<animate attributeName="height" from="100%" to="0%" dur="2s"/>',
        ),
        initialTime: _oneSecond,
      );
      expect(_lastRedRow(mounted.pixels), closeTo(49, 1.5));
    });

    testWidgets('discrete percentage values resolve as bbox fractions', (
      tester,
    ) async {
      final mounted = await _mount(
        tester,
        _maskRegionSvg(
          region: _unitRegion,
          animation:
              '<animate attributeName="x" values="0%;50%" calcMode="discrete" dur="2s"/>',
        ),
        initialTime: _threeHalves,
      );
      expect(_firstRedColumn(mounted.pixels), closeTo(100, 1.5));
    });

    testWidgets('set percentage value resolves as a bbox fraction', (
      tester,
    ) async {
      final mounted = await _mount(
        tester,
        _maskRegionSvg(
          region: _unitRegion,
          animation: '<set attributeName="x" to="50%" begin="0s" dur="2s"/>',
        ),
        initialTime: _oneSecond,
      );
      expect(_firstRedColumn(mounted.pixels), closeTo(100, 1.5));
    });

    testWidgets('paced mixed percentage values pace by bbox distance', (
      tester,
    ) async {
      // Distances 0→50% = 0.5 and 50%→0.2 = 0.3 give keyTimes 0 / 0.625 / 1.
      // At t = 0.5 the first segment is 80% complete: x = 40% = 0.4.
      final mounted = await _mount(
        tester,
        _maskRegionSvg(
          region: _unitRegion,
          animation:
              '<animate attributeName="x" values="0;50%;0.2" calcMode="paced" dur="2s"/>',
        ),
        initialTime: _oneSecond,
      );
      expect(_firstRedColumn(mounted.pixels), closeTo(80, 1.5));
    });

    testWidgets('hit testing uses the animated region', (tester) async {
      final mounted = await _mount(
        tester,
        _maskRegionSvg(
          region: _unitRegion,
          animation:
              '<animate attributeName="x" from="0%" to="100%" dur="2s"/>',
        ),
        initialTime: _oneSecond,
      );
      expect(await mounted.tap(const Offset(150, 50)), 'target');
      expect(await mounted.tap(const Offset(50, 50)), isNull);
    });
  });

  group('clipPathUnits objectBoundingBox content', () {
    testWidgets(
      'animated x keeps its viewport percentage through interpolation',
      (tester) async {
        // 0.25% of the 200-wide viewport is 0.5 user units, read as 0.5 bbox
        // units. A stripped numeric midpoint (0.25) would clip from x=50.
        final mounted = await _mount(
          tester,
          _clipContentSvg(
            animation:
                '<animate attributeName="x" from="0" to="0.5%" dur="2s"/>',
          ),
          initialTime: _oneSecond,
        );
        expect(_firstRedColumn(mounted.pixels), closeTo(100, 1.5));
      },
    );

    testWidgets(
      'animated y keeps its viewport percentage through interpolation',
      (tester) async {
        // 0.5% of the 100-high viewport is 0.5 user units, read as 0.5 bbox
        // units. (The viewport height equals 100, so a stripped number would
        // coincide here; the x/width cases above discriminate, this one guards
        // the vertical resolver.)
        final mounted = await _mount(
          tester,
          _clipContentSvg(
            animation: '<animate attributeName="y" from="0" to="1%" dur="2s"/>',
          ),
          initialTime: _oneSecond,
        );
        expect(_firstRedRow(mounted.pixels), closeTo(50, 1.5));
      },
    );

    testWidgets(
      'animated width keeps its viewport percentage through interpolation',
      (tester) async {
        final mounted = await _mount(
          tester,
          _clipContentSvg(
            animation:
                '<animate attributeName="width" from="0.5%" to="0" dur="2s"/>',
          ),
          initialTime: _oneSecond,
        );
        expect(_lastRedColumn(mounted.pixels), closeTo(99, 1.5));
      },
    );

    testWidgets(
      'animated height keeps its viewport percentage through interpolation',
      (tester) async {
        final mounted = await _mount(
          tester,
          _clipContentSvg(
            animation:
                '<animate attributeName="height" from="1%" to="0" dur="2s"/>',
          ),
          initialTime: _oneSecond,
        );
        expect(_lastRedRow(mounted.pixels), closeTo(49, 1.5));
      },
    );

    testWidgets('discrete percentage values resolve against the viewport', (
      tester,
    ) async {
      final mounted = await _mount(
        tester,
        _clipContentSvg(
          animation:
              '<animate attributeName="x" values="0%;0.25%" calcMode="discrete" dur="2s"/>',
        ),
        initialTime: _threeHalves,
      );
      expect(_firstRedColumn(mounted.pixels), closeTo(100, 1.5));
    });

    testWidgets('set percentage value resolves against the viewport', (
      tester,
    ) async {
      final mounted = await _mount(
        tester,
        _clipContentSvg(
          animation: '<set attributeName="x" to="0.25%" begin="0s" dur="2s"/>',
        ),
        initialTime: _oneSecond,
      );
      expect(_firstRedColumn(mounted.pixels), closeTo(100, 1.5));
    });

    testWidgets('use-referenced content resolves the same way', (tester) async {
      const svg = '''
<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <rect id="src" width="1" height="1">
      <animate attributeName="x" from="0" to="0.5%" dur="2s"/>
    </rect>
    <clipPath id="c" clipPathUnits="objectBoundingBox">
      <use href="#src"/>
    </clipPath>
  </defs>
  <rect id="target" width="200" height="100" fill="red" clip-path="url(#c)"/>
</svg>''';
      final mounted = await _mount(tester, svg, initialTime: _oneSecond);
      expect(_firstRedColumn(mounted.pixels), closeTo(100, 1.5));
    });

    testWidgets('hit testing uses the animated clip geometry', (tester) async {
      final mounted = await _mount(
        tester,
        _clipContentSvg(
          animation: '<animate attributeName="x" from="0" to="0.5%" dur="2s"/>',
        ),
        initialTime: _oneSecond,
      );
      expect(await mounted.tap(const Offset(150, 50)), 'target');
      expect(await mounted.tap(const Offset(50, 50)), isNull);
    });
  });

  group('maskContentUnits objectBoundingBox content', () {
    testWidgets(
      'animated x keeps its viewport percentage through interpolation',
      (tester) async {
        final mounted = await _mount(
          tester,
          _maskContentSvg(
            animation:
                '<animate attributeName="x" from="0" to="0.5%" dur="2s"/>',
          ),
          initialTime: _oneSecond,
        );
        expect(_firstRedColumn(mounted.pixels), closeTo(100, 1.5));
      },
    );

    testWidgets(
      'animated height keeps its viewport percentage through interpolation',
      (tester) async {
        final mounted = await _mount(
          tester,
          _maskContentSvg(
            animation:
                '<animate attributeName="height" from="1%" to="0" dur="2s"/>',
          ),
          initialTime: _oneSecond,
        );
        expect(_lastRedRow(mounted.pixels), closeTo(49, 1.5));
      },
    );

    testWidgets('set percentage value resolves against the viewport', (
      tester,
    ) async {
      final mounted = await _mount(
        tester,
        _maskContentSvg(
          animation: '<set attributeName="x" to="0.25%" begin="0s" dur="2s"/>',
        ),
        initialTime: _oneSecond,
      );
      expect(_firstRedColumn(mounted.pixels), closeTo(100, 1.5));
    });

    testWidgets('hit testing uses the animated mask content', (tester) async {
      final mounted = await _mount(
        tester,
        _maskContentSvg(
          animation: '<animate attributeName="x" from="0" to="0.5%" dur="2s"/>',
        ),
        initialTime: _oneSecond,
      );
      expect(await mounted.tap(const Offset(150, 50)), 'target');
      expect(await mounted.tap(const Offset(50, 50)), isNull);
    });
  });
}
