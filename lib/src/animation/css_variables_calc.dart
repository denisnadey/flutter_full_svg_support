/// CSS custom properties (variables) and calc() expression support.
library;

import 'svg_dom.dart';

/// Regex to match CSS custom property declarations: --property-name: value
final RegExp _customPropertyDeclarationRegex = RegExp(
  r'(--[\w-]+)\s*:\s*([^;]+)',
  caseSensitive: false,
);

/// Regex to match var() function calls
final RegExp _varFunctionRegex = RegExp(
  r'var\(\s*(--[\w-]+)(?:\s*,\s*([^)]+))?\s*\)',
  caseSensitive: false,
);

/// Regex to match calc() function calls (including nested)
final RegExp _calcFunctionRegex = RegExp(r'calc\(', caseSensitive: false);

/// Unit conversion factors to pixels (base unit)
const Map<String, double> _unitToPixels = {
  'px': 1.0,
  'pt': 1.333333, // 1pt = 4/3 px
  'pc': 16.0, // 1pc = 16px
  'in': 96.0, // 1in = 96px
  'cm': 37.795276, // 1cm ≈ 37.8px
  'mm': 3.7795276, // 1mm ≈ 3.78px
  'q': 0.94488189, // 1Q = 1/40 cm
};

/// Default font size for em/rem calculations
const double _defaultFontSize = 16.0;

/// CSS custom property store attached to an SvgNode.
/// Custom properties are inheritable by default.
class CssCustomProperties {
  CssCustomProperties([Map<String, String>? initial])
    : _properties = initial ?? {};

  final Map<String, String> _properties;

  /// Get a custom property value from this store.
  String? get(String name) => _properties[name];

  /// Set a custom property value.
  void set(String name, String value) {
    _properties[name] = value;
  }

  /// Check if a property exists.
  bool has(String name) => _properties.containsKey(name);

  /// Get all properties.
  Map<String, String> get all => Map.unmodifiable(_properties);

  /// Create a copy of this store.
  CssCustomProperties copy() => CssCustomProperties(Map.from(_properties));

  @override
  String toString() => 'CssCustomProperties($_properties)';
}

/// Extension to store custom properties on SvgNode.
/// Uses a weak map pattern via attribute storage.
extension SvgNodeCssVariablesExtension on SvgNode {
  static const String _customPropertiesKey = '__cssCustomProperties';

  /// Get or create the custom properties store for this node.
  CssCustomProperties get cssCustomProperties {
    final existing = attributes[_customPropertiesKey];
    if (existing != null && existing.baseValue is CssCustomProperties) {
      return existing.baseValue as CssCustomProperties;
    }
    final store = CssCustomProperties();
    setAttribute(_customPropertiesKey, store);
    return store;
  }

  /// Set custom properties from a parsed style string.
  void parseAndSetCustomProperties(String styleString) {
    final matches = _customPropertyDeclarationRegex.allMatches(styleString);
    for (final match in matches) {
      final name = match.group(1)!.trim();
      final value = match.group(2)!.trim();
      cssCustomProperties.set(name, value);
    }
  }
}

/// CSS variable resolver that walks up the element tree.
class CssVariableResolver {
  /// Resolve a CSS value that may contain var() references.
  /// Walks up the node tree to find variable definitions.
  /// Supports var(--name) and var(--name, fallback).
  static String resolveValue(String value, SvgNode node, {double? fontSize}) {
    if (!value.contains('var(')) {
      return value;
    }

    var result = value;
    var iterations = 0;
    const maxIterations = 10; // Prevent infinite recursion

    // Keep resolving until no more var() calls or max iterations
    while (result.contains('var(') && iterations < maxIterations) {
      result = _resolveVarOnce(result, node, fontSize: fontSize);
      iterations++;
    }

    return result;
  }

  /// Single pass of var() resolution.
  static String _resolveVarOnce(
    String value,
    SvgNode node, {
    double? fontSize,
  }) {
    return value.replaceAllMapped(_varFunctionRegex, (match) {
      final varName = match.group(1)!.trim();
      final fallback = match.group(2)?.trim();

      // Walk up the tree to find the variable
      final resolvedValue = _lookupVariable(varName, node);

      if (resolvedValue != null) {
        // If resolved value contains var(), it will be resolved in next iteration
        return resolvedValue;
      } else if (fallback != null) {
        // Use fallback if variable not found
        return fallback;
      } else {
        // Variable not found and no fallback - return empty
        return '';
      }
    });
  }

  /// Look up a custom property by walking up the element tree.
  static String? _lookupVariable(String name, SvgNode node) {
    SvgNode? current = node;

    while (current != null) {
      final props = current.cssCustomProperties;
      if (props.has(name)) {
        return props.get(name);
      }
      current = current.parent;
    }

    return null;
  }
}

/// calc() expression parser and evaluator.
class CssCalcEvaluator {
  /// Evaluate a calc() expression to a numeric value.
  /// Returns null if evaluation fails.
  ///
  /// [value] - The string potentially containing calc()
  /// [fontSize] - Current font size for em/rem units
  /// [containerSize] - Container size for percentage calculations (optional)
  static double? evaluate(
    String value, {
    double fontSize = _defaultFontSize,
    double? containerSize,
  }) {
    final trimmed = value.trim();

    // Check if it's a calc() expression
    if (!trimmed.toLowerCase().startsWith('calc(')) {
      // Try to parse as a simple numeric value with units
      return _parseNumericValue(
        trimmed,
        fontSize: fontSize,
        containerSize: containerSize,
      );
    }

    // Extract the calc() content
    final content = _extractCalcContent(trimmed);
    if (content == null) {
      return null;
    }

    // Evaluate the expression
    return _evaluateExpression(
      content,
      fontSize: fontSize,
      containerSize: containerSize,
    );
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

  /// Evaluate an expression string.
  static double? _evaluateExpression(
    String expr, {
    required double fontSize,
    double? containerSize,
  }) {
    // First, handle nested calc() expressions
    var resolved = _resolveNestedCalc(
      expr,
      fontSize: fontSize,
      containerSize: containerSize,
    );

    if (resolved == null) {
      return null;
    }

    // Parse and evaluate the expression
    return _parseAndEvaluate(
      resolved,
      fontSize: fontSize,
      containerSize: containerSize,
    );
  }

  /// Resolve nested calc() expressions recursively.
  static String? _resolveNestedCalc(
    String expr, {
    required double fontSize,
    double? containerSize,
  }) {
    var result = expr;
    var iterations = 0;
    const maxIterations = 10;

    while (_calcFunctionRegex.hasMatch(result) && iterations < maxIterations) {
      final match = _calcFunctionRegex.firstMatch(result);
      if (match == null) break;

      final start = match.start;
      // Find the matching closing paren
      var depth = 1;
      var end = match.end;
      while (end < result.length && depth > 0) {
        if (result[end] == '(') depth++;
        if (result[end] == ')') depth--;
        end++;
      }

      if (depth != 0) {
        return null; // Unmatched parentheses
      }

      final nestedExpr = result.substring(match.end, end - 1);
      final nestedValue = _evaluateExpression(
        nestedExpr,
        fontSize: fontSize,
        containerSize: containerSize,
      );

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
  static double? _parseNumericValue(
    String value, {
    required double fontSize,
    double? containerSize,
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
        return num * fontSize;
      case 'rem':
        return num * _defaultFontSize;
      case '%':
        if (containerSize != null) {
          return num / 100.0 * containerSize;
        }
        // Without container size, return the percentage as-is
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
      case 'vh':
      case 'vmin':
      case 'vmax':
        // Viewport units - return as-is since we don't have viewport info
        return num;
      default:
        // Unknown unit, try to return the number
        return num;
    }
  }
}

/// Combined resolver for CSS values with var() and calc() support.
class CssValueResolver {
  /// Resolve a CSS value that may contain var() and/or calc().
  /// Returns the resolved string value.
  static String resolve(
    String value,
    SvgNode node, {
    double fontSize = _defaultFontSize,
    double? containerSize,
  }) {
    // First resolve any var() references
    var resolved = CssVariableResolver.resolveValue(
      value,
      node,
      fontSize: fontSize,
    );

    return resolved;
  }

  /// Resolve a CSS value to a numeric result.
  /// Handles var(), calc(), and plain numeric values.
  static double? resolveToNumber(
    String value,
    SvgNode node, {
    double fontSize = _defaultFontSize,
    double? containerSize,
  }) {
    // First resolve var() references
    final resolved = resolve(
      value,
      node,
      fontSize: fontSize,
      containerSize: containerSize,
    );

    // Then evaluate calc() or parse as number
    return CssCalcEvaluator.evaluate(
      resolved,
      fontSize: fontSize,
      containerSize: containerSize,
    );
  }
}

/// Parse custom property declarations from a style string.
/// Returns a map of property names to values.
Map<String, String> parseCustomProperties(String styleString) {
  final properties = <String, String>{};
  final matches = _customPropertyDeclarationRegex.allMatches(styleString);
  for (final match in matches) {
    final name = match.group(1)!.trim();
    final value = match.group(2)!.trim();
    properties[name] = value;
  }
  return properties;
}

/// Check if a string contains CSS variable references.
bool containsVarReference(String value) => value.contains('var(');

/// Check if a string contains calc() expressions.
bool containsCalcExpression(String value) =>
    value.toLowerCase().contains('calc(');

/// Check if a property name is a custom property (starts with --).
bool isCustomProperty(String name) => name.startsWith('--');
