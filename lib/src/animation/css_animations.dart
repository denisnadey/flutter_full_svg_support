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
    
    // Регулярное выражение для @keyframes
    final keyframesRegex = RegExp(
      r'@keyframes\s+([\w-]+)\s*\{([^}]+)\}',
      multiLine: true,
      dotAll: true,
    );
    
    final matches = keyframesRegex.allMatches(cssText);
    
    for (final match in matches) {
      final name = match.group(1)!.trim();
      final body = match.group(2)!;
      
      // Парсим keyframes внутри блока
      final keyframeList = _parseKeyframeBody(body);
      
      keyframes.add(CssKeyframes(name: name, keyframes: keyframeList));
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
    
    // Парсим остальные части
    for (int i = 1; i < parts.length; i++) {
      final part = parts[i];
      
      // Duration (например "2s", "500ms")
      if (part.endsWith('s') || part.endsWith('ms')) {
        if (part.endsWith('ms')) {
          final ms = double.tryParse(part.replaceAll('ms', '')) ?? 1000.0;
          duration = Duration(milliseconds: ms.toInt());
        } else {
          final seconds = double.tryParse(part.replaceAll('s', '')) ?? 1.0;
          duration = Duration(milliseconds: (seconds * 1000).toInt());
        }
        continue;
      }
      
      // Timing function
      if (_isTimingFunction(part)) {
        timingFunction = part;
        continue;
      }
      
      // Delay (аналогично duration)
      if (i < parts.length - 1 && (part.endsWith('s') || part.endsWith('ms'))) {
        // Уже обработано выше
      } else if (part.endsWith('s') || part.endsWith('ms')) {
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
}
