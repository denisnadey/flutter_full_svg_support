# Current Development Status

**Last Updated:** March 12, 2026  
**Authority:** This file is the single source of truth for current project state.

## Snapshot

- Branch: `main`
- Flutter SDK: `3.38.1` (via `./.fvm/flutter_sdk/bin/flutter`)
- Dart SDK: `3.10.0`

## Verified Health (February 21, 2026)

Commands run in `/Users/denisnadey/apps/flutter_full_svg_support`:

```bash
./.fvm/flutter_sdk/bin/flutter test
./.fvm/flutter_sdk/bin/flutter analyze
```

Result:
- `flutter test`: **All tests passed** (`+537 ~1`)
- `flutter analyze`: **56 info**, **0 errors**, **0 warnings** (deprecations and minor lint items)

## What Is Implemented

### SMIL Engine
- `<animate>`, `<animateTransform>`, `<animateMotion>`, `<set>`, `<animateColor>` parsing
- `animateMotion`: inline `path` and `<mpath href="#...">` / `<mpath xlink:href="#...">` references
- Timing conditions: offset, syncbase, event-based
- Event target syntax support: `id.click`, `id.mouseover+200ms`
- `calcMode="spline"`, `calcMode="paced"`
- `additive="sum"`, `accumulate="sum"`
- `AnimatedSvgController`: pause/resume/seek/playbackRate/restart/reverse

### CSS Animation Interop
- `@keyframes` extraction and `animation` / `animation-*` parsing
- CSS->SMIL timing conversion with `cubic-bezier(...)` and `ease*` mapped to SMIL `keySplines`
- CSS `animation-direction`: `reverse`, `alternate`, `alternate-reverse` runtime behavior
- Baseline CSS transform-function normalization in converter (`deg/rad/turn`, `px`, function aliases like `translateX`)

### Color Parsing (Parser Path)
- `#RGB`, `#RGBA`, `#RRGGBB`, `#RRGGBBAA`
- `rgb(...)` / `rgba(...)` (comma and CSS Color 4 space/slash variants)
- `hsl(...)` / `hsla(...)` with angle units (`deg/rad/turn/grad`)

### Interaction & Events
- Document-level events: click/mouseover/mouseout dispatch
- Element-level hit-testing and dispatch for `rect/circle/ellipse/line/path/polygon/polyline/image/foreignObject/text/tspan/textPath`
- Baseline `pointer-events` hit-testing semantics: inherited `none` suppression, descendant override, geometry-mode support (`fill`, `stroke`, `painted`, `all`, `bounding-box`), and text-aware mode gating for `text`/`tspan`/`textPath` (including `visible*`/`stroke`/`fill` behavior)
- Baseline `<use>`-referenced hit-testing is implemented (event targets inside `defs` can be activated via rendered `<use>`)
- Baseline `clip-path` / `mask` visibility gating is applied in hit-testing (including inline `style` property forms)
- Inline `style` declarations with trailing `!important` are normalized in hit-testing/visibility gating path for properties like `display`, `clip-path`, and `mask`
- Target-specific event activation in timeline and tests

### Runtime Diagnostics
- Structured trace API in `AnimatedSvgPicture`:
  - `SvgTraceEvent`, `SvgTraceLevel`, `onTrace`
  - Optional per-frame tick tracing (`traceFrameTicks`)

### Example Playground
- `example/lib/pages/custom_svg_viewer_page.dart` now provides:
  - SVG input (code + URL)
  - Live preview with controller controls
  - Trace logs, problems panel, and system checklist
  - Structured static diagnostics (parity/unsupported tags, unsupported filter primitives, broken references)
  - Export/import of full run report as JSON (source + diagnostics + runtime trace log)
  - Trace logs filtering (severity/category) and search
  - Problems grouping by `code`/`category`
  - Widget-test coverage for trace-log search/filter controls and problems grouping UI behavior

### SVG Filters (Animated Pipeline)
- Parsed/applied primitives:
  - `feGaussianBlur`
  - `feMorphology` (baseline `erode`/`dilate`)
  - `feDisplacementMap` (baseline graph pass-through for `in`/`in2`, with `scale=0` identity behavior, explicit `in2` unresolved gating, and explicit `in2="none"` transparent-input handling)
  - `feImage` (baseline non-source graph semantics: `href` without explicit `in` starts a new placeholder source output)
  - `feConvolveMatrix` (baseline graph pass-through with parsed kernel attributes)
  - `feTurbulence` (baseline graph pass-through with parsed noise generator attributes)
  - `feComponentTransfer` (baseline graph pass-through with parsed channel-function attributes)
  - `feDiffuseLighting` (baseline graph pass-through with parsed light-source, geometry, and kernelUnitLength attributes)
  - `feSpecularLighting` (baseline graph pass-through with parsed light-source, geometry, and kernelUnitLength attributes)
  - Baseline unresolved-result parity for non-merge primitives (`in`/`in2` explicit unknown inputs no longer fall back to previous output)
  - Explicit `in="none"` is treated as empty input (transparent placeholder semantics) and does not fall back to previous output, including merge-node graph flow
  - Explicit `in2="none"` for `feDisplacementMap`, `feBlend`, and `feComposite` is treated as transparent input (case-insensitive) rather than unresolved input-chain collapse
  - Built-in filter inputs (`Source*`, `Background*`, `FillPaint`, `StrokePaint`) are resolved case-insensitively in baseline graph resolver
  - `FillPaint` / `StrokePaint` now consume element paint context in animated painter path (solid-color baseline approximation, with fill-only/stroke-only source masking fallback for unresolved paint servers)
  - `BackgroundImage` / `BackgroundAlpha` now accept optional source-context passes in resolver flow (fallback remains source placeholder + source alpha placeholder)
  - `feOffset`
  - `feFlood`
  - `feBlend` (baseline `in2` layering in pass graph + extended SVG2 mode mapping: `overlay`, `color-dodge`, `color-burn`, `hard-light`, `soft-light`, `difference`, `exclusion`, `hue`, `saturation`, `color`, `luminosity`)
  - `feComposite` (baseline `in2` layering for non-arithmetic operators + arithmetic coefficient approximations for `k3-only`/`k2+k3` and transparent all-zero output)
  - `feMerge` (multi-pass composition with named primitive results; explicit unresolved/forward `feMergeNode in` inputs resolve as empty without previous-input fallback, while implicit node input remains previous-chain based)
  - `feTile` (baseline pass-through in filter graph)
  - `feDropShadow` (source + shadow multi-pass composition with color/opacity/offset/blur; shadow passes preserve input paint-channel scope for `FillPaint`/`StrokePaint` contexts; parser supports inline `style` fallback/override for `dx`/`dy`/`stdDeviation`/`flood-color`/`flood-opacity` with `!important` normalization)
  - `feColorMatrix`

### Geometry Rendering (Animated Pipeline)
- Painted: `rect`, `circle`, `ellipse`, `line`, `path`, `polygon`, `polyline`, `image`, `text`, `tspan`, `textPath` (baseline)
- `path` rendering implemented via `PathParser` + command-to-canvas conversion
- Gradient paint servers for fill/stroke: `linearGradient`, `radialGradient`, `stop`
- `visibility` inheritance is respected in painting flow (hidden ancestors suppress descendant paint unless explicitly overridden by descendant visibility)

### Text & Typography (Animated Pipeline)
- Baseline `<text>` rendering is implemented
- Baseline `<tspan>` rendering is implemented (including basic `dx`/`dy` offsets)
- Baseline `<textPath href="#...">` rendering is implemented (including `xlink:href` and `startOffset`)
- Direct text content extraction from SVG DOM is implemented for text nodes
- Text spacing attributes `letter-spacing` and `word-spacing` are applied in paint and aligned hit-testing flow
- Baseline alignment semantics `dominant-baseline` and `baseline-shift` are applied in paint and aligned hit-testing flow
- `textLength` and `lengthAdjust` (`spacing`, `spacingAndGlyphs`) are supported for `<text>` and `<textPath>` in paint and hit-testing

### Structural / Reuse (Animated Pipeline)
- Baseline `<use href="#id">` rendering is implemented
- Baseline `<symbol>` rendering through `<use href="#symbolId">` is implemented (`viewBox` + `use width/height` scaling)
- `<defs>` content is treated as definitions-only (not painted directly)

### External Content (Animated Pipeline)
- Baseline `<image>` rendering is implemented (`href` / `xlink:href`)
- `data:` URI image sources are decoded and rendered
- Network (`http/https`) and bundle-path image source loading is implemented (best-effort)
- Baseline `<foreignObject>` container viewport is implemented (`x/y` offset + rectangular clip for children)

### Clipping / Masking (Animated Pipeline)
- Baseline `clipPath` support (`clip-path="url(#id)"`) is implemented
- Baseline `mask` support (`mask="url(#id)"`) is implemented (geometry clipping semantics)
- Inline `style` forms are supported for `clip-path`, `mask`, and `filter` application paths
- Inline `style` parsing normalizes trailing `!important` in paint/filter application flow

## Known Gaps (Blink Parity, Animated Pipeline)

Detailed audit: `/Users/denisnadey/apps/flutter_full_svg_support/docs/BLINK_PARITY_AUDIT.md`

High-impact gaps:
1. No full animated-pipeline text parity (advanced typography semantics for `<text>/<tspan>/<textPath>`), full mask/clip semantics parity, and full reuse parity (advanced `<use>` inheritance and `symbol` semantics).
2. Hit-testing still misses full painted-geometry parity (advanced clip/mask/use semantics, units/inheritance parity, and full text geometry semantics).
3. Filter parity is partial: 17/25 Blink filter primitives; advanced cross-input FE graph semantics remain limited (e.g. partial background input handling and non-rasterized external sources).
4. CSS animation conversion remains partial for advanced/edge CSS semantics (broader transform/timing shorthand corner cases and fidelity gaps).
5. `animateMotion` still lacks broader Blink-level semantics beyond path references.
6. `paced` distance fallback for `path`/`transform` remains incomplete.

## Documentation Policy

To avoid drift:
- Current factual status lives only here.
- `NEXT_STEPS.md` and `TODO.md` are planning documents.

## Next Execution Plan

1. Expand filter primitive support beyond current 17/25 and improve advanced non-source input graph semantics.
2. Complete advanced text parity beyond current baseline (`textPath` spacing/length adjustments, dominant baseline, anchor model parity).
3. Expand hit-testing beyond current baseline to cover advanced painted geometry semantics (clip/mask/use and text geometry parity).
4. Expand `<foreignObject>` from baseline viewport/container behavior to broader parity and close advanced `<image>` semantics.
5. Continue CSS/SMIL parity gaps (advanced CSS edge cases and regression fixtures).
