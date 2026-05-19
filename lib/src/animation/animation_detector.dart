/// Utility for quickly detecting the presence of animations in an SVG
///
/// Used by [FSvgPicture] to decide whether a document needs the animation
/// timeline at all, or can be rendered as a single static frame.
class AnimationDetector {
  AnimationDetector._();

  /// Check whether the SVG contains animations (SMIL or CSS)
  ///
  /// Uses a fast regex search to detect the presence of:
  /// - SMIL elements: `<animate>`, `<animateTransform>`, `<animateMotion>`, `<set>`
  /// - CSS animations: @keyframes, animation-* properties
  /// - CSS transitions: transition-* properties
  ///
  /// This is a heuristic check — false positives are possible (for example,
  /// if these strings appear inside comments or text content),
  /// but it works correctly for the vast majority of real SVG files.
  static bool hasAnimations(String svgXml) {
    // SMIL animations
    if (_hasSmilAnimations(svgXml)) {
      return true;
    }

    // CSS animations and transitions
    if (_hasCssAnimations(svgXml)) {
      return true;
    }

    return false;
  }

  /// Check for SMIL animations
  static bool hasSmilAnimations(String svgXml) {
    return _hasSmilAnimations(svgXml);
  }

  /// Check for CSS animations
  static bool hasCssAnimations(String svgXml) {
    return _hasCssAnimations(svgXml);
  }

  // Regex patterns for SMIL elements
  static final RegExp _animatePattern = RegExp(r'<animate[\s>]');
  static final RegExp _animateTransformPattern = RegExp(
    r'<animateTransform[\s>]',
  );
  static final RegExp _animateMotionPattern = RegExp(r'<animateMotion[\s>]');
  static final RegExp _setPattern = RegExp(r'<set[\s>]');
  static final RegExp _animateColorPattern = RegExp(
    r'<animateColor[\s>]',
  ); // deprecated, but may still appear

  // Regex patterns for CSS
  static final RegExp _keyframesPattern = RegExp(r'@keyframes\s+');
  static final RegExp _animationPropertyPattern = RegExp(
    r'animation[\s]*[:-]',
    caseSensitive: false,
  );
  static final RegExp _transitionPropertyPattern = RegExp(
    r'transition[\s]*[:-]',
    caseSensitive: false,
  );

  static bool _hasSmilAnimations(String svgXml) {
    return _animatePattern.hasMatch(svgXml) ||
        _animateTransformPattern.hasMatch(svgXml) ||
        _animateMotionPattern.hasMatch(svgXml) ||
        _setPattern.hasMatch(svgXml) ||
        _animateColorPattern.hasMatch(svgXml);
  }

  static bool _hasCssAnimations(String svgXml) {
    return _keyframesPattern.hasMatch(svgXml) ||
        _animationPropertyPattern.hasMatch(svgXml) ||
        _transitionPropertyPattern.hasMatch(svgXml);
  }

  /// Get detailed information about the animation types in the SVG
  static AnimationInfo analyzeAnimations(String svgXml) {
    return AnimationInfo(
      hasSmilAnimate: _animatePattern.hasMatch(svgXml),
      hasSmilAnimateTransform: _animateTransformPattern.hasMatch(svgXml),
      hasSmilAnimateMotion: _animateMotionPattern.hasMatch(svgXml),
      hasSmilSet: _setPattern.hasMatch(svgXml),
      hasSmilAnimateColor: _animateColorPattern.hasMatch(svgXml),
      hasCssKeyframes: _keyframesPattern.hasMatch(svgXml),
      hasCssAnimationProperty: _animationPropertyPattern.hasMatch(svgXml),
      hasCssTransitionProperty: _transitionPropertyPattern.hasMatch(svgXml),
    );
  }
}

/// Detailed information about animation types in an SVG
class AnimationInfo {
  /// Creates animation information
  const AnimationInfo({
    this.hasSmilAnimate = false,
    this.hasSmilAnimateTransform = false,
    this.hasSmilAnimateMotion = false,
    this.hasSmilSet = false,
    this.hasSmilAnimateColor = false,
    this.hasCssKeyframes = false,
    this.hasCssAnimationProperty = false,
    this.hasCssTransitionProperty = false,
  });

  /// Whether there are `<animate>` elements
  final bool hasSmilAnimate;

  /// Whether there are `<animateTransform>` elements
  final bool hasSmilAnimateTransform;

  /// Whether there are `<animateMotion>` elements
  final bool hasSmilAnimateMotion;

  /// Whether there are `<set>` elements
  final bool hasSmilSet;

  /// Whether there are `<animateColor>` elements (deprecated)
  final bool hasSmilAnimateColor;

  /// Whether there are @keyframes in `<style>`
  final bool hasCssKeyframes;

  /// Whether there are CSS animation-* properties
  final bool hasCssAnimationProperty;

  /// Whether there are CSS transition-* properties
  final bool hasCssTransitionProperty;

  /// Whether there are any SMIL animations
  bool get hasAnySmil =>
      hasSmilAnimate ||
      hasSmilAnimateTransform ||
      hasSmilAnimateMotion ||
      hasSmilSet ||
      hasSmilAnimateColor;

  /// Whether there are any CSS animations
  bool get hasAnyCss =>
      hasCssKeyframes || hasCssAnimationProperty || hasCssTransitionProperty;

  /// Whether there are any animations at all
  bool get hasAny => hasAnySmil || hasAnyCss;

  @override
  String toString() {
    final parts = <String>[];
    if (hasSmilAnimate) parts.add('animate');
    if (hasSmilAnimateTransform) parts.add('animateTransform');
    if (hasSmilAnimateMotion) parts.add('animateMotion');
    if (hasSmilSet) parts.add('set');
    if (hasSmilAnimateColor) parts.add('animateColor');
    if (hasCssKeyframes) parts.add('CSS @keyframes');
    if (hasCssAnimationProperty) parts.add('CSS animation');
    if (hasCssTransitionProperty) parts.add('CSS transition');

    return 'AnimationInfo(${parts.isEmpty ? 'none' : parts.join(', ')})';
  }
}
