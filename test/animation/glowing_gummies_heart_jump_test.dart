// ignore_for_file: avoid_print
/// Repro / diagnostic for the "Glowing Gummies" SVG where the gummy heart
/// (group id `egCFBHozAYS3`) jumps upward off the visible card.
///
/// Reported state at t=1559 ms (from a debug-viewer JSON dump):
///   live transform = `translate(-231.892831 -167.837275)`
///   This is **exactly** the SVGator data.t offset for that element.
///   The expected formula is `translate = data.t + key.o`, so a "data.t
///   only" output implies key.o = (0,0) — i.e. the player did not apply a
///   keyframe origin at all.
///
/// This test scrubs through a range of seek times to characterise where the
/// bug occurs. For each time we expect:
///   t=0       → translate = (-31.736, -10.375)   (static = data.t + o[0])
///   t=3600    → translate = (-31.74,   65.45)    (gummy bouncing down)
///   t=4100    → translate = (-31.40,  -96.06)    (gummy peak high)
///   t=8900    → translate = (-31.74, -10.38)     (return to start)
///
/// If at *any* probed time the player writes `translate(-231.89, -167.84)`
/// instead, the keyframe origin lookup is broken.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:full_svg_flutter/full_svg_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

const _fixturesDir = 'test/golden_comparison/svg_fixtures';
String _gummiesSvg() =>
    File('$_fixturesDir/glowing_gummies_full.svg').readAsStringSync();
String _svgatorPlayerJs() =>
    File('test/animation/_svgator_player_91c80d77.js').readAsStringSync();

/// Inlines the player JS + an inline probe that pauses the player and seeks
/// to a specific time before the snapshot is read.
String _svgWithSeek(int seekMs) {
  final svg = _gummiesSvg();
  final playerScript =
      '<script><![CDATA[\n${_svgatorPlayerJs()}\n]]></script>';
  final probe = '''
<script><![CDATA[
  try {
    var roots = document.querySelectorAll('svg');
    for (var i = 0; i < roots.length; i++) {
      var p = roots[i].svgatorPlayer;
      if (p && typeof p.pause === 'function') { try { p.pause(); } catch(e) {} }
      if (p && typeof p.seekTo === 'function') { try { p.seekTo($seekMs); } catch(e) {} }
    }
  } catch(e) {}
]]></script>''';
  final idx = svg.lastIndexOf('</svg>');
  return svg.substring(0, idx) + playerScript + probe + svg.substring(idx);
}

void main() {
  testWidgets('heart transform trajectory (egCFBHozAYS3) — log only',
      (tester) async {
    final times = [0, 250, 500, 1000, 1500, 1559, 2000, 3100, 3600, 4100, 5100,
                  6100, 7100, 8000, 8900];

    print('time(ms)  | live transform (egCFBHozAYS3)');
    print('----------+---------------------------------------------------');
    for (final t in times) {
      final controller = AnimatedSvgController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(
              _svgWithSeek(t),
              controller: controller,
              autoPlay: false,
              width: 700,
              height: 400,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await tester.pump();

      final snap = controller.captureDebugSnapshot();
      final elements = (snap?['elements'] as List?)
              ?.cast<Map<String, Object?>>() ??
          const <Map<String, Object?>>[];
      final heart = elements.firstWhere(
        (e) => e['id'] == 'egCFBHozAYS3',
        orElse: () => const <String, Object?>{},
      );
      final transform =
          (heart['attrs'] as Map?)?.cast<String, String>()['transform'] ?? '?';
      print('${t.toString().padLeft(7)}  | $transform');

      // Tear down for next iteration.
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    }
  });

  testWidgets('SVGator bezier-glitch workaround: heart never gets a '
      'data.t-only transform across the broken keyframe segment',
      (tester) async {
    // Probe the entire broken window (1500..2400 ms in steps of 50ms) and
    // assert the heart's transform is never the bare data.t fallback.
    final controller = AnimatedSvgController();
    for (int t = 1500; t <= 2400; t += 50) {
      final svg = _gummiesSvg();
      final playerScript =
          '<script><![CDATA[\n${_svgatorPlayerJs()}\n]]></script>';
      final probe = '''
<script><![CDATA[
  try {
    var roots = document.querySelectorAll('svg');
    for (var i = 0; i < roots.length; i++) {
      var p = roots[i].svgatorPlayer;
      if (p) { try { p.pause(); } catch(e) {} try { p.seekTo($t); } catch(e) {} }
    }
  } catch(e) {}
]]></script>''';
      final idx = svg.lastIndexOf('</svg>');
      final mutated = svg.substring(0, idx) + playerScript + probe +
          svg.substring(idx);

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
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 250)),
      );
      await tester.pump();

      final snap = controller.captureDebugSnapshot();
      final elements = (snap?['elements'] as List?)
              ?.cast<Map<String, Object?>>() ??
          const <Map<String, Object?>>[];
      final heart = elements.firstWhere(
        (e) => e['id'] == 'egCFBHozAYS3',
        orElse: () => const <String, Object?>{},
      );
      final transform =
          (heart['attrs'] as Map?)?.cast<String, String>()['transform'] ??
              '';
      // data.t = (-231.892831, -167.837275). If the workaround failed
      // we'd see this string literally.
      expect(
        transform.contains('-231.89') && transform.contains('-167.83'),
        isFalse,
        reason: 'at t=$t the heart should NOT have a data.t-only '
            'transform; got "$transform"',
      );

      await tester.pumpWidget(const SizedBox.shrink());
    }
    controller.dispose();
  });

  testWidgets('heart transform at t=0 ≈ data.t + key.o[0] (no "data.t only")',
      (tester) async {
    final controller = AnimatedSvgController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnimatedSvgPicture.string(
            _svgWithSeek(0),
            controller: controller,
            autoPlay: false,
            width: 700,
            height: 400,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pump();
    final snap = controller.captureDebugSnapshot();
    final elements = (snap!['elements'] as List).cast<Map<String, Object?>>();
    final heart = elements.firstWhere((e) => e['id'] == 'egCFBHozAYS3');
    final transform =
        (heart['attrs'] as Map).cast<String, String>()['transform']!;
    print('[t=0] heart transform = "$transform"');

    // Expect translate(~-31.7, ~-10.4) — not translate(-231.89, -167.84).
    final match = RegExp(r'translate\(\s*(-?\d+\.?\d*)[\s,]+(-?\d+\.?\d*)\s*\)')
        .firstMatch(transform);
    expect(match, isNotNull,
        reason: 'expected translate(...) at t=0, got "$transform"');
    final tx = double.parse(match!.group(1)!);
    final ty = double.parse(match.group(2)!);
    expect(tx, closeTo(-31.7, 5.0),
        reason: 'expected tx ~ -31.7 (data.t.x + key.o[0].x), got $tx');
    expect(ty, closeTo(-10.4, 5.0),
        reason: 'expected ty ~ -10.4 (data.t.y + key.o[0].y), got $ty');
  });
}
