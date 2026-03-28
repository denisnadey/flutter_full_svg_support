/// calc() expression parser and evaluator.
part of 'css_variables_calc.dart';

/// calc() expression parser and evaluator.
///
/// Supports:
/// - Basic arithmetic: +, -, *, /
/// - Nested calc(): calc(calc(100% - 10px) * 2)
/// - CSS math functions: min(), max(), clamp()
/// - Mixed units: calc(100% - 50px)
/// - Deeply nested expressions (up to 20 levels)
/// - Proper em/rem unit resolution with font-size cascading
class CssCalcEvaluator {
  /// Maximum nesting depth for recursive evaluations.
  static const int _maxNestingDepth = 20;

  /// Evaluate a calc() expression to a numeric value.
  /// Returns null if evaluation fails.
  ///
  /// [value] - The string potentially containing calc()
  /// [fontSize] - Current font size for em units (in non-font-size contexts)
  /// [containerSize] - Container size for percentage calculations (optional)
  /// [parentFontSize] - Parent element's font size for em inheritance in
  ///   font-size computation context
  /// [rootFontSize] - Root SVG element's font-size for rem units (default 16px)
  /// [viewportSize] - Viewport size for vw/vh/vmin/vmax units
  static double? evaluate(
    String value, {
    double fontSize = _defaultFontSize,
    double? containerSize,
    double? parentFontSize,
    double? rootFontSize,
    Size? viewportSize,
  }) {
    return _evaluateWithDepth(
      value,
      fontSize: fontSize,
      containerSize: containerSize,
      parentFontSize: parentFontSize,
      rootFontSize: rootFontSize ?? _defaultFontSize,
      viewportSize: viewportSize,
      depth: 0,
    );
  }

  /// Internal evaluation with depth tracking to prevent infinite recursion.
  static double? _evaluateWithDepth(
    String value, {
    required double fontSize,
    double? containerSize,
    double? parentFontSize,
    required double rootFontSize,
    Size? viewportSize,
    required int depth,
  }) {
    if (depth > _maxNestingDepth) {
      return null; // Prevent infinite recursion
    }

    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return null; // Empty expression is invalid
    }

    final lower = trimmed.toLowerCase();

    // Check for CSS math functions first
    if (lower.startsWith('clamp(')) {
      return _evaluateClampWithDepth(
        trimmed,
        fontSize: fontSize,
        containerSize: containerSize,
        parentFontSize: parentFontSize,
        rootFontSize: rootFontSize,
        viewportSize: viewportSize,
        depth: depth,
      );
    }

    if (lower.startsWith('min(')) {
      return _evaluateMinWithDepth(
        trimmed,
        fontSize: fontSize,
        containerSize: containerSize,
        parentFontSize: parentFontSize,
        rootFontSize: rootFontSize,
        viewportSize: viewportSize,
        depth: depth,
      );
    }

    if (lower.startsWith('max(')) {
      return _evaluateMaxWithDepth(
        trimmed,
        fontSize: fontSize,
        containerSize: containerSize,
        parentFontSize: parentFontSize,
        rootFontSize: rootFontSize,
        viewportSize: viewportSize,
        depth: depth,
      );
    }

    // Check if it's a calc() expression
    if (!lower.startsWith('calc(')) {
      // Try to parse as a simple numeric value with units
      return _parseNumericValue(
        trimmed,
        fontSize: fontSize,
        containerSize: containerSize,
        parentFontSize: parentFontSize,
        rootFontSize: rootFontSize,
        viewportSize: viewportSize,
      );
    }

    // Extract the calc() content
    final content = _extractCalcContent(trimmed);
    if (content == null || content.trim().isEmpty) {
      return null; // Invalid calc() expression
    }

    // Evaluate the expression
    return _evaluateExpressionWithDepth(
      content,
      fontSize: fontSize,
      containerSize: containerSize,
      parentFontSize: parentFontSize,
      rootFontSize: rootFontSize,
      viewportSize: viewportSize,
      depth: depth,
    );
  }

  /// Evaluate a clamp(min, val, max) expression.
  /// clamp(MIN, VAL, MAX) is equivalent to max(MIN, min(VAL, MAX))
  static double? _evaluateClampWithDepth(
    String expr, {
    required double fontSize,
    double? containerSize,
    double? parentFontSize,
    required double rootFontSize,
    Size? viewportSize,
    required int depth,
  }) {
    final content = _extractFunctionContent(expr, 'clamp');
    if (content == null) return null;

    final args = _splitFunctionArgs(content);
    if (args.length != 3) return null;

    final minVal = _evaluateWithDepth(
      args[0],
      fontSize: fontSize,
      containerSize: containerSize,
      parentFontSize: parentFontSize,
      rootFontSize: rootFontSize,
      viewportSize: viewportSize,
      depth: depth + 1,
    );
    final val = _evaluateWithDepth(
      args[1],
      fontSize: fontSize,
      containerSize: containerSize,
      parentFontSize: parentFontSize,
      rootFontSize: rootFontSize,
      viewportSize: viewportSize,
      depth: depth + 1,
    );
    final maxVal = _evaluateWithDepth(
      args[2],
      fontSize: fontSize,
      containerSize: containerSize,
      parentFontSize: parentFontSize,
      rootFontSize: rootFontSize,
      viewportSize: viewportSize,
      depth: depth + 1,
    );

    if (minVal == null || val == null || maxVal == null) return null;

    // clamp(min, val, max) = max(min, min(val, max))
    return val.clamp(minVal, maxVal);
  }

  /// Evaluate a min(...) expression - returns the smallest value.
  static double? _evaluateMinWithDepth(
    String expr, {
    required double fontSize,
    double? containerSize,
    double? parentFontSize,
    required double rootFontSize,
    Size? viewportSize,
    required int depth,
  }) {
    final content = _extractFunctionContent(expr, 'min');
    if (content == null) return null;

    final args = _splitFunctionArgs(content);
    if (args.isEmpty) return null;

    double? result;
    for (final arg in args) {
      final val = _evaluateWithDepth(
        arg,
        fontSize: fontSize,
        containerSize: containerSize,
        parentFontSize: parentFontSize,
        rootFontSize: rootFontSize,
        viewportSize: viewportSize,
        depth: depth + 1,
      );
      if (val == null) return null;
      if (result == null || val < result) {
        result = val;
      }
    }

    return result;
  }

  /// Evaluate a max(...) expression - returns the largest value.
  static double? _evaluateMaxWithDepth(
    String expr, {
    required double fontSize,
    double? containerSize,
    double? parentFontSize,
    required double rootFontSize,
    Size? viewportSize,
    required int depth,
  }) {
    final content = _extractFunctionContent(expr, 'max');
    if (content == null) return null;

    final args = _splitFunctionArgs(content);
    if (args.isEmpty) return null;

    double? result;
    for (final arg in args) {
      final val = _evaluateWithDepth(
        arg,
        fontSize: fontSize,
        containerSize: containerSize,
        parentFontSize: parentFontSize,
        rootFontSize: rootFontSize,
        viewportSize: viewportSize,
        depth: depth + 1,
      );
      if (val == null) return null;
      if (result == null || val > result) {
        result = val;
      }
    }

    return result;
  }

  /// Extract content from a function call like func(...).
  static String? _extractFunctionContent(String expr, String funcName) {
    final lower = expr.toLowerCase();
    final prefix = '$funcName(';
    if (!lower.startsWith(prefix)) {
      return null;
    }

    // Find matching closing parenthesis
    var depth = 0;
    final start = funcName.length + 1;
    for (var i = funcName.length; i < expr.length; i++) {
      if (expr[i] == '(') {
        depth++;
      } else if (expr[i] == ')') {
        depth--;
        if (depth == 0) {
          return expr.substring(start, i);
        }
      }
    }

    return null;
  }

  /// Split function arguments by commas, respecting nested parentheses.
  static List<String> _splitFunctionArgs(String content) {
    final args = <String>[];
    var depth = 0;
    var current = StringBuffer();

    for (var i = 0; i < content.length; i++) {
      final char = content[i];
      if (char == '(') {
        depth++;
        current.write(char);
      } else if (char == ')') {
        depth--;
        current.write(char);
      } else if (char == ',' && depth == 0) {
        args.add(current.toString().trim());
        current = StringBuffer();
      } else {
        current.write(char);
      }
    }

    final lastArg = current.toString().trim();
    if (lastArg.isNotEmpty) {
      args.add(lastArg);
    }

    return args;
  }

  /// Extract content from calc(...).
  static String? _extractCalcContent(String calc) {
    final lower = calc.toLowerCase();
    if (!lower.startsWith('calc(')) {
      return null;
    }

    // Find matching closing parenthesis
    var depth = 0;
    var start = 5; // After 'calc('
    for (var i = 4; i < calc.length; i++) {
      if (calc[i] == '(') {
        depth++;
      } else if (calc[i] == ')') {
        depth--;
        if (depth == 0) {
          return calc.substring(start, i);
        }
      }
    }

    return null;
  }

  /// Evaluate an expression string with depth tracking.
  static double? _evaluateExpressionWithDepth(
    String expr, {
    required double fontSize,
    double? containerSize,
    double? parentFontSize,
    required double rootFontSize,
    Size? viewportSize,
    required int depth,
  }) {
    // First, handle nested calc() expressions and math functions
    var resolved = _resolveNestedFunctionsWithDepth(
      expr,
      fontSize: fontSize,
      containerSize: containerSize,
      parentFontSize: parentFontSize,
      rootFontSize: rootFontSize,
      viewportSize: viewportSize,
      depth: depth,
    );

    if (resolved == null) {
      return null;
    }

    // Parse and evaluate the expression
    return _parseAndEvaluate(
      resolved,
      fontSize: fontSize,
      containerSize: containerSize,
      parentFontSize: parentFontSize,
      rootFontSize: rootFontSize,
      viewportSize: viewportSize,
    );
  }

  /// Resolve nested calc(), min(), max(), clamp() expressions recursively.
  static String? _resolveNestedFunctionsWithDepth(
    String expr, {
    required double fontSize,
    double? containerSize,
    double? parentFontSize,
    required double rootFontSize,
    Size? viewportSize,
    required int depth,
  }) {
    var result = expr;
    var iterations = 0;

    // Handle all CSS math functions: calc(), min(), max(), clamp()
    final funcRegex = RegExp(r'(calc|min|max|clamp)\(', caseSensitive: false);

    while (funcRegex.hasMatch(result) && iterations < _maxNestingDepth) {
      final match = funcRegex.firstMatch(result);
      if (match == null) break;

      final funcName = match.group(1)!.toLowerCase();
      final start = match.start;
      // Find the matching closing paren
      var parenDepth = 1;
      var end = match.end;
      while (end < result.length && parenDepth > 0) {
        if (result[end] == '(') parenDepth++;
        if (result[end] == ')') parenDepth--;
        end++;
      }

      if (parenDepth != 0) {
        return null; // Unmatched parentheses
      }

      final fullExpr = result.substring(start, end);
      double? nestedValue;

      if (funcName == 'calc') {
        final nestedExpr = result.substring(match.end, end - 1);
        nestedValue = _evaluateExpressionWithDepth(
          nestedExpr,
          fontSize: fontSize,
          containerSize: containerSize,
          parentFontSize: parentFontSize,
          rootFontSize: rootFontSize,
          viewportSize: viewportSize,
          depth: depth + 1,
        );
      } else {
        // min, max, clamp - use the full evaluation with depth
        nestedValue = _evaluateWithDepth(
          fullExpr,
          fontSize: fontSize,
          containerSize: containerSize,
          parentFontSize: parentFontSize,
          rootFontSize: rootFontSize,
          viewportSize: viewportSize,
          depth: depth + 1,
        );
      }

      if (nestedValue == null) {
        return null;
      }

      result =
          result.substring(0, start) + '$nestedValue' + result.substring(end);
      iterations++;
    }

    return result;
  }

  /// Parse and evaluate a simple expression (no nested calc).
  static double? _parseAndEvaluate(
    String expr, {
    required double fontSize,
    double? containerSize,
    double? parentFontSize,
    required double rootFontSize,
    Size? viewportSize,
  }) {
    // Tokenize the expression
    final tokens = _tokenize(expr);
    if (tokens == null || tokens.isEmpty) {
      return null;
    }

    // Convert tokens to values and operators
    final values = <double>[];
    final operators = <String>[];

    for (var i = 0; i < tokens.length; i++) {
      final token = tokens[i];

      if (token == '+' || token == '-' || token == '*' || token == '/') {
        // Handle negative numbers at start or after operator
        if (token == '-' &&
            (values.isEmpty ||
                (operators.isNotEmpty &&
                    i > 0 &&
                    ['+', '-', '*', '/'].contains(tokens[i - 1])))) {
          // This is a negative sign, combine with next token
          if (i + 1 < tokens.length) {
            final nextValue = _parseNumericValue(
              '-${tokens[i + 1]}',
              fontSize: fontSize,
              containerSize: containerSize,
              parentFontSize: parentFontSize,
              rootFontSize: rootFontSize,
              viewportSize: viewportSize,
            );
            if (nextValue == null) return null;
            values.add(nextValue);
            i++; // Skip next token
            continue;
          }
        }
        operators.add(token);
      } else {
        final value = _parseNumericValue(
          token,
          fontSize: fontSize,
          containerSize: containerSize,
          parentFontSize: parentFontSize,
          rootFontSize: rootFontSize,
          viewportSize: viewportSize,
        );
        if (value == null) {
          return null;
        }
        values.add(value);
      }
    }

    if (values.isEmpty) {
      return null;
    }

    // Validate: number of values should be operators + 1
    // e.g., "10 + 20 - 5" has 3 values and 2 operators
    if (operators.isNotEmpty && values.length != operators.length + 1) {
      // Invalid expression: mismatched values and operators
      // If we have more values than expected, use what we have
      // If we have fewer values, return the last valid value or null
      if (values.length < operators.length + 1) {
        // Not enough values for operators (trailing operator)
        // Remove trailing operators until we have a valid expression
        while (operators.length >= values.length && operators.isNotEmpty) {
          operators.removeLast();
        }
        if (values.isEmpty) return null;
        if (operators.isEmpty) return values.first;
      }
    }

    // Evaluate: first * and /, then + and -
    // Handle multiplication and division first
    var i = 0;
    while (i < operators.length) {
      if (operators[i] == '*' || operators[i] == '/') {
        final left = values[i];
        final right = values[i + 1];
        final result = operators[i] == '*'
            ? left * right
            : (right != 0 ? left / right : 0.0);
        values[i] = result;
        values.removeAt(i + 1);
        operators.removeAt(i);
      } else {
        i++;
      }
    }

    // Handle addition and subtraction
    var result = values[0];
    for (var j = 0; j < operators.length; j++) {
      final right = values[j + 1];
      if (operators[j] == '+') {
        result += right;
      } else if (operators[j] == '-') {
        result -= right;
      }
    }

    return result;
  }

  /// Tokenize an expression into values and operators.
  static List<String>? _tokenize(String expr) {
    final tokens = <String>[];
    final buffer = StringBuffer();
    var i = 0;

    while (i < expr.length) {
      final char = expr[i];

      if (char == ' ' || char == '\t' || char == '\n') {
        // Whitespace separates tokens
        if (buffer.isNotEmpty) {
          tokens.add(buffer.toString());
          buffer.clear();
        }
        i++;
        continue;
      }

      // Check for operators with required surrounding whitespace
      if (char == '+' || char == '-' || char == '*' || char == '/') {
        // In calc(), operators must be surrounded by whitespace
        // But we already handle whitespace above, so just emit
        if (buffer.isNotEmpty) {
          tokens.add(buffer.toString());
          buffer.clear();
        }
        tokens.add(char);
        i++;
        continue;
      }

      if (char == '(') {
        // Handle parenthesized sub-expression
        var depth = 1;
        var start = i + 1;
        i++;
        while (i < expr.length && depth > 0) {
          if (expr[i] == '(') depth++;
          if (expr[i] == ')') depth--;
          i++;
        }
        // Recursively evaluate parenthesized expression
        final subExpr = expr.substring(start, i - 1);
        buffer.write(subExpr);
        continue;
      }

      buffer.write(char);
      i++;
    }

    if (buffer.isNotEmpty) {
      tokens.add(buffer.toString());
    }

    return tokens.isEmpty ? null : tokens;
  }

  /// Parse a numeric value with optional units.
  ///
  /// [parentFontSize] is used for em units in the context where an element's
  /// font-size is being computed (em is relative to parent, not current).
  /// [rootFontSize] is used for rem units (always relative to root element).
  /// [viewportSize] is used for vw/vh/vmin/vmax viewport units.
  static double? _parseNumericValue(
    String value, {
    required double fontSize,
    double? containerSize,
    double? parentFontSize,
    required double rootFontSize,
    Size? viewportSize,
  }) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    // Try simple number
    final simpleNum = double.tryParse(trimmed);
    if (simpleNum != null) {
      return simpleNum;
    }

    // Parse number with unit
    final unitMatch = RegExp(r'^(-?[\d.]+)\s*([\w%]+)?$').firstMatch(trimmed);
    if (unitMatch == null) {
      return null;
    }

    final numStr = unitMatch.group(1);
    final unit = unitMatch.group(2)?.toLowerCase() ?? '';

    final num = double.tryParse(numStr ?? '');
    if (num == null) {
      return null;
    }

    // Convert to base unit (px)
    switch (unit) {
      case '':
      case 'px':
        return num;
      case 'em':
        // When computing font-size, em is relative to parent font-size.
        // In other contexts, em is relative to current element's font-size.
        return num * (parentFontSize ?? fontSize);
      case 'rem':
        // rem is always relative to root element's font-size,
        // regardless of nesting depth - does NOT compound.
        return num * rootFontSize;
      case 'ex':
        // ex is approximately 0.5em (x-height of the font)
        return num * (parentFontSize ?? fontSize) * 0.5;
      case '%':
        if (containerSize != null) {
          return num / 100.0 * containerSize;
        }
        // Fall back to viewport width if available
        if (viewportSize != null) {
          return num / 100.0 * viewportSize.width;
        }
        // Without container size or viewport, return the percentage as-is
        return num;
      case 'pt':
      case 'pc':
      case 'in':
      case 'cm':
      case 'mm':
      case 'q':
        final factor = _unitToPixels[unit];
        if (factor != null) {
          return num * factor;
        }
        return num;
      case 'vw':
        // vw = 1% of viewport width
        if (viewportSize != null) {
          return num * viewportSize.width / 100.0;
        }
        return num;
      case 'vh':
        // vh = 1% of viewport height
        if (viewportSize != null) {
          return num * viewportSize.height / 100.0;
        }
        return num;
      case 'vmin':
        // vmin = 1% of smaller viewport dimension
        if (viewportSize != null) {
          final minDim = viewportSize.width < viewportSize.height
              ? viewportSize.width
              : viewportSize.height;
          return num * minDim / 100.0;
        }
        return num;
      case 'vmax':
        // vmax = 1% of larger viewport dimension
        if (viewportSize != null) {
          final maxDim = viewportSize.width > viewportSize.height
              ? viewportSize.width
              : viewportSize.height;
          return num * maxDim / 100.0;
        }
        return num;
      case 'ch':
        // ch is the width of the '0' character, approximately 0.5em
        return num * (parentFontSize ?? fontSize) * 0.5;
      case 'lh':
        // lh is the line-height of the element, approximate with 1.2em
        return num * (parentFontSize ?? fontSize) * 1.2;
      default:
        // Unknown unit, try to return the number
        return num;
    }
  }
}
