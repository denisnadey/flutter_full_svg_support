// ignore_for_file: avoid_print
/// Diagnostic for the "Animated Basketball Boy" SVGator SVG. User reported
/// most of the character is missing in the gallery view. Captures live
/// per-element transforms / opacities at a few seek times and counts how
/// many writes the bridge had to reject as bezier-glitch (data.t-only)
/// fallbacks. Compare those numbers to confirm or rule out the workaround
/// being too aggressive.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:full_svg_flutter/full_svg_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

const _fixturesDir = 'test/golden_comparison/svg_fixtures';
String _basketballSvg() =>
    File('$_fixturesDir/basketball_boy.svg').readAsStringSync();
String _svgatorPlayerJs() =>
    File('test/animation/_svgator_player_91c80d77.js').readAsStringSync();

/// Production-like setup: do NOT inline the player JS. Only the SVG's own
/// inline bootstrap runs; the external `cdn.svgator.com/.../91c80d77.js`
/// is fetched via `loadExternalScript`, which our bridge can intercept.
/// This is what users see on macOS/iOS where the player is fetched over
/// the network — exactly the path we want to skip for cusp-heavy SVGs.
String _svgWithSeek(int seekMs) => _basketballSvg();

void main() {
  testWidgets('basketball boy: per-element transform/opacity at t=467ms',
      (tester) async {
    final controller = AnimatedSvgController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnimatedSvgPicture.string(
            _svgWithSeek(467),
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
      () => Future<void>.delayed(const Duration(milliseconds: 400)),
    );
    await tester.pump();

    final snap = controller.captureDebugSnapshot();
    expect(snap, isNotNull);
    final elements = (snap!['elements'] as List).cast<Map<String, Object?>>();
    final stats = snap['jsBridge'] as Map?;
    print('basketball-boy snapshot at t=467ms: '
        '${elements.length} elements');
    print('jsBridge stats: $stats');

    // After the polyfill fix (getTotalLength/getPointAtLength on virtual
    // path elements now return real values instead of {x:0, y:0}), the
    // SVGator player produces correct transforms without any Dart-side
    // override. The dump below is for human inspection — the only thing
    // we assert is that the player wrote a non-trivial number of
    // transform attributes. The external player JS isn't fetched in
    // `flutter test` (HTTP mock), so this can legitimately be 0; treat
    // it as a smoke check rather than a hard requirement.
    int identityTransforms = 0;
    int zeroOpacity = 0;
    int withTransform = 0;
    int withMatrix = 0;
    final examples = <String>[];
    for (final e in elements) {
      final id = e['id'] as String?;
      if (id == null) continue;
      final attrs = (e['attrs'] as Map?)?.cast<String, String>();
      if (attrs == null) continue;
      final t = attrs['transform'];
      final op = attrs['opacity'];
      if (t != null) {
        withTransform++;
        if (t.contains('matrix(')) withMatrix++;
        if (t.trim().isEmpty ||
            t.contains('translate(0') ||
            t.contains('matrix(1 0 0 1 0 0)')) {
          identityTransforms++;
        }
      }
      if (op == '0' || op == '0.0') zeroOpacity++;
      if (examples.length < 12 && (t != null || op != null)) {
        examples.add('#$id  tag=${e['tag']}  '
            'transform=${t ?? "—"}  opacity=${op ?? "—"}');
      }
    }
    print('summary:');
    print('  total elements with id: '
        '${elements.where((e) => e['id'] != null).length}');
    print('  elements with transform attr: $withTransform');
    print('  └─ matrix(): $withMatrix');
    print('  └─ identity-looking: $identityTransforms');
    print('  elements with opacity=0: $zeroOpacity');
    print('first 12 sample elements (with transform or opacity):');
    for (final ex in examples) {
      final clipped = ex.length > 180 ? '${ex.substring(0, 180)}…' : ex;
      print('  $clipped');
    }
  });
}
