part of 'css_animations.dart';

/// Парсер CSS для SVG
class CssParser {
  /// Парсит содержимое <style> элемента
  static List<CssKeyframes> parseKeyframes(String cssText) {
    return _parseKeyframes(cssText);
  }

  /// Парсит CSS правила с простыми селекторами (#id, .class, element).
  ///
  /// Игнорирует @-правила (including @keyframes) и многокомпонентные
  /// селекторы с пробелами (потомки, дочерние) — они слишком сложны
  /// для SVG контекста и не используются в SVGator-генерированных файлах.
  ///
  /// Возвращает список [CssSelectorRule] — по одному на каждый найденный
  /// selector-body блок. Один selector может дублироваться (cascading).
  static List<CssSelectorRule> parseSelectorRules(String cssText) {
    return _parseSelectorRules(cssText);
  }

  /// Парсит animation shorthand свойство
  /// animation: name duration timing-function delay iteration-count direction fill-mode;
  static CssAnimation? parseAnimation(String animationValue) {
    return _parseAnimation(animationValue);
  }

  /// Parse comma-separated animation values into multiple CssAnimation objects
  /// Example: "fadeIn 1s, slideUp 2s 0.5s" returns two CssAnimation objects
  static List<CssAnimation> parseMultipleAnimations(String animationValue) {
    return _parseMultipleAnimations(animationValue);
  }

  /// Парсит animation-* свойства из style атрибута или строки стилей
  static CssAnimation? parseAnimationFromStyle(String styleText) {
    return _parseAnimationFromStyle(styleText);
  }

  /// Parse multiple animations from style attribute or style string
  /// Handles both shorthand "animation" and individual "animation-*" properties
  static List<CssAnimation> parseMultipleAnimationsFromStyle(String styleText) {
    return _parseMultipleAnimationsFromStyle(styleText);
  }

  /// Parse CSS transition property
  static CssTransition? parseTransition(String transitionValue) {
    return _parseTransition(transitionValue);
  }

  /// Parse CSS transitions from style string
  static List<CssTransition> parseTransitionsFromStyle(String styleText) {
    return _parseTransitionsFromStyle(styleText);
  }

  /// Parse @media rules from CSS text
  static List<CssMediaRule> parseMediaRules(String cssText) {
    return _parseMediaRules(cssText);
  }

  /// Parses CSS properties from a string (e.g., inline style attribute).
  ///
  /// Returns a map of property names to values.
  static Map<String, String> parseProperties(String propertiesStr) {
    return _parseProperties(propertiesStr);
  }

  /// Parses CSS properties and expands shorthand properties.
  ///
  /// This handles shorthands like:
  /// - `font` → font-style, font-variant, font-weight, font-size, line-height, font-family
  /// - `animation` → animation-name, animation-duration, etc. (supports multiple animations)
  /// - `transition` → transition-property, transition-duration, etc.
  /// - `margin`/`padding` → individual side properties
  /// - `marker` → marker-start, marker-mid, marker-end (SVG-specific)
  /// - `border` → border-width, border-style, border-color
  static Map<String, String> parsePropertiesExpanded(String propertiesStr) {
    return _parsePropertiesWithShorthandExpansion(propertiesStr);
  }

  /// Expands a single shorthand property into its longhand equivalents.
  ///
  /// Returns a map of property-value pairs. If the property is not a shorthand,
  /// returns a single-entry map with the original property.
  static Map<String, String> expandShorthand(String property, String value) {
    return CssShorthandExpander.expandProperty(property, value);
  }

  /// Expands all shorthand properties in a map of declarations.
  ///
  /// Explicit longhand properties take precedence over expanded values.
  static Map<String, String> expandAllShorthands(
    Map<String, String> properties,
  ) {
    return CssShorthandExpander.expandAll(properties);
  }

  /// Parses @font-face rules from CSS text.
  ///
  /// Extracts all @font-face blocks and parses their properties into
  /// [CssFontFaceRule] objects containing font-family, src, font-weight, etc.
  static List<CssFontFaceRule> parseFontFaceRules(String cssText) {
    return extractFontFaceRules(cssText);
  }
}
