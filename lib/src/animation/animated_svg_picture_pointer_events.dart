part of 'animated_svg_picture.dart';

extension _AnimatedSvgPictureStatePointerEventsExtension
    on _AnimatedSvgPictureState {
  /// Resolves the effective pointer-events mode for a node.
  /// Handles inheritance and normalizes values.
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

  /// Checks if pointer-events="none" blocks all events.
  /// Returns true if events should be completely blocked.
  bool _isPointerEventsBlocked(SvgNode node) {
    final mode = _resolvePointerEventsMode(node);
    return mode == 'none';
  }

  /// Checks if pointer-events="all" allows events on invisible elements.
  /// Returns true if events fire even on invisible/unpainted areas.
  bool _pointerEventsAllowsAll(SvgNode node) {
    final mode = _resolvePointerEventsMode(node);
    return mode == 'all';
  }

  /// Checks if the element should receive pointer events based on its mode
  /// and visibility state.
  bool _shouldReceivePointerEvents(
    SvgNode node, {
    required bool visibilityHidden,
    required bool hitFill,
    required bool hitStroke,
  }) {
    final mode = _resolvePointerEventsMode(node);

    switch (mode) {
      case 'none':
        // Never receive events
        return false;

      case 'all':
        // Always receive events, regardless of visibility or paint
        return true;

      case 'visible':
        // Only visible elements receive events (any part)
        return !visibilityHidden;

      case 'visiblepainted':
        // Default: visible AND (fill painted OR stroke painted)
        if (visibilityHidden) return false;
        return (hitFill && _isFillEnabled(node)) ||
            (hitStroke && _hasStroke(node));

      case 'visiblefill':
        // Visible AND fill area
        if (visibilityHidden) return false;
        return hitFill;

      case 'visiblestroke':
        // Visible AND stroke area
        if (visibilityHidden) return false;
        return hitStroke;

      case 'painted':
        // Fill or stroke painted (ignores visibility)
        return (hitFill && _isFillEnabled(node)) ||
            (hitStroke && _hasStroke(node));

      case 'fill':
        // Fill area only (ignores visibility and paint)
        return hitFill;

      case 'stroke':
        // Stroke area only (ignores visibility and paint)
        return hitStroke;

      case 'bounding-box':
        // Entire bounding box receives events
        return true;

      default:
        // Fallback to visiblePainted behavior
        if (visibilityHidden) return false;
        return (hitFill && _isFillEnabled(node)) ||
            (hitStroke && _hasStroke(node));
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
        // visibleFill: requires visibility AND fill to be enabled
        return !visibilityHidden && _isFillEnabled(node);
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
        // visibleStroke: requires visibility AND stroke to be enabled
        return !visibilityHidden && _hasStroke(node);
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
