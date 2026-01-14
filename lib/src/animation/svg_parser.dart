import 'dart:ui' as ui;

import 'package:xml/xml.dart';

import 'css_animations.dart';
import 'svg_dom.dart';
import 'svg_filters.dart';

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
    );
    
    return svgDocument;
  }

  /// Парсит фильтры из <defs><filter> элементов
  static SvgFilters _parseFilters(XmlElement svgElement) {
    final filters = SvgFilters();
    
    // Ищем <defs> элемент
    final defsElements = svgElement.findElements('defs');
    if (defsElements.isEmpty) {
      return filters;
    }
    
    final defs = defsElements.first;
    
    // Ищем все <filter> элементы
    for (final filterElement in defs.findElements('filter')) {
      final filterId = filterElement.getAttribute('id');
      if (filterId == null || filterId.isEmpty) {
        continue; // Фильтр без ID не может быть использован
      }
      
      // Парсим примитивы фильтра (feGaussianBlur, feDropShadow, etc.)
      for (final child in filterElement.childElements) {
        final filter = _parseFilterPrimitive(child, filterId);
        if (filter != null) {
          filters.add(filter);
        }
      }
    }
    
    return filters;
  }

  /// Парсит примитив фильтра (feGaussianBlur, feDropShadow, feColorMatrix)
  static SvgFilter? _parseFilterPrimitive(XmlElement element, String filterId) {
    final tagName = element.name.local;
    
    switch (tagName) {
      case 'feGaussianBlur':
        return _parseGaussianBlur(element, filterId);
      case 'feDropShadow':
        return _parseDropShadow(element, filterId);
      case 'feColorMatrix':
        return _parseColorMatrix(element, filterId);
      default:
        // Другие фильтры пока не поддерживаются
        return null;
    }
  }

  /// Парсит feGaussianBlur элемент
  static SvgGaussianBlurFilter _parseGaussianBlur(
    XmlElement element,
    String filterId,
  ) {
    final stdDeviationStr = element.getAttribute('stdDeviation') ?? '0';
    final stdDeviation = _parseNumberOptionalNumber(stdDeviationStr);
    
    return SvgGaussianBlurFilter(
      id: filterId,
      stdDeviationX: stdDeviation.$1,
      stdDeviationY: stdDeviation.$2,
    );
  }

  /// Парсит feDropShadow элемент
  static SvgDropShadowFilter _parseDropShadow(
    XmlElement element,
    String filterId,
  ) {
    final dx = _parseNumber(element.getAttribute('dx') ?? '2');
    final dy = _parseNumber(element.getAttribute('dy') ?? '2');
    final stdDeviationStr = element.getAttribute('stdDeviation') ?? '2';
    final stdDeviation = _parseNumberOptionalNumber(stdDeviationStr);
    final stdDev = stdDeviation.$1; // Используем X значение
    
    // Парсим flood-color
    final floodColorStr = element.getAttribute('flood-color') ??
        element.getAttribute('floodColor') ??
        'black';
    final parsedColor = _parseColor(floodColorStr);
    final color = parsedColor is ui.Color ? parsedColor : null;
    
    return SvgDropShadowFilter(
      id: filterId,
      dx: dx,
      dy: dy,
      stdDeviation: stdDev,
      floodColor: color,
    );
  }

  /// Парсит feColorMatrix элемент
  static SvgColorMatrixFilter _parseColorMatrix(
    XmlElement element,
    String filterId,
  ) {
    final typeStr = element.getAttribute('type') ?? 'matrix';
    final valuesStr = element.getAttribute('values') ?? '';
    
    SvgColorMatrixType matrixType;
    switch (typeStr.toLowerCase()) {
      case 'saturate':
        matrixType = SvgColorMatrixType.saturate;
        break;
      case 'huerotate':
      case 'hueRotate':
        matrixType = SvgColorMatrixType.hueRotate;
        break;
      case 'luminancetoalpha':
      case 'luminanceToAlpha':
        matrixType = SvgColorMatrixType.luminanceToAlpha;
        break;
      case 'matrix':
      default:
        matrixType = SvgColorMatrixType.matrix;
        break;
    }
    
    // Парсим values
    final values = valuesStr
        .split(RegExp(r'[\s,]+'))
        .map((s) => double.tryParse(s.trim()))
        .whereType<double>()
        .toList();
    
    return SvgColorMatrixFilter(
      id: filterId,
      matrixType: matrixType,
      values: values,
    );
  }

  /// Парсит CSS <style> элементы и извлекает @keyframes
  static List<CssKeyframes> _parseStyleElements(XmlElement svgElement) {
    final keyframes = <CssKeyframes>[];
    
    // Ищем все <style> элементы
    final styleElements = svgElement.findElements('style');
    
    for (final styleElement in styleElements) {
      final cssText = styleElement.text;
      if (cssText.isEmpty) continue;
      
      // Парсим @keyframes из CSS текста
      final parsedKeyframes = CssParser.parseKeyframes(cssText);
      keyframes.addAll(parsedKeyframes);
    }
    
    return keyframes;
  }

  /// Парсит число или пару чисел (например "5" или "5 10")
  static (double, double) _parseNumberOptionalNumber(String value) {
    final parts = value
        .trim()
        .split(RegExp(r'[\s,]+'))
        .map((s) => double.tryParse(s))
        .whereType<double>()
        .toList();
    
    if (parts.isEmpty) {
      return (0.0, 0.0);
    } else if (parts.length == 1) {
      return (parts[0], parts[0]);
    } else {
      return (parts[0], parts[1]);
    }
  }

  /// Парсит XML элемент в SvgNode
  static SvgNode _parseElement(XmlElement element) {
    final tagName = element.name.local;
    final id = element.getAttribute('id');
    final className = element.getAttribute('class');

    final node = SvgNode(tagName: tagName, id: id, className: className);

    // Парсим атрибуты
    for (final attr in element.attributes) {
      final attrName = attr.name.local;
      final attrValue = attr.value;

      // Пропускаем специальные атрибуты, которые уже обработаны
      if (attrName == 'id' || attrName == 'class') {
        continue;
      }

      // Определяем тип атрибута и парсим значение
      // Для анимационных элементов fill - это режим заполнения, не цвет
      final isAnimationElement = _isAnimationElement(tagName);
      final attributeType = _inferAttributeType(attrName, isAnimationElement);
      final parsedValue = _parseAttributeValue(attrValue, attributeType);

      node.setAttribute(attrName, parsedValue, type: attributeType);
    }

    // Рекурсивно парсим дочерние элементы
    for (final child in element.childElements) {
      // Пропускаем <style> элементы - они обрабатываются отдельно
      if (child.name.local == 'style') {
        continue; // CSS parsing будет позже
      }
      final childNode = _parseElement(child);
      node.addChild(childNode);
    }

    return node;
  }

  /// Определяет тип атрибута по его имени
  static SvgAttributeType _inferAttributeType(
    String attributeName, [
    bool isAnimationElement = false,
  ]) {
    // Для анимационных элементов fill/calcMode/etc - это строки, не цвета
    if (isAnimationElement &&
        (attributeName == 'fill' ||
            attributeName == 'calcMode' ||
            attributeName == 'additive' ||
            attributeName == 'accumulate')) {
      return SvgAttributeType.string;
    }

    // Числовые атрибуты
    if (_numericAttributes.contains(attributeName)) {
      return SvgAttributeType.number;
    }

    // Цветовые атрибуты
    if (_colorAttributes.contains(attributeName)) {
      return SvgAttributeType.color;
    }

    // Трансформации
    if (attributeName == 'transform') {
      return SvgAttributeType.transform;
    }

    // Path данные
    if (attributeName == 'd') {
      return SvgAttributeType.path;
    }

    // Points для polygon/polyline
    if (attributeName == 'points') {
      return SvgAttributeType.points;
    }

    // URL ссылки
    if (_urlAttributes.contains(attributeName)) {
      return SvgAttributeType.url;
    }

    // По умолчанию — строка
    return SvgAttributeType.string;
  }

  /// Парсит значение атрибута в соответствующий тип
  static Object _parseAttributeValue(String value, SvgAttributeType type) {
    switch (type) {
      case SvgAttributeType.number:
        return _parseNumber(value);
      case SvgAttributeType.color:
        return _parseColor(value);
      case SvgAttributeType.transform:
      case SvgAttributeType.path:
      case SvgAttributeType.points:
      case SvgAttributeType.string:
      case SvgAttributeType.url:
      case SvgAttributeType.list:
      case SvgAttributeType.length:
        // Пока возвращаем как строку, парсинг будет позже
        return value;
    }
  }

  /// Парсит числовое значение (может содержать единицы измерения)
  static double _parseNumber(String value) {
    // Убираем единицы измерения и пробелы
    final cleaned = value.trim().replaceAll(RegExp(r'[a-zA-Z%]+$'), '');
    return double.tryParse(cleaned) ?? 0.0;
  }

  /// Парсит цвет (упрощённая версия, полный парсинг будет позже)
  static Object _parseColor(String value) {
    final trimmed = value.trim().toLowerCase();

    // Пока возвращаем строку, позже добавим полный парсинг
    // #RGB, #RRGGBB, rgb(), rgba(), named colors, etc.
    if (trimmed == 'none' || trimmed == 'transparent') {
      return ui.Color(0x00000000);
    }

    // Именованные цвета (базовые)
    if (_namedColors.containsKey(trimmed)) {
      return _namedColors[trimmed]!;
    }

    // #RGB или #RRGGBB
    if (trimmed.startsWith('#')) {
      return _parseHexColor(trimmed);
    }

    // Для всех остальных пока возвращаем чёрный
    // TODO: добавить парсинг rgb(), rgba(), hsl(), hsla()
    return const ui.Color(0xFF000000);
  }

  /// Парсит hex цвет
  static ui.Color _parseHexColor(String hex) {
    var cleaned = hex.substring(1); // убираем #

    // #RGB -> #RRGGBB
    if (cleaned.length == 3) {
      cleaned = cleaned.split('').map((c) => c + c).join();
    }

    // #RRGGBB
    if (cleaned.length == 6) {
      final value = int.tryParse('FF$cleaned', radix: 16);
      return ui.Color(value ?? 0xFF000000);
    }

    // #RRGGBBAA
    if (cleaned.length == 8) {
      final value = int.tryParse(cleaned, radix: 16);
      return ui.Color(value ?? 0xFF000000);
    }

    return const ui.Color(0xFF000000);
  }

  /// Парсит viewBox атрибут
  static ui.Rect? _parseViewBox(String? viewBox) {
    if (viewBox == null || viewBox.isEmpty) {
      return null;
    }

    final parts = viewBox
        .trim()
        .split(RegExp(r'[\s,]+'))
        .map((s) => double.tryParse(s))
        .whereType<double>()
        .toList();

    if (parts.length == 4) {
      return ui.Rect.fromLTWH(parts[0], parts[1], parts[2], parts[3]);
    }

    return null;
  }

  /// Парсит длину (может быть число, px, em, %, etc.)
  static double? _parseLength(String? length) {
    if (length == null || length.isEmpty) {
      return null;
    }

    return _parseNumber(length);
  }

  // Множества известных атрибутов по категориям

  static const Set<String> _numericAttributes = {
    'x',
    'y',
    'cx',
    'cy',
    'r',
    'rx',
    'ry',
    'width',
    'height',
    'x1',
    'y1',
    'x2',
    'y2',
    'opacity',
    'fill-opacity',
    'stroke-opacity',
    'stroke-width',
    'stroke-miterlimit',
    'font-size',
    'offset',
  };

  static const Set<String> _colorAttributes = {
    'fill',
    'stroke',
    'stop-color',
    'flood-color',
    'lighting-color',
  };

  /// Проверяет, является ли элемент анимационным
  static bool _isAnimationElement(String tagName) {
    return tagName == 'animate' ||
        tagName == 'animateTransform' ||
        tagName == 'animateMotion' ||
        tagName == 'set' ||
        tagName == 'animateColor';
  }

  static const Set<String> _urlAttributes = {
    'href',
    'xlink:href',
    'clip-path',
    'mask',
    'filter',
  };

  static const Map<String, ui.Color> _namedColors = {
    'black': ui.Color(0xFF000000),
    'white': ui.Color(0xFFFFFFFF),
    'red': ui.Color(0xFFFF0000),
    'green': ui.Color(0xFF008000),
    'blue': ui.Color(0xFF0000FF),
    'yellow': ui.Color(0xFFFFFF00),
    'cyan': ui.Color(0xFF00FFFF),
    'magenta': ui.Color(0xFFFF00FF),
    'gray': ui.Color(0xFF808080),
    'grey': ui.Color(0xFF808080),
    'orange': ui.Color(0xFFFFA500),
    'purple': ui.Color(0xFF800080),
    'pink': ui.Color(0xFFFFC0CB),
    'brown': ui.Color(0xFFA52A2A),
    // TODO: добавить полный список CSS named colors
  };
}
