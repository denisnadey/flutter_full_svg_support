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
- `flutter test`: **All tests passed** (`+493 ~1`)
- `flutter analyze`: **0 errors**, **0 warnings** (info-level deprecations remain)

## What Is Implemented

### SMIL Engine
- `<animate>`, `<animateTransform>`, `<animateMotion>`, `<set>`, `<animateColor>` parsing
- `animateMotion`: inline `path` and `<mpath href="#...">` / `<mpath xlink:href="#...">` references
- Timing conditions: offset, syncbase, event-based
- Event target syntax support: `id.click`, `id.mouseover+200ms`
- `calcMode="spline"`, `calcMode="paced"`
- `additive="sum"`, `accumulate="sum"`
- `AnimatedSvgController`: pause/resume/seek/playbackRate/restart/reverse

### Interaction & Events
- Document-level events: click/mouseover/mouseout dispatch
- Element-level hit-testing and dispatch for `rect/circle/ellipse/line/path/polygon/polyline`
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
  - `feMerge` (baseline parsing/composition placeholder)
  - `feDropShadow` (simplified)
  - `feColorMatrix`

### Geometry Rendering (Animated Pipeline)
- Painted: `rect`, `circle`, `ellipse`, `line`, `path`, `polygon`, `polyline`
- `path` rendering implemented via `PathParser` + command-to-canvas conversion
- Gradient paint servers for fill/stroke: `linearGradient`, `radialGradient`, `stop`

### Structural / Reuse (Animated Pipeline)
- Baseline `<use href="#id">` rendering is implemented
- Baseline `<symbol>` rendering through `<use href="#symbolId">` is implemented (`viewBox` + `use width/height` scaling)
- `<defs>` content is treated as definitions-only (not painted directly)

### Clipping / Masking (Animated Pipeline)
- Baseline `clipPath` support (`clip-path="url(#id)"`) is implemented
- Baseline `mask` support (`mask="url(#id)"`) is implemented (geometry clipping semantics)

## Known Gaps (Blink Parity, Animated Pipeline)

Detailed audit: `/Users/denisnadey/apps/flutter_full_svg_support/docs/BLINK_PARITY_AUDIT.md`

High-impact gaps:
1. No animated-pipeline support for text, full mask/clip semantics parity, full reuse parity (advanced `<use>` inheritance and `symbol` semantics), image/foreignObject.
2. Hit-testing still misses text and advanced painted-geometry semantics (full clip/mask/use-aware hit regions).
3. Filter parity is partial: 8/25 Blink filter primitives.
4. CSS animation conversion is partial (`transform` parsing, `cubic-bezier`, `alternate*`).
5. `animateMotion` still lacks broader Blink-level semantics beyond path references.
6. `paced` distance fallback for `path`/`transform` remains incomplete.

## Documentation Policy

To avoid drift:
- Current factual status lives only here.
- `NEXT_STEPS.md` and `TODO.md` are planning documents.

## Next Execution Plan

1. Expand filter primitive support beyond current 8/25 by upgrading `feMerge`/`feMergeNode` and `feDropShadow` to full composition semantics.
2. Expand hit-testing beyond current baseline to cover advanced painted geometry semantics (clip/mask/use and text).
3. Continue CSS/SMIL parity gaps (`transform`, `cubic-bezier`, `alternate*`).
4. Improve `<use>`/`symbol` inheritance semantics.
