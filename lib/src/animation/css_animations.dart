/// CSS Keyframe правило
class CssKeyframe {
  final double offset; // 0.0 - 1.0
  final Map<String, String> properties;

  /// Per-keyframe timing function override (animation-timing-function in keyframe body).
  /// Applies to the interval starting at this keyframe. null means use animation-level default.
  final String? timingFunction;

  CssKeyframe({
    required this.offset,
    required this.properties,
    this.timingFunction,
  });
}

/// CSS @keyframes анимация
class CssKeyframes {
  final String name;
  final List<CssKeyframe> keyframes;

  CssKeyframes({required this.name, required this.keyframes});
}

/// CSS Animation свойство (shorthand)
/// animation: name duration timing-function delay iteration-count direction fill-mode;
class CssAnimation {
  final String name;
  final Duration duration;
  final String timingFunction; // ease, linear, ease-in, etc.
  final Duration delay;
  final double iterationCount; // 1.0, 2.0, or double.infinity for 'infinite'
  final String direction; // normal, reverse, alternate, alternate-reverse
  final String fillMode; // none, forwards, backwards, both

  CssAnimation({
    required this.name,
    required this.duration,
    this.timingFunction = 'ease',
    this.delay = Duration.zero,
    this.iterationCount = 1.0,
    this.direction = 'normal',
    this.fillMode = 'none',
  });
}

/// CSS rule targeting elements via selector (id, class, element, etc.).
/// Example: `#myId { animation: spin 1s; fill: red; }`
class CssSelectorRule {
  /// The raw selector string, e.g. `#myId`, `.myClass`, `circle`
  final String selector;

  /// All CSS declarations in the rule body (property → value).
  final Map<String, String> declarations;

  const CssSelectorRule({required this.selector, required this.declarations});

  /// Whether this rule targets an `id` selector.
  bool get isIdSelector => selector.startsWith('#');

  /// Whether this rule targets a `class` selector.
  bool get isClassSelector =>
      selector.startsWith('.') && !selector.contains(' ');

  /// The id value if this is an id selector (without `#`).
  String? get targetId => isIdSelector ? selector.substring(1).trim() : null;

  /// The class name if this is a class selector (without `.`).
  String? get targetClass =>
      isClassSelector ? selector.substring(1).trim() : null;

  /// Whether this rule has any animation-related declarations.
  bool get hasAnimation =>
      declarations.containsKey('animation') ||
      declarations.containsKey('animation-name');
}

/// Парсер CSS для SVG
class CssParser {
  /// Парсит содержимое <style> элемента
  static List<CssKeyframes> parseKeyframes(String cssText) {
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

  /// Парсит CSS правила с простыми селекторами (#id, .class, element).
  ///
  /// Игнорирует @-правила (including @keyframes) и многокомпонентные
  /// селекторы с пробелами (потомки, дочерние) — они слишком сложны
  /// для SVG контекста и не используются в SVGator-генерированных файлах.
  ///
  /// Возвращает список [CssSelectorRule] — по одному на каждый найденный
  /// selector-body блок. Один selector может дублироваться (cascading).
  static List<CssSelectorRule> parseSelectorRules(String cssText) {
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
  static String _stripAtRuleBlocks(String css) {
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
  static List<CssKeyframe> _parseKeyframeBody(String body) {
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
  static Map<String, String> _parseProperties(String propertiesStr) {
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

  /// Парсит animation shorthand свойство
  /// animation: name duration timing-function delay iteration-count direction fill-mode;
  static CssAnimation? parseAnimation(String animationValue) {
    final parts = _tokenizeAnimationShorthand(animationValue.trim());
    if (parts.isEmpty) return null;

    String name = parts[0];
    Duration duration = const Duration(seconds: 1);
    String timingFunction = 'ease';
    Duration delay = Duration.zero;
    double iterationCount = 1.0;
    String direction = 'normal';
    String fillMode = 'none';

    bool durationFound = false;

    // Парсим остальные части
    for (int i = 1; i < parts.length; i++) {
      final part = parts[i];

      // Duration (например "2s", "500ms") - первое встреченное время
      final parsedTime = _parseTimeToken(part);
      if (parsedTime != null && !durationFound) {
        duration = parsedTime;
        durationFound = true;
        continue;
      }

      // Timing function
      if (_isTimingFunction(part)) {
        timingFunction = part;
        continue;
      }

      // Delay - второе встреченное время (после duration)
      if (parsedTime != null) {
        delay = parsedTime;
        continue;
      }

      // Iteration count
      if (part == 'infinite') {
        iterationCount = double.infinity;
      } else {
        final count = double.tryParse(part);
        if (count != null) {
          iterationCount = count;
          continue;
        }
      }

      // Direction
      if ([
        'normal',
        'reverse',
        'alternate',
        'alternate-reverse',
      ].contains(part)) {
        direction = part;
        continue;
      }

      // Fill mode
      if (['none', 'forwards', 'backwards', 'both'].contains(part)) {
        fillMode = part;
        continue;
      }
    }

    return CssAnimation(
      name: name,
      duration: duration,
      timingFunction: timingFunction,
      delay: delay,
      iterationCount: iterationCount,
      direction: direction,
      fillMode: fillMode,
    );
  }

  /// Проверяет является ли строка timing function
  static bool _isTimingFunction(String value) {
    final normalized = value.toLowerCase().trim();
    return [
          'ease',
          'linear',
          'ease-in',
          'ease-out',
          'ease-in-out',
          'step-start',
          'step-end',
        ].contains(normalized) ||
        (normalized.startsWith('cubic-bezier(') && normalized.endsWith(')')) ||
        (normalized.startsWith('steps(') && normalized.endsWith(')'));
  }

  /// Парсит animation-* свойства из style атрибута или строки стилей
  static CssAnimation? parseAnimationFromStyle(String styleText) {
    // Парсим style атрибут (CSS свойства)
    final properties = _parseProperties(styleText);

    // Проверяем наличие animation или animation-* свойств
    String? animationValue = properties['animation'];
    String? animationName = properties['animation-name'];
    String? animationDuration = properties['animation-duration'];
    String? animationTimingFunction = properties['animation-timing-function'];
    String? animationDelay = properties['animation-delay'];
    String? animationIterationCount = properties['animation-iteration-count'];
    String? animationDirection = properties['animation-direction'];
    String? animationFillMode = properties['animation-fill-mode'];

    // Если есть shorthand animation, используем его
    if (animationValue != null) {
      return parseAnimation(animationValue);
    }

    // Иначе собираем из отдельных свойств
    if (animationName == null) {
      return null; // Без имени анимации ничего не делаем
    }

    // Парсим duration
    Duration duration = const Duration(seconds: 1);
    if (animationDuration != null) {
      if (animationDuration.endsWith('ms')) {
        final ms =
            double.tryParse(animationDuration.replaceAll('ms', '')) ?? 1000.0;
        duration = Duration(milliseconds: ms.toInt());
      } else if (animationDuration.endsWith('s')) {
        final seconds =
            double.tryParse(animationDuration.replaceAll('s', '')) ?? 1.0;
        duration = Duration(milliseconds: (seconds * 1000).toInt());
      }
    }

    // Парсим delay
    Duration delay = Duration.zero;
    if (animationDelay != null) {
      if (animationDelay.endsWith('ms')) {
        final ms = double.tryParse(animationDelay.replaceAll('ms', '')) ?? 0.0;
        delay = Duration(milliseconds: ms.toInt());
      } else if (animationDelay.endsWith('s')) {
        final seconds =
            double.tryParse(animationDelay.replaceAll('s', '')) ?? 0.0;
        delay = Duration(milliseconds: (seconds * 1000).toInt());
      }
    }

    // Парсим iteration count
    double iterationCount = 1.0;
    if (animationIterationCount != null) {
      if (animationIterationCount == 'infinite') {
        iterationCount = double.infinity;
      } else {
        iterationCount = double.tryParse(animationIterationCount) ?? 1.0;
      }
    }

    return CssAnimation(
      name: animationName,
      duration: duration,
      timingFunction: animationTimingFunction ?? 'ease',
      delay: delay,
      iterationCount: iterationCount,
      direction: animationDirection ?? 'normal',
      fillMode: animationFillMode ?? 'none',
    );
  }

  static Duration? _parseTimeToken(String token) {
    final match = RegExp(
      r'^([+-]?(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?)\s*(ms|s)$',
      caseSensitive: false,
    ).firstMatch(token.trim());
    if (match == null) {
      return null;
    }

    final value = double.tryParse(match.group(1) ?? '');
    final unit = (match.group(2) ?? '').toLowerCase();
    if (value == null) {
      return null;
    }

    if (unit == 'ms') {
      return Duration(milliseconds: value.toInt());
    }
    return Duration(milliseconds: (value * 1000).toInt());
  }

  static List<String> _tokenizeAnimationShorthand(String input) {
    final tokens = <String>[];
    final buffer = StringBuffer();
    int parenthesesDepth = 0;

    for (int i = 0; i < input.length; i++) {
      final char = input[i];
      if (char == '(') {
        parenthesesDepth++;
        buffer.write(char);
        continue;
      }
      if (char == ')') {
        if (parenthesesDepth > 0) {
          parenthesesDepth--;
        }
        buffer.write(char);
        continue;
      }

      final isWhitespace = char.trim().isEmpty;
      if (isWhitespace && parenthesesDepth == 0) {
        if (buffer.isNotEmpty) {
          tokens.add(buffer.toString());
          buffer.clear();
        }
        continue;
      }

      buffer.write(char);
    }

    if (buffer.isNotEmpty) {
      tokens.add(buffer.toString());
    }

    return tokens;
  }
}
