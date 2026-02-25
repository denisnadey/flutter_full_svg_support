import 'dart:math' as math;
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
      case 'feOffset':
        return _parseOffset(element, filterId);
      case 'feFlood':
        return _parseFlood(element, filterId);
      case 'feBlend':
        return _parseBlend(element, filterId);
      case 'feComposite':
        return _parseComposite(element, filterId);
      case 'feMerge':
        return _parseMerge(element, filterId);
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
    final input = _normalizeFilterInput(element.getAttribute('in'));
    final resultName = _normalizeFilterResult(element.getAttribute('result'));

    return SvgGaussianBlurFilter(
      id: filterId,
      stdDeviationX: stdDeviation.$1,
      stdDeviationY: stdDeviation.$2,
      input: input,
      resultName: resultName,
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
    final input = _normalizeFilterInput(element.getAttribute('in'));
    final resultName = _normalizeFilterResult(element.getAttribute('result'));

    // Парсим flood-color
    final floodColorStr =
        element.getAttribute('flood-color') ??
        element.getAttribute('floodColor') ??
        'black';
    final parsedColor = _parseColor(floodColorStr);
    final color = parsedColor is ui.Color ? parsedColor : null;
    final floodOpacity = _parseNumber(
      element.getAttribute('flood-opacity') ??
          element.getAttribute('floodOpacity') ??
          '1',
    ).clamp(0.0, 1.0);

    return SvgDropShadowFilter(
      id: filterId,
      dx: dx,
      dy: dy,
      stdDeviationX: stdDeviation.$1,
      stdDeviationY: stdDeviation.$2,
      floodColor: color,
      floodOpacity: floodOpacity,
      input: input,
      resultName: resultName,
    );
  }

  /// Парсит feOffset элемент
  static SvgOffsetFilter _parseOffset(XmlElement element, String filterId) {
    final dx = _parseNumber(element.getAttribute('dx') ?? '0');
    final dy = _parseNumber(element.getAttribute('dy') ?? '0');
    final input = _normalizeFilterInput(element.getAttribute('in'));
    final resultName = _normalizeFilterResult(element.getAttribute('result'));

    return SvgOffsetFilter(
      id: filterId,
      dx: dx,
      dy: dy,
      input: input,
      resultName: resultName,
    );
  }

  /// Парсит feFlood элемент
  static SvgFloodFilter _parseFlood(XmlElement element, String filterId) {
    final floodColorStr =
        element.getAttribute('flood-color') ??
        element.getAttribute('floodColor') ??
        'black';
    final parsedColor = _parseColor(floodColorStr);
    final floodColor = parsedColor is ui.Color
        ? parsedColor
        : const ui.Color(0xFF000000);
    final floodOpacity = _parseNumber(
      element.getAttribute('flood-opacity') ??
          element.getAttribute('floodOpacity') ??
          '1',
    );

    return SvgFloodFilter(
      id: filterId,
      floodColor: floodColor,
      floodOpacity: floodOpacity.clamp(0.0, 1.0),
      resultName: _normalizeFilterResult(element.getAttribute('result')),
    );
  }

  /// Парсит feBlend элемент
  static SvgBlendFilter _parseBlend(XmlElement element, String filterId) {
    final mode = parseSvgBlendMode(element.getAttribute('mode'));
    return SvgBlendFilter(
      id: filterId,
      mode: mode,
      input: _normalizeFilterInput(element.getAttribute('in')),
      input2: _normalizeFilterInput(element.getAttribute('in2')),
      resultName: _normalizeFilterResult(element.getAttribute('result')),
    );
  }

  /// Парсит feComposite элемент
  static SvgCompositeFilter _parseComposite(
    XmlElement element,
    String filterId,
  ) {
    final operatorType = element.getAttribute('operator') ?? 'over';
    final mode = parseSvgCompositeOperator(operatorType);

    return SvgCompositeFilter(
      id: filterId,
      operatorType: operatorType,
      mode: mode,
      k1: _parseNumber(element.getAttribute('k1') ?? '0'),
      k2: _parseNumber(element.getAttribute('k2') ?? '0'),
      k3: _parseNumber(element.getAttribute('k3') ?? '0'),
      k4: _parseNumber(element.getAttribute('k4') ?? '0'),
      input: _normalizeFilterInput(element.getAttribute('in')),
      input2: _normalizeFilterInput(element.getAttribute('in2')),
      resultName: _normalizeFilterResult(element.getAttribute('result')),
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
      input: _normalizeFilterInput(element.getAttribute('in')),
      resultName: _normalizeFilterResult(element.getAttribute('result')),
    );
  }

  /// Парсит feMerge элемент и его дочерние feMergeNode.
  static SvgMergeFilter _parseMerge(XmlElement element, String filterId) {
    final nodeInputs = <String?>[];

    for (final child in element.childElements) {
      if (child.name.local != 'feMergeNode') {
        continue;
      }
      final inAttr = child.getAttribute('in');
      final normalized = inAttr?.trim();
      nodeInputs.add(
        normalized == null || normalized.isEmpty ? null : normalized,
      );
    }

    return SvgMergeFilter(
      id: filterId,
      nodeInputs: nodeInputs,
      resultName: _normalizeFilterResult(element.getAttribute('result')),
    );
  }

  static String? _normalizeFilterInput(String? raw) {
    final normalized = raw?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  static String? _normalizeFilterResult(String? raw) {
    final normalized = raw?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  /// Парсит CSS <style> элементы и извлекает @keyframes
  static List<CssKeyframes> _parseStyleElements(XmlElement svgElement) {
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
  static List<CssSelectorRule> _parseSelectorRulesElements(
    XmlElement svgElement,
  ) {
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

    // Сохраняем прямой текстовый контент для текстовых узлов.
    if (tagName == 'text' || tagName == 'tspan' || tagName == 'textPath') {
      final directText = _extractDirectText(element);
      if (directText != null) {
        node.setAttribute('__text', directText, type: SvgAttributeType.string);
      }
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

  static String? _extractDirectText(XmlElement element) {
    final raw = element.children
        .whereType<XmlText>()
        .map((n) => n.value)
        .join();
    if (raw.trim().isEmpty) {
      return null;
    }
    final normalized = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    return normalized.isEmpty ? null : normalized;
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

  /// Парсит цвет
  static Object _parseColor(String value) {
    final trimmed = value.trim().toLowerCase();

    // paint servers, e.g. url(#gradientId)
    if (trimmed.startsWith('url(')) {
      return value.trim();
    }

    // Пока возвращаем строку, позже добавим полный парсинг
    // #RGB, #RRGGBB, rgb(), rgba(), named colors, etc.
    if (trimmed == 'none' || trimmed == 'transparent') {
      return ui.Color(0x00000000);
    }

    // Именованные цвета (базовые)
    if (_namedColors.containsKey(trimmed)) {
      return _namedColors[trimmed]!;
    }

    // #RGB/#RGBA/#RRGGBB/#RRGGBBAA
    if (trimmed.startsWith('#')) {
      return _parseHexColor(trimmed);
    }

    // rgb()/rgba()
    final rgbColor = _parseRgbColor(trimmed);
    if (rgbColor != null) {
      return rgbColor;
    }

    // hsl()/hsla()
    final hslColor = _parseHslColor(trimmed);
    if (hslColor != null) {
      return hslColor;
    }

    // Неподдерживаемый формат -> чёрный (baseline fallback)
    return const ui.Color(0xFF000000);
  }

  /// Парсит hex цвет
  static ui.Color _parseHexColor(String hex) {
    var cleaned = hex.substring(1); // убираем #

    // #RGB -> #RRGGBB
    if (cleaned.length == 3) {
      cleaned = cleaned.split('').map((c) => c + c).join();
    }

    // #RGBA -> #RRGGBBAA
    if (cleaned.length == 4) {
      cleaned = cleaned.split('').map((c) => c + c).join();
    }

    // #RRGGBB
    if (cleaned.length == 6) {
      final value = int.tryParse('FF$cleaned', radix: 16);
      return ui.Color(value ?? 0xFF000000);
    }

    // #RRGGBBAA
    if (cleaned.length == 8) {
      final parsed = int.tryParse(cleaned, radix: 16);
      if (parsed == null) {
        return const ui.Color(0xFF000000);
      }

      final r = (parsed >> 24) & 0xFF;
      final g = (parsed >> 16) & 0xFF;
      final b = (parsed >> 8) & 0xFF;
      final a = parsed & 0xFF;
      return ui.Color((a << 24) | (r << 16) | (g << 8) | b);
    }

    return const ui.Color(0xFF000000);
  }

  static ui.Color? _parseRgbColor(String value) {
    final match = RegExp(r'^rgba?\(\s*(.+)\s*\)$').firstMatch(value);
    if (match == null) {
      return null;
    }

    final args = _parseColorFunctionArgs(match.group(1)!);
    if (args.length < 3) {
      return null;
    }

    double alpha = 1.0;
    late final int r;
    late final int g;
    late final int b;

    if (args.contains('/')) {
      final slashIndex = args.indexOf('/');
      if (slashIndex != 3 || args.length != 5) {
        return null;
      }
      r = _parseRgbChannel(args[0]);
      g = _parseRgbChannel(args[1]);
      b = _parseRgbChannel(args[2]);
      alpha = _parseAlpha(args[4]);
    } else {
      if (args.length < 3) {
        return null;
      }
      r = _parseRgbChannel(args[0]);
      g = _parseRgbChannel(args[1]);
      b = _parseRgbChannel(args[2]);
      if (args.length >= 4) {
        alpha = _parseAlpha(args[3]);
      }
    }

    return _colorFromRgba(r, g, b, alpha);
  }

  static ui.Color? _parseHslColor(String value) {
    final match = RegExp(r'^hsla?\(\s*(.+)\s*\)$').firstMatch(value);
    if (match == null) {
      return null;
    }

    final args = _parseColorFunctionArgs(match.group(1)!);
    if (args.length < 3) {
      return null;
    }

    double alpha = 1.0;
    late final double hue;
    late final double saturation;
    late final double lightness;

    if (args.contains('/')) {
      final slashIndex = args.indexOf('/');
      if (slashIndex != 3 || args.length != 5) {
        return null;
      }
      hue = _parseHueDegrees(args[0]);
      saturation = _parseFraction(args[1]);
      lightness = _parseFraction(args[2]);
      alpha = _parseAlpha(args[4]);
    } else {
      hue = _parseHueDegrees(args[0]);
      saturation = _parseFraction(args[1]);
      lightness = _parseFraction(args[2]);
      if (args.length >= 4) {
        alpha = _parseAlpha(args[3]);
      }
    }

    return _hslToColor(hue, saturation, lightness, alpha);
  }

  static List<String> _parseColorFunctionArgs(String input) {
    if (input.contains(',')) {
      return input
          .split(',')
          .map((part) => part.trim())
          .where((part) => part.isNotEmpty)
          .toList();
    }

    return input
        .replaceAll('/', ' / ')
        .split(RegExp(r'\s+'))
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
  }

  static int _parseRgbChannel(String input) {
    final value = input.trim();
    if (value.endsWith('%')) {
      final percent =
          double.tryParse(value.substring(0, value.length - 1)) ?? 0.0;
      final normalized = percent.clamp(0.0, 100.0) / 100.0;
      return (normalized * 255).round();
    }

    final number = double.tryParse(value) ?? 0.0;
    return number.clamp(0.0, 255.0).round();
  }

  static double _parseAlpha(String input) {
    final value = input.trim();
    if (value.endsWith('%')) {
      final percent =
          double.tryParse(value.substring(0, value.length - 1)) ?? 0.0;
      return (percent.clamp(0.0, 100.0) / 100.0).toDouble();
    }

    final alpha = double.tryParse(value) ?? 1.0;
    return alpha.clamp(0.0, 1.0).toDouble();
  }

  static double _parseFraction(String input) {
    final value = input.trim();
    if (value.endsWith('%')) {
      final percent =
          double.tryParse(value.substring(0, value.length - 1)) ?? 0.0;
      return (percent.clamp(0.0, 100.0) / 100.0).toDouble();
    }

    final number = double.tryParse(value) ?? 0.0;
    return number.clamp(0.0, 1.0).toDouble();
  }

  static double _parseHueDegrees(String input) {
    final match = RegExp(
      r'^([+-]?(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?)\s*(deg|rad|turn|grad)?$',
      caseSensitive: false,
    ).firstMatch(input.trim());
    if (match == null) {
      return 0.0;
    }

    final value = double.tryParse(match.group(1) ?? '') ?? 0.0;
    final unit = (match.group(2) ?? 'deg').toLowerCase();
    return switch (unit) {
      'deg' => value,
      'rad' => value * 180.0 / math.pi,
      'turn' => value * 360.0,
      'grad' => value * 0.9,
      _ => value,
    };
  }

  static ui.Color _colorFromRgba(int r, int g, int b, double alpha) {
    final a = (alpha.clamp(0.0, 1.0) * 255).round();
    return ui.Color((a << 24) | (r << 16) | (g << 8) | b);
  }

  static ui.Color _hslToColor(
    double hueDegrees,
    double saturation,
    double lightness,
    double alpha,
  ) {
    final h = ((hueDegrees % 360.0) + 360.0) % 360.0 / 360.0;
    final s = saturation.clamp(0.0, 1.0).toDouble();
    final l = lightness.clamp(0.0, 1.0).toDouble();

    if (s == 0.0) {
      final gray = (l * 255).round();
      return _colorFromRgba(gray, gray, gray, alpha);
    }

    final q = l < 0.5 ? l * (1 + s) : l + s - l * s;
    final p = 2 * l - q;
    final r = _hueToRgb(p, q, h + (1 / 3));
    final g = _hueToRgb(p, q, h);
    final b = _hueToRgb(p, q, h - (1 / 3));
    return _colorFromRgba(
      (r * 255).round(),
      (g * 255).round(),
      (b * 255).round(),
      alpha,
    );
  }

  static double _hueToRgb(double p, double q, double t) {
    var adjusted = t;
    if (adjusted < 0) adjusted += 1;
    if (adjusted > 1) adjusted -= 1;

    if (adjusted < 1 / 6) {
      return p + (q - p) * 6 * adjusted;
    }
    if (adjusted < 1 / 2) {
      return q;
    }
    if (adjusted < 2 / 3) {
      return p + (q - p) * (2 / 3 - adjusted) * 6;
    }
    return p;
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
    'stroke-dashoffset',
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
