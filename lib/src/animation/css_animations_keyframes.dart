part of 'css_animations.dart';

List<CssKeyframes> _parseKeyframes(String cssText) {
  final keyframes = <CssKeyframes>[];

  // Регулярное выражение для @keyframes с поддержкой вложенных фигурных скобок
  final keyframesRegex = RegExp(
    r'@keyframes\s+([\w-]+)\s*\{',
    multiLine: true,
    caseSensitive: false,
  );

  int pos = 0;
  while (pos < cssText.length) {
    final remainingText = cssText.substring(pos);
    final match = keyframesRegex.firstMatch(remainingText);
    if (match == null) break;

    final name = match.group(1)!.trim();
    final relativeStart = match.end;
    final start = pos + relativeStart;

    // Находим закрывающую скобку, учитывая вложенность
    int depth = 1;
    int end = start;
    while (end < cssText.length && depth > 0) {
      if (cssText[end] == '{') depth++;
      if (cssText[end] == '}') depth--;
      end++;
    }

    if (depth == 0) {
      final body = cssText.substring(start, end - 1);
      final keyframeList = _parseKeyframeBody(body);
      keyframes.add(CssKeyframes(name: name, keyframes: keyframeList));
    }

    pos = end;
  }

  return keyframes;
}

List<CssSelectorRule> _parseSelectorRules(String cssText) {
  final rules = <CssSelectorRule>[];

  // Шаг 1: убираем @keyframes блоки, чтобы их фигурные скобки не мешали.
  final strippedCss = _stripAtRuleBlocks(cssText);

  // Шаг 2: ищем блоки вида `selector { ... }`.
  // Поддерживаем: #id, .class, element, #id.class и т.п.
  // Не поддерживаем: a > b, a ~ b (descendant combinator).
  int pos = 0;
  while (pos < strippedCss.length) {
    // Ищем ближайшую открывающую скобку.
    final braceOpen = strippedCss.indexOf('{', pos);
    if (braceOpen == -1) break;

    // Извлекаем selector (всё что до '{', trimmed).
    final rawSelector = strippedCss.substring(pos, braceOpen).trim();

    // Ищем закрывающую скобку (без вложенности — simple rules).
    final braceClose = strippedCss.indexOf('}', braceOpen + 1);
    if (braceClose == -1) break;

    final body = strippedCss.substring(braceOpen + 1, braceClose);
    pos = braceClose + 1;

    // Пропускаем пустые или @-правила.
    if (rawSelector.isEmpty || rawSelector.startsWith('@')) continue;

    // Обрабатываем мультиселекторы через запятую: `#a, .b { ... }`.
    final selectors = rawSelector
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final declarations = _parseProperties(body);
    if (declarations.isEmpty) continue;

    for (final sel in selectors) {
      rules.add(CssSelectorRule(selector: sel, declarations: declarations));
    }
  }

  return rules;
}

/// Убирает все @-rule блоки (типа @keyframes) из CSS текста, заменяя
/// их пустыми строками той же длины (для сохранения офсетов, если нужно).
String _stripAtRuleBlocks(String css) {
  // Простой подход: заменяем каждый @... {...} на пробелы.
  final result = StringBuffer();
  int pos = 0;
  while (pos < css.length) {
    // Ищем знак '@'.
    final atPos = css.indexOf('@', pos);
    if (atPos == -1) {
      result.write(css.substring(pos));
      break;
    }
    // Копируем всё до '@'.
    result.write(css.substring(pos, atPos));
    // Ищем '{' после '@'.
    final braceOpen = css.indexOf('{', atPos);
    if (braceOpen == -1) {
      // Нет '{' — конец файла.
      break;
    }
    // Пропускаем блок с учётом вложенности.
    int depth = 1;
    int end = braceOpen + 1;
    while (end < css.length && depth > 0) {
      if (css[end] == '{') depth++;
      if (css[end] == '}') depth--;
      end++;
    }
    // Заменяем пробелами.
    result.write(' ' * (end - atPos));
    pos = end;
  }
  return result.toString();
}

/// Парсит тело @keyframes блока
List<CssKeyframe> _parseKeyframeBody(String body) {
  final keyframes = <CssKeyframe>[];

  // Парсим keyframe правила: 0% { ... }, 50% { ... }, 100% { ... }
  final keyframeRegex = RegExp(
    r'(\d+%|from|to)\s*\{([^}]+)\}',
    multiLine: true,
  );

  final matches = keyframeRegex.allMatches(body);

  for (final match in matches) {
    final offsetStr = match.group(1)!;
    final propertiesStr = match.group(2)!;

    // Конвертируем offset в число 0.0-1.0
    double offset;
    if (offsetStr == 'from') {
      offset = 0.0;
    } else if (offsetStr == 'to') {
      offset = 1.0;
    } else {
      final percent = double.tryParse(offsetStr.replaceAll('%', '')) ?? 0.0;
      offset = percent / 100.0;
    }

    // Парсим CSS свойства
    final properties = _parseProperties(propertiesStr);

    // Извлекаем per-keyframe animation-timing-function (не анимируемое свойство)
    final perKeyframeTiming = properties.remove('animation-timing-function');

    keyframes.add(
      CssKeyframe(
        offset: offset,
        properties: properties,
        timingFunction: perKeyframeTiming,
      ),
    );
  }

  // Сортируем по offset
  keyframes.sort((a, b) => a.offset.compareTo(b.offset));

  return keyframes;
}

/// Парсит CSS свойства из строки
Map<String, String> _parseProperties(String propertiesStr) {
  final properties = <String, String>{};

  // Разделяем по ; и парсим каждое свойство
  final lines = propertiesStr.split(';');

  for (final line in lines) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) continue;

    final colonIndex = trimmed.indexOf(':');
    if (colonIndex == -1) continue;

    final name = trimmed.substring(0, colonIndex).trim();
    final value = trimmed.substring(colonIndex + 1).trim();

    if (name.isNotEmpty && value.isNotEmpty) {
      properties[name] = value;
    }
  }

  return properties;
}

/// Parses CSS properties and returns them as ordered list of (name, value) pairs.
///
/// This preserves declaration order which is important for proper cascade
/// resolution when shorthands and longhands interact.
List<(String, String)> _parsePropertiesOrdered(String propertiesStr) {
  final declarations = <(String, String)>[];

  final lines = propertiesStr.split(';');

  for (final line in lines) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) continue;

    final colonIndex = trimmed.indexOf(':');
    if (colonIndex == -1) continue;

    final name = trimmed.substring(0, colonIndex).trim().toLowerCase();
    final value = trimmed.substring(colonIndex + 1).trim();

    if (name.isNotEmpty && value.isNotEmpty) {
      declarations.add((name, value));
    }
  }

  return declarations;
}

/// Parses CSS properties from string and expands shorthand properties.
///
/// This is the preferred function for parsing CSS that may contain
/// shorthand properties like font, margin, padding, animation, etc.
///
/// Per CSS cascade rules, when shorthand and longhand properties are declared
/// at the same specificity level, the later declaration wins. This function
/// preserves declaration order to ensure proper cascade behavior.
Map<String, String> _parsePropertiesWithShorthandExpansion(
  String propertiesStr,
) {
  final orderedDeclarations = _parsePropertiesOrdered(propertiesStr);
  return CssShorthandExpander.expandAllOrdered(orderedDeclarations);
}
