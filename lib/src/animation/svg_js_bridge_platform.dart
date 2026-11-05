/// Platform switch for the SVG `<script>` runtime.
///
/// Native platforms (Android, iOS, macOS, Windows, Linux) get the
/// QuickJS-backed `SvgJsBridge` from `svg_js_bridge.dart`. On the web
/// (dart2js and dart2wasm) `dart:ffi` — and therefore
/// `package:quickjs_engine` — is unavailable, so `svg_js_bridge_web.dart` is
/// exported instead: `svgJsBridgeSupported` is `false` and `<script>`
/// elements are skipped while everything else still renders.
library;

export 'svg_js_bridge.dart'
    if (dart.library.js_interop) 'svg_js_bridge_web.dart';
