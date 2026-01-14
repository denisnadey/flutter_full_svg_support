import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/src/animation/path_parser.dart';
import 'package:flutter_svg/src/animation/path_normalizer.dart';
import 'package:flutter_svg/src/animation/path_interpolation.dart';
import 'dart:ui' as ui;

/// Integration tests for complete path morphing pipeline
void main() {
  group('Path Morphing Integration Tests', () {
    late PathParser parser;
    late PathNormalizer normalizer;

    setUp(() {
      parser = PathParser();
      normalizer = PathNormalizer();
    });

    group('Square to Circle Morphing', () {
      const squarePath = 'M10,10 L90,10 L90,90 L10,90 Z';
      const circlePath =
          'M50,10 A40,40 0 0,1 90,50 A40,40 0 0,1 50,90 A40,40 0 0,1 10,50 A40,40 0 0,1 50,10 Z';

      test('parses square path correctly', () {
        final commands = parser.parse(squarePath);

        expect(commands.length, 5);
        expect(commands[0].type, 'M');
        expect(commands[1].type, 'L');
        expect(commands[2].type, 'L');
        expect(commands[3].type, 'L');
        expect(commands[4].type, 'Z');
      });

      test('parses circle path correctly', () {
        final commands = parser.parse(circlePath);

        expect(commands.length, 6); // M + 4 arcs + Z
        expect(commands[0].type, 'M');
        expect(commands[1].type, 'A');
        expect(commands[2].type, 'A');
        expect(commands[3].type, 'A');
        expect(commands[4].type, 'A');
        expect(commands[5].type, 'Z');
      });

      test('normalizes square to cubic beziers', () {
        final commands = parser.parse(squarePath);
        final normalized = normalizer.normalizeSingle(commands);

        // Should have: MoveTo + 4 CubicBeziers (one per line segment) + ClosePath
        expect(normalized.length, greaterThanOrEqualTo(2));
        expect(normalized[0].type, 'M');

        // All middle commands should be cubic beziers
        for (int i = 1; i < normalized.length - 1; i++) {
          expect(
            normalized[i].type,
            'C',
            reason: 'Command $i should be cubic bezier',
          );
        }
      });

      test('normalizes circle arcs to cubic beziers', () {
        final commands = parser.parse(circlePath);
        final normalized = normalizer.normalizeSingle(commands);

        expect(normalized.length, greaterThanOrEqualTo(2));
        expect(normalized[0].type, 'M');

        // All middle commands should be cubic beziers
        for (int i = 1; i < normalized.length - 1; i++) {
          expect(
            normalized[i].type,
            'C',
            reason: 'Arc command $i should be converted to cubic bezier',
          );
        }
      });

      test('normalizes square and circle to same length', () {
        final squareCommands = parser.parse(squarePath);
        final circleCommands = parser.parse(circlePath);

        final normalized = normalizer.normalize(squareCommands, circleCommands);

        expect(
          normalized.from.length,
          normalized.to.length,
          reason: 'Normalized paths should have same length',
        );

        // Both should start with MoveTo
        expect(normalized.from[0].type, 'M');
        expect(normalized.to[0].type, 'M');

        print('Normalized square commands: ${normalized.from.length}');
        print('Normalized circle commands: ${normalized.to.length}');

        for (int i = 0; i < normalized.from.length; i++) {
          print(
            '  [$i] Square: ${normalized.from[i].type}, Circle: ${normalized.to[i].type}',
          );
        }
      });

      test('interpolates at t=0 produces square', () {
        final squareCommands = parser.parse(squarePath);
        final circleCommands = parser.parse(circlePath);

        final normalized = normalizer.normalize(squareCommands, circleCommands);
        final interpolator = PathInterpolator();

        final path = interpolator.interpolate(
          normalized.from,
          normalized.to,
          0.0,
        );

        expect(path, isNotNull);
        expect(path, isA<ui.Path>());

        // At t=0, should produce original square
        // Verify by checking path bounds
        final bounds = path.getBounds();
        expect(bounds.left, closeTo(10.0, 0.1));
        expect(bounds.top, closeTo(10.0, 0.1));
        expect(bounds.right, closeTo(90.0, 0.1));
        expect(bounds.bottom, closeTo(90.0, 0.1));
      });

      test('interpolates at t=1 produces circle', () {
        final squareCommands = parser.parse(squarePath);
        final circleCommands = parser.parse(circlePath);

        final normalized = normalizer.normalize(squareCommands, circleCommands);
        final interpolator = PathInterpolator();

        final path = interpolator.interpolate(
          normalized.from,
          normalized.to,
          1.0,
        );

        expect(path, isNotNull);
        expect(path, isA<ui.Path>());

        // At t=1, should produce circle
        final bounds = path.getBounds();

        // Circle should be roughly centered at (50, 50) with radius 40
        expect(bounds.left, closeTo(10.0, 5.0));
        expect(bounds.top, closeTo(10.0, 5.0));
        expect(bounds.right, closeTo(90.0, 5.0));
        expect(bounds.bottom, closeTo(90.0, 5.0));
      });

      test('interpolates at t=0.5 produces intermediate shape', () {
        final squareCommands = parser.parse(squarePath);
        final circleCommands = parser.parse(circlePath);

        final normalized = normalizer.normalize(squareCommands, circleCommands);
        final interpolator = PathInterpolator();

        final path = interpolator.interpolate(
          normalized.from,
          normalized.to,
          0.5,
        );

        expect(path, isNotNull);

        final bounds = path.getBounds();

        // Intermediate shape should still be roughly in same area
        expect(bounds.left, greaterThanOrEqualTo(5.0));
        expect(bounds.left, lessThanOrEqualTo(15.0));
        expect(bounds.right, greaterThanOrEqualTo(85.0));
        expect(bounds.right, lessThanOrEqualTo(95.0));
      });

      test('PathMorpher produces consistent results', () {
        final squareCommands = parser.parse(squarePath);
        final circleCommands = parser.parse(circlePath);

        final normalized = normalizer.normalize(squareCommands, circleCommands);
        final morpher = PathMorpher(
          fromCommands: normalized.from,
          toCommands: normalized.to,
        );

        // Get paths at different t values
        final path0 = morpher.getPathAt(0.0);
        final path05 = morpher.getPathAt(0.5);
        final path1 = morpher.getPathAt(1.0);

        expect(path0, isNotNull);
        expect(path05, isNotNull);
        expect(path1, isNotNull);

        // Verify bounds progression
        final bounds0 = path0.getBounds();
        final bounds05 = path05.getBounds();
        final bounds1 = path1.getBounds();

        print('t=0.0 bounds: $bounds0');
        print('t=0.5 bounds: $bounds05');
        print('t=1.0 bounds: $bounds1');

        // All should be in reasonable range
        expect(bounds0.width, greaterThan(0));
        expect(bounds05.width, greaterThan(0));
        expect(bounds1.width, greaterThan(0));
      });
    });

    group('Star to Heart Morphing', () {
      const starPath =
          'M50,5 L61,38 L95,38 L68,58 L79,91 L50,71 L21,91 L32,58 L5,38 L39,38 Z';
      const heartPath =
          'M50,85 L20,55 C10,45 10,30 20,20 C30,10 45,10 50,20 '
          'C55,10 70,10 80,20 C90,30 90,45 80,55 Z';

      test('parses and normalizes star and heart', () {
        final starCommands = parser.parse(starPath);
        final heartCommands = parser.parse(heartPath);

        expect(starCommands, isNotEmpty);
        expect(heartCommands, isNotEmpty);

        final normalized = normalizer.normalize(starCommands, heartCommands);

        expect(normalized.from.length, normalized.to.length);
        expect(normalized.from.length, greaterThan(0));
      });

      test('morphs star to heart smoothly', () {
        final starCommands = parser.parse(starPath);
        final heartCommands = parser.parse(heartPath);

        final normalized = normalizer.normalize(starCommands, heartCommands);
        final morpher = PathMorpher(
          fromCommands: normalized.from,
          toCommands: normalized.to,
        );

        // Test multiple interpolation points
        final steps = [0.0, 0.25, 0.5, 0.75, 1.0];

        for (final t in steps) {
          final path = morpher.getPathAt(t);
          expect(path, isNotNull);

          final bounds = path.getBounds();
          expect(bounds.width, greaterThan(0));
          expect(bounds.height, greaterThan(0));

          print('Star→Heart at t=$t: bounds=$bounds');
        }
      });
    });

    group('Triangle to Hexagon Morphing', () {
      const trianglePath = 'M50,10 L90,90 L10,90 Z';
      const hexagonPath = 'M50,10 L80,30 L80,70 L50,90 L20,70 L20,30 Z';

      test('handles different vertex counts', () {
        final triangleCommands = parser.parse(trianglePath);
        final hexagonCommands = parser.parse(hexagonPath);

        expect(triangleCommands.length, 4); // M + 2L + Z
        expect(hexagonCommands.length, 7); // M + 5L + Z

        final normalized = normalizer.normalize(
          triangleCommands,
          hexagonCommands,
        );

        // Should pad triangle to match hexagon
        expect(normalized.from.length, normalized.to.length);
        expect(
          normalized.from.length,
          greaterThanOrEqualTo(hexagonCommands.length),
        );
      });

      test('morphs triangle to hexagon', () {
        final triangleCommands = parser.parse(trianglePath);
        final hexagonCommands = parser.parse(hexagonPath);

        final normalized = normalizer.normalize(
          triangleCommands,
          hexagonCommands,
        );
        final morpher = PathMorpher(
          fromCommands: normalized.from,
          toCommands: normalized.to,
        );

        final path0 = morpher.getPathAt(0.0);
        final path1 = morpher.getPathAt(1.0);

        expect(path0.getBounds().width, greaterThan(0));
        expect(path1.getBounds().width, greaterThan(0));
      });
    });

    group('Edge Cases', () {
      test('handles empty paths', () {
        expect(() => parser.parse(''), returnsNormally);
        final commands = parser.parse('');
        expect(commands, isEmpty);
      });

      test('handles single point path', () {
        final commands = parser.parse('M10,10 Z');
        expect(commands.length, 2);

        final normalized = normalizer.normalizeSingle(commands);
        expect(normalized, isNotEmpty);
      });

      test('handles identical paths', () {
        const path = 'M10,10 L50,50 Z';
        final commands1 = parser.parse(path);
        final commands2 = parser.parse(path);

        final normalized = normalizer.normalize(commands1, commands2);
        final morpher = PathMorpher(
          fromCommands: normalized.from,
          toCommands: normalized.to,
        );

        // At any t, should produce same path
        final path0 = morpher.getPathAt(0.0);
        final path05 = morpher.getPathAt(0.5);
        final path1 = morpher.getPathAt(1.0);

        final bounds0 = path0.getBounds();
        final bounds05 = path05.getBounds();
        final bounds1 = path1.getBounds();

        expect(bounds0, bounds05);
        expect(bounds05, bounds1);
      });

      test('handles paths with quadratic curves', () {
        const quadPath = 'M10,10 Q30,30 50,10 Z';
        final commands = parser.parse(quadPath);

        expect(commands.length, 3);
        expect(commands[1].type, 'Q');

        final normalized = normalizer.normalizeSingle(commands);

        // Quadratic should be converted to cubic
        bool hasCubic = false;
        for (final cmd in normalized) {
          if (cmd.type == 'C') {
            hasCubic = true;
            break;
          }
        }
        expect(hasCubic, isTrue, reason: 'Quadratic should convert to cubic');
      });

      test('handles paths with smooth curves', () {
        const smoothPath = 'M10,10 C20,20 30,20 40,10 S60,0 70,10 Z';
        final commands = parser.parse(smoothPath);

        expect(commands.length, 4);
        expect(commands[1].type, 'C');
        expect(commands[2].type, 'S');

        final normalized = normalizer.normalizeSingle(commands);
        expect(normalized, isNotEmpty);
      });
    });

    group('Numerical Precision', () {
      test('handles very small numbers', () {
        const path = 'M0.001,0.001 L0.002,0.002 Z';
        final commands = parser.parse(path);

        expect(commands, isNotEmpty);

        final normalized = normalizer.normalizeSingle(commands);
        expect(normalized, isNotEmpty);
      });

      test('handles very large numbers', () {
        const path = 'M1000,1000 L2000,2000 Z';
        final commands = parser.parse(path);

        expect(commands, isNotEmpty);

        final normalized = normalizer.normalizeSingle(commands);
        expect(normalized, isNotEmpty);
      });

      test('handles negative coordinates', () {
        const path = 'M-10,-10 L-50,-50 Z';
        final commands = parser.parse(path);

        expect(commands, isNotEmpty);

        final normalized = normalizer.normalizeSingle(commands);
        expect(normalized, isNotEmpty);
      });
    });

    group('Extension Methods', () {
      test('interpolateTo works', () {
        final commands1 = parser.parse('M10,10 L50,50 Z');
        final commands2 = parser.parse('M10,10 L90,90 Z');

        final normalized = normalizer.normalize(commands1, commands2);

        final path = normalized.from.interpolateTo(normalized.to, 0.5);

        expect(path, isNotNull);
        expect(path.getBounds().width, greaterThan(0));
      });

      test('morphTo works', () {
        final commands1 = parser.parse('M10,10 L50,50 Z');
        final commands2 = parser.parse('M10,10 L90,90 Z');

        final normalized = normalizer.normalize(commands1, commands2);
        final morpher = normalized.from.morphTo(normalized.to);

        expect(morpher, isNotNull);

        final path = morpher.getPathAt(0.5);
        expect(path, isNotNull);
      });
    });
  });
}
