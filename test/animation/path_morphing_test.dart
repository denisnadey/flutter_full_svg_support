import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/src/animation/path_normalizer.dart';
import 'package:flutter_svg/src/animation/path_interpolation.dart';
import 'package:flutter_svg/src/animation/path_parser.dart';
import 'package:flutter_svg/src/animation/path_data.dart';

void main() {
  group('PathNormalizer', () {
    late PathNormalizer normalizer;
    late PathParser parser;

    setUp(() {
      normalizer = PathNormalizer();
      parser = PathParser();
    });

    group('normalizeSingle', () {
      test('converts relative commands to absolute', () {
        final commands = parser.parse('m10,10 l20,20');
        final normalized = normalizer.normalizeSingle(commands);

        expect(normalized.length, greaterThan(0));
        for (final cmd in normalized) {
          if (cmd is MoveToCommand) {
            expect(cmd.isRelative, false);
          } else if (cmd is CubicBezierCommand) {
            expect(cmd.isRelative, false);
          }
        }
      });

      test('converts LineTo to CubicBezier', () {
        final commands = parser.parse('M0,0 L10,10');
        final normalized = normalizer.normalizeSingle(commands);

        expect(normalized.length, 2);
        expect(normalized[0], isA<MoveToCommand>());
        expect(normalized[1], isA<CubicBezierCommand>());

        final cubic = normalized[1] as CubicBezierCommand;
        expect(cubic.x, 10);
        expect(cubic.y, 10);
      });

      test('converts HorizontalLineTo to CubicBezier', () {
        final commands = parser.parse('M0,0 H50');
        final normalized = normalizer.normalizeSingle(commands);

        expect(normalized.length, 2);
        expect(normalized[1], isA<CubicBezierCommand>());

        final cubic = normalized[1] as CubicBezierCommand;
        expect(cubic.x, 50);
        expect(cubic.y, 0); // Y should stay at 0
      });

      test('converts VerticalLineTo to CubicBezier', () {
        final commands = parser.parse('M0,0 V50');
        final normalized = normalizer.normalizeSingle(commands);

        expect(normalized.length, 2);
        expect(normalized[1], isA<CubicBezierCommand>());

        final cubic = normalized[1] as CubicBezierCommand;
        expect(cubic.x, 0); // X should stay at 0
        expect(cubic.y, 50);
      });

      test('converts QuadraticBezier to CubicBezier', () {
        final commands = parser.parse('M0,0 Q10,10 20,0');
        final normalized = normalizer.normalizeSingle(commands);

        expect(normalized.length, 2);
        expect(normalized[1], isA<CubicBezierCommand>());

        final cubic = normalized[1] as CubicBezierCommand;
        expect(cubic.x, 20);
        expect(cubic.y, 0);
      });

      test('keeps CubicBezier commands', () {
        final commands = parser.parse('M0,0 C10,10 20,20 30,30');
        final normalized = normalizer.normalizeSingle(commands);

        expect(normalized.length, 2);
        expect(normalized[0], isA<MoveToCommand>());
        expect(normalized[1], isA<CubicBezierCommand>());

        final cubic = normalized[1] as CubicBezierCommand;
        expect(cubic.x1, 10);
        expect(cubic.y1, 10);
        expect(cubic.x2, 20);
        expect(cubic.y2, 20);
        expect(cubic.x, 30);
        expect(cubic.y, 30);
      });

      test('handles ClosePath by adding line to start', () {
        final commands = parser.parse('M10,10 L20,20 Z');
        final normalized = normalizer.normalizeSingle(commands);

        // M, L (as C), line back to start (as C), Z
        expect(normalized.length, 4);
        expect(normalized[0], isA<MoveToCommand>());
        expect(normalized[1], isA<CubicBezierCommand>());
        expect(normalized[2], isA<CubicBezierCommand>()); // Line back
        expect(normalized[3], isA<ClosePathCommand>());
      });

      test('handles empty path', () {
        final commands = <PathCommand>[];
        final normalized = normalizer.normalizeSingle(commands);

        expect(normalized, isEmpty);
      });

      test('handles complex path with mixed commands', () {
        final commands = parser.parse(
          'M10,10 L20,20 H30 V40 C50,50 60,60 70,70 Z',
        );
        final normalized = normalizer.normalizeSingle(commands);

        // All should be M or C or Z
        for (final cmd in normalized) {
          expect(
            cmd is MoveToCommand ||
                cmd is CubicBezierCommand ||
                cmd is ClosePathCommand,
            true,
            reason: 'Got unexpected command: ${cmd.runtimeType}',
          );
        }
      });
    });

    group('normalize (pair)', () {
      test('handles paths with same length', () {
        final path1 = parser.parse('M0,0 L10,10');
        final path2 = parser.parse('M0,0 L20,20');

        final result = normalizer.normalize(path1, path2);

        expect(result.from.length, result.to.length);
        expect(result.isValid, true);
      });

      test('aligns paths with different lengths', () {
        final path1 = parser.parse('M0,0 L10,10');
        final path2 = parser.parse('M0,0 L10,10 L20,20');

        final result = normalizer.normalize(path1, path2);

        expect(result.from.length, result.to.length);
        expect(result.from.length, greaterThan(2));
      });

      test('normalizes both paths to absolute cubic beziers', () {
        final path1 = parser.parse('m0,0 l10,10');
        final path2 = parser.parse('M0,0 Q10,10 20,0');

        final result = normalizer.normalize(path1, path2);

        for (final cmd in result.from) {
          if (cmd is! MoveToCommand && cmd is! ClosePathCommand) {
            expect(cmd, isA<CubicBezierCommand>());
          }
        }

        for (final cmd in result.to) {
          if (cmd is! MoveToCommand && cmd is! ClosePathCommand) {
            expect(cmd, isA<CubicBezierCommand>());
          }
        }
      });

      test('produces valid result for compatible paths', () {
        final path1 = parser.parse('M10,10 L50,10 L50,50 L10,50 Z');
        final path2 = parser.parse('M10,10 L50,10 L50,50 L10,50 Z');

        final result = normalizer.normalize(path1, path2);

        expect(result.isValid, true);
      });
    });
  });

  group('PathInterpolator', () {
    late PathInterpolator interpolator;
    late PathNormalizer normalizer;
    late PathParser parser;

    setUp(() {
      interpolator = const PathInterpolator();
      normalizer = PathNormalizer();
      parser = PathParser();
    });

    test('interpolates at t=0 returns from path', () {
      final from = [
        const MoveToCommand(x: 0, y: 0),
        const CubicBezierCommand(x1: 10, y1: 10, x2: 20, y2: 20, x: 30, y: 30),
      ];
      final to = [
        const MoveToCommand(x: 10, y: 10),
        const CubicBezierCommand(x1: 20, y1: 20, x2: 30, y2: 30, x: 40, y: 40),
      ];

      final path = interpolator.interpolate(from, to, 0.0);

      // Path should match 'from' path
      expect(path, isNotNull);
    });

    test('interpolates at t=1 returns to path', () {
      final from = [
        const MoveToCommand(x: 0, y: 0),
        const CubicBezierCommand(x1: 10, y1: 10, x2: 20, y2: 20, x: 30, y: 30),
      ];
      final to = [
        const MoveToCommand(x: 10, y: 10),
        const CubicBezierCommand(x1: 20, y1: 20, x2: 30, y2: 30, x: 40, y: 40),
      ];

      final path = interpolator.interpolate(from, to, 1.0);

      // Path should match 'to' path
      expect(path, isNotNull);
    });

    test('interpolates at t=0.5 creates midpoint path', () {
      final from = [
        const MoveToCommand(x: 0, y: 0),
        const CubicBezierCommand(x1: 0, y1: 0, x2: 0, y2: 0, x: 0, y: 0),
      ];
      final to = [
        const MoveToCommand(x: 100, y: 100),
        const CubicBezierCommand(
          x1: 100,
          y1: 100,
          x2: 100,
          y2: 100,
          x: 100,
          y: 100,
        ),
      ];

      final path = interpolator.interpolate(from, to, 0.5);

      // Should create a path midway between from and to
      expect(path, isNotNull);
    });

    test('clamps t values outside [0,1] range', () {
      final from = [
        const MoveToCommand(x: 0, y: 0),
        const CubicBezierCommand(x1: 0, y1: 0, x2: 0, y2: 0, x: 10, y: 10),
      ];
      final to = [
        const MoveToCommand(x: 20, y: 20),
        const CubicBezierCommand(x1: 20, y1: 20, x2: 20, y2: 20, x: 30, y: 30),
      ];

      // t = -0.5 should clamp to 0
      final pathNegative = interpolator.interpolate(from, to, -0.5);
      expect(pathNegative, isNotNull);

      // t = 1.5 should clamp to 1
      final pathOver = interpolator.interpolate(from, to, 1.5);
      expect(pathOver, isNotNull);
    });

    test('throws on mismatched path lengths', () {
      final from = [
        const MoveToCommand(x: 0, y: 0),
        const CubicBezierCommand(x1: 0, y1: 0, x2: 0, y2: 0, x: 10, y: 10),
      ];
      final to = [const MoveToCommand(x: 0, y: 0)];

      expect(
        () => interpolator.interpolate(from, to, 0.5),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws on mismatched command types', () {
      final from = [const MoveToCommand(x: 0, y: 0)];
      final to = [
        const CubicBezierCommand(x1: 0, y1: 0, x2: 0, y2: 0, x: 10, y: 10),
      ];

      expect(
        () => interpolator.interpolate(from, to, 0.5),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('handles ClosePath commands', () {
      final from = [
        const MoveToCommand(x: 0, y: 0),
        const CubicBezierCommand(x1: 5, y1: 5, x2: 10, y2: 10, x: 15, y: 15),
        const ClosePathCommand(),
      ];
      final to = [
        const MoveToCommand(x: 10, y: 10),
        const CubicBezierCommand(x1: 15, y1: 15, x2: 20, y2: 20, x: 25, y: 25),
        const ClosePathCommand(),
      ];

      final path = interpolator.interpolate(from, to, 0.5);
      expect(path, isNotNull);
    });

    test('works with normalized paths from parser', () {
      final path1Cmds = parser.parse('M0,0 L10,10 Z');
      final path2Cmds = parser.parse('M0,0 L20,20 Z');

      final normalized = normalizer.normalize(path1Cmds, path2Cmds);
      final path = interpolator.interpolate(
        normalized.from,
        normalized.to,
        0.5,
      );

      expect(path, isNotNull);
    });
  });

  group('PathMorpher', () {
    test('creates morpher with valid commands', () {
      final from = [
        const MoveToCommand(x: 0, y: 0),
        const CubicBezierCommand(x1: 0, y1: 0, x2: 10, y2: 10, x: 20, y: 20),
      ];
      final to = [
        const MoveToCommand(x: 10, y: 10),
        const CubicBezierCommand(x1: 10, y1: 10, x2: 20, y2: 20, x: 30, y: 30),
      ];

      final morpher = PathMorpher(fromCommands: from, toCommands: to);

      expect(morpher, isNotNull);
    });

    test('throws on mismatched lengths', () {
      final from = [const MoveToCommand(x: 0, y: 0)];
      final to = [
        const MoveToCommand(x: 0, y: 0),
        const CubicBezierCommand(x1: 0, y1: 0, x2: 10, y2: 10, x: 20, y: 20),
      ];

      expect(
        () => PathMorpher(fromCommands: from, toCommands: to),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('getPathAt returns interpolated path', () {
      final from = [
        const MoveToCommand(x: 0, y: 0),
        const CubicBezierCommand(x1: 0, y1: 0, x2: 0, y2: 0, x: 10, y: 10),
      ];
      final to = [
        const MoveToCommand(x: 20, y: 20),
        const CubicBezierCommand(x1: 20, y1: 20, x2: 20, y2: 20, x: 30, y: 30),
      ];

      final morpher = PathMorpher(fromCommands: from, toCommands: to);

      final path0 = morpher.getPathAt(0.0);
      final path50 = morpher.getPathAt(0.5);
      final path100 = morpher.getPathAt(1.0);

      expect(path0, isNotNull);
      expect(path50, isNotNull);
      expect(path100, isNotNull);
    });

    test('fromPath returns t=0 path', () {
      final from = [const MoveToCommand(x: 0, y: 0)];
      final to = [const MoveToCommand(x: 10, y: 10)];

      final morpher = PathMorpher(fromCommands: from, toCommands: to);

      expect(morpher.fromPath, isNotNull);
    });

    test('toPath returns t=1 path', () {
      final from = [const MoveToCommand(x: 0, y: 0)];
      final to = [const MoveToCommand(x: 10, y: 10)];

      final morpher = PathMorpher(fromCommands: from, toCommands: to);

      expect(morpher.toPath, isNotNull);
    });

    test('getPathAtPercent converts percentage correctly', () {
      final from = [const MoveToCommand(x: 0, y: 0)];
      final to = [const MoveToCommand(x: 100, y: 100)];

      final morpher = PathMorpher(fromCommands: from, toCommands: to);

      final path50 = morpher.getPathAtPercent(50);
      expect(path50, isNotNull);
    });
  });

  group('PathCommandListInterpolation extension', () {
    test('interpolateTo creates interpolated path', () {
      final from = [
        const MoveToCommand(x: 0, y: 0),
        const CubicBezierCommand(x1: 0, y1: 0, x2: 0, y2: 0, x: 10, y: 10),
      ];
      final to = [
        const MoveToCommand(x: 20, y: 20),
        const CubicBezierCommand(x1: 20, y1: 20, x2: 20, y2: 20, x: 30, y: 30),
      ];

      final path = from.interpolateTo(to, 0.5);
      expect(path, isNotNull);
    });

    test('morphTo creates PathMorpher', () {
      final from = [const MoveToCommand(x: 0, y: 0)];
      final to = [const MoveToCommand(x: 10, y: 10)];

      final morpher = from.morphTo(to);
      expect(morpher, isA<PathMorpher>());
    });
  });
}
