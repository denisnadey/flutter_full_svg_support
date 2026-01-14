import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/src/animation/path_parser.dart';
import 'package:flutter_svg/src/animation/path_data.dart';

void main() {
  group('PathParser', () {
    late PathParser parser;

    setUp(() {
      parser = PathParser();
    });

    group('Basic Commands', () {
      test('parses empty path', () {
        final commands = parser.parse('');
        expect(commands, isEmpty);
      });

      test('parses whitespace-only path', () {
        final commands = parser.parse('   \t\n  ');
        expect(commands, isEmpty);
      });

      test('parses MoveTo command (M)', () {
        final commands = parser.parse('M10,20');
        expect(commands, hasLength(1));
        expect(commands[0], isA<MoveToCommand>());
        final cmd = commands[0] as MoveToCommand;
        expect(cmd.x, 10);
        expect(cmd.y, 20);
        expect(cmd.isRelative, false);
      });

      test('parses relative MoveTo command (m)', () {
        final commands = parser.parse('m10,20');
        expect(commands, hasLength(1));
        expect(commands[0], isA<MoveToCommand>());
        final cmd = commands[0] as MoveToCommand;
        expect(cmd.x, 10);
        expect(cmd.y, 20);
        expect(cmd.isRelative, true);
      });

      test('parses LineTo command (L)', () {
        final commands = parser.parse('M0,0 L10,20');
        expect(commands, hasLength(2));
        expect(commands[1], isA<LineToCommand>());
        final cmd = commands[1] as LineToCommand;
        expect(cmd.x, 10);
        expect(cmd.y, 20);
        expect(cmd.isRelative, false);
      });

      test('parses relative LineTo command (l)', () {
        final commands = parser.parse('m0,0 l10,20');
        expect(commands, hasLength(2));
        expect(commands[1], isA<LineToCommand>());
        final cmd = commands[1] as LineToCommand;
        expect(cmd.isRelative, true);
      });

      test('parses HorizontalLineTo command (H)', () {
        final commands = parser.parse('M0,0 H50');
        expect(commands, hasLength(2));
        expect(commands[1], isA<HorizontalLineToCommand>());
        final cmd = commands[1] as HorizontalLineToCommand;
        expect(cmd.x, 50);
        expect(cmd.isRelative, false);
      });

      test('parses VerticalLineTo command (V)', () {
        final commands = parser.parse('M0,0 V50');
        expect(commands, hasLength(2));
        expect(commands[1], isA<VerticalLineToCommand>());
        final cmd = commands[1] as VerticalLineToCommand;
        expect(cmd.y, 50);
        expect(cmd.isRelative, false);
      });

      test('parses ClosePath command (Z)', () {
        final commands = parser.parse('M0,0 L10,10 Z');
        expect(commands, hasLength(3));
        expect(commands[2], isA<ClosePathCommand>());
      });

      test('treats lowercase z same as uppercase Z', () {
        final commands = parser.parse('M0,0 L10,10 z');
        expect(commands, hasLength(3));
        expect(commands[2], isA<ClosePathCommand>());
      });
    });

    group('Cubic Bezier Commands', () {
      test('parses CubicBezier command (C)', () {
        final commands = parser.parse('M0,0 C10,10 20,20 30,30');
        expect(commands, hasLength(2));
        expect(commands[1], isA<CubicBezierCommand>());
        final cmd = commands[1] as CubicBezierCommand;
        expect(cmd.x1, 10);
        expect(cmd.y1, 10);
        expect(cmd.x2, 20);
        expect(cmd.y2, 20);
        expect(cmd.x, 30);
        expect(cmd.y, 30);
        expect(cmd.isRelative, false);
      });

      test('parses relative CubicBezier command (c)', () {
        final commands = parser.parse('m0,0 c10,10 20,20 30,30');
        expect(commands, hasLength(2));
        final cmd = commands[1] as CubicBezierCommand;
        expect(cmd.isRelative, true);
      });

      test('parses SmoothCubicBezier command (S)', () {
        final commands = parser.parse('M0,0 S20,20 30,30');
        expect(commands, hasLength(2));
        expect(commands[1], isA<SmoothCubicBezierCommand>());
        final cmd = commands[1] as SmoothCubicBezierCommand;
        expect(cmd.x2, 20);
        expect(cmd.y2, 20);
        expect(cmd.x, 30);
        expect(cmd.y, 30);
      });

      test('parses multiple cubic bezier curves', () {
        final commands = parser.parse(
          'M0,0 C10,10 20,20 30,30 C40,40 50,50 60,60',
        );
        expect(commands, hasLength(3));
        expect(commands[1], isA<CubicBezierCommand>());
        expect(commands[2], isA<CubicBezierCommand>());
      });
    });

    group('Quadratic Bezier Commands', () {
      test('parses QuadraticBezier command (Q)', () {
        final commands = parser.parse('M0,0 Q10,10 20,20');
        expect(commands, hasLength(2));
        expect(commands[1], isA<QuadraticBezierCommand>());
        final cmd = commands[1] as QuadraticBezierCommand;
        expect(cmd.x1, 10);
        expect(cmd.y1, 10);
        expect(cmd.x, 20);
        expect(cmd.y, 20);
      });

      test('parses SmoothQuadraticBezier command (T)', () {
        final commands = parser.parse('M0,0 T20,20');
        expect(commands, hasLength(2));
        expect(commands[1], isA<SmoothQuadraticBezierCommand>());
        final cmd = commands[1] as SmoothQuadraticBezierCommand;
        expect(cmd.x, 20);
        expect(cmd.y, 20);
      });
    });

    group('Arc Commands', () {
      test('parses Arc command (A)', () {
        final commands = parser.parse('M0,0 A10,10 0 0,1 20,20');
        expect(commands, hasLength(2));
        expect(commands[1], isA<ArcCommand>());
        final cmd = commands[1] as ArcCommand;
        expect(cmd.rx, 10);
        expect(cmd.ry, 10);
        expect(cmd.rotation, 0);
        expect(cmd.largeArc, false);
        expect(cmd.sweep, true);
        expect(cmd.x, 20);
        expect(cmd.y, 20);
      });

      test('parses Arc with large-arc and sweep flags', () {
        final commands = parser.parse('M0,0 A10,15 45 1,0 30,40');
        final cmd = commands[1] as ArcCommand;
        expect(cmd.rx, 10);
        expect(cmd.ry, 15);
        expect(cmd.rotation, 45);
        expect(cmd.largeArc, true);
        expect(cmd.sweep, false);
        expect(cmd.x, 30);
        expect(cmd.y, 40);
      });
    });

    group('Multiple Coordinates', () {
      test('parses MoveTo with implicit LineTo commands', () {
        final commands = parser.parse('M10,10 20,20 30,30');
        expect(commands, hasLength(3));
        expect(commands[0], isA<MoveToCommand>());
        expect(commands[1], isA<LineToCommand>());
        expect(commands[2], isA<LineToCommand>());
      });

      test('parses multiple LineTo commands', () {
        final commands = parser.parse('M0,0 L10,10 20,20 30,30');
        expect(commands, hasLength(4));
        expect(commands[1], isA<LineToCommand>());
        expect(commands[2], isA<LineToCommand>());
        expect(commands[3], isA<LineToCommand>());
      });

      test('parses multiple H commands', () {
        final commands = parser.parse('M0,0 H10 20 30');
        expect(commands, hasLength(4));
        expect((commands[1] as HorizontalLineToCommand).x, 10);
        expect((commands[2] as HorizontalLineToCommand).x, 20);
        expect((commands[3] as HorizontalLineToCommand).x, 30);
      });

      test('parses multiple V commands', () {
        final commands = parser.parse('M0,0 V10 20 30');
        expect(commands, hasLength(4));
        expect((commands[1] as VerticalLineToCommand).y, 10);
        expect((commands[2] as VerticalLineToCommand).y, 20);
        expect((commands[3] as VerticalLineToCommand).y, 30);
      });
    });

    group('Number Formats', () {
      test('parses negative numbers', () {
        final commands = parser.parse('M-10,-20 L-30,-40');
        final move = commands[0] as MoveToCommand;
        final line = commands[1] as LineToCommand;
        expect(move.x, -10);
        expect(move.y, -20);
        expect(line.x, -30);
        expect(line.y, -40);
      });

      test('parses decimal numbers', () {
        final commands = parser.parse('M10.5,20.75 L30.25,40.125');
        final move = commands[0] as MoveToCommand;
        final line = commands[1] as LineToCommand;
        expect(move.x, 10.5);
        expect(move.y, 20.75);
        expect(line.x, 30.25);
        expect(line.y, 40.125);
      });

      test('parses scientific notation', () {
        final commands = parser.parse('M1e2,2e3');
        final move = commands[0] as MoveToCommand;
        expect(move.x, 100);
        expect(move.y, 2000);
      });

      test('parses numbers with positive sign', () {
        final commands = parser.parse('M+10,+20');
        final move = commands[0] as MoveToCommand;
        expect(move.x, 10);
        expect(move.y, 20);
      });

      test('parses compact number notation', () {
        // Numbers can be directly adjacent with sign
        final commands = parser.parse('M10-20');
        final move = commands[0] as MoveToCommand;
        expect(move.x, 10);
        expect(move.y, -20);
      });
    });

    group('Whitespace Handling', () {
      test('handles spaces between numbers', () {
        final commands = parser.parse('M 10 20 L 30 40');
        expect(commands, hasLength(2));
      });

      test('handles commas between numbers', () {
        final commands = parser.parse('M10,20,L,30,40');
        expect(commands, hasLength(2));
      });

      test('handles tabs and newlines', () {
        final commands = parser.parse('M\t10\n20\rL\t30\n40');
        expect(commands, hasLength(2));
      });

      test('handles multiple whitespace characters', () {
        final commands = parser.parse('M  \t\n  10  ,  20');
        final move = commands[0] as MoveToCommand;
        expect(move.x, 10);
        expect(move.y, 20);
      });
    });

    group('Complex Paths', () {
      test('parses simple rectangle', () {
        final commands = parser.parse('M10,10 L50,10 L50,50 L10,50 Z');
        expect(commands, hasLength(5));
        expect(commands[0], isA<MoveToCommand>());
        expect(commands[1], isA<LineToCommand>());
        expect(commands[2], isA<LineToCommand>());
        expect(commands[3], isA<LineToCommand>());
        expect(commands[4], isA<ClosePathCommand>());
      });

      test('parses path with mixed commands', () {
        final commands = parser.parse(
          'M10,10 L20,20 H30 V40 C50,50 60,60 70,70 Z',
        );
        expect(commands, hasLength(6));
        expect(commands[0], isA<MoveToCommand>());
        expect(commands[1], isA<LineToCommand>());
        expect(commands[2], isA<HorizontalLineToCommand>());
        expect(commands[3], isA<VerticalLineToCommand>());
        expect(commands[4], isA<CubicBezierCommand>());
        expect(commands[5], isA<ClosePathCommand>());
      });

      test('parses path with relative and absolute commands', () {
        final commands = parser.parse('M10,10 l10,10 L30,30 h5 H40 v5 V45');
        expect(commands, hasLength(7));
        expect((commands[0] as MoveToCommand).isRelative, false);
        expect((commands[1] as LineToCommand).isRelative, true);
        expect((commands[2] as LineToCommand).isRelative, false);
        expect((commands[3] as HorizontalLineToCommand).isRelative, true);
        expect((commands[4] as HorizontalLineToCommand).isRelative, false);
      });
    });

    group('Error Handling', () {
      test('throws on unknown command', () {
        expect(
          () => parser.parse('X10,20'),
          throwsA(isA<PathParseException>()),
        );
      });

      test('throws on incomplete number', () {
        expect(() => parser.parse('M10'), throwsA(isA<PathParseException>()));
      });

      test('throws on invalid number format', () {
        expect(
          () => parser.parse('Mabc,def'),
          throwsA(isA<PathParseException>()),
        );
      });
    });
  });

  group('PathCommand equality and toString', () {
    test('MoveToCommand equality', () {
      const cmd1 = MoveToCommand(x: 10, y: 20);
      const cmd2 = MoveToCommand(x: 10, y: 20);
      const cmd3 = MoveToCommand(x: 10, y: 20, isRelative: true);

      expect(cmd1, equals(cmd2));
      expect(cmd1, isNot(equals(cmd3)));
      expect(cmd1.toString(), 'M10.0,20.0');
      expect(cmd3.toString(), 'm10.0,20.0');
    });

    test('CubicBezierCommand equality', () {
      const cmd1 = CubicBezierCommand(x1: 1, y1: 2, x2: 3, y2: 4, x: 5, y: 6);
      const cmd2 = CubicBezierCommand(x1: 1, y1: 2, x2: 3, y2: 4, x: 5, y: 6);

      expect(cmd1, equals(cmd2));
      expect(cmd1.toString(), 'C1.0,2.0 3.0,4.0 5.0,6.0');
    });

    test('ClosePathCommand equality', () {
      const cmd1 = ClosePathCommand();
      const cmd2 = ClosePathCommand();

      expect(cmd1, equals(cmd2));
      expect(cmd1.toString(), 'Z');
    });
  });

  group('PathCommand toAbsolute', () {
    test('converts relative MoveTo to absolute', () {
      const cmd = MoveToCommand(x: 10, y: 20, isRelative: true);
      final absolute = cmd.toAbsolute(5, 15) as MoveToCommand;

      expect(absolute.x, 15);
      expect(absolute.y, 35);
      expect(absolute.isRelative, false);
    });

    test('converts relative LineTo to absolute', () {
      const cmd = LineToCommand(x: 10, y: 20, isRelative: true);
      final absolute = cmd.toAbsolute(5, 15) as LineToCommand;

      expect(absolute.x, 15);
      expect(absolute.y, 35);
      expect(absolute.isRelative, false);
    });

    test('converts relative CubicBezier to absolute', () {
      const cmd = CubicBezierCommand(
        x1: 1,
        y1: 2,
        x2: 3,
        y2: 4,
        x: 5,
        y: 6,
        isRelative: true,
      );
      final absolute = cmd.toAbsolute(10, 20) as CubicBezierCommand;

      expect(absolute.x1, 11);
      expect(absolute.y1, 22);
      expect(absolute.x2, 13);
      expect(absolute.y2, 24);
      expect(absolute.x, 15);
      expect(absolute.y, 26);
      expect(absolute.isRelative, false);
    });

    test('keeps absolute commands unchanged', () {
      const cmd = LineToCommand(x: 10, y: 20, isRelative: false);
      final absolute = cmd.toAbsolute(5, 15) as LineToCommand;

      expect(absolute.x, 10);
      expect(absolute.y, 20);
      expect(absolute.isRelative, false);
    });
  });
}
