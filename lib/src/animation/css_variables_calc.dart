/// CSS custom properties (variables) and calc() expression support.
library;

import 'svg_dom.dart';

/// Callback type for looking up custom properties from use context.
/// This enables CSS variables to flow through <use> boundaries.
typedef UseContextCustomPropertyLookup = String? Function(String name);

/// Global hook for use context custom property lookup.
/// Set by the render tree when inside a <use> boundary.
/// Made public for access from part files.
UseContextCustomPropertyLookup? useContextCustomPropertyLookup;

/// Regex to match CSS custom property declarations: --property-name: value
final RegExp _customPropertyDeclarationRegex = RegExp(
  r'(--[\w-]+)\s*:\s*([^;]+)',
  caseSensitive: false,
);

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
  /// Optional CSS cascade resolver for rule-based variable lookup.
  /// When set, variables defined in CSS rules will also be considered.
  static CssVariablesCascadeResolver? cascadeResolver;

  /// Resolve a CSS value that may contain var() references.
  /// Walks up the node tree to find variable definitions.
  /// Supports var(--name) and var(--name, fallback).
  /// Supports nested fallbacks: var(--x, var(--y, default)).
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
    // Use a more robust regex that handles nested var() in fallback
    return _replaceVarCalls(value, (varName, fallback) {
      // Walk up the tree to find the variable
      final resolvedValue = _lookupVariable(varName, node);

      if (resolvedValue != null) {
        // If resolved value contains var(), it will be resolved in next iteration
        return resolvedValue;
      } else if (fallback != null) {
        // Use fallback if variable not found
        // The fallback may itself contain var() which will be resolved in next pass
        return fallback;
      } else {
        // Variable not found and no fallback - return empty
        return '';
      }
    });
  }

  /// Replace var() calls handling nested parentheses properly.
  static String _replaceVarCalls(
    String value,
    String Function(String varName, String? fallback) replacer,
  ) {
    final result = StringBuffer();
    var i = 0;

    while (i < value.length) {
      // Look for var(
      final varStart = value.indexOf('var(', i);
      if (varStart == -1) {
        result.write(value.substring(i));
        break;
      }

      // Add text before var(
      result.write(value.substring(i, varStart));

      // Find matching closing paren
      var depth = 1;
      var pos = varStart + 4;
      var commaPos = -1;

      while (pos < value.length && depth > 0) {
        if (value[pos] == '(') {
          depth++;
        } else if (value[pos] == ')') {
          depth--;
        } else if (value[pos] == ',' && depth == 1 && commaPos == -1) {
          commaPos = pos;
        }
        if (depth > 0) pos++;
      }

      if (depth == 0) {
        // Parse var name and fallback
        final content = value.substring(varStart + 4, pos);
        String varName;
        String? fallback;

        if (commaPos != -1) {
          varName = value.substring(varStart + 4, commaPos).trim();
          fallback = value.substring(commaPos + 1, pos).trim();
        } else {
          varName = content.trim();
        }

        result.write(replacer(varName, fallback));
        i = pos + 1;
      } else {
        // Malformed var() - just copy as-is
        result.write(value.substring(varStart, varStart + 4));
        i = varStart + 4;
      }
    }

    return result.toString();
  }

  /// Look up a custom property by walking up the element tree.
  /// Checks in order:
  /// 1. Inline style custom properties on the element and ancestors
  /// 2. CSS rules from style blocks (via cascade resolver)
  /// 3. Use inheritance context for properties defined on <use> elements
  static String? _lookupVariable(String name, SvgNode node) {
    // Check inline custom properties first (highest specificity)
    SvgNode? current = node;
    while (current != null) {
      final props = current.cssCustomProperties;
      if (props.has(name)) {
        return props.get(name);
      }
      current = current.parent;
    }

    // Check CSS cascade resolver for rule-based custom properties
    if (cascadeResolver != null) {
      final ruleValue = cascadeResolver!.resolveCustomProperty(name, node);
      if (ruleValue != null) {
        return ruleValue;
      }
    }

    // Check use inheritance context for CSS custom properties.
    // Per SVG spec, custom properties should cascade through <use> boundaries.
    if (useContextCustomPropertyLookup != null) {
      final useValue = useContextCustomPropertyLookup!(name);
      if (useValue != null) {
        return useValue;
      }
    }

    return null;
  }
}

/// Interface for CSS cascade-based custom property resolution.
/// This allows integration with the CSS rule matching system.
abstract class CssVariablesCascadeResolver {
  /// Resolve a custom property value from CSS rules for the given node.
  /// Returns null if not defined.
  String? resolveCustomProperty(String name, SvgNode node);
}

/// calc() expression parser and evaluator.
class CssCalcEvaluator {
  /// Evaluate a calc() expression to a numeric value.
  /// Returns null if evaluation fails.
  ///
  /// [value] - The string potentially containing calc()
  /// [fontSize] - Current font size for em/rem units
  /// [containerSize] - Container size for percentage calculations (optional)
  /// [parentFontSize] - Parent element's font size for em inheritance
  static double? evaluate(
    String value, {
    double fontSize = _defaultFontSize,
    double? containerSize,
    double? parentFontSize,
  }) {
    final trimmed = value.trim();
    final lower = trimmed.toLowerCase();

    // Check for CSS math functions first
    if (lower.startsWith('clamp(')) {
      return _evaluateClamp(
        trimmed,
        fontSize: fontSize,
        containerSize: containerSize,
        parentFontSize: parentFontSize,
      );
    }

    if (lower.startsWith('min(')) {
      return _evaluateMin(
        trimmed,
        fontSize: fontSize,
        containerSize: containerSize,
        parentFontSize: parentFontSize,
      );
    }

    if (lower.startsWith('max(')) {
      return _evaluateMax(
        trimmed,
        fontSize: fontSize,
        containerSize: containerSize,
        parentFontSize: parentFontSize,
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
      parentFontSize: parentFontSize,
    );
  }

  /// Evaluate a clamp(min, val, max) expression.
  /// clamp(MIN, VAL, MAX) is equivalent to max(MIN, min(VAL, MAX))
  static double? _evaluateClamp(
    String expr, {
    required double fontSize,
    double? containerSize,
    double? parentFontSize,
  }) {
    final content = _extractFunctionContent(expr, 'clamp');
    if (content == null) return null;

    final args = _splitFunctionArgs(content);
    if (args.length != 3) return null;

    final minVal = evaluate(
      args[0],
      fontSize: fontSize,
      containerSize: containerSize,
      parentFontSize: parentFontSize,
    );
    final val = evaluate(
      args[1],
      fontSize: fontSize,
      containerSize: containerSize,
      parentFontSize: parentFontSize,
    );
    final maxVal = evaluate(
      args[2],
      fontSize: fontSize,
      containerSize: containerSize,
      parentFontSize: parentFontSize,
    );

    if (minVal == null || val == null || maxVal == null) return null;

    // clamp(min, val, max) = max(min, min(val, max))
    return val.clamp(minVal, maxVal);
  }

  /// Evaluate a min(...) expression - returns the smallest value.
  static double? _evaluateMin(
    String expr, {
    required double fontSize,
    double? containerSize,
    double? parentFontSize,
  }) {
    final content = _extractFunctionContent(expr, 'min');
    if (content == null) return null;

    final args = _splitFunctionArgs(content);
    if (args.isEmpty) return null;

    double? result;
    for (final arg in args) {
      final val = evaluate(
        arg,
        fontSize: fontSize,
        containerSize: containerSize,
        parentFontSize: parentFontSize,
      );
      if (val == null) return null;
      if (result == null || val < result) {
        result = val;
      }
    }

    return result;
  }

  /// Evaluate a max(...) expression - returns the largest value.
  static double? _evaluateMax(
    String expr, {
    required double fontSize,
    double? containerSize,
    double? parentFontSize,
  }) {
    final content = _extractFunctionContent(expr, 'max');
    if (content == null) return null;

    final args = _splitFunctionArgs(content);
    if (args.isEmpty) return null;

    double? result;
    for (final arg in args) {
      final val = evaluate(
        arg,
        fontSize: fontSize,
        containerSize: containerSize,
        parentFontSize: parentFontSize,
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

  /// Evaluate an expression string.
  static double? _evaluateExpression(
    String expr, {
    required double fontSize,
    double? containerSize,
    double? parentFontSize,
  }) {
    // First, handle nested calc() expressions and math functions
    var resolved = _resolveNestedFunctions(
      expr,
      fontSize: fontSize,
      containerSize: containerSize,
      parentFontSize: parentFontSize,
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
    );
  }

  /// Resolve nested calc(), min(), max(), clamp() expressions recursively.
  static String? _resolveNestedFunctions(
    String expr, {
    required double fontSize,
    double? containerSize,
    double? parentFontSize,
  }) {
    var result = expr;
    var iterations = 0;
    const maxIterations = 10;

    // Handle all CSS math functions: calc(), min(), max(), clamp()
    final funcRegex = RegExp(r'(calc|min|max|clamp)\(', caseSensitive: false);

    while (funcRegex.hasMatch(result) && iterations < maxIterations) {
      final match = funcRegex.firstMatch(result);
      if (match == null) break;

      final funcName = match.group(1)!.toLowerCase();
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

      final fullExpr = result.substring(start, end);
      double? nestedValue;

      if (funcName == 'calc') {
        final nestedExpr = result.substring(match.end, end - 1);
        nestedValue = _evaluateExpression(
          nestedExpr,
          fontSize: fontSize,
          containerSize: containerSize,
          parentFontSize: parentFontSize,
        );
      } else {
        // min, max, clamp - use the full evaluation
        nestedValue = evaluate(
          fullExpr,
          fontSize: fontSize,
          containerSize: containerSize,
          parentFontSize: parentFontSize,
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
  ///
  /// [parentFontSize] is used for em units in the context where an element's
  /// font-size is being computed (em is relative to parent, not current).
  static double? _parseNumericValue(
    String value, {
    required double fontSize,
    double? containerSize,
    double? parentFontSize,
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
        return num * _defaultFontSize;
      case 'ex':
        // ex is approximately 0.5em (x-height of the font)
        return num * (parentFontSize ?? fontSize) * 0.5;
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

/// Combined resolver for CSS values with var() and calc() support.
class CssValueResolver {
  /// Resolve a CSS value that may contain var() and/or calc().
  /// Returns the resolved string value.
  static String resolve(
    String value,
    SvgNode node, {
    double fontSize = _defaultFontSize,
    double? containerSize,
    double? parentFontSize,
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
  /// Handles var(), calc(), min(), max(), clamp() and plain numeric values.
  ///
  /// [parentFontSize] is used when computing font-size values where em
  /// should be relative to the parent element's font-size.
  static double? resolveToNumber(
    String value,
    SvgNode node, {
    double fontSize = _defaultFontSize,
    double? containerSize,
    double? parentFontSize,
  }) {
    // First resolve var() references
    final resolved = resolve(
      value,
      node,
      fontSize: fontSize,
      containerSize: containerSize,
      parentFontSize: parentFontSize,
    );

    // Then evaluate calc() or parse as number
    return CssCalcEvaluator.evaluate(
      resolved,
      fontSize: fontSize,
      containerSize: containerSize,
      parentFontSize: parentFontSize,
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

/// Check if a string contains CSS math functions (calc, min, max, clamp).
bool containsCssMathFunction(String value) {
  final lower = value.toLowerCase();
  return lower.contains('calc(') ||
      lower.contains('min(') ||
      lower.contains('max(') ||
      lower.contains('clamp(');
}

/// Check if a property name is a custom property (starts with --).
bool isCustomProperty(String name) => name.startsWith('--');
