part of 'css_animations.dart';

/// CSS shorthand property expansion utilities for SVG styles.
///
/// This module expands CSS shorthand properties into their longhand equivalents
/// to ensure proper inheritance and animation support.
///
/// The implementation is split across multiple part files:
/// - css_shorthand_expansion_animation.dart - animation/transition expansion
/// - css_shorthand_expansion_font.dart - font shorthand expansion
/// - css_shorthand_expansion_box.dart - box model shorthand expansion
class CssShorthandExpander {
  /// Expands all shorthand properties in a map of CSS declarations.
  ///
  /// Returns a new map with shorthand properties expanded into their
  /// longhand equivalents. Per CSS cascade rules, later declarations
  /// (whether shorthand or longhand) override earlier ones at the same
  /// specificity level.
  ///
  /// Note: This method processes declarations in map iteration order.
  /// For proper cascade behavior, use [expandAllOrdered] with a list
  /// of declarations that preserves source order.
  static Map<String, String> expandAll(Map<String, String> properties) {
    final result = <String, String>{};

    for (final entry in properties.entries) {
      final expanded = expandProperty(entry.key, entry.value);
      // Later declarations override earlier ones (cascade rule)
      for (final expandedEntry in expanded.entries) {
        result[expandedEntry.key] = expandedEntry.value;
      }
    }

    return result;
  }

  /// Expands shorthand properties while preserving declaration order.
  ///
  /// Takes a list of (property, value) pairs in declaration order.
  /// Per CSS cascade rules, later declarations override earlier ones
  /// when at the same specificity level.
  ///
  /// Example:
  /// ```dart
  /// expandAllOrdered([
  ///   ('margin', '10px 20px'),
  ///   ('margin-left', '5px'),
  /// ])
  /// // Returns: {margin-top: 10px, margin-right: 20px, margin-bottom: 10px, margin-left: 5px}
  /// ```
  static Map<String, String> expandAllOrdered(
    List<(String, String)> declarations,
  ) {
    final result = <String, String>{};

    for (final (property, value) in declarations) {
      final expanded = expandProperty(property, value);
      // Later declarations always override earlier ones
      for (final entry in expanded.entries) {
        result[entry.key] = entry.value;
      }
    }

    return result;
  }

  /// Expands a single CSS shorthand property into its longhand equivalents.
  ///
  /// Returns a map of property-value pairs. If the property is not a shorthand,
  /// returns a single-entry map with the original property.
  static Map<String, String> expandProperty(String property, String value) {
    final normalizedProperty = property.toLowerCase().trim();
    final normalizedValue = value.trim();

    switch (normalizedProperty) {
      case 'font':
        return _expandFont(normalizedValue);
      case 'animation':
        return _expandAnimation(normalizedValue);
      case 'transition':
        return _expandTransition(normalizedValue);
      case 'margin':
        return _expandBoxModel('margin', normalizedValue);
      case 'padding':
        return _expandBoxModel('padding', normalizedValue);
      case 'marker':
        return _expandMarker(normalizedValue);
      case 'border':
        return _expandBorder(normalizedValue);
      case 'border-top':
        return _expandBorderSide('top', normalizedValue);
      case 'border-right':
        return _expandBorderSide('right', normalizedValue);
      case 'border-bottom':
        return _expandBorderSide('bottom', normalizedValue);
      case 'border-left':
        return _expandBorderSide('left', normalizedValue);
      case 'border-width':
        return _expandBorderWidth(normalizedValue);
      case 'border-style':
        return _expandBorderStyle(normalizedValue);
      case 'border-color':
        return _expandBorderColor(normalizedValue);
      case 'border-radius':
        return _expandBorderRadius(normalizedValue);
      case 'background':
        return _expandBackground(normalizedValue);
      case 'offset':
        return _expandOffset(normalizedValue);
      default:
        return {normalizedProperty: normalizedValue};
    }
  }

  /// Checks if a property is a shorthand that can be expanded.
  static bool _isShorthandProperty(String property) {
    const shorthands = {
      'font',
      'animation',
      'transition',
      'margin',
      'padding',
      'marker',
      'border',
      'border-top',
      'border-right',
      'border-bottom',
      'border-left',
      'border-width',
      'border-style',
      'border-color',
      'border-radius',
      'background',
      'offset',
    };
    return shorthands.contains(property.toLowerCase().trim());
  }

  /// Checks if a property is a CSS motion path property.
  /// This includes both the standard offset-* properties and legacy motion-* properties.
  static bool isMotionProperty(String property) {
    const motionProperties = {
      // Standard offset properties
      'offset',
      'offset-path',
      'offset-distance',
      'offset-rotate',
      'offset-position',
      'offset-anchor',
      // Legacy motion properties
      'motion-path',
      'motion-offset',
      'motion-rotation',
    };
    return motionProperties.contains(property.toLowerCase().trim());
  }
}
