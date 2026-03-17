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
  String playState = 'running';

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

    // Play state
    if (part == 'running' || part == 'paused') {
      playState = part;
      continue;
    }

    // Iteration count
    if (part == 'infinite') {
      iterationCount = double.infinity;
      continue;
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
    playState: playState,
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
  String? animationPlayState = properties['animation-play-state'];

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
    final parsed = _parseDurationString(animationDuration);
    if (parsed != null) duration = parsed;
  }

  // Парсим delay (supports negative values)
  Duration delay = Duration.zero;
  if (animationDelay != null) {
    final parsed = _parseDurationString(animationDelay);
    if (parsed != null) delay = parsed;
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
    playState: animationPlayState ?? 'running',
  );
}

/// Parse comma-separated animation values into multiple CssAnimation objects
List<CssAnimation> _parseMultipleAnimations(String animationValue) {
  final animations = <CssAnimation>[];
  final rawAnimations = _splitAnimationValues(animationValue);

  for (final raw in rawAnimations) {
    final animation = _parseAnimation(raw.trim());
    if (animation != null) {
      animations.add(animation);
    }
  }

  return animations;
}

/// Split comma-separated animation values, respecting parentheses
List<String> _splitAnimationValues(String value) {
  final result = <String>[];
  final buffer = StringBuffer();
  int parenDepth = 0;

  for (int i = 0; i < value.length; i++) {
    final char = value[i];
    if (char == '(') {
      parenDepth++;
      buffer.write(char);
    } else if (char == ')') {
      parenDepth--;
      buffer.write(char);
    } else if (char == ',' && parenDepth == 0) {
      final trimmed = buffer.toString().trim();
      if (trimmed.isNotEmpty) {
        result.add(trimmed);
      }
      buffer.clear();
    } else {
      buffer.write(char);
    }
  }

  final remaining = buffer.toString().trim();
  if (remaining.isNotEmpty) {
    result.add(remaining);
  }

  return result;
}

/// Parse duration string that may be negative (e.g., "-0.5s", "500ms", "-100ms")
Duration? _parseDurationString(String durationStr) {
  final str = durationStr.trim();
  if (str.endsWith('ms')) {
    final ms = double.tryParse(str.replaceAll('ms', ''));
    if (ms != null) return Duration(microseconds: (ms * 1000).toInt());
  } else if (str.endsWith('s')) {
    final seconds = double.tryParse(str.replaceAll('s', ''));
    if (seconds != null)
      return Duration(microseconds: (seconds * 1000000).toInt());
  }
  return null;
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

/// Parse multiple animations from style attribute or style string
List<CssAnimation> _parseMultipleAnimationsFromStyle(String styleText) {
  final properties = _parseProperties(styleText);
  final animationValue = properties['animation'];

  if (animationValue != null) {
    return _parseMultipleAnimations(animationValue);
  }

  // Fall back to single animation from individual properties
  final single = _parseAnimationFromStyle(styleText);
  return single != null ? [single] : [];
}

/// Parse CSS transition property
CssTransition? _parseTransition(String transitionValue) {
  final parts = _tokenizeAnimationShorthand(transitionValue.trim());
  if (parts.isEmpty) return null;

  String property = 'all';
  Duration duration = Duration.zero;
  String timingFunction = 'ease';
  Duration delay = Duration.zero;
  bool durationFound = false;

  for (final part in parts) {
    final parsedTime = _parseTimeToken(part);
    if (parsedTime != null && !durationFound) {
      duration = parsedTime;
      durationFound = true;
      continue;
    }

    if (parsedTime != null) {
      delay = parsedTime;
      continue;
    }

    if (_isTimingFunction(part)) {
      timingFunction = part;
      continue;
    }

    // Property name (first non-time, non-timing-function value)
    if (!['all', 'none'].contains(part.toLowerCase()) &&
        !_isTimingFunction(part)) {
      property = part;
    } else if (part.toLowerCase() == 'all' || part.toLowerCase() == 'none') {
      property = part.toLowerCase();
    }
  }

  return CssTransition(
    property: property,
    duration: duration,
    timingFunction: timingFunction,
    delay: delay,
  );
}

/// Parse multiple CSS transitions from style string
List<CssTransition> _parseTransitionsFromStyle(String styleText) {
  final properties = _parseProperties(styleText);
  final transitionValue = properties['transition'];

  if (transitionValue != null) {
    final transitions = <CssTransition>[];
    final rawTransitions = _splitAnimationValues(transitionValue);

    for (final raw in rawTransitions) {
      final transition = _parseTransition(raw.trim());
      if (transition != null) {
        transitions.add(transition);
      }
    }
    return transitions;
  }

  // Fall back to individual transition-* properties
  final transitionProperty = properties['transition-property'];
  if (transitionProperty == null) return [];

  final durationStr = properties['transition-duration'] ?? '0s';
  final timingStr = properties['transition-timing-function'] ?? 'ease';
  final delayStr = properties['transition-delay'] ?? '0s';

  final props = transitionProperty.split(',').map((p) => p.trim()).toList();
  final durations = durationStr
      .split(',')
      .map((d) => _parseDurationString(d.trim()))
      .toList();
  final timings = timingStr.split(',').map((t) => t.trim()).toList();
  final delays = delayStr
      .split(',')
      .map((d) => _parseDurationString(d.trim()))
      .toList();

  final transitions = <CssTransition>[];
  for (int i = 0; i < props.length; i++) {
    transitions.add(
      CssTransition(
        property: props[i],
        duration: durations.length > i
            ? (durations[i] ?? Duration.zero)
            : (durations.isNotEmpty
                  ? (durations.last ?? Duration.zero)
                  : Duration.zero),
        timingFunction: timings.length > i
            ? timings[i]
            : (timings.isNotEmpty ? timings.last : 'ease'),
        delay: delays.length > i
            ? (delays[i] ?? Duration.zero)
            : (delays.isNotEmpty
                  ? (delays.last ?? Duration.zero)
                  : Duration.zero),
      ),
    );
  }

  return transitions;
}

/// Parse @media rules from CSS text
List<CssMediaRule> _parseMediaRules(String cssText) {
  final mediaRules = <CssMediaRule>[];

  final mediaRegex = RegExp(
    r'@media\s+([^{]+)\s*\{',
    multiLine: true,
    caseSensitive: false,
  );

  int pos = 0;
  while (pos < cssText.length) {
    final remainingText = cssText.substring(pos);
    final match = mediaRegex.firstMatch(remainingText);
    if (match == null) break;

    final query = match.group(1)!.trim();
    final relativeStart = match.end;
    final start = pos + relativeStart;

    // Find closing brace, accounting for nesting
    int depth = 1;
    int end = start;
    while (end < cssText.length && depth > 0) {
      if (cssText[end] == '{') depth++;
      if (cssText[end] == '}') depth--;
      end++;
    }

    if (depth == 0) {
      final body = cssText.substring(start, end - 1);
      final rules = _parseSelectorRules(body);
      final condition = _parseMediaCondition(query);

      mediaRules.add(
        CssMediaRule(query: query, rules: rules, condition: condition),
      );
    }

    pos = end;
  }

  return mediaRules;
}

/// Parse a media query condition
CssMediaCondition? _parseMediaCondition(String query) {
  final normalized = query.toLowerCase().trim();

  // prefers-color-scheme
  final colorSchemeMatch = RegExp(
    r'\(\s*prefers-color-scheme\s*:\s*(dark|light)\s*\)',
  ).firstMatch(normalized);
  if (colorSchemeMatch != null) {
    return CssMediaCondition(
      feature: CssMediaFeature.prefersColorScheme,
      value: colorSchemeMatch.group(1),
    );
  }

  // min-width / max-width / min-height / max-height
  final sizeMatch = RegExp(
    r'\(\s*(min-width|max-width|min-height|max-height)\s*:\s*([\d.]+)(px|em|rem|vw|vh)?\s*\)',
  ).firstMatch(normalized);
  if (sizeMatch != null) {
    final featureName = sizeMatch.group(1)!;
    final numValue = double.tryParse(sizeMatch.group(2) ?? '');
    final unit = sizeMatch.group(3) ?? 'px';

    final feature = switch (featureName) {
      'min-width' => CssMediaFeature.minWidth,
      'max-width' => CssMediaFeature.maxWidth,
      'min-height' => CssMediaFeature.minHeight,
      'max-height' => CssMediaFeature.maxHeight,
      _ => CssMediaFeature.unknown,
    };

    return CssMediaCondition(
      feature: feature,
      numericValue: numValue,
      unit: unit,
    );
  }

  return null;
}
