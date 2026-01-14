/// CSS Keyframe правило
class CssKeyframe {
  final double offset; // 0.0 - 1.0
  final Map<String, String> properties;
  
  CssKeyframe({required this.offset, required this.properties});
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
      
      keyframes.add(CssKeyframe(offset: offset, properties: properties));
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
    final parts = animationValue.trim().split(RegExp(r'\s+'));
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
      if ((part.endsWith('s') || part.endsWith('ms')) && !durationFound) {
        if (part.endsWith('ms')) {
          final ms = double.tryParse(part.replaceAll('ms', '')) ?? 1000.0;
          duration = Duration(milliseconds: ms.toInt());
        } else {
          final seconds = double.tryParse(part.replaceAll('s', '')) ?? 1.0;
          duration = Duration(milliseconds: (seconds * 1000).toInt());
        }
        durationFound = true;
        continue;
      }
      
      // Timing function
      if (_isTimingFunction(part)) {
        timingFunction = part;
        continue;
      }
      
      // Delay - второе встреченное время (после duration)
      if (part.endsWith('s') || part.endsWith('ms')) {
        if (part.endsWith('ms')) {
          final ms = double.tryParse(part.replaceAll('ms', '')) ?? 0.0;
          delay = Duration(milliseconds: ms.toInt());
        } else {
          final seconds = double.tryParse(part.replaceAll('s', '')) ?? 0.0;
          delay = Duration(milliseconds: (seconds * 1000).toInt());
        }
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
      if (['normal', 'reverse', 'alternate', 'alternate-reverse'].contains(part)) {
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
    return [
      'ease',
      'linear',
      'ease-in',
      'ease-out',
      'ease-in-out',
      'step-start',
      'step-end',
    ].contains(value) || value.startsWith('cubic-bezier(');
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
        final ms = double.tryParse(animationDuration.replaceAll('ms', '')) ?? 1000.0;
        duration = Duration(milliseconds: ms.toInt());
      } else if (animationDuration.endsWith('s')) {
        final seconds = double.tryParse(animationDuration.replaceAll('s', '')) ?? 1.0;
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
        final seconds = double.tryParse(animationDelay.replaceAll('s', '')) ?? 0.0;
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
}
