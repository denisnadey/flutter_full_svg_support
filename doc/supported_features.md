# Supported SVG features

This document is the detailed companion to the feature table in the README.

Status legend:
- ✅ **Supported** — works in normal use
- ⚠️ **Partial** — works for common cases; edge cases may differ from browser
- 🧪 **Experimental** — available but not yet fully tested
- ❌ **Not supported** — not implemented; may be planned
- 🚧 **Planned** — on the roadmap

---

## Geometry and shapes

| Feature | Status | Notes |
|---|---|---|
| `<rect>` | ✅ | Including `rx`/`ry` rounded corners |
| `<circle>` | ✅ | |
| `<ellipse>` | ✅ | |
| `<line>` | ✅ | |
| `<polyline>` | ✅ | |
| `<polygon>` | ✅ | |
| `<path>` | ✅ | All commands: M/m L/l H/h V/v C/c S/s Q/q T/t A/a Z |
| `<image>` (asset) | ✅ | Flutter asset bundle |
| `<image>` (http/https) | ✅ | Network loading |
| `<image>` (data URI) | ✅ | Base64-encoded inline images |
| `<image>` (file://) | ✅ | Native platforms only (web: not supported) |
| Markers (`<marker>`) | ✅ | markerUnits, orient, refX/Y |
| `context-fill` / `context-stroke` (SVG 2) | ✅ | In markers (referencing shape) and `<use>` content (the `<use>` element); `none` elsewhere |
| Patterns (`<pattern>`) | ✅ | patternUnits, patternContentUnits, patternTransform |

---

## Gradients

| Feature | Status | Notes |
|---|---|---|
| `<linearGradient>` | ✅ | gradientUnits, spreadMethod, gradientTransform |
| `<radialGradient>` | ✅ | focal point (fx/fy), gradientUnits |
| `<stop>` with `stop-opacity` | ✅ | |
| Gradient inheritance (`href`) | ✅ | |

---

## Clipping and masking

| Feature | Status | Notes |
|---|---|---|
| `<clipPath>` | ✅ | clipPathUnits, nested clip paths |
| `clip-rule` (nonzero / evenodd) | ✅ | |
| `<mask>` | ✅ | maskUnits, maskContentUnits |
| Luminance mask | ✅ | mask-type: luminance |
| Alpha mask | ✅ | mask-type: alpha |
| Layer compositing order | ✅ | Blink parity |

---

## Text and typography

| Feature | Status | Notes |
|---|---|---|
| `<text>` / `<tspan>` | ✅ | |
| Multi-position x/y/dx/dy arrays | ✅ | Per-character positioning |
| Per-character rotate | ✅ | |
| `<textPath>` | ✅ | startOffset, method, spacing |
| writing-mode (horizontal/vertical) | ✅ | |
| text-decoration (underline/overline/line-through) | ✅ | |
| Bidi / RTL text | ✅ | unicode-bidi, direction |
| text-emphasis | ✅ | |
| paint-order (stroke-then-fill) | ✅ | |
| font-variant | ✅ | |
| NFC normalization | ✅ | |
| Grapheme cluster handling | ✅ | |
| Hanging punctuation | ✅ | |
| Baseline alignment | ✅ | dominant-baseline, alignment-baseline |
| Ligature shaping | ✅ | |
| text-shadow | ✅ | |
| `<tref>` | ⚠️ | Partial |

---

## SMIL animation

| Feature | Status | Notes |
|---|---|---|
| `<animate>` | ✅ | |
| `<animateTransform>` | ✅ | translate, rotate, scale, skewX, skewY |
| `<animateMotion>` | ✅ | |
| `<mpath>` | ✅ | path follow with rotate=auto |
| `<set>` | ✅ | |
| `<animateColor>` | ✅ | |
| begin / end / dur / repeatCount | ✅ | |
| Syncbase timing (begin="other.end+1s") | ✅ | |
| Event-based begin/end | ✅ | click, mouseover, etc. |
| calcMode linear / discrete | ✅ | |
| calcMode spline | ✅ | cubic bezier |
| calcMode paced | ✅ | |
| keyTimes / keySplines | ✅ | |
| keyPoints | ✅ | |
| additive="sum" | ✅ | |
| accumulate="sum" | ✅ | |
| `values` list | ✅ | |
| `from` / `to` / `by` | ✅ | |

---

## CSS animation

| Feature | Status | Notes |
|---|---|---|
| `@keyframes` | ✅ | |
| `animation-name` / `animation-duration` | ✅ | |
| `animation-timing-function` | ✅ | |
| `animation-delay` | ✅ | |
| `animation-iteration-count` | ✅ | |
| `animation-direction` | ✅ | |
| `animation-fill-mode` | ✅ | |
| `animation-play-state` | ✅ | |
| CSS transitions | ✅ | |
| 2D transforms (translate, rotate, scale, skew, matrix) | ✅ | |
| 3D transforms (translate3d, rotate3d, matrix3d, perspective) | ✅ | |
| `calc()` | ✅ | |
| `var()` (CSS custom properties) | ✅ | |
| `@media` queries | ✅ | |

---

## CSS selectors

| Feature | Status |
|---|---|
| Type / class / id selectors | ✅ |
| Descendant / child / sibling combinators | ✅ |
| Attribute selectors (`[attr]`, `[attr=val]`, `[attr^=val]`, etc.) | ✅ |
| `:hover`, `:active`, `:focus` | ✅ |
| `:not()`, `:nth-child()`, `:nth-of-type()` | ✅ |
| `:empty`, `:root`, `:first-child`, `:last-child` | ✅ |
| `!important` | ✅ |
| Specificity cascade | ✅ |
| CSS shorthand expansion | ✅ |

---

## SVG filters (all 17/17 FE primitives)

| Primitive | Status | Notes |
|---|---|---|
| `feGaussianBlur` | ✅ | |
| `feColorMatrix` | ✅ | matrix, saturate, hueRotate, luminanceToAlpha |
| `feBlend` | ✅ | All SVG2 blend modes |
| `feComposite` | ✅ | arithmetic operator |
| `feMorphology` | ✅ | erode / dilate |
| `feDisplacementMap` | ✅ | bilinear sampling |
| `feDiffuseLighting` | ✅ | Lambertian per-pixel |
| `feSpecularLighting` | ✅ | Blinn-Phong per-pixel |
| `feConvolveMatrix` | ✅ | full kernel math |
| `feTurbulence` | ✅ | Perlin noise, fractalNoise / turbulence |
| `feComponentTransfer` | ✅ | identity, linear, gamma, discrete, table |
| `feOffset` | ✅ | |
| `feFlood` | ✅ | |
| `feMerge` | ✅ | |
| `feTile` | ✅ | |
| `feDropShadow` | ✅ | |
| `feImage` | ✅ | References SVG elements or external images |

---

## Interaction and accessibility

| Feature | Status | Notes |
|---|---|---|
| Hit-testing (rect, circle, path, text, use, g, image, …) | ✅ | 12 element types |
| `pointer-events` | ✅ | |
| `<a>` with `onLinkTap` callback | ✅ | |
| `<view>` fragment identifiers | ✅ | Named viewports |
| Per-character text hit regions | ✅ | |
| `<title>` → Semantics label | ✅ | |
| `<desc>` → Semantics hint | ✅ | |
| ARIA attributes | ✅ | |
| Flutter Semantics flags | ✅ | |

---

## Structural elements

| Feature | Status |
|---|---|
| `<g>` | ✅ |
| `<use>` | ✅ |
| `<symbol>` | ✅ |
| `<defs>` | ✅ |
| `<view>` | ✅ |
| `<a>` | ✅ |
| `<switch>` + `systemLanguage` | ✅ |
| `<foreignObject>` | ⚠️ Parsed; content not rendered |

---

## JavaScript runtime

As of 1.1.0, SVGs with inline `<script>` blocks (SVGator JS-export, custom
animations) execute against an embedded QuickJS engine on Android, iOS,
macOS, Windows and Linux.

**Web:** `<script>` is skipped, with a one-time console note and an
`onTrace` warning event. The rest of the SVG still renders and animates.
QuickJS is loaded through `dart:ffi`, which web builds don't have. For the
details and why scripts aren't run in the browser's own engine, see
[limitations.md › Web platform](limitations.md#web-platform). Every row
below is native-only.

| Feature | Status |
|---|---|
| Inline `<script>` execution | ✅ via [`quickjs_engine`](https://pub.dev/packages/quickjs_engine) |
| External `<script src="...">` | ✅ fetched via Dart `http`, executed locally |
| `document.getElementById` / `Element.setAttribute` | ✅ |
| `requestAnimationFrame` / timers | ✅ |
| `addEventListener` on SVG elements | ✅ (load, click, custom DOM events) |
| `getTotalLength` / `getPointAtLength` on virtual `<path>` | ✅ real arc-length math |
| `style` property proxy / `style.setProperty` | ✅ |
| `createElementNS` / `createElement` virtual nodes | ✅ |
| `MutationObserver` / full DOM observers | ❌ not polyfilled |
| Full browser DOM (window.location, History, layout APIs, IndexedDB, WebGL) | ❌ only SVG-DOM surface |
| Inline HTML event handlers (`onclick="…"`) | ❌ use `addEventListener` |

---

## Platforms

| Platform | Status | Notes |
|---|---|---|
| Android, iOS, macOS, Windows, Linux | ✅ | Full feature set, including `<script>` |
| Web (dart2js) | ✅ | No `<script>` execution. No compressed WOFF/WOFF2 `@font-face` decoding. No `file://` |
| Web (`--wasm`) | ✅ | Same as dart2js |

---

## Not supported

| Feature | Notes |
|---|---|
| External cross-origin resources | Platform security policy applies |
| SMIL `begin="wallclock(…)"` | Not implemented |
| SVG fonts (`<font>`, `<glyph>`) | Use system or web fonts instead |
| `cursor` property | Not applicable in Flutter |
| CSS custom media queries | Only basic `@media` (width, height, prefers-color-scheme) |
