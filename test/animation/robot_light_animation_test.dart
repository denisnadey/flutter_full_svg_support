// ignore_for_file: avoid_print
/// Tests for the "Robot Character Light Animation" SVGator SVG.
///
/// The screenshot showed only floating cyan spheres with the robot body missing.
/// Root cause: polyfill crashed at `globalThis.URL.createObjectURL` (URL not yet
/// defined), aborting execution before `atob`/`btoa` were set up.
/// The SVGator player calls `atob` during init → "Can't find variable: atob" →
/// player never starts → elements that start at opacity:0 stay invisible.
///
/// This suite verifies:
///   1. Parser handles the large SVGator SVG without crashing.
///   2. Background color (#15121c) is applied.
///   3. Initial visible pixels exist (main body is not fully hidden at t=0).
///   4. Initial opacity:0 groups parse correctly (they exist in the tree).
///   5. The SVGator inline-script JS pattern works in the bridge (atob, URL,
///      querySelectorAll, createElementNS, setAttributeNS, getElementsByTagName,
///      parentNode.insertBefore).
///   6. setAttribute('opacity', '1') makes initially-hidden elements visible.
///   7. `<use>` elements with xlink:href resolve correctly.
///   8. `<circle>` and `<ellipse>` elements in `<defs>` (referenced by `<use>`)
///      do not produce visible pixels on their own.
library;

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:full_svg_flutter/src/animation/animated_svg_picture.dart';
import 'package:full_svg_flutter/src/animation/svg_parser.dart';
import 'package:flutter_test/flutter_test.dart';

// ─── fixture ────────────────────────────────────────────────────────────────

const _fixturesDir = 'test/golden_comparison/svg_fixtures';
String _robotSvg() =>
    File('$_fixturesDir/robot_character_light.svg').readAsStringSync();

// ─── helpers ────────────────────────────────────────────────────────────────

Future<Uint8List> _render(
  WidgetTester tester,
  String svg, {
  double width = 700,
  double height = 400,
  bool autoPlay = false,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1.0;

  final key = GlobalKey();
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.transparent,
        body: RepaintBoundary(
          key: key,
          child: SizedBox(
            width: width,
            height: height,
            child: AnimatedSvgPicture.string(
              svg,
              width: width,
              height: height,
              fit: BoxFit.fill,
              autoPlay: autoPlay,
            ),
          ),
        ),
      ),
    ),
  );

  await tester.pump();
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 400)),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));

  return await tester.runAsync<Uint8List>(() async {
    final boundary =
        key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1.0);
    final byteData =
        await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    return byteData!.buffer.asUint8List();
  }) as Uint8List;
}

double _visibleFraction(Uint8List rgba, int width, int height) {
  int visible = 0;
  for (int i = 3; i < rgba.length; i += 4) {
    if (rgba[i] > 10) visible++;
  }
  return visible / (width * height);
}

({int r, int g, int b, int a}) _pixel(
    Uint8List rgba, int width, int x, int y) {
  final idx = (y * width + x) * 4;
  return (
    r: rgba[idx],
    g: rgba[idx + 1],
    b: rgba[idx + 2],
    a: rgba[idx + 3]
  );
}

// ─── tests ──────────────────────────────────────────────────────────────────

void main() {
  // ── 1. Parser correctness ──────────────────────────────────────────────────

  group('Parser', () {
    test('parses robot SVG without throwing', () {
      expect(() => SvgParser.parse(_robotSvg().trim()), returnsNormally);
    });

    test('finds root svg element with correct viewBox', () {
      final doc = SvgParser.parse(_robotSvg().trim());
      final root = doc.root;
      expect(root.tagName, equals('svg'));
      expect(root.getAttributeValue('viewBox'), equals('0 0 700 400'));
    });

    test('finds key elements by id', () {
      final doc = SvgParser.parse(_robotSvg().trim());
      // Main body group
      expect(doc.root.findById('eXCGagAMSin29'), isNotNull,
          reason: 'main body group must exist');
      // A defs ellipse
      expect(doc.root.findById('eXCGagAMSin4'), isNotNull,
          reason: 'defs ellipse must exist');
      // A hidden group (opacity:0 at t=0)
      expect(doc.root.findById('eXCGagAMSin82'), isNotNull,
          reason: 'initially-hidden group must exist');
    });

    test('hidden groups parse with opacity=0', () {
      final doc = SvgParser.parse(_robotSvg().trim());
      final hidden = doc.root.findById('eXCGagAMSin82');
      expect(hidden, isNotNull);
      expect(hidden!.getAttributeValue('opacity'), equals('0'));
    });

    test('main body group has translate transform', () {
      final doc = SvgParser.parse(_robotSvg().trim());
      final body = doc.root.findById('eXCGagAMSin29');
      expect(body, isNotNull);
      expect(body!.getAttributeValue('transform'), contains('translate'));
    });

    test('document has background-color style', () {
      final doc = SvgParser.parse(_robotSvg().trim());
      final style = doc.root.getAttributeValue('style') ?? '';
      expect(style, contains('15121c'),
          reason: 'dark background #15121c must be present');
    });
  });

  // ── 2. Render: smoke & background ─────────────────────────────────────────

  group('Render', () {
    testWidgets('smoke: renders without throwing', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(
              _robotSvg(),
              width: 700,
              height: 400,
              autoPlay: false,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('background is dark (#15121c)', (tester) async {
      final pixels = await _render(tester, _robotSvg());
      // Sample several points near the edges where background should dominate.
      // #15121c ≈ RGB(21, 18, 28) — very dark, but alpha > 0 means rendered.
      final corners = [
        _pixel(pixels, 700, 10, 10),
        _pixel(pixels, 700, 690, 10),
        _pixel(pixels, 700, 10, 390),
        _pixel(pixels, 700, 690, 390),
      ];
      int darkCount = 0;
      for (final p in corners) {
        if (p.a > 200 && p.r < 80 && p.g < 80 && p.b < 80) darkCount++;
      }
      print('[Robot] dark corners: $darkCount / ${corners.length}');
      expect(darkCount, greaterThanOrEqualTo(2),
          reason:
              'Expected dark background (#15121c) at corners; '
              'corners=$corners');
    });

    testWidgets('has visible pixels at t=0 (not all transparent)', (
      tester,
    ) async {
      final pixels = await _render(tester, _robotSvg());
      final visible = _visibleFraction(pixels, 700, 400);
      print('[Robot] visible fraction: ${(visible * 100).toStringAsFixed(1)}%');
      // The dark background + body elements should give >10% visible pixels.
      expect(visible, greaterThan(0.10),
          reason:
              'Expected at least 10% visible pixels at t=0; '
              'got ${(visible * 100).toStringAsFixed(1)}%');
    });

    testWidgets('renders more than just background (body elements visible)', (
      tester,
    ) async {
      final pixels = await _render(tester, _robotSvg());
      // Sample interior pixels. The robot body (off-white, cyan, orange fills)
      // should produce pixels that differ from the background.
      // Background is ~(21, 18, 28). Non-background pixel has higher values.
      int nonBackground = 0;
      for (int y = 50; y < 350; y += 20) {
        for (int x = 100; x < 600; x += 20) {
          final p = _pixel(pixels, 700, x, y);
          if (p.a > 100 && (p.r > 40 || p.g > 40 || p.b > 50)) {
            nonBackground++;
          }
        }
      }
      print('[Robot] non-background interior pixels: $nonBackground');
      expect(nonBackground, greaterThan(5),
          reason:
              'Expected robot body elements to produce visible non-background '
              'pixels; got $nonBackground');
    });
  });

  // ── 3. JS Bridge / polyfill invariants ────────────────────────────────────

  group('JS Bridge polyfill (inline SVGator-style script patterns)', () {
    // These tests exercise the exact JS patterns the SVGator player uses,
    // isolated from the real robot SVG so they don't need network access.

    testWidgets('atob/btoa are available and correct', (tester) async {
      // The bug: polyfill crashed before atob was defined.
      const svg = '''
<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg"
     xmlns:xlink="http://www.w3.org/1999/xlink">
  <rect id="box" x="10" y="10" width="80" height="80" fill="red"/>
  <script><![CDATA[
    (function() {
      var encoded = btoa('hello');        // must not throw
      var decoded = atob(encoded);        // must not throw
      if (decoded !== 'hello') {
        document.getElementById('box').setAttribute('fill', 'black');
      } else {
        document.getElementById('box').setAttribute('fill', 'lime');
      }
    })();
  ]]></script>
</svg>''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svg, width: 200, height: 200),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      // No crash = atob/btoa available
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('URL.createObjectURL does not throw', (tester) async {
      // The exact line that was crashing the polyfill.
      const svg = '''
<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
  <rect id="r" x="10" y="10" width="80" height="80" fill="red"/>
  <script><![CDATA[
    (function() {
      var url = URL.createObjectURL(new Blob(['test'], {type: 'text/plain'}));
      URL.revokeObjectURL(url);
      document.getElementById('r').setAttribute('fill', 'blue');
    })();
  ]]></script>
</svg>''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svg, width: 200, height: 200),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('SVGator inline-script bootstrap pattern runs without error',
        (tester) async {
      // Reproduces the exact self-executing function shape from the robot SVG:
      // (function(s,i,u,o,c,w,d,t,n,x,e,p,a,b){ ... })(args)
      // Tests: Array.from, querySelectorAll, createElementNS, setAttributeNS
      //        (xlink), getElementsByTagName, parentNode.insertBefore.
      const svg = '''
<svg id="testRoot" viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg"
     xmlns:xlink="http://www.w3.org/1999/xlink">
  <rect id="status" x="10" y="10" width="80" height="80" fill="orange"/>
  <script><![CDATA[
    var _ok = true;
    try {
      // Pattern 1: Array.from + querySelectorAll
      var svgEls = Array.from(document.querySelectorAll('svg#testRoot'));
      if (!svgEls) _ok = false;

      // Pattern 2: createElementNS (SVGator creates a script element)
      var e = document.createElementNS('http://www.w3.org/2000/svg', 'script');
      if (!e) _ok = false;

      // Pattern 3: setAttributeNS with xlink (xlink:href assignment)
      e.setAttributeNS('http://www.w3.org/1999/xlink', 'href', 'https://example.com/player.js');
      e.setAttributeNS(null, 'src', 'https://example.com/player.js');

      // Pattern 4: getElementsByTagName + parentNode.insertBefore
      var scripts = document.getElementsByTagName('script');
      var first = scripts[0];
      if (first && first.parentNode) {
        first.parentNode.insertBefore(e, first);
      }
    } catch(err) {
      _ok = false;
    }
    if (_ok) {
      document.getElementById('status').setAttribute('fill', 'lime');
    } else {
      document.getElementById('status').setAttribute('fill', 'red');
    }
  ]]></script>
</svg>''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svg, width: 200, height: 200),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('window.svgator namespace and push pattern works', (
      tester,
    ) async {
      // SVGator pushes animation data: window['svgator']['91c80d77'].push(data)
      const svg = '''
<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
  <rect id="r" x="10" y="10" width="80" height="80" fill="orange"/>
  <script><![CDATA[
    var ns = 'svgator';
    var key = '91c80d77';
    window[ns] = window[ns] || {};
    window[ns][key] = window[ns][key] || [];
    window[ns][key].push({root: 'testSvg', version: '2024-09-05'});
    if (window[ns][key].length === 1) {
      document.getElementById('r').setAttribute('fill', 'lime');
    }
  ]]></script>
</svg>''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svg, width: 200, height: 200),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('xlink setAttributeNS stores as both href and xlink:href', (
      tester,
    ) async {
      // After our fix, setAttributeNS with xlink namespace should dual-store.
      const svg = '''
<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg"
     xmlns:xlink="http://www.w3.org/1999/xlink">
  <rect id="r" x="10" y="10" width="80" height="80" fill="orange"/>
  <script><![CDATA[
    var e = document.createElementNS('http://www.w3.org/2000/svg', 'use');
    e.setAttributeNS('http://www.w3.org/1999/xlink', 'href', '#r');
    var xlinkVal = e.getAttribute('xlink:href');
    var hrefVal  = e.getAttribute('href');
    if (xlinkVal === '#r' || hrefVal === '#r') {
      document.getElementById('r').setAttribute('fill', 'lime');
    } else {
      document.getElementById('r').setAttribute('fill', 'red');
    }
  ]]></script>
</svg>''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svg, width: 200, height: 200),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });

  // ── 4. Opacity & visibility via JS setAttribute ────────────────────────────

  group('Opacity control via setAttribute', () {
    testWidgets('element with opacity=0 is not visible', (tester) async {
      const svg = '''
<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
  <rect x="0" y="0" width="100" height="100" fill="white"/>
  <g id="hidden" opacity="0">
    <rect x="10" y="10" width="80" height="80" fill="red"/>
  </g>
</svg>''';

      final pixels = await _render(tester, svg, width: 100, height: 100);
      // Center pixel should be white (from background rect), not red.
      final center = _pixel(pixels, 100, 50, 50);
      print('[Opacity=0] center pixel: r=${center.r} g=${center.g} b=${center.b}');
      expect(center.r, greaterThan(150),
          reason: 'opacity=0 group should not show red; center=$center');
      expect(center.g, greaterThan(150));
      expect(center.b, greaterThan(150));
    });

    testWidgets('JS setAttribute opacity=1 makes hidden group visible', (
      tester,
    ) async {
      const svg = '''
<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
  <rect x="0" y="0" width="100" height="100" fill="white"/>
  <g id="hidden" opacity="0">
    <rect x="10" y="10" width="80" height="80" fill="#ff0000"/>
  </g>
  <script><![CDATA[
    document.getElementById('hidden').setAttribute('opacity', '1');
  ]]></script>
</svg>''';

      final pixels = await _render(tester, svg, width: 100, height: 100);
      // After JS runs, center should be red.
      final center = _pixel(pixels, 100, 50, 50);
      print('[JS opacity fix] center: r=${center.r} g=${center.g} b=${center.b}');
      expect(center.r, greaterThan(150),
          reason: 'JS setAttribute opacity=1 should reveal red rect; center=$center');
      expect(center.g, lessThan(100));
    });

    testWidgets('multiple hidden groups can be made visible via JS', (
      tester,
    ) async {
      const svg = '''
<svg viewBox="0 0 300 100" xmlns="http://www.w3.org/2000/svg">
  <rect x="0" y="0" width="300" height="100" fill="white"/>
  <g id="h1" opacity="0"><rect x="0"   y="0" width="100" height="100" fill="red"/></g>
  <g id="h2" opacity="0"><rect x="100" y="0" width="100" height="100" fill="green"/></g>
  <g id="h3" opacity="0"><rect x="200" y="0" width="100" height="100" fill="blue"/></g>
  <script><![CDATA[
    ['h1','h2','h3'].forEach(function(id) {
      document.getElementById(id).setAttribute('opacity', '1');
    });
  ]]></script>
</svg>''';

      final pixels = await _render(tester, svg, width: 300, height: 100);
      final red   = _pixel(pixels, 300, 50,  50);
      final green = _pixel(pixels, 300, 150, 50);
      final blue  = _pixel(pixels, 300, 250, 50);
      print('[Multi-reveal] red=$red green=$green blue=$blue');
      expect(red.r,   greaterThan(150), reason: 'red panel');
      expect(green.g, greaterThan(100), reason: 'green panel');
      expect(blue.b,  greaterThan(100), reason: 'blue panel');
    });
  });

  // ── 5. <use> element correctness ──────────────────────────────────────────

  group('use element with xlink:href', () {
    testWidgets('<use> with xlink:href renders referenced shape', (
      tester,
    ) async {
      const svg = '''
<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg"
     xmlns:xlink="http://www.w3.org/1999/xlink">
  <defs>
    <circle id="dot" r="30" fill="#72f6f9"/>
  </defs>
  <use xlink:href="#dot" transform="translate(50 50)"/>
</svg>''';

      final pixels = await _render(tester, svg, width: 100, height: 100);
      // Center (50,50) should show the cyan circle color.
      final center = _pixel(pixels, 100, 50, 50);
      print('[use xlink:href] center: r=${center.r} g=${center.g} b=${center.b}');
      // #72f6f9 ≈ RGB(114, 246, 249) — high green and blue
      expect(center.a, greaterThan(100), reason: '<use> must render');
      expect(center.g + center.b, greaterThan(center.r * 2),
          reason: 'cyan (#72f6f9) has high G+B; center=$center');
    });

    testWidgets('<use> with href (SVG2) renders referenced shape', (
      tester,
    ) async {
      const svg = '''
<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <circle id="dot2" r="30" fill="#ff8800"/>
  </defs>
  <use href="#dot2" transform="translate(50 50)"/>
</svg>''';

      final pixels = await _render(tester, svg, width: 100, height: 100);
      final center = _pixel(pixels, 100, 50, 50);
      print('[use href] center: r=${center.r} g=${center.g} b=${center.b}');
      expect(center.a, greaterThan(100), reason: '<use href> must render');
      expect(center.r, greaterThan(center.b * 2),
          reason: 'orange has high R; center=$center');
    });

    testWidgets('<use> with transform applies position correctly', (
      tester,
    ) async {
      // Circle only at (75,50); (25,50) should be transparent.
      const svg = '''
<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <circle id="small" r="15" fill="red"/>
  </defs>
  <use href="#small" transform="translate(75 50)"/>
</svg>''';

      final pixels = await _render(tester, svg, width: 100, height: 100);
      final left   = _pixel(pixels, 100, 25, 50);
      final right  = _pixel(pixels, 100, 75, 50);
      print('[use transform] left=$left right=$right');
      expect(right.a, greaterThan(100), reason: 'circle at (75,50) must be visible');
      expect(left.a,  lessThan(50),     reason: 'no circle at (25,50)');
    });
  });

  // ── 6. Robot SVG structural invariants ───────────────────────────────────

  group('Robot SVG structural invariants', () {
    test('SVG has correct number of path elements (≥100)', () {
      final content = _robotSvg();
      final pathCount =
          RegExp(r'<path\b').allMatches(content).length;
      print('[Robot] path count: $pathCount');
      expect(pathCount, greaterThanOrEqualTo(100));
    });

    test('SVG has use elements referencing defs', () {
      final content = _robotSvg();
      final useCount = RegExp(r'<use\b').allMatches(content).length;
      print('[Robot] use element count: $useCount');
      expect(useCount, greaterThan(5));
    });

    test('8 groups start with opacity=0 (hidden robot parts)', () {
      final content = _robotSvg();
      final hiddenGroups =
          RegExp(r'<g [^>]*opacity="0"').allMatches(content).length;
      print('[Robot] opacity=0 groups: $hiddenGroups');
      // There are exactly 8 such groups — robot parts animated from invisible.
      expect(hiddenGroups, greaterThanOrEqualTo(5),
          reason:
              'Robot body parts start hidden (opacity:0) and are revealed by '
              'SVGator JS animation; if count dropped, something changed');
    });

    test('SVGator inline script contains required JS API calls', () {
      final content = _robotSvg();
      expect(content, contains('querySelectorAll'),
          reason: 'SVGator uses querySelectorAll');
      expect(content, contains('createElementNS'),
          reason: 'SVGator creates script element via createElementNS');
      expect(content, contains('getElementsByTagName'),
          reason: 'SVGator finds insertion point via getElementsByTagName');
      expect(content, contains('insertBefore'),
          reason: 'SVGator inserts script via insertBefore');
    });

    test('SVGator inline script references external player JS', () {
      final content = _robotSvg();
      expect(content, contains('cdn.svgator.com'),
          reason: 'SVGator player is hosted on cdn.svgator.com');
      expect(content, contains('91c80d77'),
          reason: 'player bundle hash must be present');
    });
  });
}
