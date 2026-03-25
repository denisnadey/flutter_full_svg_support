part of 'animated_svg_picture.dart';

extension _AnimatedSvgPictureStateEventsExtension on _AnimatedSvgPictureState {
  /// Handle tap with full W3C event model support.
  /// Events bubble through the DOM tree and get retargeted through <use> shadows.
  void _handleTapDown(TapDownDetails details) {
    final hitResult = _hitTestWithEventModel(details.localPosition);
    final actualTargetId = hitResult.elementId;
    // For SMIL events, use retargeted ID (the use element if inside shadow)
    final retargetedId = hitResult.retargetedElementId;

    _trace(
      category: 'event',
      message: 'Tap detected',
      data: <String, Object?>{
        'x': details.localPosition.dx,
        'y': details.localPosition.dy,
        'targetId': actualTargetId,
        'retargetedId': retargetedId,
        'useElementId': hitResult.useElementId,
        'composedPath': hitResult.composedPath,
        'anchorHref': hitResult.anchorInfo?.href,
        'anchorTarget': hitResult.anchorInfo?.target,
      },
    );

    // Handle anchor (link) tap if present
    if (hitResult.anchorInfo != null && widget.onLinkTap != null) {
      widget.onLinkTap!(hitResult.anchorInfo!);
    }

    // Set :active state on retargeted element
    if (retargetedId != null) {
      _document.pseudoClassState.setActive(retargetedId, true);
      // Set :focus state on tap (triggers focusin event)
      _document.pseudoClassState.setFocus(retargetedId);
    }

    // Trigger click events with bubbling through ancestor chain
    _dispatchEventWithBubbling(
      eventType: 'click',
      targetId: retargetedId,
      composedPath: hitResult.composedPath,
    );

    _markNeedsRepaint();
  }

  /// Dispatch an event that bubbles through the DOM tree.
  /// Events fire on target first, then bubble up to ancestors.
  void _dispatchEventWithBubbling({
    required String eventType,
    required String? targetId,
    required List<String> composedPath,
  }) {
    // Trigger on target element
    if (targetId != null) {
      _timeline?.triggerEvent(targetId, eventType);
    }

    // Bubble through ancestor chain (skip target, which is last in path)
    for (int i = composedPath.length - 2; i >= 0; i--) {
      final ancestorId = composedPath[i];
      _timeline?.triggerEvent(ancestorId, eventType);
    }

    // Document-level event as final fallback
    _timeline?.triggerEvent(null, eventType);
  }

  /// Handle tap up / tap cancel to clear :active state
  void _handleTapUp() {
    _document.pseudoClassState.clearActive();
    _markNeedsRepaint();
  }

  /// Handle mouse enter into the SVG widget bounds
  void _handleMouseEnter(Offset position) {
    _timeline?.triggerEvent(null, 'mouseover');
    _trace(
      category: 'event',
      message: 'Mouse entered widget bounds',
      data: <String, Object?>{'x': position.dx, 'y': position.dy},
    );
    _updateHoveredElement(position);
  }

  /// Handle mouse exit from the SVG widget bounds
  void _handleMouseExit() {
    final oldHoveredId = _hoveredElementId;
    if (oldHoveredId != null) {
      // Fire mouseout (bubbles) then mouseleave (non-bubbling)
      _timeline?.triggerEvent(oldHoveredId, 'mouseout');
      _timeline?.triggerEvent(oldHoveredId, 'mouseleave');
      _trace(
        category: 'event',
        message: 'Mouse out from hovered element',
        data: <String, Object?>{'targetId': oldHoveredId},
      );
      // Clear :hover state
      _document.pseudoClassState.setHovered(oldHoveredId, false);
      _hoveredElementId = null;
    }
    _hoveredAnchorInfo = null;
    _timeline?.triggerEvent(null, 'mouseout');
    _trace(category: 'event', message: 'Mouse exited widget bounds');
    // Clear all :active states on mouse exit
    _document.pseudoClassState.clearActive();
    _markNeedsRepaint();
  }

  /// Handle mouse hover movement over the SVG
  void _handleMouseHover(Offset position) {
    _updateHoveredElement(position);
  }

  void _updateHoveredElement(Offset position) {
    final hitResult = _hitTestWithEventModel(position);
    // Use retargeted element for hover state
    final hitElementId = hitResult.retargetedElementId;
    final hitAnchorInfo = hitResult.anchorInfo;

    // Check if anchor changed (for cursor update)
    final anchorChanged = _hoveredAnchorInfo?.href != hitAnchorInfo?.href;

    if (hitElementId == _hoveredElementId && !anchorChanged) {
      return;
    }

    final oldHoveredId = _hoveredElementId;

    // Clear old :hover state and fire mouseout/mouseleave
    if (oldHoveredId != null) {
      // mouseout bubbles
      _timeline?.triggerEvent(oldHoveredId, 'mouseout');
      // mouseleave doesn't bubble
      _timeline?.triggerEvent(oldHoveredId, 'mouseleave');
      _document.pseudoClassState.setHovered(oldHoveredId, false);
    }

    // Set new :hover state and fire mouseover/mouseenter
    if (hitElementId != null) {
      // mouseenter doesn't bubble - only fires on the entered element
      _timeline?.triggerEvent(hitElementId, 'mouseenter');
      // mouseover bubbles
      _timeline?.triggerEvent(hitElementId, 'mouseover');
      _document.pseudoClassState.setHovered(hitElementId, true);
    }

    _hoveredElementId = hitElementId;
    _hoveredAnchorInfo = hitAnchorInfo;
    _trace(
      category: 'event',
      level: SvgTraceLevel.debug,
      message: 'Hovered element changed',
      data: <String, Object?>{
        'targetId': _hoveredElementId,
        'anchorHref': _hoveredAnchorInfo?.href,
        'x': position.dx,
        'y': position.dy,
      },
    );
    _markNeedsRepaint();
  }
}

/// Extension for gesture events (long press, pan/drag).
extension _AnimatedSvgPictureStateGestureEventsExtension
    on _AnimatedSvgPictureState {
  /// Handle long press start - fires 'longpress' event.
  void _handleLongPressStart(LongPressStartDetails details) {
    final hitResult = _hitTestWithEventModel(details.localPosition);
    final retargetedId = hitResult.retargetedElementId;

    _trace(
      category: 'event',
      message: 'Long press started',
      data: <String, Object?>{
        'x': details.localPosition.dx,
        'y': details.localPosition.dy,
        'targetId': retargetedId,
      },
    );

    _dispatchEventWithBubbling(
      eventType: 'longpress',
      targetId: retargetedId,
      composedPath: hitResult.composedPath,
    );
    _markNeedsRepaint();
  }

  /// Handle long press end.
  void _handleLongPressEnd(LongPressEndDetails details) {
    _trace(
      category: 'event',
      message: 'Long press ended',
      data: <String, Object?>{
        'x': details.localPosition.dx,
        'y': details.localPosition.dy,
      },
    );
    _markNeedsRepaint();
  }

  /// Handle pan start - fires 'panstart' event.
  void _handlePanStart(DragStartDetails details) {
    final hitResult = _hitTestWithEventModel(details.localPosition);
    final retargetedId = hitResult.retargetedElementId;

    _trace(
      category: 'event',
      message: 'Pan started',
      data: <String, Object?>{
        'x': details.localPosition.dx,
        'y': details.localPosition.dy,
        'targetId': retargetedId,
      },
    );

    _dispatchEventWithBubbling(
      eventType: 'panstart',
      targetId: retargetedId,
      composedPath: hitResult.composedPath,
    );
    _markNeedsRepaint();
  }

  /// Handle pan update - fires 'panupdate' event.
  void _handlePanUpdate(DragUpdateDetails details) {
    final hitResult = _hitTestWithEventModel(details.localPosition);
    final retargetedId = hitResult.retargetedElementId;

    _trace(
      category: 'event',
      level: SvgTraceLevel.debug,
      message: 'Pan update',
      data: <String, Object?>{
        'x': details.localPosition.dx,
        'y': details.localPosition.dy,
        'dx': details.delta.dx,
        'dy': details.delta.dy,
        'targetId': retargetedId,
      },
    );

    _dispatchEventWithBubbling(
      eventType: 'panupdate',
      targetId: retargetedId,
      composedPath: hitResult.composedPath,
    );
    _markNeedsRepaint();
  }

  /// Handle pan end - fires 'panend' event.
  void _handlePanEnd(DragEndDetails details) {
    _trace(
      category: 'event',
      message: 'Pan ended',
      data: <String, Object?>{
        'velocityX': details.velocity.pixelsPerSecond.dx,
        'velocityY': details.velocity.pixelsPerSecond.dy,
      },
    );

    // Document-level event as we don't have position at end
    _timeline?.triggerEvent(null, 'panend');
    _markNeedsRepaint();
  }
}

/// Extension for pointer events (pointerdown, pointermove, pointerup).
extension _AnimatedSvgPictureStatePointerEventsHandlersExtension
    on _AnimatedSvgPictureState {
  /// Handle pointer down - fires 'pointerdown' event.
  void _handlePointerDown(PointerDownEvent event) {
    final hitResult = _hitTestWithEventModel(event.localPosition);
    final retargetedId = hitResult.retargetedElementId;

    _trace(
      category: 'event',
      message: 'Pointer down',
      data: <String, Object?>{
        'x': event.localPosition.dx,
        'y': event.localPosition.dy,
        'pointerId': event.pointer,
        'pointerKind': event.kind.toString(),
        'targetId': retargetedId,
      },
    );

    _dispatchEventWithBubbling(
      eventType: 'pointerdown',
      targetId: retargetedId,
      composedPath: hitResult.composedPath,
    );
    _markNeedsRepaint();
  }

  /// Handle pointer move - fires 'pointermove' event.
  void _handlePointerMove(PointerMoveEvent event) {
    final hitResult = _hitTestWithEventModel(event.localPosition);
    final retargetedId = hitResult.retargetedElementId;

    _dispatchEventWithBubbling(
      eventType: 'pointermove',
      targetId: retargetedId,
      composedPath: hitResult.composedPath,
    );
  }

  /// Handle pointer up - fires 'pointerup' event.
  void _handlePointerUp(PointerUpEvent event) {
    final hitResult = _hitTestWithEventModel(event.localPosition);
    final retargetedId = hitResult.retargetedElementId;

    _trace(
      category: 'event',
      message: 'Pointer up',
      data: <String, Object?>{
        'x': event.localPosition.dx,
        'y': event.localPosition.dy,
        'pointerId': event.pointer,
        'targetId': retargetedId,
      },
    );

    _dispatchEventWithBubbling(
      eventType: 'pointerup',
      targetId: retargetedId,
      composedPath: hitResult.composedPath,
    );
    _markNeedsRepaint();
  }

  /// Handle pointer cancel - fires 'pointercancel' event.
  void _handlePointerCancel(PointerCancelEvent event) {
    _trace(
      category: 'event',
      message: 'Pointer cancelled',
      data: <String, Object?>{'pointerId': event.pointer},
    );

    _timeline?.triggerEvent(null, 'pointercancel');
    _markNeedsRepaint();
  }
}

/// Extension for focus events (focusin, focusout).
extension _AnimatedSvgPictureStateFocusEventsExtension
    on _AnimatedSvgPictureState {
  /// Triggers focusin event when an element gains focus.
  void _triggerFocusIn(String elementId) {
    _trace(
      category: 'event',
      message: 'Focus in',
      data: <String, Object?>{'targetId': elementId},
    );

    _timeline?.triggerEvent(elementId, 'focusin');
    _timeline?.triggerEvent(elementId, 'focus');
    _markNeedsRepaint();
  }

  /// Triggers focusout event when an element loses focus.
  void _triggerFocusOut(String elementId) {
    _trace(
      category: 'event',
      message: 'Focus out',
      data: <String, Object?>{'targetId': elementId},
    );

    _timeline?.triggerEvent(elementId, 'focusout');
    _timeline?.triggerEvent(elementId, 'blur');
    _markNeedsRepaint();
  }
}
