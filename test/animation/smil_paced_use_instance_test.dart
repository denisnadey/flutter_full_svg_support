import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:full_svg_flutter/src/animation/animated_svg_picture.dart';
import 'package:full_svg_flutter/src/animation/smil/smil_parser.dart';
import 'package:full_svg_flutter/src/animation/svg_length_resolver.dart';
import 'package:full_svg_flutter/src/animation/svg_parser.dart';

/// Regressions for issue #44: percentage-aware `calcMode="paced"` animations
/// on shared `<symbol>` content resolve their segment distances in the
/// viewport of each `<use>` instance, for painting and hit testing alike.
///
/// The shared fixture animates `x` with `values="0;50%;40"` on a 6×10 rect
/// inside a no-viewBox symbol. For a 100-wide instance the values are
/// 0 / 50 / 40 (distances 50 + 10 → keyTimes 0 / 0.833 / 1), so at half the
/// duration x = 30. For a 200-wide instance they are 0 / 100 / 40
/// (100 + 60 → keyTimes 0 / 0.625 / 1), so at the same time x = 80.
const _symbol = '''
    <symbol id="source">
      <rect id="inst" y="0" width="6" height="10" fill="red">
        <animate attributeName="x" values="0;50%;40" calcMode="paced" dur="2s"/>
      </rect>
    </symbol>''';

const _oneSecond = Duration(seconds: 1);

class _Mounted {
  const _Mounted({
    required this.pixels,
    required this.tap,
    required this.width,
  });

  final Uint8List pixels;
  final int width;
  final Future<({String? targetId, String? retargetedId})> Function(Offset) tap;
}

Future<_Mounted> _mount(
  WidgetTester tester,
  String svg, {
  int width = 200,
  int height = 60,
  Key? pictureKey,
  List<SvgTraceEvent>? traceSink,
}) async {
  final repaintBoundaryKey = GlobalKey();
  final traceEvents = traceSink ?? <SvgTraceEvent>[];
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
                key: pictureKey,
                autoPlay: false,
                initialTime: _oneSecond,
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

  return _Mounted(pixels: pixels!, tap: tap, width: width);
}

bool _isRed(_Mounted mounted, int x, int y) {
  final offset = ((y * mounted.width) + x) * 4;
  final p = mounted.pixels;
  return p[offset] > 200 &&
      p[offset + 1] < 100 &&
      p[offset + 2] < 100 &&
      p[offset + 3] > 200;
}

String _twoInstances({bool wideFirst = false}) {
  const narrow = '<use id="u1" href="#source" width="100" height="20"/>';
  const wide = '<use id="u2" href="#source" y="30" width="200" height="20"/>';
  return '''
<svg viewBox="0 0 200 60" xmlns="http://www.w3.org/2000/svg">
  <defs>
$_symbol
  </defs>
  ${wideFirst ? wide : narrow}
  ${wideFirst ? narrow : wide}
</svg>''';
}

void _expectTwoInstancePositions(_Mounted mounted) {
  // 100-wide instance (row 0..10): x = 30.
  expect(_isRed(mounted, 31, 5), isTrue, reason: 'u1 should be at x=30');
  expect(_isRed(mounted, 81, 5), isFalse, reason: 'u1 must not use x=80');
  // 200-wide instance (row 30..40): x = 80.
  expect(_isRed(mounted, 81, 35), isTrue, reason: 'u2 should be at x=80');
  expect(_isRed(mounted, 31, 35), isFalse, reason: 'u2 must not use x=30');
}

void main() {
  group('paced percentages per use instance viewport', () {
    testWidgets('two differently sized instances paint independently', (
      tester,
    ) async {
      final mounted = await _mount(tester, _twoInstances());
      _expectTwoInstancePositions(mounted);
    });

    testWidgets('document order does not seed the shared definition', (
      tester,
    ) async {
      final mounted = await _mount(tester, _twoInstances(wideFirst: true));
      _expectTwoInstancePositions(mounted);
    });

    testWidgets('two differently sized instances hit-test independently', (
      tester,
    ) async {
      final mounted = await _mount(tester, _twoInstances());

      final narrowHit = await mounted.tap(const Offset(33, 5));
      expect(narrowHit.targetId, 'inst');
      expect(narrowHit.retargetedId, 'u1');

      final wideHit = await mounted.tap(const Offset(83, 35));
      expect(wideHit.targetId, 'inst');
      expect(wideHit.retargetedId, 'u2');

      expect((await mounted.tap(const Offset(83, 5))).targetId, isNull);
      expect((await mounted.tap(const Offset(33, 35))).targetId, isNull);
    });

    testWidgets('hit testing re-evaluates the instance painted first', (
      tester,
    ) async {
      // The wide instance is painted last, so the shared DOM holds x = 80
      // after painting; hit testing the narrow instance must still find its
      // own x = 30.
      final mounted = await _mount(tester, _twoInstances());
      final hit = await mounted.tap(const Offset(33, 5));
      expect(hit.targetId, 'inst');
      expect(hit.retargetedId, 'u1');
      expect((await mounted.tap(const Offset(83, 5))).targetId, isNull);
    });

    testWidgets('leaving an instance restores the surrounding viewport', (
      tester,
    ) async {
      // u3 has no width/height, so it establishes no instance viewport and
      // reads the shared rect with the root viewport (200 → x = 80). It is
      // painted right after the 100-wide u2, whose refresh must not leak.
      const svg =
          '''
<svg viewBox="0 0 200 90" xmlns="http://www.w3.org/2000/svg">
  <defs>
$_symbol
  </defs>
  <use id="u1" href="#source" width="200" height="20"/>
  <use id="u2" href="#source" y="30" width="100" height="20"/>
  <use id="u3" href="#source" y="60"/>
</svg>''';
      final mounted = await _mount(tester, svg, height: 90);
      expect(_isRed(mounted, 81, 5), isTrue);
      expect(_isRed(mounted, 31, 35), isTrue);
      expect(
        _isRed(mounted, 81, 65),
        isTrue,
        reason: 'u3 uses the root viewport',
      );
      expect(
        _isRed(mounted, 31, 65),
        isFalse,
        reason: 'u2 state leaked into u3',
      );
    });

    testWidgets('nested instances restore the outer instance viewport', (
      tester,
    ) async {
      // Inside the 200-wide outer instance, the first child use gets a
      // 100-wide viewport (x = 30); the second has no size of its own and
      // resolves against the outer instance (x = 80).
      const svg =
          '''
<svg viewBox="0 0 200 60" xmlns="http://www.w3.org/2000/svg">
  <defs>
$_symbol
    <symbol id="outer">
      <use href="#source" width="50%" height="20"/>
      <use href="#source" y="30"/>
    </symbol>
  </defs>
  <use id="o" href="#outer" width="200" height="60"/>
</svg>''';
      final mounted = await _mount(tester, svg);
      expect(_isRed(mounted, 31, 5), isTrue, reason: 'inner 100-wide use');
      expect(_isRed(mounted, 81, 5), isFalse);
      expect(_isRed(mounted, 81, 35), isTrue, reason: 'outer 200-wide use');
      expect(_isRed(mounted, 31, 35), isFalse, reason: 'inner state leaked');
    });

    testWidgets('viewport change invalidates the cached paced key times', (
      tester,
    ) async {
      // A dimensionless root takes the widget size as its viewport, so the
      // 50%-wide use instance is 100 wide at 200px and 200 wide at 400px.
      // The GlobalKey keeps the same widget state (and timeline) across the
      // two layouts.
      const svg =
          '''
<svg xmlns="http://www.w3.org/2000/svg">
  <defs>
$_symbol
  </defs>
  <use id="u" href="#source" width="50%" height="20"/>
</svg>''';
      final key = GlobalKey();
      final narrow = await _mount(tester, svg, width: 200, pictureKey: key);
      expect(_isRed(narrow, 31, 5), isTrue);
      expect(_isRed(narrow, 81, 5), isFalse);

      final wide = await _mount(tester, svg, width: 400, pictureKey: key);
      expect(_isRed(wide, 81, 5), isTrue, reason: 'instance is 200 wide now');
      expect(_isRed(wide, 31, 5), isFalse, reason: 'stale 100-wide key times');
    });
  });

  group('paced key-time cache', () {
    test('keeps one entry per instance viewport without recomputing', () {
      final document = SvgParser.parse('''
        <svg viewBox="0 0 200 60">
          <defs>
$_symbol
          </defs>
          <use href="#source" width="100" height="20"/>
        </svg>
      ''');
      final animation = SmilParser.parseAnimations(document).single;
      final symbol = document.root.findById('source')!;
      final rect = document.root.findById('inst')!;
      const narrow = ui.Size(100, 20);
      const wide = ui.Size(200, 20);

      // Geometry consumers receive the deferred percentage value and resolve
      // it themselves, so mirror that here inside the instance viewport.
      double xAt(ui.Size viewport) {
        return SvgLengthResolutionContext.runWithRootViewport(
          const ui.Size(200, 60),
          () => SvgLengthResolutionContext.runWithViewportForNode(
            symbol,
            viewport,
            () => resolveSvgLengthValue(
              rect,
              animation.computeValue(0.5),
              reference: SvgLengthReference.horizontal,
            )!,
          ),
        );
      }

      expect(xAt(narrow), closeTo(30, 1e-9));
      expect(xAt(wide), closeTo(80, 1e-9));
      expect(xAt(narrow), closeTo(30, 1e-9));
      expect(xAt(wide), closeTo(80, 1e-9));
      expect(animation.debugPacedKeyTimesComputations, 2);
    });
  });
}
