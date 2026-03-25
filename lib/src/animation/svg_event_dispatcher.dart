/// SVG Event Dispatcher implementing W3C DOM event dispatch algorithm.
///
/// Handles event path construction, capture phase, target phase, and bubble
/// phase with proper event retargeting through <use> shadow boundaries.
library;

import 'svg_dom.dart';
import 'svg_event.dart';

/// Result of a hit test including event path information.
class SvgHitTestResult {
  const SvgHitTestResult({
    required this.target,
    this.useElement,
    required this.eventPath,
    required this.composedPath,
  });

  /// The actual element hit.
  final SvgNode target;

  /// The <use> element if the target is inside a use shadow tree.
  final SvgNode? useElement;

  /// The event path for bubbling (may be retargeted).
  final List<SvgNode> eventPath;

  /// The composed path including shadow elements.
  final List<SvgNode> composedPath;

  /// Whether the hit is inside a <use> shadow tree.
  bool get isInsideUseShadow => useElement != null;
}

/// Manages event listeners on SVG elements.
class SvgEventTarget {
  final Map<String, List<SvgEventListenerEntry>> _listeners = {};

  /// Adds an event listener.
  void addEventListener(
    String type,
    SvgEventListener listener, {
    bool capture = false,
    bool once = false,
    bool passive = false,
  }) {
    final entry = SvgEventListenerEntry(
      type: type,
      listener: listener,
      capture: capture,
      once: once,
      passive: passive,
    );
    _listeners.putIfAbsent(type, () => []).add(entry);
  }

  /// Removes an event listener.
  void removeEventListener(
    String type,
    SvgEventListener listener, {
    bool capture = false,
  }) {
    final typeListeners = _listeners[type];
    if (typeListeners == null) return;

    typeListeners.removeWhere(
      (entry) =>
          entry.listener == listener &&
          entry.capture == capture,
    );
  }

  /// Gets all listeners for a given type and phase.
  List<SvgEventListenerEntry> getListeners(String type, {required bool capture}) {
    final typeListeners = _listeners[type];
    if (typeListeners == null) return const [];
    return typeListeners.where((e) => e.capture == capture).toList();
  }

  /// Dispatches an event to this target.
  /// Returns true if the event was not prevented.
  bool dispatchEvent(SvgEvent event) {
    final typeListeners = _listeners[event.type];
    if (typeListeners == null || typeListeners.isEmpty) return !event.defaultPrevented;

    final phase = event.eventPhase;
    final useCapture = phase == SvgEventPhase.capturing;

    final toRemove = <SvgEventListenerEntry>[];

    for (final entry in List.of(typeListeners)) {
      // Skip if phase doesn't match
      if (phase != SvgEventPhase.atTarget) {
        if (entry.capture != useCapture) continue;
      }

      // Invoke the listener
      entry.listener(event);

      // Mark for removal if once
      if (entry.once) {
        toRemove.add(entry);
      }

      // Stop if immediate propagation was stopped
      if (event.immediatePropagationStopped) break;
    }

    // Remove one-time listeners
    for (final entry in toRemove) {
      typeListeners.remove(entry);
    }

    return !event.defaultPrevented;
  }
}

/// Event targets map for storing listeners per element.
class SvgEventTargetRegistry {
  final Map<String, SvgEventTarget> _targets = {};

  /// Gets or creates an event target for an element.
  SvgEventTarget getOrCreate(String elementId) {
    return _targets.putIfAbsent(elementId, () => SvgEventTarget());
  }

  /// Gets an event target for an element, if it exists.
  SvgEventTarget? get(String elementId) {
    return _targets[elementId];
  }

  /// Removes all listeners.
  void clear() {
    _targets.clear();
  }
}

/// SVG Event dispatcher implementing the W3C DOM event dispatch algorithm.
class SvgEventDispatcher {
  SvgEventDispatcher({required this.document, required this.registry});

  /// The SVG document.
  final SvgDocument document;

  /// Event target registry.
  final SvgEventTargetRegistry registry;

  /// Builds the event path from target to root.
  ///
  /// Returns a list starting with the root and ending with the target,
  /// suitable for capture phase traversal.
  List<SvgNode> buildEventPath(SvgNode target) {
    final path = <SvgNode>[];
    SvgNode? current = target;

    while (current != null) {
      path.add(current);
      current = current.parent;
    }

    // Path is target -> ... -> root, reverse for capture phase
    return path.reversed.toList();
  }

  /// Builds the composed path including shadow tree elements.
  ///
  /// For elements inside a <use> shadow tree, includes both the shadow
  /// elements and the <use> element's ancestors.
  List<SvgNode> buildComposedPath(
    SvgNode target, {
    SvgNode? useElement,
    List<SvgNode>? shadowPath,
  }) {
    final path = <SvgNode>[];

    // Add the shadow path if inside a use element
    if (shadowPath != null) {
      path.addAll(shadowPath);
    }

    // Add the use element and its ancestors
    if (useElement != null) {
      SvgNode? current = useElement;
      while (current != null) {
        path.add(current);
        current = current.parent;
      }
    } else {
      // Not inside a use, just build normal path
      SvgNode? current = target;
      while (current != null) {
        path.add(current);
        current = current.parent;
      }
    }

    return path;
  }

  /// Builds the retargeted path for non-composed events.
  ///
  /// When an event fires on an element inside a <use> shadow tree
  /// and the event is not composed, the path starts from the <use> element.
  List<SvgNode> buildRetargetedPath(SvgNode useElement) {
    final path = <SvgNode>[];
    SvgNode? current = useElement;

    while (current != null) {
      path.add(current);
      current = current.parent;
    }

    return path;
  }

  /// Dispatches an event following the W3C DOM event dispatch algorithm.
  ///
  /// 1. Capture phase: Event travels from root to target
  /// 2. Target phase: Event is at the target
  /// 3. Bubble phase: Event travels from target to root (if bubbles)
  bool dispatchEvent(
    SvgEvent event, {
    required SvgNode target,
    SvgNode? useElement,
    List<SvgNode>? shadowPath,
  }) {
    // Set event target (may be retargeted for non-composed events)
    event.setTargetInternal(target);
    event.setUseElementInternal(useElement);

    // Build paths
    final composedPath = buildComposedPath(
      target,
      useElement: useElement,
      shadowPath: shadowPath,
    );
    event.setComposedPathInternal(composedPath);

    // For non-composed events inside use shadow, build retargeted path
    if (useElement != null && !event.composed) {
      event.setRetargetedPathInternal(buildRetargetedPath(useElement));
    }

    // Get the path for event dispatch
    final dispatchPath = event.path;
    if (dispatchPath.isEmpty) return true;

    // Reverse for capture phase (root -> target)
    final capturePath = dispatchPath.reversed.toList();
    final effectiveTarget = event.target;

    // Phase 1: Capture phase
    event.setEventPhaseInternal(SvgEventPhase.capturing);
    for (int i = 0; i < capturePath.length - 1; i++) {
      final node = capturePath[i];
      event.setCurrentTargetInternal(node);

      if (node.id != null) {
        final eventTarget = registry.get(node.id!);
        if (eventTarget != null) {
          eventTarget.dispatchEvent(event);
          if (event.propagationStopped) {
            event.setEventPhaseInternal(SvgEventPhase.none);
            event.setCurrentTargetInternal(null);
            return !event.defaultPrevented;
          }
        }
      }
    }

    // Phase 2: Target phase
    event.setEventPhaseInternal(SvgEventPhase.atTarget);
    event.setCurrentTargetInternal(effectiveTarget);

    if (effectiveTarget?.id != null) {
      final eventTarget = registry.get(effectiveTarget!.id!);
      if (eventTarget != null) {
        eventTarget.dispatchEvent(event);
        if (event.propagationStopped) {
          event.setEventPhaseInternal(SvgEventPhase.none);
          event.setCurrentTargetInternal(null);
          return !event.defaultPrevented;
        }
      }
    }

    // Phase 3: Bubble phase (if event bubbles)
    if (event.bubbles) {
      event.setEventPhaseInternal(SvgEventPhase.bubbling);

      // Traverse from parent of target to root
      for (int i = dispatchPath.length - 2; i >= 0; i--) {
        final node = dispatchPath[i];
        event.setCurrentTargetInternal(node);

        if (node.id != null) {
          final eventTarget = registry.get(node.id!);
          if (eventTarget != null) {
            eventTarget.dispatchEvent(event);
            if (event.propagationStopped) {
              break;
            }
          }
        }
      }
    }

    // Reset event state
    event.setEventPhaseInternal(SvgEventPhase.none);
    event.setCurrentTargetInternal(null);

    return !event.defaultPrevented;
  }

  /// Dispatches a non-bubbling event (like mouseenter, mouseleave).
  ///
  /// Only fires on the target element, no capture or bubble phase.
  void dispatchNonBubblingEvent(SvgEvent event, SvgNode target) {
    event.setTargetInternal(target);
    event.setEventPhaseInternal(SvgEventPhase.atTarget);
    event.setCurrentTargetInternal(target);

    if (target.id != null) {
      final eventTarget = registry.get(target.id!);
      eventTarget?.dispatchEvent(event);
    }

    event.setEventPhaseInternal(SvgEventPhase.none);
    event.setCurrentTargetInternal(null);
  }

  /// Checks if an element is an ancestor of another.
  bool isAncestor(SvgNode ancestor, SvgNode descendant) {
    SvgNode? current = descendant.parent;
    while (current != null) {
      if (current == ancestor) return true;
      current = current.parent;
    }
    return false;
  }

  /// Finds the common ancestor of two nodes.
  SvgNode? findCommonAncestor(SvgNode a, SvgNode b) {
    final ancestorsA = <SvgNode>{};
    SvgNode? current = a;
    while (current != null) {
      ancestorsA.add(current);
      current = current.parent;
    }

    current = b;
    while (current != null) {
      if (ancestorsA.contains(current)) return current;
      current = current.parent;
    }

    return null;
  }
}

/// Non-bubbling event types (mouseenter/mouseleave).
const Set<String> nonBubblingEventTypes = {
  'mouseenter',
  'mouseleave',
  'pointerenter',
  'pointerleave',
};

/// Check if an event type should bubble.
bool shouldEventBubble(String type) {
  return !nonBubblingEventTypes.contains(type);
}
