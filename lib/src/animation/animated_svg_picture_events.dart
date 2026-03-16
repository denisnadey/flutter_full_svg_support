part of 'animated_svg_picture.dart';

extension _AnimatedSvgPictureStateEventsExtension on _AnimatedSvgPictureState {
  /// Обработать клик с координатами (может триггерить клик на элемент)
  void _handleTapDown(TapDownDetails details) {
    final targetId = _hitTestElementId(details.localPosition);
    _trace(
      category: 'event',
      message: 'Tap detected',
      data: <String, Object?>{
        'x': details.localPosition.dx,
        'y': details.localPosition.dy,
        'targetId': targetId,
      },
    );
    if (targetId != null) {
      _timeline?.triggerEvent(targetId, 'click');
    }
    // Поддерживаем document-level click как fallback/всплытие
    _timeline?.triggerEvent(null, 'click');
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
      _hoveredElementId = null;
    }
    _timeline?.triggerEvent(null, 'mouseout');
    _trace(category: 'event', message: 'Mouse exited widget bounds');
    _markNeedsRepaint();
  }

  /// Обработать движение мыши над SVG
  void _handleMouseHover(Offset position) {
    _updateHoveredElement(position);
  }

  void _updateHoveredElement(Offset position) {
    final hitElementId = _hitTestElementId(position);
    if (hitElementId == _hoveredElementId) {
      return;
    }

    if (_hoveredElementId != null) {
      _timeline?.triggerEvent(_hoveredElementId, 'mouseout');
    }
    if (hitElementId != null) {
      _timeline?.triggerEvent(hitElementId, 'mouseover');
    }

    _hoveredElementId = hitElementId;
    _trace(
      category: 'event',
      level: SvgTraceLevel.debug,
      message: 'Hovered element changed',
      data: <String, Object?>{
        'targetId': _hoveredElementId,
        'x': position.dx,
        'y': position.dy,
      },
    );
    _markNeedsRepaint();
  }
}
