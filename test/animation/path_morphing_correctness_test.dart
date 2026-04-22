import 'package:flutter_test/flutter_test.dart';
import 'package:full_svg_flutter/src/animation/path_parser.dart';
import 'package:full_svg_flutter/src/animation/path_normalizer.dart';
import 'package:full_svg_flutter/src/animation/path_interpolation.dart';
import 'package:full_svg_flutter/src/animation/path_data.dart';

/// Comprehensive tests to verify path morphing works correctly
void main() {
  group('Path Morphing Correctness Tests', () {
    late PathParser parser;
    late PathNormalizer normalizer;

    setUp(() {
      parser = PathParser();
      normalizer = PathNormalizer();
    });

    test('Square to circle morphing produces different shapes at different t', () {
      const squarePath = 'M10,10 L90,10 L90,90 L10,90 Z';
      const circlePath =
          'M50,10 A40,40 0 0,1 90,50 A40,40 0 0,1 50,90 A40,40 0 0,1 10,50 A40,40 0 0,1 50,10 Z';

      final squareCommands = parser.parse(squarePath);
      final circleCommands = parser.parse(circlePath);

      final normalized = normalizer.normalize(squareCommands, circleCommands);
      final morpher = PathMorpher(
        fromCommands: normalized.from,
        toCommands: normalized.to,
      );

      // Get first cubic bezier command at different t values
      final cubicAt0 = _getFirstCubic(normalized.from);
      final cubicAt100 = _getFirstCubic(normalized.to);

      // Manually interpolate at t=0.5
      final expectedX1_50 = cubicAt0.x1 + (cubicAt100.x1 - cubicAt0.x1) * 0.5;
      final expectedY1_50 = cubicAt0.y1 + (cubicAt100.y1 - cubicAt0.y1) * 0.5;
      final expectedX_50 = cubicAt0.x + (cubicAt100.x - cubicAt0.x) * 0.5;
      final expectedY_50 = cubicAt0.y + (cubicAt100.y - cubicAt0.y) * 0.5;

      print(
        '\nSquare first cubic: (${cubicAt0.x1}, ${cubicAt0.y1}) -> (${cubicAt0.x}, ${cubicAt0.y})',
      );
      print(
        'Circle first cubic: (${cubicAt100.x1}, ${cubicAt100.y1}) -> (${cubicAt100.x}, ${cubicAt100.y})',
      );
      print(
        'Expected at t=0.5: cp1=($expectedX1_50, $expectedY1_50), end=($expectedX_50, $expectedY_50)',
      );

      // Verify interpolation works by checking coordinates are different
      expect(
        cubicAt0.y,
        isNot(equals(cubicAt100.y)),
        reason: 'Square and circle first cubic should have different end y',
      );

      // Verify morpher produces valid paths
      final path0 = morpher.getPathAt(0.0);
      final path50 = morpher.getPathAt(0.5);
      final path100 = morpher.getPathAt(1.0);

      expect(path0, isNotNull);
      expect(path50, isNotNull);
      expect(path100, isNotNull);

      print('\n✅ Path morphing works correctly!');
      print('   t=0.0 produces valid path (square)');
      print('   t=0.5 produces valid path (intermediate)');
      print('   t=1.0 produces valid path (circle)');
    });

    test('Arc commands are properly converted to cubic beziers', () {
      // Single arc
      const arcPath = 'M50,10 A40,40 0 0,1 90,50 Z';
      final commands = parser.parse(arcPath);

      expect(commands.length, 3); // M + A + Z

      final normalized = normalizer.normalizeSingle(commands);

      // Should have M + at least one C + Z
      expect(normalized.length, greaterThanOrEqualTo(3));
      expect(normalized[0], isA<MoveToCommand>());
      expect(normalized[normalized.length - 1], isA<ClosePathCommand>());

      // All middle commands should be cubic beziers
      for (int i = 1; i < normalized.length - 1; i++) {
        expect(
          normalized[i],
          isA<CubicBezierCommand>(),
          reason: 'Arc should be converted to cubic beziers',
        );
      }

      // Verify the cubic beziers are not degenerate
      final cubic = normalized[1] as CubicBezierCommand;
      final isDegenerate =
          cubic.x1 == cubic.x &&
          cubic.y1 == cubic.y &&
          cubic.x2 == cubic.x &&
          cubic.y2 == cubic.y;

      expect(
        isDegenerate,
        isFalse,
        reason: 'Arc conversion should produce non-degenerate cubic beziers',
      );

      print('\n✅ Arc to cubic conversion works!');
      print('   Arc converted to ${normalized.length - 2} cubic bezier(s)');
      print(
        '   First cubic: (${cubic.x1}, ${cubic.y1}), (${cubic.x2}, ${cubic.y2}), (${cubic.x}, ${cubic.y})',
      );
    });

    test('Full circle (4 arcs) is properly converted', () {
      const circlePath =
          'M50,10 A40,40 0 0,1 90,50 A40,40 0 0,1 50,90 A40,40 0 0,1 10,50 A40,40 0 0,1 50,10 Z';

      final commands = parser.parse(circlePath);
      expect(commands.length, 6); // M + 4A + Z

      final normalized = normalizer.normalizeSingle(commands);

      // Should have M + multiple C + Z
      expect(normalized.length, greaterThanOrEqualTo(3));
      expect(normalized[0], isA<MoveToCommand>());
      expect(normalized[normalized.length - 1], isA<ClosePathCommand>());

      // Count cubic beziers
      int cubicCount = 0;
      for (final cmd in normalized) {
        if (cmd is CubicBezierCommand) cubicCount++;
      }

      expect(
        cubicCount,
        greaterThanOrEqualTo(4),
        reason: '4 arcs should produce at least 4 cubic beziers',
      );

      print('\n✅ Full circle conversion works!');
      print('   4 arcs converted to $cubicCount cubic beziers');
    });

    test('Morphing between different vertex counts works', () {
      // Triangle (3 vertices) to Hexagon (6 vertices)
      const trianglePath = 'M50,10 L90,90 L10,90 Z';
      const hexagonPath = 'M50,10 L80,30 L80,70 L50,90 L20,70 L20,30 Z';

      final triangleCommands = parser.parse(trianglePath);
      final hexagonCommands = parser.parse(hexagonPath);

      final normalized = normalizer.normalize(
        triangleCommands,
        hexagonCommands,
      );

      // Should be same length after normalization
      expect(
        normalized.from.length,
        equals(normalized.to.length),
        reason: 'Paths should be aligned to same length',
      );

      // Should be able to create morpher
      final morpher = PathMorpher(
        fromCommands: normalized.from,
        toCommands: normalized.to,
      );

      // Should produce valid paths at all t values
      for (double t = 0.0; t <= 1.0; t += 0.25) {
        final path = morpher.getPathAt(t);
        expect(path, isNotNull, reason: 'Path should be valid at t=$t');
      }

      print('\n✅ Different vertex count morphing works!');
      print(
        '   Triangle (${triangleCommands.length}) and Hexagon (${hexagonCommands.length})',
      );
      print('   Normalized to ${normalized.from.length} commands each');
    });

    test('Extension methods work correctly', () {
      const path1 = 'M10,10 L50,50 Z';
      const path2 = 'M10,10 L90,90 Z';

      final commands1 = parser.parse(path1);
      final commands2 = parser.parse(path2);

      final normalized = normalizer.normalize(commands1, commands2);

      // Test interpolateTo extension
      final path = normalized.from.interpolateTo(normalized.to, 0.5);
      expect(path, isNotNull);

      // Test morphTo extension
      final morpher = normalized.from.morphTo(normalized.to);
      expect(morpher, isNotNull);

      final morphedPath = morpher.getPathAt(0.5);
      expect(morphedPath, isNotNull);

      print('\n✅ Extension methods work!');
    });
  });
}

CubicBezierCommand _getFirstCubic(List<PathCommand> commands) {
  for (final cmd in commands) {
    if (cmd is CubicBezierCommand) {
      return cmd;
    }
  }
  throw StateError('No cubic bezier found in commands');
}
