part of 'css_animations.dart';

/// Animation and transition shorthand expansion utilities.
///
/// Contains methods for expanding CSS animation and transition
/// shorthand properties into their longhand equivalents.
///
/// Note: _isTimingFunction and _tokenizeAnimationShorthand are defined
/// in css_animations_timing.dart and shared across the library.

// ============================================================
// ANIMATION SHORTHAND HELPERS
// ============================================================

/// Expands animation shorthand, supporting multiple comma-separated animations.
///
/// Format: animation: name duration timing-function delay iteration-count direction fill-mode play-state
/// Multiple: animation: anim1 1s, anim2 2s ease-in
Map<String, String> _expandAnimation(String value) {
  // Split by comma, but preserve commas inside timing functions
  final animations = _splitAnimations(value);

  if (animations.length == 1) {
    return _expandSingleAnimation(animations.first);
  }

  // For multiple animations, expand each and combine with commas
  final names = <String>[];
  final durations = <String>[];
  final timingFunctions = <String>[];
  final delays = <String>[];
  final iterationCounts = <String>[];
  final directions = <String>[];
  final fillModes = <String>[];
  final playStates = <String>[];

  for (final anim in animations) {
    final expanded = _parseSingleAnimationToComponents(anim.trim());
    names.add(expanded['animation-name'] ?? 'none');
    durations.add(expanded['animation-duration'] ?? '0s');
    timingFunctions.add(expanded['animation-timing-function'] ?? 'ease');
    delays.add(expanded['animation-delay'] ?? '0s');
    iterationCounts.add(expanded['animation-iteration-count'] ?? '1');
    directions.add(expanded['animation-direction'] ?? 'normal');
    fillModes.add(expanded['animation-fill-mode'] ?? 'none');
    playStates.add(expanded['animation-play-state'] ?? 'running');
  }

  return {
    'animation-name': names.join(', '),
    'animation-duration': durations.join(', '),
    'animation-timing-function': timingFunctions.join(', '),
    'animation-delay': delays.join(', '),
    'animation-iteration-count': iterationCounts.join(', '),
    'animation-direction': directions.join(', '),
    'animation-fill-mode': fillModes.join(', '),
    'animation-play-state': playStates.join(', '),
  };
}

Map<String, String> _expandSingleAnimation(String value) {
  final parsed = _parseSingleAnimationToComponents(value);
  
  // Return all animation properties with defaults for unspecified ones
  return {
    'animation-name': parsed['animation-name'] ?? 'none',
    'animation-duration': parsed['animation-duration'] ?? '0s',
    'animation-timing-function': parsed['animation-timing-function'] ?? 'ease',
    'animation-delay': parsed['animation-delay'] ?? '0s',
    'animation-iteration-count': parsed['animation-iteration-count'] ?? '1',
    'animation-direction': parsed['animation-direction'] ?? 'normal',
    'animation-fill-mode': parsed['animation-fill-mode'] ?? 'none',
    'animation-play-state': parsed['animation-play-state'] ?? 'running',
  };
}

Map<String, String> _parseSingleAnimationToComponents(String value) {
  final tokens = _tokenizeAnimationShorthand(value);
  if (tokens.isEmpty) {
    return {'animation': value};
  }

  String? name;
  String? duration;
  String? timingFunction;
  String? delay;
  String? iterationCount;
  String? direction;
  String? fillMode;
  String? playState;

  bool firstTimeFound = false;

  for (final token in tokens) {
    // Check for timing function (must be before other checks as cubic-bezier contains parens)
    if (_isTimingFunction(token)) {
      timingFunction = token;
      continue;
    }

    // Check for time value (duration or delay)
    if (_isTimeValue(token)) {
      if (!firstTimeFound) {
        duration = token;
        firstTimeFound = true;
      } else {
        delay = token;
      }
      continue;
    }

    // Check for iteration count
    if (token == 'infinite' || double.tryParse(token) != null) {
      iterationCount = token;
      continue;
    }

    // Check for direction
    if (_isAnimationDirection(token)) {
      direction = token;
      continue;
    }

    // Check for fill-mode
    if (_isAnimationFillMode(token)) {
      fillMode = token;
      continue;
    }

    // Check for play-state
    if (_isAnimationPlayState(token)) {
      playState = token;
      continue;
    }

    // Otherwise, it's the animation name
    if (name == null) {
      name = token;
    }
  }

  final result = <String, String>{};
  if (name != null) result['animation-name'] = name;
  if (duration != null) result['animation-duration'] = duration;
  if (timingFunction != null)
    result['animation-timing-function'] = timingFunction;
  if (delay != null) result['animation-delay'] = delay;
  if (iterationCount != null)
    result['animation-iteration-count'] = iterationCount;
  if (direction != null) result['animation-direction'] = direction;
  if (fillMode != null) result['animation-fill-mode'] = fillMode;
  if (playState != null) result['animation-play-state'] = playState;

  return result.isNotEmpty ? result : {'animation': value};
}

bool _isTimeValue(String value) {
  return RegExp(
    r'^[+-]?(\d+\.?\d*|\.\d+)(ms|s)$',
    caseSensitive: false,
  ).hasMatch(value.trim());
}

bool _isAnimationDirection(String value) {
  const directions = {'normal', 'reverse', 'alternate', 'alternate-reverse'};
  return directions.contains(value.toLowerCase());
}

bool _isAnimationFillMode(String value) {
  const fillModes = {'none', 'forwards', 'backwards', 'both'};
  return fillModes.contains(value.toLowerCase());
}

bool _isAnimationPlayState(String value) {
  const playStates = {'running', 'paused'};
  return playStates.contains(value.toLowerCase());
}

List<String> _splitAnimations(String value) {
  final animations = <String>[];
  final buffer = StringBuffer();
  int parenDepth = 0;

  for (int i = 0; i < value.length; i++) {
    final char = value[i];

    if (char == '(') {
      parenDepth++;
      buffer.write(char);
      continue;
    }

    if (char == ')') {
      parenDepth--;
      buffer.write(char);
      continue;
    }

    if (char == ',' && parenDepth == 0) {
      if (buffer.isNotEmpty) {
        animations.add(buffer.toString().trim());
        buffer.clear();
      }
      continue;
    }

    buffer.write(char);
  }

  if (buffer.isNotEmpty) {
    animations.add(buffer.toString().trim());
  }

  return animations;
}

// ============================================================
// TRANSITION SHORTHAND HELPERS
// ============================================================

/// Expands transition shorthand into its longhand properties.
///
/// Format: transition: property duration timing-function delay
/// Multiple: transition: opacity 0.3s ease, transform 0.5s ease-in-out
Map<String, String> _expandTransition(String value) {
  final transitions = _splitAnimations(value); // Same comma handling

  if (transitions.length == 1) {
    return _expandSingleTransition(transitions.first);
  }

  final properties = <String>[];
  final durations = <String>[];
  final timingFunctions = <String>[];
  final delays = <String>[];

  for (final trans in transitions) {
    final expanded = _parseSingleTransitionToComponents(trans.trim());
    properties.add(expanded['transition-property'] ?? 'all');
    durations.add(expanded['transition-duration'] ?? '0s');
    timingFunctions.add(expanded['transition-timing-function'] ?? 'ease');
    delays.add(expanded['transition-delay'] ?? '0s');
  }

  return {
    'transition-property': properties.join(', '),
    'transition-duration': durations.join(', '),
    'transition-timing-function': timingFunctions.join(', '),
    'transition-delay': delays.join(', '),
  };
}

Map<String, String> _expandSingleTransition(String value) {
  return _parseSingleTransitionToComponents(value);
}

Map<String, String> _parseSingleTransitionToComponents(String value) {
  // Handle 'none' or 'inherit'
  final lower = value.toLowerCase().trim();
  if (lower == 'none' ||
      lower == 'inherit' ||
      lower == 'initial' ||
      lower == 'unset') {
    return {'transition-property': lower};
  }

  final tokens = _tokenizeAnimationShorthand(value);
  if (tokens.isEmpty) {
    return {'transition': value};
  }

  String? property;
  String? duration;
  String? timingFunction;
  String? delay;

  bool firstTimeFound = false;

  for (final token in tokens) {
    // Check for timing function
    if (_isTimingFunction(token)) {
      timingFunction = token;
      continue;
    }

    // Check for time value
    if (_isTimeValue(token)) {
      if (!firstTimeFound) {
        duration = token;
        firstTimeFound = true;
      } else {
        delay = token;
      }
      continue;
    }

    // Otherwise, it's the property name
    if (property == null) {
      property = token;
    }
  }

  final result = <String, String>{};
  if (property != null) result['transition-property'] = property;
  if (duration != null) result['transition-duration'] = duration;
  if (timingFunction != null)
    result['transition-timing-function'] = timingFunction;
  if (delay != null) result['transition-delay'] = delay;

  return result.isNotEmpty ? result : {'transition': value};
}
