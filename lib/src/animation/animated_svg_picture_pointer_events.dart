part of 'animated_svg_picture.dart';

extension _AnimatedSvgPictureStatePointerEventsExtension
    on _AnimatedSvgPictureState {
  String _resolvePointerEventsMode(SvgNode node) {
    final raw = _resolveInheritedPointerEvents(node);
    if (raw == null || raw.isEmpty || raw == 'auto') {
      return 'visiblepainted';
    }
    switch (raw) {
      case 'none':
      case 'visiblepainted':
      case 'visiblefill':
      case 'visiblestroke':
      case 'visible':
      case 'painted':
      case 'fill':
      case 'stroke':
      case 'all':
      case 'bounding-box':
        return raw;
      default:
        return 'visiblepainted';
    }
  }

  bool _pointerEventsAllowsFill(
    SvgNode node,
    String pointerEvents, {
    required bool visibilityHidden,
  }) {
    switch (pointerEvents) {
      case 'visiblepainted':
        if (visibilityHidden) {
          return false;
        }
        return _isFillEnabled(node);
      case 'visiblefill':
      case 'visible':
        return !visibilityHidden;
      case 'visiblestroke':
        return false;
      case 'painted':
        return _isFillEnabled(node);
      case 'fill':
      case 'all':
      case 'bounding-box':
        return true;
      case 'none':
      case 'stroke':
        return false;
      default:
        return _isFillEnabled(node);
    }
  }

  bool _pointerEventsAllowsStroke(
    SvgNode node,
    String pointerEvents, {
    required bool visibilityHidden,
  }) {
    switch (pointerEvents) {
      case 'visiblepainted':
        if (visibilityHidden) {
          return false;
        }
        return _hasStroke(node);
      case 'visiblestroke':
      case 'visible':
        return !visibilityHidden;
      case 'visiblefill':
        return false;
      case 'painted':
        return _hasStroke(node);
      case 'stroke':
      case 'all':
      case 'bounding-box':
        return true;
      case 'none':
      case 'fill':
        return false;
      default:
        return _hasStroke(node);
    }
  }

  bool _pointerEventsAllowsBoundingBox(
    String pointerEvents, {
    required bool visibilityHidden,
  }) {
    switch (pointerEvents) {
      case 'none':
      case 'stroke':
      case 'visiblestroke':
        return false;
      case 'visible':
      case 'visiblepainted':
      case 'visiblefill':
        return !visibilityHidden;
      default:
        return true;
    }
  }

  String? _resolveInheritedPointerEvents(SvgNode node) {
    SvgNode? current = node;
    while (current != null) {
      final styleValue = _extractStyleValue(current, 'pointer-events');
      final raw = styleValue ?? current.getAttributeValue('pointer-events');
      final normalized = raw?.toString().trim().toLowerCase();
      if (normalized == null || normalized.isEmpty) {
        current = current.parent;
        continue;
      }
      if (normalized == 'inherit') {
        current = current.parent;
        continue;
      }
      return normalized;
    }
    return null;
  }
}
