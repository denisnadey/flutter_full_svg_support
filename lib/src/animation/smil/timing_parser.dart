/// Parser for SMIL timing attributes (begin, end)
///
/// Supports multiple semicolon-separated conditions:
/// - "2s; anim1.end+1s; click"
library;

import 'timing_condition.dart';

/// Parses SMIL timing attribute values
class TimingParser {
  /// Parse a begin or end attribute value
  ///
  /// Examples:
  /// - "2s" → [OffsetCondition(2s)]
  /// - "anim1.begin+1s" → [SyncbaseCondition(...)]
  /// - "2s; anim1.end" → [OffsetCondition(2s), SyncbaseCondition(...)]
  static List<TimingCondition> parse(String value) {
    if (value.trim().isEmpty) {
      return [];
    }

    final conditions = <TimingCondition>[];
    final parts = value.split(';');

    for (final part in parts) {
      final trimmed = part.trim();
      if (trimmed.isEmpty) continue;

      final condition = _parseCondition(trimmed);
      if (condition != null) {
        conditions.add(condition);
      }
    }

    return conditions;
  }

  static TimingCondition? _parseCondition(String value) {
    // Check for indefinite
    if (value == 'indefinite') {
      return const IndefiniteCondition();
    }

    // Check for syncbase (contains id.type pattern, not just a decimal point)
    // Syncbase has format: id.begin, id.end, id.repeat(N)
    if (RegExp(r'[a-zA-Z][a-zA-Z0-9_-]*\.(begin|end|repeat)').hasMatch(value)) {
      return _parseSyncbase(value);
    }

    // Try to parse as offset first (most common case)
    final offsetCondition = _parseOffset(value);
    if (offsetCondition != null) {
      return offsetCondition;
    }

    // Check for event (if offset parsing failed)
    if (_isEventName(value)) {
      return _parseEvent(value);
    }

    return null;
  }

  static bool _isEventName(String value) {
    // Extract event name (before any +/- offset)
    final eventName = value.split(RegExp(r'[+-]')).first.trim();

    // Common DOM events
    const events = {
      'click',
      'mousedown',
      'mouseup',
      'mouseover',
      'mouseout',
      'mousemove',
      'focus',
      'blur',
      'focusin',
      'focusout',
      'activate',
      'beginEvent',
      'endEvent',
      'repeatEvent',
    };

    return events.contains(eventName);
  }

  /// Parse syncbase condition: "id.begin", "id.end+2s", "id.repeat(2)"
  static SyncbaseCondition? _parseSyncbase(String value) {
    // Pattern: id.type[+/-offset]
    final match = RegExp(
      r'^([a-zA-Z0-9_-]+)\.(begin|end|repeat(?:\((\d+)\))?)([+-].+)?$',
    ).firstMatch(value);

    if (match == null) return null;

    final animationId = match.group(1)!;
    final typeStr = match.group(2)!;
    final repeatIndexStr = match.group(3);
    final offsetStr = match.group(4);

    // Parse type
    SyncbaseType type;
    int? repeatIndex;

    if (typeStr == 'begin') {
      type = SyncbaseType.begin;
    } else if (typeStr == 'end') {
      type = SyncbaseType.end;
    } else if (typeStr.startsWith('repeat')) {
      type = SyncbaseType.repeat;
      if (repeatIndexStr != null) {
        repeatIndex = int.tryParse(repeatIndexStr);
      }
    } else {
      return null;
    }

    // Parse offset
    Duration offset = Duration.zero;
    if (offsetStr != null && offsetStr.isNotEmpty) {
      // Remove leading +/- and parse
      final sign = offsetStr[0] == '-' ? -1 : 1;
      final timeStr = offsetStr.substring(1).trim();
      final parsedOffset = _parseTimeValue(timeStr);
      if (parsedOffset != null) {
        offset = parsedOffset * sign;
      }
    }

    return SyncbaseCondition(
      animationId: animationId,
      type: type,
      offset: offset,
      repeatIndex: repeatIndex,
    );
  }

  /// Parse event condition: "click", "mouseover+1s"
  static EventCondition? _parseEvent(String value) {
    // Pattern: eventName[+/-offset]
    final match = RegExp(r'^([a-zA-Z]+)([+-].+)?$').firstMatch(value);
    if (match == null) return null;

    final eventType = match.group(1)!;
    final offsetStr = match.group(2);

    Duration offset = Duration.zero;
    if (offsetStr != null && offsetStr.isNotEmpty) {
      final sign = offsetStr[0] == '-' ? -1 : 1;
      final timeStr = offsetStr.substring(1).trim();
      final parsedOffset = _parseTimeValue(timeStr);
      if (parsedOffset != null) {
        offset = parsedOffset * sign;
      }
    }

    return EventCondition(eventType: eventType, offset: offset);
  }

  /// Parse offset condition: "2s", "500ms", "0.5s"
  static OffsetCondition? _parseOffset(String value) {
    final duration = _parseTimeValue(value);
    if (duration == null) return null;
    return OffsetCondition(duration);
  }

  /// Parse time value: "2s", "500ms", "2.5s"
  static Duration? _parseTimeValue(String value) {
    final trimmed = value.trim();

    // Pattern: number + unit (s, ms, min, h)
    // Note: 's' must come before 'ms' in the regex to avoid matching just 'm'
    final match = RegExp(r'^([\d.]+)(ms|min|h|s)?$').firstMatch(trimmed);
    if (match == null) return null;

    final numberStr = match.group(1)!;
    final unit = match.group(2) ?? 's'; // Default to seconds

    final number = double.tryParse(numberStr);
    if (number == null) return null;

    switch (unit) {
      case 'ms':
        return Duration(microseconds: (number * 1000).round());
      case 's':
        return Duration(microseconds: (number * 1000000).round());
      case 'min':
        return Duration(microseconds: (number * 60000000).round());
      case 'h':
        return Duration(microseconds: (number * 3600000000).round());
      default:
        return null;
    }
  }
}
