part of 'animated_svg_picture.dart';

extension _AnimatedSvgPictureStateCoreUtilsExtension
    on _AnimatedSvgPictureState {
  bool _isFillEnabled(SvgNode node) {
    final fill = _getInheritedAttributeValue(node, 'fill');
    return !_isPaintNone(fill);
  }

  bool _hasStroke(SvgNode node) {
    final stroke = _getInheritedAttributeValue(node, 'stroke');
    return stroke != null && !_isPaintNone(stroke);
  }

  double _strokeTolerance(SvgNode node) {
    final strokeWidth = _getInheritedNumber(node, 'stroke-width') ?? 1.0;
    // Use actual stroke-width/2 for hit tolerance without artificial clamping.
    // Minimum 0.5 ensures hairline strokes remain hittable.
    return math.max(strokeWidth / 2, 0.5);
  }

  /// Returns extra hit tolerance at line endpoints based on stroke-linecap.
  /// - butt: no extra (returns 0)
  /// - round: adds strokeWidth/2 radius at endpoints
  /// - square: adds strokeWidth/2 extension at endpoints
  double _strokeLinecapTolerance(SvgNode node) {
    final linecap =
        _getInheritedString(node, 'stroke-linecap')?.toLowerCase() ?? 'butt';
    if (linecap == 'butt') {
      return 0.0;
    }
    // Both round and square add strokeWidth/2 extension at endpoints
    final strokeWidth = _getInheritedNumber(node, 'stroke-width') ?? 1.0;
    return strokeWidth / 2;
  }

  bool _isPaintNone(Object? value) {
    if (value is Color && value.a <= 0) {
      return true;
    }
    final str = value?.toString().trim().toLowerCase();
    return str == 'none';
  }

  bool _isVisibilityHidden(SvgNode node) {
    final visibility = _getInheritedString(node, 'visibility')?.toLowerCase();
    return visibility == 'hidden' || visibility == 'collapse';
  }

  /// Checks if opacity causes non-visibility.
  /// Per CSS spec, opacity:0 elements are STILL hit-testable.
  /// This method returns true only when opacity should prevent hit-testing
  /// which is NEVER - opacity doesn't affect pointer events.
  bool _isZeroOpacity(SvgNode node) {
    final opacity = _getInheritedNumber(node, 'opacity');
    // opacity:0 is still hit-testable per CSS spec
    // This is only used for informational purposes
    return opacity != null && opacity <= 0;
  }

  /// Checks if the pointer-events mode requires visibility for hit testing.
  /// Per SVG spec:
  /// - visible* modes (visiblePainted, visibleFill, visibleStroke, visible)
  ///   require the element to be visible
  /// - other modes (painted, fill, stroke, all) do NOT require visibility
  bool _pointerEventsRequiresVisibility(String? pointerEventsMode) {
    if (pointerEventsMode == null) return true; // default is visiblePainted
    switch (pointerEventsMode.toLowerCase()) {
      case 'visiblepainted':
      case 'visiblefill':
      case 'visiblestroke':
      case 'visible':
        return true;
      case 'painted':
      case 'fill':
      case 'stroke':
      case 'all':
      case 'bounding-box':
        return false;
      default:
        return true; // default assumes visibility required
    }
  }

  /// Checks if element is excluded from hit-testing due to visibility/display.
  /// Note: opacity:0 does NOT exclude from hit-testing per CSS spec.
  ///
  /// Per SVG spec, visibility:hidden only excludes hit testing for visible*
  /// pointer-events modes. For modes like 'painted', 'fill', 'stroke', 'all',
  /// visibility:hidden elements can still be hit-tested if they have paint.
  ///
  /// [pointerEventsMode] - the resolved pointer-events mode for the element.
  /// If null, assumes visibility is required (default visiblePainted behavior).
  bool _isHitTestExcluded(SvgNode node, {String? pointerEventsMode}) {
    // display:none always excludes from hit-testing
    if (_isDisplayNone(node)) return true;
    // visibility:hidden only excludes when pointer-events requires visibility
    if (_pointerEventsRequiresVisibility(pointerEventsMode)) {
      if (_isVisibilityHidden(node)) return true;
    }
    // opacity:0 does NOT exclude - element is still hit-testable
    return false;
  }

  bool _isDisplayNone(SvgNode node) {
    final styleValue = _extractStyleValue(node, 'display');
    final rawValue = styleValue ?? node.getAttributeValue('display');
    final display = rawValue?.toString().trim().toLowerCase();
    return display == 'none';
  }

  void _trace({
    required String category,
    required String message,
    SvgTraceLevel level = SvgTraceLevel.info,
    Map<String, Object?> data = const <String, Object?>{},
    Object? error,
    StackTrace? stackTrace,
  }) {
    final callback = widget.onTrace;
    if (callback == null) {
      return;
    }
    callback(
      SvgTraceEvent(
        timestamp: DateTime.now(),
        level: level,
        category: category,
        message: message,
        data: data,
        error: error,
        stackTrace: stackTrace,
      ),
    );
  }
}
