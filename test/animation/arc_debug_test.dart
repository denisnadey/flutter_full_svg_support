import 'package:flutter_test/flutter_test.dart';
import 'package:full_svg_flutter/src/animation/path_parser.dart';
import 'package:full_svg_flutter/src/animation/path_normalizer.dart';
import 'package:full_svg_flutter/src/animation/path_data.dart';

/// Debug test to understand what's happening with arc conversion
void main() {
  test('Debug arc to cubic conversion', () {
    final parser = PathParser();
    final normalizer = PathNormalizer();

    const circlePath =
        'M50,10 A40,40 0 0,1 90,50 A40,40 0 0,1 50,90 A40,40 0 0,1 10,50 A40,40 0 0,1 50,10 Z';

    print('\n=== Parsing circle path ===');
    final circleCommands = parser.parse(circlePath);

    print('Parsed ${circleCommands.length} commands:');
    for (int i = 0; i < circleCommands.length; i++) {
      final cmd = circleCommands[i];
      print('  [$i] ${cmd.type}: ${cmd.params}');
    }

    print('\n=== Normalizing circle ===');
    final normalized = normalizer.normalizeSingle(circleCommands);

    print('Normalized to ${normalized.length} commands:');
    for (int i = 0; i < normalized.length; i++) {
      final cmd = normalized[i];
      if (cmd is MoveToCommand) {
        print('  [$i] M ${cmd.x}, ${cmd.y}');
      } else if (cmd is CubicBezierCommand) {
        print(
          '  [$i] C ${cmd.x1}, ${cmd.y1}, ${cmd.x2}, ${cmd.y2}, ${cmd.x}, ${cmd.y}',
        );
      } else if (cmd is ClosePathCommand) {
        print('  [$i] Z');
      } else {
        print('  [$i] ${cmd.type}: ${cmd.params}');
      }
    }

    // Check if cubic beziers are actually different
    print('\n=== Checking cubic bezier variety ===');
    final cubics = normalized.whereType<CubicBezierCommand>().toList();
    print('Found ${cubics.length} cubic bezier commands');

    if (cubics.length >= 2) {
      final first = cubics[0];
      final second = cubics[1];

      print(
        'First cubic: (${first.x1}, ${first.y1}), (${first.x2}, ${first.y2}), (${first.x}, ${first.y})',
      );
      print(
        'Second cubic: (${second.x1}, ${second.y1}), (${second.x2}, ${second.y2}), (${second.x}, ${second.y})',
      );

      final isDifferent =
          first.x1 != second.x1 ||
          first.y1 != second.y1 ||
          first.x2 != second.x2 ||
          first.y2 != second.y2 ||
          first.x != second.x ||
          first.y != second.y;

      print('Cubics are different: $isDifferent');
    }
  });
}
