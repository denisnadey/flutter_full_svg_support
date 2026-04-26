import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:xml/xml.dart';

import 'css_animations.dart';
import 'css_named_colors.dart';
import 'svg_dom.dart';
import 'svg_filters.dart';

part 'svg_parser_constants.dart';
part 'svg_parser_values.dart';
part 'svg_parser_color.dart';
part 'svg_parser_css.dart';
part 'svg_parser_elements.dart';
part 'svg_parser_filters.dart';
part 'svg_parser_filters_primitives.dart';
part 'svg_parser_filters_primitives_advanced.dart';
part 'svg_parser_filters_lighting.dart';
part 'svg_parser_filters_utils.dart';

/// SVG XML parser that builds a DOM tree
///
/// Converts an XML string into an [SvgDocument] structure with an [SvgNode] tree.
/// Unlike vector_graphics_compiler, it preserves the full DOM structure,
/// including animation elements (`<animate>`, `<animateTransform>`, etc.)
class SvgParser {
  SvgParser._();

  /// Parses an SVG XML string into a document
  static SvgDocument parse(String svgXml) {
    final document = XmlDocument.parse(svgXml);
    final svgElement = document.findElements('svg').first;

    // Parse filters from <defs><filter>...</filter></defs>
    final filters = _parseFilters(svgElement);

    // Parse CSS <style> elements for @keyframes
    final keyframes = _parseStyleElements(svgElement);

    // Parse CSS rules for selectors (id, class)
    final selectorRules = _parseSelectorRulesElements(svgElement);

    // Parse @font-face rules for embedded fonts
    final fontFaceRules = _parseFontFaceRulesElements(svgElement);

    // Parse the root <svg> element
    final rootNode = _parseElement(svgElement);

    // Link filter primitives to their DOM SvgNodes for animated attribute access
    _linkFilterPrimitivesToNodes(rootNode, filters);

    // Extract viewBox, width, height from the root element
    final viewBox = _parseViewBox(svgElement.getAttribute('viewBox'));
    final width = _parseLength(svgElement.getAttribute('width'));
    final height = _parseLength(svgElement.getAttribute('height'));

    final svgDocument = SvgDocument(
      root: rootNode,
      viewBox: viewBox,
      width: width,
      height: height,
      filters: filters,
      cssKeyframes: keyframes,
      cssSelectorRules: selectorRules,
      cssFontFaceRules: fontFaceRules.isEmpty ? null : fontFaceRules,
    );

    // Parse and register <view> elements
    _parseViewElements(svgElement, svgDocument);

    return svgDocument;
  }

  /// Parse `<view>` elements and register them with the document.
  static void _parseViewElements(XmlElement svgElement, SvgDocument document) {
    // Find all <view> elements in the document
    final viewElements = svgElement.findAllElements('view');
    for (final viewElement in viewElements) {
      final id = viewElement.getAttribute('id');
      final viewBoxAttr = viewElement.getAttribute('viewBox');
      final preserveAspectRatio = viewElement.getAttribute(
        'preserveAspectRatio',
      );

      if (id != null && id.isNotEmpty) {
        final viewBox = _parseViewBox(viewBoxAttr);
        final view = SvgViewElement(
          id: id,
          viewBox: viewBox,
          preserveAspectRatio: preserveAspectRatio,
        );
        document.registerView(view);
      }
    }

    // Also check <defs> for <view> elements
    final defsElements = svgElement.findAllElements('defs');
    for (final defs in defsElements) {
      final viewElements = defs.findAllElements('view');
      for (final viewElement in viewElements) {
        final id = viewElement.getAttribute('id');
        final viewBoxAttr = viewElement.getAttribute('viewBox');
        final preserveAspectRatio = viewElement.getAttribute(
          'preserveAspectRatio',
        );

        if (id != null && id.isNotEmpty) {
          final viewBox = _parseViewBox(viewBoxAttr);
          final view = SvgViewElement(
            id: id,
            viewBox: viewBox,
            preserveAspectRatio: preserveAspectRatio,
          );
          document.registerView(view);
        }
      }
    }
  }
}
