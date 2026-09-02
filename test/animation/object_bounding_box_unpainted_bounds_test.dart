import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:full_svg_flutter/src/animation/animated_svg_picture.dart';

/// Regressions for issue #42: `clipPathUnits`, `maskUnits`, and
/// `maskContentUnits` objectBoundingBox coordinate systems derive their
/// transform from the target's unpainted object bounds. Stroke and other paint
/// effects must not expand the bounding box, group targets must map their
/// children through the children's own transforms, `<use>` targets include
/// their x/y translation, and hit testing uses the same geometry as painting.
///
/// All fixtures use `viewBox="0 0 200 100"` rendered at 200×100 so document
/// coordinates equal pixel coordinates.
///
/// Reference target: `rect x=50 y=20 width=100 height=40` with a 20px stroke.
/// Unpainted bounds are 50..150 × 20..60; the stroke-inflated bounds would be
/// 40..160 × 10..70. A `.25/.25/.5/.5` objectBoundingBox region therefore
/// resolves to 75..125 × 30..50 (unpainted) instead of 70..130 × 25..55.
class _Mounted {
  const _Mounted({required this.pixels, required this.tap});

  final Uint8List pixels;
  final Future<({String? targetId, String? retargetedId})> Function(Offset) tap;
}

Future<_Mounted> _mount(
  WidgetTester tester,
  String svg, {
  int width = 200,
  int height = 100,
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
              width: width.toDouble(),
              height: height.toDouble(),
              child: AnimatedSvgPicture.string(
                svg,
                autoPlay: false,
                onTrace: traceEvents.add,
                // A link callback installs the gesture layer even for static
                // fixtures.
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

  Future<({String? targetId, String? retargetedId})> tap(
    Offset documentOffset,
  ) async {
    final pictureTopLeft = tester.getTopLeft(find.byType(AnimatedSvgPicture));
    traceEvents.clear();
    await tester.tapAt(pictureTopLeft + documentOffset);
    await tester.pump();
    final tapTrace = traceEvents.lastWhere(
      (event) => event.category == 'event' && event.message == 'Tap detected',
    );
    return (
      targetId: tapTrace.data['targetId'] as String?,
      retargetedId: tapTrace.data['retargetedId'] as String?,
    );
  }

  return _Mounted(pixels: pixels!, tap: tap);
}

bool _isRed(Uint8List pixels, int width, int x, int y) {
  final offset = ((y * width) + x) * 4;
  return pixels[offset] > 200 &&
      pixels[offset + 1] < 100 &&
      pixels[offset + 2] < 100 &&
      pixels[offset + 3] > 200;
}

/// Inclusive bounds of clearly red pixels, or null when nothing is red.
({int left, int top, int right, int bottom})? _redBounds(
  Uint8List pixels,
  int width,
  int height,
) {
  int? left, top, right, bottom;
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      if (!_isRed(pixels, width, x, y)) continue;
      left = left == null ? x : (x < left ? x : left);
      right = right == null ? x : (x > right ? x : right);
      top ??= y;
      bottom = y;
    }
  }
  if (left == null || top == null || right == null || bottom == null) {
    return null;
  }
  return (left: left, top: top, right: right, bottom: bottom);
}

bool _columnHasRed(Uint8List pixels, int width, int height, int x) {
  for (var y = 0; y < height; y++) {
    if (_isRed(pixels, width, x, y)) return true;
  }
  return false;
}

int? _firstRedColumn(Uint8List pixels, int width, int height) {
  for (var x = 0; x < width; x++) {
    if (_columnHasRed(pixels, width, height, x)) return x;
  }
  return null;
}

void _expectUnpaintedQuarterRegion(Uint8List pixels) {
  final bounds = _redBounds(pixels, 200, 100);
  expect(bounds, isNotNull, reason: 'clipped/masked target must be visible');
  expect(bounds!.left, closeTo(75, 1.5));
  expect(bounds.right, closeTo(124, 1.5));
  expect(bounds.top, closeTo(30, 1.5));
  expect(bounds.bottom, closeTo(49, 1.5));
  // Column 72 is red under stroke-inflated bounds (region 70..130) and must
  // stay clear with unpainted bounds.
  expect(_columnHasRed(pixels, 200, 100, 72), isFalse);
}

const _quarterClip = '''
    <clipPath id="c" clipPathUnits="objectBoundingBox">
      <rect x=".25" y=".25" width=".5" height=".5"/>
    </clipPath>''';

const _quarterMaskRegion = '''
    <mask id="m" maskUnits="objectBoundingBox" maskContentUnits="userSpaceOnUse"
          x=".25" y=".25" width=".5" height=".5">
      <rect width="200" height="100" fill="white"/>
    </mask>''';

const _quarterMaskContent = '''
    <mask id="m" maskContentUnits="objectBoundingBox">
      <rect x=".25" y=".25" width=".5" height=".5" fill="white"/>
    </mask>''';

const _strokedTarget =
    'x="50" y="20" width="100" height="40" fill="red" stroke="blue" stroke-width="20"';

String _svg({required String defs, required String body}) {
  return '''
<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg"
     xmlns:xlink="http://www.w3.org/1999/xlink">
  <defs>
$defs
  </defs>
$body
</svg>''';
}

void main() {
  group('objectBoundingBox uses unpainted target bounds', () {
    testWidgets('clipPathUnits excludes the target stroke', (tester) async {
      final mounted = await _mount(
        tester,
        _svg(
          defs: _quarterClip,
          body: '<rect id="target" $_strokedTarget clip-path="url(#c)"/>',
        ),
      );
      _expectUnpaintedQuarterRegion(mounted.pixels);
    });

    testWidgets('maskUnits region excludes the target stroke', (tester) async {
      final mounted = await _mount(
        tester,
        _svg(
          defs: _quarterMaskRegion,
          body: '<rect id="target" $_strokedTarget mask="url(#m)"/>',
        ),
      );
      _expectUnpaintedQuarterRegion(mounted.pixels);
    });

    testWidgets('maskContentUnits content excludes the target stroke', (
      tester,
    ) async {
      final mounted = await _mount(
        tester,
        _svg(
          defs: _quarterMaskContent,
          body: '<rect id="target" $_strokedTarget mask="url(#m)"/>',
        ),
      );
      _expectUnpaintedQuarterRegion(mounted.pixels);
    });

    testWidgets('group target unites children through their transforms', (
      tester,
    ) async {
      // The child geometry is 0..100 × 0..40 in its own space; the group's
      // object bounds must map it through translate(50 20).
      final mounted = await _mount(
        tester,
        _svg(
          defs: _quarterClip,
          body: '''
  <g id="target" clip-path="url(#c)">
    <rect id="child" transform="translate(50 20)" width="100" height="40"
          fill="red" stroke="blue" stroke-width="20"/>
  </g>''',
        ),
      );
      _expectUnpaintedQuarterRegion(mounted.pixels);
    });

    testWidgets('use target keeps its x/y translation in the bounds', (
      tester,
    ) async {
      // Clip and mask effects apply before the use x/y translation, so the
      // object bounds are the referenced geometry shifted by x/y.
      final mounted = await _mount(
        tester,
        _svg(
          defs:
              '$_quarterClip\n    <rect id="src" width="100" height="40" fill="red" stroke="blue" stroke-width="20"/>',
          body:
              '<use id="target" href="#src" x="50" y="20" clip-path="url(#c)"/>',
        ),
      );
      _expectUnpaintedQuarterRegion(mounted.pixels);
    });

    testWidgets('text target stroke does not shift the clip region', (
      tester,
    ) async {
      // A `.25`-offset clip start moves by a quarter of any stroke inflation,
      // so an inflated 16px stroke would shift the first visible column by 4px.
      // The stroke is red as well, so paint order cannot hide fill pixels.
      String fixture(String stroke) => _svg(
        defs: '''
    <clipPath id="c" clipPathUnits="objectBoundingBox">
      <rect x=".25" width=".75" height="1"/>
    </clipPath>''',
        body:
            '<text id="target" x="20" y="60" font-size="40" fill="red" $stroke clip-path="url(#c)">MM</text>',
      );
      final plain = await _mount(tester, fixture(''));
      final plainFirst = _firstRedColumn(plain.pixels, 200, 100);
      final stroked = await _mount(
        tester,
        fixture('stroke="red" stroke-width="16"'),
      );
      final strokedFirst = _firstRedColumn(stroked.pixels, 200, 100);
      expect(plainFirst, isNotNull);
      expect(strokedFirst, isNotNull);
      expect((strokedFirst! - plainFirst!).abs(), lessThanOrEqualTo(1));
    });
  });

  group('hit testing shares the unpainted bounds', () {
    Future<void> expectQuarterRegionHits(
      _Mounted mounted, {
      required String insideTarget,
      String? insideRetargeted,
    }) async {
      final inside = await mounted.tap(const Offset(100, 40));
      expect(inside.targetId, insideTarget);
      expect(inside.retargetedId, insideRetargeted ?? insideTarget);
      // Inside the painted fill and the stroke-inflated region, but outside
      // the unpainted objectBoundingBox region.
      final leftOfRegion = await mounted.tap(const Offset(72, 40));
      expect(leftOfRegion.targetId, isNull);
      final rightOfRegion = await mounted.tap(const Offset(128, 40));
      expect(rightOfRegion.targetId, isNull);
    }

    testWidgets('clipPathUnits objectBoundingBox on a stroked rect', (
      tester,
    ) async {
      final mounted = await _mount(
        tester,
        _svg(
          defs: _quarterClip,
          body: '<rect id="target" $_strokedTarget clip-path="url(#c)"/>',
        ),
      );
      await expectQuarterRegionHits(mounted, insideTarget: 'target');
    });

    testWidgets('maskUnits objectBoundingBox region on a stroked rect', (
      tester,
    ) async {
      final mounted = await _mount(
        tester,
        _svg(
          defs: _quarterMaskRegion,
          body: '<rect id="target" $_strokedTarget mask="url(#m)"/>',
        ),
      );
      await expectQuarterRegionHits(mounted, insideTarget: 'target');
    });

    testWidgets('maskContentUnits objectBoundingBox on a stroked rect', (
      tester,
    ) async {
      final mounted = await _mount(
        tester,
        _svg(
          defs: _quarterMaskContent,
          body: '<rect id="target" $_strokedTarget mask="url(#m)"/>',
        ),
      );
      await expectQuarterRegionHits(mounted, insideTarget: 'target');
    });

    testWidgets('group target with a transformed child', (tester) async {
      final mounted = await _mount(
        tester,
        _svg(
          defs: _quarterClip,
          body: '''
  <g id="target" clip-path="url(#c)">
    <rect id="child" transform="translate(50 20)" width="100" height="40"
          fill="red" stroke="blue" stroke-width="20"/>
  </g>''',
        ),
      );
      await expectQuarterRegionHits(mounted, insideTarget: 'child');
    });

    testWidgets('use target with x/y translation', (tester) async {
      final mounted = await _mount(
        tester,
        _svg(
          defs:
              '$_quarterClip\n    <rect id="src" width="100" height="40" fill="red" stroke="blue" stroke-width="20"/>',
          body:
              '<use id="target" href="#src" x="50" y="20" clip-path="url(#c)"/>',
        ),
      );
      await expectQuarterRegionHits(
        mounted,
        insideTarget: 'src',
        insideRetargeted: 'target',
      );
    });

    testWidgets('text target clip edge matches between paint and hit', (
      tester,
    ) async {
      // Derive the clip edge from the painted pixels so the assertion does
      // not depend on font metrics, then probe just inside and outside it.
      final mounted = await _mount(
        tester,
        _svg(
          defs: '''
    <clipPath id="c" clipPathUnits="objectBoundingBox">
      <rect x=".5" width=".5" height="1"/>
    </clipPath>''',
          body:
              '<text id="target" x="20" y="60" font-size="40" fill="red" clip-path="url(#c)">MM</text>',
        ),
      );
      final edge = _firstRedColumn(mounted.pixels, 200, 100);
      expect(edge, isNotNull);
      final inside = await mounted.tap(Offset(edge! + 6.0, 50));
      expect(inside.targetId, 'target');
      final outside = await mounted.tap(Offset(edge - 6.0, 50));
      expect(outside.targetId, isNull);
    });
  });
}
