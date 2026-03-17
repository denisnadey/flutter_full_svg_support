part of 'animated_svg_picture.dart';

extension _AnimatedSvgPictureStateEventsExtension on _AnimatedSvgPictureState {
  /// Обработать клик с координатами (может триггерить клик на элемент)
  void _handleTapDown(TapDownDetails details) {
    final hitResult = _hitTestWithAnchorInfo(details.localPosition);
    final targetId = hitResult.elementId;
    _trace(
      category: 'event',
      message: 'Tap detected',
      data: <String, Object?>{
        'x': details.localPosition.dx,
        'y': details.localPosition.dy,
        'targetId': targetId,
        'anchorHref': hitResult.anchorInfo?.href,
        'anchorTarget': hitResult.anchorInfo?.target,
      },
    );

    // Handle anchor (link) tap if present
    if (hitResult.anchorInfo != null && widget.onLinkTap != null) {
      widget.onLinkTap!(hitResult.anchorInfo!);
    }
    
    // Set :active state
    if (targetId != null) {
      _document.pseudoClassState.setActive(targetId, true);
      // Set :focus state on tap
      _document.pseudoClassState.setFocus(targetId);
    }
    
    if (targetId != null) {
      _timeline?.triggerEvent(targetId, 'click');
    }
    // Поддерживаем document-level click как fallback/всплытие
    _timeline?.triggerEvent(null, 'click');
    _markNeedsRepaint();
  }

  /// Handle tap up / tap cancel to clear :active state
  void _handleTapUp() {
    _document.pseudoClassState.clearActive();
    _markNeedsRepaint();
  }

  /// Обработать вход мыши в область SVG
  void _handleMouseEnter(Offset position) {
    _timeline?.triggerEvent(null, 'mouseover');
    _trace(
      category: 'event',
      message: 'Mouse entered widget bounds',
      data: <String, Object?>{'x': position.dx, 'y': position.dy},
    );
    _updateHoveredElement(position);
  }

  /// Обработать выход мыши из области SVG
  void _handleMouseExit() {
    if (_hoveredElementId != null) {
      _timeline?.triggerEvent(_hoveredElementId, 'mouseout');
      _trace(
        category: 'event',
        message: 'Mouse out from hovered element',
        data: <String, Object?>{'targetId': _hoveredElementId},
      );
      // Clear :hover state
      _document.pseudoClassState.setHovered(_hoveredElementId!, false);
      _hoveredElementId = null;
    }
    _hoveredAnchorInfo = null;
    _timeline?.triggerEvent(null, 'mouseout');
    _trace(category: 'event', message: 'Mouse exited widget bounds');
    // Clear all :active states on mouse exit
    _document.pseudoClassState.clearActive();
    _markNeedsRepaint();
  }

  /// Обработать движение мыши над SVG
  void _handleMouseHover(Offset position) {
    _updateHoveredElement(position);
  }

  void _updateHoveredElement(Offset position) {
    final hitResult = _hitTestWithAnchorInfo(position);
    final hitElementId = hitResult.elementId;
    final hitAnchorInfo = hitResult.anchorInfo;

    // Check if anchor changed (for cursor update)
    final anchorChanged = _hoveredAnchorInfo?.href != hitAnchorInfo?.href;

    if (hitElementId == _hoveredElementId && !anchorChanged) {
      return;
    }

    // Clear old :hover state
    if (_hoveredElementId != null) {
      _timeline?.triggerEvent(_hoveredElementId, 'mouseout');
      _document.pseudoClassState.setHovered(_hoveredElementId!, false);
    }
    
    // Set new :hover state
    if (hitElementId != null) {
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
