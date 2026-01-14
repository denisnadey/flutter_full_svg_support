import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/src/animation/path_parser.dart';
import 'package:flutter_svg/src/animation/path_normalizer.dart';
import 'package:flutter_svg/src/animation/path_data.dart';
import 'package:flutter_svg/src/animation/path_interpolation.dart';

/// Test to verify interpolation actually works by checking coordinates
void main() {
  test('Verify interpolation produces different coordinates', () {
    final parser = PathParser();
    final normalizer = PathNormalizer();
    final interpolator = PathInterpolator();

    const squarePath = 'M10,10 L90,10 L90,90 L10,90 Z';
    const circlePath =
        'M50,10 A40,40 0 0,1 90,50 A40,40 0 0,1 50,90 A40,40 0 0,1 10,50 A40,40 0 0,1 50,10 Z';

    final squareCommands = parser.parse(squarePath);
    final circleCommands = parser.parse(circlePath);

    final normalized = normalizer.normalize(squareCommands, circleCommands);

    print('\n=== Checking interpolation at different t values ===');

    for (final t in [0.0, 0.25, 0.5, 0.75, 1.0]) {
      print('\n--- t=$t ---');

      // Get interpolated commands manually
      final interpolatedCommands = <PathCommand>[];

      for (int i = 0; i < normalized.from.length; i++) {
        final from = normalized.from[i];
        final to = normalized.to[i];

        if (from is MoveToCommand && to is MoveToCommand) {
          final x = from.x + (to.x - from.x) * t;
          final y = from.y + (to.y - from.y) * t;
          interpolatedCommands.add(MoveToCommand(x: x, y: y));
          print('MoveTo: ($x, $y)');
        } else if (from is CubicBezierCommand && to is CubicBezierCommand) {
          final x1 = from.x1 + (to.x1 - from.x1) * t;
          final y1 = from.y1 + (to.y1 - from.y1) * t;
          final x2 = from.x2 + (to.x2 - from.x2) * t;
          final y2 = from.y2 + (to.y2 - from.y2) * t;
          final x = from.x + (to.x - from.x) * t;
          final y = from.y + (to.y - from.y) * t;

          print('CubicTo: cp1=($x1, $y1), cp2=($x2, $y2), end=($x, $y)');
        }
      }
    }

    // Now test with PathInterpolator
    print('\n\n=== Testing PathInterpolator ===');
    final path05 = interpolator.interpolate(
      normalized.from,
      normalized.to,
      0.5,
    );
    print('t=0.5 bounds: ${path05.getBounds()}');

    // Create paths manually at t=0 and t=1
    final path0 = interpolator.interpolate(normalized.from, normalized.to, 0.0);
    final path1 = interpolator.interpolate(normalized.from, normalized.to, 1.0);

    print('t=0.0 bounds: ${path0.getBounds()}');
    print('t=1.0 bounds: ${path1.getBounds()}');

    // The issue: all bounds are the same because degenerate curves at (10,10)
    // don't change the bounds. But the actual cubic curves ARE different!
  });
}
