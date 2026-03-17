part of 'css_animations.dart';

/// CSS Keyframe правило
class CssKeyframe {
  final double offset; // 0.0 - 1.0
  final Map<String, String> properties;

  /// Per-keyframe timing function override (animation-timing-function in keyframe body).
  /// Applies to the interval starting at this keyframe. null means use animation-level default.
  final String? timingFunction;

  CssKeyframe({
    required this.offset,
    required this.properties,
    this.timingFunction,
  });
}

/// CSS @keyframes анимация
class CssKeyframes {
  final String name;
  final List<CssKeyframe> keyframes;

  CssKeyframes({required this.name, required this.keyframes});
}

/// CSS Animation свойство (shorthand)
/// animation: name duration timing-function delay iteration-count direction fill-mode play-state;
class CssAnimation {
  final String name;
  final Duration duration;
  final String timingFunction; // ease, linear, ease-in, etc.
  final Duration delay;
  final double iterationCount; // 1.0, 2.0, or double.infinity for 'infinite'
  final String direction; // normal, reverse, alternate, alternate-reverse
  final String fillMode; // none, forwards, backwards, both
  final String playState; // running, paused

  CssAnimation({
    required this.name,
    required this.duration,
    this.timingFunction = 'ease',
    this.delay = Duration.zero,
    this.iterationCount = 1.0,
    this.direction = 'normal',
    this.fillMode = 'none',
    this.playState = 'running',
  });

  /// Returns true if the animation is paused
  bool get isPaused => playState.toLowerCase() == 'paused';
}

/// CSS rule targeting elements via selector (id, class, element, etc.).
/// Example: `#myId { animation: spin 1s; fill: red; }`
class CssSelectorRule {
  /// The raw selector string, e.g. `#myId`, `.myClass`, `circle`
  final String selector;

  /// Parsed CSS selector (lazily computed)
  CssSelector? _parsedSelector;

  /// All CSS declarations in the rule body (property → value).
  final Map<String, String> declarations;

  CssSelectorRule({required this.selector, required this.declarations});

  /// Get the parsed CSS selector
  CssSelector? get parsedSelector {
    _parsedSelector ??= _parseCssSelector(selector);
    return _parsedSelector;
  }

  /// Whether this rule targets an `id` selector.
  bool get isIdSelector => selector.startsWith('#');

  /// Whether this rule targets a `class` selector.
  bool get isClassSelector =>
      selector.startsWith('.') && !selector.contains(' ');

  /// Whether this selector has combinators (space, >, +, ~)
  bool get hasCombinators {
    final parsed = parsedSelector;
    return parsed != null && !parsed.isSimple;
  }

  /// The id value if this is an id selector (without `#`).
  String? get targetId => isIdSelector ? selector.substring(1).trim() : null;

  /// The class name if this is a class selector (without `.`).
  String? get targetClass =>
      isClassSelector ? selector.substring(1).trim() : null;

  /// Whether this rule has any animation-related declarations.
  bool get hasAnimation =>
      declarations.containsKey('animation') ||
      declarations.containsKey('animation-name');

  /// Whether this rule has any transition-related declarations.
  bool get hasTransition =>
      declarations.containsKey('transition') ||
      declarations.containsKey('transition-property');
}

/// CSS Transition property
class CssTransition {
  final String
  property; // property name to transition (e.g., 'opacity', 'transform', 'all')
  final Duration duration;
  final String timingFunction;
  final Duration delay;

  CssTransition({
    required this.property,
    required this.duration,
    this.timingFunction = 'ease',
    this.delay = Duration.zero,
  });
}

/// CSS @media rule
class CssMediaRule {
  final String
  query; // raw media query string (e.g., '(prefers-color-scheme: dark)')
  final List<CssSelectorRule> rules; // CSS rules within this @media block
  final CssMediaCondition? condition; // parsed condition for evaluation

  CssMediaRule({required this.query, required this.rules, this.condition});
}

/// Parsed media query condition for evaluation
class CssMediaCondition {
  final CssMediaFeature feature;
  final String? value;
  final double? numericValue;
  final String? unit;

  CssMediaCondition({
    required this.feature,
    this.value,
    this.numericValue,
    this.unit,
  });

  /// Evaluate this condition against the given context
  bool evaluate(CssMediaContext context) {
    switch (feature) {
      case CssMediaFeature.prefersColorScheme:
        return value?.toLowerCase() == (context.isDarkMode ? 'dark' : 'light');
      case CssMediaFeature.minWidth:
        if (numericValue == null) return false;
        return context.viewportWidth >= _convertToPixels(numericValue!, unit);
      case CssMediaFeature.maxWidth:
        if (numericValue == null) return false;
        return context.viewportWidth <= _convertToPixels(numericValue!, unit);
      case CssMediaFeature.minHeight:
        if (numericValue == null) return false;
        return context.viewportHeight >= _convertToPixels(numericValue!, unit);
      case CssMediaFeature.maxHeight:
        if (numericValue == null) return false;
        return context.viewportHeight <= _convertToPixels(numericValue!, unit);
      case CssMediaFeature.unknown:
        return false;
    }
  }

  double _convertToPixels(double value, String? unit) {
    switch (unit?.toLowerCase()) {
      case 'px':
      case null:
      case '':
        return value;
      case 'em':
      case 'rem':
        return value * 16; // Assume 16px base font size
      case 'vw':
        return value; // Already in viewport units
      case 'vh':
        return value;
      default:
        return value;
    }
  }
}

/// Supported CSS media features
enum CssMediaFeature {
  prefersColorScheme,
  minWidth,
  maxWidth,
  minHeight,
  maxHeight,
  unknown,
}

/// Context for evaluating media queries
class CssMediaContext {
  final double viewportWidth;
  final double viewportHeight;
  final bool isDarkMode;

  CssMediaContext({
    required this.viewportWidth,
    required this.viewportHeight,
    this.isDarkMode = false,
  });
}
