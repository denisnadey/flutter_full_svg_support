/// SVG Path parser for converting SVG path strings into PathCommand objects.
library;

import 'path_data.dart';

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

  List<PathCommand> _parseMoveTo(_PathScanner scanner, bool isRelative) {
    final commands = <PathCommand>[];
    // First MoveTo
    final x = scanner.readNumber();
    final y = scanner.readNumber();
    commands.add(MoveToCommand(x: x, y: y, isRelative: isRelative));

    // Subsequent coordinates are treated as LineTo
    while (scanner.hasMoreNumbers()) {
      final x = scanner.readNumber();
      final y = scanner.readNumber();
      commands.add(LineToCommand(x: x, y: y, isRelative: isRelative));
    }

    return commands;
  }

  List<PathCommand> _parseLineTo(_PathScanner scanner, bool isRelative) {
    final commands = <PathCommand>[];
    while (scanner.hasMoreNumbers()) {
      final x = scanner.readNumber();
      final y = scanner.readNumber();
      commands.add(LineToCommand(x: x, y: y, isRelative: isRelative));
    }
    return commands;
  }

  List<PathCommand> _parseHorizontalLineTo(
    _PathScanner scanner,
    bool isRelative,
  ) {
    final commands = <PathCommand>[];
    while (scanner.hasMoreNumbers()) {
      final x = scanner.readNumber();
      commands.add(HorizontalLineToCommand(x: x, isRelative: isRelative));
    }
    return commands;
  }

  List<PathCommand> _parseVerticalLineTo(
    _PathScanner scanner,
    bool isRelative,
  ) {
    final commands = <PathCommand>[];
    while (scanner.hasMoreNumbers()) {
      final y = scanner.readNumber();
      commands.add(VerticalLineToCommand(y: y, isRelative: isRelative));
    }
    return commands;
  }

  List<PathCommand> _parseCubicBezier(_PathScanner scanner, bool isRelative) {
    final commands = <PathCommand>[];
    while (scanner.hasMoreNumbers()) {
      final x1 = scanner.readNumber();
      final y1 = scanner.readNumber();
      final x2 = scanner.readNumber();
      final y2 = scanner.readNumber();
      final x = scanner.readNumber();
      final y = scanner.readNumber();
      commands.add(
        CubicBezierCommand(
          x1: x1,
          y1: y1,
          x2: x2,
          y2: y2,
          x: x,
          y: y,
          isRelative: isRelative,
        ),
      );
    }
    return commands;
  }

  List<PathCommand> _parseSmoothCubicBezier(
    _PathScanner scanner,
    bool isRelative,
  ) {
    final commands = <PathCommand>[];
    while (scanner.hasMoreNumbers()) {
      final x2 = scanner.readNumber();
      final y2 = scanner.readNumber();
      final x = scanner.readNumber();
      final y = scanner.readNumber();
      commands.add(
        SmoothCubicBezierCommand(
          x2: x2,
          y2: y2,
          x: x,
          y: y,
          isRelative: isRelative,
        ),
      );
    }
    return commands;
  }

  List<PathCommand> _parseQuadraticBezier(
    _PathScanner scanner,
    bool isRelative,
  ) {
    final commands = <PathCommand>[];
    while (scanner.hasMoreNumbers()) {
      final x1 = scanner.readNumber();
      final y1 = scanner.readNumber();
      final x = scanner.readNumber();
      final y = scanner.readNumber();
      commands.add(
        QuadraticBezierCommand(
          x1: x1,
          y1: y1,
          x: x,
          y: y,
          isRelative: isRelative,
        ),
      );
    }
    return commands;
  }

  List<PathCommand> _parseSmoothQuadraticBezier(
    _PathScanner scanner,
    bool isRelative,
  ) {
    final commands = <PathCommand>[];
    while (scanner.hasMoreNumbers()) {
      final x = scanner.readNumber();
      final y = scanner.readNumber();
      commands.add(
        SmoothQuadraticBezierCommand(x: x, y: y, isRelative: isRelative),
      );
    }
    return commands;
  }

  List<PathCommand> _parseArc(_PathScanner scanner, bool isRelative) {
    final commands = <PathCommand>[];
    while (scanner.hasMoreNumbers()) {
      final rx = scanner.readNumber();
      final ry = scanner.readNumber();
      final rotation = scanner.readNumber();
      final largeArc = scanner.readNumber() != 0;
      final sweep = scanner.readNumber() != 0;
      final x = scanner.readNumber();
      final y = scanner.readNumber();
      commands.add(
        ArcCommand(
          rx: rx,
          ry: ry,
          rotation: rotation,
          largeArc: largeArc,
          sweep: sweep,
          x: x,
          y: y,
          isRelative: isRelative,
        ),
      );
    }
    return commands;
  }
}

/// Scanner for tokenizing SVG path data strings.
class _PathScanner {
  _PathScanner(this.data);

  final String data;
  int position = 0;

  bool get isDone => position >= data.length;

  /// Skip whitespace and commas
  void skipWhitespace() {
    while (!isDone) {
      final char = data[position];
      if (char == ' ' ||
          char == '\t' ||
          char == '\n' ||
          char == '\r' ||
          char == ',') {
        position++;
      } else {
        break;
      }
    }
  }

  /// Read a single character
  String? read() {
    if (isDone) return null;
    return data[position++];
  }

  /// Peek at the next character without consuming it
  String? peek() {
    if (isDone) return null;
    return data[position];
  }

  /// Check if there are more numbers available
  bool hasMoreNumbers() {
    skipWhitespace();
    if (isDone) return false;

    final char = peek();
    if (char == null) return false;

    // Check if next character is a number, sign, or decimal point
    return char == '-' ||
        char == '+' ||
        char == '.' ||
        (char.codeUnitAt(0) >= '0'.codeUnitAt(0) &&
            char.codeUnitAt(0) <= '9'.codeUnitAt(0));
  }

  /// Read a number (integer or floating point)
  double readNumber() {
    skipWhitespace();

    if (isDone) {
      throw PathParseException(
        'Expected number but reached end of path data at position $position',
      );
    }

    final start = position;
    var hasDecimal = false;
    var hasExponent = false;

    // Handle sign
    if (peek() == '-' || peek() == '+') {
      position++;
    }

    // Read digits before decimal point
    while (!isDone) {
      final char = peek();
      if (char == null) break;

      if (char.codeUnitAt(0) >= '0'.codeUnitAt(0) &&
          char.codeUnitAt(0) <= '9'.codeUnitAt(0)) {
        position++;
      } else if (char == '.' && !hasDecimal && !hasExponent) {
        hasDecimal = true;
        position++;
      } else if ((char == 'e' || char == 'E') && !hasExponent) {
        hasExponent = true;
        position++;
        // Handle exponent sign
        if (peek() == '-' || peek() == '+') {
          position++;
        }
      } else {
        break;
      }
    }

    if (start == position) {
      throw PathParseException(
        'Invalid number at position $position: ${peek()}',
      );
    }

    final numberStr = data.substring(start, position);
    final number = double.tryParse(numberStr);

    if (number == null) {
      throw PathParseException('Failed to parse number: $numberStr');
    }

    return number;
  }
}

/// Exception thrown when path parsing fails.
class PathParseException implements Exception {
  PathParseException(this.message);

  final String message;

  @override
  String toString() => 'PathParseException: $message';
}
