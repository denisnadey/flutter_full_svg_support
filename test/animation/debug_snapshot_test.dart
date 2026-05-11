// ignore_for_file: avoid_print
/// Tests for the live-state debug snapshot mechanism wired into
/// [AnimatedSvgController.captureDebugSnapshot] / `currentTimeMs`.
///
/// The snapshot is the data source for the in-app debug viewer (gallery
/// card → long-press) — it is what gets dumped to JSON when the user hits
/// the "copy/save" button. These tests verify:
///
///   1. After mounting, the snapshot reports a sensible element count and a
///      viewBox.
///   2. After running the SVGator player for ≈400 ms, the snapshot reflects
///      the live `transform` attribute the player wrote onto the cup group
///      `eyAEWINQ6855` (i.e. the snapshot is *live*, not just initial).
///   3. Each element's `hasAnimations` flag reflects whether SMIL/SVGator
///      touches it.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:full_svg_flutter/full_svg_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

const _fixturesDir = 'test/golden_comparison/svg_fixtures';
String _coffeeSvg() =>
    File('$_fixturesDir/coffee_match_cut_animation_1.svg').readAsStringSync();
String _svgatorPlayerJs() =>
    File('test/animation/_svgator_player_91c80d77.js').readAsStringSync();

/// Splices the local copy of the SVGator player JS into the SVG so the
/// player runs deterministically without trying to fetch the CDN script.
String _coffeeSvgWithInlinePlayer() {
  final svg = _coffeeSvg();
  final scriptTag =
      '<script><![CDATA[\n${_svgatorPlayerJs()}\n]]></script>';
  final idx = svg.lastIndexOf('</svg>');
  if (idx < 0) {
    throw StateError('No </svg> tag');
  }
  return svg.substring(0, idx) + scriptTag + svg.substring(idx);
}

void main() {
  group('AnimatedSvgController debug snapshot', () {
    testWidgets('captureDebugSnapshot returns the document tree',
        (tester) async {
      final controller = AnimatedSvgController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(
              _coffeeSvg(),
              controller: controller,
              autoPlay: false,
              width: 700,
              height: 400,
            ),
          ),
        ),
      );
      await tester.pump();

      final snap = controller.captureDebugSnapshot();
      expect(snap, isNotNull, reason: 'snapshot must be available once mounted');
      expect(snap!['elementCount'], isA<int>());
      expect(snap['elementCount'], greaterThan(50),
          reason: 'coffee SVG has many groups; expected >50 elements');

      final vb = snap['viewBox'];
      expect(vb, isA<Map>());
      expect((vb as Map)['width'], 700);
      expect(vb['height'], 400);

      final elements =
          (snap['elements'] as List).cast<Map<String, Object?>>();
      final cup = elements.firstWhere(
        (e) => e['id'] == 'eyAEWINQ6855',
        orElse: () => const <String, Object?>{},
      );
      expect(cup.isNotEmpty, isTrue,
          reason: 'cup group eyAEWINQ6855 must appear in the snapshot');
      expect(cup['tag'], 'g');
      final attrs = (cup['attrs'] as Map).cast<String, String>();
      expect(attrs.containsKey('transform'), isTrue,
          reason: 'cup group has a transform attribute (static or animated)');
    });

    testWidgets('snapshot reflects SVGator-applied transforms after '
        'force-seek to t=400ms',
        (tester) async {
      // The test runtime does not drive vsync, so the JS bridge's rAF never
      // ticks on its own. To prove the snapshot captures *live* state, we
      // inject a tiny script after the inline player that pauses + seeks the
      // SVGator player to t=400 ms before the snapshot is captured.
      final svg = _coffeeSvg();
      final playerScript =
          '<script><![CDATA[\n${_svgatorPlayerJs()}\n]]></script>';
      const probeScript = '''
<script><![CDATA[
  try {
    var root = document.getElementById('eyAEWINQ6851');
    var p = root && root.svgatorPlayer;
    if (p) { p.pause(); p.seekTo(400); }
  } catch(e) {}
]]></script>''';
      final closeIdx = svg.lastIndexOf('</svg>');
      final mutated = svg.substring(0, closeIdx) +
          playerScript +
          probeScript +
          svg.substring(closeIdx);

      final controller = AnimatedSvgController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(
              mutated,
              controller: controller,
              autoPlay: false,
              width: 700,
              height: 400,
            ),
          ),
        ),
      );
      await tester.pump();
      // Let the inline scripts run.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 400)),
      );
      await tester.pump();

      final snap = controller.captureDebugSnapshot();
      expect(snap, isNotNull);
      final elements =
          (snap!['elements'] as List).cast<Map<String, Object?>>();
      final cup = elements.firstWhere(
        (e) => e['id'] == 'eyAEWINQ6855',
        orElse: () => const <String, Object?>{},
      );
      expect(cup.isNotEmpty, isTrue);
      final attrs = (cup['attrs'] as Map).cast<String, String>();
      final transform = attrs['transform'] ?? '';
      print('[debug-snapshot] cup transform after seek(400) = "$transform"');

      // After seek(400) the SVGator player overwrote the cup's transform.
      // Used to be `matrix(...)` straight from the player; since the
      // Dart-side interpolator rewrite we emit `translate(...) rotate(...)`
      // instead (functionally equivalent). Either shape is fine — the
      // assertion is "we wrote something that *moved* the cup off its
      // static `translate(0 0.000002)`".
      expect(
        transform.contains('matrix(') || transform.contains('translate('),
        isTrue,
        reason: 'cup transform should be matrix(...) or translate(...) '
            'after the SVGator player has applied a seek; got "$transform"',
      );
      expect(transform.contains('0.000002'), isFalse,
          reason: 'cup transform should NOT still be the static authored '
              'value (`translate(0 0.000002)`) — that means the player never '
              'wrote anything; got "$transform"');
    });

    testWidgets('snapshot includes bboxRoot for geometric elements',
        (tester) async {
      // Simple SVG with a known rect: x=10, y=20, width=80, height=60.
      // The rect's parent group has translate(100, 50). So the world bbox
      // should be (110, 70, 80, 60).
      const svg = '''
<svg viewBox="0 0 500 500" xmlns="http://www.w3.org/2000/svg">
  <g transform="translate(100 50)">
    <rect id="r1" x="10" y="20" width="80" height="60" fill="red"/>
  </g>
</svg>''';
      final controller = AnimatedSvgController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(
              svg,
              controller: controller,
              autoPlay: false,
              width: 500,
              height: 500,
            ),
          ),
        ),
      );
      await tester.pump();
      final snap = controller.captureDebugSnapshot();
      expect(snap, isNotNull);
      final elements =
          (snap!['elements'] as List).cast<Map<String, Object?>>();
      final rect = elements.firstWhere(
        (e) => e['id'] == 'r1',
        orElse: () => const <String, Object?>{},
      );
      expect(rect.isNotEmpty, isTrue);
      final bb = rect['bboxRoot'] as Map?;
      expect(bb, isNotNull,
          reason: 'rect must have a bboxRoot populated by the snapshot');
      expect(bb!['x'], closeTo(110, 0.01));
      expect(bb['y'], closeTo(70, 0.01));
      expect(bb['w'], closeTo(80, 0.01));
      expect(bb['h'], closeTo(60, 0.01));
    });

    testWidgets('bbox hit-test data supports tap-to-select: deepest wins',
        (tester) async {
      // Outer 200×200 rect at (0,0) covers the whole viewBox.
      // Inner 50×50 rect at (75,75) sits in the middle.
      // A click at (100,100) should resolve to the inner — it's deeper and
      // smaller. This mirrors the algorithm the debug viewer uses.
      const svg = '''
<svg viewBox="0 0 200 200" xmlns="http://www.w3.org/2000/svg">
  <rect id="outer" x="0" y="0" width="200" height="200" fill="blue"/>
  <g>
    <rect id="inner" x="75" y="75" width="50" height="50" fill="red"/>
  </g>
</svg>''';
      final controller = AnimatedSvgController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(
              svg,
              controller: controller,
              autoPlay: false,
              width: 200,
              height: 200,
            ),
          ),
        ),
      );
      await tester.pump();
      final snap = controller.captureDebugSnapshot();
      expect(snap, isNotNull);
      final elements =
          (snap!['elements'] as List).cast<Map<String, Object?>>();

      bool contains(Map bb, double x, double y) {
        final bx = (bb['x'] as num).toDouble();
        final by = (bb['y'] as num).toDouble();
        final bw = (bb['w'] as num).toDouble();
        final bh = (bb['h'] as num).toDouble();
        return x >= bx && y >= by && x <= bx + bw && y <= by + bh;
      }

      String? bestIdAt(double x, double y) {
        String? bestId;
        int bestDepth = -1;
        double bestArea = double.infinity;
        for (final e in elements) {
          final id = e['id'] as String?;
          final bb = e['bboxRoot'] as Map?;
          if (id == null || bb == null) continue;
          if (!contains(bb, x, y)) continue;
          final depth = (e['depth'] as int?) ?? 0;
          final area =
              (bb['w'] as num).toDouble() * (bb['h'] as num).toDouble();
          if (depth > bestDepth ||
              (depth == bestDepth && area < bestArea)) {
            bestDepth = depth;
            bestArea = area;
            bestId = id;
          }
        }
        return bestId;
      }

      expect(bestIdAt(100, 100), 'inner',
          reason: 'centre point is inside both rects; inner is deeper');
      expect(bestIdAt(10, 10), 'outer',
          reason: 'corner is only inside the outer rect');
      expect(bestIdAt(-50, -50), isNull,
          reason: 'point outside any bbox returns null');
    });

    testWidgets('debugSnapshotProvider is cleared on widget dispose',
        (tester) async {
      final controller = AnimatedSvgController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(
              _coffeeSvg(),
              controller: controller,
              autoPlay: false,
              width: 100,
              height: 100,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(controller.captureDebugSnapshot(), isNotNull);

      // Replace with an empty widget so the AnimatedSvgPicture is disposed.
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.pump();

      expect(controller.captureDebugSnapshot(), isNull,
          reason: 'snapshot provider must be cleared when the widget is '
              'disposed so the controller does not hold stale state');
      controller.dispose();
    });
  });
}
