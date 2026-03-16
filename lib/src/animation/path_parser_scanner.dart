part of 'path_parser.dart';

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
