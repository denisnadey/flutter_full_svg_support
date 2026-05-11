// ignore_for_file: avoid_print
/// Reproduction test for "Coffee Match Cut Animation 1" SVGator SVG.
///
/// Reported issue: the cup graphic (group id `eyAEWINQ6855`) "flies off to
/// the top of the card" — i.e. ends up clipped near y=0 instead of staying
/// roughly centered in the viewBox (700×400) during the first ~850 ms of the
/// animation.
///
/// SVGator data summary for `eyAEWINQ6855` (the cup group):
///   transform.data.t = (-399.95, -689.099999)
///   keys.o starts at t=100 with (399.95, 689.1) → translate = (0, 0)
///   keys.o stays within ~(390..574, 679..689) up to t=1730
/// So the *delta* applied by SVGator over the first ~1.7s is small; the cup
/// should remain near its "rest" position which, after the parent group
/// transforms `matrix(.552741 0 0 0.552741 125.774291 -38.339071)` and
/// `translate(-1.231932 -38.493285)`, sits roughly in the centre of the canvas.
///
/// This file's purpose is to *render* the SVG and capture diagnostic
/// information (pixel distribution by row/column, presence of the cup's
/// colourful palette in the expected region) so the bug can be iterated on
/// without spinning up the full example app.
library;

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:full_svg_flutter/src/animation/animated_svg_picture.dart';
import 'package:flutter_test/flutter_test.dart';

// ─── fixture ────────────────────────────────────────────────────────────────

const _fixturesDir = 'test/golden_comparison/svg_fixtures';
String _coffeeSvg() =>
    File('$_fixturesDir/coffee_match_cut_animation_1.svg')
        .readAsStringSync();

/// SVGator player JS (`https://cdn.svgator.com/ply/91c80d77.js?v=2024-09-05`,
/// downloaded once into the test directory). Used to reproduce the bug
/// deterministically — flutter_test cannot reach the real CDN, so without an
/// inlined copy the player never runs and the SVG stays at its static rest
/// position.
String _svgatorPlayerJs() =>
    File('test/animation/_svgator_player_91c80d77.js').readAsStringSync();

/// Wraps the player JS in a `<script><![CDATA[…]]></script>` block and
/// splices it in just before `</svg>` so it runs *after* SVGator's bootstrap
/// script has pushed animation data into `window.__SVGATOR_PLAYER__`.
String _coffeeSvgWithInlinePlayer() {
  final svg = _coffeeSvg();
  final playerScript =
      '<script><![CDATA[\n${_svgatorPlayerJs()}\n]]></script>';
  final idx = svg.lastIndexOf('</svg>');
  if (idx < 0) {
    throw StateError('Coffee SVG has no </svg> closing tag');
  }
  return svg.substring(0, idx) + playerScript + svg.substring(idx);
}

// ─── helpers ────────────────────────────────────────────────────────────────

Future<Uint8List> _render(
  WidgetTester tester,
  String svg, {
  double width = 700,
  double height = 400,
  bool autoPlay = true,
  Duration warmup = const Duration(milliseconds: 600),
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
  // Let the inline <script> finish executing, the external player JS download,
  // and a few rAF ticks happen so SVGator has actually written transforms.
  await tester.runAsync(() => Future<void>.delayed(warmup));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));

  final pixels = await tester.runAsync<Uint8List>(() async {
    final boundary =
        key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1.0);
    final byteData =
        await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    return byteData!.buffer.asUint8List();
  }) as Uint8List;

  // Drain any HTTP timers left dangling by the external script fetch.
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 500)),
  );
  await tester.pump();

  return pixels;
}

({int r, int g, int b, int a}) _pixel(
    Uint8List rgba, int width, int x, int y) {
  final idx = (y * width + x) * 4;
  return (
    r: rgba[idx],
    g: rgba[idx + 1],
    b: rgba[idx + 2],
    a: rgba[idx + 3],
  );
}

/// A pixel is "card" (white-ish card background) when bright and roughly
/// neutral. The SVG sets the page background to `#faf4ff` (very pale lavender)
/// and the card itself reads as near-white (`#f0f4ff` in the fixture).
bool _isCardLike(({int r, int g, int b, int a}) p) {
  return p.a > 200 &&
      p.r > 200 &&
      p.g > 200 &&
      p.b > 200;
}

/// A "cup" pixel — the cup graphic uses saturated colours (red/orange,
/// purple, dark navy). Saturated = max(R,G,B) − min(R,G,B) is large and at
/// least one channel is well below 200.
bool _isCupLike(({int r, int g, int b, int a}) p) {
  if (p.a < 100) return false;
  final maxC = [p.r, p.g, p.b].reduce((a, b) => a > b ? a : b);
  final minC = [p.r, p.g, p.b].reduce((a, b) => a < b ? a : b);
  return (maxC - minC) > 60 && minC < 200;
}

/// Returns the rows (y values) and columns (x values) where colourful "cup"
/// pixels exist, and the bounding box of the cup.
({int yMin, int yMax, int xMin, int xMax, int count}) _cupBoundingBox(
  Uint8List rgba,
  int width,
  int height,
) {
  int yMin = height, yMax = -1, xMin = width, xMax = -1, count = 0;
  for (int y = 0; y < height; y += 2) {
    for (int x = 0; x < width; x += 2) {
      final p = _pixel(rgba, width, x, y);
      if (_isCupLike(p)) {
        if (y < yMin) yMin = y;
        if (y > yMax) yMax = y;
        if (x < xMin) xMin = x;
        if (x > xMax) xMax = x;
        count++;
      }
    }
  }
  return (yMin: yMin, yMax: yMax, xMin: xMin, xMax: xMax, count: count);
}

void _logRowHistogram(
  Uint8List rgba,
  int width,
  int height,
  String label,
) {
  // 20-row buckets — show how many colourful cup pixels appear at each Y band.
  final bands = 10;
  final bandH = height ~/ bands;
  final counts = List<int>.filled(bands, 0);
  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x += 2) {
      if (_isCupLike(_pixel(rgba, width, x, y))) {
        final b = (y ~/ bandH).clamp(0, bands - 1);
        counts[b]++;
      }
    }
  }
  print('[$label] cup pixels per Y band (rows of ~$bandH):');
  for (int i = 0; i < bands; i++) {
    final yStart = i * bandH;
    final yEnd = (i + 1) * bandH - 1;
    print('   y=$yStart..$yEnd : ${counts[i]}');
  }
}

// ─── tests ──────────────────────────────────────────────────────────────────

void main() {
  group('Coffee Match Cut Animation 1 — repro', () {
    test('fixture exists and is non-trivial', () {
      final svg = _coffeeSvg();
      expect(svg.length, greaterThan(100000),
          reason: 'SVG should be the ~800KB SVGator export');
      expect(svg, contains('eyAEWINQ6855'),
          reason: 'cup group id must be present');
      expect(svg, contains('cdn.svgator.com/ply/'),
          reason: 'SVGator player bootstrap must be present');
    });

    testWidgets('cup is positioned in the lower-middle band, not at the top',
        (tester) async {
      final pixels = await _render(tester, _coffeeSvg(),
          warmup: const Duration(milliseconds: 600));

      final box = _cupBoundingBox(pixels, 700, 400);
      print('[Coffee t≈200ms] cup bbox: $box');
      _logRowHistogram(pixels, 700, 400, 'Coffee t≈200ms');

      expect(box.count, greaterThan(50),
          reason: 'cup should render (>50 colourful pixels found)');

      // The cup graphic spans roughly from the middle to the bottom of the
      // card in the original animation. If it has "flown off the top", its
      // bounding box yMin will be at the very top of the canvas (≤ 20) and
      // most of the cup pixels will be in the top 25% of the image.
      final cupCenterY = (box.yMin + box.yMax) / 2;
      print('[Coffee] cup center Y = $cupCenterY '
          '(viewport height = 400, expected roughly 200..360)');

      expect(cupCenterY, greaterThan(120),
          reason:
              'cup centre should be below ~y=120; if it is near the top, '
              'SVGator transforms are mis-applied (cup "flew up")');
    });

    testWidgets('cup horizontal centroid is inside the card area',
        (tester) async {
      final pixels = await _render(tester, _coffeeSvg(),
          warmup: const Duration(milliseconds: 600));
      final box = _cupBoundingBox(pixels, 700, 400);

      final cupCenterX = (box.xMin + box.xMax) / 2;
      print('[Coffee] cup center X = $cupCenterX (viewport width = 700)');
      // Card sits roughly in the middle horizontally; cup should be inside.
      expect(cupCenterX, greaterThan(200));
      expect(cupCenterX, lessThan(500));
    });

    testWidgets(
        'card background is visible (white-ish region exists in the centre)',
        (tester) async {
      final pixels = await _render(tester, _coffeeSvg());
      int cardCount = 0;
      for (int y = 80; y < 320; y += 4) {
        for (int x = 100; x < 600; x += 4) {
          if (_isCardLike(_pixel(pixels, 700, x, y))) cardCount++;
        }
      }
      print('[Coffee] card-like pixels in interior: $cardCount');
      expect(cardCount, greaterThan(500),
          reason: 'the white card should occupy a large central area');
    });
  });

  // ── With the real SVGator player JS inlined ───────────────────────────────
  //
  // The tests above only exercise the *static* render: in flutter_test the
  // external player JS at cdn.svgator.com cannot be fetched, so SVGator never
  // mutates the cup's transform attribute. To reproduce the reported "cup
  // flies up" bug we inline a copy of the player JS so the same code that
  // runs in the example app runs here too.

  group('Coffee Match Cut Animation 1 — with inline player', () {
    test('player JS fixture exists', () {
      final js = _svgatorPlayerJs();
      expect(js.length, greaterThan(10000),
          reason: 'player JS should be ~40 KB');
      expect(js, contains('__SVGATOR_PLAYER__'));
    });

    test('inline-player SVG is well-formed', () {
      final svg = _coffeeSvgWithInlinePlayer();
      // Two <script> tags: SVGator bootstrap (original) + injected player.
      final scriptCount =
          RegExp(r'<script\b').allMatches(svg).length;
      expect(scriptCount, equals(2));
      // Original file ends with `</svg>\r\n` — accept trailing whitespace.
      expect(svg.trimRight().endsWith('</svg>'), isTrue);
    });

    testWidgets(
        'diagnostic: does the player JS install svgatorPlayer on the SVG root?',
        (tester) async {
      // Inject a probe script AFTER the player. It writes the result of
      // checking key player state onto a fresh element id we can read back
      // via a status colour.
      final svg = _coffeeSvg();
      final playerScript =
          '<script><![CDATA[\n${_svgatorPlayerJs()}\n]]></script>';
      const probeScript = '''
<script><![CDATA[
  try {
    var ns = globalThis.__SVGATOR_PLAYER__ || globalThis.window && globalThis.window.__SVGATOR_PLAYER__;
    var slot = ns ? ns['91c80d77'] : null;
    var svg = document.getElementById('eyAEWINQ6851');
    var hasPlayer = !!(svg && svg.svgatorPlayer);
    var slotKind = slot ? (typeof slot === 'function' ? 'fn' : Array.isArray(slot) ? 'arr' : 'obj') : 'none';
    document.getElementById('eyAEWINQ6851').setAttribute('data-test-ns', ns ? 'yes' : 'no');
    document.getElementById('eyAEWINQ6851').setAttribute('data-test-slot', slotKind);
    document.getElementById('eyAEWINQ6851').setAttribute('data-test-player', hasPlayer ? 'yes' : 'no');
  } catch(e) {
    document.getElementById('eyAEWINQ6851').setAttribute('data-test-error', String(e));
  }
]]></script>''';
      final idx = svg.lastIndexOf('</svg>');
      final mutated = svg.substring(0, idx) +
          playerScript +
          probeScript +
          svg.substring(idx);

      await _render(tester, mutated,
          warmup: const Duration(milliseconds: 400));

      // The bridge applies attrs back to the SvgNode. Read them via the
      // public parser to inspect.
      // (We can't reach the live SvgDocument from outside the widget, so
      // instead we use a follow-up inline script that paints a status rect
      // whose colour encodes the answer. See alternative test below.)
    });

    testWidgets(
        'diagnostic: probe script paints status rect encoding player state',
        (tester) async {
      // Adds a small rect at (0, 0, 50, 50). After the player runs, an
      // inline probe colours it:
      //   green  = player attached
      //   yellow = bootstrap data still present (player never wrote)
      //   red    = JS error in player or probe
      //   blue   = neither — bootstrap didn't even register
      final svg = _coffeeSvg();
      final playerScript =
          '<script><![CDATA[\n${_svgatorPlayerJs()}\n]]></script>';
      const probeRect =
          '<rect id="testStatus" x="0" y="0" width="50" height="50" fill="blue"/>';
      const probeScript = '''
<script><![CDATA[
  try {
    var ns = globalThis.__SVGATOR_PLAYER__ || (globalThis.window && globalThis.window.__SVGATOR_PLAYER__);
    var slot = ns ? ns['91c80d77'] : null;
    var rootSvg = document.getElementById('eyAEWINQ6851');
    var hasPlayer = !!(rootSvg && rootSvg.svgatorPlayer);
    var color = 'magenta';
    if (hasPlayer) color = 'green';
    else if (slot && typeof slot === 'function') color = 'orange';
    else if (Array.isArray(slot)) color = 'yellow';
    else color = 'blue';
    document.getElementById('testStatus').setAttribute('fill', color);
  } catch(e) {
    document.getElementById('testStatus').setAttribute('fill', 'red');
  }
]]></script>''';

      // Add the probe rect just after <svg…>; insert the player + probe
      // scripts just before </svg>.
      final svgOpenEnd = svg.indexOf('>') + 1;
      final closeIdx = svg.lastIndexOf('</svg>');
      final mutated = svg.substring(0, svgOpenEnd) +
          probeRect +
          svg.substring(svgOpenEnd, closeIdx) +
          playerScript +
          probeScript +
          svg.substring(closeIdx);

      final pixels = await _render(tester, mutated,
          warmup: const Duration(milliseconds: 400));
      // Sample inside the 50×50 probe rect.
      final probe = _pixel(pixels, 700, 25, 25);
      print('[Coffee+player probe] status pixel: $probe');
      print('   green   = player attached to root svg.svgatorPlayer');
      print('   orange  = ns slot is a function (player class assigned)');
      print('   yellow  = ns slot is still an array (player never overwrote)');
      print('   blue    = no namespace / no slot');
      print('   red     = JS exception in probe');
      // The test just records; we'll iterate on what we find.
    });

    testWidgets(
        'diagnostic: force-seek the player to t=400 and inspect the cup '
        'transform attribute',
        (tester) async {
      // Confirmed in the previous probe: the SVGator player IS attached to
      // svg.svgatorPlayer. So either autoPlay is not firing or rAF is not
      // advancing time. Force a seek to t=400 and read back the transform.
      final svg = _coffeeSvg();
      final playerScript =
          '<script><![CDATA[\n${_svgatorPlayerJs()}\n]]></script>';
      const probeRect =
          '<rect id="testStatus" x="0" y="0" width="50" height="50" fill="blue"/>';
      // After seeking we encode info into the rect's `fill` (uses base-16
      // hex characters so we can express more than one bit). We pack a
      // crude tag into the colour so we can read it back.
      const probeScript = '''
<script><![CDATA[
  try {
    var root = document.getElementById('eyAEWINQ6851');
    var player = root && root.svgatorPlayer;
    if (!player) { document.getElementById('testStatus').setAttribute('fill','blue'); }
    else {
      try { player.seekTo(400); } catch(e1) {
        document.getElementById('testStatus').setAttribute('fill','red');
        document.getElementById('testStatus').setAttribute('data-err', String(e1));
        throw e1;
      }
      var cup = document.getElementById('eyAEWINQ6855');
      var t = cup ? cup.getAttribute('transform') : null;
      // Encode the y component of the cup transform into the rect's height
      // and the x component into its width so we can read positions back.
      var col = 'green';
      if (!t) col = 'orange';
      else if (t.indexOf('translate') < 0) col = 'magenta';
      document.getElementById('testStatus').setAttribute('fill', col);
      document.getElementById('testStatus').setAttribute('data-transform', t || '(null)');
    }
  } catch(err) {
    document.getElementById('testStatus').setAttribute('fill','red');
  }
]]></script>''';

      final svgOpenEnd = svg.indexOf('>') + 1;
      final closeIdx = svg.lastIndexOf('</svg>');
      final mutated = svg.substring(0, svgOpenEnd) +
          probeRect +
          svg.substring(svgOpenEnd, closeIdx) +
          playerScript +
          probeScript +
          svg.substring(closeIdx);

      final pixels = await _render(tester, mutated,
          warmup: const Duration(milliseconds: 400));
      final probe = _pixel(pixels, 700, 25, 25);
      print('[Coffee seek-400] status pixel: $probe');
      print('   green   = seek succeeded and transform attr exists');
      print('   orange  = no transform attribute on the cup after seek');
      print('   blue    = no player attached (regression)');
      print('   red     = exception during seek');

      // Now look at the cup's render. If seek+transform write worked, the
      // cup should have shifted compared to the unseeded render baseline.
      final box = _cupBoundingBox(pixels, 700, 400);
      print('[Coffee seek-400] cup bbox: $box');
    });

    testWidgets(
        'diagnostic: capture the exact transform string SVGator writes',
        (tester) async {
      // We can't easily read attributes back from inside flutter_test, so
      // encode the *prefix* of the transform value into a colour. The
      // bridge applies setAttribute → SvgNode attr → rerender; so we set the
      // testStatus rect's fill to a colour encoding what the cup's
      // transform attribute starts with.
      final svg = _coffeeSvg();
      final playerScript =
          '<script><![CDATA[\n${_svgatorPlayerJs()}\n]]></script>';
      const probeRect =
          '<rect id="testStatus" x="0" y="0" width="50" height="50" fill="blue"/>';
      const probeScript = '''
<script><![CDATA[
  try {
    var root = document.getElementById('eyAEWINQ6851');
    var p = root && root.svgatorPlayer;
    if (!p) { document.getElementById('testStatus').setAttribute('fill','blue'); }
    else {
      p.seekTo(400);
      var cup = document.getElementById('eyAEWINQ6855');
      var t = cup ? cup.getAttribute('transform') : '';
      // Distinguish formats by checking start:
      //   #00ff00 (green)   translate(
      //   #00ffff (cyan)    matrix(
      //   #ffff00 (yellow)  rotate(
      //   #ff0000 (red)     other / non-empty but unrecognised
      //   #888888 (gray)    null / empty
      var col;
      if (!t) col = '#888888';
      else if (t.indexOf('translate(') === 0 || t.indexOf(' translate(') >= 0) col = '#00ff00';
      else if (t.indexOf('matrix(') === 0) col = '#00ffff';
      else if (t.indexOf('rotate(') === 0) col = '#ffff00';
      else col = '#ff0000';
      document.getElementById('testStatus').setAttribute('fill', col);
      // Encode the length of the transform string into the rect's width
      // (clamped 50..400) so we can guess how complex the string is.
      var w = Math.min(400, 50 + (t ? t.length * 2 : 0));
      document.getElementById('testStatus').setAttribute('width', String(w));
      // Encode the FIRST 12 characters as a 60x10 bar at y=60 (one px per
      // char) — no, simpler: dump it into a console.log via setAttribute
      // on the doc's title so the bridge's message log shows it (the test
      // does not surface developer.log either, but we leave a sentinel).
      var titleEl = document.createElementNS('http://www.w3.org/2000/svg','title');
      titleEl.textContent = 'TRANSFORM:' + (t || '(null)');
      try { root.appendChild(titleEl); } catch(e) {}
    }
  } catch(err) {
    document.getElementById('testStatus').setAttribute('fill','#ff8800');
  }
]]></script>''';

      final svgOpenEnd = svg.indexOf('>') + 1;
      final closeIdx = svg.lastIndexOf('</svg>');
      final mutated = svg.substring(0, svgOpenEnd) +
          probeRect +
          svg.substring(svgOpenEnd, closeIdx) +
          playerScript +
          probeScript +
          svg.substring(closeIdx);

      final pixels = await _render(tester, mutated,
          warmup: const Duration(milliseconds: 400));
      final probe = _pixel(pixels, 700, 25, 25);
      print('[Coffee seek-400 fmt-probe] colour: r=${probe.r} g=${probe.g} b=${probe.b}');
      print('   #00ff00 (g=255) → translate(...)');
      print('   #00ffff (g=255,b=255) → matrix(...)');
      print('   #ffff00 (r=255,g=255) → rotate(...)');
      print('   #ff0000 (r=255) → other format');
      print('   #ff8800 → JS exception during probe');

      // Length encoding: pixel at (200, 25). If width was extended past 200
      // the pixel is the fill colour; otherwise blue background of probe.
      final tailPx = _pixel(pixels, 700, 200, 25);
      print('[Coffee seek-400 fmt-probe] tail @ (200, 25): $tailPx '
          '(non-blue ⇒ transform string ≥ 75 chars)');
    });

    testWidgets(
        'diagnostic: decode the matrix(a,b,c,d,e,f) SVGator writes',
        (tester) async {
      // Encode each component of the matrix into a separate small rect's
      // width attribute, so we can read it back from pixel widths.
      // tx_rect width = clamp(matrix.e + 500, 0, 1200) → tx readable in [-500, +700]
      // ty_rect width = clamp(matrix.f + 500, 0, 1200) → ty readable in [-500, +700]
      // a_rect width = round(matrix.a * 100 + 200)
      // d_rect width = round(matrix.d * 100 + 200)
      final svg = _coffeeSvg();
      final playerScript =
          '<script><![CDATA[\n${_svgatorPlayerJs()}\n]]></script>';
      const probeRects = '''
<rect id="rA" x="0"   y="0"   width="10" height="10" fill="#ff0000"/>
<rect id="rD" x="0"   y="20"  width="10" height="10" fill="#00ff00"/>
<rect id="rE" x="0"   y="40"  width="10" height="10" fill="#0000ff"/>
<rect id="rF" x="0"   y="60"  width="10" height="10" fill="#ff00ff"/>
<rect id="rOK" x="800" y="0" width="50" height="80" fill="blue"/>
''';
      const probeScript = '''
<script><![CDATA[
  function clamp(v, lo, hi){return v<lo?lo:v>hi?hi:v;}
  try {
    var root = document.getElementById('eyAEWINQ6851');
    var p = root && root.svgatorPlayer;
    if (!p) { document.getElementById('rOK').setAttribute('fill','black'); }
    else {
      p.seekTo(400);
      var cup = document.getElementById('eyAEWINQ6855');
      var t = cup ? cup.getAttribute('transform') : '';
      var m = t && t.match(/matrix\\(([^)]+)\\)/);
      if (m) {
        var nums = m[1].split(/[,\\s]+/).filter(Boolean).map(Number);
        var a = nums[0]||0, b = nums[1]||0, c = nums[2]||0;
        var d = nums[3]||0, e = nums[4]||0, f = nums[5]||0;
        document.getElementById('rA').setAttribute('width', String(Math.round(clamp(a*100+200, 1, 1200))));
        document.getElementById('rD').setAttribute('width', String(Math.round(clamp(d*100+200, 1, 1200))));
        document.getElementById('rE').setAttribute('width', String(Math.round(clamp(e+500, 1, 1200))));
        document.getElementById('rF').setAttribute('width', String(Math.round(clamp(f+500, 1, 1200))));
        document.getElementById('rOK').setAttribute('fill','green');
      } else {
        document.getElementById('rOK').setAttribute('fill','red');
      }
    }
  } catch(err) {
    document.getElementById('rOK').setAttribute('fill','#ff8800');
  }
]]></script>''';

      final svgOpenEnd = svg.indexOf('>') + 1;
      final closeIdx = svg.lastIndexOf('</svg>');
      final mutated = svg.substring(0, svgOpenEnd) +
          probeRects +
          svg.substring(svgOpenEnd, closeIdx) +
          playerScript +
          probeScript +
          svg.substring(closeIdx);

      final pixels = await _render(tester, mutated,
          warmup: const Duration(milliseconds: 400));

      // The probe rects are at y=0..69 in viewBox space. With viewBox=700×400
      // and BoxFit.fill onto a 700×400 widget, 1 viewBox unit = 1 device px.
      // For each rect, find the maximum x where the rect's distinctive
      // fill colour still shows.
      int rectWidthByColour(int rowY, int targetR, int targetG, int targetB) {
        int last = 0;
        for (int x = 0; x < 700; x++) {
          final p = _pixel(pixels, 700, x, rowY);
          if (p.r == targetR && p.g == targetG && p.b == targetB) last = x;
        }
        return last + 1;
      }

      final widthA = rectWidthByColour(5,  255,   0,   0);
      final widthD = rectWidthByColour(25,   0, 255,   0);
      final widthE = rectWidthByColour(45,   0,   0, 255);
      final widthF = rectWidthByColour(65, 255,   0, 255);

      final okPx = _pixel(pixels, 700, 825, 25);
      print('[Coffee matrix-decode] OK rect colour: $okPx');
      print('   green = matrix parsed, red = no match, black = no player, '
          'orange = exception');
      print('[Coffee matrix-decode] widthA=$widthA → matrix.a ≈ ${(widthA - 200) / 100.0}');
      print('[Coffee matrix-decode] widthD=$widthD → matrix.d ≈ ${(widthD - 200) / 100.0}');
      print('[Coffee matrix-decode] widthE=$widthE → matrix.e (tx) ≈ ${widthE - 500}');
      print('[Coffee matrix-decode] widthF=$widthF → matrix.f (ty) ≈ ${widthF - 500}');
    });

    testWidgets(
        'diagnostic: sample matrix at multiple seek times',
        (tester) async {
      // Walk through a series of seek times and dump the resulting matrix
      // for the cup. This characterises whether the bug is at a single
      // time or systemic.
      Future<({double e, double f, String full})> seekAndCapture(
          int seekMs) async {
        final svg = _coffeeSvg();
        final playerScript =
            '<script><![CDATA[\n${_svgatorPlayerJs()}\n]]></script>';
        final probeRects = '''
<rect id="rE" x="0"   y="0"  width="10" height="10" fill="#0000ff"/>
<rect id="rF" x="0"   y="20" width="10" height="10" fill="#ff00ff"/>
<rect id="rOK" x="800" y="0" width="50" height="40" fill="blue"/>
''';
        final probeScript = '''
<script><![CDATA[
  function clamp(v,lo,hi){return v<lo?lo:v>hi?hi:v;}
  try {
    var root = document.getElementById('eyAEWINQ6851');
    var p = root && root.svgatorPlayer;
    if (!p) { document.getElementById('rOK').setAttribute('fill','black'); }
    else {
      p.seekTo($seekMs);
      var cup = document.getElementById('eyAEWINQ6855');
      var t = cup ? cup.getAttribute('transform') : '';
      var m = t && t.match(/matrix\\(([^)]+)\\)/);
      if (m) {
        var nums = m[1].split(/[,\\s]+/).filter(Boolean).map(Number);
        var e = nums[4]||0, f = nums[5]||0;
        document.getElementById('rE').setAttribute('width', String(Math.round(clamp(e+500,1,1200))));
        document.getElementById('rF').setAttribute('width', String(Math.round(clamp(f+500,1,1200))));
        document.getElementById('rOK').setAttribute('fill','green');
      } else {
        document.getElementById('rOK').setAttribute('fill','red');
      }
    }
  } catch(err) {
    document.getElementById('rOK').setAttribute('fill','#ff8800');
  }
]]></script>''';

        final svgOpenEnd = svg.indexOf('>') + 1;
        final closeIdx = svg.lastIndexOf('</svg>');
        final mutated = svg.substring(0, svgOpenEnd) +
            probeRects +
            svg.substring(svgOpenEnd, closeIdx) +
            playerScript +
            probeScript +
            svg.substring(closeIdx);

        final pixels = await _render(tester, mutated,
            warmup: const Duration(milliseconds: 400));

        int rectWidth(int rowY, int r, int g, int b) {
          int last = 0;
          for (int x = 0; x < 700; x++) {
            final p = _pixel(pixels, 700, x, rowY);
            if (p.r == r && p.g == g && p.b == b) last = x;
          }
          return last + 1;
        }

        final widthE = rectWidth(5, 0, 0, 255);
        final widthF = rectWidth(25, 255, 0, 255);
        final e = (widthE - 500).toDouble();
        final f = (widthF - 500).toDouble();
        return (e: e, f: f, full: '($e, $f)');
      }

      final results = <int, ({double e, double f, String full})>{};
      for (final t in [0, 100, 200, 400, 650, 850, 1180, 1730, 3000]) {
        results[t] = await seekAndCapture(t);
      }
      print('[Coffee matrix vs time]');
      print('  Expected (per data.t + key.o):');
      print('    t=100  → translate ≈ ( 0.0,    0.0)');
      print('    t=650  → translate ≈ (174.05, -2.0)');
      print('    t=850  → translate ≈ (100.0,  -2.0)');
      print('    t=1180 → translate ≈ (-10.0, -10.0)');
      print('    t=1730 → translate ≈ ( 0.0,    0.0)');
      print('  Actual:');
      results.forEach((t, v) {
        print('    t=$t → matrix tx,ty ≈ ${v.full}');
      });
    });

    testWidgets(
        'sanity: an inline JS mutation that hides the cup IS observed',
        (tester) async {
      // Confirms that *if* the player JS could change the cup transform, our
      // test would detect it. Injects a script that sets the cup's opacity
      // to 0; after rendering, the colourful cup pixels should drop to ~0.
      final svg = _coffeeSvg();
      final mutator = '<script><![CDATA[\n'
          "document.getElementById('eyAEWINQ6855').setAttribute('opacity','0');\n"
          ']]></script>';
      final idx = svg.lastIndexOf('</svg>');
      final mutated = svg.substring(0, idx) + mutator + svg.substring(idx);

      final pixels = await _render(tester, mutated,
          warmup: const Duration(milliseconds: 300));
      final box = _cupBoundingBox(pixels, 700, 400);
      print('[Coffee+hide-mutator] cup bbox: $box');
      expect(box.count, lessThan(500),
          reason:
              'an inline opacity=0 mutation on eyAEWINQ6855 should make the '
              'colourful cup pixels disappear; if this fails the JS bridge '
              'is not executing the inline script at all');
    });

    testWidgets('cup does not fly above the top of the card '
        '(player JS runs)',
        (tester) async {
      // 600 ms warmup means SVGator has had time to:
      //   * run the bootstrap script
      //   * load and execute the injected player
      //   * tick ≈10 rAF frames
      // At t≈200..400ms the cup should still be near its rest position
      // (translate ≈ 0..(174,-2)) inside the card.
      final pixels = await _render(
        tester,
        _coffeeSvgWithInlinePlayer(),
        warmup: const Duration(milliseconds: 600),
      );

      final box = _cupBoundingBox(pixels, 700, 400);
      print('[Coffee+player t≈600ms] cup bbox: $box');
      _logRowHistogram(pixels, 700, 400, 'Coffee+player t≈600ms');

      expect(box.count, greaterThan(50),
          reason: 'cup should still render after player ticks');

      final cupCenterY = (box.yMin + box.yMax) / 2;
      print('[Coffee+player] cup center Y = $cupCenterY');

      // The reported bug: cup ends up clipped near y=0. If centerY < 100
      // the cup has flown off the top.
      expect(cupCenterY, greaterThan(120),
          reason:
              'cup centre should be below y=120; if it is near the top, '
              'the SVGator player is mis-applying transforms (cup "flew up")');
    });

    testWidgets('cup stays roughly horizontally centred while player runs',
        (tester) async {
      final pixels = await _render(
        tester,
        _coffeeSvgWithInlinePlayer(),
        warmup: const Duration(milliseconds: 600),
      );
      final box = _cupBoundingBox(pixels, 700, 400);
      final cupCenterX = (box.xMin + box.xMax) / 2;
      print('[Coffee+player] cup center X = $cupCenterX');
      expect(cupCenterX, greaterThan(200));
      expect(cupCenterX, lessThan(500));
    });
  });
}
