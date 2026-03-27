part of 'svg_parser.dart';

/// Парсит CSS <style> элементы и извлекает @keyframes
List<CssKeyframes> _parseStyleElements(XmlElement svgElement) {
  final keyframes = <CssKeyframes>[];

  // Ищем все <style> элементы
  final styleElements = svgElement.findElements('style');

  for (final styleElement in styleElements) {
    final cssText = styleElement.innerText;
    if (cssText.isEmpty) continue;

    // Парсим @keyframes из CSS текста
    final parsedKeyframes = CssParser.parseKeyframes(cssText);
    keyframes.addAll(parsedKeyframes);
  }

  return keyframes;
}

/// Парсит CSS <style> элементы и извлекает правила для селекторов
List<CssSelectorRule> _parseSelectorRulesElements(XmlElement svgElement) {
  final rules = <CssSelectorRule>[];

  final styleElements = svgElement.findElements('style');

  for (final styleElement in styleElements) {
    final cssText = styleElement.innerText;
    if (cssText.isEmpty) continue;

    final parsedRules = CssParser.parseSelectorRules(cssText);
    rules.addAll(parsedRules);
  }

  return rules;
}

/// Parses CSS <style> elements and extracts @font-face rules.
///
/// Extracts all @font-face blocks from embedded CSS and returns a list
/// of [CssFontFaceRule] objects containing font metadata and source.
List<CssFontFaceRule> _parseFontFaceRulesElements(XmlElement svgElement) {
  final rules = <CssFontFaceRule>[];

  final styleElements = svgElement.findElements('style');

  for (final styleElement in styleElements) {
    final cssText = styleElement.innerText;
    if (cssText.isEmpty) continue;

    final parsedRules = CssParser.parseFontFaceRules(cssText);
    rules.addAll(parsedRules);
  }

  return rules;
}
