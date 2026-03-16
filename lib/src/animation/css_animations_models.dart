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
/// animation: name duration timing-function delay iteration-count direction fill-mode;
class CssAnimation {
  final String name;
  final Duration duration;
  final String timingFunction; // ease, linear, ease-in, etc.
  final Duration delay;
  final double iterationCount; // 1.0, 2.0, or double.infinity for 'infinite'
  final String direction; // normal, reverse, alternate, alternate-reverse
  final String fillMode; // none, forwards, backwards, both

  CssAnimation({
    required this.name,
    required this.duration,
    this.timingFunction = 'ease',
    this.delay = Duration.zero,
    this.iterationCount = 1.0,
    this.direction = 'normal',
    this.fillMode = 'none',
  });
}

/// CSS rule targeting elements via selector (id, class, element, etc.).
/// Example: `#myId { animation: spin 1s; fill: red; }`
class CssSelectorRule {
  /// The raw selector string, e.g. `#myId`, `.myClass`, `circle`
  final String selector;

  /// All CSS declarations in the rule body (property → value).
  final Map<String, String> declarations;

  const CssSelectorRule({required this.selector, required this.declarations});

  /// Whether this rule targets an `id` selector.
  bool get isIdSelector => selector.startsWith('#');

  /// Whether this rule targets a `class` selector.
  bool get isClassSelector =>
      selector.startsWith('.') && !selector.contains(' ');

  /// The id value if this is an id selector (without `#`).
  String? get targetId => isIdSelector ? selector.substring(1).trim() : null;

  /// The class name if this is a class selector (without `.`).
  String? get targetClass =>
      isClassSelector ? selector.substring(1).trim() : null;

  /// Whether this rule has any animation-related declarations.
  bool get hasAnimation =>
      declarations.containsKey('animation') ||
      declarations.containsKey('animation-name');
}
