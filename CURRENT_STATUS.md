# Current Development Status

**Last Updated:** February 21, 2026  
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
- Baseline `<use>`-referenced hit-testing is implemented (event targets inside `defs` can be activated via rendered `<use>`)
- Baseline `clip-path` / `mask` visibility gating is applied in hit-testing
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

### SVG Filters (Animated Pipeline)
- Parsed/applied primitives:
  - `feGaussianBlur`
  - `feOffset`
  - `feFlood`
  - `feBlend`
  - `feComposite`
  - `feMerge` (multi-pass composition with named primitive results in source-based graph path)
  - `feDropShadow` (source + shadow multi-pass composition with color/opacity/offset/blur)
  - `feColorMatrix`

### Geometry Rendering (Animated Pipeline)
- Painted: `rect`, `circle`, `ellipse`, `line`, `path`, `polygon`, `polyline`, `image`, `text`, `tspan`, `textPath` (baseline)
- `path` rendering implemented via `PathParser` + command-to-canvas conversion
- Gradient paint servers for fill/stroke: `linearGradient`, `radialGradient`, `stop`

### Text & Typography (Animated Pipeline)
- Baseline `<text>` rendering is implemented
- Baseline `<tspan>` rendering is implemented (including basic `dx`/`dy` offsets)
- Baseline `<textPath href="#...">` rendering is implemented (including `xlink:href` and `startOffset`)
- Direct text content extraction from SVG DOM is implemented for text nodes

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

## Known Gaps (Blink Parity, Animated Pipeline)

Detailed audit: `/Users/denisnadey/apps/flutter_full_svg_support/docs/BLINK_PARITY_AUDIT.md`

High-impact gaps:
1. No full animated-pipeline text parity (advanced typography semantics for `<text>/<tspan>/<textPath>`), full mask/clip semantics parity, and full reuse parity (advanced `<use>` inheritance and `symbol` semantics).
2. Hit-testing still misses full painted-geometry parity (advanced clip/mask/use semantics, units/inheritance parity, and full text geometry semantics).
3. Filter parity is partial: 8/25 Blink filter primitives; advanced cross-input FE graph semantics remain limited (e.g. background inputs).
4. CSS animation conversion remains partial for advanced/edge CSS semantics (broader transform/timing shorthand corner cases and fidelity gaps).
5. `animateMotion` still lacks broader Blink-level semantics beyond path references.
6. `paced` distance fallback for `path`/`transform` remains incomplete.

## Documentation Policy

To avoid drift:
- Current factual status lives only here.
- `NEXT_STEPS.md` and `TODO.md` are planning documents.

## Next Execution Plan

1. Expand filter primitive support beyond current 8/25 and improve advanced non-source input graph semantics.
2. Complete advanced text parity beyond current baseline (`textPath` spacing/length adjustments, dominant baseline, anchor model parity).
3. Expand hit-testing beyond current baseline to cover advanced painted geometry semantics (clip/mask/use and text geometry parity).
4. Expand `<foreignObject>` from baseline viewport/container behavior to broader parity and close advanced `<image>` semantics.
5. Continue CSS/SMIL parity gaps (advanced CSS edge cases and regression fixtures).
