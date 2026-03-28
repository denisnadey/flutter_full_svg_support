/// CSS variable resolver for walking up the element tree.
part of 'css_variables_calc.dart';

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
