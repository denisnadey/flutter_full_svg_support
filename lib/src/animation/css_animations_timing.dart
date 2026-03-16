part of 'css_animations.dart';

CssAnimation? _parseAnimation(String animationValue) {
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
bool _isTimingFunction(String value) {
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

CssAnimation? _parseAnimationFromStyle(String styleText) {
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
    return _parseAnimation(animationValue);
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

Duration? _parseTimeToken(String token) {
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

List<String> _tokenizeAnimationShorthand(String input) {
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
