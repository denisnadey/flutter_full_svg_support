part of 'path_parser.dart';

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

List<PathCommand> _parseVerticalLineTo(_PathScanner scanner, bool isRelative) {
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

List<PathCommand> _parseQuadraticBezier(_PathScanner scanner, bool isRelative) {
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
