import 'dart:ui';

import '../css_animations.dart';
import '../css_to_smil_converter.dart';
import '../css_variables_calc.dart';
import '../svg_dom.dart';
import 'motion_path.dart';
import 'smil_animation.dart';
import 'timing_condition.dart';
import 'timing_parser.dart';

part 'smil_parser_animation_parsing.dart';
part 'smil_parser_css_extraction.dart';
part 'smil_parser_motion.dart';

/// Parser for SMIL animation elements from SVG DOM
class SmilParser {
  SmilParser._();

  /// Extract all SMIL animations from the document (including CSS animations)
  static List<SmilAnimation> parseAnimations(SvgDocument document) {
    final animations = <SmilAnimation>[];

    // Parse SMIL animations (<animate>, <animateTransform>, etc.)
    _extractAnimations(document.root, document, animations);

    // Parse CSS animations from style attributes and @keyframes
    _extractCssAnimations(document.root, document, animations);

    // Parse CSS animations from <style> selectors (#id, .class, tagName)
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
