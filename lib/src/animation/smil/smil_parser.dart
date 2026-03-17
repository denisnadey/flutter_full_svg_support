import '../css_animations.dart';
import '../css_to_smil_converter.dart';
import '../css_variables_calc.dart';
import '../svg_dom.dart';
import 'smil_animation.dart';
import 'timing_condition.dart';
import 'timing_parser.dart';

part 'smil_parser_animation_parsing.dart';
part 'smil_parser_css_extraction.dart';
part 'smil_parser_motion.dart';

/// Парсер SMIL анимационных элементов из SVG DOM
class SmilParser {
  SmilParser._();

  /// Извлечь все SMIL анимации из документа (включая CSS анимации)
  static List<SmilAnimation> parseAnimations(SvgDocument document) {
    final animations = <SmilAnimation>[];

    // Парсим SMIL анимации (<animate>, <animateTransform>, etc.)
    _extractAnimations(document.root, document, animations);

    // Парсим CSS анимации из style атрибутов и @keyframes
    _extractCssAnimations(document.root, document, animations);

    // Парсим CSS анимации из <style> селекторов (#id, .class, tagName)
    if (document.cssSelectorRules != null) {
      _extractCssSelectorAnimations(
        document.root,
        document,
        document.cssSelectorRules!,
        animations,
      );
    }

    return animations;
  }
}
