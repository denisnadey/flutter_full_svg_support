import 'package:flutter_test/flutter_test.dart';
import 'package:full_svg_flutter/src/animation/path_parser.dart';
import 'package:full_svg_flutter/src/animation/path_normalizer.dart';
import 'package:full_svg_flutter/src/animation/path_data.dart';
import 'package:full_svg_flutter/src/animation/path_interpolation.dart';

/// Debug test for square-to-circle morphing
void main() {
  test('Debug square to circle normalization', () {
    final parser = PathParser();
    final normalizer = PathNormalizer();

    const squarePath = 'M10,10 L90,10 L90,90 L10,90 Z';
    const circlePath =
        'M50,10 A40,40 0 0,1 90,50 A40,40 0 0,1 50,90 A40,40 0 0,1 10,50 A40,40 0 0,1 50,10 Z';

    print('\n=== Parsing paths ===');
    final squareCommands = parser.parse(squarePath);
    final circleCommands = parser.parse(circlePath);

    print('Square: ${squareCommands.length} commands');
    print('Circle: ${circleCommands.length} commands');

    print('\n=== Normalizing square ===');
    final normSquare = normalizer.normalizeSingle(squareCommands);
    print('Normalized square: ${normSquare.length} commands');
    for (int i = 0; i < normSquare.length; i++) {
      final cmd = normSquare[i];
      if (cmd is CubicBezierCommand) {
        print(
          '  [$i] C (${cmd.x1}, ${cmd.y1}), (${cmd.x2}, ${cmd.y2}), (${cmd.x}, ${cmd.y})',
        );
      } else {
        print('  [$i] ${cmd.type}');
      }
    }

    print('\n=== Normalizing circle ===');
    final normCircle = normalizer.normalizeSingle(circleCommands);
    print('Normalized circle: ${normCircle.length} commands');
    for (int i = 0; i < normCircle.length; i++) {
      final cmd = normCircle[i];
      if (cmd is CubicBezierCommand) {
        print(
          '  [$i] C (${cmd.x1}, ${cmd.y1}), (${cmd.x2}, ${cmd.y2}), (${cmd.x}, ${cmd.y})',
        );
      } else {
        print('  [$i] ${cmd.type}');
      }
    }

    print('\n=== Normalizing pair ===');
    final normalized = normalizer.normalize(squareCommands, circleCommands);

    print('From (square): ${normalized.from.length} commands');
    for (int i = 0; i < normalized.from.length; i++) {
      final cmd = normalized.from[i];
      if (cmd is CubicBezierCommand) {
        print(
          '  [$i] C (${cmd.x1}, ${cmd.y1}), (${cmd.x2}, ${cmd.y2}), (${cmd.x}, ${cmd.y})',
        );
      } else {
        print('  [$i] ${cmd.type}');
      }
    }

    print('\nTo (circle): ${normalized.to.length} commands');
    for (int i = 0; i < normalized.to.length; i++) {
      final cmd = normalized.to[i];
      if (cmd is CubicBezierCommand) {
        print(
          '  [$i] C (${cmd.x1}, ${cmd.y1}), (${cmd.x2}, ${cmd.y2}), (${cmd.x}, ${cmd.y})',
        );
      } else {
        print('  [$i] ${cmd.type}');
      }
    }

    print('\n=== Testing interpolation ===');
    final interpolator = PathInterpolator();

    final path0 = interpolator.interpolate(normalized.from, normalized.to, 0.0);
    final path05 = interpolator.interpolate(
      normalized.from,
      normalized.to,
      0.5,
    );
    final path1 = interpolator.interpolate(normalized.from, normalized.to, 1.0);

    print('t=0.0: ${path0.getBounds()}');
    print('t=0.5: ${path05.getBounds()}');
    print('t=1.0: ${path1.getBounds()}');

    print('\n=== Analyzing first cubic at different t values ===');
    if (normalized.from.length > 1 && normalized.to.length > 1) {
      final fromCubic = normalized.from[1] as CubicBezierCommand;
      final toCubic = normalized.to[1] as CubicBezierCommand;

      print(
        'From cubic: (${fromCubic.x1}, ${fromCubic.y1}), (${fromCubic.x2}, ${fromCubic.y2}), (${fromCubic.x}, ${fromCubic.y})',
      );
      print(
        'To cubic: (${toCubic.x1}, ${toCubic.y1}), (${toCubic.x2}, ${toCubic.y2}), (${toCubic.x}, ${toCubic.y})',
      );

      // Manual interpolation
      final x1_05 = fromCubic.x1 + (toCubic.x1 - fromCubic.x1) * 0.5;
      final y1_05 = fromCubic.y1 + (toCubic.y1 - fromCubic.y1) * 0.5;
      print('Expected at t=0.5: x1=$x1_05, y1=$y1_05');
    }
  });
}
