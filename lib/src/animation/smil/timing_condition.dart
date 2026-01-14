/// SMIL timing conditions for begin and end attributes
///
/// Supports:
/// - Offset values: "2s", "500ms"
/// - Syncbase: "anim1.begin", "anim1.end+2s", "anim1.repeat(2)"
/// - Event-based: "click", "mouseover+1s" (future)
/// - Wallclock: "wallclock(...)" (future)
/// - Access key: "accessKey(...)" (future)
library;

/// Base class for all timing conditions
abstract class TimingCondition {
  const TimingCondition();

  /// Returns true if this condition has been met at the given time
  bool isMet(Duration currentTime);

  /// Returns the time when this condition will be met, or null if unknown
  Duration? getResolvedTime();
}

/// Simple offset from timeline start
/// Example: "2s", "500ms", "0s"
class OffsetCondition extends TimingCondition {
  final Duration offset;

  const OffsetCondition(this.offset);

  @override
  bool isMet(Duration currentTime) => currentTime >= offset;

  @override
  Duration? getResolvedTime() => offset;

  @override
  String toString() => 'OffsetCondition(${offset.inMilliseconds}ms)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OffsetCondition && offset == other.offset;

  @override
  int get hashCode => offset.hashCode;
}

/// Syncbase condition - synchronize with another animation
/// Examples:
/// - "anim1.begin" - start when anim1 begins
/// - "anim1.end+2s" - start 2 seconds after anim1 ends
/// - "anim1.repeat(2)" - start on 2nd repeat of anim1
class SyncbaseCondition extends TimingCondition {
  /// ID of the animation to sync with
  final String animationId;

  /// Type of sync point: 'begin', 'end', or 'repeat'
  final SyncbaseType type;

  /// Offset from the sync point
  final Duration offset;

  /// For repeat conditions, which repeat to sync with (null = all repeats)
  final int? repeatIndex;

  const SyncbaseCondition({
    required this.animationId,
    required this.type,
    this.offset = Duration.zero,
    this.repeatIndex,
  });

  @override
  bool isMet(Duration currentTime) {
    // Cannot determine without access to the referenced animation
    // This will be resolved by the timeline
    return false;
  }

  @override
  Duration? getResolvedTime() {
    // Will be resolved by the timeline when the referenced animation
    // reaches its sync point
    return null;
  }

  @override
  String toString() {
    final buffer = StringBuffer('SyncbaseCondition(');
    buffer.write('id: $animationId, ');
    buffer.write('type: $type');
    if (repeatIndex != null) {
      buffer.write(', repeat: $repeatIndex');
    }
    if (offset != Duration.zero) {
      buffer.write(', offset: ${offset.inMilliseconds}ms');
    }
    buffer.write(')');
    return buffer.toString();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SyncbaseCondition &&
          animationId == other.animationId &&
          type == other.type &&
          offset == other.offset &&
          repeatIndex == other.repeatIndex;

  @override
  int get hashCode => Object.hash(animationId, type, offset, repeatIndex);
}

/// Type of syncbase synchronization point
enum SyncbaseType {
  /// Synchronize with the begin of another animation
  begin,

  /// Synchronize with the end of another animation
  end,

  /// Synchronize with a repeat event of another animation
  repeat,
}

/// Event-based condition (future implementation)
/// Examples: "click", "mouseover+1s"
class EventCondition extends TimingCondition {
  final String eventType;
  final Duration offset;
  final String? targetId;

  const EventCondition({
    required this.eventType,
    this.offset = Duration.zero,
    this.targetId,
  });

  @override
  bool isMet(Duration currentTime) {
    // Event-based timing requires runtime event handling
    return false;
  }

  @override
  Duration? getResolvedTime() => null;

  @override
  String toString() => 'EventCondition($eventType, offset: $offset)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EventCondition &&
          eventType == other.eventType &&
          offset == other.offset &&
          targetId == other.targetId;

  @override
  int get hashCode => Object.hash(eventType, offset, targetId);
}

/// Indefinite condition - requires external triggering
/// Example: "indefinite"
class IndefiniteCondition extends TimingCondition {
  const IndefiniteCondition();

  @override
  bool isMet(Duration currentTime) => false;

  @override
  Duration? getResolvedTime() => null;

  @override
  String toString() => 'IndefiniteCondition()';

  @override
  bool operator ==(Object other) => other is IndefiniteCondition;

  @override
  int get hashCode => 0;
}
