# Limitations

`full_svg_flutter` is a full-featured SVG renderer, but it is not a full browser engine. This document lists known limitations honestly so you can evaluate whether the package fits your use case.

---

## JavaScript

As of 1.1.0, JavaScript inside SVG files **is executed** by an embedded
QuickJS engine ([`quickjs_engine`](https://pub.dev/packages/quickjs_engine))
running against a polyfilled SVG DOM, on Android, iOS, macOS, Windows and
Linux. On the web, scripts are skipped. See [Web platform](#web-platform).
On native platforms this covers:

- inline `<script>` blocks and `<script src="...">` references
- SVGator files exported in **JavaScript** animation mode
- hand-written JS animations that walk the SVG via
  `document.getElementById` + `setAttribute`

What still won't work:

- code that depends on the **full browser DOM** (`window.location`,
  `History` API, full HTML layout, IndexedDB, WebGL, etc.) — only SVG-DOM
  surface is polyfilled
- inline HTML event handlers (`onclick="…"` on SVG elements) — use
  `addEventListener` from a `<script>` instead
- third-party JS frameworks that try to bootstrap a browser environment

If a JS-export SVGator file (or any other JS-driven SVG) renders
incorrectly, please open an issue with the offending `.svg` attached. The
SVG-DOM polyfill is still growing and missing methods get added as we
encounter real-world cases.

---

## External resources

Cross-origin external resources (images, fonts, stylesheets linked via `href` or `xlink:href` to an external domain) follow Flutter's platform security policy. On most platforms they will not load unless you configure the appropriate network permissions.

Local `file://` URIs work on all non-web platforms. On the web, browser security policy restricts `file://` access.

---

## SVG filters

All 17 filter primitives are implemented, but complex stacked filter chains may produce results that differ slightly from browser rendering. The differences are typically due to:

- floating-point precision in convolution math
- color-space handling (sRGB vs linearRGB) in edge cases
- compositing order differences in nested filter regions

---

## Text layout

Text rendering is handled by Flutter's paragraph layout engine, which differs from browsers in some edge cases:

- Mixed RTL+LTR within a single `<text>` element may differ in line-breaking
- Some OpenType features (discretionary ligatures, contextual alternates) depend on the available system fonts
- `<tref>` (referencing external text content) has partial support

---

## `<foreignObject>`

`<foreignObject>` is parsed and its bounding box is included in layout, but its content is not rendered. This is intentional — rendering arbitrary HTML inside Flutter is not possible without a WebView.

---

## Malformed SVG

Malformed SVG files may produce unexpected results or silent failures. The parser is lenient by design (browsers are too), but severely invalid SVG may need preprocessing.

---

## Performance on very complex SVGs

SVGs with hundreds of animated elements, deep filter chains, or very large path datasets may impact frame rate on lower-end devices. Use the `raster` rendering strategy for static-or-rarely-updated complex SVGs:

```dart
FSvgPicture.asset('assets/complex.svg', renderingStrategy: RenderingStrategy.raster)
```

---

## Web platform

The package builds and runs on the web with both the default dart2js
compiler and `flutter build web --wasm`. Static rendering, SMIL and CSS
animation, filters, masks, gradients and text are all supported on the web.
The exceptions are below.

### `<script>` is not executed

The embedded JavaScript engine (`quickjs_engine`) is loaded through
`dart:ffi`, which web builds don't have. On the web, `<script>` elements
(inline and `src=`) and inline `on*="…"` handlers are **skipped**:

- The rest of the SVG renders and animates as usual.
- SVGator files exported in *JavaScript* mode show their static,
  un-animated markup. To animate them on the web, export them in
  SMIL/CSS mode.
- The first skipped SVG prints one console line,
  `full_svg_flutter: skipping N SVG <script> element(s) …`. Every skipped
  SVG also sends an `SvgTraceEvent` (category `js`, level `warning`) to
  `onTrace`.

The scripts are deliberately not run through the browser's own JavaScript
engine. The bridge makes synchronous calls into Dart and replaces `window`,
`document`, timers and `requestAnimationFrame` with SVG-DOM polyfills. In a
browser that would need a realm on the host page's origin. An SVG script,
often loaded from the network, could then reach the app's cookies, storage
and DOM. On native platforms these scripts can only reach the SVG through
the bridge.

### Compressed WOFF / WOFF2 `@font-face` fonts

`@font-face` fonts are decoded by the `woff2` package. It uses `dart:io`'s
zlib for WOFF1 and an FFI Brotli codec for WOFF2, and neither works in the
browser. On the web, WOFF1 fonts with zlib-compressed tables and all WOFF2
fonts fail to decode. The failure is caught and recorded, and text falls
back to the next font in `font-family`. Embedded TTF/OTF fonts and WOFF1
fonts with uncompressed tables load normally.

### `file://` URIs

`<image href="file://...">` and `AnimatedSvgPicture.file` are not supported
on the web, because browsers don't allow file access. The web stub returns
`null`, so the image element is skipped without an error.

---

## Reporting issues

If you encounter a rendering difference from a browser, please open an issue at the [GitHub repository](https://github.com/denisnadey/flutter_full_svg_support/issues) with:

1. The SVG file or a minimal reproduction
2. A screenshot of the expected (browser) output
3. A screenshot of the actual (Flutter) output
4. The platform and Flutter version
