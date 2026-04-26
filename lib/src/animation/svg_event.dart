/// W3C SVG Event model implementation.
///
/// Provides proper event bubbling, capturing, and retargeting through `<use>`
/// shadow boundaries following the DOM Event specification.
library;

import 'package:flutter/foundation.dart';

import 'svg_dom.dart';

/// Event phases as defined in the W3C DOM Event specification.
enum SvgEventPhase {
  /// Event phase not determined.
  none,

  /// Event is propagating from the root to the target (capture phase).
  capturing,

  /// Event has reached the target element.
  atTarget,

  /// Event is propagating from the target back to the root (bubble phase).
  bubbling,
}

/// Base class for SVG events following the W3C DOM Event model.
///
/// Supports:
/// - Event bubbling and capturing phases
/// - Event retargeting through `<use>` shadow boundaries
/// - stopPropagation() and stopImmediatePropagation()
/// - preventDefault() for cancelable events
class SvgEvent {
  /// Creates an SVG event.
  SvgEvent({
    required this.type,
    this.bubbles = true,
    this.cancelable = false,
    this.composed = false,
  });

  /// The event type (e.g., 'click', 'mouseover').
  final String type;

  /// Whether this event bubbles up through the DOM tree.
  final bool bubbles;

  /// Whether this event can be canceled.
  final bool cancelable;

  /// Whether this event crosses shadow DOM boundaries.
  /// For `<use>` elements, this determines event retargeting behavior.
  final bool composed;

  /// The element that originally received the event.
  /// For events inside `<use>` shadow trees, this is the original element.
  SvgNode? _target;

  /// The current target during event propagation.
  /// This is the element whose event listener is currently being invoked.
  SvgNode? _currentTarget;

  /// The current event phase.
  SvgEventPhase _eventPhase = SvgEventPhase.none;

  /// Whether stopPropagation() has been called.
  bool _propagationStopped = false;

  /// Whether stopImmediatePropagation() has been called.
  bool _immediatePropagationStopped = false;

  /// Whether preventDefault() has been called.
  bool _defaultPrevented = false;

  /// Timestamp when the event was created.
  final int timeStamp = DateTime.now().millisecondsSinceEpoch;

  /// The complete path of the event, including elements in shadow trees.
  /// This represents the composedPath() functionality.
  List<SvgNode>? _composedPath;

  /// The retargeted path for non-composed events, excluding shadow internals.
  List<SvgNode>? _retargetedPath;

  /// The `<use>` element that is the shadow host, if any.
  SvgNode? _useElement;

  /// Gets the event target.
  /// For events inside `<use>` shadows with non-composed events,
  /// this returns the `<use>` element.
  SvgNode? get target {
    if (!composed && _useElement != null) {
      return _useElement;
    }
    return _target;
  }

  /// Gets the current target during event propagation.
  SvgNode? get currentTarget => _currentTarget;

  /// Gets the current event phase.
  SvgEventPhase get eventPhase => _eventPhase;

  /// Whether propagation has been stopped.
  bool get propagationStopped => _propagationStopped;

  /// Whether immediate propagation has been stopped.
  bool get immediatePropagationStopped => _immediatePropagationStopped;

  /// Whether the default action has been prevented.
  bool get defaultPrevented => _defaultPrevented;

  // Internal setters for event dispatcher to set event state.
  // These are package-private (accessible within the library).

  /// Internal: Sets the event target.
  // ignore: use_setters_to_change_properties
  void setTargetInternal(SvgNode? target) => _target = target;

  /// Internal: Sets the use element for retargeting.
  // ignore: use_setters_to_change_properties
  void setUseElementInternal(SvgNode? useElement) => _useElement = useElement;

  /// Internal: Sets the composed path.
  // ignore: use_setters_to_change_properties
  void setComposedPathInternal(List<SvgNode> path) => _composedPath = path;

  /// Internal: Sets the retargeted path.
  // ignore: use_setters_to_change_properties
  void setRetargetedPathInternal(List<SvgNode> path) => _retargetedPath = path;

  /// Internal: Sets the event phase.
  // ignore: use_setters_to_change_properties
  void setEventPhaseInternal(SvgEventPhase phase) => _eventPhase = phase;

  /// Internal: Sets the current target.
  // ignore: use_setters_to_change_properties
  void setCurrentTargetInternal(SvgNode? currentTarget) =>
      _currentTarget = currentTarget;

  /// Gets the composed path - the complete event path including shadow trees.
  List<SvgNode> composedPath() {
    return List<SvgNode>.unmodifiable(_composedPath ?? const <SvgNode>[]);
  }

  /// Gets the retargeted path for event dispatch.
  /// For non-composed events, shadow internals are excluded.
  List<SvgNode> get path {
    if (composed || _useElement == null) {
      return _composedPath ?? const <SvgNode>[];
    }
    return _retargetedPath ?? const <SvgNode>[];
  }

  /// Stops the event from propagating further.
  void stopPropagation() {
    _propagationStopped = true;
  }

  /// Stops the event from propagating further and prevents
  /// any other listeners on the current target from being invoked.
  void stopImmediatePropagation() {
    _propagationStopped = true;
    _immediatePropagationStopped = true;
  }

  /// Prevents the default action of the event.
  void preventDefault() {
    if (cancelable) {
      _defaultPrevented = true;
    }
  }

  @override
  String toString() {
    return 'SvgEvent($type, phase: $_eventPhase, target: ${_target?.id})';
  }
}

/// Mouse event extending SvgEvent with position information.
class SvgMouseEvent extends SvgEvent {
  SvgMouseEvent({
    required super.type,
    super.bubbles = true,
    super.cancelable = true,
    super.composed = false,
    required this.clientX,
    required this.clientY,
    this.button = 0,
    this.buttons = 0,
    this.altKey = false,
    this.ctrlKey = false,
    this.metaKey = false,
    this.shiftKey = false,
    this.relatedTarget,
  });

  /// X coordinate relative to the SVG viewport.
  final double clientX;

  /// Y coordinate relative to the SVG viewport.
  final double clientY;

  /// The button that triggered the event.
  final int button;

  /// The buttons currently pressed.
  final int buttons;

  /// Whether the Alt key was pressed.
  final bool altKey;

  /// Whether the Ctrl key was pressed.
  final bool ctrlKey;

  /// Whether the Meta key was pressed.
  final bool metaKey;

  /// Whether the Shift key was pressed.
  final bool shiftKey;

  /// The related target for mouseover/mouseout events.
  final SvgNode? relatedTarget;
}

/// Pointer event for unified pointer handling.
class SvgPointerEvent extends SvgMouseEvent {
  SvgPointerEvent({
    required super.type,
    super.bubbles = true,
    super.cancelable = true,
    super.composed = false,
    required super.clientX,
    required super.clientY,
    super.button = 0,
    super.buttons = 0,
    super.altKey = false,
    super.ctrlKey = false,
    super.metaKey = false,
    super.shiftKey = false,
    super.relatedTarget,
    required this.pointerId,
    this.width = 1.0,
    this.height = 1.0,
    this.pressure = 0.5,
    this.tangentialPressure = 0.0,
    this.tiltX = 0,
    this.tiltY = 0,
    this.twist = 0,
    this.pointerType = 'mouse',
    this.isPrimary = true,
  });

  /// Unique identifier for the pointer.
  final int pointerId;

  /// Width of the pointer contact geometry.
  final double width;

  /// Height of the pointer contact geometry.
  final double height;

  /// Normalized pressure of the pointer input.
  final double pressure;

  /// Tangential pressure (for stylus).
  final double tangentialPressure;

  /// Tilt angle on X axis.
  final int tiltX;

  /// Tilt angle on Y axis.
  final int tiltY;

  /// Clockwise rotation of the pointer.
  final int twist;

  /// Type of pointer: 'mouse', 'pen', or 'touch'.
  final String pointerType;

  /// Whether this is the primary pointer.
  final bool isPrimary;
}

/// Focus event for focus-related events.
class SvgFocusEvent extends SvgEvent {
  SvgFocusEvent({
    required super.type,
    super.bubbles = true,
    super.cancelable = false,
    super.composed = true,
    this.relatedTarget,
  });

  /// The element that is losing/gaining focus.
  final SvgNode? relatedTarget;
}

/// Gesture event for high-level gesture recognition.
class SvgGestureEvent extends SvgEvent {
  SvgGestureEvent({
    required super.type,
    super.bubbles = true,
    super.cancelable = true,
    super.composed = false,
    required this.localPosition,
    required this.globalPosition,
    this.velocity,
    this.delta,
  });

  /// Position relative to the SVG viewport.
  final Offset localPosition;

  /// Position relative to the screen.
  final Offset globalPosition;

  /// Velocity for drag/fling gestures.
  final Offset? velocity;

  /// Delta for pan/drag gestures.
  final Offset? delta;
}

/// Wheel event for scroll/wheel interactions.
class SvgWheelEvent extends SvgMouseEvent {
  SvgWheelEvent({
    required super.clientX,
    required super.clientY,
    super.button = 0,
    super.buttons = 0,
    super.altKey = false,
    super.ctrlKey = false,
    super.metaKey = false,
    super.shiftKey = false,
    required this.deltaX,
    required this.deltaY,
    this.deltaZ = 0.0,
    this.deltaMode = SvgWheelDeltaMode.pixel,
  }) : super(type: 'wheel', bubbles: true, cancelable: true, composed: false);

  /// Horizontal scroll amount.
  final double deltaX;

  /// Vertical scroll amount.
  final double deltaY;

  /// Scroll amount on Z axis (usually 0).
  final double deltaZ;

  /// Unit of delta values (pixel, line, or page).
  final SvgWheelDeltaMode deltaMode;
}

/// Delta mode for wheel events.
enum SvgWheelDeltaMode {
  /// Delta values are specified in pixels.
  pixel,

  /// Delta values are specified in lines.
  line,

  /// Delta values are specified in pages.
  page,
}

/// Context menu event for right-click / long-press handling.
class SvgContextMenuEvent extends SvgMouseEvent {
  SvgContextMenuEvent({
    required super.clientX,
    required super.clientY,
    super.button = 2, // Right button
    super.buttons = 2,
    super.altKey = false,
    super.ctrlKey = false,
    super.metaKey = false,
    super.shiftKey = false,
  }) : super(
         type: 'contextmenu',
         bubbles: true,
         cancelable: true,
         composed: false,
       );
}

/// Offset class for position information.
@immutable
class Offset {
  const Offset(this.dx, this.dy);

  static const Offset zero = Offset(0, 0);

  final double dx;
  final double dy;

  Offset operator +(Offset other) => Offset(dx + other.dx, dy + other.dy);
  Offset operator -(Offset other) => Offset(dx - other.dx, dy - other.dy);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Offset && dx == other.dx && dy == other.dy;

  @override
  int get hashCode => Object.hash(dx, dy);

  @override
  String toString() => 'Offset($dx, $dy)';
}

/// Event listener callback type.
typedef SvgEventListener = void Function(SvgEvent event);

/// Represents an event listener registration.
@immutable
class SvgEventListenerEntry {
  const SvgEventListenerEntry({
    required this.type,
    required this.listener,
    this.capture = false,
    this.once = false,
    this.passive = false,
  });

  /// The event type to listen for.
  final String type;

  /// The callback function.
  final SvgEventListener listener;

  /// Whether to use capture phase.
  final bool capture;

  /// Whether to remove after first invocation.
  final bool once;

  /// Whether the listener is passive (cannot call preventDefault).
  final bool passive;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SvgEventListenerEntry &&
          type == other.type &&
          listener == other.listener &&
          capture == other.capture;

  @override
  int get hashCode => Object.hash(type, listener, capture);
}
