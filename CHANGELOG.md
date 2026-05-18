## 2.0.0

### One self-contained rendering engine 🎉

Static SVG rendering no longer depends on the `vector_graphics` package
family. Both static (`SvgPicture`) and animated (`FSvgPicture` /
`AnimatedSvgPicture`) SVGs are now rendered by this package's own
DOM-preserving engine — one consistent code path, fewer transitive
dependencies, and the full feature set (filters, masks, gradients, text)
available to static SVGs too.

**Breaking changes**

- Removed the dependencies on `vector_graphics`, `vector_graphics_compiler`,
  and `vector_graphics_codec`. They are no longer pulled into your app.
- `SvgPicture` is now rendered by the built-in engine instead of
  `vector_graphics`' `createCompatVectorGraphic`. The public `SvgPicture`
  API — every constructor, `SvgTheme`, `ColorMapper`, and all loaders — is
  unchanged.
- Types previously re-exported from `vector_graphics` are now owned by this
  package:
  - `BytesLoader` resolves the raw UTF-8 SVG source rather than a compiled
    binary vector format.
  - `PictureInfo` is now this package's own class (`picture` + `size`),
    produced by the new `renderSvgToPicture` helper.
  - `RenderingStrategy` is retained for source compatibility but is now a
    no-op hint.
- Removed precompiled `.vec` asset support (`AssetBytesLoader`) — it was a
  `vector_graphics_compiler` feature. SVGs are parsed directly at runtime
  and the decoded source is cached.
- `vg` / `VectorGraphicUtilities` are no longer exported. Use
  `renderSvgToPicture` to render an SVG to a `ui.Picture` / `ui.Image`.

**New**

- `renderSvgToPicture(String svg, {Size?, SvgTheme?, ColorMapper?})` renders
  an SVG to a `PictureInfo` outside the widget tree.
- `SvgTheme` (`currentColor`, `font-size`) and `ColorMapper` (per-attribute
  color substitution) are now honored by the engine for both static and
  animated SVGs.
- `AnimatedSvgPicture` accepts `theme` and `colorMapper`.
- `BoxFit` / `alignment` are now honored for non-`contain` fits.
- `SvgPicture` without an explicit `width`/`height` lays out at its
  intrinsic size in unbounded contexts (rows, columns, scroll views).
- New demo assets: an animated Flutter logo (`assets/flutter_logo_animated.svg`)
  and a CSS `@keyframes` loader (`assets/demo_css.svg`).

**Fixed**

- Relaxed the `meta` dependency constraint from `^1.17.0` to `^1.16.0` so it
  no longer conflicts with the `meta` version pinned by the SDK's
  `flutter_test` (Flutter 3.32 ships `meta 1.16.0`), which previously made
  version resolution fail for projects that also use `flutter_test`.

**Migration**

For static SVGs no code change is required — `SvgPicture.asset` /
`.network` / `.string` / `.memory` / `.file` work exactly as before. If you
imported `vector_graphics` types directly, switch to the package's own
(`BytesLoader`, `PictureInfo`, `renderSvgToPicture`) exported from
`package:full_svg_flutter/full_svg_flutter.dart`.

## 1.1.1

Documentation fixes for the 1.1.0 release — no code changes.

- Updated supported-features table: `JavaScript inside SVG` row now reads ✅ Supported (linking to the JavaScript runtime section) instead of the stale ❌ from previous versions.
- Updated FAQ entry on SVGator: both SMIL/CSS and JS-export modes are documented as working now.
- Added a **Native dependencies** + **Building the native library from source** section to the README covering macOS / Linux / Windows toolchain prerequisites and when end users actually need to recompile.
- Rewrote [`doc/limitations.md`](doc/limitations.md) JavaScript section: spelled out which DOM APIs the polyfill covers and which still aren't supported (full HTML DOM, inline `onclick=` handlers, browser frameworks).
- Updated [`doc/supported_features.md`](doc/supported_features.md): JavaScript runtime is its own table now with the polyfill surface; removed the obsolete row from "Not supported".
- Quick-start version pins refreshed from 1.0.3 → 1.1.0.

## 1.1.0

### JavaScript runtime + SVGator support 🎉

This release ships an embedded JavaScript engine and a polyfilled SVG DOM, so animated SVGs that drive their animation through inline `<script>` blocks now render natively — no WebView, no conversion to SMIL.

- **SVGator JS-export files now render correctly.** Coffee Match Cut, Glowing Gummies, Basketball Boy, Skating Girls, Dog Character, Ramen Raccoon and similar SVGator-exported scenes play with their original player script attached. SMIL/CSS export is no longer required.
- **Embedded JavaScript engine.** [QuickJS-NG][qjsng] 0.14.0 (May 2026 release) ships inside the app on every platform — Android, iOS, macOS, Linux, Windows — via the new [`quickjs_engine`][qjs-engine-pkg] runtime package. The same JS engine on every target eliminates the JSC-vs-old-QuickJS divergence that plagued cross-platform JS-in-SVG.
- **SVG DOM polyfill.** `document.getElementById`, `Element.setAttribute`/`setAttributeNS`, `style` property proxy, virtual `createElementNS('svg', 'path')` with real `getTotalLength()` and `getPointAtLength(distance)` for arc-length-parameterized bezier interpolation, `requestAnimationFrame`, `addEventListener`, timers, `fetch`/XHR via Dart `http`, plus the rest of the surface SVGator and similar players touch.
- **Cubic-bezier path arc-length math.** Virtual `<path>` elements compute real arc length via 100-sample subdivision + cumulative table; `getPointAtLength` does a binary search across the table and linearly interpolates between samples. Cached per-path keyed by the `d` attribute. This is the keystone fix that gets SVGator's `Ft()` interpolator to produce correct points instead of `{x:0, y:0}` mid-segment.
- Custom JS animations also work — any inline `<script>` that walks the SVG via `getElementById` + `setAttribute` will animate, even if it's not from SVGator.

[qjsng]: https://github.com/quickjs-ng/quickjs
[qjs-engine-pkg]: https://pub.dev/packages/quickjs_engine

## 1.0.3

- Fix `<image>` aspect ratio: when only `width` or `height` is specified, the missing dimension is now computed proportionally from the image's intrinsic size. Previously, the raw pixel dimension was used, causing images placed with a single size attribute to shift position and appear at incorrect scale.
- Fix `background-color` clipping with `clipToViewBox=true`: the SVG root `background-color` style was drawn before the viewBox clip was applied, causing it to fill the entire widget instead of being bounded by the SVG viewport. It is now drawn inside the transformed and clipped canvas context, matching browser behaviour.
- Add `clipToViewBox` toggle (default `true`) to the example playground, so SVG content that overflows the viewBox boundary is clipped by default — matching how browsers display SVG files opened directly.
- Fix playground SVG proportions: preview width and height are now derived from the SVG `viewBox` aspect ratio instead of forcing a square container, so portrait or landscape SVGs display at correct proportions.

## 1.0.2

- Add native `file://` URI support for `<image>` elements: local files load via `dart:io` on all non-web platforms. Web stub returns null gracefully.
- Improve pub.dev package description and topics for animated SVG discoverability.
- Rewrite README: clear animated-SVG positioning, comparison table, migration guide, SVGator notes, FAQ, and supported-features matrix.
- Add `docs/` directory: migration guide, feature compatibility matrix, limitations, and SEO notes.
- Add marketing article drafts in `docs/marketing/`.

## 1.0.1

* Fix filter rendering on `<g>` groups: filters applied to `<g>` elements with no opacity or blend-mode were silently discarded. Now correctly opens a `saveLayer` with the filter, improving fidelity for SVGs that animate filter primitives on groups.
* Fix SMIL sandwich model for multiple animations targeting the same attribute: additive animations no longer double-stack when chained via `computeRawValue` + `applyAdditiveWithBase`.
* Add `clipToViewBox` option to `AnimatedSvgPicture` and `AnimatedSvgPainter`: opt-in strict viewBox clipping to match browser direct-URL rendering behaviour (defaults to `false` for backward compatibility).
* Widen `xml` dependency constraint from `^6.0.0` to `>=6.0.0 <8.0.0` to support xml 7.x.
* Fix deprecated `FontWeight.index` usage — replaced with `FontWeight.value`.

## 1.0.0

* Initial release of `full_svg_flutter` — a comprehensive SVG rendering library for Flutter.
