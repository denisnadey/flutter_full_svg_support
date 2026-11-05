import 'svg_dom.dart';

/// Whether SVG `<script>` elements are executed on this platform.
///
/// `false` on the web: the native bridge embeds QuickJS through `dart:ffi`,
/// which does not exist on dart2js / dart2wasm. Running the scripts through
/// the browser's own engine is deliberately not done — the bridge needs
/// synchronous host calls and replaces `window` / `document` wholesale, which
/// would require a same-origin realm and give SVG scripts (often loaded from
/// the network) access to the host page's origin. On native they are confined
/// to the QuickJS sandbox.
const bool svgJsBridgeSupported = false;

/// Web stand-in for the QuickJS-backed `SvgJsBridge`.
///
/// Has the same public surface so platform-neutral code compiles, but never
/// executes JavaScript. `AnimatedSvgPicture` checks [svgJsBridgeSupported]
/// and does not construct a bridge on the web; if one is constructed anyway,
/// every call is a no-op and [externalScriptsLoaded] is already complete.
class SvgJsBridge {
  /// Creates an inert bridge. The arguments are accepted for API parity with
  /// the native implementation and ignored.
  SvgJsBridge({
    required SvgDocument document,
    required void Function() markNeedsRepaint,
    required void Function(
      String elementId,
      String eventType,
      void Function() callback,
    )
    addEventHandler,
  });

  /// Always complete: no external scripts are ever fetched on the web.
  Future<void> get externalScriptsLoaded => Future<void>.value();

  /// No-op on the web.
  void executeScript(String code) {}

  /// No-op on the web.
  void onInlinesDone() {}

  /// No-op on the web.
  void fireLoadEvents() {}

  /// No-op on the web.
  void dispatchInlineHandler(String elementId, String handlerCode) {}

  /// Always `null` on the web (there is no runtime to evaluate in).
  String? evaluateForDebug(String code) => null;

  /// No-op on the web.
  void dispose() {}
}
