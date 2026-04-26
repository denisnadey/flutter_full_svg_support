part of 'svg_parser.dart';

/// Parses CSS <style> elements and extracts @keyframes
List<CssKeyframes> _parseStyleElements(XmlElement svgElement) {
  final keyframes = <CssKeyframes>[];

  // Find all <style> elements in the entire document (including <defs> and nested groups)
  final styleElements = svgElement.findAllElements('style');

  for (final styleElement in styleElements) {
    final cssText = styleElement.innerText;
    if (cssText.isEmpty) continue;

    // Parse @keyframes from the CSS text
    final parsedKeyframes = CssParser.parseKeyframes(cssText);
    keyframes.addAll(parsedKeyframes);
  }

  return keyframes;
}

/// Parses CSS <style> elements and extracts selector rules
List<CssSelectorRule> _parseSelectorRulesElements(XmlElement svgElement) {
  final rules = <CssSelectorRule>[];

  final styleElements = svgElement.findAllElements('style');

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

  final styleElements = svgElement.findAllElements('style');

  for (final styleElement in styleElements) {
    final cssText = styleElement.innerText;
    if (cssText.isEmpty) continue;

    final parsedRules = CssParser.parseFontFaceRules(cssText);
    rules.addAll(parsedRules);
  }

  return rules;
}
