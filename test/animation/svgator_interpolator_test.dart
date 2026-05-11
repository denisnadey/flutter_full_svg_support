// ignore_for_file: avoid_print
/// Cross-check our Dart-side SVGator interpolator against the real
/// browser output captured from a Chrome SVGator player probe.
///
/// The reference values below come from `/tmp/gummies_probe_final.html`
/// where we logged `heart.getAttribute('transform')` after `seekTo(t)` at
/// several times. Our Dart computation should match those translations to
/// fractions of a pixel.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:full_svg_flutter/src/animation/svgator_interpolator.dart';

void main() {
  // ── Gummies heart `egCFBHozAYS3` keyframes (taken verbatim from
  // glowing-gummies-graphic-art-animation.svg) ────────────────────────────
  //
  // data.t = (-231.892831, -167.837275)
  // keys.o[0..12] with easing per segment
  //
  // The browser produced (from gummies_probe_final.html, real Chrome):
  //   t=    0 ms  → translate(-31.73568,   -10.375001)
  //   t=  500 ms  → translate(-31.739629,   -7.150352)
  //   t= 1000 ms  → translate(-31.743352,   -4.110934)
  //   t= 1500 ms  → translate(-31.767811,   -8.00924)
  //   t= 1559 ms  → translate(-31.767526,   -7.973399)
  //   t= 1750 ms  → translate(-31.763543,   -7.489832)
  //   t= 2000 ms  → translate(-31.74952,    -6.017313)
  //   t= 2400 ms  → translate(-31.725915,   -4.762186)
  //   t= 3100 ms  → translate(-31.743352,   -7.965091)
  //   t= 3600 ms  → translate(-31.743352,  65.445215)
  //   t= 4100 ms  → translate(-31.404024, -96.063019)

  group('SVGator interpolator — Gummies heart parity vs real Chrome', () {
    late SvgatorTransformTrack track;

    setUp(() {
      final json = <String, dynamic>{
        'data': {
          't': {'x': -231.892831, 'y': -167.837275}
        },
        'keys': {
          'o': [
            {
              't': 0,
              'v': {'x': 200.157151, 'y': 157.462274, 'type': 'corner'},
              'e': [0.455, 0.03, 0.515, 0.955]
            },
            {
              't': 1000,
              'v': {'x': 200.149479, 'y': 163.726341, 'type': 'corner'},
              'e': [0.175, 0.885, 0.32, 1.275]
            },
            {
              't': 1500,
              'v': {
                'x': 200.12502,
                'y': 159.828035,
                'type': 'corner',
                'start': {'x': 200.12502, 'y': 159.828035},
                'end': {'x': 200.12502, 'y': 159.828035}
              },
              'e': [0.455, 0.03, 0.515, 0.955]
            },
            {
              't': 2400,
              'v': {
                'x': 200.166917,
                'y': 163.075087,
                'type': 'cusp',
                'start': {'x': 200.145968, 'y': 162.677062},
                'end': {'x': 200.142776, 'y': 163.045047}
              }
            },
            {
              't': 2500,
              'v': {
                'x': 200.149479,
                'y': 163.726341,
                'type': 'corner',
                'start': {'x': 200.149479, 'y': 163.726341},
                'end': {'x': 200.149479, 'y': 163.726341}
              },
              'e': [0.455, 0.03, 0.515, 0.955]
            },
            {
              't': 3100,
              'v': {'x': 200.149479, 'y': 159.872184, 'type': 'corner'},
              'e': [0.455, 0.03, 0.515, 0.955]
            },
            {
              't': 3600,
              'v': {'x': 200.149479, 'y': 233.28249, 'type': 'corner'},
              'e': [0.455, 0.03, 0.515, 0.955]
            },
            {
              't': 4100,
              'v': {'x': 200.488807, 'y': 71.774256, 'type': 'corner'},
              'e': [0.455, 0.03, 0.515, 0.955]
            },
            {
              't': 5100,
              'v': {'x': 200.149479, 'y': 233.28249, 'type': 'corner'},
              'e': [0.455, 0.03, 0.515, 0.955]
            },
            {
              't': 6100,
              'v': {'x': 200.488807, 'y': 71.610219, 'type': 'corner'},
              'e': [0.455, 0.03, 0.515, 0.955]
            },
            {
              't': 7100,
              'v': {'x': 200.14948, 'y': 159.015016, 'type': 'corner'},
              'e': [0.455, 0.03, 0.515, 0.955]
            },
            {
              't': 8000,
              'v': {'x': 200.14948, 'y': 161.905634, 'type': 'corner'},
              'e': [0.455, 0.03, 0.515, 0.955]
            },
            {
              't': 8900,
              'v': {'x': 200.157151, 'y': 157.462274, 'type': 'corner'},
              'e': [0.455, 0.03, 0.515, 0.955]
            }
          ]
        }
      };
      final parsed = parseSvgatorElement('egCFBHozAYS3', {'transform': json});
      track = parsed!.transform!;
    });

    void expectMatch(double timeMs, double expectedX, double expectedY,
        {double tolerance = 1.0}) {
      final str = track.transformAt(timeMs);
      final m = RegExp(r'translate\((-?\d+\.?\d*),\s*(-?\d+\.?\d*)\)')
          .firstMatch(str);
      expect(m, isNotNull,
          reason: 't=$timeMs returned "$str" — no translate match');
      final tx = double.parse(m!.group(1)!);
      final ty = double.parse(m.group(2)!);
      print('  t=${timeMs.toStringAsFixed(0).padLeft(5)} '
          'expected=(${expectedX.toStringAsFixed(3)}, '
          '${expectedY.toStringAsFixed(3)})  '
          'actual=(${tx.toStringAsFixed(3)}, ${ty.toStringAsFixed(3)})');
      expect((tx - expectedX).abs(), lessThan(tolerance),
          reason: 't=$timeMs: x off by ${(tx - expectedX).abs()}');
      expect((ty - expectedY).abs(), lessThan(tolerance),
          reason: 't=$timeMs: y off by ${(ty - expectedY).abs()}');
    }

    test('matches real Chrome output within ±1 px', () {
      print('Gummies heart — Dart interpolator vs Chrome reference:');
      expectMatch(0, -31.73568, -10.375001);
      expectMatch(500, -31.739629, -7.150352);
      expectMatch(1000, -31.743352, -4.110934);
      expectMatch(1500, -31.767811, -8.00924);
      // The broken-window samples — these are where our QuickJS player
      // wrote `data.t` (i.e. (-231.89, -167.84)). The browser was correct.
      // Our Dart interpolator MUST match the browser here.
      expectMatch(1559, -31.767526, -7.973399);
      expectMatch(1750, -31.763543, -7.489832);
      expectMatch(2000, -31.74952, -6.017313);
      expectMatch(2400, -31.725915, -4.762186);
      expectMatch(3100, -31.743352, -7.965091);
      expectMatch(3600, -31.743352, 65.445215);
      expectMatch(4100, -31.404024, -96.063019);
    });
  });
}
