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

  bool _isPointerEventsNone(SvgNode node) {
    return _resolvePointerEventsMode(node) == 'none';
  }

  bool _isVisibilityHidden(SvgNode node) {
    final visibility = _getInheritedString(node, 'visibility')?.toLowerCase();
    return visibility == 'hidden' || visibility == 'collapse';
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
