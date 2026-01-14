/// Утилита для быстрого определения наличия анимаций в SVG
///
/// Используется для выбора между быстрым статичным pipeline (vector_graphics)
/// и полноценным анимационным pipeline с DOM-деревом.
class AnimationDetector {
  AnimationDetector._();

  /// Проверить, содержит ли SVG анимации (SMIL или CSS)
  ///
  /// Использует быстрый regex-поиск для определения наличия:
  /// - SMIL элементов: <animate>, <animateTransform>, <animateMotion>, <set>
  /// - CSS анимаций: @keyframes, animation-* свойства
  /// - CSS transitions: transition-* свойства
  ///
  /// Это эвристическая проверка — false positives возможны (например,
  /// если эти строки встречаются в комментариях или текстовом контенте),
  /// но для большинства реальных SVG файлов работает корректно.
  static bool hasAnimations(String svgXml) {
    // SMIL анимации
    if (_hasSmilAnimations(svgXml)) {
      return true;
    }

    // CSS анимации и transitions
    if (_hasCssAnimations(svgXml)) {
      return true;
    }

    return false;
  }

  /// Проверить наличие SMIL анимаций
  static bool hasSmilAnimations(String svgXml) {
    return _hasSmilAnimations(svgXml);
  }

  /// Проверить наличие CSS анимаций
  static bool hasCssAnimations(String svgXml) {
    return _hasCssAnimations(svgXml);
  }

  // Regex паттерны для SMIL элементов
  static final RegExp _animatePattern = RegExp(r'<animate[\s>]');
  static final RegExp _animateTransformPattern = RegExp(
    r'<animateTransform[\s>]',
  );
  static final RegExp _animateMotionPattern = RegExp(r'<animateMotion[\s>]');
  static final RegExp _setPattern = RegExp(r'<set[\s>]');
  static final RegExp _animateColorPattern = RegExp(
    r'<animateColor[\s>]',
  ); // deprecated, но может встречаться

  // Regex паттерны для CSS
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

  /// Получить детальную информацию о типах анимаций в SVG
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

/// Детальная информация о типах анимаций в SVG
class AnimationInfo {
  /// Создаёт информацию об анимациях
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

  /// Есть ли <animate> элементы
  final bool hasSmilAnimate;

  /// Есть ли <animateTransform> элементы
  final bool hasSmilAnimateTransform;

  /// Есть ли <animateMotion> элементы
  final bool hasSmilAnimateMotion;

  /// Есть ли <set> элементы
  final bool hasSmilSet;

  /// Есть ли <animateColor> элементы (deprecated)
  final bool hasSmilAnimateColor;

  /// Есть ли @keyframes в <style>
  final bool hasCssKeyframes;

  /// Есть ли CSS animation-* свойства
  final bool hasCssAnimationProperty;

  /// Есть ли CSS transition-* свойства
  final bool hasCssTransitionProperty;

  /// Есть ли любые SMIL анимации
  bool get hasAnySmil =>
      hasSmilAnimate ||
      hasSmilAnimateTransform ||
      hasSmilAnimateMotion ||
      hasSmilSet ||
      hasSmilAnimateColor;

  /// Есть ли любые CSS анимации
  bool get hasAnyCss =>
      hasCssKeyframes || hasCssAnimationProperty || hasCssTransitionProperty;

  /// Есть ли любые анимации вообще
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
