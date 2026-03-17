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

/// Парсер SVG XML в DOM-дерево
///
/// Преобразует XML строку в структуру [SvgDocument] с деревом [SvgNode].
/// В отличие от vector_graphics_compiler, сохраняет полную DOM-структуру,
/// включая анимационные элементы (<animate>, <animateTransform>, etc.)
class SvgParser {
  SvgParser._();

  /// Парсит SVG XML строку в документ
  static SvgDocument parse(String svgXml) {
    final document = XmlDocument.parse(svgXml);
    final svgElement = document.findElements('svg').first;

    // Парсим фильтры из <defs><filter>...</filter></defs>
    final filters = _parseFilters(svgElement);

    // Парсим CSS <style> элементы для @keyframes
    final keyframes = _parseStyleElements(svgElement);

    // Парсим CSS правила для селекторов (id, class)
    final selectorRules = _parseSelectorRulesElements(svgElement);

    // Парсим корневой <svg> элемент
    final rootNode = _parseElement(svgElement);

    // Извлекаем viewBox, width, height из корневого элемента
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
    );

    // Parse and register <view> elements
    _parseViewElements(svgElement, svgDocument);

    return svgDocument;
  }

  /// Parse <view> elements and register them with the document.
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
