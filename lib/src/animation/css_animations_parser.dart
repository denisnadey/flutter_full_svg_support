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

  /// Парсит animation-* свойства из style атрибута или строки стилей
  static CssAnimation? parseAnimationFromStyle(String styleText) {
    return _parseAnimationFromStyle(styleText);
  }
}
