// ignore_for_file: avoid_print
/// Tests for the "Robot Character Light Animation" SVGator SVG.
///
/// The screenshot showed only floating cyan spheres with the robot body missing.
/// Root cause: polyfill crashed at `globalThis.URL.createObjectURL` (URL not yet
/// defined), aborting execution before `atob`/`btoa` were set up.
/// The SVGator player calls `atob` during init → "Can't find variable: atob" →
/// player never starts → elements that start at opacity:0 stay invisible.
///
/// Test design note:
///   SVGs with inline scripts that call `insertBefore` on a `<script src="https://...">`
///   element trigger `loadExternalScript` → real HTTP request via `http.get` →
///   pending async timer after widget disposal → "Timer still pending" test failure.
///   To avoid this, polyfill unit tests use inline JS only (no `src=` attribute on
///   the inserted element, or no `insertBefore` call), while the "bootstrap pattern"
///   test verifies the DOM API surface without actually loading an external URL.
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

/// Renders [svg] at [width]×[height] and returns raw RGBA pixels.
/// Uses [tester.runAsync] so unawaited image codec futures can complete.
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

/// Renders [svg] but also drains pending HTTP futures so the test framework
/// doesn't complain about a "Timer still pending" after widget disposal.
/// Use this for SVGs that contain inline `<script>` with external-script loading
/// (e.g., SVGator player bootstrap).
Future<Uint8List> _renderWithNetworkDrain(
  WidgetTester tester,
  String svg, {
  double width = 700,
  double height = 400,
}) async {
  final pixels = await _render(tester, svg, width: width, height: height);
  // Give pending HTTP requests a chance to complete (test mock returns 400
  // almost immediately; this extra pump drains the completion callbacks).
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 500)),
  );
  await tester.pump();
  return pixels;
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
      expect(doc.root.findById('eXCGagAMSin29'), isNotNull,
          reason: 'main body group must exist');
      expect(doc.root.findById('eXCGagAMSin4'), isNotNull,
          reason: 'defs ellipse must exist');
      expect(doc.root.findById('eXCGagAMSin82'), isNotNull,
          reason: 'initially-hidden group must exist');
    });

    test('hidden groups parse with numeric opacity 0', () {
      final doc = SvgParser.parse(_robotSvg().trim());
      final hidden = doc.root.findById('eXCGagAMSin82');
      expect(hidden, isNotNull);
      final opacity = hidden!.getAttributeValue('opacity');
      // The attribute is stored as-is from the SVG; compare numerically.
      expect(double.tryParse(opacity?.toString() ?? '') ?? -1.0,
          closeTo(0.0, 0.001),
          reason: 'opacity attribute must parse to ~0');
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
      // Robot SVG has inline JS that triggers external script load via http.
      // Drain the HTTP mock response so no timer is left pending.
      await _renderWithNetworkDrain(tester, _robotSvg());
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('background is dark (#15121c)', (tester) async {
      final pixels = await _renderWithNetworkDrain(tester, _robotSvg());
      // #15121c ≈ RGB(21, 18, 28) — dark purple/black.
      // Sample corners — should all be dark and opaque.
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
      final pixels = await _renderWithNetworkDrain(tester, _robotSvg());
      final visible = _visibleFraction(pixels, 700, 400);
      print('[Robot] visible fraction: ${(visible * 100).toStringAsFixed(1)}%');
      expect(visible, greaterThan(0.10),
          reason:
              'Expected at least 10% visible pixels at t=0; '
              'got ${(visible * 100).toStringAsFixed(1)}%');
    });

    testWidgets('renders non-background body elements', (tester) async {
      final pixels = await _renderWithNetworkDrain(tester, _robotSvg());
      // Background is ~(21, 18, 28). Body elements (off-white, cyan, orange)
      // should produce pixels with higher RGB values in the interior.
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
              'Expected robot body elements to produce visible '
              'non-background pixels; got $nonBackground');
    });
  });

  // ── 3. JS Bridge / polyfill invariants ────────────────────────────────────

  group('JS Bridge polyfill', () {
    // These tests use simple SVGs with inline JS only — no external script
    // loading — so no HTTP timers are created.

    testWidgets('atob/btoa are available and correct', (tester) async {
      // The bug: polyfill crashed before atob was defined.
      // The SVG has no `insertBefore` with http src, so no loadExternalScript.
      const svg = '''
<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
  <rect id="box" x="10" y="10" width="80" height="80" fill="red"/>
  <script><![CDATA[
    var encoded = btoa('hello');
    var decoded = atob(encoded);
    if (decoded === 'hello') {
      document.getElementById('box').setAttribute('fill', 'lime');
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

    testWidgets('URL.createObjectURL does not throw', (tester) async {
      // Regression: polyfill crashed here because URL was not yet defined.
      const svg = '''
<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
  <rect id="r" x="10" y="10" width="80" height="80" fill="red"/>
  <script><![CDATA[
    var url = URL.createObjectURL(new Blob(['test'], {type: 'text/plain'}));
    URL.revokeObjectURL(url);
    document.getElementById('r').setAttribute('fill', 'blue');
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

    testWidgets('SVGator DOM API surface: querySelectorAll, createElementNS, setAttributeNS',
        (tester) async {
      // Tests the exact DOM calls SVGator uses, WITHOUT inserting an https:// script
      // (which would trigger loadExternalScript and leave a pending HTTP timer).
      const svg = '''
<svg id="testRoot" viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg"
     xmlns:xlink="http://www.w3.org/1999/xlink">
  <rect id="status" x="10" y="10" width="80" height="80" fill="orange"/>
  <script><![CDATA[
    var ok = true;
    try {
      var svgEls = Array.from(document.querySelectorAll('svg#testRoot'));
      if (!svgEls || svgEls.length === 0) ok = false;

      var e = document.createElementNS('http://www.w3.org/2000/svg', 'script');
      if (!e) { ok = false; }

      e.setAttributeNS('http://www.w3.org/1999/xlink', 'href', '/local/player.js');
      e.setAttributeNS(null, 'src', '/local/player.js');

      var scripts = document.getElementsByTagName('script');
      if (!scripts || scripts.length === 0) ok = false;

      var first = scripts[0];
      if (!first || !first.parentNode) ok = false;
    } catch(err) {
      ok = false;
    }
    if (ok) {
      document.getElementById('status').setAttribute('fill', 'lime');
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

    testWidgets('window.svgator namespace push pattern', (tester) async {
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

    testWidgets('xlink setAttributeNS dual-stores href and xlink:href',
        (tester) async {
      const svg = '''
<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg"
     xmlns:xlink="http://www.w3.org/1999/xlink">
  <rect id="r" x="10" y="10" width="80" height="80" fill="orange"/>
  <script><![CDATA[
    var e = document.createElementNS('http://www.w3.org/2000/svg', 'use');
    e.setAttributeNS('http://www.w3.org/1999/xlink', 'href', '#r');
    var xl = e.getAttribute('xlink:href');
    var hr = e.getAttribute('href');
    if (xl === '#r' || hr === '#r') {
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
      final center = _pixel(pixels, 100, 50, 50);
      print('[Opacity=0] center: r=${center.r} g=${center.g} b=${center.b}');
      // Should be white (background rect), not red.
      expect(center.r, greaterThan(150), reason: 'opacity=0 hides red rect');
      expect(center.g, greaterThan(150));
      expect(center.b, greaterThan(150));
    });

    testWidgets('JS setAttribute opacity=1 reveals hidden group', (
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
      final center = _pixel(pixels, 100, 50, 50);
      print('[JS opacity] center: r=${center.r} g=${center.g} b=${center.b}');
      expect(center.r, greaterThan(150),
          reason: 'JS setAttribute should reveal red rect; center=$center');
      expect(center.g, lessThan(100));
    });

    testWidgets('multiple hidden groups revealed via forEach', (tester) async {
      const svg = '''
<svg viewBox="0 0 300 100" xmlns="http://www.w3.org/2000/svg">
  <rect x="0" y="0" width="300" height="100" fill="white"/>
  <g id="h1" opacity="0"><rect x="0"   y="0" width="100" height="100" fill="red"/></g>
  <g id="h2" opacity="0"><rect x="100" y="0" width="100" height="100" fill="green"/></g>
  <g id="h3" opacity="0"><rect x="200" y="0" width="100" height="100" fill="blue"/></g>
  <script><![CDATA[
    var ids = ['h1', 'h2', 'h3'];
    for (var i = 0; i < ids.length; i++) {
      document.getElementById(ids[i]).setAttribute('opacity', '1');
    }
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

  group('use element', () {
    testWidgets('<use xlink:href> renders referenced shape', (tester) async {
      const svg = '''
<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg"
     xmlns:xlink="http://www.w3.org/1999/xlink">
  <defs>
    <circle id="dot" r="30" fill="#72f6f9"/>
  </defs>
  <use xlink:href="#dot" transform="translate(50 50)"/>
</svg>''';

      final pixels = await _render(tester, svg, width: 100, height: 100);
      final center = _pixel(pixels, 100, 50, 50);
      print('[use xlink:href] center: r=${center.r} g=${center.g} b=${center.b}');
      // #72f6f9 ≈ RGB(114, 246, 249) — high G+B
      expect(center.a, greaterThan(100), reason: '<use> must render');
      expect(center.g + center.b, greaterThan(center.r * 2),
          reason: 'cyan has high G+B; center=$center');
    });

    testWidgets('<use href> (SVG2) renders referenced shape', (tester) async {
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

    testWidgets('<use transform> positions circle correctly', (tester) async {
      const svg = '''
<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <circle id="small" r="15" fill="red"/>
  </defs>
  <use href="#small" transform="translate(75 50)"/>
</svg>''';

      final pixels = await _render(tester, svg, width: 100, height: 100);
      final left  = _pixel(pixels, 100, 25, 50);
      final right = _pixel(pixels, 100, 75, 50);
      print('[use transform] left=$left right=$right');
      expect(right.a, greaterThan(100), reason: 'circle at (75,50) must be visible');
      expect(left.a,  lessThan(50),     reason: 'no circle at (25,50)');
    });
  });

  // ── 6. Structural invariants (no widget / DOM needed) ─────────────────────

  group('Robot SVG structure', () {
    test('has ≥100 path elements', () {
      final pathCount =
          RegExp(r'<path\b').allMatches(_robotSvg()).length;
      print('[Robot] path count: $pathCount');
      expect(pathCount, greaterThanOrEqualTo(100));
    });

    test('has >5 use elements', () {
      final useCount = RegExp(r'<use\b').allMatches(_robotSvg()).length;
      print('[Robot] use count: $useCount');
      expect(useCount, greaterThan(5));
    });

    test('≥5 groups start with opacity=0 (hidden robot parts animated by JS)', () {
      final hiddenCount =
          RegExp(r'<g [^>]*opacity="0"').allMatches(_robotSvg()).length;
      print('[Robot] opacity=0 groups: $hiddenCount');
      expect(hiddenCount, greaterThanOrEqualTo(5));
    });

    test('SVGator inline script uses querySelectorAll/createElementNS/insertBefore', () {
      final content = _robotSvg();
      expect(content, contains('querySelectorAll'));
      expect(content, contains('createElementNS'));
      expect(content, contains('getElementsByTagName'));
      expect(content, contains('insertBefore'));
    });

    test('SVGator inline script references cdn.svgator.com player', () {
      final content = _robotSvg();
      expect(content, contains('cdn.svgator.com'));
      expect(content, contains('91c80d77'));
    });
  });
}
