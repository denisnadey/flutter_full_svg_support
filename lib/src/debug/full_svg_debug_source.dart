import 'package:flutter/widgets.dart';

/// Debug-only source metadata propagated to the converged renderer state.
class FullSvgDebugSourceScope extends InheritedWidget {
  const FullSvgDebugSourceScope({
    required this.sourceType,
    required this.sourceLabel,
    required super.child,
    super.key,
  });

  final String sourceType;
  final String sourceLabel;

  static FullSvgDebugSourceScope? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<FullSvgDebugSourceScope>();
  }

  @override
  bool updateShouldNotify(FullSvgDebugSourceScope oldWidget) {
    return sourceType != oldWidget.sourceType ||
        sourceLabel != oldWidget.sourceLabel;
  }
}

/// Adds source metadata in debug builds and compiles to an identity function
/// in release builds.
Widget wrapWithFullSvgDebugSource({
  required Widget child,
  required String sourceType,
  required String sourceLabel,
}) {
  var result = child;
  assert(() {
    result = FullSvgDebugSourceScope(
      sourceType: sourceType,
      sourceLabel: sourceLabel,
      child: child,
    );
    return true;
  }());
  return result;
}
