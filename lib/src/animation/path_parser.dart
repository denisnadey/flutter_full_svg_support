/// SVG Path parser for converting SVG path strings into PathCommand objects.
library;

import 'path_data.dart';
part 'path_parser_commands.dart';
part 'path_parser_exceptions.dart';
part 'path_parser_scanner.dart';

/// Parses SVG path data strings into structured PathCommand objects.
///
/// Supports all SVG path commands: M, L, H, V, C, S, Q, T, A, Z
/// and their relative counterparts (lowercase letters).
///
/// Example:
/// ```dart
/// final parser = PathParser();
/// final commands = parser.parse('M10,10 L20,20 Z');
/// ```
class PathParser {
  PathParser();

  /// Parse an SVG path data string into a list of PathCommand objects.
  ///
  /// The [pathData] parameter is the SVG path 'd' attribute value.
  /// Returns a list of PathCommand objects representing the path.
  ///
  /// Throws [PathParseException] if the path data is malformed.
  List<PathCommand> parse(String pathData) {
    if (pathData.trim().isEmpty) {
      return [];
    }

    final commands = <PathCommand>[];
    final scanner = _PathScanner(pathData);

    while (!scanner.isDone) {
      scanner.skipWhitespace();
      if (scanner.isDone) break;

      final commandChar = scanner.read();
      if (commandChar == null) break;

      // Parse command based on its character
      switch (commandChar) {
        case 'M':
        case 'm':
          commands.addAll(_parseMoveTo(scanner, commandChar == 'm'));
          break;
        case 'L':
        case 'l':
          commands.addAll(_parseLineTo(scanner, commandChar == 'l'));
          break;
        case 'H':
        case 'h':
          commands.addAll(_parseHorizontalLineTo(scanner, commandChar == 'h'));
          break;
        case 'V':
        case 'v':
          commands.addAll(_parseVerticalLineTo(scanner, commandChar == 'v'));
          break;
        case 'C':
        case 'c':
          commands.addAll(_parseCubicBezier(scanner, commandChar == 'c'));
          break;
        case 'S':
        case 's':
          commands.addAll(_parseSmoothCubicBezier(scanner, commandChar == 's'));
          break;
        case 'Q':
        case 'q':
          commands.addAll(_parseQuadraticBezier(scanner, commandChar == 'q'));
          break;
        case 'T':
        case 't':
          commands.addAll(
            _parseSmoothQuadraticBezier(scanner, commandChar == 't'),
          );
          break;
        case 'A':
        case 'a':
          commands.addAll(_parseArc(scanner, commandChar == 'a'));
          break;
        case 'Z':
        case 'z':
          commands.add(const ClosePathCommand());
          break;
        default:
          throw PathParseException(
            'Unknown path command: $commandChar at position ${scanner.position}',
          );
      }
    }

    return commands;
  }
}
