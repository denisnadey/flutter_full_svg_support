/// Combined CSS value resolver and utility functions.
part of 'css_variables_calc.dart';

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
    double? rootFontSize,
    Size? viewportSize,
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
  /// [rootFontSize] is used for rem units (always relative to root SVG element).
  /// [viewportSize] is used for vw/vh/vmin/vmax viewport units.
  static double? resolveToNumber(
    String value,
    SvgNode node, {
    double fontSize = _defaultFontSize,
    double? containerSize,
    double? parentFontSize,
    double? rootFontSize,
    Size? viewportSize,
  }) {
    // First resolve var() references
    final resolved = resolve(
      value,
      node,
      fontSize: fontSize,
      containerSize: containerSize,
      parentFontSize: parentFontSize,
      rootFontSize: rootFontSize,
      viewportSize: viewportSize,
    );

    // Then evaluate calc() or parse as number
    return CssCalcEvaluator.evaluate(
      resolved,
      fontSize: fontSize,
      containerSize: containerSize,
      parentFontSize: parentFontSize,
      rootFontSize: rootFontSize,
      viewportSize: viewportSize,
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
